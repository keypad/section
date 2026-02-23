import AppKit
import Carbon.HIToolbox

@MainActor
protocol HotkeyHandler: AnyObject {
	func show()
	func next()
	func previous()
	func confirm()
	func cancel()
	func quickswitch()
}

final class Hotkey: @unchecked Sendable {
	private var tap: CFMachPort?
	private var source: CFRunLoopSource?
	private var timer: Timer?
	private weak var handler: (any HotkeyHandler)?
	private var primed = false
	private var showing = false
	private var option = false
	private var pending: DispatchWorkItem?

	@MainActor
	init(handler: any HotkeyHandler) {
		self.handler = handler
		setup()
	}

	func reset() {
		primed = false
		showing = false
		option = false
		pending?.cancel()
		pending = nil
	}

	@MainActor
	private func setup() {
		let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
		let callback: CGEventTapCallBack = { _, type, event, refcon in
			guard let refcon else { return Unmanaged.passRetained(event) }
			let this = Unmanaged<Hotkey>.fromOpaque(refcon).takeUnretainedValue()
			return this.handle(type: type, event: event)
		}

		let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

		guard let tap = CGEvent.tapCreate(
			tap: .cgSessionEventTap,
			place: .headInsertEventTap,
			options: .defaultTap,
			eventsOfInterest: mask,
			callback: callback,
			userInfo: refcon
		) else { return }

		self.tap = tap
		source = CFMachPortCreateRunLoopSource(nil, tap, 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
		CGEvent.tapEnable(tap: tap, enable: true)

		timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
			self?.reenable()
		}
	}

	private func reenable() {
		guard let tap, !CGEvent.tapIsEnabled(tap: tap) else { return }
		CGEvent.tapEnable(tap: tap, enable: true)
	}

	nonisolated private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
		if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
			reenable()
			return Unmanaged.passRetained(event)
		}

		let flags = event.flags
		let keycode = event.getIntegerValueField(.keyboardEventKeycode)
		let optionDown = flags.contains(.maskAlternate)

		if type == .flagsChanged {
			option = optionDown
			if !optionDown {
				pending?.cancel()
				pending = nil
				if primed && !showing {
					primed = false
					DispatchQueue.main.async { [weak self] in
						self?.handler?.quickswitch()
					}
					return Unmanaged.passRetained(event)
				}
				primed = false
				if showing {
					showing = false
					DispatchQueue.main.async { [weak self] in
						self?.handler?.confirm()
					}
				}
			}
			return Unmanaged.passRetained(event)
		}

		if type == .keyDown && optionDown {
			if keycode == Int64(kVK_Tab) {
				if !primed {
					primed = true
					let task = DispatchWorkItem { [weak self] in
						guard let this = self else { return }
						guard this.primed, this.option, !this.showing else { return }
						this.showing = true
						DispatchQueue.main.async { [weak this] in
							this?.handler?.show()
						}
					}
					pending = task
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: task)
					return nil
				}

				if !showing {
					pending?.cancel()
					pending = nil
					showing = true
					DispatchQueue.main.async { [weak self] in
						self?.handler?.show()
						self?.handler?.next()
					}
				} else {
					let shift = flags.contains(.maskShift)
					DispatchQueue.main.async { [weak self] in
						if shift {
							self?.handler?.previous()
						} else {
							self?.handler?.next()
						}
					}
				}
				return nil
			}

			if keycode == Int64(kVK_Escape) && showing {
				showing = false
				primed = false
				pending?.cancel()
				pending = nil
				DispatchQueue.main.async { [weak self] in
					self?.handler?.cancel()
				}
				return nil
			}
		}

		if type == .keyDown && !optionDown && showing {
			showing = false
			primed = false
			pending?.cancel()
			pending = nil
			DispatchQueue.main.async { [weak self] in
				self?.handler?.cancel()
			}
		}

		return Unmanaged.passRetained(event)
	}

	deinit {
		timer?.invalidate()
		if let tap {
			CGEvent.tapEnable(tap: tap, enable: false)
		}
		if let source {
			CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
		}
	}
}
