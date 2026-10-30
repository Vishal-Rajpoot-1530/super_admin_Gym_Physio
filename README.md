# multyapp_pannel

The **Gym Management** module connects to `gym-services-api` at
`http://10.0.2.2:3001/api/v1` by default on an Android emulator. Configure
`PANEL_ADMIN_EMAIL`, `PANEL_ADMIN_PASSWORD`, and `JWT_SECRET` on the backend.
In the app, open **API Connection**, enter those panel credentials and the API
URL, then tap **Verify & Save**. The app receives and securely stores a
short-lived bearer token; it does not need the backend super-admin key.

Start the backend from the `gym-services-api` directory with `npm run start:dev`.

Gym and Physio connections have separate base URLs and authentication. Gym
defaults to port `3001`; Physio defaults to port `3002`. To override them at
build time, use `GYM_API_BASE_URL` and `PHYSIO_API_BASE_URL` independently.
The panel signs in to each backend separately and stores each short-lived
session separately. Existing local Physio URLs are migrated from port `3004`
and the old `/physio` suffix to port `3002` and `/api/v1`.

The **Physio Clinic** module uses a separate API and clinic key, configured
independently in **API Connection**. It is not supported by `gym-services-api`.

## Web

The Super Admin web app uses port `5503`:

```powershell
flutter run -d web-server --web-port 5503
```

Open `http://localhost:5503`. In VS Code, select **Super Admin Web (5503)** in
Run and Debug. For browser requests to Gym, allow `http://localhost:5503` in
the Gym backend's `CORS_ORIGIN`.
