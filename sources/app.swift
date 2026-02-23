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
		print("section ready")
	}
}

extension App: HotkeyHandler {
	func show() {
		let screen = Screens.current()
		let items = Windows.list(on: screen)
		print("show: \(items.count) windows [\(items.map { "\($0.owner):\($0.name)" }.joined(separator: ", "))]")

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
		guard let item = state.selected else {
			overlay?.hide()
			return
		}
		overlay?.hide()
		Focus.activate(item)
	}

	func cancel() {
		overlay?.hide()
	}

	func quickswitch() {
		let screen = Screens.current()
		let items = Windows.list(on: screen)
		guard items.count > 1 else { return }
		Focus.activate(items[1])
	}
}
