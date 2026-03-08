import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var screenObserver: NSObjectProtocol?
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  deinit {
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
    }
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.toolbar = nil
    self.isMovable = false
    self.isOpaque = true
    self.backgroundColor = .black
    self.hasShadow = false
    self.styleMask.remove(.titled)
    self.styleMask.remove(.closable)
    self.styleMask.remove(.miniaturizable)
    self.styleMask.remove(.resizable)
    self.styleMask.insert(.borderless)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.makeMain()
      self.expandAcrossAllDisplays()
      self.makeKeyAndOrderFront(nil)
      self.makeFirstResponder(flutterViewController.view)
    }

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.expandAcrossAllDisplays()
    }
  }

  private func expandAcrossAllDisplays() {
    let targetFrame: NSRect
    if NSScreen.screensHaveSeparateSpaces {
      guard let currentScreenFrame = (self.screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else {
        return
      }
      targetFrame = currentScreenFrame
    } else {
      let allScreensFrame = NSScreen.screens.reduce(NSRect.null) { partial, screen in
        partial.union(screen.visibleFrame)
      }
      guard !allScreensFrame.isNull else {
        return
      }
      targetFrame = allScreensFrame
    }

    guard !targetFrame.isNull else {
      return
    }

    setFrame(targetFrame, display: true)
    orderFrontRegardless()
  }
}
