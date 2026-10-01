# Farmer approval notifications and product sales

The farmer dashboard links to Approval notifications and My product sales.
Product approval and rejection save a notification in the same transaction as
the review. Notifications retain the decision after a product is edited and
resubmitted. These are in-app notifications, loaded on opening or refreshing
the screen.

Apply the `AddFarmerNotifications` migration before running the updated API:

```powershell
dotnet ef database update --project SmartAgri.Api
```

Restart the API and rebuild the Flutter client after applying the migration.
Existing reviews are not backfilled.

All endpoints require an active FARMER account and use the authenticated user:

- `GET /api/farmer-reports/notifications?page=1`: 30 notifications per page,
  total count, and unread count.
- `PUT /api/farmer-reports/notifications/{id}/read`: marks an owned notification
  read; repeated requests preserve the original read time.
- `GET /api/farmer-reports/sales?range=This%20Month`: accepts This Week,
  This Month, Last 6 Months, or This Year, using Asia/Colombo boundaries.

Sales include owned farmer product lines in paid, non-cancelled orders, using
payment dates and checkout unit prices. Unpaid and chargeback payments are
excluded. Product totals include quantity, order count, and sales value.
Delivery fees, farmer payouts, and profit are outside this report. The client
can copy the report as CSV.

Verification: `flutter test test/farmer_reports_test.dart` in agriculture_flutter;
backend integration tests require SMARTAGRI_TEST_CONNECTION pointing to a
local PostgreSQL server with permission to create a temporary test database:

```powershell
dotnet test SmartAgri.Api.Tests --filter FullyQualifiedName~FarmerReportsTests
```
