# Quick Start Guide - MS Authenticate Plugin

This guide helps you set up native Microsoft Azure Authentication in your Flutter application.

## 🚀 5-Minute Setup

### Step 1: Azure AD Configuration

1. Go to [Azure Portal](https://portal.azure.com).
2. **Azure AD → App registrations → New registration**.
3. Select: "Accounts in any organizational directory (Multi-tenant)".
4. Click **Register**.

### Step 2: Configure Redirect URIs

1. **Manage → Authentication → Add a platform**.
2. **Android**:
   - Package name: `id.my.wongflores.ms_authenticate_example` (or your app package).
   - Signature hash: Generate using your keystore.
3. **iOS/macOS**:
   - Bundle ID: Your iOS app bundle ID.
4. Add the **Redirect URI** to your configuration (e.g., `btn.obsd.eon://auth/login`).

### Step 3: API Permissions

1. **Manage → API permissions**.
2. **Add a permission → Microsoft Graph → Delegated permissions**.
3. Select `openid`, `profile`, `email`, and `offline_access`.
4. Grant admin consent if required.

---

## 📱 Implementation

### 1. Update Dependencies

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  ms_authenticate:
    path: ../ # or use version if published
```

### 2. Configure Android

Ensure your `AndroidManifest.xml` has the intent filter for the redirect URI:
android:path should be "/{your-default-path}" or don't use "android:path" if you don't have a custom path.
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="your.custom.scheme" android:host="auth" android:path="{/your-default-path}" />
</intent-filter>
</application>
<queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
</queries>
```

### 3. Usage in Flutter

```dart
import 'package:ms_authenticate/ms_authenticate.dart';

final msAuth = MsAuthenticate();

Future<void> login() async {
  try {
    final tokenMap = await msAuth.loginWithMicrosoft(
      tenantId: 'YOUR_TENANT_ID',
      clientId: 'YOUR_CLIENT_ID',
      redirectUrl: 'YOUR_REDIRECT_URL',
      scope: 'openid profile email offline_access',
      tokenScope: 'https://graph.microsoft.com/.default', // Optional
    );

    if (tokenMap != null) {
      print('Access Token: ${tokenMap['access_token']}');
    }
  } catch (e) {
    print('Login error: $e');
  }
}
```

---

## ✨ Features

- **Chrome Custom Tabs**: Provides a secure and integrated browser experience that automatically dismisses after login.
- **Native Token Exchange**: The plugin handles the authorization code exchange for tokens natively, simplifying your Flutter code.
- **Background Threading**: Token exchange is performed on a background thread to keep the UI responsive.

## 📋 Checklist

- [ ] Azure AD App Registration completed.
- [ ] Redirect URIs configured in Azure and `AndroidManifest.xml`.
- [ ] API permissions granted.
- [ ] `tenantId` and `clientId` updated in your app.

---

## 🆘 Troubleshooting

- **Browser not closing**: Ensure you are using the latest version of the plugin which implements Chrome Custom Tabs.
- **Redirect not working**: Double-check that your `redirectUrl` in code exactly matches the one in Azure Portal and `AndroidManifest.xml`.
