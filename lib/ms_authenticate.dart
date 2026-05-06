import 'ms_authenticate_platform_interface.dart';

class MsAuthenticate {
  Future<String?> getPlatformVersion() {
    return MsAuthenticatePlatform.instance.getPlatformVersion();
  }

  /// Login with Microsoft Azure
  ///
  /// Parameters:
  /// - [tenantId]: Azure tenant ID
  /// - [clientId]: Azure client ID
  /// - [redirectUrl]: Redirect URL (must match registered URI in Azure)
  /// - [scope]: OAuth scopes (space-separated)
  ///
  /// Returns: A Map containing the token response (id_token, access_token) on success, null on cancel
  Future<Map<Object?, Object?>?> loginWithMicrosoft({
    required String tenantId,
    required String clientId,
    String? clientSecret,
    required String redirectUrl,
    required String scope,
    String? tokenScope,
  }) {
    return MsAuthenticatePlatform.instance.loginWithMicrosoft(
      tenantId: tenantId,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUrl: redirectUrl,
      scope: scope,
      tokenScope: tokenScope,
    );
  }

  /// Exchange authorization code for token
  Future<Map<Object?, Object?>?> exchangeCodeForToken({
    required String tenantId,
    required String clientId,
    String? clientSecret,
    required String code,
    required String redirectUrl,
    String? scope,
  }) {
    return MsAuthenticatePlatform.instance.exchangeCodeForToken(
      tenantId: tenantId,
      clientId: clientId,
      clientSecret: clientSecret,
      code: code,
      redirectUrl: redirectUrl,
      scope: scope,
    );
  }

  /// Logout and clean up
  Future<void> logout() {
    return MsAuthenticatePlatform.instance.logout();
  }
}
