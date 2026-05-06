# Microsoft Azure Authentication Native Plugin

A complete native Flutter plugin for Microsoft Azure authentication without external dependencies like `url_launcher` or `app_links`.

## Features

✅ **Native Implementation**: Uses WebView on Android and WKWebView on iOS
✅ **No External Dependencies**: Only requires Flutter's core packages
✅ **OAuth 2.0 Flow**: Full support for Azure AD authorization code flow
✅ **Error Handling**: Comprehensive error handling and logging
✅ **Cross-Platform**: Works on both Android and iOS

## Setup

### 1. Add to pubspec.yaml

```yaml
dependencies:
  ms_authenticate: ^0.0.1
  dio: ^5.3.0 # For token exchange
```

### 2. Android Configuration

No additional configuration needed. The plugin handles everything natively using WebView.

### 3. iOS Configuration

No additional configuration needed. The plugin uses WKWebView natively.

## Usage

### Basic Login

```dart
import 'package:ms_authenticate/ms_authenticate.dart';

// Initialize the plugin
final msAuth = MsAuthenticate();

// Perform login
try {
  final authCode = await msAuth.loginWithMicrosoft(
    tenantId: 'YOUR_TENANT_ID',
    clientId: 'YOUR_CLIENT_ID',
    redirectUrl: 'msal{CLIENT_ID}://auth',  // Must match Azure app registration
    scope: 'openid profile email offline_access',
  );

  if (authCode != null) {
    // Exchange code for token (server-side recommended)
    print('Authorization code received: $authCode');

    // Exchange the code for an access token
    final token = await exchangeCodeForToken(authCode);
    // Save token securely
  }
} catch (e) {
  print('Login failed: $e');
}
```

### Complete Example with Token Exchange

```dart
import 'package:dio/dio.dart';
import 'package:ms_authenticate/ms_authenticate.dart';

class AuthService {
  final msAuth = MsAuthenticate();
  final dio = Dio();

  final String tenantId = 'YOUR_TENANT_ID';
  final String clientId = 'YOUR_CLIENT_ID';
  final String clientSecret = 'YOUR_CLIENT_SECRET'; // Keep secure!
  final String redirectUrl = 'msal{CLIENT_ID}://auth';

  Future<String?> loginWithMicrosoft() async {
    try {
      // Step 1: Get authorization code
      final authCode = await msAuth.loginWithMicrosoft(
        tenantId: tenantId,
        clientId: clientId,
        redirectUrl: redirectUrl,
        scope: 'openid profile email offline_access',
      );

      if (authCode == null) {
        print('User cancelled login');
        return null;
      }

      // Step 2: Exchange code for token
      final token = await _exchangeCodeForToken(authCode);
      return token;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<String> _exchangeCodeForToken(String code) async {
    final tokenUrl =
        'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token';

    try {
      final response = await dio.post(
        tokenUrl,
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        data: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'redirect_uri': redirectUrl,
          'grant_type': 'authorization_code',
          'scope': 'https://graph.microsoft.com/.default',
        },
      );

      if (response.statusCode == 200) {
        final idToken = response.data['id_token'];
        final accessToken = response.data['access_token'];

        print('ID Token: $idToken');
        print('Access Token: $accessToken');

        // Store tokens securely (e.g., using flutter_secure_storage)
        return idToken ?? accessToken;
      }

      throw Exception('Token exchange failed: ${response.statusCode}');
    } catch (e) {
      print('Token exchange error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await msAuth.logout();
    // Clear stored tokens
  }
}
```

## Azure App Registration Setup

### 1. Create App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to Azure AD → App registrations
3. Click "New registration"
4. Fill in the details and click "Register"

### 2. Add Platform Credentials

#### Android

1. Go to Manage → Authentication
2. Click "Add a platform"
3. Select "Android"
4. Enter:
   - **Package name**: `id.my.wongflores.ms_authenticate` (or your app's package)
   - **Signature hash**: Generate using your keystore

#### iOS

1. Go to Manage → Authentication
2. Click "Add a platform"
3. Select "iOS/macOS"
4. Enter:
   - **Bundle ID**: Your app's bundle ID
   - **Redirect URI**: `msauth.{BUNDLE_ID}://auth` (where {BUNDLE_ID} is your app's bundle ID)

### 3. Configure Redirect URIs

In the app registration, add redirect URIs:

```
# Android
msal<CLIENT_ID>://auth

# iOS (optional, automatic)
msauth.<BUNDLE_ID>://auth
```

### 4. API Permissions

1. Go to Manage → API permissions
2. Click "Add a permission"
3. Select "Microsoft Graph"
4. Add required permissions (e.g., `User.Read`)

## Platform-Specific Details

### Android

The plugin uses Android's WebView to display the login form. The authorization code is extracted when the redirect URL is detected.

```kotlin
// Key implementation details:
// - WebView client intercepts redirect URLs
// - Extracts authorization code from query parameters
// - DialogInterface shows login UI
// - All network calls are native
```

### iOS

The plugin uses WKWebView wrapped in a UIViewController with a NavigationController for a native iOS experience.

```swift
// Key implementation details:
// - WKWebView handles login form display
// - Navigation delegate intercepts redirect URLs
// - Code extraction from URL query parameters
// - Full-screen modal presentation
```

## Error Handling

### Common Errors

| Error                           | Cause                         | Solution                                         |
| ------------------------------- | ----------------------------- | ------------------------------------------------ |
| `INVALID_ARGS`                  | Missing required arguments    | Ensure all required parameters are provided      |
| `AUTH_FAILED`                   | Authentication failed         | Check tenant ID, client ID, and scope            |
| `NO_ACTIVITY` (Android)         | Activity not available        | Ensure plugin is called from UI thread           |
| `NO_VIEW_CONTROLLER` (iOS)      | View controller not available | Similar to Android, ensure proper initialization |
| `User cancelled authentication` | User closed login dialog      | Handle gracefully in your UI                     |

## Security Best Practices

1. **Store Secrets Securely**: Never hardcode `clientSecret`
2. **Use PKCE**: For public clients, consider implementing PKCE flow
3. **Secure Token Storage**: Use `flutter_secure_storage` for tokens
4. **Token Validation**: Validate tokens server-side before using
5. **HTTPS Only**: Ensure all redirect URLs use HTTPS in production
6. **Scope Minimization**: Request only necessary scopes

## Troubleshooting

### Android WebView Issues

If WebView doesn't load:

1. Check internet permission in AndroidManifest.xml
2. Verify redirect URL format
3. Check Firebase console for any blocking issues

### iOS Issues

If WKWebView doesn't work:

1. Check Bundle ID configuration
2. Verify redirect URI in Azure app registration
3. Ensure Info.plist has required entries

## Advanced Usage

### Custom Redirect Handler (Example with Deep Linking)

```dart
// If you need custom deep link handling:
// Create a service that wraps the plugin

class CustomAuthService {
  Future<String?> login() async {
    // Use plugin as shown
    final code = await msAuth.loginWithMicrosoft(
      tenantId: 'YOUR_TENANT_ID',
      clientId: 'YOUR_CLIENT_ID',
      redirectUrl: 'YOUR_CUSTOM_SCHEME://auth',
      scope: 'openid profile email',
    );
    return code;
  }
}
```

## License

Your License Here

## Support

For issues and questions, please create an issue in the repository.
