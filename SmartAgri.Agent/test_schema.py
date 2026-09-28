import json
from pydantic import BaseModel, ConfigDict, Field
from typing import Annotated

PositiveId = Annotated[int, Field(strict=True, gt=0)]
Quantity = Annotated[int, Field(strict=True, gt=0, le=100000)]

class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

class RequiredItem(StrictModel):
    product_id: PositiveId
    quantity: Quantity
    exact_quantity: bool

class UnavailableItem(StrictModel):
    requested_name: str
    reason: str

class CatalogSelection(StrictModel):
    eligible_product_ids: list[PositiveId] = Field(max_length=50)
    excluded_product_ids: list[PositiveId] = Field(max_length=50)
    required_items: list[RequiredItem] = Field(max_length=50)
    unavailable_items: list[UnavailableItem] = Field(max_length=50)
    cover_all_categories: bool
    fill_budget: bool
    fixed_list: bool
    issues: list[str] = Field(max_length=10)

schema = CatalogSelection.model_json_schema()

def resolve_refs(value, defs):
    if isinstance(value, dict):
        if "$ref" in value:
            ref_name = value["$ref"].split("/")[-1]
            resolved = defs[ref_name].copy()
            value.clear()
            value.update(resolved)
            resolve_refs(value, defs)
        else:
            for k, v in list(value.items()):
                if k in ("default", "title", "minLength", "maxLength", "additionalProperties"):
                    value.pop(k, None)
                elif k == "exclusiveMinimum" and value.get("type") == "integer":
                    value["minimum"] = value.pop("exclusiveMinimum") + 1
                elif k == "exclusiveMaximum" and value.get("type") == "integer":
                    value["maximum"] = value.pop("exclusiveMaximum") - 1
                else:
                    resolve_refs(v, defs)
    elif isinstance(value, list):
        for item in value:
            resolve_refs(item, defs)

defs = schema.pop("$defs", {})
resolve_refs(schema, defs)

print(json.dumps(schema, indent=2))
