import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up environment detection method channel
    setupEnvironmentChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Set up method channel for environment detection (TestFlight/Sandbox)
  private func setupEnvironmentChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.obsessiontracker.app/environment",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "isSandbox" {
        result(self?.isRunningInSandbox() ?? false)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Check if the app is running from TestFlight or Sandbox environment.
  /// TestFlight apps have a receipt URL containing "sandboxReceipt".
  private func isRunningInSandbox() -> Bool {
    guard let receiptURL = Bundle.main.appStoreReceiptURL else {
      return false
    }
    return receiptURL.path.contains("sandboxReceipt")
  }

  // Handle file URLs specially - need to copy from security-scoped location to local sandbox
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    NSLog("[AppDelegate] Received URL: \(url)")

    // Check if it's a file URL that needs special handling
    if url.isFileURL {
      let supportedExtensions = ["obstrack", "obk", "gpx", "kml"]
      let ext = url.pathExtension.lowercased()

      if supportedExtensions.contains(ext) {
        NSLog("[AppDelegate] Handling file URL with extension: \(ext)")
        handleSecurityScopedFile(url)
        return true
      }
    }

    // Let app_links or other plugins handle non-file URLs
    return super.application(app, open: url, options: options)
  }

  /// Handle a security-scoped file URL by copying to local sandbox
  private func handleSecurityScopedFile(_ url: URL) {
    // Start accessing security-scoped resource
    let didStartAccessing = url.startAccessingSecurityScopedResource()
    NSLog("[AppDelegate] Started security scoped access: \(didStartAccessing)")

    defer {
      if didStartAccessing {
        url.stopAccessingSecurityScopedResource()
        NSLog("[AppDelegate] Stopped security scoped access")
      }
    }

    do {
      // Use the app's temporary directory for incoming files
      // (Documents/Inbox is managed by iOS and we can't create it ourselves)
      let tempDir = FileManager.default.temporaryDirectory
      let importsDir = tempDir.appendingPathComponent("imports")

      // Create imports directory if needed
      try FileManager.default.createDirectory(at: importsDir, withIntermediateDirectories: true)

      // Generate unique filename to avoid conflicts
      let fileName = url.lastPathComponent
      var destinationURL = importsDir.appendingPathComponent(fileName)

      // If file already exists, remove it first (temp files)
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
      }

      // Copy file to local sandbox
      try FileManager.default.copyItem(at: url, to: destinationURL)
      NSLog("[AppDelegate] Copied file to: \(destinationURL.path)")

      // Send the LOCAL file path to Flutter via method channel
      sendFileToFlutter(destinationURL.path)

    } catch {
      NSLog("[AppDelegate] Error copying file: \(error)")
    }
  }

  /// Send file path to Flutter via method channel
  private func sendFileToFlutter(_ filePath: String) {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("[AppDelegate] No FlutterViewController found")
      return
    }

    let channel = FlutterMethodChannel(
      name: "obsessiontracker/incoming_file",
      binaryMessenger: controller.binaryMessenger
    )

    channel.invokeMethod("onFileReceived", arguments: filePath)
    NSLog("[AppDelegate] Sent file to Flutter: \(filePath)")
  }
}
