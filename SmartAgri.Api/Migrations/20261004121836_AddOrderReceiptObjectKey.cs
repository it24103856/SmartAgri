using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddOrderReceiptObjectKey : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ReceiptObjectKey",
                table: "OrderPaymentProofs",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ReceiptObjectKey",
                table: "OrderPaymentProofs");
        }
    }
}
