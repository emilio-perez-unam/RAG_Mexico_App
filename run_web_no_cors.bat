@echo off
REM Run Flutter web with Chrome security disabled (DEVELOPMENT ONLY)
flutter run -d chrome --web-browser-flag "--disable-web-security" --web-browser-flag "--user-data-dir=%TEMP%/chrome_dev"