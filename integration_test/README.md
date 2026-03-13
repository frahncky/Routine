# E2E Suite (Firebase)

This project has a full end-to-end suite at:

- `integration_test/app_e2e_test.dart`

## What it validates

- Login with Firebase test account.
- Profile name update (immediate UI + app bar reflection).
- Profile photo update (test override picker).
- Notification settings persistence and scheduling behavior.

## Run on Android device

```powershell
flutter test integration_test/app_e2e_test.dart -d <deviceId> `
  --dart-define=E2E_RUN=true `
  --dart-define=E2E_EMAIL=your-test-user@email.com `
  --dart-define=E2E_PASSWORD=your-test-password
```

Example using the connected phone id:

```powershell
flutter test integration_test/app_e2e_test.dart -d "adb-RXCT702R6HF-iZp0N2._adb-tls-connect._tcp" `
  --dart-define=E2E_RUN=true `
  --dart-define=E2E_EMAIL=qa_routine_test@yourdomain.com `
  --dart-define=E2E_PASSWORD=your-password
```

## Safe default

If `E2E_RUN` or credentials are not provided, the suite is skipped intentionally.
