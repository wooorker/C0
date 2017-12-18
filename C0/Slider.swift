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

protocol Slidable {
    var value: CGFloat { get set }
    var defaultValue: CGFloat { get }
    var minValue: CGFloat { get }
    var maxValue: CGFloat { get }
    var exp: CGFloat { get }
    var isInvert: Bool { get }
    var isVertical: Bool { get }
}

protocol SliderDelegate: class {
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType)
}
final class Slider: LayerRespondable, Equatable, Slidable {
    static let name = Localization(english: "Slider", japanese: "スライダー")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    weak var delegate: SliderDelegate?
    
    var value = 0.0.cf {
        didSet {
            updateKnobPosition()
        }
    }
    
    let layer: CALayer, knobLayer = CALayer.knobLayer()
    
    init(frame: CGRect = CGRect(),
         value: CGFloat = 0, defaultValue: CGFloat = 0,
         min: CGFloat = 0, max: CGFloat = 1,
         isInvert: Bool = false, isVertical: Bool = false,
         exp: CGFloat = 1, valueInterval: CGFloat = 0,
         description: Localization = Localization()) {
        
        self.layer = CALayer.interfaceLayer()
        self.value = value.clip(min: min, max: max)
        self.defaultValue = defaultValue
        self.minValue = min
        self.maxValue = max
        self.isInvert = isInvert
        self.isVertical = isVertical
        self.exp = exp
        self.valueInterval = valueInterval
        self.instanceDescription = description
        
        layer.frame = frame
        updateKnobPosition()
        layer.addSublayer(knobLayer)
    }
    var unit = "", numberOfDigits = 0
    var knobY = 0.0.cf, viewPadding = 10.0.cf, isNumberEdit = false
    var defaultValue = 0.0.cf, minValue: CGFloat, maxValue: CGFloat, valueInterval = 0.0.cf
    var exp = 1.0.cf, isInvert = false, isVertical = false, slideMinMax = false
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateKnobPosition()
        }
    }
    func updateKnobPosition() {
        if minValue < maxValue {
            CATransaction.disableAnimation {
                let t = (value - minValue) / (maxValue - minValue)
                if isVertical {
                    let y = viewPadding + (bounds.height - viewPadding * 2)
                        * pow(isInvert ? 1 - t : t, 1 / exp)
                    knobLayer.position = CGPoint(x: bounds.midX, y: y)
                } else {
                    let x = viewPadding + (bounds.width - viewPadding * 2)
                        * pow(isInvert ? 1 - t : t, 1 / exp)
                    knobLayer.position = CGPoint(x: x, y: knobY == 0 ? bounds.midY : knobY)
                }
            }
        }
    }
    
    func delete(with event: KeyInputEvent) {
        oldValue = value
        let newValue = defaultValue.clip(min: minValue, max: maxValue)
        if oldValue != newValue {
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
            value = defaultValue.clip(min: minValue, max: maxValue)
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
        }
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [String(value.d)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let string = object as? String {
                if let v = Double(string)?.cf {
                    oldValue = value
                    delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
                    value = v.clip(min: minValue, max: maxValue)
                    delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
                    return
                }
            }
        }
    }
    
    private var oldValue = 0.0.cf, oldMinValue = 0.0.cf, oldMaxValue = 0.0.cf, oldPoint = CGPoint()
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldValue = value
            oldMinValue = minValue
            oldMaxValue = maxValue
            oldPoint = p
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
            updateValue(p)
            knobLayer.backgroundColor = Color.edit.cgColor
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .sending)
        case .sending:
            updateValue(p)
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .sending)
        case .end:
            updateValue(p)
            knobLayer.backgroundColor = Color.knob.cgColor
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
        }
    }
    private func intervalValue(value v: CGFloat) -> CGFloat {
        if valueInterval == 0 {
            return v
        } else {
            let t = floor(v / valueInterval) * valueInterval
            if v - t > valueInterval / 2 {
                return t + valueInterval
            } else {
                return t
            }
        }
    }
    func updateValue(_ point: CGPoint) {
        if slideMinMax && value == maxValue {
            let delta = floor(point.x - oldPoint.x)
            minValue = oldMinValue + delta
            maxValue = oldMaxValue + delta
        } else {
            let v: CGFloat
            if isVertical {
                let h = bounds.height - viewPadding * 2
                if h > 0 {
                    let y = (point.y - viewPadding).clip(min: 0, max: h)
                    v = (maxValue - minValue) * pow((isInvert ? (h - y) : y) / h, exp) + minValue
                } else {
                    v = minValue
                }
            } else {
                let w = bounds.width - viewPadding * 2
                if w > 0 {
                    let x = (point.x - viewPadding).clip(min: 0, max: w)
                    v = (maxValue - minValue) * pow((isInvert ? (w - x) : x) / w, exp) + minValue
                } else {
                    v = minValue
                }
            }
            value = intervalValue(value: v).clip(min: minValue, max: maxValue)
        }
    }
}

protocol NumberSliderDelegate: class {
    func changeValue(_ slider: NumberSlider, value: CGFloat, oldValue: CGFloat, type: Action.SendType)
}
final class NumberSlider: LayerRespondable, Equatable, Slidable {
    static let name = Localization(english: "Number Slider", japanese: "数値スライダー")
    static let feature = Localization(english: "Change value: Left and right drag",
                                      japanese: "値を変更: 左右ドラッグ")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    weak var delegate: NumberSliderDelegate?
    
    var value = 0.0.cf {
        didSet {
            updateText()
        }
    }
    
    private let knobLayer = CALayer.knobLayer(radius: 3, lineWidth: 1)
    private let lineLayer: CAShapeLayer = {
        let lineLayer = CAShapeLayer()
        lineLayer.fillColor = Color.content.cgColor
        return lineLayer
    }()
    
    let label: Label
    let layer = CALayer.interfaceLayer()
    init(frame: CGRect = CGRect(), value: CGFloat = 0, defaultValue: CGFloat = 0,
         min: CGFloat = 0, max: CGFloat = 1, isInvert: Bool = false,
         isVertical: Bool = false, exp: CGFloat = 1, valueInterval: CGFloat = 0,
         numberOfDigits: Int = 0, unit: String = "", font: Font = .small,
         description: Localization = Localization()) {
        
        self.unit = unit
        self.value = value.clip(min: min, max: max)
        self.defaultValue = defaultValue
        self.minValue = min
        self.maxValue = max
        self.isInvert = isInvert
        self.isVertical = isVertical
        self.exp = exp
        self.valueInterval = valueInterval
        self.numberOfDigits = numberOfDigits
        self.instanceDescription = description
        self.label = Label(font: font)
        label.frame.origin.x = arrowWidth
        label.frame.origin.y = round((frame.height - label.frame.height) / 2)
        layer.frame = frame
        children = [label]
        update(withChildren: children, oldChildren: [])
        layer.addSublayer(lineLayer)
        layer.addSublayer(knobLayer)
        updateKnobPosition()
    }
    var unit = "", numberOfDigits = 0
    var knobY = 0.0.cf, viewPadding = 10.0.cf, isNumberEdit = false
    var defaultValue = 0.0.cf, minValue: CGFloat, maxValue: CGFloat, valueInterval = 0.0.cf
    var exp = 1.0.cf, isInvert = false, isVertical = false, slideMinMax = false
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateText()
            label.frame.origin.y = round((newValue.height - label.frame.height) / 2)
        }
    }
    func updateText() {
        CATransaction.disableAnimation {
            if value - floor(value) > 0 {
                label.text.string = String(format: numberOfDigits == 0 ?
                    "%g" : "%.\(numberOfDigits)f", value) + "\(unit)"
            } else {
                label.text.string = "\(Int(value))" + "\(unit)"
            }
        }
    }
    
    let arrowWidth = Layout.basicPadding, arrowRadius = 3.0.cf
    func updateKnobPosition() {
        let path = CGMutablePath()
        path.addRect(CGRect(x: 5, y: 3, width: bounds.width - 10, height: 1))
        knobLayer.position = CGPoint(x: bounds.midX, y: 3.5)
        lineLayer.path = path
    }
    
    func delete(with event: KeyInputEvent) {
        oldValue = value
        let newValue = defaultValue.clip(min: minValue, max: maxValue)
        if oldValue != newValue {
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
            value = defaultValue.clip(min: minValue, max: maxValue)
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
        }
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [String(value.d)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let string = object as? String, let v = Double(string)?.cf {
                oldValue = value
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
                value = v.clip(min: minValue, max: maxValue)
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
                return
            }
        }
    }
    
    private var valueX = 2.0.cf, valueLog = -2
    private var oldValue = 0.0.cf, oldMinValue = 0.0.cf, oldMaxValue = 0.0.cf, oldPoint = CGPoint()
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldValue = value
            oldMinValue = minValue
            oldMaxValue = maxValue
            oldPoint = p
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
        case .sending:
            let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
            let v =  oldValue.interval(scale: valueInterval) + value(with: d)
            value = v.clip(min: minValue, max: maxValue)
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .sending)
        case .end:
            let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
            let v = oldValue.interval(scale: valueInterval) + value(with: d)
            value = v.clip(min: minValue, max: maxValue)
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
        }
    }
    func value(with delta: CGFloat) -> CGFloat {
        return ((delta / valueX) * valueInterval).interval(scale: valueInterval)
    }
}
