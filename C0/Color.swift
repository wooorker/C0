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

import Foundation
import QuartzCore

struct Color: Hashable, Equatable, Interpolatable, ByteCoding, Drawable {
    static let name = Localization(english: "Color", japanese: "カラー")
    
    static let white = Color(hue: 0, saturation: 0, lightness: 1)
    static let black = Color(hue: 0, saturation: 0, lightness: 0)
    static let red = Color(red: 1, green: 0, blue: 0)
    static let orange = Color(red: 1, green: 0.5, blue: 0)
    static let yellow = Color(red: 1, green: 1, blue: 0)
    static let green = Color(red: 0, green: 1, blue: 0)
    
    static let background = Color(white: 0.81)
    static let subBackground = Color(white: 0.89)
    static let subBackground2 = Color(white: 0.905)
    static let subBackground3 = Color(white: 0.92)
    static let subBackground4 = Color(white: 0.86)
    static let translucentSubBackground = Color(white: 0.85)
    static let subSecondBackground = Color(white: 0.87)
    static let subEdit = Color(white: 0.84)
    static let subSecondEdit = Color(white: 0.83)
    static let content = Color.white
    static let contentBorder = Color(white: 0.973)
    static let contentEdit = Color(white: 0.3)
    static let indicationSelection = Color(white: 0.88)
    static let edit = Color(white: 0.68)
    static let editing = Color(white: 0.9)
    static let indication = Color(red: 0.1, green: 0.7, blue: 1, alpha: 0.3)
    static let selection = Color(red: 0.1, green: 0.7, blue: 1)
    static let menu = Color(white: 0.96)
    static let panelBorder = Color(white: 0)
    static let translucentBackground = Color(white: 0, alpha: 0.1)
    static let font = Color(white: 0.05)
    static let smallFont = Color(white: 0.5)
    static let actionBackground = Color(white: 0.92)
    static let temporaryNoAction = Color.orange
    static let warning = Color.red
    
    static let rough = Color(red: 0, green: 0.5, blue: 1, alpha: 0.15)
    static let subRough = Color(red: 0, green: 0.5, blue: 1, alpha: 0.1)
    static let previous = Color(red: 1, green: 0, blue: 0, alpha: 0.1)
    static let subPrevious = Color(red: 1, green: 0.2, blue: 0.2, alpha: 0.025)
    static let previousSkin = previous.with(alpha: 1)
    static let subPreviousSkin = subPrevious.with(alpha: 0.08)
    static let next = Color(red: 0.2, green: 0.8, blue: 0, alpha: 0.1)
    static let subNext = Color(red: 0.4, green: 1, blue: 0, alpha: 0.025)
    static let nextSkin = next.with(alpha: 1)
    static let subNextSkin = subNext.with(alpha: 0.08)
    static let interpolation = Color(red: 1.0, green: 0.2, blue: 0.0)
    static let subSelection = Color(red: 0.8, green: 0.95, blue: 1, alpha: 0.6)
    static let subSelectionSkin =  subSelection.with(alpha: 0.3)
    static let selectionSkinLine =  subSelection.with(alpha: 1)
    static let snap = Color(red: 0.5, green: 0, blue: 1)
    static let editMaterial = Color(red: 1, green: 0.5, blue: 0, alpha: 0.5)
    static let editMaterialColorOnly = Color(red: 1, green: 0.75, blue: 0, alpha: 0.5)
    static let cellBorderNormal = Color(red: 0, green: 0, blue: 1, alpha: 0.2)
    static let cellBorder = Color(white: 0, alpha: 0.5)
    static let cellIndicationNormal = selection.with(alpha: 0.9)
    static let cellIndication = selection.with(alpha: 0.4)
    static let timelineRough = Color(red: 1, green: 1, blue: 0.2)
    static let controlPointIn = content
    static let controlEditPointIn = Color(red: 1, green: 1, blue: 0)
    static let controlPointCapIn = content
    static let controlPointJointIn = Color(red: 1, green: 0, blue: 0)
    static let controlPointOtherJointIn = Color(red: 1, green: 0.5, blue: 1)
    static let controlPointUnionIn = Color(red: 0, green: 1, blue: 0.2)
    static let controlPointPathIn = Color(red: 0, green: 1, blue: 1)
    static let controlPointOut = edit
    static let editControlPointIn = Color(red: 1, green: 0, blue: 0, alpha: 0.8)
    static let editControlPointOut = Color(red: 1, green: 0.5, blue: 0.5, alpha: 0.3)
    static let contolLineIn = Color(red: 1, green: 0.5, blue: 0.5, alpha: 0.3)
    static let contolLineOut = Color(red: 1, green: 0, blue: 0, alpha: 0.3)
    static let moveZ = Color(red: 1, green: 0, blue: 0)
    static let moveZSelection = Color(red: 1, green: 0.5, blue: 0)
    static let camera = Color(red: 0.7, green: 0.6, blue: 0)
    static let cameraBorder = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    static let cutBorder = Color(red: 0.3, green: 0.46, blue: 0.7, alpha: 0.5)
    static let cutSubBorder = Color(white: 1, alpha: 0.5)
    static let strokeLine = Color(white: 0)
    static let playBorder = Color(white: 0.3)
    static let rotateCaution = Color.red
    static let speechBorder = Color(white: 0)
    static let speechFill = Color.white
    
    let hue: CGFloat, saturation: CGFloat, lightness: CGFloat, rgb: RGB, alpha: CGFloat, id: UUID
    
    static func random() -> Color {
        let hue = CGFloat.random(min: 0, max: 1)
        let saturation = CGFloat.random(min: 0.5, max: 1)
        let lightness = CGFloat.random(min: 0.4, max: 0.9)
        return Color(hue: hue, saturation: saturation, lightness: lightness)
    }
    init(hue: CGFloat = 0, saturation: CGFloat = 0, lightness: CGFloat = 0, alpha: CGFloat = 1) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        self.rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
        self.alpha = alpha
        self.id = UUID()
    }
    init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat = 1) {
        let hsv = HSV(h: hue, s: saturation, v: brightness)
        self.init(hsv: hsv, rgb: hsv.rgb, alpha: alpha)
    }
    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        let rgb = RGB(r: red, g: green, b: blue)
        self.init(hsv: rgb.hsv, rgb: rgb, alpha: alpha)
    }
    init(white: CGFloat, alpha: CGFloat = 1) {
        self.init(hue: 0, saturation: 0, lightness: white, alpha: alpha)
    }
    var cgColor: CGColor {
        return CGColor.with(rgb: rgb, alpha: alpha)
    }
    private static func hsvWithHSL(h: CGFloat, s: CGFloat, l: CGFloat) -> HSV {
        let y = Color.y(withHue: h)
        if y < l {
            let by = y == 1 ? 0 : (l - y)/(1 - y)
            return HSV(h: h, s: -s*by + s, v: (1 - y)*(-s*by + s + by) + y)
        } else {
            let by = y == 0 ? 0 : l/y
            return HSV(h: h, s: s, v: s*by*(1 - y) + by*y)
        }
    }
    var hsv: HSV {
        return Color.hsvWithHSL(h: hue, s: saturation, l: lightness)
    }
    init(hsv: HSV, rgb: RGB, alpha: CGFloat) {
        let h = hsv.h, s = hsv.s, v = hsv.v
        let y = Color.y(withHue: h), saturation: CGFloat, lightness: CGFloat
        let n = s*(1 - y) + y
        let nb = n == 0 ? 0 : y*v/n
        if nb < y {
            saturation = s
            lightness = nb
        } else {
            let n = 1 - y
            let nb = n == 0 ? 1 : (v - y)/n - s
            lightness = n*nb + y
            saturation = nb == 1 ? 0 : s/(1 - nb)
        }
        self.hue =  h
        self.saturation = saturation
        self.lightness = lightness
        self.rgb = rgb
        self.alpha = alpha
        self.id = UUID()
    }
    
    func withNewID() -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func withHue(_ hue: CGFloat) -> Color {
        return Color(hue: hue, saturation: saturation, lightness:  lightness, alpha: alpha)
    }
    func withSaturation(_ saturation: CGFloat) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func withLightness(_ lightness: CGFloat) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(saturation: CGFloat, lightness: CGFloat) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(alpha: CGFloat) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    
    func multiply(alpha: CGFloat) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha*alpha)
    }
    func multiply(white: CGFloat) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness + (1 - lightness)*white, alpha: alpha)
    }
    
    static func y(withHue hue: CGFloat) -> CGFloat {
        let hueRGB = HSV(h: hue, s: 1, v: 1).rgb
        return 0.299*hueRGB.r + 0.587*hueRGB.g + 0.114*hueRGB.b
    }
    
    static func linear(_ f0: Color, _ f1: Color, t: CGFloat) -> Color {
        let hue = CGFloat.linear(f0.hue, f1.hue.loopValue(other: f0.hue), t: t).loopValue()
        let saturation = CGFloat.linear(f0.saturation, f1.saturation, t: t)
        let lightness = CGFloat.linear(f0.lightness, f1.lightness, t: t)
        return Color(hue: hue, saturation: saturation, lightness: lightness)
    }
    static func firstMonospline(_ f1: Color, _ f2: Color, _ f3: Color, with msx: MonosplineX) -> Color {
        let hue = CGFloat.firstMonospline(f1.hue, f2.hue.loopValue(other: f1.hue), f3.hue.loopValue(other: f1.hue), with: msx).loopValue()
        let saturation = CGFloat.firstMonospline(f1.saturation, f2.saturation, f3.saturation, with: msx)
        let lightness = CGFloat.firstMonospline(f1.lightness, f2.lightness, f3.lightness, with: msx)
        return Color(hue: hue, saturation: saturation, lightness: lightness)
    }
    static func monospline(_ f0: Color, _ f1: Color, _ f2: Color, _ f3: Color, with msx: MonosplineX) -> Color {
        let hue = CGFloat.monospline(
            f0.hue, f1.hue.loopValue(other: f0.hue), f2.hue.loopValue(other: f0.hue), f3.hue.loopValue(other: f0.hue), with: msx
        ).loopValue()
        let saturation = CGFloat.monospline(f0.saturation, f1.saturation, f2.saturation, f3.saturation, with: msx)
        let lightness = CGFloat.monospline(f0.lightness, f1.lightness, f2.lightness, f3.lightness, with: msx)
        return Color(hue: hue, saturation: saturation, lightness: lightness)
    }
    static func endMonospline(_ f0: Color, _ f1: Color, _ f2: Color, with msx: MonosplineX) -> Color {
        let hue = CGFloat.endMonospline(f0.hue, f1.hue.loopValue(other: f0.hue), f2.hue.loopValue(other: f0.hue), with: msx).loopValue()
        let saturation = CGFloat.endMonospline(f0.saturation, f1.saturation, f2.saturation, with: msx)
        let lightness = CGFloat.endMonospline(f0.lightness, f1.lightness, f2.lightness, with: msx)
        return Color(hue: hue, saturation: saturation, lightness: lightness)
    }
    
    var hashValue: Int {
        return id.hashValue
    }
    static func == (lhs: Color, rhs: Color) -> Bool {
        return lhs.id == rhs.id
    }
    
    func draw(with bounds: CGRect, in ctx: CGContext) {
        ctx.setFillColor(cgColor)
        ctx.fillEllipse(in: bounds.inset(by: 5))
    }
}
struct RGB {
    let r: CGFloat, g: CGFloat, b: CGFloat
    var hsv: HSV {
        let min = Swift.min(r, g, b), max = Swift.max(r, g, b)
        let d = max - min
        let h: CGFloat, s = max == 0 ? d : d/max, v = max
        if d > 0 {
            if r == max {
                let hh = (g - b)/d
                h = (hh < 0 ? hh + 6 : hh)/6
            } else if g == max {
                h = (2 + (b - r)/d)/6
            } else {
                h = (4 + (r - g)/d)/6
            }
        } else {
            h = d/6
        }
        return HSV(h: h, s: s, v: v)
    }
}
struct HSV {
    let h: CGFloat, s: CGFloat, v: CGFloat
    var rgb: RGB {
        guard s != 0 else {
            return RGB(r: v, g: v, b: v)
        }
        let h6 = 6*h
        let hi = Int(h6)
        let nh = h6 - hi.cf
        switch (hi) {
        case 0:
            return RGB(r: v, g: v*(1 - s*(1 - nh)), b: v*(1 - s))
        case 1:
            return RGB(r: v*(1 - s*nh), g: v, b: v*(1 - s))
        case 2:
            return RGB(r: v*(1 - s), g: v, b: v*(1 - s*(1 - nh)))
        case 3:
            return RGB(r: v*(1 - s), g: v*(1 - s*nh), b: v)
        case 4:
            return RGB(r: v*(1 - s*(1 - nh)), g: v*(1 - s), b: v)
        default:
            return RGB(r: v, g: v*(1 - s), b: v*(1 - s*nh))
        }
    }
}
extension CGColor {
    static func with(rgb: RGB, alpha a: CGFloat = 1.0, colorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()) -> CGColor {
        return CGColor(colorSpace: colorSpace, components: [rgb.r, rgb.g, rgb.b, a]) ?? CGColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: a)
    }
}

protocol ColorPickerDelegate: class {
    func changeColor(_ colorPicker: ColorPicker, color: Color, oldColor: Color, type: Action.SendType)
}
final class ColorPicker: LayerRespondable {
    static let name = Localization(english: "Color Picker", japanese: "カラーピッカー")
    static let description = Localization(english: "Ring: Hue, Width: Saturation, Height: Luminance", japanese: "輪: 色相, 横: 彩度, 縦: 輝度")
    var description: Localization
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: ColorPickerDelegate?
    let layer = CALayer.interfaceLayer()
    private let hWidth = 2.2.cf, inPadding = 6.0.cf,  outPadding = 6.0.cf, sbPadding = 6.0.cf
    private let colorLayer: DrawLayer
    private let editSBLayer = CALayer()
    private let sbColorLayer = CAGradientLayer(), sbBlackWhiteLayer = CAGradientLayer()
    private let hKnobLayer = CALayer.knobLayer(), sbKnobLayer = CALayer.knobLayer()
    private var sbBounds = CGRect(), colorCircle = ColorCircle()
    init(frame: CGRect, description: Localization = Localization()) {
        self.description = description
        layer.frame = frame
        self.colorLayer = DrawLayer(fillColor: Color.subBackground)
        colorLayer.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        colorCircle = ColorCircle(width: 2.5, bounds: colorLayer.bounds.inset(by: 6))
        colorLayer.drawBlock = { [unowned self] ctx in
            self.colorCircle.draw(in: ctx)
        }
        colorLayer.addSublayer(hKnobLayer)
        let r = floor(min(bounds.size.width, bounds.size.height)/2)
        let sr = r - hWidth - inPadding - outPadding - sbPadding*sqrt(2)
        let b2 = floor(sr*0.82)
        let a2 = floor(sqrt(sr*sr - b2*b2))
        sbBounds = CGRect(x: bounds.size.width/2 - a2, y: bounds.size.height/2 - b2, width: a2*2, height: b2*2)
        
        editSBLayer.backgroundColor = Color.subEdit.cgColor
        editSBLayer.frame = sbBounds.inset(by: -sbPadding)
        
        sbColorLayer.frame = sbBounds
        sbColorLayer.startPoint = CGPoint(x: 0, y: 0)
        sbColorLayer.endPoint = CGPoint(x: 1, y: 0)
        
        sbBlackWhiteLayer.frame = sbBounds
        sbBlackWhiteLayer.startPoint = CGPoint(x: 0, y: 0)
        sbBlackWhiteLayer.endPoint = CGPoint(x: 0, y: 1)
        sbBlackWhiteLayer.colors = [
            Color(white: 0, alpha: 1).cgColor,
            Color(white: 0, alpha: 0).cgColor,
            Color(white: 1, alpha: 0).cgColor,
            Color(white: 1, alpha: 1).cgColor
        ]
        
        layer.sublayers = [colorLayer, editSBLayer, sbColorLayer, sbBlackWhiteLayer, sbKnobLayer]
        updateSublayers()
    }
    private func updateSublayers() {
        CATransaction.disableAnimation {
            let hueAngle = colorCircle.angle(withHue: color.hue)
            let y = Color.y(withHue: color.hue), r = colorCircle.radius - colorCircle.width/2
            sbColorLayer.colors = [
                Color(hue: color.hue, saturation: 0, brightness: y).cgColor,
                Color(hue: color.hue, saturation: 1, brightness: 1).cgColor
            ]
            sbBlackWhiteLayer.locations = [0, NSNumber(value: y.d), NSNumber(value: y.d), 1]
            hKnobLayer.position = CGPoint(
                x: colorLayer.bounds.midX + r*cos(hueAngle),
                y: colorLayer.bounds.midY + r*sin(hueAngle)
            )
            sbKnobLayer.position = CGPoint(
                x: sbBounds.origin.x + color.saturation*sbBounds.size.width,
                y: sbBounds.origin.y + color.lightness*sbBounds.size.height
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
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [color])
    }
    func paste(copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
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
            editH = !sbBounds.inset(by: -sbPadding).contains(p)
            if editH {
                setColor(withHPosition: p)
                hKnobLayer.backgroundColor = Color.editing.cgColor
            } else {
                setColor(withSBPosition: p)
                sbKnobLayer.backgroundColor = Color.editing.cgColor
            }
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .begin)
        case .sending:
            if editH {
                setColor(withHPosition: isSlow ? p.mid(oldPoint) : p)
            } else {
                setColor(withSBPosition: isSlow ? p.mid(oldPoint) : p)
            }
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .sending)
        case .end:
            if editH {
                setColor(withHPosition:isSlow ? p.mid(oldPoint) : p)
                hKnobLayer.backgroundColor = Color.content.cgColor
            } else {
                setColor(withSBPosition: isSlow ? p.mid(oldPoint) : p)
                sbKnobLayer.backgroundColor = Color.content.cgColor
            }
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .end)
        }
    }
    private func setColor(withHPosition point: CGPoint) {
        let angle = atan2(point.y - colorLayer.bounds.size.height/2, point.x - colorLayer.bounds.size.width/2)
        color = color.withHue(colorCircle.hue(withAngle: angle))
    }
    private func setColor(withSBPosition point: CGPoint) {
        let saturation = ((point.x - sbBounds.origin.x)/sbBounds.size.width).clip(min: 0, max: 1)
        let lightness = ((point.y - sbBounds.origin.y)/sbBounds.size.height).clip(min: 0, max: 1)
        color = color.with(saturation: saturation, lightness: lightness)
    }
}

struct ColorCircle {
    let width: CGFloat, bounds: CGRect, radius: CGFloat
    
    init(width: CGFloat = 2.0.cf, bounds: CGRect = CGRect()) {
        self.width = width
        self.bounds = bounds
        self.radius = min(bounds.width, bounds.height)/2
    }
    
    func hue(withAngle angle: CGFloat) -> CGFloat {
        let a = angle + .pi  + .pi/6
        let clippedA = a > 2*(.pi) ? a - 2*(.pi) : a
        return hue(withRevisionHue: 1 - clippedA/(2*(.pi)))
    }
    func angle(withHue hue: CGFloat) -> CGFloat {
        return (1 - revisionHue(withHue: hue))*2*(.pi) + .pi - .pi/6
    }
    
    private let split = 1.0.cf/12.0.cf, slow = 0.6.cf, fast = 1.4.cf
    private func revisionHue(withHue hue: CGFloat) -> CGFloat {
        if hue < split {
            return hue*fast
        } else if hue < split*2 {
            return (hue - split)*slow + split*fast
        } else if hue < split*3 {
            return (hue - split*2)*slow + split*(fast + slow)
        } else if hue < split*4 {
            return (hue - split*3)*fast + split*(fast + slow*2)
        } else if hue < split*5 {
            return (hue - split*4)*fast + split*(fast*2 + slow*2)
        } else if hue < split*6 {
            return (hue - split*5)*slow + split*(fast*3 + slow*2)
        } else if hue < split*7 {
            return (hue - split*6)*slow + split*(fast*3 + slow*3)
        } else if hue < split*8 {
            return (hue - split*7)*fast + split*(fast*3 + slow*4)
        } else if hue < split*9 {
            return (hue - split*8)*fast + split*(fast*4 + slow*4)
        } else if hue < split*10 {
            return (hue - split*9)*slow + split*(fast*5 + slow*4)
        } else if hue < split*11 {
            return (hue - split*10)*slow + split*(fast*5 + slow*5)
        } else {
            return (hue - split*11)*fast + split*(fast*5 + slow*6)
        }
    }
    private func hue(withRevisionHue revisionHue: CGFloat) -> CGFloat {
        if revisionHue < split*fast {
            return revisionHue/fast
        } else if revisionHue < split*(fast + slow) {
            return (revisionHue - split*fast)/slow + split
        } else if revisionHue < split*(fast + slow*2) {
            return (revisionHue - split*(fast + slow))/slow + split*2
        } else if revisionHue < split*(fast*2 + slow*2) {
            return (revisionHue - split*(fast + slow*2))/fast + split*3
        } else if revisionHue < split*(fast*3 + slow*2) {
            return (revisionHue - split*(fast*2 + slow*2))/fast + split*4
        } else if revisionHue < split*(fast*3 + slow*3) {
            return (revisionHue - split*(fast*3 + slow*2))/slow + split*5
        } else if revisionHue < split*(fast*3 + slow*4) {
            return (revisionHue - split*(fast*3 + slow*3))/slow + split*6
        } else if revisionHue < split*(fast*4 + slow*4) {
            return (revisionHue - split*(fast*3 + slow*4))/fast + split*7
        } else if revisionHue < split*(fast*5 + slow*4) {
            return (revisionHue - split*(fast*4 + slow*4))/fast + split*8
        } else if revisionHue < split*(fast*5 + slow*5) {
            return (revisionHue - split*(fast*5 + slow*4))/slow + split*9
        } else if revisionHue < split*(fast*5 + slow*6) {
            return (revisionHue - split*(fast*5 + slow*5))/slow + split*10
        } else {
            return (revisionHue - split*(fast*5 + slow*6))/fast + split*11
        }
    }
    func draw(in ctx: CGContext) {
        let outR = radius
        let inR = outR - width, deltaAngle = 1/outR, splitCount = Int(ceil(2*(.pi)*outR))
        let inChord = 2 + inR/outR, outChord = 2.0.cf
        let points = [
            CGPoint(x: inChord/2, y: inR), CGPoint(x: outChord/2, y: outR),
            CGPoint(x: -outChord/2, y: outR), CGPoint(x: -inChord/2, y: inR)
        ]
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: .pi/3 - deltaAngle/2)
        for i in 0 ..< splitCount {
            ctx.setFillColor(Color(hue: revisionHue(withHue: i.cf/splitCount.cf), saturation: 1, brightness: 1).cgColor)
            ctx.addLines(between: points)
            ctx.fillPath()
            ctx.rotate(by: -deltaAngle)
        }
        ctx.restoreGState()
    }
}
