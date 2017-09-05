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
import AppKit.NSColor

protocol ColorViewDelegate: class {
    func changeColor(_ colorView: ColorView, color: HSLColor, oldColor: HSLColor, type: DragEvent.SendType)
}
final class ColorView: View {
    weak var delegate: ColorViewDelegate?
    
    private let hWidth = 2.2.cf, inPadding = 6.0.cf,  outPadding = 6.0.cf, sbPadding = 6.0.cf
    private let colorLayer: DrawLayer
    private let editSBLayer = CALayer()
    private let sbColorLayer = CAGradientLayer(), sbBlackWhiteLayer = CAGradientLayer()
    private let hKnobLayer = CALayer.knobLayer(), sbKnobLayer = CALayer.knobLayer()
    private var sbBounds = CGRect(), colorCircle = ColorCircle()
    init(frame: CGRect) {
        let layer = CALayer.interfaceLayer()
        layer.frame = frame
        self.colorLayer = DrawLayer(fillColor: Defaults.subBackgroundColor.cgColor)
        super.init(layer: layer)
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
        
         editSBLayer.backgroundColor = Defaults.subEditColor.cgColor
        editSBLayer.frame = sbBounds.inset(by: -sbPadding)
        
        sbColorLayer.frame = sbBounds
        sbColorLayer.startPoint = CGPoint(x: 0, y: 0)
        sbColorLayer.endPoint = CGPoint(x: 1, y: 0)
        
        sbBlackWhiteLayer.frame = sbBounds
        sbBlackWhiteLayer.startPoint = CGPoint(x: 0, y: 0)
        sbBlackWhiteLayer.endPoint = CGPoint(x: 0, y: 1)
        sbBlackWhiteLayer.colors = [
            NSColor(white: 0, alpha: 1).cgColor,
            NSColor(white: 0, alpha: 0).cgColor,
            NSColor(white: 1, alpha: 0).cgColor,
            NSColor(white: 1, alpha: 1).cgColor
        ]
        
        layer.sublayers = [colorLayer, editSBLayer, sbColorLayer, sbBlackWhiteLayer, sbKnobLayer]
        updateSublayers()
    }
    private func updateSublayers() {
        CATransaction.disableAnimation {
            let hueAngle = colorCircle.angle(withHue: color.hue), Y = HSLColor.y(withHue: color.hue), r = colorCircle.radius - colorCircle.width/2
            sbColorLayer.colors = [
                NSColor(hue: color.hue, saturation: 0, brightness: Y, alpha: 1).cgColor,
                NSColor(hue: color.hue, saturation: 1, brightness: 1, alpha: 1).cgColor
            ]
            sbBlackWhiteLayer.locations = [0, NSNumber(value: Y.d), NSNumber(value: Y.d), 1]
            hKnobLayer.position = CGPoint(x: colorLayer.bounds.midX + r*cos(hueAngle), y: colorLayer.bounds.midY + r*sin(hueAngle))
            sbKnobLayer.position = CGPoint(x: sbBounds.origin.x + color.saturation*sbBounds.size.width, y: sbBounds.origin.y + color.lightness*sbBounds.size.height)
        }
    }
    
    override var contentsScale: CGFloat {
        didSet {
            colorLayer.contentsScale = contentsScale
        }
    }
    
    var color = HSLColor() {
        didSet {
            updateSublayers()
        }
    }
    
    override func copy() {
        screen?.copy(color.data, forType: HSLColor.dataType, from: self)
    }
    override func paste() {
        if let data = screen?.copyData(forType: HSLColor.dataType) {
            let oldColor = color
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .begin)
            color = HSLColor(data: data)
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .end)
        }
    }
    override func delete() {
        let oldColor = color
        delegate?.changeColor(self, color: color, oldColor: oldColor, type: .begin)
        color = HSLColor()
        delegate?.changeColor(self, color: color, oldColor: oldColor, type: .end)
    }
    
    private var editH = false, oldPoint = CGPoint(), oldColor = HSLColor()
    override func slowDrag(with event: DragEvent) {
        drag(with: event, isSlow: true)
    }
    override func drag(with event: DragEvent) {
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
                hKnobLayer.backgroundColor = Defaults.editingColor.cgColor
            } else {
                setColor(withSBPosition: p)
                sbKnobLayer.backgroundColor = Defaults.editingColor.cgColor
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
                hKnobLayer.backgroundColor = Defaults.contentColor.cgColor
            } else {
                setColor(withSBPosition: isSlow ? p.mid(oldPoint) : p)
                sbKnobLayer.backgroundColor = Defaults.contentColor.cgColor
            }
            delegate?.changeColor(self, color: color, oldColor: oldColor, type: .end)
        }
    }
    private func setColor(withHPosition point: CGPoint) {
        color = color.withHue(colorCircle.hue(withAngle: atan2(point.y - colorLayer.bounds.size.height/2, point.x - colorLayer.bounds.size.width/2)))
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
        let points = [CGPoint(x: inChord/2, y: inR), CGPoint(x: outChord/2, y: outR), CGPoint(x: -outChord/2, y: outR), CGPoint(x: -inChord/2, y: inR)]
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: .pi/3 - deltaAngle/2)
        for i in 0 ..< splitCount {
            ctx.setFillColor(NSColor(hue: revisionHue(withHue: i.cf/splitCount.cf), saturation: 1, brightness: 1, alpha: 1).cgColor)
            ctx.addLines(between: points)
            ctx.fillPath()
            ctx.rotate(by: -deltaAngle)
        }
        ctx.restoreGState()
    }
}

struct HSLColor: Hashable, Equatable, Interpolatable, ByteCoding {
    let hue: CGFloat, saturation: CGFloat, lightness: CGFloat, id: UUID
    
    static func random() -> HSLColor {
        let hue = CGFloat.random(min: 0, max: 1)
        let saturation = CGFloat.random(min: 0.5, max: 1)
        let lightness = CGFloat.random(min: 0.4, max: 0.9)
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    static let white = HSLColor(hue: 0, saturation: 0, lightness: 1)
    init(hue: CGFloat = 0, saturation: CGFloat = 0, lightness: CGFloat = 0) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        self.id = UUID()
    }
    init(_ nsColor: NSColor) {
        let hue = nsColor.hueComponent, s = nsColor.saturationComponent, b = nsColor.brightnessComponent
        let y = HSLColor.y(withHue: hue), saturation: CGFloat, lightness: CGFloat
        let n = s*(1 - y) + y
        let nb = n == 0 ? 0 : y*b/n
        if nb < y {
            saturation = s
            lightness = nb
        } else {
            let n = 1 - y
            let nb = n == 0 ? 1 : (b - y)/n - s
            lightness = n*nb + y
            saturation = nb == 1 ? 0 : s/(1 - nb)
        }
        self.hue =  hue
        self.saturation = saturation
        self.lightness = lightness
        self.id = UUID()
    }
    
    static let dataType = "C0.HSLColor.1"
    func withNewID() -> HSLColor {
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    func withHue(_ hue: CGFloat) -> HSLColor {
        return HSLColor(hue: hue, saturation: saturation, lightness:  lightness)
    }
    func withSaturation(_ saturation: CGFloat) -> HSLColor {
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    func withLightness(_ lightness: CGFloat) -> HSLColor {
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    func with(saturation: CGFloat, lightness: CGFloat) -> HSLColor {
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    
    static func y(withHue hue: CGFloat) -> CGFloat {
        let hueColor = NSColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
        return 0.299*hueColor.redComponent + 0.587*hueColor.greenComponent + 0.114*hueColor.blueComponent
    }
    
    var nsColor: NSColor {
        let y = HSLColor.y(withHue: hue)
        if y < lightness {
            let by = y == 1 ? 0 : (lightness - y)/(1 - y)
            return NSColor(hue: hue, saturation: -saturation*by + saturation, brightness: (1 - y)*(-saturation*by + saturation + by) + y, alpha: 1)
        } else {
            let by = y == 0 ? 0 : lightness/y
            return NSColor(hue: hue, saturation: saturation, brightness: saturation*by*(1 - y) + by*y, alpha: 1)
        }
    }
    func correction(luminance lum: CGFloat, withFraction t: CGFloat) -> HSLColor {
        return blendColor(with: NSColor(red: lum, green: lum, blue: lum, alpha: 1), withFraction: t)
    }
    func correction(hue: CGFloat, withFraction t: CGFloat) -> HSLColor {
        return saturation != 0 ? blendColor(with: NSColor(hue: hue, saturation: 1, brightness: 1, alpha: 1), withFraction: t) : self
    }
    private func blendColor(with otherNSColor: NSColor, withFraction t: CGFloat) -> HSLColor {
        if t == 0 {
            return self
        }
        let nsColor = self.nsColor
        let red = CGFloat.linear(nsColor.redComponent, otherNSColor.redComponent, t: t)
        let green = CGFloat.linear(nsColor.greenComponent, otherNSColor.greenComponent, t: t)
        let blue = CGFloat.linear(nsColor.blueComponent, otherNSColor.blueComponent, t: t)
        return HSLColor(NSColor(red: red, green: green, blue: blue, alpha: 1))
    }
    
    static func linear(_ f0: HSLColor, _ f1: HSLColor, t: CGFloat) -> HSLColor {
        let hue = CGFloat.linear(f0.hue, f1.hue.loopValue(other: f0.hue), t: t).loopValue()
        let saturation = CGFloat.linear(f0.saturation, f1.saturation, t: t)
        let lightness = CGFloat.linear(f0.lightness, f1.lightness, t: t)
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    static func firstMonospline(_ f1: HSLColor, _ f2: HSLColor, _ f3: HSLColor, with msx: MonosplineX) -> HSLColor {
        let hue = CGFloat.firstMonospline(f1.hue, f2.hue.loopValue(other: f1.hue), f3.hue.loopValue(other: f1.hue), with: msx).loopValue()
        let saturation = CGFloat.firstMonospline(f1.saturation, f2.saturation, f3.saturation, with: msx)
        let lightness = CGFloat.firstMonospline(f1.lightness, f2.lightness, f3.lightness, with: msx)
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    static func monospline(_ f0: HSLColor, _ f1: HSLColor, _ f2: HSLColor, _ f3: HSLColor, with msx: MonosplineX) -> HSLColor {
        let hue = CGFloat.monospline(f0.hue, f1.hue.loopValue(other: f0.hue), f2.hue.loopValue(other: f0.hue), f3.hue.loopValue(other: f0.hue), with: msx).loopValue()
        let saturation = CGFloat.monospline(f0.saturation, f1.saturation, f2.saturation, f3.saturation, with: msx)
        let lightness = CGFloat.monospline(f0.lightness, f1.lightness, f2.lightness, f3.lightness, with: msx)
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    static func endMonospline(_ f0: HSLColor, _ f1: HSLColor, _ f2: HSLColor, with msx: MonosplineX) -> HSLColor {
        let hue = CGFloat.endMonospline(f0.hue, f1.hue.loopValue(other: f0.hue), f2.hue.loopValue(other: f0.hue), with: msx).loopValue()
        let saturation = CGFloat.endMonospline(f0.saturation, f1.saturation, f2.saturation, with: msx)
        let lightness = CGFloat.endMonospline(f0.lightness, f1.lightness, f2.lightness, with: msx)
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
    
    var hashValue: Int {
        return id.hashValue
    }
    static func == (lhs: HSLColor, rhs: HSLColor) -> Bool {
        return lhs.id == rhs.id
    }
}
