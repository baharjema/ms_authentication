import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ms_authenticate_platform_interface.dart';

/// An implementation of [MsAuthenticatePlatform] that uses method channels.
class MethodChannelMsAuthenticate extends MsAuthenticatePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ms_authenticate');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<Map<Object?, Object?>?> loginWithMicrosoft({
    required String tenantId,
    required String clientId,
    String? clientSecret,
    required String redirectUrl,
    required String scope,
    String? tokenScope,
  }) async {
    final token = await methodChannel
        .invokeMethod<Map<Object?, Object?>?>('loginWithMicrosoft', {
          'tenantId': tenantId,
          'clientId': clientId,
          'clientSecret': ?clientSecret,
          'redirectUrl': redirectUrl,
          'scope': scope,
          'tokenScope': ?tokenScope,
        });
    return token;
  }

  @override
  Future<Map<Object?, Object?>?> exchangeCodeForToken({
    required String tenantId,
    required String clientId,
    String? clientSecret,
    required String code,
    required String redirectUrl,
    String? scope,
  }) async {
    final result = await methodChannel
        .invokeMethod<Map<Object?, Object?>?>('exchangeCodeForToken', {
          'tenantId': tenantId,
          'clientId': clientId,
          'clientSecret': ?clientSecret,
          'code': code,
          'redirectUrl': redirectUrl,
          'scope': ?scope,
        });
    return result;
  }

  @override
  Future<void> logout() async {
    await methodChannel.invokeMethod<void>('logout');
  }
}
