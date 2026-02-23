import AppKit
import CoreImage
import CoreMedia
import ScreenCaptureKit

@MainActor
final class Live {
	private var box: Box?
	private var pending: WindowItem?
	private var running = false
	private let apply: @MainActor ([CGWindowID: NSImage]) -> Void

	init(apply: @escaping @MainActor ([CGWindowID: NSImage]) -> Void) {
		self.apply = apply
	}

	func start(item: WindowItem?) {
		guard let item else {
			stop()
			return
		}
		if box == nil {
			box = Box { [weak self] id, image in
				DispatchQueue.main.async {
					if let self {
						self.apply([id: image])
					}
				}
			}
		}
		pending = item
		guard !running else { return }
		running = true
		Task { @MainActor [weak self] in
			await self?.drain()
		}
	}

	func stop() {
		pending = nil
		running = false
		guard let box else { return }
		self.box = nil
		Task { @MainActor in
			await box.stop()
		}
	}

	private func drain() async {
		while true {
			guard let item = pending else {
				running = false
				return
			}
			pending = nil
			await box?.set(item)
		}
	}
}

final class Box: NSObject, SCStreamOutput, @unchecked Sendable {
	private struct Meta {
		let id: CGWindowID
		let bounds: CGRect
	}

	private let push: @Sendable (CGWindowID, NSImage) -> Void
	private let queue = DispatchQueue(label: "section.live")
	private let context = CIContext(options: [.cacheIntermediates: false])
	private let lock = NSLock()
	private var meta: Meta?
	private var switching = false
	private var skip = 0
	private var last: CFAbsoluteTime = 0
	private var staged: (CGWindowID, NSImage)?
	private var scheduled = false
	private var stream: SCStream?
	private var table: [CGWindowID: SCWindow] = [:]
	private var active: CGWindowID?
	private var size: CGSize?

	init(push: @escaping @Sendable (CGWindowID, NSImage) -> Void) {
		self.push = push
	}

	@MainActor
	func set(_ item: WindowItem) async {
		drop()
		if active == item.id {
			setmeta(Meta(id: item.id, bounds: item.bounds))
			return
		}
		if stream == nil {
			let ok = await open(item.id, bounds: item.bounds)
			if ok {
				active = item.id
				setmeta(Meta(id: item.id, bounds: item.bounds))
				setskip(3)
			}
			return
		}
		setswitching(true)
		let ok = await update(item.id, bounds: item.bounds)
		setswitching(false)
		if ok {
			active = item.id
			setmeta(Meta(id: item.id, bounds: item.bounds))
			setskip(3)
		}
	}

	@MainActor
	func stop() async {
		guard let stream else { return }
		self.stream = nil
		try? stream.removeStreamOutput(self, type: .screen)
		try? await stream.stopCapture()
		table = [:]
		active = nil
		size = nil
		clear()
	}

	@MainActor
	private func open(_ id: CGWindowID, bounds: CGRect) async -> Bool {
		guard let window = await window(id) else { return false }

		let filter = SCContentFilter(desktopIndependentWindow: window)
		let config = config(bounds)
		let stream = SCStream(filter: filter, configuration: config, delegate: nil)
		self.stream = stream
		size = CGSize(width: config.width, height: config.height)
		try? stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
		try? await stream.startCapture()
		return true
	}

	@MainActor
	private func update(_ id: CGWindowID, bounds: CGRect) async -> Bool {
		guard let stream else {
			return await open(id, bounds: bounds)
		}
		guard let window = await window(id) else { return false }
		let filter = SCContentFilter(desktopIndependentWindow: window)
		let next = config(bounds)
		let nextsize = CGSize(width: next.width, height: next.height)
		do {
			if size != nextsize {
				try await stream.updateConfiguration(next)
				size = nextsize
			}
			try await stream.updateContentFilter(filter)
			return true
		} catch {
			try? await stream.stopCapture()
			self.stream = nil
			size = nil
			return await open(id, bounds: bounds)
		}
	}

	@MainActor
	private func refresh() async {
		let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
		guard let windows = content?.windows else {
			table = [:]
			return
		}
		table = Dictionary(uniqueKeysWithValues: windows.map { ($0.windowID, $0) })
	}

	@MainActor
	private func window(_ id: CGWindowID) async -> SCWindow? {
		if let value = table[id] { return value }
		await refresh()
		return table[id]
	}

	private func config(_ bounds: CGRect) -> SCStreamConfiguration {
		let config = SCStreamConfiguration()
		let cap: CGFloat = 320
		let w = bounds.width
		let h = bounds.height
		let fit = min(cap / w, cap / h, 1)
		config.width = Int(w * fit * 2)
		config.height = Int(h * fit * 2)
		config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
		config.queueDepth = 1
		config.showsCursor = false
		config.ignoreShadowsSingleWindow = true
		config.shouldBeOpaque = true
		return config
	}

	private func setmeta(_ value: Meta) {
		lock.lock()
		meta = value
		lock.unlock()
	}

	private func getmeta() -> Meta? {
		lock.lock()
		let value = meta
		lock.unlock()
		return value
	}

	private func setswitching(_ value: Bool) {
		lock.lock()
		switching = value
		lock.unlock()
	}

	private func getswitching() -> Bool {
		lock.lock()
		let value = switching
		lock.unlock()
		return value
	}

	private func clear() {
		lock.lock()
		meta = nil
		switching = false
		skip = 0
		last = 0
		staged = nil
		scheduled = false
		lock.unlock()
	}

	private func setskip(_ value: Int) {
		lock.lock()
		skip = value
		lock.unlock()
	}

	private func drop() {
		lock.lock()
		staged = nil
		lock.unlock()
	}

	private func shouldskip() -> Bool {
		lock.lock()
		if skip > 0 {
			skip -= 1
			lock.unlock()
			return true
		}
		lock.unlock()
		return false
	}

	private func allowpush() -> Bool {
		let now = CFAbsoluteTimeGetCurrent()
		lock.lock()
		if now - last < 1.0 / 30.0 {
			lock.unlock()
			return false
		}
		last = now
		lock.unlock()
		return true
	}

	func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
		guard outputType == .screen else { return }
		guard !getswitching() else { return }
		guard complete(sampleBuffer) else { return }
		guard let current = getmeta() else { return }
		guard !shouldskip() else { return }
		guard allowpush() else { return }
		autoreleasepool {
			guard let buffer = sampleBuffer.imageBuffer else { return }
			let image = CIImage(cvImageBuffer: buffer)
			guard let cg = context.createCGImage(image, from: image.extent) else { return }
			let ns = NSImage(
				cgImage: cg,
				size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2)
			)
			stage(current.id, ns)
		}
	}

	private func stage(_ id: CGWindowID, _ image: NSImage) {
		var run = false
		lock.lock()
		staged = (id, image)
		if !scheduled {
			scheduled = true
			run = true
		}
		lock.unlock()

		guard run else { return }
		DispatchQueue.main.async { [weak self] in
			self?.flush()
		}
	}

	private func flush() {
		while true {
			lock.lock()
			guard let next = staged else {
				scheduled = false
				lock.unlock()
				return
			}
			staged = nil
			lock.unlock()
			push(next.0, next.1)
		}
	}

	private func complete(_ sampleBuffer: CMSampleBuffer) -> Bool {
		guard let array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
			let attachments = array.first,
			let raw = attachments[.status] as? Int,
			let status = SCFrameStatus(rawValue: raw)
		else { return false }
		return status == .complete
	}

}
