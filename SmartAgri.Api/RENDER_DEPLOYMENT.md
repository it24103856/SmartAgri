# Render Docker Web Service

## Exact service settings

| Setting | Value |
| --- | --- |
| Language/runtime | Docker |
| Root Directory | Leave empty (repository root) |
| Dockerfile Path | `SmartAgri.Api/Dockerfile` |
| Docker Build Context | `.` |
| Docker Command | Leave empty (use image entrypoint) |
| Health Check Path | `/health` |
| Pre-deploy Command | Leave empty; no automatic migrations or seeding |

The project targets `net8.0`, has no `ProjectReference` entries, and produces
`SmartAgri.Api.dll`. SDK and ASP.NET runtime images both use .NET 8. The sibling
`SmartAgri.Agent/crop_catalog.json` is a linked publish dependency, so setting the
Root Directory to `SmartAgri.Api` would hide a required file. The Python agent
is not part of this image and needs a separate reachable service.

The root `.dockerignore` limits context to the API and linked catalog, excludes
all `appsettings*.json`, `.env` files, certificates, upload/receipt directories,
developer tools, SQL files and build outputs. No credentials are build arguments.
Configuration comes from runtime environment variables using ASP.NET's `__`
separator. Local configuration files remain unchanged.

## Environment variables

Values below are placeholders only. Supply real values in Render's Environment
settings; do not commit them or put them into Docker build arguments.

Required for startup and authentication:

```dotenv
ConnectionStrings__DefaultConnection=<Npgsql connection string with production TLS settings>
JwtSettings__Secret=<strong random signing secret of at least 32 bytes>
JwtSettings__Issuer=<JWT issuer>
JwtSettings__Audience=<JWT audience>
JwtSettings__ExpiryInHours=<positive numeric expiry in hours>
Supabase__Url=<HTTPS Supabase project URL>
Supabase__ServiceRoleKey=<backend-only Supabase service-role key>
Supabase__ProductBucket=<public product image bucket>
Supabase__CategoryBucket=<public category image bucket>
Supabase__ProfileBucket=<public profile image bucket>
Supabase__FarmBucket=<public farm image bucket>
Supabase__PackageBucket=<public package image bucket>
```

Required to preserve AI, password-reset and receipt workflows:

```dotenv
AgentService__BaseUrl=<reachable agent service base URL>
AgentService__InternalKey=<shared internal authentication key matching the agent>
PasswordReset__HashKey=<base64 key decoding to at least 32 random bytes>
Email__Host=<SMTP host>
Email__Port=<supported TLS SMTP port>
Email__Username=<SMTP username>
Email__Password=<SMTP password>
Email__FromEmail=<verified sender email>
Email__FromName=<sender display name>
Supabase__OrderReceiptBucket=<private customer order receipt bucket>
Supabase__PackageReceiptBucket=<private package payment receipt bucket>
```

Feature configuration, as applicable:

```dotenv
PackageBankTransfer__BankName=<bank name>
PackageBankTransfer__AccountName=<account name>
PackageBankTransfer__AccountNumber=<account number>
PackageBankTransfer__Branch=<branch name>
PayHere__PublicBaseUrl=<public HTTPS API base URL for payment callbacks>
PayHere__MerchantId=<merchant ID>
PayHere__MerchantSecret=<merchant secret>
AllowedHosts=<semicolon-separated API hostnames>
SmartBasket__WorkerEnabled=<true only when database and agent are ready>
```

Container defaults are Production environment, port 10000, forwarded scheme
handling enabled, and Smart Basket processing disabled. Render's `PORT` overrides
the image default. To override container settings explicitly:

```dotenv
ASPNETCORE_ENVIRONMENT=<Production>
PORT=<Render-provided port>
ReverseProxy__TrustForwardedProto=<true behind Render's proxy; false for direct traffic>
ProductImages__Directory=<absolute writable product legacy-image directory>
CategoryImages__Directory=<absolute writable category legacy-image directory>
ProfileImages__Directory=<absolute writable profile legacy-image directory>
FarmImages__Directory=<absolute writable farm legacy-image directory>
PackageImages__Directory=<absolute writable package legacy-image directory>
```

Do not put Gemini keys on the API service; the separately configured Python
agent owns provider credentials. Do not set `ASPNETCORE_FORWARDEDHEADERS_ENABLED`
in addition to the scoped proxy configuration below.

## Port, health, storage and HTTPS

`Program.cs` validates `PORT` and listens on `http://0.0.0.0:<PORT>` when set.
Without it, existing local ASP.NET URL configuration continues to apply.
`EXPOSE 10000` documents the default but does not control binding. `/health`
returns only `{"status":"ok"}` anonymously and checks process liveness, not
database, storage or agent availability.

Render terminates TLS and redirects public HTTP to HTTPS at its edge. The API
uses HTTP internally and processes the final hop's `X-Forwarded-Proto` before
other middleware. It does not consume forwarded host or client-IP headers.
`ReverseProxy__TrustForwardedProto` accepts scheme forwarding from any connecting
proxy because Render proxy addresses are not pinned here: enable it only where
ingress is controlled by Render. There is no application HTTPS redirect loop.
Client-IP rate limiting still sees proxy addresses; individual client rate
limiting needs a separately configured trusted proxy/IP forwarding policy.

The container runs as the .NET image's non-root `app` user. All five image stores
call `Directory.CreateDirectory` at startup. Docker supplies writable directories
under `/app/uploads` with matching ownership, avoiding the existing default
outside `/app`. Overridden paths or mounted disks must be writable by that user.
New images go to Supabase; these directories serve legacy local images only.
Receipts are private Supabase objects and are never exposed by static middleware.
Local media is intentionally not packaged. Existing local-only URLs need an
explicit storage migration or persistent disk before they can work in production.

## Production checks and risks

- There are no startup calls to `Migrate`, `EnsureCreated`, `EnsureDeleted` or
  `DbSeeder.Seed`. `DbSeeder` is empty and no model seed data/default accounts
  were found. Docker starts only the API assembly. The database schema must
  already match the application; schema updates require a separate reviewed job.
- Smart Basket's optional worker can modify workflow/order data as soon as it
  runs. It is disabled by default in this image; enable only when dependencies
  and production processing are ready. Password-reset processing writes data
  only after requests enqueue work. No worker tasks or database operations were
  exercised here.
- Supabase image settings are required at startup because image stores are
  resolved for static middleware. Receipt settings are required when used.
- Render's ephemeral filesystem is unsuitable for legacy media or persistent
  Data Protection keys. Data Protection currently uses default key storage;
  features consuming those keys need persistent/shared, protected storage.
  JWT signing instead depends on retaining the configured signing secret.
- CORS currently permits all origins. Restrict it to intended browser clients
  as a separate application policy decision before public production use.
- Password-reset email uses SMTP ports 587 or 465. Render Free web services
  block both, so the current email implementation needs a plan permitting SMTP
  or a separately implemented HTTPS email provider. Do not assume reset email
  works merely because health passes.
- Keep service-role keys backend-only, receipt buckets private, and database
  TLS/authentication configured. This preparation does not change bucket policy,
  data, credentials or infrastructure.

## Validation performed

`dotnet build` and `dotnet publish` succeeded in Release configuration using
isolated validation output. NuGet emitted `NU1900` because vulnerability data
could not be fetched; compilation had no errors.

A published-assembly smoke check removed copied appsettings files and supplied
test-only environment values, an unreachable database endpoint, disabled Smart
Basket processing and temporary upload paths. Anonymous `/health`, a nondefault
PORT, a request carrying forwarded HTTPS, directory creation and the published
crop catalog passed. The smoke process was stopped. No database records or
external service were accessed.

Docker CLI was absent (including the standard Docker Desktop location).
**The Docker image build and Linux container runtime were not tested.**

When Docker is available, run from the repository root:

```sh
docker build --file SmartAgri.Api/Dockerfile --tag smartagri-api:local .
docker run --rm --env-file /path/to/test-only-runtime.env -e PORT=10000 -p 10000:10000 smartagri-api:local
curl --fail http://localhost:10000/health
```

Use test-only dependencies, keep the worker disabled, and do not invoke data
endpoints against production during validation. Check authenticated requests,
storage, email and the separate agent in a disposable environment before release.

References: [Render Docker](https://render.com/docs/docker),
[Render monorepo paths](https://render.com/docs/monorepo-support),
[Render ports and TLS](https://render.com/docs/web-services),
[Render Free limitations](https://render.com/docs/free),
[ASP.NET proxy configuration](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/proxy-load-balancer?view=aspnetcore-8.0).
