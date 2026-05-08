import Flutter
import UIKit
import AuthenticationServices
import Foundation

public class MsAuthenticatePlugin: NSObject, FlutterPlugin, ASWebAuthenticationPresentationContextProviding {
    private var channel: FlutterMethodChannel?
    private var authSession: ASWebAuthenticationSession?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "ms_authenticate",
            binaryMessenger: registrar.messenger()
        )
        let instance = MsAuthenticatePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Fallback to first available window for older iOS versions
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "loginWithMicrosoft":
            guard let args = call.arguments as? [String: Any],
                  let tenantId = args["tenantId"] as? String,
                  let clientId = args["clientId"] as? String,
                  let redirectUrl = args["redirectUrl"] as? String,
                  let scope = args["scope"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing required arguments",
                    details: nil
                ))
                return
            }
            let clientSecret = args["clientSecret"] as? String
            let tokenScope = args["tokenScope"] as? String
            let nonce = args["nonce"] as? String
            
            loginWithMicrosoft(
                tenantId: tenantId,
                clientId: clientId,
                clientSecret: clientSecret,
                redirectUrl: redirectUrl,
                scope: scope,
                tokenScope: tokenScope,
                nonce: nonce,
                result: result
            )
            
        case "logout":
            logout()
            result(nil)
            
        case "exchangeCodeForToken":
            guard let args = call.arguments as? [String: Any],
                  let tenantId = args["tenantId"] as? String,
                  let clientId = args["clientId"] as? String,
                  let code = args["code"] as? String,
                  let redirectUrl = args["redirectUrl"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing required arguments for exchangeCodeForToken",
                    details: nil
                ))
                return
            }
            let clientSecret = args["clientSecret"] as? String
            let scope = args["scope"] as? String
            
            exchangeCodeForToken(
                tenantId: tenantId,
                clientId: clientId,
                clientSecret: clientSecret,
                code: code,
                redirectUrl: redirectUrl,
                scope: scope,
                result: result
            )
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func loginWithMicrosoft(
        tenantId: String,
        clientId: String,
        clientSecret: String?,
        redirectUrl: String,
        scope: String,
        tokenScope: String?,
        nonce: String?,
        result: @escaping FlutterResult
    ) {
        let authUrlStr = buildAuthorizationUrl(
            tenantId: tenantId,
            clientId: clientId,
            redirectUrl: redirectUrl,
            scope: scope,
            nonce: nonce
        )
        
        guard let authUrl = URL(string: authUrlStr) else {
            result(FlutterError(code: "INVALID_URL", message: "Failed to create authorization URL", details: nil))
            return
        }
        
        // Extract scheme from redirect URL
        guard let redirectUrlObj = URL(string: redirectUrl), let scheme = redirectUrlObj.scheme else {
            result(FlutterError(code: "INVALID_REDIRECT", message: "Redirect URL must have a valid scheme", details: nil))
            return
        }
        
        authSession = ASWebAuthenticationSession(url: authUrl, callbackURLScheme: scheme) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                    result(FlutterError(code: "AUTH_CANCELLED", message: "User cancelled login", details: nil))
                } else {
                    result(FlutterError(code: "AUTH_FAILED", message: error.localizedDescription, details: nil))
                }
                return
            }
            
            guard let callbackURL = callbackURL else {
                result(FlutterError(code: "NO_CALLBACK_URL", message: "No callback URL received", details: nil))
                return
            }
            
            // Extract code
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                result(FlutterError(code: "NO_QUERY_ITEMS", message: "Could not parse query items from redirect", details: nil))
                return
            }
            
            if let errorParam = queryItems.first(where: { $0.name == "error" || $0.name == "error_description" })?.value {
                result(FlutterError(code: "AUTH_FAILED", message: errorParam, details: nil))
                return
            }
            
            guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                result(FlutterError(code: "NO_CODE", message: "Authorization code not found", details: nil))
                return
            }
            
            // Automatically exchange code for token
            self.exchangeCodeForToken(
                tenantId: tenantId,
                clientId: clientId,
                clientSecret: clientSecret,
                code: code,
                redirectUrl: redirectUrl,
                scope: tokenScope,
                result: result
            )
        }
        
        if #available(iOS 13.0, *) {
            authSession?.presentationContextProvider = self
        }
        
        authSession?.start()
    }
    
    private func exchangeCodeForToken(
        tenantId: String,
        clientId: String,
        clientSecret: String?,
        code: String,
        redirectUrl: String,
        scope: String?,
        result: @escaping FlutterResult
    ) {
        let urlString = "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token"
        guard let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid token URL", details: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var params: [String: String] = [
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectUrl,
            "grant_type": "authorization_code"
        ]
        
        if let secret = clientSecret {
            params["client_secret"] = secret
        }
        if let s = scope {
            params["scope"] = s
        }
        
        let postData = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = postData.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "NETWORK_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    result(FlutterError(code: "NETWORK_ERROR", message: "Invalid HTTP response", details: nil))
                    return
                }
                
                if httpResponse.statusCode == 200, let data = data {
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            result(jsonObject)
                        } else {
                            result(FlutterError(code: "PARSE_ERROR", message: "Failed to parse JSON response", details: nil))
                        }
                    } catch {
                        result(FlutterError(code: "PARSE_ERROR", message: error.localizedDescription, details: nil))
                    }
                } else {
                    var errorMsg = "HTTP \(httpResponse.statusCode)"
                    if let data = data, let str = String(data: data, encoding: .utf8) {
                        errorMsg += ": \(str)"
                    }
                    result(FlutterError(code: "TOKEN_EXCHANGE_FAILED", message: errorMsg, details: nil))
                }
            }
        }
        
        task.resume()
    }

    private func buildAuthorizationUrl(
        tenantId: String,
        clientId: String,
        redirectUrl: String,
        scope: String,
        nonce: String?
    ) -> String {
        let baseUrl = "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/authorize"
        let currentState = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var params: [String: String] = [
            "client_id": clientId,
            "response_type": "code",
            "redirect_uri": redirectUrl,
            "response_mode": "query",
            "scope": scope,
            "state": currentState,
            "prompt": "login"
        ]

        if let nonce = nonce {
            params["nonce"] = nonce
        }
        
        let queryString = params
            .map { key, value in
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(encodedValue)"
            }
            .joined(separator: "&")
        
        return "\(baseUrl)?\(queryString)"
    }

    private func logout() {
        authSession?.cancel()
        authSession = nil
    }
}
