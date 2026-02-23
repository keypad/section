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
	private var pictureitem: NSMenuItem?
	private var videoitem: NSMenuItem?

	func applicationDidFinishLaunching(_ notification: Notification) {
		Permissions.check()
		overlay = Panel()
		hotkey = Hotkey(handler: self)
		setup()
	}

	private func setup() {
		let tray = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
		if let button = tray.button {
			button.image = Icon.image()
			button.setAccessibilityTitle("Section")
		}

		let menu = NSMenu()
		menu.autoenablesItems = false
		let head = NSMenuItem(title: "Section", action: nil, keyEquivalent: "")
		head.isEnabled = false
		menu.addItem(head)
		menu.addItem(.separator())

		let picture = NSMenuItem(title: "Picture", action: #selector(setpicture), keyEquivalent: "p")
		picture.target = self
		menu.addItem(picture)
		let video = NSMenuItem(title: "Video", action: #selector(setvideo), keyEquivalent: "v")
		video.target = self
		menu.addItem(video)
		menu.addItem(.separator())
		let quit = NSMenuItem(title: "Quit", action: #selector(exit), keyEquivalent: "q")
		quit.target = self
		menu.addItem(quit)
		tray.menu = menu

		self.tray = tray
		self.pictureitem = picture
		self.videoitem = video
		update()
	}

	private func update() {
		pictureitem?.state = video ? .off : .on
		videoitem?.state = video ? .on : .off
	}

	@objc
	private func setpicture() {
		video = false
		update()
		stop()
	}

	@objc
	private func setvideo() {
		video = true
		update()
		if open {
			start()
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
			Task { @MainActor in
				self?.loop()
			}
		}
		loop()
	}

	private func stop() {
		live?.invalidate()
		live = nil
		busy = false
	}

	private func loop() {
		let items = state.items
		guard !items.isEmpty else { return }
		guard !busy else { return }
		busy = true
		Capture.frames(for: items) { [weak self] images in
			defer { self?.busy = false }
			guard !images.isEmpty else { return }
			self?.state.apply(images, animated: false)
		}
	}
}
