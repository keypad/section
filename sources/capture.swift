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
		let second = solid(first) ?? first
		guard let third = center(second, ratio: ratio) else { return nil }
		return scale(third, width: 400, height: 320)
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

	private static func solid(_ image: CGImage) -> CGImage? {
		guard let raw = image.dataProvider?.data else { return nil }
		guard let data = CFDataGetBytePtr(raw) else { return nil }

		let width = image.width
		let height = image.height
		let row = image.bytesPerRow
		let bits = image.bitsPerPixel / 8
		guard bits >= 4 else { return nil }

		let alpha: Int
		switch image.alphaInfo {
		case .premultipliedFirst, .first, .noneSkipFirst:
			alpha = 0
		case .premultipliedLast, .last, .noneSkipLast:
			alpha = bits - 1
		default:
			return nil
		}

		let step = 2
		let mark: UInt8 = 8
		var left = width
		var right = -1
		var top = height
		var bottom = -1

		var y = 0
		while y < height {
			var x = 0
			while x < width {
				let index = y * row + x * bits + alpha
				if data[index] > mark {
					if x < left { left = x }
					if x > right { right = x }
					if y < top { top = y }
					if y > bottom { bottom = y }
				}
				x += step
			}
			y += step
		}

		guard right >= left, bottom >= top else { return nil }

		let pad = 2
		let x = max(left - pad, 0)
		let y0 = max(top - pad, 0)
		let w = min(right - left + 1 + pad * 2, width - x)
		let h = min(bottom - top + 1 + pad * 2, height - y0)
		let rect = CGRect(x: x, y: y0, width: w, height: h)
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
		context.setFillColor(CGColor(gray: 0.06, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: width, height: height))
		context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
		return context.makeImage()
	}
}
