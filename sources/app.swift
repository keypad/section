import AppKit

@MainActor
final class App: NSObject, NSApplicationDelegate {
	private var hotkey: Hotkey?
	private var overlay: Panel?
	private var state = SwitcherState()

	func applicationDidFinishLaunching(_ notification: Notification) {
		Permissions.check()
		overlay = Panel()
		overlay?.onConfirm = { [weak self] in self?.confirm() }
		hotkey = Hotkey(handler: self)
	}
}

extension App: HotkeyHandler {
	func show() {
		let screen = Screens.current()
		let items = Windows.list(on: screen)

		if items.isEmpty { return }

		state.reset(with: items)
		overlay?.show(on: screen, state: state)
		Capture.thumbnails(for: items) { [weak self] results in
			self?.state.apply(results)
		}
	}

	func next() {
		state.next()
	}

	func previous() {
		state.previous()
	}

	func confirm() {
		let item = state.selected
		overlay?.hide()
		hotkey?.reset()
		if let item { Focus.activate(item) }
	}

	func cancel() {
		overlay?.hide()
		hotkey?.reset()
	}

	func quickswitch() {
		let screen = Screens.current()
		let items = Windows.list(on: screen)
		guard items.count > 1 else { return }
		Focus.activate(items[1])
	}
}
