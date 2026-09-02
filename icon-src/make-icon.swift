import AppKit
import CoreGraphics

let S: CGFloat = 1024
let rect = CGRect(x: 0, y: 0, width: S, height: S)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// rounded-square canvas (Big Sur style: 824pt squircle-ish, radius 185)
let pad: CGFloat = 100
let iconRect = CGRect(x: pad, y: pad, width: S - 2 * pad, height: S - 2 * pad)
let iconPath = CGPath(roundedRect: iconRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.addPath(iconPath)
ctx.clip()

// background: deep navy vertical gradient
let bg = CGGradient(colorsSpace: cs, colors: [c(0.13, 0.13, 0.19), c(0.07, 0.07, 0.11)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: S/2, y: S), end: CGPoint(x: S/2, y: 0), options: [])

// radial glow behind the lock (accent orange, faint)
let glow = CGGradient(colorsSpace: cs,
                      colors: [c(0.95, 0.45, 0.30, 0.35), c(0.95, 0.45, 0.30, 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: S/2, y: S/2), startRadius: 0,
                       endCenter: CGPoint(x: S/2, y: S/2), endRadius: 420, options: [])

// ---- timer ring (gap = focus timer), white 15%
let ringCenter = CGPoint(x: S/2, y: S/2)
let ringR: CGFloat = 335
ctx.setStrokeColor(c(1, 1, 1, 0.14))
ctx.setLineWidth(28)
ctx.setLineCap(.round)
ctx.addArc(center: ringCenter, radius: ringR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

// accent arc: 270 degree sweep clockwise from 12 o'clock, gap sits at 9-12 o'clock
ctx.setStrokeColor(c(0.95, 0.55, 0.38, 1))
ctx.setLineWidth(28)
ctx.addArc(center: ringCenter, radius: ringR, startAngle: .pi / 2,
           endAngle: .pi / 2 - .pi * 1.5, clockwise: true)
ctx.strokePath()

// ---- padlock
let bodyW: CGFloat = 380, bodyH: CGFloat = 310
let bodyRect = CGRect(x: S/2 - bodyW/2, y: S/2 - bodyH/2 - 60, width: bodyW, height: bodyH)
let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 56, cornerHeight: 56, transform: nil)

// shackle: thick stroked arc
let shR: CGFloat = 120
let shCenter = CGPoint(x: S/2, y: bodyRect.maxY - 10)
ctx.setStrokeColor(c(0.82, 0.86, 0.95, 1))
ctx.setLineWidth(52)
ctx.addArc(center: shCenter, radius: shR, startAngle: 0, endAngle: .pi, clockwise: false)
ctx.strokePath()
// shackle legs
ctx.setFillColor(c(0.82, 0.86, 0.95, 1))
ctx.fill(CGRect(x: shCenter.x - shR - 26, y: bodyRect.maxY - 60, width: 52, height: 80))
ctx.fill(CGRect(x: shCenter.x + shR - 26, y: bodyRect.maxY - 60, width: 52, height: 80))

// body: warm gradient
ctx.addPath(bodyPath)
ctx.clip()
let bodyGrad = CGGradient(colorsSpace: cs,
                          colors: [c(0.98, 0.62, 0.45), c(0.88, 0.42, 0.25)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(bodyGrad, start: CGPoint(x: S/2, y: bodyRect.maxY),
                       end: CGPoint(x: S/2, y: bodyRect.minY), options: [])
// keyhole
let keyCenterY = bodyRect.midY + 58
ctx.setFillColor(c(0.30, 0.10, 0.05, 0.9))
ctx.fillEllipse(in: CGRect(x: S/2 - 36, y: keyCenterY - 36, width: 72, height: 72))
ctx.fill(CGRect(x: S/2 - 17, y: keyCenterY - 170, width: 34, height: 134))
ctx.resetClip()

// render
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let png = rep.representation(using: .png, properties: [:])!
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
