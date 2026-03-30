/*
 * MetaWearablesPlugin.swift
 *
 * STUB VERSION - Meta Wearables SDK disabled for App Store.
 * MFi accessory authorization not available until 2026.
 *
 * This stub returns "not available" for all method calls.
 * The full implementation is preserved in git history.
 */

import Flutter
import UIKit

/// Stub plugin - Meta Wearables not available on iOS App Store
@MainActor
public class MetaWearablesPlugin: NSObject, FlutterPlugin {

    private let methodChannel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "obsessiontracker/meta_wearables",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = MetaWearablesPlugin(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // All methods return "not available" since SDK is disabled for App Store
        switch call.method {
        case "initialize":
            result(FlutterError(
                code: "NOT_AVAILABLE",
                message: "Meta Wearables not available on iOS App Store (MFi approval pending until 2026)",
                details: nil
            ))
        case "isAvailable":
            result(false)
        case "getConnectionState":
            result("not_available")
        case "getSessionState":
            result("not_available")
        case "getDevices":
            result([])
        default:
            result(FlutterError(
                code: "NOT_AVAILABLE",
                message: "Meta Wearables not available on iOS App Store",
                details: nil
            ))
        }
    }
}
