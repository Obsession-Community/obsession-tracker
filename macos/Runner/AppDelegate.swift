import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    setupEnvironmentChannel()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Set up method channel for environment detection (TestFlight/Sandbox)
  private func setupEnvironmentChannel() {
    guard let mainWindow = NSApplication.shared.mainWindow,
          let flutterViewController = mainWindow.contentViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.obsessiontracker.app/environment",
      binaryMessenger: flutterViewController.engine.binaryMessenger
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
  /// Mac App Store sandbox apps have a receipt URL containing "sandboxReceipt".
  private func isRunningInSandbox() -> Bool {
    guard let receiptURL = Bundle.main.appStoreReceiptURL else {
      return false
    }
    return receiptURL.path.contains("sandboxReceipt")
  }
}
