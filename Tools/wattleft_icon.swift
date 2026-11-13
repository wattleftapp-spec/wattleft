// Иконка Wattleft: матовая светлая плитка 5×5, «ступени» тёплых квадратов — как столбики
// заряда, который убывает слева направо. Тёплое свечение в глубине, зерно, полупрозрачные верхушки.
// Запуск: swift Tools/wattleft_icon.swift App/Assets.xcassets/AppIcon.appiconset/icon.png
import AppKit
import CoreImage

let S: CGFloat = 1024
let N = 5
let cell = S / CGFloat(N)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ci = CIContext()

func ctx() -> CGContext {
    CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
              space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}
func blurred(_ img: CGImage, _ r: Double) -> CGImage {
    let i = CIImage(cgImage: img).clampedToExtent().applyingGaussianBlur(sigma: r)
        .cropped(to: CGRect(x: 0, y: 0, width: S, height: S))
    return ci.createCGImage(i, from: CGRect(x: 0, y: 0, width: S, height: S))!
}
func lerp(_ a: [Double], _ b: [Double], _ t: Double) -> [Double] { zip(a, b).map { $0 + ($1 - $0) * t } }

/// Цвет квадрата по расстоянию от «горячей» точки: янтарь в центре → оранжевый → кирпичный по краям.
func heat(_ x: CGFloat, _ y: CGFloat) -> [Double] {
    let hot = CGPoint(x: S * 0.36, y: S * 0.30)
    let d = Double(hypot(x - hot.x, y - hot.y) / (S * 0.62))
    let amber = [0.98, 0.72, 0.38], orange = [0.95, 0.47, 0.27], brick = [0.88, 0.30, 0.22]
    return d < 0.45 ? lerp(amber, orange, d / 0.45) : lerp(orange, brick, min(1, (d - 0.45) / 0.55))
}

// Высота столбиков слева направо (в клетках снизу) — заряд «утекает» вправо.
let heights = [4, 4, 3, 2, 1]

let base = ctx()

// 1. Матовый белый фон с лёгким вертикальным градиентом.
base.drawLinearGradient(CGGradient(colorsSpace: cs, colors: [rgb(0.975, 0.97, 0.965), rgb(0.94, 0.935, 0.93)] as CFArray,
                                   locations: [0, 1])!,
                        start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

// 2. Тонкая сетка на пустых клетках.
base.setStrokeColor(rgb(0, 0, 0, 0.035)); base.setLineWidth(2)
for i in 1..<N {
    let v = CGFloat(i) * cell
    base.move(to: CGPoint(x: v, y: 0)); base.addLine(to: CGPoint(x: v, y: S))
    base.move(to: CGPoint(x: 0, y: v)); base.addLine(to: CGPoint(x: S, y: v))
}
base.strokePath()

// 3. Квадраты: заливка цветом поля, верхний в столбике — полупрозрачный, над ним — «призрак».
let tiles = ctx()
for (col, h) in heights.enumerated() {
    for row in 0..<(h + 1) {
        let r = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
        let c = heat(r.midX, r.midY)
        let alpha: Double = row < h - 1 ? 1 : (row == h - 1 ? 0.62 : 0.10)
        // Внутри квадрата — лёгкий собственный градиент (светлее сверху), как у стекла.
        let top = lerp(c, [1, 1, 1], 0.10), bottom = lerp(c, [0.75, 0.2, 0.15], 0.06)
        tiles.saveGState()
        tiles.clip(to: r)
        tiles.drawLinearGradient(CGGradient(colorsSpace: cs,
                                            colors: [rgb(top[0], top[1], top[2], alpha), rgb(bottom[0], bottom[1], bottom[2], alpha)] as CFArray,
                                            locations: [0, 1])!,
                                 start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
        tiles.restoreGState()
    }
}
let tilesImg = tiles.makeImage()!
// Мягкое свечение от квадратов на фон и сами квадраты поверх.
base.setAlpha(0.35); base.draw(blurred(tilesImg, 30), in: CGRect(x: 0, y: 0, width: S, height: S)); base.setAlpha(1)
base.draw(tilesImg, in: CGRect(x: 0, y: 0, width: S, height: S))

// 4. Тёплое внутреннее сияние в «глубине» ступеней.
let glow = ctx()
glow.drawRadialGradient(CGGradient(colorsSpace: cs, colors: [rgb(1, 0.85, 0.55, 0.55), rgb(1, 0.7, 0.4, 0)] as CFArray, locations: [0, 1])!,
                        startCenter: CGPoint(x: S * 0.36, y: S * 0.30), startRadius: 0,
                        endCenter: CGPoint(x: S * 0.36, y: S * 0.30), endRadius: S * 0.32, options: [])
base.saveGState()
base.clip(to: CGRect(x: 0, y: 0, width: S, height: S), mask: tilesImg)  // сияние только на квадратах
base.setBlendMode(.softLight)
base.draw(glow.makeImage()!, in: CGRect(x: 0, y: 0, width: S, height: S))
base.restoreGState()

// 5. Швы между квадратами — тонкие светлые линии поверх заливки.
base.saveGState()
for (col, h) in heights.enumerated() {
    for row in 0..<h {
        let r = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell).insetBy(dx: 1.5, dy: 1.5)
        base.setStrokeColor(rgb(1, 1, 1, 0.16)); base.setLineWidth(3)
        base.stroke(r)
    }
}
base.restoreGState()

// 6. Зерно: мелкие светлые и тёмные точки по всей иконке, гуще на цвете.
var rng = SystemRandomNumberGenerator()
for _ in 0..<32000 {
    let x = CGFloat.random(in: 0..<S, using: &rng), y = CGFloat.random(in: 0..<S, using: &rng)
    let col = Int(x / cell), row = Int(y / cell)
    let onTile = col < N && row < heights[min(col, N - 1)]
    let light = Bool.random(using: &rng)
    let a = onTile ? Double.random(in: 0.10...0.28, using: &rng) : Double.random(in: 0.02...0.06, using: &rng)
    base.setFillColor(light ? rgb(1, 0.95, 0.85, a) : rgb(0.4, 0.1, 0.05, a * 0.6))
    let s = CGFloat.random(in: 0.9...1.9, using: &rng)
    base.fillEllipse(in: CGRect(x: x, y: y, width: s, height: s))
}

// 7. Матовый блик сверху (как у стекла плитки).
base.drawLinearGradient(CGGradient(colorsSpace: cs, colors: [rgb(1, 1, 1, 0.22), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 1])!,
                        start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: S * 0.72), options: [])

// Сохранить без альфы.
let out = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
out.draw(base.makeImage()!, in: CGRect(x: 0, y: 0, width: S, height: S))
try! NSBitmapImageRep(cgImage: out.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
