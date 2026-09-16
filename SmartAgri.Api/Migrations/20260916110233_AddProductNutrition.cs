using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddProductNutrition : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsFood",
                table: "Products",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "NutritionBasis",
                table: "Products",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NutritionFacts",
                table: "Products",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NutritionSourceName",
                table: "Products",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NutritionSourceUrl",
                table: "Products",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsFood",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "NutritionBasis",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "NutritionFacts",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "NutritionSourceName",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "NutritionSourceUrl",
                table: "Products");
        }
    }
}
