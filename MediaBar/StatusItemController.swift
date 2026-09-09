import AppKit

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let quitMenu: NSMenu

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        quitMenu = NSMenu()
        super.init()

        let quit = NSMenuItem(
            title: "Quit Media Bar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitMenu.addItem(quit)

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.toolTip = "Play"
        updateIcon()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackDidChange),
            name: MediaController.playbackDidChange,
            object: MediaController.shared
        )
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            NSMenu.popUpContextMenu(quitMenu, with: NSApp.currentEvent!, for: sender)
            return
        }
        MediaController.shared.togglePlayPause()
        updateIcon()
    }

    @objc private func playbackDidChange() {
        updateIcon()
    }

    private func updateIcon() {
        let playing = MediaController.shared.isPlaying
        let name = playing ? "pause.fill" : "play.fill"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: playing ? "Pause" : "Play")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = playing ? "Pause" : "Play"
    }
}
