import AppKit
import SwiftUI

@MainActor
final class Overlay: NSPanel {
	init(frame: NSRect) {
		super.init(
			contentRect: frame,
			styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
			backing: .buffered,
			defer: false
		)
		isOpaque = false
		backgroundColor = .clear
		level = .popUpMenu
		isFloatingPanel = true
		hidesOnDeactivate = false
		isReleasedWhenClosed = false
		isMovableByWindowBackground = false
		hasShadow = true
		collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
	}

	override var canBecomeKey: Bool { true }
	override var canBecomeMain: Bool { false }
}

@MainActor
final class Panel {
	private var window: Overlay?
	private var hosting: NSHostingView<SwitcherView>?
	private var state: SwitcherState?
	private var observer: Any?
	var onConfirm: (() -> Void)?

	func setup() {
		observer = NSWorkspace.shared.notificationCenter.addObserver(
			forName: NSWorkspace.activeSpaceDidChangeNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				self?.hide()
			}
		}
	}

	func show(on screen: NSScreen, state: SwitcherState) {
		if observer == nil { setup() }
		self.state = state
		dismiss()

		let count = state.items.count
		let columns = min(max(count, 1), 4)
		let rows = (count + columns - 1) / columns
		let cardW: CGFloat = 200
		let cardH: CGFloat = 160
		let spacing: CGFloat = 12
		let padding: CGFloat = 24

		let width = CGFloat(columns) * cardW + CGFloat(columns - 1) * spacing + padding * 2
		let height = CGFloat(rows) * cardH + CGFloat(rows - 1) * spacing + padding * 2

		let x = screen.frame.midX - width / 2
		let y = screen.frame.midY - height / 2
		let frame = NSRect(x: x, y: y, width: width, height: height)

		let panel = Overlay(frame: frame)

		let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
		blur.material = .hudWindow
		blur.state = .active
		blur.blendingMode = .behindWindow
		blur.wantsLayer = true
		blur.layer?.cornerRadius = 16
		blur.layer?.masksToBounds = true

		let view = SwitcherView(state: state, onConfirm: { [weak self] in self?.onConfirm?() })
		let hostView = NSHostingView(rootView: view)
		hosting = hostView

		blur.addSubview(hostView)
		hostView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			hostView.topAnchor.constraint(equalTo: blur.topAnchor),
			hostView.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
			hostView.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
			hostView.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
		])

		panel.contentView = blur
		panel.alphaValue = 0
		panel.orderFrontRegardless()

		NSAnimationContext.runAnimationGroup { ctx in
			ctx.duration = 0.15
			panel.animator().alphaValue = 1
		}

		self.window = panel
	}

	private func dismiss() {
		window?.orderOut(nil)
		window = nil
		hosting = nil
	}

	func hide() {
		guard let window else { return }
		NSAnimationContext.runAnimationGroup({ ctx in
			ctx.duration = 0.1
			window.animator().alphaValue = 0
		}, completionHandler: { [weak self] in
			MainActor.assumeIsolated {
				self?.dismiss()
			}
		})
	}
}
