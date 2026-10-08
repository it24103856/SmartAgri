using Npgsql;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;

namespace SmartAgri.Api.Tests;

internal sealed class SupabaseTestDatabase : IAsyncDisposable
{
    private readonly NpgsqlConnection _adminConnection;

    private SupabaseTestDatabase(
        NpgsqlConnection adminConnection,
        string connectionString,
        string schema)
    {
        _adminConnection = adminConnection;
        ConnectionString = connectionString;
        Schema = schema;
    }

    public string ConnectionString { get; }
    public string Schema { get; }

    public async Task InitializeAsync(ApplicationDbContext db)
    {
        await db.Database.OpenConnectionAsync();
        try
        {
            await using var command = db.Database.GetDbConnection().CreateCommand();
            command.CommandText = $"SET search_path TO \"{Schema}\"";
            await command.ExecuteNonQueryAsync();
            command.CommandText = db.Database.GenerateCreateScript();
            await command.ExecuteNonQueryAsync();
        }
        finally
        {
            await db.Database.CloseConnectionAsync();
        }
    }

    public static async Task<SupabaseTestDatabase> CreateAsync()
    {
        var raw = Environment.GetEnvironmentVariable("SMARTAGRI_TEST_CONNECTION");
        if (string.IsNullOrWhiteSpace(raw))
        {
            throw new InvalidOperationException(
                "Set SMARTAGRI_TEST_CONNECTION to the Supabase test database.");
        }

        var schema = $"test_{Guid.NewGuid():N}";
        var builder = new NpgsqlConnectionStringBuilder(raw)
        {
            Pooling = false,
            Timeout = 15,
            CommandTimeout = 60
        };
        builder.Remove("Search Path");

        var admin = new NpgsqlConnection(builder.ConnectionString);
        await admin.OpenAsync();
        await using (var command = admin.CreateCommand())
        {
            command.CommandText = $"CREATE SCHEMA \"{schema}\"";
            await command.ExecuteNonQueryAsync();
        }

        builder["Search Path"] = $"\"{schema}\"";
        return new SupabaseTestDatabase(admin, builder.ConnectionString, schema);
    }

    public async ValueTask DisposeAsync()
    {
        await using var command = _adminConnection.CreateCommand();
        command.CommandText = $"DROP SCHEMA IF EXISTS \"{Schema}\" CASCADE";
        await command.ExecuteNonQueryAsync();
        await _adminConnection.CloseAsync();
        await _adminConnection.DisposeAsync();
    }
}
