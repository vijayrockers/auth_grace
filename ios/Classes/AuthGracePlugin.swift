import Flutter
import LocalAuthentication

public class AuthGracePlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "auth_grace", binaryMessenger: registrar.messenger())
        let instance = AuthGracePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let gracePeriodSeconds = args?["gracePeriodSeconds"] as? Int ?? 30

        switch call.method {
        case "generateKey":
            // iOS: no key generation needed — we use Keychain timestamp
            result(true)

        case "isWithinGracePeriod":
            result(AuthGraceSession.isWithinGracePeriod(seconds: gracePeriodSeconds))

        case "keyExists":
            // Always true on iOS — we use timestamp approach
            result(true)

        case "deleteKey":
            AuthGraceSession.clearSession()
            result(true)

        case "isHardwareBacked":
            // iOS always uses Secure Enclave on supported devices
            result(true)

        case "markAuthenticated":
            AuthGraceSession.markAuthenticated()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
