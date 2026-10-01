using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddPackagePaymentProofs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "AdvanceAmount",
                table: "PackageBookings",
                type: "numeric(12,2)",
                precision: 12,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "AmountPaid",
                table: "PackageBookings",
                type: "numeric(12,2)",
                precision: 12,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "PaymentStatus",
                table: "PackageBookings",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "NOT_REQUIRED");

            migrationBuilder.AddColumn<bool>(
                name: "RequiresAdvancePayment",
                table: "PackageBookings",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "PackagePaymentProofs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    BookingId = table.Column<int>(type: "integer", nullable: false),
                    Stage = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    TransferReference = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ReceiptFileName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    AdminNote = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ReviewedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ReviewedById = table.Column<int>(type: "integer", nullable: true),
                    Version = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PackagePaymentProofs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PackagePaymentProofs_PackageBookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "PackageBookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PackagePaymentProofs_Users_ReviewedById",
                        column: x => x.ReviewedById,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PackagePaymentProofs_BookingId_Stage",
                table: "PackagePaymentProofs",
                columns: new[] { "BookingId", "Stage" },
                unique: true,
                filter: "\"Status\" IN ('SUBMITTED', 'APPROVED')");

            migrationBuilder.CreateIndex(
                name: "IX_PackagePaymentProofs_ReviewedById",
                table: "PackagePaymentProofs",
                column: "ReviewedById");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PackagePaymentProofs");

            migrationBuilder.DropColumn(
                name: "AdvanceAmount",
                table: "PackageBookings");

            migrationBuilder.DropColumn(
                name: "AmountPaid",
                table: "PackageBookings");

            migrationBuilder.DropColumn(
                name: "PaymentStatus",
                table: "PackageBookings");

            migrationBuilder.DropColumn(
                name: "RequiresAdvancePayment",
                table: "PackageBookings");
        }
    }
}
