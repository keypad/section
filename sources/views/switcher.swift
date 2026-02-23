import SwiftUI

struct SwitcherView: View {
	@ObservedObject var state: SwitcherState

	private var columns: [GridItem] {
		let count = min(max(state.items.count, 1), 4)
		return Array(repeating: GridItem(.fixed(220), spacing: 12), count: count)
	}

	var body: some View {
		LazyVGrid(columns: columns, spacing: 12) {
			ForEach(Array(state.items.enumerated()), id: \.element.id) { offset, item in
				ThumbnailView(item: item, selected: offset == state.index)
			}
		}
		.padding(24)
	}
}
