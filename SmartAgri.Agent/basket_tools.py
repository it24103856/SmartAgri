from schemas import (
    BasketValidationRequest,
    BasketValidationResponse,
    ValidatedLine,
)


def validate_basket(
    request: BasketValidationRequest,
) -> BasketValidationResponse:
    catalog = {
        product.id: product
        for product in request.products
    }

    excluded = set(request.excluded_product_ids)
    seen = set()

    errors: list[str] = []
    validated_items: list[ValidatedLine] = []
    total = 0

    for line in request.items:
        product_id = line.product_id

        if product_id in seen:
            errors.append(
                f"Product {product_id} appears more than once."
            )
            continue

        seen.add(product_id)

        product = catalog.get(product_id)

        if product is None:
            errors.append(
                f"Product {product_id} is not in the supplied catalog."
            )
            continue

        if not product.approved:
            errors.append(
                f"Product {product_id} is not approved."
            )
            continue

        if not product.is_food:
            errors.append(
                f"Product {product_id} is not a food product."
            )
            continue

        if product_id in excluded:
            errors.append(
                f"Product {product_id} was excluded."
            )
            continue

        if line.quantity > product.stock_quantity:
            errors.append(
                f"Product {product_id} has insufficient stock."
            )
            continue

        # Use catalog prices, never a price supplied by the AI.
        line_total = product.unit_price_minor * line.quantity
        total += line_total

        validated_items.append(
            ValidatedLine(
                product_id=product.id,
                product_name=product.name,
                unit=product.unit,
                quantity=line.quantity,
                unit_price_minor=product.unit_price_minor,
                line_total_minor=line_total,
            )
        )

    if total > request.budget_minor:
        errors.append("The proposed basket exceeds the budget.")

    if errors:
        return BasketValidationResponse(
            workflow_id=request.workflow_id,
            valid=False,
            total_minor=None,
            items=[],
            errors=errors,
        )

    return BasketValidationResponse(
        workflow_id=request.workflow_id,
        valid=True,
        total_minor=total,
        items=validated_items,
        errors=[],
    )