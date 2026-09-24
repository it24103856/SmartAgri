using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using SmartAgri.Api.Data;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Middleware;
using SmartAgri.Api.Services;
using Microsoft.Extensions.FileProviders;
using Microsoft.AspNetCore.DataProtection;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

// 1. Add Services to DI Container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IProductService, ProductService>();
builder.Services.AddSingleton<ProductImageStore>();
builder.Services.AddSingleton<CategoryImageStore>();
builder.Services.AddSingleton<ProfileImageStore>();
builder.Services.AddScoped<IFarmService, FarmService>();
builder.Services.AddSingleton<FarmImageStore>();

// 2. Swagger Configuration with JWT Authorize Button
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "SmartAgri API", Version = "v1" });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter your JWT token: Bearer <your_token>"
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// 3. DbContext Registration
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// 4. Register Custom Services
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();

// 5. CORS Setup
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod());
});

// 6. JWT Authentication Setup
var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var key = Encoding.UTF8.GetBytes(jwtSettings["Secret"]!);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["Issuer"],
        ValidAudience = jwtSettings["Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(key),
        RoleClaimType = ClaimTypes.Role
    };

    options.Events = new JwtBearerEvents
    {
        OnTokenValidated = async context =>
        {
            var principal = context.Principal;

            if (!int.TryParse(
                    principal?.FindFirstValue(ClaimTypes.NameIdentifier),
                    out var userId) ||
                !Guid.TryParse(
                    principal?.FindFirstValue("session_stamp"),
                    out var tokenStamp))
            {
                context.Fail("Invalid session.");
                return;
            }

            var db = context.HttpContext.RequestServices
                .GetRequiredService<ApplicationDbContext>();

            var account = await db.Users
                .AsNoTracking()
                .Where(user => user.Id == userId)
                .Select(user => new
                {
                    user.SessionStamp,
                    user.Status,
                    user.Role
                })
                .SingleOrDefaultAsync(
                    context.HttpContext.RequestAborted);

            var tokenRole =
                principal?.FindFirstValue(ClaimTypes.Role);

            if (account is null ||
                account.Status != "ACTIVE" ||
                account.SessionStamp != tokenStamp ||
                account.Role != tokenRole)
            {
                context.Fail("Session is no longer valid.");
            }
        }
    };
});

builder.Services.AddAuthorization();

builder.Services.AddDataProtection();
builder.Services.AddScoped<CustomerCheckoutService>();
builder.Services.AddScoped<AdminOrderService>();
builder.Services.AddScoped<CustomerOrderCancellationService>();
builder.Services.AddTransient<EmailService>();
builder.Services.AddScoped<PasswordResetService>();
builder.Services.AddSingleton<PasswordResetQueue>();
builder.Services.AddHostedService<PasswordResetWorker>();
builder.Services.AddScoped<SmartBasketService>();
builder.Services.AddScoped<AdminSmartBasketService>();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode =
        StatusCodes.Status429TooManyRequests;

    options.AddPolicy("password-reset", context =>
    {
        var address =
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown";

        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: address,
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            });
    });
});

builder.Services.AddHttpClient<AgentValidationClient>(
    (services, client) =>
    {
        var configuration =
            services.GetRequiredService<IConfiguration>();

        var baseUrl = configuration["AgentService:BaseUrl"]
            ?? throw new InvalidOperationException(
                "AgentService:BaseUrl is missing.");

        client.BaseAddress = new Uri(baseUrl);
        client.Timeout = TimeSpan.FromSeconds(15);
    });

builder.Services.AddHttpClient<AgentProposalClient>((services, client) =>
{
    var configuration = services
        .GetRequiredService<IConfiguration>();

    var baseUrl = configuration["AgentService:BaseUrl"]
        ?? "http://127.0.0.1:8001/";

    client.BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/");
    client.Timeout = TimeSpan.FromSeconds(380);
    client.MaxResponseContentBufferSize = 1_048_576;
});

builder.Services.AddScoped<SmartBasketProcessor>();

if (builder.Configuration.GetValue<bool>("SmartBasket:WorkerEnabled"))
{
    builder.Services.AddHostedService<SmartBasketWorker>();
}

var app = builder.Build();
if (app.Environment.IsDevelopment() &&
    app.Configuration.GetValue<bool>("Email:SendStartupTest"))
{
    using var scope = app.Services.CreateScope();

    var emailService =
        scope.ServiceProvider.GetRequiredService<EmailService>();

    var recipient = app.Configuration["Email:FromEmail"]
        ?? throw new InvalidOperationException(
            "Email:FromEmail is not configured.");

    try
    {
        using var timeout =
            new CancellationTokenSource(TimeSpan.FromSeconds(30));

        await emailService.SendAsync(
            recipient,
            "SmartAgri email test",
            "Your SmartAgri backend email service is working.",
            timeout.Token);

        app.Logger.LogInformation(
            "Email test accepted by the SMTP server. Check your inbox.");
    }
    catch (Exception ex)
    {
        // Do not log credentials or email contents.
        app.Logger.LogError(
            "Email test failed ({ErrorType}). Check SMTP configuration.",
            ex.GetType().Name);
    }
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Custom exception handler must run early, before auth/authorization,
// so it can catch anything thrown further down the pipeline.
app.UseMiddleware<ExceptionMiddleware>();

app.UseCors("AllowAll");
var productImageStore =
    app.Services.GetRequiredService<ProductImageStore>();

app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(
        productImageStore.RootDirectory),

    RequestPath = "/uploads/products",

    OnPrepareResponse = context =>
    {
        context.Context.Response.Headers["X-Content-Type-Options"] =
            "nosniff";
    }
});

var categoryImageStore = app.Services.GetRequiredService<CategoryImageStore>();
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(categoryImageStore.RootDirectory),
    RequestPath = "/uploads/categories",
    OnPrepareResponse = context =>
        context.Context.Response.Headers["X-Content-Type-Options"] = "nosniff"
});

var profileImageStore = app.Services.GetRequiredService<ProfileImageStore>();
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(profileImageStore.RootDirectory),
    RequestPath = "/uploads/profiles",
    OnPrepareResponse = context => context.Context.Response.Headers["X-Content-Type-Options"] = "nosniff"
});

var farmImageStore = app.Services.GetRequiredService<FarmImageStore>();
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(farmImageStore.RootDirectory),
    RequestPath = "/uploads/farms",
    OnPrepareResponse = context => context.Context.Response.Headers["X-Content-Type-Options"] = "nosniff"
});

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapControllers();

app.Run();
