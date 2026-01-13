---
description: How to deploy the Ticketing System to SmarterASP.NET
---

// turbo-all
# Deployment Workflow

Follow these steps to deploy the Unified Ticketing System (Backend + Mobile API) to SmarterASP.NET.

## 1. Prepare Backend for Production
1. Open `e:\New App Full Stack\TicketingSystem\Backend\Program.cs` and ensure the CORS settings are restricted to your production domain if necessary.
2. Update the `baseUrl` in the Flutter app `main.dart` to your production URL.

## 2. Publish ASP.NET Core API
1. Run the publish command:
   ```powershell
   dotnet publish -c Release -o ./publish
   ```
2. Upload the contents of the `./publish` folder to your SmarterASP.NET site via FTP.

## 3. Database Migration
1. Ensure your SQL Server connection string in `appsettings.json` points to the SmarterASP.NET database.
2. The app will automatically run `DbInitializer.Initialize` on the first run to seed the Admin user and roles.

## 4. Flutter App Release
1. Update `baseUrl` in `lib/main.dart` to your site's URL (e.g., `https://your-site.smarterasp.net`).
2. Build the APK:
   ```powershell
   flutter build apk --release
   ```
3. Install the APK found in `build/app/outputs/flutter-apk/app-release.apk` on your Android devices.

## 5. Mobile API Deletion (Optional)
Since we moved the Mobile API into the C# backend, you can safely delete the old Node.js API folder:
`e:\New App Full Stack\TicketingSystem\Backend\MobileAppDev\api`
