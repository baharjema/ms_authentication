import 'package:flutter/material.dart';
import 'package:ms_authenticate/ms_authenticate.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microsoft Authenticate Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MyHomePage(title: 'Microsoft Authenticate Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final msAuth = MsAuthenticate();

  // Azure configuration - Replace with your actual values
  final String tenantId = 'your tenant id';
  final String clientId = 'your client id';
  final String clientSecret = 'your client secret'; //optionals
  final String redirectUrl = 'your-auth-schema://auth{/your-default-path}';

  String _platformVersion = 'Unknown';
  String _authStatus = 'Not authenticated';
  String _token = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await msAuth.getPlatformVersion() ?? 'Unknown platform version.';
    } catch (e) {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _authStatus = 'Logging in...';
    });

    try {
      // Step 1: Get token directly from native plugin
      final tokenMap = await msAuth.loginWithMicrosoft(
        tenantId: tenantId,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        scope: 'openid profile email offline_access',
        tokenScope: 'https://graph.microsoft.com/.default',
      );

      if (tokenMap == null) {
        setState(() {
          _authStatus = 'Login cancelled';
          _isLoading = false;
        });
        return;
      }

      final idToken = tokenMap['id_token'] as String?;
      final accessToken = tokenMap['access_token'] as String?;
      final token = idToken ?? accessToken;

      if (token != null) {
        setState(() {
          _authStatus = 'Authenticated ✓';
          _token = token;
          _isLoading = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login successful!')));
      } else {
        setState(() {
          _authStatus = 'Login failed: No token received';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Login error: $e');
      setState(() {
        _authStatus = 'Login failed: ${e.toString()}';
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await msAuth.logout();
      setState(() {
        _authStatus = 'Not authenticated';
        _token = '';
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out successfully')));
    } catch (e) {
      debugPrint('Logout error: $e');
      setState(() {
        _authStatus = 'Logout failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform version
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Platform Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Running on: $_platformVersion'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Auth status
            Card(
              color: _authStatus.contains('Authenticated')
                  ? Colors.green[50]
                  : Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authentication Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _authStatus,
                      style: TextStyle(
                        color: _authStatus.contains('Authenticated')
                            ? Colors.green
                            : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Token display (truncated)
            if (_token.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Token (Partial)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _token.length > 100
                            ? '${_token.substring(0, 100)}...'
                            : _token,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Courier',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Login button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleLogin,
                icon: const Icon(Icons.login),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Login with Microsoft'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading || _token.isEmpty ? null : _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Setup instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Setup Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Update Azure configuration in main.dart:\n'
                      '   - tenantId\n'
                      '   - clientId\n'
                      '   - clientSecret\n'
                      '   - redirectUrl\n\n'
                      '2. Register redirect URIs in Azure AD app registration\n\n'
                      '3. Add API permissions in Azure\n\n'
                      '4. Run: flutter pub get',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
