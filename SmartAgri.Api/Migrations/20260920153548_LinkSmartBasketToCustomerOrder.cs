using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class LinkSmartBasketToCustomerOrder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_SmartBasketWorkflow_Status",
                table: "SmartBasketWorkflows");

            migrationBuilder.AddColumn<int>(
                name: "SmartBasketRevision",
                table: "CustomerOrders",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "SmartBasketWorkflowId",
                table: "CustomerOrders",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "CK_SmartBasketWorkflow_Status",
                table: "SmartBasketWorkflows",
                sql: "\"Status\" IN ('Pending', 'Planning', 'Validating', 'AwaitingCustomerReview', 'AwaitingApproval', 'Approved', 'Rejected', 'Failed', 'Ordered')");

            migrationBuilder.CreateIndex(
                name: "IX_CustomerOrders_SmartBasketWorkflowId",
                table: "CustomerOrders",
                column: "SmartBasketWorkflowId",
                unique: true);

            migrationBuilder.AddCheckConstraint(
                name: "CK_CustomerOrder_SmartBasketLink",
                table: "CustomerOrders",
                sql: "(\"SmartBasketWorkflowId\" IS NULL AND \"SmartBasketRevision\" IS NULL) OR (\"SmartBasketWorkflowId\" IS NOT NULL AND \"SmartBasketRevision\" IS NOT NULL AND \"SmartBasketRevision\" > 0)");

            migrationBuilder.AddForeignKey(
                name: "FK_CustomerOrders_SmartBasketWorkflows_SmartBasketWorkflowId",
                table: "CustomerOrders",
                column: "SmartBasketWorkflowId",
                principalTable: "SmartBasketWorkflows",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CustomerOrders_SmartBasketWorkflows_SmartBasketWorkflowId",
                table: "CustomerOrders");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SmartBasketWorkflow_Status",
                table: "SmartBasketWorkflows");

            migrationBuilder.DropIndex(
                name: "IX_CustomerOrders_SmartBasketWorkflowId",
                table: "CustomerOrders");

            migrationBuilder.DropCheckConstraint(
                name: "CK_CustomerOrder_SmartBasketLink",
                table: "CustomerOrders");

            migrationBuilder.DropColumn(
                name: "SmartBasketRevision",
                table: "CustomerOrders");

            migrationBuilder.DropColumn(
                name: "SmartBasketWorkflowId",
                table: "CustomerOrders");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SmartBasketWorkflow_Status",
                table: "SmartBasketWorkflows",
                sql: "\"Status\" IN ('Pending', 'Planning', 'Validating', 'AwaitingCustomerReview', 'AwaitingApproval', 'Approved', 'Rejected', 'Failed')");
        }
    }
}
