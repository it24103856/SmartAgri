using System.Threading.Channels;

namespace SmartAgri.Api.Services;

public sealed class PasswordResetQueue
{
    private readonly Channel<string> _channel =
        Channel.CreateBounded<string>(
            new BoundedChannelOptions(100)
            {
                SingleReader = true,
                SingleWriter = false,
                FullMode = BoundedChannelFullMode.Wait
            });

    public bool TryAdd(string email) =>
        _channel.Writer.TryWrite(email);

    public IAsyncEnumerable<string> ReadAllAsync(
        CancellationToken cancellationToken) =>
        _channel.Reader.ReadAllAsync(cancellationToken);
}

public sealed class PasswordResetWorker : BackgroundService
{
    private readonly PasswordResetQueue _queue;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<PasswordResetWorker> _logger;

    public PasswordResetWorker(
        PasswordResetQueue queue,
        IServiceScopeFactory scopeFactory,
        ILogger<PasswordResetWorker> logger)
    {
        _queue = queue;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        try
        {
            await foreach (var email in
                _queue.ReadAllAsync(stoppingToken))
            {
                try
                {
                    using var timeout =
                        CancellationTokenSource.CreateLinkedTokenSource(
                            stoppingToken);

                    timeout.CancelAfter(TimeSpan.FromSeconds(30));

                    await using var scope =
                        _scopeFactory.CreateAsyncScope();

                    var service = scope.ServiceProvider
                        .GetRequiredService<PasswordResetService>();

                    await service.SendCodeAsync(email, timeout.Token);
                }
                catch (OperationCanceledException)
                    when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception error)
                {
                    // Never log the reset code, password, or email body.
                    _logger.LogError(
                        "Password reset email processing failed: {ErrorType}",
                        error.GetType().Name);
                }
            }
        }
        catch (OperationCanceledException)
            when (stoppingToken.IsCancellationRequested)
        {
            // Normal application shutdown.
        }
    }
}