import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ms_authenticate_method_channel.dart';

abstract class MsAuthenticatePlatform extends PlatformInterface {
  /// Constructs a MsAuthenticatePlatform.
  MsAuthenticatePlatform() : super(token: _token);

  static final Object _token = Object();

  static MsAuthenticatePlatform _instance = MethodChannelMsAuthenticate();

  /// The default instance of [MsAuthenticatePlatform] to use.
  ///
  /// Defaults to [MethodChannelMsAuthenticate].
  static MsAuthenticatePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MsAuthenticatePlatform] when
  /// they register themselves.
  static set instance(MsAuthenticatePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Map<Object?, Object?>?> loginWithMicrosoft({
    required String tenantId,
    required String clientId,
    String? clientSecret,
    required String redirectUrl,
    required String scope,
    String? tokenScope,
  }) {
    throw UnimplementedError('loginWithMicrosoft() has not been implemented.');
  }

  Future<Map<Object?, Object?>?> exchangeCodeForToken({
    required String tenantId,
    required String clientId,
    String? clientSecret,
    required String code,
    required String redirectUrl,
    String? scope,
  }) {
    throw UnimplementedError(
      'exchangeCodeForToken() has not been implemented.',
    );
  }

  Future<void> logout() {
    throw UnimplementedError('logout() has not been implemented.');
  }
}
