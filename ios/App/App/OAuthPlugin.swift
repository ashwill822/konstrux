import AuthenticationServices
import Capacitor

/**
 * OAuthPlugin — native iOS OAuth using ASWebAuthenticationSession.
 *
 * WHY ASWebAuthenticationSession (not WKWebView):
 * Google enforces the "Use secure browsers" policy (Error 403: disallowed_useragent).
 * WKWebView is explicitly blocked. ASWebAuthenticationSession uses Safari's engine
 * under the hood and is the only approach Google allows for native apps.
 *
 * HOW IT WORKS:
 * 1. JS calls Capacitor.Plugins.OAuth.start({ url, callbackScheme })
 * 2. We open ASWebAuthenticationSession with the Manus portal URL
 * 3. After Google auth, the server redirects to konstrux://oauth/done?token=...
 * 4. ASWebAuthenticationSession intercepts the custom scheme and returns the URL
 * 5. We resolve the promise with { url: "konstrux://oauth/done?token=..." }
 * 6. JS extracts the token, sets the cookie, and navigates to the dashboard
 *
 * WHY NOT WKWebView:
 * - Google 403: disallowed_useragent blocks all embedded web views
 * - sessionStorage is cleared on cross-origin redirects (api.manus.im → manus.im)
 *
 * PLUGIN REGISTRATION (Capacitor 6):
 * Implement CAPBridgedPlugin directly in Swift — do NOT use the CAP_PLUGIN ObjC macro.
 * The macro creates a conflicting @interface OAuthPlugin : NSObject which shadows the
 * Swift class. NSClassFromString("OAuthPlugin") returns the ObjC stub (not a CAPPlugin
 * subclass), the CapacitorPlugin cast fails, and the plugin never loads.
 */
@objc(OAuthPlugin)
public class OAuthPlugin: CAPPlugin, CAPBridgedPlugin {
    // MARK: - CAPBridgedPlugin conformance (required for Capacitor 6 auto-registration)
    public let identifier = "OAuthPlugin"
    public let jsName = "OAuth"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise)
    ]

    private var authSession: ASWebAuthenticationSession?

    @objc func start(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url"), let url = URL(string: urlString) else {
            call.reject("Invalid URL")
            return
        }
        let callbackScheme = call.getString("callbackScheme") ?? "konstrux"
        NSLog("[OAuthPlugin] start() url=%@ callbackScheme=%@", urlString, callbackScheme)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    // User cancelled — not an error
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        NSLog("[OAuthPlugin] User cancelled")
                        call.resolve(["cancelled": true])
                    } else {
                        NSLog("[OAuthPlugin] ASWebAuthenticationSession error: %@", error.localizedDescription)
                        call.reject(error.localizedDescription)
                    }
                    return
                }
                guard let callbackURL = callbackURL else {
                    call.reject("No callback URL received")
                    return
                }
                NSLog("[OAuthPlugin] ✅ Callback: %@", callbackURL.absoluteString)
                call.resolve(["url": callbackURL.absoluteString])
            }

            // Required on iOS 13+ — provide the presentation anchor
            session.presentationContextProvider = self
            // Allow the session to share cookies/credentials with Safari
            // This lets users who are already signed into Google in Safari skip re-auth
            session.prefersEphemeralWebBrowserSession = false

            self.authSession = session
            let started = session.start()
            NSLog("[OAuthPlugin] ASWebAuthenticationSession started: %@", started ? "YES" : "NO")
            if !started {
                call.reject("Failed to start ASWebAuthenticationSession")
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension OAuthPlugin: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return bridge?.viewController?.view.window ?? UIWindow()
    }
}
