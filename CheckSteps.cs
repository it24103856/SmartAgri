using System;
using System.IO;
using Npgsql;

class Program
{
    static void Main()
    {
        string connStr = "Host=localhost;Port=5432;Database=smartagri_db;Username=postgres;Password=minsara@2002";
        using var conn = new NpgsqlConnection(connStr);
        conn.Open();

        using var cmd = new NpgsqlCommand(@"
            SELECT ""AgentName"", ""Status"", ""ErrorMessage"", ""OutputJson"" 
            FROM ""SmartBasketSteps"" 
            ORDER BY ""FinishedAt"" DESC NULLS LAST 
            LIMIT 5", conn);

        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            Console.WriteLine($"Agent: {reader.GetString(0)}");
            Console.WriteLine($"Status: {reader.GetString(1)}");
            Console.WriteLine($"Error: {(reader.IsDBNull(2) ? "None" : reader.GetString(2))}");
            string output = reader.IsDBNull(3) ? "None" : reader.GetString(3);
            Console.WriteLine($"Output: {output.Substring(0, Math.Min(output.Length, 150))}...");
            Console.WriteLine(new string('-', 50));
        }
    }
}
