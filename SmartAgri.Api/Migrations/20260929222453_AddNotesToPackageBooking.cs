using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddNotesToPackageBooking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "FarmId",
                table: "PackageBookings",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FarmLocation",
                table: "PackageBookings",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FarmName",
                table: "PackageBookings",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "ServiceDate",
                table: "PackageBookings",
                type: "date",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_PackageBookings_FarmId",
                table: "PackageBookings",
                column: "FarmId");

            migrationBuilder.CreateIndex(
                name: "IX_PackageBookings_ServiceDate",
                table: "PackageBookings",
                column: "ServiceDate");

            migrationBuilder.AddForeignKey(
                name: "FK_PackageBookings_Farms_FarmId",
                table: "PackageBookings",
                column: "FarmId",
                principalTable: "Farms",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PackageBookings_Farms_FarmId",
                table: "PackageBookings");

            migrationBuilder.DropIndex(
                name: "IX_PackageBookings_FarmId",
                table: "PackageBookings");

            migrationBuilder.DropIndex(
                name: "IX_PackageBookings_ServiceDate",
                table: "PackageBookings");

            migrationBuilder.DropColumn(
                name: "FarmId",
                table: "PackageBookings");

            migrationBuilder.DropColumn(
                name: "FarmLocation",
                table: "PackageBookings");

            migrationBuilder.DropColumn(
                name: "FarmName",
                table: "PackageBookings");

            migrationBuilder.DropColumn(
                name: "ServiceDate",
                table: "PackageBookings");
        }
    }
}
