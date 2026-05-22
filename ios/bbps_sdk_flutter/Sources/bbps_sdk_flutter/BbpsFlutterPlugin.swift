import Flutter
import UIKit
import BBPSSDK

public class BbpsFlutterPlugin: NSObject, FlutterPlugin {
    private var bbpsService: BBPSService?
    private var eventSink: FlutterEventSink?
    private var currentResult: FlutterResult?
    private var clientId: String?

    private var rootViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return nil
        }
        
        guard let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              var rootVC = window.rootViewController else {
            return nil
        }
        
        while let presented = rootVC.presentedViewController {
            rootVC = presented
        }
        
        return rootVC
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "bbps_sdk_flutter", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "bbps_sdk_flutter_events", binaryMessenger: registrar.messenger())
        let instance = BbpsFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createService":
            createService(call.arguments as? [String: Any], result: result)
        case "initiate":
            initiate(call.arguments as? [String: Any], result: result)
        case "process":
            process(call.arguments as? [String: Any], result: result)
        case "terminate":
            terminate(result: result)
        case "onBackPressed":
            onBackPressed(result: result)
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func createService(_ params: [String: Any]?, result: @escaping FlutterResult) {
        guard let clientId = params?["clientId"] as? String else {
            result(FlutterError(code: "INIT_ERROR", message: "clientId is required", details: nil))
            return
        }
        
        self.clientId = clientId
        bbpsService = BBPSService(clientId: clientId)
        result(true)
    }

    private func initiate(_ params: [String: Any]?, result: @escaping FlutterResult) {
        guard let service = bbpsService else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call createService first", details: nil))
            return
        }
        guard let params = params else {
            result(FlutterError(code: "INVALID_PARAMS", message: "Params required", details: nil))
            return
        }
        guard let viewController = rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Could not find root view controller", details: nil))
            return
        }
        
        currentResult = result
        
        var payload: [String: Any] = [:]
        for (key, value) in params {
            payload[key] = value
        }
        
        service.initiate(viewController, payload: payload) { [weak self] response in
            guard let self = self else { return }
            guard let responseDict = response as? [String: Any] else { return }
            
            if let eventName = responseDict["event"] as? String {
                let innerPayload = responseDict["payload"]
                self.eventSink?(["event": eventName, "payload": innerPayload ?? [:]])
                
                if eventName == "initiate_result" {
                    self.currentResult?(responseDict)
                    self.currentResult = nil
                }
            } else {
                self.eventSink?(["event": "INITIATE_RESULT", "payload": responseDict])
                self.currentResult?(responseDict)
                self.currentResult = nil
            }
        }
    }
    
    private func process(_ params: [String: Any]?, result: @escaping FlutterResult) {
        guard let service = bbpsService else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call createService first", details: nil))
            return
        }
        
        currentResult = result
        service.process(params ?? [:])
    }
    
    private func terminate(result: @escaping FlutterResult) {
        bbpsService?.terminate()
        bbpsService = nil
        result(true)
    }

    private func onBackPressed(result: @escaping FlutterResult) {
        result(false)
    }
}

extension BbpsFlutterPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
