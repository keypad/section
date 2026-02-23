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
		let ratio: CGFloat = 200.0 / 160.0
		guard let first = trim(image) else { return nil }
		guard let second = center(first, ratio: ratio) else { return nil }
		return scale(second, width: 400, height: 320)
	}

	private static func trim(_ image: CGImage) -> CGImage? {
		let width = image.width
		let height = image.height

		let left = min(max(width / 220, 2), 6)
		let top = min(max(height / 220, 2), 6)
		let bottom = top
		let right = min(max(width / 45, 10), 20)

		guard width > left + right, height > top + bottom else { return image }

		let rect = CGRect(
			x: left,
			y: bottom,
			width: width - left - right,
			height: height - top - bottom
		)

		return image.cropping(to: rect) ?? image
	}

	private static func center(_ image: CGImage, ratio: CGFloat) -> CGImage? {
		let width = CGFloat(image.width)
		let height = CGFloat(image.height)
		let current = width / height

		var rect = CGRect(x: 0, y: 0, width: width, height: height)

		if current > ratio {
			let target = floor(height * ratio)
			let inset = floor((width - target) / 2)
			rect = CGRect(x: inset, y: 0, width: target, height: height)
		}

		if current < ratio {
			let target = floor(width / ratio)
			let inset = floor((height - target) / 2)
			rect = CGRect(x: 0, y: inset, width: width, height: target)
		}

		return image.cropping(to: rect) ?? image
	}

	private static func scale(_ image: CGImage, width: Int, height: Int) -> CGImage? {
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
		context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
		return context.makeImage()
	}
}
