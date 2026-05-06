import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_authenticate/ms_authenticate_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMsAuthenticate platform = MethodChannelMsAuthenticate();
  const MethodChannel channel = MethodChannel('ms_authenticate');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
