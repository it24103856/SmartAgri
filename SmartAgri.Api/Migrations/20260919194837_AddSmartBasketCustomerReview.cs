using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSmartBasketCustomerReview : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_SmartBasketWorkflow_Status",
                table: "SmartBasketWorkflows");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SmartBasketWorkflow_Status",
                table: "SmartBasketWorkflows",
                sql: "\"Status\" IN ('Pending', 'Planning', 'Validating', 'AwaitingCustomerReview', 'AwaitingApproval', 'Approved', 'Rejected', 'Failed')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_SmartBasketWorkflow_Status",
                table: "SmartBasketWorkflows");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SmartBasketWorkflow_Status",
                table: "SmartBasketWorkflows",
                sql: "\"Status\" IN ('Pending', 'Planning', 'Validating', 'AwaitingApproval', 'Approved', 'Rejected', 'Failed')");
        }
    }
}
