import asyncio
import json
from dotenv import load_dotenv
load_dotenv()
from basket_agents import generate_proposal, ProposalRequest, CatalogProduct

async def main():
    catalog = [
        CatalogProduct(id=1, name="Tomatoes", category_id=2, category_name="Vegetables", unit="pack", unit_price_minor=50000, stock_quantity=6, is_food=True, approved=True),
        CatalogProduct(id=3, name="Mozzarella cheese", category_id=5, category_name="Cheese", unit="piece", unit_price_minor=100000, stock_quantity=1, is_food=True, approved=True),
        CatalogProduct(id=4, name="Apple", category_id=3, category_name="Fruits", unit="pack", unit_price_minor=50000, stock_quantity=3, is_food=True, approved=True),
        CatalogProduct(id=5, name="Orange", category_id=3, category_name="Fruits", unit="piece", unit_price_minor=5000, stock_quantity=1, is_food=True, approved=True),
    ]

    req = ProposalRequest(
        workflow_id="00000000-0000-0000-0000-000000000000",
        objective="apple, orange",
        budget_minor=None,
        currency="LKR",
        products=catalog,
        excluded_product_ids=[]
    )

    result = await generate_proposal(req)
    with open("out.txt", "w") as f:
        f.write(json.dumps(result, indent=2))

if __name__ == "__main__":
    asyncio.run(main())
