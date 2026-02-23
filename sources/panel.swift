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
		hasShadow = false
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
	var onspace: (() -> Void)?

	func setup() {
		observer = NSWorkspace.shared.notificationCenter.addObserver(
			forName: NSWorkspace.activeSpaceDidChangeNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				guard let self else { return }
				guard self.window != nil else { return }
				self.dismiss()
				self.onspace?()
			}
		}
	}

	func show(on screen: NSScreen, state: SwitcherState) {
		if observer == nil { setup() }
		self.state = state
		dismiss()

		let count = state.items.count
		let columns = min(max(count, 1), 4)
		let cardH: CGFloat = 160
		let bar: CGFloat = 28
		let spacing: CGFloat = 12
		let padding: CGFloat = 24

		let rows = Grid.rows(state.items, count: columns)
		let width = rows.reduce(CGFloat(0)) { total, row in
			let cards = row.reduce(CGFloat(0)) { value, item in
				value + Grid.width(item, height: cardH, bar: bar)
			}
			let gaps = CGFloat(max(row.count - 1, 0)) * spacing
			return max(total, cards + gaps)
		} + padding * 2
		let rowcount = rows.count
		let height = CGFloat(rowcount) * cardH + CGFloat(max(rowcount - 1, 0)) * spacing + padding * 2

		let x = screen.frame.midX - width / 2
		let y = screen.frame.midY - height / 2
		let frame = NSRect(x: x, y: y, width: width, height: height)

		let panel = Overlay(frame: frame)
		let clip = NSView(frame: NSRect(origin: .zero, size: frame.size))
		clip.wantsLayer = true
		clip.layer?.cornerRadius = 16
		clip.layer?.cornerCurve = .continuous
		clip.layer?.masksToBounds = true

		let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
		blur.material = .hudWindow
		blur.state = .active
		blur.blendingMode = .behindWindow

		let view = SwitcherView(state: state)
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

		clip.addSubview(blur)
		blur.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			blur.topAnchor.constraint(equalTo: clip.topAnchor),
			blur.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
			blur.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
			blur.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
		])

		panel.contentView = clip
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
