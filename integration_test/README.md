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

## Capturas da Play Store (sem login)

`play_store_screenshots_test.dart` semeia dados fictícios no SQLite local e
captura seis telas reais. Use um emulador Android dedicado e sem sessão
Firebase: o teste reinicializa somente o banco local do app de teste e o remove
ao terminar.

```powershell
flutter drive -d <deviceId> `
  --driver=test_driver/play_store_screenshots_driver.dart `
  --target=integration_test/play_store_screenshots_test.dart `
  --dart-define=PLAY_STORE_SCREENSHOTS=true
```

Os PNGs são gravados em `play-assets/staging/phone/`; os arquivos oficiais em
`play-assets/phone/` não são alterados.
