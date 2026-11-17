// Генератор скриншотов App Store для Wattleft (iPhone 6.9″, 1320×2868).
// Стиль: светло-серый фон, крупный жирный заголовок (средняя строка серая), белая плашка-стикер
// с иконкой, телефон с реальным экраном приложения, обрезанный краем кадра.
//
// Запуск: swift Tools/appstore_screens.swift <папка с исходниками> <папка для результата> <en|uk>
// Исходники (снимаются в симуляторе в демо-режиме): dash.png, lock.png, menu.png, dash_dark.png,
// wg_light.png, wg_dark.png — см. AppStore/README.md.
import AppKit

let W: CGFloat = 1320, H: CGFloat = 2868
let args = CommandLine.arguments
let src = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2])
let lang = args.count > 3 ? args[3] : "en"   // en | uk
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let bg = NSColor(srgbRed: 0.945, green: 0.945, blue: 0.94, alpha: 1)
let ink = NSColor(srgbRed: 0.06, green: 0.06, blue: 0.07, alpha: 1)
let grey = NSColor(srgbRed: 0.70, green: 0.70, blue: 0.69, alpha: 1)
let captionInk = NSColor(srgbRed: 0.45, green: 0.45, blue: 0.44, alpha: 1)
let orange = NSColor(srgbRed: 0.90, green: 0.38, blue: 0.13, alpha: 1)
let green = NSColor(srgbRed: 0.02, green: 0.62, blue: 0.45, alpha: 1)

func image(_ name: String) -> NSImage { NSImage(contentsOf: src.appendingPathComponent(name))! }

// MARK: - Примитивы

@discardableResult
func headline(_ lines: [(String, NSColor)], centerY: CGFloat, size requested: CGFloat = 158) -> CGRect {
    // Самая длинная строка должна влезть в ширину кадра с полями.
    var size = requested
    let widest = lines.map { NSAttributedString(string: $0.0, attributes: [.font: NSFont.systemFont(ofSize: requested, weight: .black),
                                                                          .kern: -requested * 0.035]).size().width }.max() ?? 0
    if widest > W - 120 { size = requested * (W - 120) / widest }
    let font = NSFont.systemFont(ofSize: size, weight: .black)
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.maximumLineHeight = size * 0.98
    para.minimumLineHeight = size * 0.98
    let text = NSMutableAttributedString()
    for (i, (s, c)) in lines.enumerated() {
        text.append(NSAttributedString(string: s + (i < lines.count - 1 ? "\n" : ""),
                                       attributes: [.font: font, .foregroundColor: c, .paragraphStyle: para,
                                                    .kern: -size * 0.035]))
    }
    let h = size * 0.98 * CGFloat(lines.count) + size * 0.2
    let rect = CGRect(x: 40, y: centerY - h / 2, width: W - 80, height: h)
    text.draw(with: rect, options: [.usesLineFragmentOrigin])
    return rect
}

func caption(_ s: String, centerY: CGFloat) {
    let para = NSMutableParagraphStyle(); para.alignment = .center
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: 46, weight: .medium),
                                               .foregroundColor: captionInk, .paragraphStyle: para])
        .draw(with: CGRect(x: 60, y: centerY - 30, width: W - 120, height: 64), options: [.usesLineFragmentOrigin])
}

/// Белая плашка-стикер: цветная иконка + жирная подпись, слегка повёрнута.
func pill(_ text: String, symbol: String, tint: NSColor, center: CGPoint, angle: CGFloat = -5) {
    let font = NSFont.systemFont(ofSize: 56, weight: .bold)
    let label = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: ink])
    let ls = label.size()
    let iconBox: CGFloat = 76, padX: CGFloat = 34, gap: CGFloat = 18
    let w = padX + iconBox + gap + ls.width + padX, h: CGFloat = 124

    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angle * .pi / 180)
    let r = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
    let shape = NSBezierPath(roundedRect: r, xRadius: h / 2.6, yRadius: h / 2.6)
    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.16); sh.shadowBlurRadius = 40; sh.shadowOffset = NSSize(width: 0, height: -14)
    NSGraphicsContext.current!.saveGraphicsState(); sh.set(); NSColor.white.setFill(); shape.fill(); NSGraphicsContext.current!.restoreGraphicsState()

    let cfg = NSImage.SymbolConfiguration(pointSize: 52, weight: .bold).applying(.init(paletteColors: [tint]))
    if let sym = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let s = sym.size, scale = min(iconBox / s.width, iconBox / s.height)
        let iw = s.width * scale, ih = s.height * scale
        sym.draw(in: CGRect(x: r.minX + padX + (iconBox - iw) / 2, y: -ih / 2, width: iw, height: ih))
    }
    label.draw(at: CGPoint(x: r.minX + padX + iconBox + gap, y: -ls.height / 2))
    ctx.restoreGState()
}

/// Телефон: чёрный корпус со скруглением, внутри — скриншот.
func phone(_ screen: NSImage, x: CGFloat, y: CGFloat, width: CGFloat) {
    let aspect = screen.size.height / screen.size.width
    let bezel: CGFloat = width * 0.028
    let outer = CGRect(x: x, y: y, width: width, height: width * aspect + bezel * 2 - bezel * 2 / aspect * 0)
    let body = CGRect(x: outer.minX, y: outer.minY, width: width, height: (width - 2 * bezel) * aspect + 2 * bezel)
    let radius = width * 0.15

    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.22); sh.shadowBlurRadius = 70; sh.shadowOffset = NSSize(width: 0, height: -30)
    NSGraphicsContext.current!.saveGraphicsState(); sh.set()
    NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.current!.restoreGraphicsState()
    // Тонкая светлая кромка корпуса.
    NSColor(white: 0.35, alpha: 1).setStroke()
    let edge = NSBezierPath(roundedRect: body.insetBy(dx: 3, dy: 3), xRadius: radius - 3, yRadius: radius - 3); edge.lineWidth = 4; edge.stroke()

    let screenRect = body.insetBy(dx: bezel, dy: bezel)
    NSGraphicsContext.current!.saveGraphicsState()
    NSBezierPath(roundedRect: screenRect, xRadius: radius - bezel, yRadius: radius - bezel).addClip()
    screen.draw(in: screenRect)
    NSGraphicsContext.current!.restoreGraphicsState()
}

/// Вырезать область из исходника (в пикселях, начало — сверху слева) и скруглить.
func card(_ img: NSImage, _ crop: CGRect, to dest: CGRect, radius: CGFloat, angle: CGFloat = 0) {
    let rep = img.representations.first as! NSBitmapImageRep
    let cg = rep.cgImage!.cropping(to: crop)!
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.translateBy(x: dest.midX, y: dest.midY); ctx.rotate(by: angle * .pi / 180)
    let r = CGRect(x: -dest.width / 2, y: -dest.height / 2, width: dest.width, height: dest.height)
    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.18); sh.shadowBlurRadius = 50; sh.shadowOffset = NSSize(width: 0, height: -20)
    NSGraphicsContext.current!.saveGraphicsState(); sh.set(); NSColor.white.setFill()
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill(); NSGraphicsContext.current!.restoreGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).addClip()
    // CGImage рисуется в непереворачиваемых координатах — компенсируем.
    ctx.translateBy(x: 0, y: r.maxY + r.minY); ctx.scaleBy(x: 1, y: -1)
    ctx.draw(cg, in: r)
    ctx.restoreGState()
}

func render(_ name: String, _ draw: () -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = g
    // Переворачиваем: дальше координаты сверху вниз, как в макете.
    g.cgContext.translateBy(x: 0, y: H); g.cgContext.scaleBy(x: 1, y: -1)
    let flipped = NSGraphicsContext(cgContext: g.cgContext, flipped: true)
    NSGraphicsContext.current = flipped
    bg.setFill(); CGRect(x: 0, y: 0, width: W, height: H).fill()
    draw()
    NSGraphicsContext.restoreGraphicsState()
    // App Store не принимает скриншоты с альфа-каналом — сохраняем без него.
    let flat = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    flat.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: W, height: H))
    try! NSBitmapImageRep(cgImage: flat.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: out.appendingPathComponent(name))
    print("✓", name)
}

// MARK: - Тексты

struct Copy { let caption: String; let lines: [String]; let pill: String }

let copy: [String: [Copy]] = [
    "en": [
        Copy(caption: "For Marstek Venus home batteries", lines: ["How long", "will it", "last?"], pill: "Time, not %"),
        Copy(caption: "Without opening the app", lines: ["Countdown", "on the", "Lock Screen"], pill: "Live Activity"),
        Copy(caption: "Light and dark", lines: ["Widgets", "for your", "Home Screen"], pill: "Always up to date"),
        Copy(caption: "Load calculator", lines: ["What if", "I boil the", "kettle?"], pill: "2000 W"),
        Copy(caption: "No accounts, no cloud", lines: ["Just", "your", "Wi‑Fi"], pill: "Private"),
        Copy(caption: "Notification when the grid is back", lines: ["Know when", "the power", "is back"], pill: "Power is back"),
    ],
    "uk": [
        Copy(caption: "Для домашніх станцій Marstek Venus", lines: ["На скільки", "ще", "вистачить?"], pill: "Час, а не %"),
        Copy(caption: "Не відкриваючи застосунок", lines: ["Таймер", "на екрані", "блокування"], pill: "Live Activity"),
        Copy(caption: "Світлі й темні", lines: ["Віджети", "для екрана", "«Початок»"], pill: "Оновлюються самі"),
        Copy(caption: "Калькулятор навантаження", lines: ["А якщо", "увімкнути", "чайник?"], pill: "2000 Вт"),
        Copy(caption: "Без акаунтів і хмари", lines: ["Лише", "ваша", "Wi‑Fi мережа"], pill: "Приватно"),
        Copy(caption: "Сповіщення, коли з’явиться мережа", lines: ["Дізнайтеся,", "коли дали", "світло"], pill: "Світло дали"),
    ],
]
let t = copy[lang]!
func lines(_ c: Copy) -> [(String, NSColor)] { [(c.lines[0], ink), (c.lines[1], grey), (c.lines[2], ink)] }

// MARK: - Слайды

// 1. Главный экран.
render("01-dashboard.png") {
    caption(t[0].caption, centerY: 200)
    headline(lines(t[0]), centerY: 470)
    pill(t[0].pill, symbol: "hourglass", tint: orange, center: CGPoint(x: 900, y: 735))
    phone(image("dash.png"), x: 150, y: 900, width: 1020)
}

// 2. Экран блокировки: телефон сверху, текст снизу.
render("02-lock-screen.png") {
    phone(image("lock.png"), x: 150, y: -720, width: 1020)
    pill(t[1].pill, symbol: "lock.iphone", tint: orange, center: CGPoint(x: 380, y: 1640), angle: 4)
    caption(t[1].caption, centerY: 1820)
    headline(lines(t[1]), centerY: 2180, size: 150)
}

// 3. Виджеты: светлые и тёмные карточки.
render("03-widgets.png") {
    caption(t[2].caption, centerY: 200)
    headline(lines(t[2]), centerY: 470, size: 146)
    pill(t[2].pill, symbol: "square.grid.2x2.fill", tint: green, center: CGPoint(x: 870, y: 735))
    let l = image("wg_light.png"), d = image("wg_dark.png")
    // Координаты карточек на экране-витрине (пиксели исходника 1206×2622).
    let mediumDis = CGRect(x: 58, y: 395, width: 1090, height: 510)
    let mediumChg = CGRect(x: 58, y: 948, width: 1090, height: 510)
    let smallDis = CGRect(x: 72, y: 1500, width: 508, height: 510)
    let smallChg = CGRect(x: 625, y: 1500, width: 508, height: 510)
    card(l, mediumDis, to: CGRect(x: 110, y: 960, width: 1100, height: 515), radius: 72)
    card(d, mediumChg, to: CGRect(x: 110, y: 1545, width: 1100, height: 515), radius: 72)
    card(d, smallDis, to: CGRect(x: 120, y: 2140, width: 520, height: 522), radius: 72, angle: -3)
    card(l, smallChg, to: CGRect(x: 690, y: 2160, width: 520, height: 522), radius: 72, angle: 3)
}

// 4. Калькулятор нагрузки.
render("04-calculator.png") {
    caption(t[3].caption, centerY: 200)
    headline(lines(t[3]), centerY: 470)
    pill(t[3].pill, symbol: "cup.and.saucer.fill", tint: orange, center: CGPoint(x: 960, y: 735))
    phone(image("menu.png"), x: 150, y: 900, width: 1020)
}

// 5. Тёмная тема и приватность.
render("05-private.png") {
    caption(t[4].caption, centerY: 200)
    headline(lines(t[4]), centerY: 470, size: 150)
    pill(t[4].pill, symbol: "lock.shield.fill", tint: green, center: CGPoint(x: 930, y: 735), angle: -4)
    phone(image("dash_dark.png"), x: 150, y: 900, width: 1020)
}

// 6. Свет дали: экран заряда с баннером «Power is back».
render("06-power-back.png") {
    caption(t[5].caption, centerY: 200)
    headline(lines(t[5]), centerY: 470)
    pill(t[5].pill, symbol: "bolt.fill", tint: green, center: CGPoint(x: 900, y: 735))
    phone(image("dash_charging.png"), x: 150, y: 900, width: 1020)
}
