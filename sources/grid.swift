import AppKit

enum Grid {
	static func width(_ item: WindowItem, height: CGFloat, bar: CGFloat) -> CGFloat {
		let body = max(height - bar, 1)
		let ratio = item.bounds.width / max(item.bounds.height, 1)
		let value = body * ratio
		return min(max(value, 140), 320)
	}

	static func rows(_ items: [WindowItem], count: Int) -> [[WindowItem]] {
		guard count > 0 else { return [] }
		var result: [[WindowItem]] = []
		var index = 0
		while index < items.count {
			let end = min(index + count, items.count)
			result.append(Array(items[index..<end]))
			index = end
		}
		return result
	}
}
