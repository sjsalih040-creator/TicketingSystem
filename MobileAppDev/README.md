# Warehouse Staff Mobile App & API

## Overview
This project contains:
1.  **api**: A Node.js Express server that connects to your existing SQL Server database and provides a real-time WebSocket interface for the mobile app.
2.  **app**: Source code for the Flutter mobile application.

## 1. Node.js API
Located in `api/`.

### Setup & Run
```bash
cd api
npm install
node server.js
```
The server runs on http://localhost:5000.

### Features
- Connects to `db_ac2b67_db1` (Tickets table).
- `GET /api/tickets`: Fetches tickets.
- `POST /api/simulate`: Triggers a "New Ticket" event for testing.
- **Verification**: Run `node test_client.js` to see the real-time event system in action.

## 2. Flutter App
Located in `app/`.

### Setup
Ensure you have Flutter installed.
```bash
cd app
flutter pub get
```

### Important Notes
- **Audio**: A placeholder `assets/alarm.mp3` is provided. **Please replace it with a real MP3 file** for the ringtone feature to work correctly.
- **Connection**: `main.dart` is configured to connect to `http://localhost:5000` (web/windows) or `http://10.0.2.2:5000` (Android Emulator). Update `baseUrl` in `lib/main.dart` if testing on a physical device.

### Running
```bash
flutter run
```

## How it works
1.  When a ticket is created (simulated via `/api/simulate` or implemented in backend), the API emits `ticket_created`.
2.  The App listens for this event.
3.  On event:
    - Plays `alarm.mp3` in a loop.
    - Shows a full-screen alert and Notification.
    - User must press "STOP ALARM" to silence it.
