import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'ms_authenticate_platform_interface.dart';

/// A web implementation of the MsAuthenticatePlatform of the MsAuthenticate plugin.
class MsAuthenticateWeb extends MsAuthenticatePlatform {
  /// Constructs a MsAuthenticateWeb
  MsAuthenticateWeb();

  static void registerWith(Registrar registrar) {
    MsAuthenticatePlatform.instance = MsAuthenticateWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
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
    String? nonce,
  }) async {
    final authUrl = _buildAuthorizationUrl(
      tenantId: tenantId,
      clientId: clientId,
      redirectUrl: redirectUrl,
      scope: scope,
      nonce: nonce,
    );

    // Open popup
    final popup = web.window.open(
      authUrl,
      'MicrosoftAuth',
      'width=800,height=600',
    );
    if (popup == null) {
      throw Exception(
        'Could not open popup window. Please allow popups for this site.',
      );
    }

    final completer = Completer<String>();
    late Timer timer;
    timer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (popup.closed) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('User closed the authentication window.'),
          );
        }
        return;
      }

      try {
        final currentUrl = popup.location.href;
        if (currentUrl.startsWith(redirectUrl)) {
          final uri = Uri.parse(currentUrl);
          if (uri.queryParameters.containsKey('code')) {
            timer.cancel();
            popup.close();
            completer.complete(uri.queryParameters['code']);
          } else if (uri.queryParameters.containsKey('error')) {
            timer.cancel();
            popup.close();
            final errorMsg =
                uri.queryParameters['error_description'] ??
                uri.queryParameters['error'];
            completer.completeError(Exception(errorMsg));
          }
        }
      } catch (e) {
        // Cross-origin access throws an error until redirected back to the same origin.
      }
    });

    try {
      final code = await completer.future;

      return await exchangeCodeForToken(
        tenantId: tenantId,
        clientId: clientId,
        clientSecret: clientSecret,
        code: code,
        redirectUrl: redirectUrl,
        scope: tokenScope,
      );
    } catch (e) {
      return Future.error(e);
    }
  }

  String _buildAuthorizationUrl({
    required String tenantId,
    required String clientId,
    required String redirectUrl,
    required String scope,
    String? nonce,
  }) {
    final currentState = generateSecureState();
    final baseUrl =
        'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize';
    final params = {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUrl,
      'response_mode': 'query',
      'scope': scope,
      'state': currentState,
      'prompt': 'login',
    };

    if (nonce != null) {
      params['nonce'] = nonce;
    }

    final queryString = params.entries
        .map(
          (e) =>
              '\${Uri.encodeComponent(e.key)}=\${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$baseUrl?$queryString';
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
    final urlString =
        'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token';

    final params = <String, String>{
      'client_id': clientId,
      'code': code,
      'redirect_uri': redirectUrl,
      'grant_type': 'authorization_code',
    };

    if (clientSecret != null) {
      params['client_secret'] = clientSecret;
    }
    if (scope != null) {
      params['scope'] = scope;
    }

    final headers = web.Headers();
    headers.append('Content-Type', 'application/x-www-form-urlencoded');

    final bodyContent = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final init = web.RequestInit(
      method: 'POST',
      headers: headers,
      body: bodyContent.toJS,
    );

    try {
      final response = await web.window.fetch(urlString.toJS, init).toDart;
      final textJs = await response.text().toDart;
      final text = textJs.toDart;

      if (response.ok) {
        final Map<String, dynamic> jsonObject = jsonDecode(text);
        return jsonObject;
      } else {
        throw Exception('Response code: ${response.status}, error: $text');
      }
    } catch (e) {
      throw Exception('NETWORK_ERROR: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    // Optional web logout implementation
  }

  String generateSecureState([int byteLength = 32]) {
    final random = Random.secure();
    final values = List<int>.generate(byteLength, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }
}
