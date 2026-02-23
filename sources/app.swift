import AppKit

@MainActor
final class App: NSObject, NSApplicationDelegate {
	private var hotkey: Hotkey?
	private var overlay: Panel?
	private var state = SwitcherState()
	private var live: Live?
	private var open = false
	private var video = true
	private var permonitor = false
	private var retunework: DispatchWorkItem?
	private var laststep: CFAbsoluteTime = 0
	private var session = 0
	private var refreshid = 0
	private var videotimer: Timer?
	private var videobusy = false
	private var tray: NSStatusItem?
	private var pictureitem: NSMenuItem?
	private var videoitem: NSMenuItem?
	private var monitoritem: NSMenuItem?
	private var loginitem: NSMenuItem?

	func applicationDidFinishLaunching(_ notification: Notification) {
		Permissions.check()
		overlay = Panel()
		overlay?.onspace = { [weak self] in
			guard let self else { return }
			open = false
			session += 1
			stop()
			hotkey?.reset()
		}
		hotkey = Hotkey(handler: self)
		live = Live { [weak self] images in
			guard let self else { return }
			guard open, video else { return }
			guard let selected = state.selected?.id else { return }
			let current = images.filter { $0.key == selected }
			guard !current.isEmpty else { return }
			state.apply(current, animated: false)
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
		let monitor = NSMenuItem(title: "Per Monitor", action: #selector(togglemonitor), keyEquivalent: "m")
		monitor.target = self
		menu.addItem(monitor)
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
		self.monitoritem = monitor
		self.loginitem = login
		update()
	}

	private func update() {
		pictureitem?.state = video ? .off : .on
		videoitem?.state = video ? .on : .off
		monitoritem?.state = permonitor ? .on : .off
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
			startvideo()
		}
	}

	@objc
	private func togglelogin() {
		let next = !Launch.enabled()
		_ = Launch.set(next)
		update()
	}

	@objc
	private func togglemonitor() {
		permonitor.toggle()
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
		let items = windows()

		if items.isEmpty { return }

		state.reset(with: items)
		session += 1
		refreshid = 0
		overlay?.show(on: screen, state: state)
		open = true
		applysnapshot(items: items, animated: true)
		if video {
			start()
			startvideo()
		}
	}

	func next() {
		step(1)
	}

	func previous() {
		step(-1)
	}

	func confirm() {
		let item = state.selected
		overlay?.hide()
		hotkey?.reset()
		open = false
		session += 1
		stop()
		if let item { Focus.activate(item) }
	}

	func cancel() {
		overlay?.hide()
		hotkey?.reset()
		open = false
		session += 1
		stop()
	}

	func quickswitch() {
		let items = windows()
		guard items.count > 1 else { return }
		Focus.activate(items[1])
	}

	private func start() {
		live?.start(item: state.selected)
	}

	private func stop() {
		retunework?.cancel()
		retunework = nil
		stopvideo()
		live?.stop()
	}

	private func queuevideo() {
		retunework?.cancel()
		let work = DispatchWorkItem { [weak self] in
			self?.retune()
		}
		retunework = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
	}

	private func step(_ direction: Int) {
		let now = CFAbsoluteTimeGetCurrent()
		if now - laststep < 0.10 { return }
		laststep = now
		if direction > 0 {
			state.next()
		} else {
			state.previous()
		}
		if video { queuevideo() }
	}

	private func retune() {
		live?.start(item: state.selected)
	}

	private func refresh() {
		let items = state.items
		guard !items.isEmpty else { return }
		applysnapshot(items: items, animated: false)
	}

	private func windows() -> [WindowItem] {
		if permonitor {
			return Windows.list(on: Screens.current())
		}
		return Windows.list(on: nil)
	}

	private func applysnapshot(items: [WindowItem], animated: Bool) {
		let ticket = session
		refreshid += 1
		let refresh = refreshid
		let focus = state.index
		let limit = items.count
		Capture.thumbnails(for: items, focus: focus, limit: limit) { [weak self] results in
			guard let self else { return }
			guard open else { return }
			guard ticket == session else { return }
			guard refresh == refreshid else { return }
			state.apply(results, animated: animated)
		}
	}

	private func startvideo() {
		stopvideo()
		videotimer = Timer.scheduledTimer(withTimeInterval: 0.60, repeats: true) { [weak self] _ in
			self?.videotick()
		}
	}

	private func stopvideo() {
		videotimer?.invalidate()
		videotimer = nil
		videobusy = false
	}

	private func videotick() {
		guard open, video else { return }
		guard retunework == nil else { return }
		guard !videobusy else { return }
		let items = state.items
		guard !items.isEmpty else { return }
		videobusy = true
		let ticket = session
		let selected = state.selected?.id
		Capture.frames(for: items) { [weak self] results in
			guard let self else { return }
			self.videobusy = false
			guard self.open else { return }
			guard ticket == self.session else { return }
			if let selected {
				self.state.apply(results.filter { $0.key != selected }, animated: false)
				return
			}
			self.state.apply(results, animated: false)
		}
	}
}
