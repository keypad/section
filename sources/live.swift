import AppKit
import CoreImage
import CoreMedia
import ScreenCaptureKit

@MainActor
final class Live {
	private var box: Box?
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
		Task { @MainActor [weak self] in
			await self?.box?.set(item)
		}
	}

	func stop() {
		guard let box else { return }
		self.box = nil
		Task { @MainActor in
			await box.stop()
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
		if active == item.id {
			setmeta(Meta(id: item.id, bounds: item.bounds))
			return
		}
		if stream == nil {
			let ok = await open(item.id, bounds: item.bounds)
			if ok {
				active = item.id
				setmeta(Meta(id: item.id, bounds: item.bounds))
			}
			return
		}
		setswitching(true)
		let ok = await update(item.id, bounds: item.bounds)
		setswitching(false)
		if ok {
			active = item.id
			setmeta(Meta(id: item.id, bounds: item.bounds))
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
		let cap: CGFloat = 480
		let w = bounds.width
		let h = bounds.height
		let fit = min(cap / w, cap / h, 1)
		config.width = Int(w * fit * 2)
		config.height = Int(h * fit * 2)
		config.minimumFrameInterval = CMTime(value: 1, timescale: 10)
		config.queueDepth = 2
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
		last = 0
		staged = nil
		scheduled = false
		lock.unlock()
	}

	private func allowpush() -> Bool {
		let now = CFAbsoluteTimeGetCurrent()
		lock.lock()
		if now - last < 1.0 / 10.0 {
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
		guard allowpush() else { return }
		autoreleasepool {
			guard let buffer = sampleBuffer.imageBuffer else { return }
			let image = CIImage(cvImageBuffer: buffer)
			guard let cg = context.createCGImage(image, from: image.extent) else { return }
			guard let cropped = crop(cg, bounds: current.bounds) else { return }
			let ns = NSImage(
				cgImage: cropped,
				size: NSSize(width: CGFloat(cropped.width) / 2, height: CGFloat(cropped.height) / 2)
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

	private func cardwidth(_ bounds: CGRect) -> CGFloat {
		let body = max(CGFloat(160 - 28), 1)
		let ratio = bounds.width / max(bounds.height, 1)
		let value = body * ratio
		return min(max(value, 140), 320)
	}

	private func crop(_ image: CGImage, bounds: CGRect) -> CGImage? {
		let base = trim(image) ?? image
		let targetw = cardwidth(bounds)
		let targeth = max(CGFloat(160 - 28), 1)
		let targetr = targetw / targeth
		let sw = CGFloat(base.width)
		let sh = CGFloat(base.height)
		let sr = sw / sh
		var rect = CGRect(x: 0, y: 0, width: sw, height: sh)
		if sr > targetr {
			let w = floor(sh * targetr)
			let x = floor((sw - w) / 2)
			rect = CGRect(x: x, y: 0, width: w, height: sh)
		} else if sr < targetr {
			let h = floor(sw / targetr)
			let y = max(sh - h, 0)
			rect = CGRect(x: 0, y: y, width: sw, height: h)
		}
		return base.cropping(to: rect)
	}

	private func trim(_ image: CGImage) -> CGImage? {
		guard let data = image.dataProvider?.data else { return image }
		guard let bytes = CFDataGetBytePtr(data) else { return image }
		let width = image.width
		let height = image.height
		let row = image.bytesPerRow
		let pixel = max(image.bitsPerPixel / 8, 4)
		guard width > 8, height > 8 else { return image }
		let limitx = max(width / 4, 1)
		let limity = max(height / 4, 1)

		func dark(_ x: Int, _ y: Int) -> Bool {
			let index = y * row + x * pixel
			let r = Int(bytes[index + 0])
			let g = Int(bytes[index + 1])
			let b = Int(bytes[index + 2])
			return r + g + b < 24
		}

		func col(_ x: Int) -> Bool {
			var y = 0
			while y < height {
				if !dark(x, y) { return false }
				y += 8
			}
			return true
		}

		func rowdark(_ y: Int) -> Bool {
			var x = 0
			while x < width {
				if !dark(x, y) { return false }
				x += 8
			}
			return true
		}

		var left = 0
		while left < limitx && col(left) { left += 1 }
		var right = 0
		while right < limitx && col(width - 1 - right) { right += 1 }
		var top = 0
		while top < limity && rowdark(height - 1 - top) { top += 1 }
		var bottom = 0
		while bottom < limity && rowdark(bottom) { bottom += 1 }

		if left == 0 && right == 0 && top == 0 && bottom == 0 { return image }
		let x = left
		let y = bottom
		let w = width - left - right
		let h = height - top - bottom
		guard w > 16, h > 16 else { return image }
		let rect = CGRect(x: x, y: y, width: w, height: h)
		return image.cropping(to: rect) ?? image
	}
}
