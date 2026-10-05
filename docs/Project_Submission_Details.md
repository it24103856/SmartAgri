# SmartAgri Project Details & Submission Information

This document contains the detailed technical breakdowns, architectural designs, deployment URLs, and startup instructions requested for the project evaluation.

---

## 1. Database Design (PostgreSQL)
The system uses a highly normalized relational database managed via **Entity Framework Core (Code-First Approach)** on PostgreSQL. 

**Core Entities & Relationships (20 Total Database Tables):**
*   **Users & Profiles:** `Users` (Role-Based Access: Admin, Farmer, Customer), `Farms`.
*   **E-Commerce:** `Products`, `Categories`, `Carts`, `CartItems`, `CustomerOrders`, `CustomerOrderLines`, `CustomerOrderStatusHistories`.
*   **Services & Packages:** `Packages`, `PackageBookings`.
*   **Transactions & Proofs:** `CustomerPayments`, `PackagePaymentProofs`, `OrderPaymentProofs`.
*   **AI & Workflows:** `SmartBasketWorkflows`, `SmartBasketItems`, `SmartBasketSteps`, `SmartBasketApprovals`, `FarmAiAnalyses`.
*   **Notifications:** `FarmerNotifications`.
*   **Design Highlights:** 
    *   **Optimistic Concurrency:** Uses a `Version` (Guid) concurrency token on Bookings/Orders/Products to prevent simultaneous overwrite conflicts.
    *   **Data Integrity:** Enforced JSONB check constraints for budget and AI validations directly at the PostgreSQL schema level.

---

## 2. System Architecture & Design

### 2.1 ASP.NET Core API (Backend)
*   **Pattern:** Modular Monolith with a layered architecture.
*   **Scale:** Comprehensive API featuring **34 distinct Controllers** (e.g., `AdminController`, `AIController`, `PackagesController`, `SmartBasketDiagnosticsController`).
*   **Security:** Stateless JWT authentication. Role-based authorization (`[Authorize(Roles="ADMIN")]`).
*   **Storage:** Integrated with Supabase Cloud Storage for high-performance receipt and image retrieval.
*   **Performance:** Extensive use of `.AsNoTracking()` for read-only queries (Analytics, Dashboards) to minimize memory allocation.
*   **Local Port:** Runs on `http://localhost:5000` via `launchSettings.json`.

### 2.2 React Web Panel (Admin Dashboard)
*   **Framework:** React 18 + Vite (running on standard port `5173`).
*   **Architecture:** Component-based SPA mapping to 11 core management modules in `src/pages` (Analytics, Auth, Categories, Dashboard, Orders, Packages, Products, SmartBaskets, Users).
*   **UI/UX:** Styled entirely with TailwindCSS. Uses Recharts for real-time financial analytics (`SalesAndProfit.jsx`).
*   **State & Navigation:** Managed via `activeTab` routing in `App.jsx` with secure login wrappers.

### 2.3 Flutter Mobile App (Farmers & Customers)
*   **Architecture:** Feature-driven cross-platform mobile architecture. Code is strictly organized into domains (`features/auth`, `features/farmer`, `features/orders`, `features/smart_basket`, etc.).
*   **Scale:** Contains **26 individual UI screens** mapped through `customer_shell.dart` and `farmer_shell.dart`.
*   **Networking:** Secure API communication handling JWT injection securely for endpoints like AI insights, marketplace management, and payment uploads.

---

## 3. Project URLs & Access Information

*Please update the bracketed `[...]` placeholders with your actual live URLs before submission.*

*   **Repository URL:** `[INSERT_YOUR_GITHUB_REPO_URL]`
*   **React Admin Dashboard URL:** `[INSERT_YOUR_VERCEL_OR_NETLIFY_URL]`
*   **ASP.NET Core API URL:** `[INSERT_YOUR_RENDER_OR_AZURE_API_URL]`
*   **Swagger API Documentation URL:** `[INSERT_YOUR_API_URL]/swagger/index.html`
*   **Health Check URL:** `[INSERT_YOUR_API_URL]/health` 

### PostgreSQL Deployment Evidence
*   **Database Provider:** Supabase / Render PostgreSQL
*   **Evidence:** *(Attach a screenshot of your Cloud Database Dashboard showing the active `smartagri` database and connection metrics here).*

---

## 4. Agentic AI Setup (Smart Basket & Farm AI)
The AI features are powered by a **Multi-Agent System** running on a separate Python FastAPI microservice.
*   **Agent Service URL:** `https://smartagri-agent.onrender.com`
*   **Workflow:** 
    1.  **Planner Agent:** Extracts user constraints (budget, land size).
    2.  **Catalog/Evidence Agent:** Uses custom tools to query real-time product stock or farm history.
    3.  **Review/Safety Agent:** Validates the drafted basket/recommendation against initial constraints.
*   **Resilience:** Features a built-in deterministic local algorithm that acts as a fallback if the Gemini LLM API is rate-limited.
*   **Authentication:** The backend API communicates securely with the Agent API using the `X-Agent-Key` header (`AGENT_INTERNAL_KEY`).

---

## 5. Required Environment Variables

### ASP.NET Core API (`appsettings.json` / Env Vars)
```env
ASPNETCORE_ENVIRONMENT=Production
ConnectionStrings__DefaultConnection=<PostgreSQL_Connection_String>
JwtSettings__Secret=<Min_32_Byte_Secret_Key>
JwtSettings__ExpiryInHours=8
Supabase__Url=<Supabase_Project_URL>
Supabase__ServiceRoleKey=<Supabase_Admin_Key>
Supabase__ProductBucket=product-images
Supabase__CategoryBucket=category-images
Supabase__ProfileBucket=profile-images
Supabase__FarmBucket=farm-images
Supabase__PackageBucket=package-images
Supabase__PackageReceiptBucket=package-receipts
Supabase__OrderReceiptBucket=order-receipts
AgentService__BaseUrl=https://smartagri-agent.onrender.com
AgentService__InternalKey=<Shared_Secret_With_Agent>
Email__Host=smtp.gmail.com
Email__Username=<Gmail_Address>
Email__Password=<Gmail_App_Password>
PasswordReset__HashKey=<Base64_Encoded_32_Byte_Key>
```

### Python Agent (`.env`)
```env
AGENT_INTERNAL_KEY=<Shared_Secret_With_API>
GEMINI_API_KEY=<Google_Gemini_Key>
```

---

## 6. Local Startup Instructions

### 1. Database Setup
1. Run a local PostgreSQL instance.
2. Update `ConnectionStrings:DefaultConnection` in the API's `appsettings.Development.json`.
3. Apply migrations: `dotnet ef database update`

### 2. Backend API (C#)
```bash
cd SmartAgri.Api
dotnet build
dotnet run
# API runs on http://localhost:5000
# Swagger available at http://localhost:5000/swagger
```

### 3. Agentic AI Service (Python)
```bash
cd SmartAgri.Agent
python -m venv .venv
# Activate venv (Windows: .venv\Scripts\activate)
pip install -r requirements.txt
uvicorn main:app --reload --port 8001
```

### 4. React Admin Panel
```bash
cd agriculture_web
npm install
npm run dev
# Dashboard runs on http://localhost:5173
```

### 5. Flutter Mobile App
```bash
cd agriculture_flutter
flutter pub get
flutter run
```
