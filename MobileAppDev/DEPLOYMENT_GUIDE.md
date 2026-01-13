# Deployment Guide for Warehouse Mobile API

## Option 1: Deploy to Railway (Recommended - Easiest)

### Step 1: Prepare Your Project

1. **Add a start script to package.json**
   Already done! Your `server.js` is the entry point.

2. **Create a `.gitignore` file** (if you want to use Git):
   ```
   node_modules/
   uploads/
   .env
   ```

3. **Environment Variables**
   Your database credentials are currently hardcoded. For production, you should use environment variables.

### Step 2: Deploy to Railway

1. Go to [railway.app](https://railway.app)
2. Sign up with GitHub
3. Click "New Project" → "Deploy from GitHub repo"
4. Connect your GitHub account and select this repository
5. Railway will auto-detect Node.js and deploy
6. Once deployed, Railway will give you a URL like: `https://your-app.up.railway.app`

### Step 3: Update Flutter App

Update the `baseUrl` in your Flutter app to your Railway URL:

```dart
String get baseUrl {
  return 'https://your-app.up.railway.app'; // Your Railway URL
}
```

---

## Option 2: Deploy to Heroku

### Step 1: Install Heroku CLI
Download from: https://devcenter.heroku.com/articles/heroku-cli

### Step 2: Create Heroku App

```bash
cd "e:\New App Full Stack\TicketingSystem\Backend\MobileAppDev\api"
heroku login
heroku create warehouse-api
```

### Step 3: Add Procfile

Create a file named `Procfile` (no extension):
```
web: node server.js
```

### Step 4: Deploy

```bash
git init
git add .
git commit -m "Initial commit"
git push heroku main
```

### Step 5: Set Port

Update `server.js` to use Heroku's dynamic port:
```javascript
const PORT = process.env.PORT || 5000;
```

---

## Option 3: Use Your Local Network (Testing on Physical Devices)

If you want to test on a physical Android device connected to the same WiFi:

### Step 1: Find Your Computer's Local IP

**Windows:**
```cmd
ipconfig
```
Look for "IPv4 Address" (e.g., `192.168.1.100`)

### Step 2: Update Flutter App

```dart
String get baseUrl {
  if (Platform.isAndroid) return 'http://192.168.1.100:5000'; // Your local IP
  return 'http://localhost:5000';
}
```

### Step 3: Allow Firewall Access

Windows Firewall might block connections. Allow Node.js through:
- Windows Defender Firewall → Allow an app
- Find Node.js → Allow on Private networks

---

## Option 4: Use ngrok (Quick Testing - No Deployment)

ngrok creates a temporary public URL for your localhost:

### Step 1: Install ngrok
Download from: https://ngrok.com/download

### Step 2: Start ngrok
```bash
ngrok http 5000
```

### Step 3: Copy the URL
ngrok gives you a URL like: `https://abc123.ngrok.io`

### Step 4: Update Flutter App
```dart
String get baseUrl {
  return 'https://abc123.ngrok.io'; // Your ngrok URL
}
```

**Note:** ngrok URLs expire when you close the terminal. Good for quick testing only.

---

## Recommended: Railway Deployment

Railway is the easiest option because:
- ✅ Free tier available
- ✅ Automatic HTTPS
- ✅ Easy deployment from GitHub
- ✅ Environment variables support
- ✅ No credit card required for free tier

Would you like me to help you set up Railway deployment?
