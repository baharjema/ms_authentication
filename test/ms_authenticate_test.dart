import 'package:flutter_test/flutter_test.dart';
import 'package:ms_authenticate/ms_authenticate.dart';
import 'package:ms_authenticate/ms_authenticate_platform_interface.dart';
import 'package:ms_authenticate/ms_authenticate_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMsAuthenticatePlatform
    with MockPlatformInterfaceMixin
    implements MsAuthenticatePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Map<Object?, Object?>?> loginWithMicrosoft({
    required String tenantId,
    required String clientId,
    String? clientSecret,
    required String redirectUrl,
    required String scope,
    String? tokenScope,
  }) => Future.value({'id_token': 'mock_id_token', 'access_token': 'mock_access_token'});

  @override
  Future<Map<Object?, Object?>?> exchangeCodeForToken({
    required String tenantId,
    required String clientId,
    String? clientSecret,
    required String code,
    required String redirectUrl,
    String? scope,
  }) => Future.value({'id_token': 'mock_id_token', 'access_token': 'mock_access_token'});

  @override
  Future<void> logout() => Future.value();
}

void main() {
  final MsAuthenticatePlatform initialPlatform = MsAuthenticatePlatform.instance;

  test('$MethodChannelMsAuthenticate is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMsAuthenticate>());
  });

  test('getPlatformVersion', () async {
    MsAuthenticate msAuthenticatePlugin = MsAuthenticate();
    MockMsAuthenticatePlatform fakePlatform = MockMsAuthenticatePlatform();
    MsAuthenticatePlatform.instance = fakePlatform;

    expect(await msAuthenticatePlugin.getPlatformVersion(), '42');
  });
}
