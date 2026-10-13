import SwiftUI

struct StationPickerView: View {
    let title: String
    let stations: [Station]
    let popular: [Station]
    let selected: Station?
    let onSelect: (Station) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @ObserveInjection var inject

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section("Popular") {
                        ForEach(popular) { row(for: $0) }
                    }
                    Section("All Stations") {
                        ForEach(stations) { row(for: $0) }
                    }
                } else {
                    ForEach(filtered) { row(for: $0) }
                }
            }
            .overlay {
                if !query.isEmpty && filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Station name or code")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .enableInjection()
    }

    private var filtered: [Station] {
        let needle = query.trimmed
        return stations.filter {
            $0.name.localizedCaseInsensitiveContains(needle) || $0.code.localizedCaseInsensitiveContains(needle)
        }
    }

    private func row(for station: Station) -> some View {
        Button {
            onSelect(station)
            dismiss()
        } label: {
            HStack(spacing: Spacing.x1 + 4) {
                Text(station.code)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(station == selected ? Color.onAccent : Color.secondary)
                    .frame(minWidth: 44, minHeight: 28)
                    .background(station == selected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.well),
                                in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    .accessibilityHidden(true)
                Text(station.name)
                    .foregroundStyle(.primary)
                Spacer()
                if station == selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(station == selected ? .isSelected : [])
    }
}
