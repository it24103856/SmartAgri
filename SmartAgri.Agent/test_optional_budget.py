import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch
from uuid import uuid4

from pydantic import ValidationError

from basket_agents import (
    BasketPlan, BasketReview, CatalogSelection, ProposalRequest,
    ProposalRejected, RequiredItem, UnavailableItem, build_basket,
    ask_model, generate_proposal, selection_errors,
)
from basket_tools import validate_basket
from schemas import BasketLine, BasketValidationRequest, CatalogProduct


def product(product_id=1, name="Apple", price=100, stock=20):
    return CatalogProduct(id=product_id, name=name, category_id=1,
                          unit="kg", unit_price_minor=price,
                          stock_quantity=stock, is_food=True, approved=True)


def selection(**changes):
    values = dict(eligible_product_ids=[1], excluded_product_ids=[],
                  required_items=[RequiredItem(product_id=1, quantity=2, exact_quantity=True)],
                  cover_all_categories=False, fill_budget=False, fixed_list=True, issues=[])
    values.update(changes)
    return CatalogSelection(**values)


class OptionalBudgetTests(unittest.TestCase):
    def test_missing_budget_and_single_short_product_name(self):
        request = ProposalRequest(workflow_id=uuid4(), objective="Rice", products=[])
        self.assertIsNone(request.budget_minor)

    def test_invalid_supplied_budgets_are_still_rejected(self):
        for budget in (0, -1, 100_000_001, 1.5, "100", True):
            with self.subTest(budget=budget), self.assertRaises(ValidationError):
                ProposalRequest(workflow_id=uuid4(), objective="Apple", products=[], budget_minor=budget)

    def test_list_without_budget_uses_requested_quantities_not_all_stock(self):
        lines = build_basket([product()], None, selection())
        self.assertEqual([(line.product_id, line.quantity) for line in lines], [(1, 2)])

    def test_fixed_list_does_not_add_unrequested_eligible_products(self):
        lines = build_basket([product(), product(2, "Orange")], 5000,
                             selection(eligible_product_ids=[1, 2]))
        self.assertEqual([(line.product_id, line.quantity) for line in lines], [(1, 2)])

    def test_general_basket_without_budget_never_fills_stock(self):
        lines = build_basket([product(), product(2, "Orange")], None,
                             selection(required_items=[], eligible_product_ids=[1, 2], fill_budget=True))
        self.assertEqual([line.quantity for line in lines], [1, 1])

    def test_mixed_basket_with_required_item_still_includes_other_products(self):
        lines = build_basket([product(), product(2, "Orange")], None,
                             selection(fixed_list=False, eligible_product_ids=[1, 2]))
        self.assertEqual([(line.product_id, line.quantity) for line in lines], [(1, 2), (2, 1)])

    def test_existing_budget_basket_still_fills_within_limit(self):
        lines = build_basket([product()], 550,
                             selection(required_items=[], fill_budget=True))
        self.assertEqual(lines[0].quantity, 5)

    def test_requested_quantities_must_fit_supplied_budget_and_stock(self):
        with self.assertRaises(ProposalRejected):
            build_basket([product()], 199, selection())
        with self.assertRaises(ProposalRejected):
            build_basket([product(stock=1)], None, selection())

    def test_validator_enforces_stock_exclusions_and_optional_budget(self):
        values = dict(workflow_id=uuid4(), products=[product()],
                      items=[BasketLine(product_id=1, quantity=2)])
        self.assertEqual(validate_basket(BasketValidationRequest(**values)).total_minor, 200)
        self.assertTrue(validate_basket(BasketValidationRequest(**values, budget_minor=200)).valid)
        self.assertFalse(validate_basket(BasketValidationRequest(**values, budget_minor=199)).valid)
        self.assertFalse(validate_basket(BasketValidationRequest(**values, excluded_product_ids=[1])).valid)
        values["items"] = [BasketLine(product_id=1, quantity=21)]
        self.assertFalse(validate_basket(BasketValidationRequest(**values)).valid)

    def test_missing_items_do_not_bypass_unknown_id_or_exclusion_checks(self):
        missing = [UnavailableItem(requested_name="Gowa", reason="not_available")]
        self.assertTrue(selection_errors(selection(eligible_product_ids=[99], unavailable_items=missing), [product()], []))
        self.assertTrue(selection_errors(selection(unavailable_items=missing), [product()], [1]))


class PartialProposalTests(unittest.IsolatedAsyncioTestCase):
    async def test_selection_json_schema_keeps_numeric_ids_and_disables_afc(self):
        import json

        for products in ([product()], []):
            selected = selection() if products else selection(
                eligible_product_ids=[], required_items=[], unavailable_items=[
                    UnavailableItem(requested_name="Apple", reason="not_available")])

            def generate_content(**kwargs):
                config = kwargs["config"]
                self.assertIsNone(config.response_schema)
                self.assertTrue(config.automatic_function_calling.disable)
                self.assertIsInstance(kwargs["contents"], str)
                schema = json.loads(json.dumps(config.response_json_schema))
                self.assertEqual(schema["properties"]["eligible_product_ids"]["items"]["type"], "integer")
                self.assertNotIn("default", schema["properties"]["fixed_list"])
                if products:
                    self.assertNotIn("enum", schema["properties"]["eligible_product_ids"]["items"])
                    self.assertNotIn("enum", schema["$defs"]["RequiredItem"]["properties"]["product_id"])
                    self.assertEqual(schema["$defs"]["RequiredItem"]["properties"]["product_id"]["minimum"], 1)
                else:
                    self.assertEqual(schema["properties"]["eligible_product_ids"]["maxItems"], 0)
                    self.assertEqual(schema["properties"]["required_items"]["maxItems"], 0)
                return SimpleNamespace(text=selected.model_dump_json())

            client = SimpleNamespace(models=SimpleNamespace(generate_content=generate_content))
            actual = await ask_model(client, "CatalogAgent", "Select products",
                                     {"catalog": [p.model_dump() for p in products]}, CatalogSelection)
            self.assertEqual(actual, selected)

    async def test_sdk_sends_json_schema_on_the_wire(self):
        import json
        import httpx
        from google import genai
        from google.genai import types

        selected = selection()
        sent = []

        def respond(request):
            body = json.loads(request.content)
            sent.append(body)
            config = body["generationConfig"]
            self.assertNotIn("responseSchema", config)
            schema = config["responseJsonSchema"]
            self.assertEqual(schema["properties"]["eligible_product_ids"]["items"],
                             {"type": "integer"})
            return httpx.Response(200, json={"candidates": [{
                "content": {"role": "model", "parts": [{"text": selected.model_dump_json()}]},
                "finishReason": "STOP",
            }]})

        with genai.Client(api_key="test-only-not-a-real-key", http_options=types.HttpOptions(
            client_args={"transport": httpx.MockTransport(respond)},
        )) as client:
            actual = await ask_model(client, "CatalogAgent", "Select products",
                                     {"catalog": [product().model_dump()]}, CatalogSelection)
        self.assertEqual(actual, selected)
        self.assertEqual(len(sent), 1)

    async def propose(self, selected, products=None, budget=None):
        request = ProposalRequest(workflow_id=uuid4(), objective="2 kg apples and gowa",
                                  products=[product()] if products is None else products,
                                  budget_minor=budget)
        answers = [BasketPlan(goal="Shopping list", excluded_foods=[], selection_rules=[]),
                   selected, BasketReview(accepted=True, issues=[])]
        if selected.eligible_product_ids:
            answers.append(BasketReview(accepted=True, issues=[]))
        with patch("basket_agents.ask_model", new=AsyncMock(side_effect=answers)):
            return await generate_proposal(request)

    async def test_available_items_survive_missing_item_with_or_without_budget(self):
        for budget in (None, 200):
            with self.subTest(budget=budget):
                result = await self.propose(selection(unavailable_items=[
                    UnavailableItem(requested_name="gowa", reason="not_available")]), budget=budget)
                self.assertEqual(result["status"], "ProposalReady")
                self.assertEqual(result["validation"]["total_minor"], 200)
                self.assertEqual(result["validation"]["items"][0]["quantity"], 2)
                self.assertEqual(result["unavailable_items"], [{"requested_name": "gowa", "reason": "not_available"}])

    async def test_all_missing_has_notices_and_no_orderable_proposal(self):
        result = await self.propose(selection(eligible_product_ids=[], required_items=[], unavailable_items=[
            UnavailableItem(requested_name="apples", reason="not_available"),
            UnavailableItem(requested_name="gowa", reason="not_available")]), products=[])
        self.assertEqual(result["status"], "NoProductsAvailable")
        self.assertEqual(len(result["unavailable_items"]), 2)
        self.assertNotIn("validation", result)
        self.assertNotIn("editing", result)

    async def test_insufficient_stock_notice_does_not_replace_requested_product(self):
        result = await self.propose(selection(unavailable_items=[
            UnavailableItem(requested_name="gowa", reason="insufficient_stock")]))
        self.assertEqual(result["status"], "ProposalReady")
        self.assertEqual(result["unavailable_items"][0]["reason"], "insufficient_stock")
        self.assertEqual([item["product_id"] for item in result["validation"]["items"]], [1])


if __name__ == "__main__":
    unittest.main()
