import SwiftUI

/// Баннер-подсказка: матовая стеклянная карточка, круглая иконка слева, заголовок со стрелкой
/// и короткий текст.
struct InfoBanner: View {
    /// Тип баннера — задаёт порядок показа (ошибки выше подсказок); внешне баннеры одинаковые.
    enum Tone { case neutral, info, success, warning, error }

    let icon: String
    let title: LocalizedStringKey
    let message: Text
    var tone: Tone = .neutral
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    init(icon: String, title: LocalizedStringKey, message: Text, tone: Tone = .neutral, action: (() -> Void)? = nil) {
        self.icon = icon; self.title = title; self.message = message; self.tone = tone; self.action = action
    }

    init(icon: String, title: LocalizedStringKey, message: LocalizedStringKey, tone: Tone = .neutral, action: (() -> Void)? = nil) {
        self.init(icon: icon, title: title, message: Text(message), tone: tone, action: action)
    }

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(PressableStyle())
        } else {
            content
        }
    }

    private var dark: Bool { scheme == .dark }

    private var content: some View {
        HStack(alignment: .top, spacing: 16) {
            // Иконка в белом «камешке».
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(dark ? .white : .black)
                .frame(width: 52, height: 52)
                .background {
                    Circle()
                        .fill(dark ? Color.white.opacity(0.12) : Color.white)
                        .shadow(color: .black.opacity(dark ? 0 : 0.08), radius: 10, y: 4)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if action != nil {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }
                message
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { glass }
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    /// Матовое стекло: полупрозрачная заливка и светлая кромка.
    private var glass: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack {
            shape.fill(dark ? Color.white.opacity(0.06) : Color.white.opacity(0.72))
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(dark ? 0.22 : 0.95), .white.opacity(dark ? 0.04 : 0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.2)
        }
        .background(.ultraThinMaterial, in: shape)
        .shadow(color: .black.opacity(dark ? 0 : 0.06), radius: 18, y: 8)
    }
}

/// Лёгкое «нажатие»: карточка чуть уменьшается, пока палец на ней.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Строка списка без собственного фона и отступов — для баннера.
    func bannerRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
    }
}
