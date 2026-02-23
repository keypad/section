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
		stop()
		guard let item else { return }
		Task { @MainActor [weak self] in
			await self?.open(item)
		}
	}

	func stop() {
		guard let box else { return }
		self.box = nil
		Task { @MainActor in
			await box.stop()
		}
	}

	private func open(_ item: WindowItem) async {
		let box = Box(item: item) { [weak self] id, image in
			Task { @MainActor in
				self?.apply([id: image])
			}
		}
		self.box = box
		await box.start()
	}
}

final class Box: NSObject, SCStreamOutput {
	private let item: WindowItem
	private let push: @Sendable (CGWindowID, NSImage) -> Void
	private let queue: DispatchQueue
	private let context: CIContext
	private var stream: SCStream?

	init(item: WindowItem, push: @escaping @Sendable (CGWindowID, NSImage) -> Void) {
		self.item = item
		self.push = push
		self.queue = DispatchQueue(label: "section.live.\(item.id)")
		self.context = CIContext()
	}

	@MainActor
	func start() async {
		await open()
	}

	@MainActor
	func stop() async {
		guard let stream else { return }
		self.stream = nil
		try? await stream.stopCapture()
	}

	@MainActor
	private func open() async {
		let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
		guard let windows = content?.windows else { return }
		guard let window = windows.first(where: { $0.windowID == item.id }) else { return }

		let filter = SCContentFilter(desktopIndependentWindow: window)
		let config = SCStreamConfiguration()

		let cap: CGFloat = 480
		let w = item.bounds.width
		let h = item.bounds.height
		let fit = min(cap / w, cap / h, 1)

		config.width = Int(w * fit * 2)
		config.height = Int(h * fit * 2)
		config.minimumFrameInterval = CMTime(value: 1, timescale: 10)
		config.queueDepth = 2
		config.showsCursor = false
		config.ignoreShadowsSingleWindow = true
		config.shouldBeOpaque = true

		let stream = SCStream(filter: filter, configuration: config, delegate: nil)
		self.stream = stream
		try? stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
		try? await stream.startCapture()
	}

	func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
		guard outputType == .screen else { return }
		guard let buffer = sampleBuffer.imageBuffer else { return }
		let image = CIImage(cvImageBuffer: buffer)
		let rect = image.extent
		guard let cg = context.createCGImage(image, from: rect) else { return }

		let body: CGFloat = 160 - 28
		let width = max(Int(Grid.width(item, height: 160, bar: 28) * 2), 1)
		let height = max(Int(body * 2), 1)
		guard let out = fit(cg, width: width, height: height) else { return }
		let ns = NSImage(
			cgImage: out,
			size: NSSize(width: CGFloat(width) / 2, height: CGFloat(height) / 2)
		)
		push(item.id, ns)
	}

	private func fit(_ image: CGImage, width: Int, height: Int) -> CGImage? {
		let sw = CGFloat(image.width)
		let sh = CGFloat(image.height)
		let dw = CGFloat(width)
		let dh = CGFloat(height)
		let sr = sw / sh
		let dr = dw / dh

		var src = CGRect(x: 0, y: 0, width: sw, height: sh)
		if sr > dr {
			let cw = floor(sh * dr)
			let x = floor((sw - cw) / 2)
			src = CGRect(x: x, y: 0, width: cw, height: sh)
		} else if sr < dr {
			let ch = floor(sw / dr)
			let y = max(sh - ch, 0)
			src = CGRect(x: 0, y: y, width: sw, height: ch)
		}

		guard let crop = image.cropping(to: src) else { return nil }
		let color = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: color,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }

		context.interpolationQuality = .high
		context.setFillColor(CGColor(gray: 0.06, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: width, height: height))
		context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
		return context.makeImage()
	}
}
