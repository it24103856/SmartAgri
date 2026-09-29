using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartAgri.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddPackageImages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ImageUrlsJson",
                table: "Packages",
                type: "text",
                nullable: false,
                defaultValue: "[]");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ImageUrlsJson",
                table: "Packages");
        }
    }
}
