import os
from pathlib import Path

import httpx
from dotenv import load_dotenv


load_dotenv(Path(__file__).with_name(".env"))

key = os.environ["AGENT_INTERNAL_KEY"]

# Synthetic test data only. These are not real database products.
payload = {
    "workflow_id": "34342df3-777c-4261-b2a7-4518e328b899",
    "budget_minor": 300000,
    "currency": "LKR",
    "products": [
        {
            "id": 101,
            "name": "Test carrots",
            "unit": "kg",
            "unit_price_minor": 25000,
            "stock_quantity": 10,
            "is_food": True,
            "approved": True,
        },
        {
            "id": 102,
            "name": "Test pumpkin",
            "unit": "kg",
            "unit_price_minor": 20000,
            "stock_quantity": 10,
            "is_food": True,
            "approved": True,
        },
    ],
    "excluded_product_ids": [102],
    "items": [
        {
            "product_id": 101,
            "quantity": 2,
        }
    ],
}

with httpx.Client(
    base_url="http://127.0.0.1:8001",
    timeout=10,
    trust_env=False,
) as client:
    # Missing service key must be rejected.
    unauthorized = client.post(
        "/internal/validate-basket",
        json=payload,
    )
    assert unauthorized.status_code == 401
    print("PASS: request without key rejected")

    headers = {"X-Agent-Key": key}

    response = client.post(
        "/internal/validate-basket",
        json=payload,
        headers=headers,
    )
    response.raise_for_status()

    result = response.json()
    assert result["valid"] is True
    assert result["total_minor"] == 50000
    print("PASS: valid basket total is Rs. 500")

    # An excluded product must invalidate the proposal.
    payload["items"] = [
        {"product_id": 102, "quantity": 1}
    ]

    response = client.post(
        "/internal/validate-basket",
        json=payload,
        headers=headers,
    )
    response.raise_for_status()

    result = response.json()
    assert result["valid"] is False
    assert result["items"] == []
    assert result["total_minor"] is None
    assert any("excluded" in error for error in result["errors"])
    print("PASS: excluded pumpkin rejected")

    # A valid product can still exceed the budget.
    payload["items"] = [
        {"product_id": 101, "quantity": 2}
    ]
    payload["budget_minor"] = 40000

    response = client.post(
        "/internal/validate-basket",
        json=payload,
        headers=headers,
    )
    response.raise_for_status()

    result = response.json()
    assert result["valid"] is False
    assert "The proposed basket exceeds the budget." in result["errors"]
    print("PASS: over-budget basket rejected")