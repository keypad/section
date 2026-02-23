import AppKit
import SwiftUI

@MainActor
final class SwitcherState: ObservableObject {
	@Published var items: [WindowItem] = []
	@Published var index: Int = 0

	var selected: WindowItem? {
		guard !items.isEmpty, index >= 0, index < items.count else { return nil }
		return items[index]
	}

	func reset(with newItems: [WindowItem]) {
		items = newItems
		index = min(1, newItems.count - 1)
	}

	func next() {
		guard !items.isEmpty else { return }
		index = (index + 1) % items.count
	}

	func previous() {
		guard !items.isEmpty else { return }
		index = (index - 1 + items.count) % items.count
	}

	func select(_ offset: Int) {
		guard offset >= 0, offset < items.count else { return }
		index = offset
	}

	func apply(_ thumbnails: [CGWindowID: NSImage]) {
		for i in items.indices {
			if let image = thumbnails[items[i].id] {
				items[i].thumbnail = image
			}
		}
	}
}
