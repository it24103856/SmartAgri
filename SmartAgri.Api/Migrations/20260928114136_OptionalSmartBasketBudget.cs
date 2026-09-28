using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class OptionalSmartBasketBudget : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_SmartBasketWorkflow_Budget",
                table: "SmartBasketWorkflows");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SmartBasketWorkflow_Total",
                table: "SmartBasketWorkflows");

            migrationBuilder.AlterColumn<decimal>(
                name: "Budget",
                table: "SmartBasketWorkflows",
                type: "numeric(18,2)",
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SmartBasketWorkflow_Budget",
                table: "SmartBasketWorkflows",
                sql: "\"Budget\" IS NULL OR \"Budget\" > 0");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SmartBasketWorkflow_Total",
                table: "SmartBasketWorkflows",
                sql: "\"ProposedTotal\" >= 0 AND (\"Budget\" IS NULL OR \"ProposedTotal\" <= \"Budget\")");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // An absent customer limit cannot be converted to an invented budget.
            // Require an explicit data decision before rolling back these rows.
            migrationBuilder.Sql("""
                DO $$ BEGIN
                    IF EXISTS (SELECT 1 FROM "SmartBasketWorkflows" WHERE "Budget" IS NULL) THEN
                        RAISE EXCEPTION 'Cannot roll back optional budgets while baskets without a budget exist.';
                    END IF;
                END $$;
                """);

            migrationBuilder.DropCheckConstraint(
                name: "CK_SmartBasketWorkflow_Budget",
                table: "SmartBasketWorkflows");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SmartBasketWorkflow_Total",
                table: "SmartBasketWorkflows");

            migrationBuilder.AlterColumn<decimal>(
                name: "Budget",
                table: "SmartBasketWorkflows",
                type: "numeric(18,2)",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)",
                oldNullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "CK_SmartBasketWorkflow_Budget",
                table: "SmartBasketWorkflows",
                sql: "\"Budget\" > 0");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SmartBasketWorkflow_Total",
                table: "SmartBasketWorkflows",
                sql: "\"ProposedTotal\" >= 0 AND \"ProposedTotal\" <= \"Budget\"");
        }
    }
}
