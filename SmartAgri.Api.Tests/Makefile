RUNNER = node test/runner.mjs
PROJECT = SmartAgri.Api.Tests.csproj

MEMBER1_FILTER = FullyQualifiedName~ProductAvailabilityTests|FullyQualifiedName~SmartBasketCategoryScopeTests
MEMBER2_FILTER = FullyQualifiedName~CheckoutPriceChangeTests|FullyQualifiedName~CheckoutIdempotencyTests|FullyQualifiedName~CheckoutConcurrencyTests|FullyQualifiedName~CustomerOrderAccessTests|FullyQualifiedName~FarmerPurchaseTests
MEMBER3_FILTER = FullyQualifiedName~FarmAiCatalogTests|FullyQualifiedName~FarmerReportsTests
MEMBER4_FILTER = FullyQualifiedName~PackageImagesTests|FullyQualifiedName~OrderReceiptStorageTests|FullyQualifiedName~SmartBasketOptionalBudgetTests|FullyQualifiedName~SalesAnalyticsTests

.PHONY: help test-member1 test-member2 test-member3 test-member4 test-backend

help:
	@echo "make test-member1  Category and Product Management"
	@echo "make test-member2  Cart and Order Management"
	@echo "make test-member3  Farm and Crop Support"
	@echo "make test-member4  Package and Service Management"
	@echo "make test-backend  All backend tests"

test-member1:
	$(RUNNER) --title "Member 1" --subtitle "Category and Product Management" --project "$(PROJECT)" --filter "$(MEMBER1_FILTER)"

test-member2:
	$(RUNNER) --title "Member 2" --subtitle "Cart and Order Management" --project "$(PROJECT)" --filter "$(MEMBER2_FILTER)"

test-member3:
	$(RUNNER) --title "Member 3" --subtitle "Farm and Crop Support" --project "$(PROJECT)" --filter "$(MEMBER3_FILTER)"

test-member4:
	$(RUNNER) --title "Member 4" --subtitle "Package and Service Management" --project "$(PROJECT)" --filter "$(MEMBER4_FILTER)"

test-backend:
	$(RUNNER) --title "All Backend Tests" --subtitle "Category, Cart, Farm and Package services" --project "$(PROJECT)"
