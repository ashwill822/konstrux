import Foundation
import Capacitor
import AuthenticationServices

/**
 * OAuthPlugin — wraps ASWebAuthenticationSession for iOS OAuth flows.
 *
 * Why ASWebAuthenticationSession instead of @capacitor/browser (SFSafariViewController)?
 *
 * SFSafariViewController creates an isolated browsing context. When the Manus portal
 * redirects from Google back to manus.im/app-auth?type=accounts, the portal's
 * sessionStorage is cleared (new page load in the same VC). The portal then cannot
 * find its stored OAuth params and shows "Authorize params not found".
 *
 * ASWebAuthenticationSession:
 *   - Shares Safari's full cookie store, so the Manus server-side session persists
 *     through the Google redirect chain.
 *   - Natively intercepts a custom URL scheme (konstrux://) and delivers the final
 *     redirect URL to the completion handler — no sessionStorage dependency.
 *   - Handles app-switching (2FA, Google prompt) correctly without losing state.
 */
@objc(OAuthPlugin)
public class OAuthPlugin: CAPPlugin, ASWebAuthenticationPresentationContextProviding {

    private var authSession: ASWebAuthenticationSession?
    private var pendingCall: CAPPluginCall?

    /**
     * start(url, callbackScheme)
     *
     * Opens url in ASWebAuthenticationSession. When the session redirects to
     * a URL whose scheme matches callbackScheme, the session closes and the
     * full callback URL is returned to JavaScript.
     *
     * On error or user cancellation, returns { error: "..." }.
     */
    @objc func start(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url"),
              let url = URL(string: urlString),
              let scheme = call.getString("callbackScheme") else {
            call.reject("url and callbackScheme are required")
            return
        }

        DispatchQueue.main.async {
            self.pendingCall = call

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }

                if let error = error {
                    let nsError = error as NSError
                    // User cancelled — not a hard error
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        self.pendingCall?.resolve(["cancelled": true])
                    } else {
                        self.pendingCall?.reject(error.localizedDescription)
                    }
                    self.pendingCall = nil
                    self.authSession = nil
                    return
                }

                if let callbackURL = callbackURL {
                    self.pendingCall?.resolve(["url": callbackURL.absoluteString])
                } else {
                    self.pendingCall?.reject("No callback URL received")
                }
                self.pendingCall = nil
                self.authSession = nil
            }

            // prefersEphemeralWebBrowserSession = false means we share Safari cookies.
            // This is critical: the Manus session cookie set during Google auth must
            // be available to the portal when it loads with type=accounts.
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self

            self.authSession = session
            session.start()
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.bridge?.viewController?.view.window ?? UIWindow()
    }
}
