import AppKit
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let page = CommandLine.arguments.dropFirst().first ?? "index.html"
        let url = URL(fileURLWithPath: page).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("HTML not found: \(url.path)")
            NSApp.terminate(nil)
            return
        }

        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let selector = NSSelectorFromString("_setUseSystemAppearance:")
        if webView.responds(to: selector), let implementation = webView.method(for: selector) {
            typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
            let set = unsafeBitCast(implementation, to: Setter.self)
            set(webView, selector, true)
            print("Enabled WKWebView system appearance.")
        } else {
            print("This WKWebView does not expose _setUseSystemAppearance:.")
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Liquid Glass · Material Lab"
        window.minSize = NSSize(width: 580, height: 520)
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()

    app.setActivationPolicy(.regular)
    app.delegate = delegate

    withExtendedLifetime(delegate) {
        app.run()
    }
}

