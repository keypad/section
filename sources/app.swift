import AppKit

@MainActor
final class App: NSObject, NSApplicationDelegate {
	private var hotkey: Hotkey?
	private var overlay: Panel?
	private var state = SwitcherState()
	private var live: Timer?
	private var busy = false
	private var open = false
	private var video = false
	private var tray: NSStatusItem?
	private var menu: NSMenu?
	private var item: NSMenuItem?

	func applicationDidFinishLaunching(_ notification: Notification) {
		Permissions.check()
		overlay = Panel()
		hotkey = Hotkey(handler: self)
		setup()
	}

	private func setup() {
		let tray = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
		if let button = tray.button {
			button.image = NSImage(
				systemSymbolName: "rectangle.on.rectangle",
				accessibilityDescription: "section"
			)
		}

		let menu = NSMenu()
		let item = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
		item.target = self
		menu.addItem(item)
		menu.addItem(.separator())
		let quit = NSMenuItem(title: "quit", action: #selector(exit), keyEquivalent: "q")
		quit.target = self
		menu.addItem(quit)
		tray.menu = menu

		self.tray = tray
		self.menu = menu
		self.item = item
		update()
	}

	private func update() {
		item?.title = video ? "video: on" : "video: off"
	}

	@objc
	private func toggle() {
		video.toggle()
		update()
		if video, open {
			start()
		} else {
			stop()
		}
	}

	@objc
	private func exit() {
		NSApplication.shared.terminate(nil)
	}
}

extension App: HotkeyHandler {
	func show() {
		let screen = Screens.current()
		let items = Windows.list(on: screen)

		if items.isEmpty { return }

		state.reset(with: items)
		overlay?.show(on: screen, state: state)
		open = true
		Capture.thumbnails(for: items, focus: state.index) { [weak self] results in
			self?.state.apply(results, animated: true)
		}
		if video { start() }
	}

	func next() {
		state.next()
		if video { loop() }
	}

	func previous() {
		state.previous()
		if video { loop() }
	}

	func confirm() {
		let item = state.selected
		overlay?.hide()
		hotkey?.reset()
		open = false
		stop()
		if let item { Focus.activate(item) }
	}

	func cancel() {
		overlay?.hide()
		hotkey?.reset()
		open = false
		stop()
	}

	func quickswitch() {
		let screen = Screens.current()
		let items = Windows.list(on: screen)
		guard items.count > 1 else { return }
		Focus.activate(items[1])
	}

	private func start() {
		stop()
		live = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
			self?.loop()
		}
		loop()
	}

	private func stop() {
		live?.invalidate()
		live = nil
		busy = false
	}

	private func loop() {
		guard let item = state.selected else { return }
		guard !busy else { return }
		busy = true
		Capture.thumbnail(for: item) { [weak self] image in
			defer { self?.busy = false }
			guard let image else { return }
			self?.state.apply([item.id: image], animated: false)
		}
	}
}
