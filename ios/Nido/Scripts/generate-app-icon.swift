import AppKit

let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

let canvas = NSRect(x: 0, y: 0, width: side, height: side)
let gradient = NSGradient(colors: [
    NSColor(red: 0.40, green: 0.53, blue: 0.45, alpha: 1),
    NSColor(red: 0.24, green: 0.35, blue: 0.29, alpha: 1),
])!
gradient.draw(in: canvas, angle: -55)

NSGraphicsContext.current?.cgContext.setShadow(
    offset: CGSize(width: 0, height: -20),
    blur: 46,
    color: NSColor.black.withAlphaComponent(0.18).cgColor
)

let nestColor = NSColor(red: 0.96, green: 0.92, blue: 0.83, alpha: 1)
nestColor.setStroke()
for (index, inset) in [160.0, 220.0, 280.0].enumerated() {
    let path = NSBezierPath()
    path.lineWidth = 34 - CGFloat(index * 4)
    path.lineCapStyle = .round
    path.move(to: NSPoint(x: inset, y: 430 + CGFloat(index * 56)))
    path.curve(
        to: NSPoint(x: side - inset, y: 430 + CGFloat(index * 56)),
        controlPoint1: NSPoint(x: 300, y: 170 + CGFloat(index * 35)),
        controlPoint2: NSPoint(x: 724, y: 170 + CGFloat(index * 35))
    )
    path.stroke()
}

NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0)
let moon = NSBezierPath()
moon.appendOval(in: NSRect(x: 360, y: 500, width: 310, height: 310))
moon.appendOval(in: NSRect(x: 462, y: 586, width: 280, height: 280))
moon.windingRule = .evenOdd
nestColor.setFill()
moon.fill()

let star = NSBezierPath()
let center = NSPoint(x: 732, y: 735)
let outer: CGFloat = 54
let inner: CGFloat = 18
for index in 0..<8 {
    let radius = index.isMultiple(of: 2) ? outer : inner
    let angle = CGFloat(index) * .pi / 4 - .pi / 2
    let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    index == 0 ? star.move(to: point) : star.line(to: point)
}
star.close()
star.fill()

image.unlockFocus()

guard
    let data = image.tiffRepresentation,
    let representation = NSBitmapImageRep(data: data),
    let png = representation.representation(using: .png, properties: [:])
else {
    fatalError("No se pudo generar el icono")
}

let destination = URL(fileURLWithPath: "Nido/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try png.write(to: destination, options: .atomic)
