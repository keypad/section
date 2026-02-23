import SwiftUI

struct SwitcherView: View {
	@ObservedObject var state: SwitcherState
	var onConfirm: (() -> Void)?

	private var columns: [GridItem] {
		let count = min(max(state.items.count, 1), 4)
		return Array(repeating: GridItem(.fixed(200), spacing: 12), count: count)
	}

	var body: some View {
		LazyVGrid(columns: columns, spacing: 12) {
			ForEach(Array(state.items.enumerated()), id: \.element.id) { offset, item in
				ThumbnailView(item: item, selected: offset == state.index)
					.onHover { hovering in
						if hovering { state.select(offset) }
					}
					.onTapGesture {
						state.select(offset)
						onConfirm?()
					}
			}
		}
		.padding(24)
	}
}
