import UIKit
import WebKit
import Capacitor

/**
 * OAuthPlugin — native iOS OAuth using WKWebView with sessionStorage injection.
 *
 * ROOT CAUSE OF "Authorize params not found":
 * The Manus portal stores OAuth params (appId, redirectUri, state) in sessionStorage
 * when it loads with type=signIn. After Google auth, api.manus.im redirects back to
 * manus.im/app-auth?type=accounts — with ALL params in the URL. However, the portal's
 * JavaScript reads from sessionStorage (not the URL). On iOS, the cross-origin redirect
 * from api.manus.im to manus.im clears sessionStorage, so the portal throws the error.
 *
 * FIX:
 * Use WKWebView instead of SFSafariViewController or ASWebAuthenticationSession.
 * WKWebView lets us intercept page loads and inject JavaScript. When the portal loads
 * with type=accounts (after Google redirect), we inject JS to populate sessionStorage
 * with the params extracted from the URL before the portal's own JS executes.
 *
 * PLUGIN REGISTRATION (Capacitor 6):
 * Implement CAPBridgedPlugin directly in Swift — do NOT use the CAP_PLUGIN ObjC macro.
 * The macro creates a conflicting @interface OAuthPlugin : NSObject which shadows the
 * Swift class. NSClassFromString("OAuthPlugin") then returns the ObjC stub (not a
 * CAPPlugin subclass), the CapacitorPlugin cast fails, and the plugin never loads.
 * The correct pattern matches @capacitor/app and @capacitor/browser.
 */

@objc(OAuthPlugin)
public class OAuthPlugin: CAPPlugin, CAPBridgedPlugin {
    // MARK: - CAPBridgedPlugin conformance (required for Capacitor 6 auto-registration)
    public let identifier = "OAuthPlugin"
    public let jsName = "OAuth"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise)
    ]

    private var authController: OAuthWebViewController?

    @objc func start(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url"), let url = URL(string: urlString) else {
            call.reject("Invalid URL")
            return
        }
        let callbackScheme = call.getString("callbackScheme") ?? "konstrux"

        NSLog("[OAuthPlugin] start() url=%@ callbackScheme=%@", urlString, callbackScheme)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let controller = OAuthWebViewController(
                url: url,
                callbackScheme: callbackScheme,
                onCallback: { [weak self] callbackUrl in
                    NSLog("[OAuthPlugin] ✅ Callback received: %@", callbackUrl.absoluteString)
                    DispatchQueue.main.async {
                        self?.authController?.dismiss(animated: true) {
                            self?.authController = nil
                        }
                    }
                    call.resolve(["url": callbackUrl.absoluteString])
                },
                onCancel: { [weak self] in
                    NSLog("[OAuthPlugin] User cancelled")
                    DispatchQueue.main.async {
                        self?.authController?.dismiss(animated: true) {
                            self?.authController = nil
                        }
                    }
                    call.resolve(["cancelled": true])
                }
            )
            self.authController = controller

            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .fullScreen
            self.bridge?.viewController?.present(nav, animated: true)
        }
    }
}

// MARK: - WKWebView Auth Controller

class OAuthWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let initialUrl: URL
    private let callbackScheme: String
    private let onCallback: (URL) -> Void
    private let onCancel: () -> Void

    // Store OAuth params from the initial URL so we can restore them after Google redirect
    private var storedAppId: String = ""
    private var storedRedirectUri: String = ""
    private var storedState: String = ""

    init(url: URL, callbackScheme: String, onCallback: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.initialUrl = url
        self.callbackScheme = callbackScheme
        self.onCallback = onCallback
        self.onCancel = onCancel

        // Extract OAuth params from the initial URL
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                let value = item.value?.removingPercentEncoding ?? item.value ?? ""
                switch item.name {
                case "appId": self.storedAppId = value
                case "redirectUri": self.storedRedirectUri = value
                case "state": self.storedState = value
                default: break
                }
            }
        }

        NSLog("[OAuthWebVC] Stored params: appId=%@ redirectUri=%@ state(40)=%@",
              storedAppId, storedRedirectUri, String(storedState.prefix(40)))

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        title = "Sign In"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped)
        )

        // Use default (non-ephemeral) data store so Safari cookies are shared.
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        view.addSubview(webView)

        NSLog("[OAuthWebVC] Loading: %@", initialUrl.absoluteString)
        webView.load(URLRequest(url: initialUrl))
    }

    @objc func cancelTapped() { onCancel() }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        NSLog("[OAuthWebVC] nav: %@", String(url.absoluteString.prefix(120)))

        // Intercept the custom URL scheme callback (konstrux://oauth/done?token=...)
        if url.scheme?.lowercased() == callbackScheme.lowercased() {
            NSLog("[OAuthWebVC] ✅ Intercepted callback: %@", url.absoluteString)
            decisionHandler(.cancel)
            onCallback(url)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentUrl = webView.url else { return }
        NSLog("[OAuthWebVC] didFinish: %@", String(currentUrl.absoluteString.prefix(120)))

        // Only inject on manus.im pages
        guard let host = currentUrl.host, host.contains("manus.im") else { return }
        guard let components = URLComponents(url: currentUrl, resolvingAgainstBaseURL: false) else { return }

        let queryItems = components.queryItems ?? []
        let typeParam = queryItems.first(where: { $0.name == "type" })?.value ?? ""

        NSLog("[OAuthWebVC] Manus portal type=%@", typeParam)

        // Inject sessionStorage on both signIn and accounts pages.
        // On accounts page: params are in the URL but sessionStorage was cleared by the
        // cross-origin redirect from api.manus.im. We restore them here.
        let appId = queryItems.first(where: { $0.name == "appId" })?.value?.removingPercentEncoding
                    ?? storedAppId
        let redirectUri = queryItems.first(where: { $0.name == "redirectUri" })?.value?.removingPercentEncoding
                          ?? storedRedirectUri
        let state = queryItems.first(where: { $0.name == "state" })?.value?.removingPercentEncoding
                    ?? storedState

        guard !appId.isEmpty, !redirectUri.isEmpty, !state.isEmpty else {
            NSLog("[OAuthWebVC] Missing params for injection, skipping")
            return
        }

        NSLog("[OAuthWebVC] Injecting sessionStorage: appId=%@ type=%@", appId, typeParam)

        let paramsJson = """
        {"appId":"\(escJS(appId))","redirectUri":"\(escJS(redirectUri))","state":"\(escJS(state))","type":"signIn","responseType":"code"}
        """

        let js = """
        (function() {
            try {
                var key = 'webdev_oauth_params';
                var existing = sessionStorage.getItem(key);
                console.log('[OAuthFix] type=\(typeParam) existing=' + (existing ? 'found' : 'empty'));
                if (!existing) {
                    sessionStorage.setItem(key, JSON.stringify(\(paramsJson)));
                    console.log('[OAuthFix] Injected sessionStorage params for type=\(typeParam)');
                }
            } catch(e) {
                console.error('[OAuthFix] Error: ' + e);
            }
        })();
        """

        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                NSLog("[OAuthWebVC] JS injection error: %@", error.localizedDescription)
            } else {
                NSLog("[OAuthWebVC] JS injection OK for type=%@", typeParam)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[OAuthWebVC] nav failed: %@", error.localizedDescription)
    }

    // Allow Google sign-in windows (target=_blank) to open in the same webview
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            NSLog("[OAuthWebVC] New window → same view: %@", url.absoluteString)
            webView.load(navigationAction.request)
        }
        return nil
    }

    // MARK: - Helpers

    private func escJS(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
