FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY SmartAgri.Api/SmartAgri.Api.csproj SmartAgri.Api/
COPY SmartAgri.Agent/crop_catalog.json SmartAgri.Agent/
RUN dotnet restore SmartAgri.Api/SmartAgri.Api.csproj

COPY SmartAgri.Api/ SmartAgri.Api/
RUN dotnet publish SmartAgri.Api/SmartAgri.Api.csproj \
    --configuration Release --no-restore --output /out /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

ENV ASPNETCORE_ENVIRONMENT=Production \
    PORT=10000 \
    ReverseProxy__TrustForwardedProto=true \
    SmartBasket__WorkerEnabled=false \
    ProductImages__Directory=/app/uploads/products \
    CategoryImages__Directory=/app/uploads/categories \
    ProfileImages__Directory=/app/uploads/profiles \
    FarmImages__Directory=/app/uploads/farms \
    PackageImages__Directory=/app/uploads/packages

COPY --from=build /out/ ./
RUN mkdir -p uploads/products uploads/categories uploads/profiles uploads/farms uploads/packages \
    && chown -R app:app uploads

USER app
EXPOSE 10000
ENTRYPOINT ["dotnet", "SmartAgri.Api.dll"]
