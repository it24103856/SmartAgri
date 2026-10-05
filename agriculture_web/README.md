# React + Vite

## Backend configuration

The default API base is `https://smartagri-api-5mkz.onrender.com/api`.
Login and all other requests use the shared Axios client. Endpoint paths remain
relative to that base (for example `/auth/login`, not `/api/auth/login`).
Relative media paths resolve against the backend origin; absolute Supabase URLs
remain external URLs. No backend credentials belong in frontend configuration.

Run against the hosted API from this directory:

```powershell
npm install
npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
```

Run against a local API at `http://localhost:5000/api`:

```powershell
npm run dev:local -- --host 127.0.0.1 --port 5173 --strictPort
```

`dev:local` explicitly selects the committed, public `.env.development-local`
configuration. `VITE_API_BASE_URL` can override the default, as shown in
`.env.example`. A previously configured shell variable or `.env.local` can
override these choices; remove that override or set it to the intended API URL.
Vite configuration is applied at startup/build time; restart after changes.
`npm run build` builds for the hosted API unless an override is configured.
Use only public URLs in `VITE_` variables, never service-role keys or JWT secrets.

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend using TypeScript with type-aware lint rules enabled. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) for information on how to integrate TypeScript and [`typescript-eslint`](https://typescript-eslint.io) in your project.
