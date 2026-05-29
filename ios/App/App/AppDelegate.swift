import UIKit
import Capacitor
import AuthenticationServices

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate,
                   ASAuthorizationControllerDelegate,
                   ASAuthorizationControllerPresentationContextProviding {

    var window: UIWindow?

    func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: - Apple Sign-In 入口（给 Capacitor 调用）
    @objc func startAppleSignIn() {
        guard #available(iOS 13.0, *) else {
            callJsCallback(["error": "iOS 版本低于 13.0，不支持 Apple 登录"])
            return
        }
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController,
                                   didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else {
            callJsCallback(["error": "未获取到 Apple 登录凭证"])
            return
        }

        var result: [String: Any] = [
            "user": cred.user
        ]
        if let email = cred.email { result["email"] = email }
        if let fullName = cred.fullName, let givenName = fullName.givenName {
            result["fullName"] = givenName
        }
        if let identityToken = cred.identityToken,
           let tokenStr = String(data: identityToken, encoding: .utf8) {
            result["identityToken"] = tokenStr
        }

        callJsCallback(result)
    }

    func authorizationController(controller: ASAuthorizationController,
                                   didCompleteWithError error: Error) {
        callJsCallback(["error": error.localizedDescription])
    }

    // MARK: - Presentation Context
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.window!
    }

    // MARK: - 把结果回调给 JS（核心：不依赖 ViewController）
    private func callJsCallback(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        DispatchQueue.main.async {
            let js = "window._onAppleSignInResult && window._onAppleSignInResult(\(json));"
            self.window?.rootViewController?.webView?.evaluateJavaScript(js)
        }
    }

    // MARK: - 原生命周期方法（原样保留）
    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ app: UIApplication, open url: URL,
                      options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                      restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}
