import SwiftUI

/// Settings › Theme: every bubble theme, grouped (Classic, Pro favorites, Sports and games, Treats, Nature and space,
/// Fun objects, Seasons and holidays). Tapping a tile picks it and plays its pop; Pro themes open Pop In Pro for free
/// users. "Surprise me" picks a different theme each day.
struct ThemeGalleryPage: View {
    @Environment(AppModel.self) private var model
    @State private var bounced: GumPalette?

    var body: some View {
        SettingsPage {
            SettingsGroup(nil, note: "A different theme each day, picked from the ones you have.") {
                SettingsToggle(model.store.isPro ? "Surprise me" : "Surprise me ✦", detail: "Changes once a day when you open Pop In",
                               isOn: Binding(get: { model.surprise }, set: { on in
                                   if on && !model.store.isPro { model.showPro = true } else { model.surprise = on }
                               }))
            }
            ForEach(ThemeGroup.allCases, id: \.self) { group in
                let themes = GumPalette.available.filter { $0.group == group }
                if !themes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Brand.secondary)
                            .padding(.leading, 18)
                            .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(themes, id: \.self) { tile($0) }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 20).fill(.white))
                    }
                }
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ palette: GumPalette) -> some View {
        let selected = model.gumColor == palette && !model.surprise
        let locked = palette.isPro && !model.store.isPro
        return Button {
            if locked { model.showPro = true; return }
            model.surprise = false
            model.gumColor = palette
            PopSound.play()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { bounced = palette }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { if bounced == palette { bounced = nil } }
            }
        } label: {
            VStack(spacing: 8) {
                SwatchBall(palette: palette)
                    .frame(width: 52, height: 52)
                    .scaleEffect(bounced == palette ? 1.18 : 1)
                    .padding(.top, 10)
                Text(locked ? "\(palette.label) ✦" : palette.label)
                    .font(.footnote.weight(selected ? .semibold : .regular))
                    .foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 14).stroke(selected ? Brand.ink : Brand.hairline, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(palette.label), Pro" : palette.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
