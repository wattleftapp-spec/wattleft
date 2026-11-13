import SwiftUI

/// Палитры состояний — общие для приложения и виджетов.
/// Каждая — один тон в трёх ступенях светлоты (тёмная → светлая), построены в OKLCH
/// и проверены валидатором dataviz. Для тёмной темы — свои, более светлые ступени.
enum BatteryPalette {
    static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    /// Изумрудный → бирюзовый.
    static let chargingLight: [Color] = [hex(0x02853C), hex(0x049E74), hex(0x0DB3A1)]
    static let chargingDark: [Color] = [hex(0x20A04E), hex(0x14B687), hex(0x25CBB7)]
    /// Кирпично-коралловый → оранжевый.
    static let dischargingLight: [Color] = [hex(0xD33E25), hex(0xE56022), hex(0xF18336)]
    static let dischargingDark: [Color] = [hex(0xE14C33), hex(0xEF713B), hex(0xFA934E)]
    /// Простой — нейтральный серый.
    static let idle: [Color] = [hex(0x5C5F66), hex(0x7A7E86), hex(0x9DA1A8)]

    static func colors(for mode: BatteryEstimate.Mode?, dark: Bool) -> [Color] {
        switch mode {
        case .charging?: dark ? chargingDark : chargingLight
        case .discharging?: dark ? dischargingDark : dischargingLight
        default: idle
        }
    }
}
