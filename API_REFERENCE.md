# MS Authenticate Plugin - API Reference

Complete API documentation for the Microsoft Azure Authentication native plugin.

## Class: `MsAuthenticate`

Main plugin class for handling Microsoft Azure authentication.

### Methods

#### `getPlatformVersion()`

Get the current platform version.

**Returns:** `Future<String?>`

**Example:**

```dart
final msAuth = MsAuthenticate();
final version = await msAuth.getPlatformVersion();
print('Platform: $version'); // Output: "Android 14" or "iOS 17.0"
```

---

#### `loginWithMicrosoft()`

Authenticate user with Microsoft Azure AD.

**Parameters:**

| Parameter     | Type   | Required | Description                          |
| ------------- | ------ | -------- | ------------------------------------ |
| `tenantId`    | String | Yes      | Azure AD tenant ID (directory ID)    |
| `clientId`    | String | Yes      | Azure app registration client ID     |
| `redirectUrl` | String | Yes      | Registered redirect URI in Azure app |
| `scope`       | String | Yes      | OAuth scopes (space-separated)       |

**Returns:** `Future<String?>`

Returns the authorization code on success, or null if user cancels.

**Throws:** `PlatformException` on platform-specific errors

**Example:**

```dart
try {
  final authCode = await msAuth.loginWithMicrosoft(
    tenantId: '00000000-0000-0000-0000-000000000000',
    clientId: '11111111-1111-1111-1111-111111111111',
    redirectUrl: 'msal11111111-1111-1111-1111-111111111111://auth',
    scope: 'openid profile email offline_access',
  );

  if (authCode != null) {
    print('Authorization code: $authCode');
    // Exchange code for token server-side
  } else {
    print('User cancelled login');
  }
} on PlatformException catch (e) {
  print('Login error: ${e.message}');
}
```

**Authorization Code Flow:**

```
┌─────────────────────────────────────────────────────────────┐
│                    OAuth 2.0 Code Flow                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Flutter App calls loginWithMicrosoft()                 │
│           ↓                                                 │
│  2. Native WebView opens login form                        │
│           ↓                                                 │
│  3. User enters credentials                                │
│           ↓                                                 │
│  4. Azure redirects to: {redirectUrl}?code={authCode}     │
│           ↓                                                 │
│  5. Plugin extracts code & returns to Flutter             │
│           ↓                                                 │
│  6. Flutter exchanges code for token (server-side)         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

#### `logout()`

Clean up authentication session.

**Returns:** `Future<void>`

**Example:**

```dart
await msAuth.logout();
print('Logout complete');
```

---

## Platform-Specific Details

### Android Implementation

**Method Channel:** `ms_authenticate`

**WebView Behavior:**

- Opens in an AlertDialog
- Size: 95% of screen width and height
- JavaScript enabled
- DOM storage enabled
- Auto-closes on redirect detection

**Important Notes:**

- Requires `android.permission.INTERNET`
- Requires `android.permission.ACCESS_NETWORK_STATE`
- Activity must be available (throws `NO_ACTIVITY` if not)

**Native Methods:**

```kotlin
// Internal: Builds OAuth URL
private fun buildAuthorizationUrl(
    tenantId: String,
    clientId: String,
    redirectUrl: String,
    scope: String
): String

// Internal: Extracts auth code from redirect URL
private fun extractCodeFromUrl(url: String): String?

// Internal: Handles WebView errors
private fun showAuthWebView(...)
```

---

### iOS Implementation

**Method Channel:** `ms_authenticate`

**WebView Behavior:**

- Uses WKWebView
- Wrapped in UINavigationController
- Full-screen modal presentation
- Auto-closes on redirect detection

**Important Notes:**

- Requires iOS 13.0+
- Swift 5.0+
- Bundle ID must match Azure app registration

**Native Classes:**

```swift
class MsAuthenticatePlugin: FlutterPlugin
class WebViewAuthViewController: UIViewController
```

---

## Error Codes

| Code                 | Platform | Description                 | Solution                            |
| -------------------- | -------- | --------------------------- | ----------------------------------- |
| `INVALID_ARGS`       | Both     | Missing required arguments  | Verify all parameters are provided  |
| `AUTH_FAILED`        | Both     | Authentication failed       | Check Azure configuration           |
| `INVALID_URL`        | iOS      | Could not create auth URL   | Verify tenantId and clientId format |
| `NO_ACTIVITY`        | Android  | Activity not available      | Ensure called from UI thread        |
| `NO_VIEW_CONTROLLER` | iOS      | View controller unavailable | Ensure proper initialization        |

---

## Return Values

### Success Case

```dart
String authCode = '0.BQcQ...'; // Authorization code from Azure
```

### Cancellation Case

```dart
String? authCode = null; // User cancelled login
```

### Error Case

```dart
throw PlatformException(
  code: 'AUTH_FAILED',
  message: 'User cancelled authentication',
)
```

---

## Common Patterns

### Pattern 1: Login with Token Exchange

```dart
Future<Map<String, dynamic>> login() async {
  try {
    final code = await msAuth.loginWithMicrosoft(...);
    if (code == null) return {};

    final token = await exchangeCodeForToken(code);
    return {'accessToken': token, 'success': true};
  } catch (e) {
    return {'error': e.toString(), 'success': false};
  }
}

Future<String> exchangeCodeForToken(String code) async {
  // Implementation...
}
```

### Pattern 2: State Management Integration

```dart
class AuthProvider with ChangeNotifier {
  final MsAuthenticate _msAuth = MsAuthenticate();
  String? _token;
  bool _isAuthenticated = false;

  Future<void> login() async {
    try {
      final code = await _msAuth.loginWithMicrosoft(...);
      _token = await _exchangeToken(code);
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      notifyListeners();
      rethrow;
    }
  }
}
```

### Pattern 3: Secure Token Storage

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureAuthService {
  final storage = const FlutterSecureStorage();
  final msAuth = MsAuthenticate();

  Future<void> loginAndStore() async {
    final code = await msAuth.loginWithMicrosoft(...);
    final token = await exchangeToken(code!);

    // Store securely
    await storage.write(key: 'access_token', value: token);
    await storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<String?> getStoredToken() async {
    return await storage.read(key: 'access_token');
  }
}
```

---

## Advanced Configuration

### Custom Redirect URLs

Redirect URL format must match Azure app registration:

**Android:**

```
msal<CLIENT_ID>://auth
```

**iOS:**

```
msauth.<BUNDLE_ID>://auth
```

### Scope Examples

```dart
// Minimal scopes
'openid profile email'

// With offline access
'openid profile email offline_access'

// Graph API access
'https://graph.microsoft.com/User.Read'

// Multiple scopes
'openid profile email offline_access https://graph.microsoft.com/.default'
```

---

## Testing

### Unit Testing

```dart
test('MsAuthenticate initialization', () async {
  final msAuth = MsAuthenticate();
  expect(msAuth, isNotNull);
});
```

### Integration Testing

```dart
testWidgets('Login flow', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());

  // Find and tap login button
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();

  // Verify WebView is shown
  expect(find.byType(WebView), findsWidgets);
});
```

---

## Frequently Asked Questions

**Q: Can I use the plugin without exchanging the code for a token?**
A: Yes, but for production apps, you should exchange the code server-side for security.

**Q: Does the plugin support PKCE flow?**
A: Currently, it supports the basic auth code flow. PKCE can be added with custom modifications.

**Q: Can I customize the login UI?**
A: The UI is handled by Azure's native login page. You cannot customize it, but the WebView is native to each platform.

**Q: How do I handle token refresh?**
A: Implement token refresh server-side using the refresh token returned from the token exchange.

**Q: Is the plugin production-ready?**
A: Yes, but follow security best practices regarding token storage and clientSecret handling.

---

## Changelog

### Version 0.0.1

- Initial release
- Native Android WebView implementation
- Native iOS WKWebView implementation
- OAuth 2.0 authorization code flow
- Error handling and logging
