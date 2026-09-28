import json
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch
from uuid import uuid4

from google.genai import errors

from basket_agents import (
    BasketPlan, BasketReview, CatalogSelection, FALLBACK_LIST_REQUIRED,
    ProposalRejected, ProposalRequest, ask_model, generate_proposal,
    local_fallback,
)
from basket_tools import validate_basket
from schemas import BasketValidationRequest, CatalogProduct


def product(product_id=1, name="Apple", price=100, unit="piece", stock=5, **kwargs):
    return CatalogProduct(id=product_id, name=name, category_id=1, unit=unit,
                          unit_price_minor=price, stock_quantity=stock,
                          is_food=True, approved=True, **kwargs)


def payload(objective="Apple", products=None, **extra):
    return dict(objective=objective, budget_minor=None,
                catalog=[p.model_dump() for p in (products if products is not None else [product()])],
                **extra)


class LocalFallbackTests(unittest.TestCase):
    def test_extra_separators_do_not_reject_a_valid_list(self):
        products = [product(), product(2, "Orrange")]
        for objective in ("apple ,orrange,", ", apple,, ; orrange ; ",
                          "apple\n\norrange\n", "apple and orrange,"):
            with self.subTest(objective=objective):
                result = local_fallback(payload(objective, products), CatalogSelection)
                self.assertEqual(result.eligible_product_ids, [1, 2])
                self.assertEqual(result.unavailable_items, [])

    def test_empty_list_is_still_rejected(self):
        for objective in ("", " , ; \n , ", "I want ,,,"):
            with self.subTest(objective=objective), self.assertRaises(ProposalRejected):
                local_fallback(payload(objective), CatalogSelection)

    def test_logged_shopping_list_uses_catalog_ids_and_reports_cabbage(self):
        products = [product(1, "Tommatos", 50000, "pack"),
                    product(5, "Orrange", 5000), product(6, "Amand", 30000)]
        result = local_fallback(payload("I want amand ,gowa ,tomatto.orrange", products), CatalogSelection)
        self.assertTrue(result._used_fallback)
        self.assertEqual(result.eligible_product_ids, [6, 1, 5])
        self.assertEqual([i.quantity for i in result.required_items], [1, 1, 1])
        self.assertEqual(result.unavailable_items[0].requested_name, "gowa")
        self.assertNotIn("_used_fallback", result.model_dump())

    def test_explicit_selling_units_and_insufficient_stock(self):
        result = local_fallback(payload("2 kg rice, 7 apples", [product(1, "Rice", unit="kg"), product(2)]), CatalogSelection)
        self.assertEqual(result.required_items[0].quantity, 2)
        self.assertEqual(result.unavailable_items[0].reason, "insufficient_stock")

    def test_ambiguous_constraints_or_quantities_never_become_success(self):
        for objective in ("apple without nuts", "apple, don't include apple", "mixed basket",
                          "apple, vegan", "1.5 kg apple", "2 kg", "apple, apples", "0 apples"):
            with self.subTest(objective=objective), self.assertRaises(ProposalRejected):
                local_fallback(payload(objective), CatalogSelection)

    def test_does_not_guess_weight_to_pack_or_multiple_catalog_matches(self):
        for request in (payload("2 kg apples", [product(unit="pack")]),
                        payload("2 apples", [product(unit="kg")]),
                        payload("apple", [product(), product(2)])):
            with self.assertRaises(ProposalRejected):
                local_fallback(request, CatalogSelection)

    def test_explicit_exclusions_and_unapproved_products_are_not_selected(self):
        with self.assertRaises(ProposalRejected):
            local_fallback(payload(explicit_excluded_product_ids=[1]), CatalogSelection)
        unavailable = product().model_copy(update={"approved": False})
        result = local_fallback(payload(products=[unavailable]), CatalogSelection)
        self.assertEqual(result.eligible_product_ids, [])
        self.assertEqual(result.unavailable_items[0].reason, "not_available")

    def test_local_review_recomputes_selection_and_does_not_auto_accept(self):
        request = payload()
        selected = local_fallback(request, CatalogSelection)
        request["selection"] = selected.model_dump()
        request["selection"]["required_items"][0]["quantity"] = 4
        review = local_fallback(request, BasketReview)
        self.assertFalse(review.accepted)
        self.assertTrue(review.issues)

    def test_local_review_rejects_wrong_prices_and_over_budget_total(self):
        request = payload()
        selected = local_fallback(request, CatalogSelection)
        request["selection"] = selected.model_dump()
        basket = validate_basket(BasketValidationRequest(
            workflow_id=uuid4(), products=request["catalog"],
            items=[{"product_id": 1, "quantity": 1}],
        )).model_dump(mode="json")
        request["basket"] = basket
        self.assertTrue(local_fallback(request, BasketReview).accepted)
        basket["items"][0]["unit_price_minor"] = 1
        self.assertFalse(local_fallback(request, BasketReview).accepted)
        basket["items"][0]["unit_price_minor"] = 100
        request["budget_minor"] = 99
        self.assertFalse(local_fallback(request, BasketReview).accepted)


class ProviderFallbackTests(unittest.IsolatedAsyncioTestCase):
    async def test_reported_trailing_comma_request_succeeds_after_503(self):
        request = ProposalRequest(workflow_id=uuid4(), objective="apple ,orrange,",
                                  budget_minor=100000,
                                  products=[product(4, "Apple", 50000, "pack", 3),
                                            product(5, "Orrange", 5000, "piece", 1)])
        generate = Mock(side_effect=errors.ServerError(503, {"error": {"message": "busy"}}))
        client = SimpleNamespace(models=SimpleNamespace(generate_content=generate), close=Mock())
        with patch.dict("os.environ", {"GEMINI_API_KEY": "test-only"}), \
             patch("basket_agents.genai.Client", return_value=client), \
             patch("basket_agents.asyncio.sleep", new_callable=AsyncMock):
            result = await generate_proposal(request)
        self.assertEqual(result["status"], "ProposalReady")
        self.assertEqual(result["generation_mode"], "catalog_fallback")
        self.assertEqual(result["validation"]["total_minor"], 55000)
        self.assertEqual([line["product_id"] for line in result["validation"]["items"]], [4, 5])
        self.assertEqual(result["unavailable_items"], [])
        self.assertEqual(generate.call_count, 3)

    async def test_503_exhausts_three_attempts_then_returns_local_plan(self):
        generate = Mock(side_effect=errors.ServerError(503, {"error": {"message": "busy"}}))
        client = SimpleNamespace(models=SimpleNamespace(generate_content=generate))
        with patch("basket_agents.asyncio.sleep", new_callable=AsyncMock) as sleep:
            result = await ask_model(client, "Planner", "Plan", payload(), BasketPlan)
        self.assertIsInstance(result, BasketPlan)
        self.assertTrue(result._used_fallback)
        self.assertEqual(generate.call_count, 3)
        self.assertEqual([call.args for call in sleep.await_args_list], [(15,), (30,)])

    async def test_actual_provider_message_is_logged_before_fallback(self):
        generate = Mock(side_effect=errors.ClientError(400, {
            "error": {"message": "Invalid response schema field"},
        }))
        client = SimpleNamespace(models=SimpleNamespace(generate_content=generate))
        with patch.dict("os.environ", {"GEMINI_MODEL": "test-model"}), \
             self.assertLogs("uvicorn.error", level="ERROR") as logs:
            result = await ask_model(client, "CatalogAgent", "Select", payload(), CatalogSelection)
        self.assertTrue(result._used_fallback)
        self.assertEqual(generate.call_count, 1)
        self.assertIn("agent=CatalogAgent | model=test-model", logs.output[0])
        self.assertIn("attempt=1/3 | code=400 | message=Invalid response schema field", logs.output[0])

    async def test_bad_request_falls_back_without_retry_but_programming_errors_do_not(self):
        generate = Mock(side_effect=errors.ClientError(400, {"error": {"message": "invalid"}}))
        client = SimpleNamespace(models=SimpleNamespace(generate_content=generate))
        with patch("basket_agents.asyncio.sleep", new_callable=AsyncMock) as sleep:
            result = await ask_model(client, "CatalogAgent", "Select", payload(), CatalogSelection)
            sleep.assert_not_awaited()
        self.assertTrue(result._used_fallback)
        generate.side_effect = RuntimeError("programming bug")
        with self.assertRaises(RuntimeError):
            await ask_model(client, "CatalogAgent", "Select", payload(), CatalogSelection)

    async def test_invalid_model_output_is_not_trusted(self):
        client = SimpleNamespace(models=SimpleNamespace(generate_content=Mock(
            return_value=SimpleNamespace(text="not JSON"))))
        result = await ask_model(client, "CatalogAgent", "Select", payload(), CatalogSelection)
        self.assertEqual(result.eligible_product_ids, [1])
        self.assertTrue(result._used_fallback)

    async def run_proposal(self, objective="apple, gowa", budget=None, fail_at=0):
        request = ProposalRequest(workflow_id=uuid4(), objective=objective,
                                  budget_minor=budget, products=[product()])
        plan = BasketPlan(goal="Shopping list", excluded_foods=[], selection_rules=[])
        selected = local_fallback(payload(objective), CatalogSelection)
        good_responses = [plan, selected, BasketReview(accepted=True, issues=[])]
        responses = [SimpleNamespace(text=r.model_dump_json()) for r in good_responses[:fail_at]]
        responses.append(errors.ClientError(400, {"error": {"message": "invalid"}}))
        generate = Mock(side_effect=responses)
        client = SimpleNamespace(models=SimpleNamespace(generate_content=generate), close=Mock())
        with patch.dict("os.environ", {"GEMINI_API_KEY": "test-only"}), patch("basket_agents.genai.Client", return_value=client):
            result = await generate_proposal(request)
        self.assertEqual(generate.call_count, fail_at + 1)
        return result

    async def test_failure_at_any_model_stage_preserves_a_valid_partial_basket(self):
        for stage in range(4):
            with self.subTest(stage=stage):
                result = await self.run_proposal(fail_at=stage)
                self.assertEqual(result["status"], "ProposalReady")
                self.assertEqual(result["generation_mode"], "catalog_fallback")
                self.assertEqual(result["validation"]["total_minor"], 100)
                self.assertEqual(result["unavailable_items"][0]["requested_name"], "gowa")
                self.assertTrue(any(step.get("source") == "LocalCatalog" for step in result["steps"]))

    async def test_fallback_still_enforces_budget(self):
        result = await self.run_proposal(budget=99)
        self.assertEqual(result["status"], "Failed")
        self.assertNotIn("validation", result)

    async def test_all_missing_has_no_orderable_items(self):
        result = await self.run_proposal(objective="gowa")
        self.assertEqual(result["status"], "NoProductsAvailable")
        self.assertEqual(result["generation_mode"], "catalog_fallback")
        self.assertNotIn("validation", result)

    async def test_complex_request_gets_honest_failure_without_fabricated_data(self):
        with patch.dict("os.environ", {"GEMINI_API_KEY": "", "GOOGLE_API_KEY": ""}):
            result = await generate_proposal(ProposalRequest(workflow_id=uuid4(),
                objective="mixed basket without nuts", products=[product()]))
        self.assertEqual(result["status"], "Failed")
        self.assertEqual(result["errors"], [FALLBACK_LIST_REQUIRED])
        self.assertNotIn("validation", result)


if __name__ == "__main__":
    unittest.main()
