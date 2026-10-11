using System.Net;
using System.Text.Json;

namespace SmartAgri.Api.Middleware;

/// <summary>
/// Global exception handling middleware that intercepts unhandled exceptions and formats consistent JSON error responses.
/// </summary>
public class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _logger;

    public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    /// <summary>
    /// Executes the middleware pipeline, catching and formatting domain or server exceptions.
    /// </summary>
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (BadHttpRequestException ex)
{
    await HandleExceptionAsync(
        context,
        (HttpStatusCode)ex.StatusCode,
        ex.Message);
}
        catch (UnauthorizedAccessException ex)
        {
            await HandleExceptionAsync(context, HttpStatusCode.Forbidden, ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception occurred");
            await HandleExceptionAsync(context, HttpStatusCode.InternalServerError, "An unexpected server error occurred.");
        }
    }

    /// <summary>
    /// Writes a JSON error payload containing HTTP status code and message to the response stream.
    /// </summary>
    private static Task HandleExceptionAsync(HttpContext context, HttpStatusCode statusCode, string message)
    {
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)statusCode;

        var response = new { statusCode = (int)statusCode, message };
        return context.Response.WriteAsync(JsonSerializer.Serialize(response));
    }
}