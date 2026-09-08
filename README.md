# SmartAgri

SmartAgri is a monorepo containing three separate applications:

- `agriculture_flutter`: Flutter mobile, desktop, and web client
- `agriculture_web`: React and Vite administration web client
- `SmartAgri.Api`: ASP.NET Core and Entity Framework Core backend

## Complete repository structure

Generated folders such as Flutter `build/`, Dart `.dart_tool/`, web
`node_modules/` and `dist/`, and .NET `bin/` and `obj/` are intentionally not
listed. They are recreated by the relevant build tools and are not source code.

```text
SmartAgri/
├── README.md
│
├── agriculture_flutter/                         # Flutter client
│   ├── lib/
│   │   ├── main.dart                            # Application entry point
│   │   ├── onboarding_screen.dart
│   │   ├── splash_screen.dart
│   │   ├── core/                                # App-wide reusable code
│   │   │   ├── constants/
│   │   │   │   ├── api_constants.dart
│   │   │   │   ├── api_endpoints.dart
│   │   │   │   ├── app_assets.dart
│   │   │   │   ├── app_colors.dart
│   │   │   │   └── app_text_styles.dart
│   │   │   ├── network/
│   │   │   │   ├── api_client.dart
│   │   │   │   ├── api_exception.dart
│   │   │   │   └── network_info.dart
│   │   │   ├── theme/
│   │   │   │   ├── app_theme.dart
│   │   │   │   ├── dark_theme.dart
│   │   │   │   └── light_theme.dart
│   │   │   └── utils/
│   │   │       ├── formatters.dart
│   │   │       ├── helpers.dart
│   │   │       ├── token_storage.dart
│   │   │       └── validators.dart
│   │   ├── features/                            # Feature-first app modules
│   │   │   ├── admin/
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   ├── ai/
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   ├── auth/
│   │   │   │   ├── data/
│   │   │   │   │   ├── datasources/
│   │   │   │   │   ├── models/
│   │   │   │   │   │   └── user_model.dart
│   │   │   │   │   ├── repositories/
│   │   │   │   │   └── services/
│   │   │   │   │       └── auth_service.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── entities/
│   │   │   │   │   ├── repositories/
│   │   │   │   │   └── usecases/
│   │   │   │   └── presentation/
│   │   │   │       ├── controllers/
│   │   │   │       ├── screens/
│   │   │   │       │   ├── login_screen.dart
│   │   │   │       │   └── register_screen.dart
│   │   │   │       └── widgets/
│   │   │   ├── cart/
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   ├── customer/
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   ├── equipment/
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   ├── farmer/
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   ├── home/
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── home_screen.dart
│   │   │   ├── orders/
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   └── products/
│   │   │       ├── data/
│   │   │       ├── domain/
│   │   │       └── presentation/
│   │   └── shared/
│   │       ├── components/
│   │       └── widgets/
│   ├── assets/images/
│   │   └── plants_bg.jpg
│   ├── android/                                # Android host project
│   ├── ios/                                    # iOS host project
│   ├── linux/                                  # Linux host project
│   ├── macos/                                  # macOS host project
│   ├── web/                                    # Flutter web host project
│   ├── windows/                                # Windows host project
│   ├── test/
│   │   └── widget_test.dart
│   ├── analysis_options.yaml
│   ├── agriculture_flutter.iml
│   ├── pubspec.yaml
│   ├── pubspec.lock
│   └── README.md
│
├── agriculture_web/                             # React/Vite web client
│   ├── src/
│   │   ├── main.jsx                            # React entry point
│   │   ├── App.jsx                             # Root application component
│   │   ├── App.css
│   │   ├── index.css
│   │   ├── assets/
│   │   │   ├── hero.png
│   │   │   ├── react.svg
│   │   │   └── vite.svg
│   │   ├── components/
│   │   │   ├── charts/
│   │   │   ├── common/
│   │   │   └── layout/
│   │   │       └── Sidebar.jsx
│   │   ├── context/                             # Currently empty
│   │   ├── hooks/                               # Currently empty
│   │   ├── pages/
│   │   │   ├── AIManagement/
│   │   │   ├── Analytics/
│   │   │   ├── Auth/
│   │   │   │   └── Login.jsx
│   │   │   ├── Categories/
│   │   │   ├── Dashboard/
│   │   │   │   └── Dashboard.jsx
│   │   │   ├── Equipment/
│   │   │   ├── Orders/
│   │   │   ├── Packages/
│   │   │   ├── Products/
│   │   │   ├── Settings/
│   │   │   └── Users/
│   │   │       └── UserManagement.jsx
│   │   ├── services/
│   │   │   └── api.js
│   │   └── utils/                               # Currently empty
│   ├── public/
│   │   ├── favicon.svg
│   │   └── icons.svg
│   ├── index.html
│   ├── link.jsx
│   ├── eslint.config.js
│   ├── package.json
│   ├── package-lock.json
│   ├── vite.config.js
│   └── README.md
│
└── SmartAgri.Api/                               # ASP.NET Core backend
    ├── Controllers/
    │   ├── AdminController.cs
    │   ├── AIController.cs
    │   ├── AuthController.cs
    │   ├── CartController.cs
    │   ├── CategoriesController.cs
    │   ├── CategoryController.cs
    │   ├── CustomerController.cs
    │   ├── CustomersController.cs
    │   ├── EquipmentController.cs
    │   ├── FarmerController.cs
    │   ├── FarmersController.cs
    │   ├── FarmsController.cs
    │   ├── OrderController.cs
    │   ├── OrdersController.cs
    │   ├── PaymentController.cs
    │   ├── PaymentsController.cs
    │   ├── ProductController.cs
    │   ├── ProductsController.cs
    │   └── UsersController.cs
    ├── Data/
    │   ├── ApplicationDbContext.cs
    │   ├── DbSeeder.cs
    │   └── Migrations/
    ├── DTOs/
    │   └── UserDtos.cs
    ├── Interfaces/
    │   ├── IAIService.cs
    │   ├── IAuthService.cs
    │   ├── IEquipmentService.cs
    │   ├── IFarmerService.cs
    │   ├── IOrderService.cs
    │   ├── IProductService.cs
    │   └── IUserService.cs
    ├── Middleware/
    │   └── ExceptionMiddleware.cs
    ├── Migrations/
    │   ├── 20260818174809_InitialCreate.cs
    │   ├── 20260818174809_InitialCreate.Designer.cs
    │   └── ApplicationDbContextModelSnapshot.cs
    ├── Models/
    │   ├── AIRequest.cs
    │   ├── Approval.cs
    │   ├── Cart.cs
    │   ├── CartItem.cs
    │   ├── Category.cs
    │   ├── CropHistory.cs
    │   ├── Customer.cs
    │   ├── EnvironmentalRecord.cs
    │   ├── Equipment.cs
    │   ├── Farm.cs
    │   ├── Farmer.cs
    │   ├── Order.cs
    │   ├── OrderItem.cs
    │   ├── Payment.cs
    │   ├── Product.cs
    │   ├── Recommendation.cs
    │   ├── SoilRecord.cs
    │   └── User.cs
    ├── Routes/
    │   └── UserRoutes.cs
    ├── Services/
    │   ├── AIService.cs
    │   ├── AuthService.cs
    │   ├── EquipmentService.cs
    │   ├── FarmerService.cs
    │   ├── OrderService.cs
    │   ├── ProductService.cs
    │   └── UserService.cs
    ├── Program.cs
    ├── SmartAgri.Api.csproj
    ├── SmartAgri.Api.http
    ├── appsettings.json
    ├── appsettings.Development.json
    └── README.md
```

## Running each application

### Flutter mobile app

```bash
cd agriculture_flutter
flutter pub get
flutter run
```

### React web app

```bash
cd agriculture_web
npm install
npm run dev
```

### ASP.NET Core API

```bash
cd SmartAgri.Api
dotnet restore
dotnet run
```

Each application has its own dependencies, configuration, and build process. The
Flutter and React clients communicate with `SmartAgri.Api` through HTTP APIs.
