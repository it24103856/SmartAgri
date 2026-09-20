from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


PositiveId = Annotated[int, Field(strict=True, gt=0)]
Quantity = Annotated[int, Field(strict=True, gt=0, le=100000)]
MoneyMinor = Annotated[
    int,
    Field(strict=True, gt=0, le=100_000_000_000),
]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CatalogProduct(StrictModel):
    id: PositiveId
    name: str = Field(min_length=1, max_length=150)
    category_id: int | None = Field(default=None, strict=True, gt=0)
    category_name: str | None = Field(default=None, max_length=500)
    unit: str = Field(min_length=1, max_length=20)

    # Money is represented in cents to avoid floating-point rounding.
    unit_price_minor: MoneyMinor
    stock_quantity: int = Field(strict=True, ge=0)

    is_food: bool
    approved: bool


class BasketLine(StrictModel):
    product_id: PositiveId
    quantity: Quantity


class BasketValidationRequest(StrictModel):
    workflow_id: UUID
    budget_minor: MoneyMinor

    currency: str = Field(default="LKR", pattern=r"^LKR$")

    products: list[CatalogProduct] = Field(
        min_length=1,
        max_length=200,
    )

    excluded_product_ids: list[PositiveId] = Field(
        default_factory=list,
        max_length=200,
    )

    items: list[BasketLine] = Field(
        min_length=1,
        max_length=50,
    )

    @model_validator(mode="after")
    def unique_catalog_ids(self):
        ids = [product.id for product in self.products]

        if len(ids) != len(set(ids)):
            raise ValueError("Catalog product IDs must be unique.")

        return self


class ValidatedLine(StrictModel):
    product_id: int
    product_name: str
    unit: str
    quantity: int
    unit_price_minor: int
    line_total_minor: int


class BasketValidationResponse(StrictModel):
    workflow_id: UUID
    valid: bool

    # Null for rejected proposals: never present a partial total as valid.
    total_minor: int | None

    currency: str = "LKR"
    items: list[ValidatedLine]
    errors: list[str]