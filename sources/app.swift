import AppKit

@MainActor
final class App: NSObject, NSApplicationDelegate {
	private var hotkey: Hotkey?
	private var overlay: Panel?
	private var state = SwitcherState()
	private var live: Live?
	private var open = false
	private var video = false
	private var tray: NSStatusItem?
	private var pictureitem: NSMenuItem?
	private var videoitem: NSMenuItem?
	private var loginitem: NSMenuItem?

	func applicationDidFinishLaunching(_ notification: Notification) {
		Permissions.check()
		overlay = Panel()
		hotkey = Hotkey(handler: self)
		live = Live { [weak self] images in
			self?.state.apply(images, animated: false)
		}
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
		let login = NSMenuItem(title: "Launch At Login", action: #selector(togglelogin), keyEquivalent: "l")
		login.target = self
		menu.addItem(login)
		menu.addItem(.separator())
		let quit = NSMenuItem(title: "Quit", action: #selector(exit), keyEquivalent: "q")
		quit.target = self
		menu.addItem(quit)
		tray.menu = menu

		self.tray = tray
		self.pictureitem = picture
		self.videoitem = video
		self.loginitem = login
		update()
	}

	private func update() {
		pictureitem?.state = video ? .off : .on
		videoitem?.state = video ? .on : .off
		loginitem?.state = Launch.enabled() ? .on : .off
		loginitem?.isEnabled = Launch.available()
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
	private func togglelogin() {
		let next = !Launch.enabled()
		_ = Launch.set(next)
		update()
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
		if video { retune() }
	}

	func previous() {
		state.previous()
		if video { retune() }
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
		live?.start(item: state.selected)
		refresh()
	}

	private func stop() {
		live?.stop()
	}

	private func retune() {
		live?.start(item: state.selected)
		refresh()
	}

	private func refresh() {
		let items = state.items
		guard !items.isEmpty else { return }
		Capture.thumbnails(for: items, focus: state.index) { [weak self] results in
			self?.state.apply(results, animated: false)
		}
	}
}
