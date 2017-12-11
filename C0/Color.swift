/*
 Copyright 2017 S
 
 This file is part of C0.
 
 C0 is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 C0 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with C0.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 #Issue
 Lab色空間ベースのカラーピッカー及びカラー補間
*/

import Foundation
import QuartzCore

struct Color: Equatable, Hashable, Codable {
    static let white = Color(hue: 0, saturation: 0, lightness: 1)
    static let gray = Color(hue: 0, saturation: 0, lightness: 0.5)
    static let black = Color(hue: 0, saturation: 0, lightness: 0)
    static let red = Color(red: 1, green: 0, blue: 0)
    static let orange = Color(red: 1, green: 0.5, blue: 0)
    static let yellow = Color(red: 1, green: 1, blue: 0)
    static let green = Color(red: 0, green: 1, blue: 0)
    static let cyan = Color(red: 0, green: 1, blue: 1)
    static let blue = Color(red: 0, green: 0, blue: 1)
    static let magenta = Color(red: 1, green: 0, blue: 1)
    
    static let background = Color(white: 0.97)
    static let border = Color(white: 0.68)
    static let content = Color(white: 0.35)
    static let font = Color(white: 0.05)
    static let knob = white
    static let locked = Color(white: 0.5)
    static let edit = Color(white: 0.88)
    static let translucentEdit = Color(white: 0, alpha: 0.1)
    static let indication = Color(red: 0.3, green: 0.9, blue: 1)
    static let subIndication = Color(red: 0.6, green: 0.95, blue: 1)
    static let select = Color(red: 0, green: 0.7, blue: 1, alpha: 0.3)
    static let selectBorder = Color(red: 0, green: 0.5, blue: 1, alpha: 0.5)
    static let deselect = Color(red: 0.9, green: 0.3, blue: 0, alpha: 0.3)
    static let deselectBorder = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    static let selection = Color(red: 0.1, green: 0.7, blue: 1)
    static let subSelection = Color(red: 0.8, green: 0.95, blue: 1)
    
    static let moveZ = Color(red: 1, green: 0, blue: 0)
    static let warning = red
    
    static let rough = Color(red: 0, green: 0.5, blue: 1, alpha: 0.15)
    static let subRough = Color(red: 0, green: 0.5, blue: 1, alpha: 0.1)
    static let timelineRough = Color(red: 1, green: 1, blue: 0.2)
    
    static let previous = Color(red: 1, green: 0, blue: 0, alpha: 0.1)
    static let previousSkin = previous.with(alpha: 1)
    static let subPrevious = Color(red: 1, green: 0.2, blue: 0.2, alpha: 0.025)
    static let subPreviousSkin = subPrevious.with(alpha: 0.08)
    
    static let next = Color(red: 0.2, green: 0.8, blue: 0, alpha: 0.1)
    static let nextSkin = next.with(alpha: 1)
    static let subNext = Color(red: 0.4, green: 1, blue: 0, alpha: 0.025)
    static let subNextSkin = subNext.with(alpha: 0.08)
    
    static let editMaterial = Color(red: 1, green: 0.5, blue: 0, alpha: 0.5)
    static let editMaterialColorOnly = Color(red: 1, green: 0.75, blue: 0, alpha: 0.5)
    
    static let snap = Color(red: 0.5, green: 0, blue: 1)
    static let controlEditPointIn = Color(red: 1, green: 1, blue: 0)
    static let controlPointIn = knob
    static let controlPointCapIn = knob
    static let controlPointJointIn = Color(red: 1, green: 0, blue: 0)
    static let controlPointOtherJointIn = Color(red: 1, green: 0.5, blue: 1)
    static let controlPointUnionIn = Color(red: 0, green: 1, blue: 0.2)
    static let controlPointPathIn = Color(red: 0, green: 1, blue: 1)
    static let controlPointOut = border
    static let editControlPointIn = Color(red: 1, green: 0, blue: 0, alpha: 0.8)
    static let editControlPointOut = Color(red: 1, green: 0.5, blue: 0.5, alpha: 0.3)
    static let contolLineIn = Color(red: 1, green: 0.5, blue: 0.5, alpha: 0.3)
    static let contolLineOut = Color(red: 1, green: 0, blue: 0, alpha: 0.3)
    
    static let camera = Color(red: 0.7, green: 0.6, blue: 0)
    static let cameraBorder = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    static let cutBorder = Color(red: 0.3, green: 0.46, blue: 0.7, alpha: 0.5)
    static let cutSubBorder = background.multiply(alpha: 0.5)
    
    static let strokeLine = Color(white: 0)
    
    static let playBorder = Color(white: 0.4)
    static let speechBorder = Color(white: 0)
    static let speechFill = white
    
    let hue: Double, saturation: Double, lightness: Double, alpha: Double, colorSpace: ColorSpace
    let rgb: RGB, id: UUID
    
    static func random(colorSpace: ColorSpace = .sRGB) -> Color {
        let hue = Double.random(min: 0, max: 1)
        let saturation = Double.random(min: 0.5, max: 1)
        let lightness = Double.random(min: 0.4, max: 0.9)
        return Color(hue: hue, saturation: saturation, lightness: lightness, colorSpace: colorSpace)
    }
    init(hue: Double = 0, saturation: Double = 0, lightness: Double = 0, alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        self.rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
        self.alpha = alpha
        self.colorSpace = colorSpace
        self.id = UUID()
    }
    init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        let hsv = HSV(h: hue, s: saturation, v: brightness)
        self.init(hsv: hsv, rgb: hsv.rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(red: Double, green: Double, blue: Double, alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        let rgb = RGB(r: red, g: green, b: blue)
        self.init(hsv: rgb.hsv, rgb: rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(rgb: RGB, alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        self.init(hsv: rgb.hsv, rgb: rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(white: Double, alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        self.init(hue: 0, saturation: 0, lightness: white, alpha: alpha, colorSpace: colorSpace)
    }
    private static func hsvWithHSL(h: Double, s: Double, l: Double) -> HSV {
        let y = Color.y(withHue: h)
        if y < l {
            let by = y == 1 ? 0 : (l - y) / (1 - y)
            return HSV(h: h, s: -s * by + s, v: (1 - y) * (-s * by + s + by) + y)
        } else {
            let by = y == 0 ? 0 : l / y
            return HSV(h: h, s: s, v: s * by * (1 - y) + by * y)
        }
    }
    var hsv: HSV {
        return Color.hsvWithHSL(h: hue, s: saturation, l: lightness)
    }
    init(hsv: HSV, rgb: RGB, alpha: Double, colorSpace: ColorSpace = .sRGB) {
        let h = hsv.h, s = hsv.s, v = hsv.v
        let y = Color.y(withHue: h), saturation: Double, lightness: Double
        let n = s * (1 - y) + y
        let nb = n == 0 ? 0 : y * v / n
        if nb < y {
            saturation = s
            lightness = nb
        } else {
            let n = 1 - y
            let nb = n == 0 ? 1 : (v - y) / n - s
            lightness = n * nb + y
            saturation = nb == 1 ? 0 : s / (1 - nb)
        }
        self.hue =  h
        self.saturation = saturation
        self.lightness = lightness
        self.rgb = rgb
        self.alpha = alpha
        self.colorSpace = colorSpace
        self.id = UUID()
    }
    
    func with(hue: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness:  lightness, alpha: alpha)
    }
    func with(saturation: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(lightness: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(saturation: Double, lightness: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(alpha: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func withNewID() -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    
    func multiply(alpha a: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha * a)
    }
    func multiply(white: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness + (1 - lightness) * white, alpha: alpha)
    }
    
    static func y(withHue hue: Double) -> Double {
        let hueRGB = HSV(h: hue, s: 1, v: 1).rgb
        return 0.299 * hueRGB.r + 0.587 * hueRGB.g + 0.114 * hueRGB.b
    }
    
    var hashValue: Int {
        return id.hashValue
    }
    static func ==(lhs: Color, rhs: Color) -> Bool {
        return lhs.id == rhs.id
    }
}
extension Color: Referenceable {
    static let name = Localization(english: "Color", japanese: "カラー")
    static var feature: Localization {
        return Localization(
            english: "HSL Color",
            japanese: "HSL カラー"
        )
    }
    var valueDescription: Localization {
        return Localization(
            english: "Hue: \(hue)\nSaturation: \(saturation)\nLightness: \(lightness)\nAlpha: \(alpha)\nRGB: \(rgb)\nColor Space: \(colorSpace)\nID: \(id.uuidString)",
            japanese: "色相: \(hue)\n彩度: \(saturation)\n輝度: \(lightness)\n不透明度: \(alpha)\nRGB: \(rgb)\n色空間: \(colorSpace)\n\nID: \(id.uuidString)"
        )
    }
}
extension Color: Interpolatable {
    static func linear(_ f0: Color, _ f1: Color, t: CGFloat) -> Color {
        let rgb = RGB.linear(f0.rgb, f1.rgb, t: t)
        let alpha = CGFloat.linear(f0.alpha.cf, f1.alpha.cf, t: t).d
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ? color : color.with(hue: CGFloat.linear(f0.hue.cf, f1.hue.cf.loopValue(other: f0.hue.cf), t: t).loopValue().d)
    }
    static func firstMonospline(_ f1: Color, _ f2: Color, _ f3: Color, with msx: MonosplineX) -> Color {
        let rgb = RGB.firstMonospline(f1.rgb, f2.rgb, f3.rgb, with: msx)
        let alpha = CGFloat.firstMonospline(f1.alpha.cf, f2.alpha.cf, f3.alpha.cf, with: msx).d
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ? color : color.with(hue: CGFloat.firstMonospline(f1.hue.cf, f2.hue.cf.loopValue(other: f1.hue.cf), f3.hue.cf.loopValue(other: f1.hue.cf), with: msx).loopValue().d)
    }
    static func monospline(_ f0: Color, _ f1: Color, _ f2: Color, _ f3: Color, with msx: MonosplineX) -> Color {
        let rgb = RGB.monospline(f0.rgb, f1.rgb, f2.rgb, f3.rgb, with: msx)
        let alpha = CGFloat.monospline(f0.alpha.cf, f1.alpha.cf, f2.alpha.cf, f3.alpha.cf, with: msx).d
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ? color : color.with(hue: CGFloat.monospline(f0.hue.cf, f1.hue.cf.loopValue(other: f0.hue.cf), f2.hue.cf.loopValue(other: f0.hue.cf), f3.hue.cf.loopValue(other: f0.hue.cf), with: msx).loopValue().d)
    }
    static func endMonospline(_ f0: Color, _ f1: Color, _ f2: Color, with msx: MonosplineX) -> Color {
        let rgb = RGB.endMonospline(f0.rgb, f1.rgb, f2.rgb, with: msx)
        let alpha = CGFloat.endMonospline(f0.alpha.cf, f1.alpha.cf, f2.alpha.cf, with: msx).d
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ? color : color.with(hue: CGFloat.endMonospline(f0.hue.cf, f1.hue.cf.loopValue(other: f0.hue.cf), f2.hue.cf.loopValue(other: f0.hue.cf), with: msx).loopValue().d)
    }
}

struct RGB: Codable {
    let r: Double, g: Double, b: Double
    var hsv: HSV {
        let min = Swift.min(r, g, b), max = Swift.max(r, g, b)
        let d = max - min
        let h: Double, s = max == 0 ? d : d / max, v = max
        if d > 0 {
            if r == max {
                let hh = (g - b) / d
                h = (hh < 0 ? hh + 6 : hh) / 6
            } else if g == max {
                h = (2 + (b - r) / d) / 6
            } else {
                h = (4 + (r - g) / d) / 6
            }
        } else {
            h = d / 6
        }
        return HSV(h: h, s: s, v: v)
    }
}
extension RGB: Interpolatable {
    static func linear(_ f0: RGB, _ f1: RGB, t: CGFloat) -> RGB {
        let r = CGFloat.linear(f0.r.cf, f1.r.cf, t: t).d
        let g = CGFloat.linear(f0.g.cf, f1.g.cf, t: t).d
        let b = CGFloat.linear(f0.b.cf, f1.b.cf, t: t).d
        return RGB(r: r, g: g, b: b)
    }
    static func firstMonospline(_ f1: RGB, _ f2: RGB, _ f3: RGB, with msx: MonosplineX) -> RGB {
        let r = CGFloat.firstMonospline(f1.r.cf, f2.r.cf, f3.r.cf, with: msx).d
        let g = CGFloat.firstMonospline(f1.g.cf, f2.g.cf, f3.g.cf, with: msx).d
        let b = CGFloat.firstMonospline(f1.b.cf, f2.b.cf, f3.b.cf, with: msx).d
        return RGB(r: r, g: g, b: b)
    }
    static func monospline(_ f0: RGB, _ f1: RGB, _ f2: RGB, _ f3: RGB, with msx: MonosplineX) -> RGB {
        let r = CGFloat.monospline(f0.r.cf, f1.r.cf, f2.r.cf, f3.r.cf, with: msx).d
        let g = CGFloat.monospline(f0.g.cf, f1.g.cf, f2.g.cf, f3.g.cf, with: msx).d
        let b = CGFloat.monospline(f0.b.cf, f1.b.cf, f2.b.cf, f3.b.cf, with: msx).d
        return RGB(r: r, g: g, b: b)
    }
    static func endMonospline(_ f0: RGB, _ f1: RGB, _ f2: RGB, with msx: MonosplineX) -> RGB {
        let r = CGFloat.endMonospline(f0.r.cf, f1.r.cf, f2.r.cf, with: msx).d
        let g = CGFloat.endMonospline(f0.g.cf, f1.g.cf, f2.g.cf, with: msx).d
        let b = CGFloat.endMonospline(f0.b.cf, f1.b.cf, f2.b.cf, with: msx).d
        return RGB(r: r, g: g, b: b)
    }
}

struct HSV: Codable {
    let h: Double, s: Double, v: Double
    var rgb: RGB {
        guard s != 0 else {
            return RGB(r: v, g: v, b: v)
        }
        let h6 = 6 * h
        let hi = Int(h6)
        let nh = h6 - Double(hi)
        switch (hi) {
        case 0:
            return RGB(r: v, g: v * (1 - s * (1 - nh)), b: v * (1 - s))
        case 1:
            return RGB(r: v * (1 - s * nh), g: v, b: v * (1 - s))
        case 2:
            return RGB(r: v * (1 - s), g: v, b: v * (1 - s * (1 - nh)))
        case 3:
            return RGB(r: v * (1 - s), g: v * (1 - s * nh), b: v)
        case 4:
            return RGB(r: v * (1 - s * (1 - nh)), g: v * (1 - s), b: v)
        default:
            return RGB(r: v, g: v * (1 - s), b: v * (1 - s * nh))
        }
    }
}

enum ColorSpace: Int8, Codable {
    static var name: Localization {
        return Localization(english: "Color space", japanese: "色空間")
    }
    var description: String {
        switch self {
        case .sRGB:
            return "sRGB"
        case .displayP3:
            return "Display P3"
        case .lab:
            return "CIELAB"
        }
    }
    
    case sRGB, displayP3, lab
}

extension Color {
    func with(colorSpace: ColorSpace) -> Color {
        guard
            let cs = CGColorSpace.with(colorSpace),
            let cgColor = self.cgColor.converted(to: cs, intent: .defaultIntent, options: nil),
            let cps = cgColor.components, cgColor.numberOfComponents == 4 else {
                return self
        }
        return Color(red: Double(cps[0]), green: Double(cps[1]), blue: Double(cps[2]), alpha: Double(cps[3]), colorSpace: colorSpace)
    }
    init(_ cgColor: CGColor) {
        guard cgColor.numberOfComponents == 4,
            let components = cgColor.components,
            let name = cgColor.colorSpace?.name as String? else {
                self.init()
                return
        }
        switch name {
        case String(CGColorSpace.sRGB):
            self.init(
                red: Double(components[0]),
                green: Double(components[1]),
                blue: Double(components[2]),
                alpha: Double(components[3]),
                colorSpace: .sRGB
            )
        case String(CGColorSpace.displayP3):
            self.init(
                red: Double(components[0]),
                green: Double(components[1]),
                blue: Double(components[2]),
                alpha: Double(components[3]),
                colorSpace: .displayP3
            )
        default:
            self.init()
        }
    }
    var cgColor: CGColor {
        return CGColor.with(rgb: rgb, alpha: alpha, colorSpace: CGColorSpace.with(colorSpace))
    }
}
extension Color: Drawable {
    func draw(with bounds: CGRect, in ctx: CGContext) {
        ctx.setFillColor(cgColor)
        ctx.fill(bounds.inset(by: Layout.basicPadding))
    }
}
extension CGColor {
    static func with(rgb: RGB, alpha a: Double = 1, colorSpace: CGColorSpace? = nil) -> CGColor {
        let cs = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let cps = [CGFloat(rgb.r), CGFloat(rgb.g), CGFloat(rgb.b), CGFloat(a)]
        return CGColor(colorSpace: cs, components: cps) ?? CGColor(red: cps[0], green: cps[1], blue: cps[2], alpha: cps[3])
    }
}
extension CGColorSpace {
    static func with(_ colorSpace: ColorSpace) -> CGColorSpace? {
        switch colorSpace {
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3)
        case .lab:
            return CGColorSpace(labWhitePoint: [0.95947, 1, 1.08883], blackPoint: [0, 0, 0], range: [-127, 127, -127, 127])
        }
    }
}

protocol ColorPickerDelegate: class {
    func changeColor(_ colorPicker: ColorPicker,
                     color: Color,
                     oldColor: Color,
                     type: Action.SendType)
}
final class ColorPicker: LayerRespondable {
    static let name = Localization(
        english: "Color Picker",
        japanese: "カラーピッカー"
    )
    static let feature = Localization(
        english: "Ring: Hue, Width: Saturation, Height: Luminance",
        japanese: "輪: 色相, 横: 彩度, 縦: 輝度"
    )
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children,
                   oldChildren: oldValue)
        }
    }
    
    weak var delegate: ColorPickerDelegate?
    let layer: CALayer
    private let hWidth = 2.2.cf, inPadding = 8.0.cf, outPadding = 8.0.cf, slPadding = 6.0.cf
    private let colorLayer: DrawLayer
    private let editSLLayer = CALayer()
    private let slColorLayer = CAGradientLayer(), slBlackWhiteLayer = CAGradientLayer()
    private let hKnobLayer = CALayer.knobLayer(), slKnobLayer = CALayer.knobLayer()
    private var slBounds = CGRect(), colorCircle = ColorCircle()
    init(frame: CGRect,
         description: Localization = Localization()) {
        self.instanceDescription = description
        self.layer = CALayer.interfaceLayer()
        layer.frame = frame
        self.colorLayer = DrawLayer(backgroundColor: .background)
        colorLayer.frame = CGRect(x: 0,
                                  y: 0,
                                  width: frame.width,
                                  height: frame.height)
        colorCircle = ColorCircle(width: 2.5,
                                  bounds: colorLayer.bounds.inset(by: 6))
        colorLayer.drawBlock = { [unowned self] ctx in
            self.colorCircle.draw(in: ctx)
        }
        colorLayer.addSublayer(hKnobLayer)
        let r = floor(min(bounds.size.width, bounds.size.height) / 2)
        let sr = r - hWidth - inPadding - outPadding - slPadding * sqrt(2)
        let b2 = floor(sr * 0.82)
        let a2 = floor(sqrt(sr * sr - b2 * b2))
        slBounds = CGRect(x: bounds.size.width / 2 - a2, y: bounds.size.height / 2 - b2, width: a2 * 2, height: b2 * 2)
        
        editSLLayer.backgroundColor = Color.background.cgColor
        editSLLayer.borderColor = Color.border.cgColor
        editSLLayer.borderWidth = 0.5
        editSLLayer.frame = slBounds.inset(by: -slPadding)
        
        slColorLayer.frame = slBounds
        slColorLayer.startPoint = CGPoint(x: 0, y: 0)
        slColorLayer.endPoint = CGPoint(x: 1, y: 0)
        
        slBlackWhiteLayer.frame = slBounds
        slBlackWhiteLayer.startPoint = CGPoint(x: 0, y: 0)
        slBlackWhiteLayer.endPoint = CGPoint(x: 0, y: 1)
        slBlackWhiteLayer.colors = [
            Color(white: 0, alpha: 1).cgColor,
            Color(white: 0, alpha: 0).cgColor,
            Color(white: 1, alpha: 0).cgColor,
            Color(white: 1, alpha: 1).cgColor
        ]
        
        layer.sublayers = [colorLayer, editSLLayer, slColorLayer, slBlackWhiteLayer, slKnobLayer]
        updateSublayers()
    }
    private func updateSublayers() {
        CATransaction.disableAnimation {
            let hueAngle = colorCircle.angle(withHue: color.hue)
            let y = Color.y(withHue: color.hue), r = colorCircle.radius - colorCircle.width / 2
            slColorLayer.colors = [
                Color(hue: color.hue, saturation: 0, brightness: y).cgColor,
                Color(hue: color.hue, saturation: 1, brightness: 1).cgColor
            ]
            slBlackWhiteLayer.locations = [0, NSNumber(value: y), NSNumber(value: y), 1]
            hKnobLayer.position = CGPoint(
                x: colorLayer.bounds.midX + r * cos(CGFloat(hueAngle)),
                y: colorLayer.bounds.midY + r * sin(CGFloat(hueAngle))
            )
            slKnobLayer.position = CGPoint(
                x: slBounds.origin.x + CGFloat(color.saturation) * slBounds.size.width,
                y: slBounds.origin.y + CGFloat(color.lightness) * slBounds.size.height
            )
        }
    }
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            colorLayer.contentsScale = newValue
        }
    }
    
    var color = Color() {
        didSet {
            updateSublayers()
        }
    }
    func updateViewWithColorSpace() {
        slBlackWhiteLayer.colors = [
            Color(white: 0, alpha: 1, colorSpace: color.colorSpace).cgColor,
            Color(white: 0, alpha: 0, colorSpace: color.colorSpace).cgColor,
            Color(white: 1, alpha: 0, colorSpace: color.colorSpace).cgColor,
            Color(white: 1, alpha: 1, colorSpace: color.colorSpace).cgColor
        ]
        colorCircle = ColorCircle(width: 2.5, bounds: colorLayer.bounds.inset(by: 6), colorSpace: color.colorSpace)
        colorLayer.drawBlock = { [unowned self] ctx in
            self.colorCircle.draw(in: ctx)
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [color])
    }
    func paste(copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let color = object as? Color {
                let oldColor = self.color
                delegate?.changeColor(self, color: oldColor, oldColor: oldColor, type: .begin)
                self.color = color
                delegate?.changeColor(self, color: color, oldColor: oldColor, type: .end)
                return
            }
        }
    }
    func delete(with event: KeyInputEvent) {
        let oldColor = color, newColor = Color()
        if oldColor != newColor {
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .begin)
            color = newColor
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .end)
        }
    }
    
    private var editH = false, oldPoint = CGPoint(), oldColor = Color()
    func slowDrag(with event: DragEvent) {
        drag(with: event, isSlow: true)
    }
    func drag(with event: DragEvent) {
        drag(with: event, isSlow: false)
    }
    func drag(with event: DragEvent, isSlow: Bool) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldColor = color
            oldPoint = p
            editH = !slBounds.inset(by: -slPadding).contains(p)
            if editH {
                setColor(withHPosition: p)
                hKnobLayer.backgroundColor = Color.edit.cgColor
            } else {
                setColor(withSLPosition: p)
                slKnobLayer.backgroundColor = Color.edit.cgColor
            }
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .begin)
        case .sending:
            if editH {
                setColor(withHPosition: isSlow ? p.mid(oldPoint) : p)
            } else {
                setColor(withSLPosition: isSlow ? p.mid(oldPoint) : p)
            }
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .sending)
        case .end:
            if editH {
                setColor(withHPosition:isSlow ? p.mid(oldPoint) : p)
                hKnobLayer.backgroundColor = Color.knob.cgColor
            } else {
                setColor(withSLPosition: isSlow ? p.mid(oldPoint) : p)
                slKnobLayer.backgroundColor = Color.knob.cgColor
            }
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .end)
        }
    }
    private func setColor(withHPosition point: CGPoint) {
        let angle = atan2(point.y - colorLayer.bounds.midY, point.x - colorLayer.bounds.midX)
        color = color.with(hue: colorCircle.hue(withAngle: Double(angle)))
    }
    private func setColor(withSLPosition point: CGPoint) {
        let saturation = ((point.x - slBounds.origin.x) / slBounds.size.width).clip(min: 0, max: 1)
        let lightness = ((point.y - slBounds.origin.y) / slBounds.size.height).clip(min: 0, max: 1)
        color = color.with(saturation: Double(saturation), lightness: Double(lightness))
    }
}

struct ColorCircle {
    let width: CGFloat, bounds: CGRect, radius: CGFloat, colorSpace: ColorSpace
    
    init(width: CGFloat = 2, bounds: CGRect = CGRect(), colorSpace: ColorSpace = .sRGB) {
        self.width = width
        self.bounds = bounds
        self.radius = min(bounds.width, bounds.height) / 2
        self.colorSpace = colorSpace
    }
    
    func hue(withAngle angle: Double) -> Double {
        let a = (angle < -.pi + .pi / 6 ? 2 * (.pi) : 0) +  angle - .pi / 6
        return hue(withRevisionHue: (a < 0 ? 1 : 0) + a / (2 * (.pi)))
    }
    func angle(withHue hue: Double) -> Double {
        return revisionHue(withHue: hue) * 2 * (.pi) + .pi / 6
    }
    
    private let split = 1.0 / 12.0, slow = 0.5, fast = 1.5
    private func revisionHue(withHue hue: Double) -> Double {
        if hue < split {
            return hue * fast
        } else if hue < split * 2 {
            return (hue - split) * slow + split * fast
        } else if hue < split * 3 {
            return (hue - split * 2) * slow + split * (fast + slow)
        } else if hue < split * 4 {
            return (hue - split * 3) * fast + split * (fast + slow * 2)
        } else if hue < split * 5 {
            return (hue - split * 4) * fast + split * (fast * 2 + slow * 2)
        } else if hue < split * 6 {
            return (hue - split * 5) * slow + split * (fast * 3 + slow * 2)
        } else if hue < split * 7 {
            return (hue - split * 6) * slow + split * (fast * 3 + slow * 3)
        } else if hue < split * 8 {
            return (hue - split * 7) * fast + split * (fast * 3 + slow * 4)
        } else if hue < split * 9 {
            return (hue - split * 8) * fast + split * (fast * 4 + slow * 4)
        } else if hue < split * 10 {
            return (hue - split * 9) * slow + split * (fast * 5 + slow * 4)
        } else if hue < split * 11 {
            return (hue - split * 10) * slow + split * (fast * 5 + slow * 5)
        } else {
            return (hue - split * 11) * fast + split * (fast * 5 + slow * 6)
        }
    }
    private func hue(withRevisionHue revisionHue: Double) -> Double {
        if revisionHue < split * fast {
            return revisionHue / fast
        } else if revisionHue < split * (fast + slow) {
            return (revisionHue - split * fast) / slow + split
        } else if revisionHue < split * (fast + slow * 2) {
            return (revisionHue - split * (fast + slow)) / slow + split * 2
        } else if revisionHue < split * (fast * 2 + slow * 2) {
            return (revisionHue - split * (fast + slow * 2)) / fast + split * 3
        } else if revisionHue < split * (fast * 3 + slow * 2) {
            return (revisionHue - split * (fast * 2 + slow * 2)) / fast + split * 4
        } else if revisionHue < split * (fast * 3 + slow * 3) {
            return (revisionHue - split * (fast * 3 + slow * 2)) / slow + split * 5
        } else if revisionHue < split * (fast * 3 + slow * 4) {
            return (revisionHue - split * (fast * 3 + slow * 3)) / slow + split * 6
        } else if revisionHue < split * (fast * 4 + slow * 4) {
            return (revisionHue - split * (fast * 3 + slow * 4)) / fast + split * 7
        } else if revisionHue < split * (fast * 5 + slow * 4) {
            return (revisionHue - split * (fast * 4 + slow * 4)) / fast + split * 8
        } else if revisionHue < split * (fast * 5 + slow * 5) {
            return (revisionHue - split * (fast * 5 + slow * 4)) / slow + split * 9
        } else if revisionHue < split * (fast * 5 + slow * 6) {
            return (revisionHue - split * (fast * 5 + slow * 5)) / slow + split * 10
        } else {
            return (revisionHue - split * (fast * 5 + slow * 6)) / fast + split * 11
        }
    }
    func draw(in ctx: CGContext) {
        let outR = radius
        let inR = outR - width, deltaAngle = 1 / outR, splitCount = Int(ceil(2 * (.pi) * outR))
        let inChord = 2 + inR / outR, outChord = 2.0.cf
        let points = [
            CGPoint(x: inR, y: inChord / 2), CGPoint(x: outR, y: outChord / 2),
            CGPoint(x: outR, y: -outChord / 2), CGPoint(x: inR, y: -inChord / 2)
        ]
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: .pi / 6 - deltaAngle / 2)
        for i in 0 ..< splitCount {
            ctx.setFillColor(
                Color(hue: revisionHue(withHue: Double(i) / Double(splitCount)), saturation: 1, brightness: 1, colorSpace: colorSpace).cgColor
            )
            ctx.addLines(between: points)
            ctx.fillPath()
            ctx.rotate(by: deltaAngle)
        }
        ctx.restoreGState()
    }
}
