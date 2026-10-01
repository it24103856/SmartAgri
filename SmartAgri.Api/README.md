# SmartAgri API

This project contains the backend API structure for the SmartAgri platform.

## Farmer product purchases

Farmers use the same cart, checkout, order history and tracking endpoints as
customers. In the Flutter app, open Marketplace, choose a product, and use
Buy Now or Add to Cart. The farmer dashboard and marketplace link to My
Purchases, which lists the signed-in buyer's latest 50 orders and their items.

Farmer checkout supports cash on delivery, PayHere, and bank transfer. Bank
transfer orders wait for receipt verification in the admin Orders page. A
rejected receipt can be resubmitted. Approval marks payment as paid and deducts
stock once; if stock is no longer available, the order enters PaymentReview
for admin resolution. Order tracking refreshes the receipt status as well.

Apply migrations through `20260930193323_AddOrderPaymentProofs`. Configure
`OrderBankTransfer:BankName`, `AccountName`, `AccountNumber`, and `Branch` in
local configuration or environment variables. Missing order bank values fall
back to the corresponding `PackageBankTransfer` settings. Bank checkout is
unavailable until the required bank details are configured.

`SmartAgri.Api.Tests/FarmerPurchaseTests.cs` checks ownership, bank receipt
review, stock and purchase history using an isolated temporary database;
set `SMARTAGRI_TEST_CONNECTION` to a local PostgreSQL server connection before
running it. Flutter regression coverage is in `test/farmer_purchase_test.dart`.

## Structure

- Controllers
- Models
- Services
- Interfaces
- Data
- AI
- DTOs
- Middleware

## Notes

The project is scaffolded and ready for further business logic implementation.

## Smart Basket shopping lists and optional budgets

`POST /api/customer-smart-baskets` accepts `budget: null` (or an omitted
budget) for a shopping list without a customer spending limit. A supplied
budget still accepts only LKR 1–1,000,000 with at most two decimal places.
Fixed shopping lists use requested quantities, or one selling unit where no
quantity is given. Budget-based mixed baskets continue to use the spending
limit. Baskets without a limit never fill the remaining stock automatically.

The agent returns available products and `unavailable_items` notices separately.
Customer and admin detail responses expose these as `unavailableItems` with
`requestedName` and `reason` (`not_available` or `insufficient_stock`). Notices
describe availability when the proposal was generated, within the selected
category. They survive customer edits. A partial basket still requires customer
review and admin approval; an entirely unavailable list has no orderable items.
Price, stock, exclusion, approval and checkout checks still apply.

Before running the updated API, apply the migration using the configured
development database connection. From `SmartAgri.Api` in PowerShell:

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
dotnet ef database update 20260928114136_OptionalSmartBasketBudget
```

Restart the updated Python agent, then the API, and hot restart the Flutter app.
Both services must be updated because the agent now accepts a null budget.
The migration preserves existing budgets and makes the database column nullable.
Rollback refuses to invent budgets for existing rows with no limit.

Checks:

```powershell
# In SmartAgri.Agent
$env:PYTHONUTF8 = "1"
.\.venv\Scripts\python.exe -m unittest discover -v

# From the repository root
dotnet test SmartAgri.Api.Tests

# In agriculture_flutter
flutter test test/smart_basket_optional_budget_test.dart
```

The API database integration tests require `SMARTAGRI_TEST_DB_PASSWORD` and
optionally `SMARTAGRI_TEST_DB_USER`; they create isolated temporary databases.
Agent tests mock model responses and do not call the paid Gemini API.

## Catalog fallback when Gemini is unavailable

After three transient-error attempts (15 and 30 seconds between attempts), the agent
can handle simple shopping lists using the supplied catalog. Provider request
errors and malformed model outputs also use this path, with a warning in the
agent log. Once a request switches to fallback, subsequent steps stay local.
Programming errors are not treated as provider failures.

The fallback supports exact catalog names and a small explicit set of spelling
aliases, including the sample `amand, gowa, tomatto, orrange`. It uses real
catalog IDs, prices, stock and units. Missing products are reported separately.
Whole-number quantities with explicit matching selling units are supported;
weights are never converted to packs. Duplicate/ambiguous names, exclusions
written in free text, mixed-basket goals and complex requirements receive an
honest retry/simplify-list message instead of a fabricated proposal. Budget,
validation, customer review and admin approval still apply.

Detail responses expose `generationMode: "catalog_fallback"` and the UI displays
that the basket was prepared directly from the shopping list. This metadata is
stored in existing constraints JSON; it needs no additional database migration.
