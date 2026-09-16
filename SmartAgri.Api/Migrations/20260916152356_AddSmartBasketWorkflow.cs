using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSmartBasketWorkflow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "SmartBasketWorkflows",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CustomerId = table.Column<int>(type: "integer", nullable: false),
                    RequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Objective = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    Budget = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    Currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    ConstraintsJson = table.Column<string>(type: "jsonb", nullable: false),
                    Status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    PlanJson = table.Column<string>(type: "jsonb", nullable: false),
                    ValidationJson = table.Column<string>(type: "jsonb", nullable: false),
                    ProposedTotal = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    ProposalRevision = table.Column<int>(type: "integer", nullable: false),
                    FailureReason = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    LeaseOwner = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    LeaseExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Version = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SmartBasketWorkflows", x => x.Id);
                    table.CheckConstraint("CK_SmartBasketWorkflow_Budget", "\"Budget\" > 0");
                    table.CheckConstraint("CK_SmartBasketWorkflow_Status", "\"Status\" IN ('Pending', 'Planning', 'Validating', 'AwaitingApproval', 'Approved', 'Rejected', 'Failed')");
                    table.CheckConstraint("CK_SmartBasketWorkflow_Total", "\"ProposedTotal\" >= 0 AND \"ProposedTotal\" <= \"Budget\"");
                    table.ForeignKey(
                        name: "FK_SmartBasketWorkflows_Users_CustomerId",
                        column: x => x.CustomerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SmartBasketApprovals",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    WorkflowId = table.Column<Guid>(type: "uuid", nullable: false),
                    ProposalRevision = table.Column<int>(type: "integer", nullable: false),
                    AdminId = table.Column<int>(type: "integer", nullable: false),
                    Decision = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Note = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SmartBasketApprovals", x => x.Id);
                    table.CheckConstraint("CK_SmartBasketApproval_Decision", "\"Decision\" IN ('Approved', 'Rejected', 'RevisionRequested')");
                    table.CheckConstraint("CK_SmartBasketApproval_Revision", "\"ProposalRevision\" > 0");
                    table.ForeignKey(
                        name: "FK_SmartBasketApprovals_SmartBasketWorkflows_WorkflowId",
                        column: x => x.WorkflowId,
                        principalTable: "SmartBasketWorkflows",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SmartBasketApprovals_Users_AdminId",
                        column: x => x.AdminId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SmartBasketItems",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    WorkflowId = table.Column<Guid>(type: "uuid", nullable: false),
                    ProposalRevision = table.Column<int>(type: "integer", nullable: false),
                    ProductId = table.Column<int>(type: "integer", nullable: false),
                    ProductName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    Unit = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Quantity = table.Column<int>(type: "integer", nullable: false),
                    UnitPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SmartBasketItems", x => x.Id);
                    table.CheckConstraint("CK_SmartBasketItem_Price", "\"UnitPrice\" > 0");
                    table.CheckConstraint("CK_SmartBasketItem_Quantity", "\"Quantity\" > 0");
                    table.CheckConstraint("CK_SmartBasketItem_Revision", "\"ProposalRevision\" > 0");
                    table.ForeignKey(
                        name: "FK_SmartBasketItems_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SmartBasketItems_SmartBasketWorkflows_WorkflowId",
                        column: x => x.WorkflowId,
                        principalTable: "SmartBasketWorkflows",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "SmartBasketSteps",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    WorkflowId = table.Column<Guid>(type: "uuid", nullable: false),
                    Attempt = table.Column<int>(type: "integer", nullable: false),
                    Sequence = table.Column<int>(type: "integer", nullable: false),
                    AgentName = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    ToolName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    InputJson = table.Column<string>(type: "jsonb", nullable: false),
                    OutputJson = table.Column<string>(type: "jsonb", nullable: false),
                    ErrorMessage = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    StartedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    FinishedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SmartBasketSteps", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SmartBasketSteps_SmartBasketWorkflows_WorkflowId",
                        column: x => x.WorkflowId,
                        principalTable: "SmartBasketWorkflows",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_SmartBasketApprovals_AdminId",
                table: "SmartBasketApprovals",
                column: "AdminId");

            migrationBuilder.CreateIndex(
                name: "IX_SmartBasketApprovals_WorkflowId_ProposalRevision",
                table: "SmartBasketApprovals",
                columns: new[] { "WorkflowId", "ProposalRevision" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SmartBasketItems_ProductId",
                table: "SmartBasketItems",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_SmartBasketItems_WorkflowId_ProposalRevision_ProductId",
                table: "SmartBasketItems",
                columns: new[] { "WorkflowId", "ProposalRevision", "ProductId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SmartBasketSteps_WorkflowId_Attempt_Sequence",
                table: "SmartBasketSteps",
                columns: new[] { "WorkflowId", "Attempt", "Sequence" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SmartBasketWorkflows_CustomerId_RequestId",
                table: "SmartBasketWorkflows",
                columns: new[] { "CustomerId", "RequestId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SmartBasketWorkflows_Status_CreatedAt",
                table: "SmartBasketWorkflows",
                columns: new[] { "Status", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SmartBasketApprovals");

            migrationBuilder.DropTable(
                name: "SmartBasketItems");

            migrationBuilder.DropTable(
                name: "SmartBasketSteps");

            migrationBuilder.DropTable(
                name: "SmartBasketWorkflows");
        }
    }
}
