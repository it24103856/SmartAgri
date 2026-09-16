using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace SmartAgri.Api.Services;

public sealed class EmailService
{
    private readonly IConfiguration _configuration;

    public EmailService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task SendAsync(
        string recipient,
        string subject,
        string text,
        CancellationToken cancellationToken = default)
    {
        var host = Required("Host");
        var username = Required("Username");
        var password = Required("Password");
        var fromEmail = Required("FromEmail");
        var fromName = _configuration["Email:FromName"] ?? "SmartAgri";
        var port = _configuration.GetValue<int?>("Email:Port") ?? 587;

        if (port is not (587 or 465))
        {
            throw new InvalidOperationException(
                "Email:Port must be 587 (STARTTLS) or 465 (TLS).");
        }

        var message = new MimeMessage();

        message.From.Add(new MailboxAddress(fromName, fromEmail));
        message.To.Add(MailboxAddress.Parse(recipient));
        message.Subject = subject;

        message.Body = new TextPart("plain")
        {
            Text = text
        };

        using var client = new SmtpClient
        {
            Timeout = 15000
        };

        var security = port == 465
            ? SecureSocketOptions.SslOnConnect
            : SecureSocketOptions.StartTls;

        Console.WriteLine($"SMTP: Connecting on port {port}...");

        await client.ConnectAsync(
            host,
            port,
            security,
            cancellationToken);

        Console.WriteLine("SMTP: Connected. Authenticating...");

        await client.AuthenticateAsync(
            username,
            password,
            cancellationToken);

        Console.WriteLine("SMTP: Authenticated. Sending...");

        await client.SendAsync(message, cancellationToken);

        Console.WriteLine("SMTP: Message accepted.");

        // Sending already succeeded; disconnect failure must not
        // turn it into an apparent failed send.
        try
        {
            await client.DisconnectAsync(true, cancellationToken);
        }
        catch
        {
            // Disposing the client still closes the connection.
        }
    }

    private string Required(string name)
    {
        var value = _configuration[$"Email:{name}"];

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(
                $"Email:{name} is not configured.");
        }

        return value;
    }
}
