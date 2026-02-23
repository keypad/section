import SwiftUI

struct SwitcherView: View {
	@ObservedObject var state: SwitcherState
	let theme: Theme
	let accent: Accent

	private var rows: [[WindowItem]] {
		Grid.rows(state.items, count: 4)
	}

	var body: some View {
		VStack(spacing: 12) {
			ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
				HStack(spacing: 12) {
					ForEach(row, id: \.id) { item in
						ThumbnailView(item: item, selected: item.id == state.selected?.id, theme: theme, accent: accent)
					}
				}
			}
		}
		.padding(24)
		.background(accent.card.opacity(0.18))
	}
}
