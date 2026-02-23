import AppKit
import ScreenCaptureKit

enum Capture {
	static func thumbnails(for items: [WindowItem], completion: @escaping @MainActor @Sendable ([CGWindowID: NSImage]) -> Void) {
		let lookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
		Task {
			var results: [CGWindowID: NSImage] = [:]

			let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
			guard let windows = content?.windows else {
				await MainActor.run { completion(results) }
				return
			}

			for window in windows {
				let wid = window.windowID
				guard let item = lookup[wid] else { continue }

				let filter = SCContentFilter(desktopIndependentWindow: window)
				let config = SCStreamConfiguration()

				let maxDim: CGFloat = 720
				let w = item.bounds.width
				let h = item.bounds.height
				let fit = min(maxDim / w, maxDim / h, 1)

				config.width = Int(w * fit * 2)
				config.height = Int(h * fit * 2)
				config.scalesToFit = false
				config.showsCursor = false
				config.ignoreShadowsSingleWindow = true

				if let image = try? await SCScreenshotManager.captureImage(
					contentFilter: filter,
					configuration: config
				), let output = output(image) {
					results[wid] = NSImage(cgImage: output, size: NSSize(width: 200, height: 160))
				}
			}

			let captured = results
			await MainActor.run { completion(captured) }
		}
	}

	private static func output(_ image: CGImage) -> CGImage? {
		guard let first = trim(image) else { return nil }
		return scale(first, maxWidth: 400, maxHeight: 320)
	}

	private static func trim(_ image: CGImage) -> CGImage? {
		let width = image.width
		let height = image.height

		let left = 0
		let top = 0
		let bottom = 0
		let right = min(max(width / 60, 6), 14)

		guard width > left + right, height > top + bottom else { return image }

		let rect = CGRect(
			x: left,
			y: bottom,
			width: width - left - right,
			height: height - top - bottom
		)

		return image.cropping(to: rect) ?? image
	}

	private static func scale(_ image: CGImage, maxWidth: Int, maxHeight: Int) -> CGImage? {
		let width = image.width
		let height = image.height
		let fit = min(CGFloat(maxWidth) / CGFloat(width), CGFloat(maxHeight) / CGFloat(height), 1)
		let outWidth = max(Int(CGFloat(width) * fit), 1)
		let outHeight = max(Int(CGFloat(height) * fit), 1)

		let color = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(
			data: nil,
			width: outWidth,
			height: outHeight,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: color,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }

		context.interpolationQuality = .high
		context.draw(image, in: CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
		return context.makeImage()
	}
}
