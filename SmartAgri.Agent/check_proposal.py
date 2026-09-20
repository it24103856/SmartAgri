import json
import os
from pathlib import Path
from uuid import uuid4

import httpx
from dotenv import load_dotenv

load_dotenv(Path(__file__).with_name(".env"))

payload = {
    "workflow_id": str(uuid4()),
    "objective": "Suggest a vegetable basket. Do not include pumpkin.",
    "budget_minor": 300000,
    "currency": "LKR",
    "excluded_product_ids": [],
    "products": [
        {
            "id": 101,
            "name": "Carrot",
            "unit": "kg",
            "unit_price_minor": 25000,
            "stock_quantity": 10,
            "is_food": True,
            "approved": True,
        },
        {
            "id": 102,
            "name": "Pumpkin",
            "unit": "kg",
            "unit_price_minor": 20000,
            "stock_quantity": 10,
            "is_food": True,
            "approved": True,
        },
        {
            "id": 103,
            "name": "Cabbage",
            "unit": "kg",
            "unit_price_minor": 30000,
            "stock_quantity": 10,
            "is_food": True,
            "approved": True,
        },
    ],
}

with httpx.Client(timeout=370, trust_env=False) as client:
    response = client.post(
        "http://127.0.0.1:8001/internal/propose-basket",
        headers={"X-Agent-Key": os.environ["AGENT_INTERNAL_KEY"]},
        json=payload,
    )
print("HTTP status:", response.status_code)
print("Response:", response.text)
response.raise_for_status()
result = response.json()

print(json.dumps(result, indent=2, ensure_ascii=False))

assert result["status"] == "ProposalReady", result.get("errors")

validation = result["validation"]
assert validation["valid"] is True
assert 0 < validation["total_minor"] <= payload["budget_minor"]
assert validation["items"]
assert all(item["product_id"] != 102 for item in validation["items"])

print("PASS: reviewed proposal is within budget and excludes pumpkin.")