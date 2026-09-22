import unittest
from unittest.mock import AsyncMock, patch
from uuid import uuid4

from basket_agents import (
    BasketPlan,
    BasketReview,
    CatalogSelection,
    ProposalRequest,
    generate_proposal,
)
from schemas import CatalogProduct


class BasketEditingTests(unittest.IsolatedAsyncioTestCase):
    def request(self):
        return ProposalRequest(
            workflow_id=uuid4(),
            objective="Choose food without excluded products.",
            budget_minor=100,
            excluded_product_ids=[4],
            products=[
                CatalogProduct(
                    id=product_id,
                    name=f"Product {product_id}",
                    category_id=1,
                    unit="piece",
                    unit_price_minor=100,
                    stock_quantity=5,
                    is_food=True,
                    approved=True,
                )
                for product_id in range(1, 5)
            ],
        )

    async def test_editing_includes_unselected_eligible_products_and_exclusions(self):
        answers = [
            BasketPlan(goal="Food basket", excluded_foods=[], selection_rules=[]),
            CatalogSelection(
                eligible_product_ids=[1, 2],
                excluded_product_ids=[3],
                required_items=[],
                cover_all_categories=False,
                fill_budget=False,
                issues=[],
            ),
            BasketReview(accepted=True, issues=[]),
            BasketReview(accepted=True, issues=[]),
        ]
        with patch("basket_agents.ask_model", new=AsyncMock(side_effect=answers)):
            result = await generate_proposal(self.request())

        self.assertEqual(result["status"], "ProposalReady")
        self.assertEqual(result["editing"], {
            "allowed_product_ids": [1, 2],
            "excluded_product_ids": [3, 4],
        })
        self.assertEqual(len(result["validation"]["items"]), 1)

    async def test_failed_response_has_no_editing_choices(self):
        request = self.request()
        request.excluded_product_ids = [1, 2, 3, 4]
        with patch("basket_agents.ask_model", new=AsyncMock()) as model:
            result = await generate_proposal(request)

        self.assertEqual(result["status"], "Failed")
        self.assertNotIn("editing", result)
        model.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
