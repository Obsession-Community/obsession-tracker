import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let windowFrameKey = "ObsessionTrackerWindowFrame"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Configure window for desktop experience
    self.minSize = NSSize(width: 1024, height: 768)
    self.title = "Obsession Tracker"

    // Enable standard window features
    self.styleMask.insert(.resizable)
    self.styleMask.insert(.miniaturizable)
    self.styleMask.insert(.closable)
    self.styleMask.insert(.titled)

    // Restore saved window frame or use default
    if let savedFrameString = UserDefaults.standard.string(forKey: windowFrameKey) {
      self.setFrame(from: savedFrameString)
    } else {
      // Default initial size for new installations
      let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
      let defaultWidth: CGFloat = 1280
      let defaultHeight: CGFloat = 800
      let newFrame = NSRect(
        x: (screenFrame.width - defaultWidth) / 2 + screenFrame.origin.x,
        y: (screenFrame.height - defaultHeight) / 2 + screenFrame.origin.y,
        width: defaultWidth,
        height: defaultHeight
      )
      self.setFrame(newFrame, display: true)
    }

    // Enable automatic window frame saving
    self.setFrameAutosaveName("ObsessionTrackerMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func close() {
    // Save window frame before closing
    UserDefaults.standard.set(self.frameDescriptor, forKey: windowFrameKey)
    super.close()
  }
}
