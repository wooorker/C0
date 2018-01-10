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

final class Slider: LayerRespondable, Equatable, Slidable {
    static let name = Localization(english: "Slider", japanese: "スライダー")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    let layer = CALayer.interface(), knobLayer = CALayer.knob()
    init(frame: CGRect = CGRect(),
         value: CGFloat = 0, defaultValue: CGFloat = 0,
         min: CGFloat = 0, max: CGFloat = 1,
         isInvert: Bool = false, isVertical: Bool = false,
         exp: CGFloat = 1, valueInterval: CGFloat = 0,
         description: Localization = Localization()) {
        
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
    
    var knobY = 0.0.cf, viewPadding = 8.0.cf
    var defaultValue = 0.0.cf, minValue: CGFloat, maxValue: CGFloat, valueInterval = 0.0.cf
    var exp = 1.0.cf, isInvert = false, isVertical = false
    
    func update(with bounds: CGRect) {
        updateKnobPosition()
    }
    func updateKnobPosition() {
        guard minValue < maxValue else {
            return
        }
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
    
    var value = 0.0.cf {
        didSet {
            updateKnobPosition()
        }
    }
    
    private func intervalValue(withValue v: CGFloat) -> CGFloat {
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
    func value(at point: CGPoint) -> CGFloat {
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
        return intervalValue(withValue: v).clip(min: minValue, max: maxValue)
    }
    
    var disabledRegisterUndo = false
    
    struct HandlerObject {
        let slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType
    }
    var setValueHandler: ((HandlerObject) -> ())?
    
    func delete(with event: KeyInputEvent) {
        let value = defaultValue.clip(min: minValue, max: maxValue)
        if value != oldValue {
            guard value != self.value else {
                return
            }
            set(value, oldValue: self.value)
        }
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [String(value.d)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let string = object as? String {
                if let value = Double(string)?.cf {
                    guard value != self.value else {
                        continue
                    }
                    set(value, oldValue: self.value)
                    return
                }
            }
        }
    }
    
    private var oldValue = 0.0.cf, oldPoint = CGPoint()
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knobLayer.backgroundColor = Color.edit.cgColor
            oldValue = value
            oldPoint = p
            setValueHandler?(HandlerObject(slider: self,
                                           value: value, oldValue: oldValue, type: .begin))
            value = self.value(at: p)
            setValueHandler?(HandlerObject(slider: self,
                                           value: value, oldValue: oldValue, type: .sending))
        case .sending:
            value = self.value(at: p)
            setValueHandler?(HandlerObject(slider: self,
                                           value: value, oldValue: oldValue, type: .sending))
        case .end:
            value = self.value(at: p)
            if value != oldValue {
                registeringUndoManager?.registerUndo(withTarget: self) { [value, oldValue] in
                    $0.set(oldValue, oldValue: value)
                }
            }
            setValueHandler?(HandlerObject(slider: self,
                                           value: value, oldValue: oldValue, type: .end))
            knobLayer.backgroundColor = Color.knob.cgColor
        }
    }
    
    func set(_ value: CGFloat, oldValue: CGFloat) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldValue, oldValue: value) }
        setValueHandler?(HandlerObject(slider: self,
                                       value: oldValue, oldValue: oldValue, type: .begin))
        self.value = value
        setValueHandler?(HandlerObject(slider: self,
                                       value: value, oldValue: oldValue, type: .end))
    }
}

final class NumberSlider: LayerRespondable, Equatable, Slidable {
    static let name = Localization(english: "Number Slider", japanese: "数値スライダー")
    static let feature = Localization(english: "Change value: Left and right drag",
                                      japanese: "値を変更: 左右ドラッグ")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var value = 0.0.cf {
        didSet {
            updateTextAndKnob()
        }
    }
    
    private let knobLayer = CALayer.discreteKnob(width: 6, height: 6, lineWidth: 1)
    private let lineLayer: CAShapeLayer = {
        let lineLayer = CAShapeLayer()
        lineLayer.fillColor = Color.content.cgColor
        return lineLayer
    } ()
    
    let label: Label
    let layer = CALayer.interface()
    init(frame: CGRect = CGRect(), value: CGFloat = 0, defaultValue: CGFloat = 0,
         min: CGFloat = 0, max: CGFloat = 1, isInvert: Bool = false,
         isVertical: Bool = false, exp: CGFloat = 1, valueInterval: CGFloat = 0,
         numberOfDigits: Int = 0, unit: String = "", font: Font = .default,
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
        layer.masksToBounds = true
        
        replace(children: [label])
        layer.addSublayer(lineLayer)
        layer.addSublayer(knobLayer)
        updateKnobPosition()
    }
    var unit = "", numberOfDigits = 0
    var viewPadding = 10.0.cf
    var defaultValue = 0.0.cf, minValue: CGFloat, maxValue: CGFloat, valueInterval = 0.0.cf
    var exp = 1.0.cf, isInvert = false, isVertical = false
    private var valueX = 2.0.cf, valueLog = -2
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateTextAndKnob()
            label.frame.origin.y = round((newValue.height - label.frame.height) / 2)
        }
    }
    func updateTextAndKnob() {
        if value - floor(value) > 0 {
            label.localization = Localization(String(format: numberOfDigits == 0 ?
                "%g" : "%.\(numberOfDigits)f", value) + "\(unit)")
        } else {
            label.localization = Localization("\(Int(value))" + "\(unit)")
        }
        if value < defaultValue {
            let x = (knobLineFrame.width / 2) * (value - minValue) / (defaultValue - minValue)
                + knobLineFrame.minX
            knobLayer.position = CGPoint(x: x, y: knobY)
        } else {
            let x = (knobLineFrame.width / 2) * (value - defaultValue) / (maxValue - defaultValue)
                + knobLineFrame.midX
            knobLayer.position = CGPoint(x: x, y: knobY)
        }
    }
    
    var isLocked = false {
        didSet {
            if isLocked != oldValue {
                label.layer.opacity = isLocked ? 0.35 : 1
            }
        }
    }
    
    var knobLineFrame = CGRect()
    let arrowWidth = Layout.basicPadding, arrowRadius = 3.0.cf, knobY = 3.5.cf
    func updateKnobPosition() {
        knobLineFrame = CGRect(x: 5, y: 3, width: bounds.width - 10, height: 1)
        let path = CGMutablePath()
        path.addRect(knobLineFrame)
        knobLayer.position = CGPoint(x: bounds.midX, y: knobY)
        lineLayer.path = path
    }
    
    func value(withDelta delta: CGFloat) -> CGFloat {
        return ((delta / valueX) * valueInterval).interval(scale: valueInterval)
    }
    func value(at p: CGPoint, oldValue: CGFloat) -> CGFloat {
        let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
        let v = oldValue.interval(scale: valueInterval) + value(withDelta: d)
        return v.clip(min: minValue, max: maxValue)
    }
    
    var disabledRegisterUndo = false
    
    struct HandlerObject {
        let slider: NumberSlider, value: CGFloat, oldValue: CGFloat, type: Action.SendType
    }
    var setValueHandler: ((HandlerObject) -> ())?
    
    func delete(with event: KeyInputEvent) {
        let value = defaultValue.clip(min: minValue, max: maxValue)
        if value != oldValue {
            guard value != self.value else {
                return
            }
            set(value, oldValue: self.value)
        }
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [String(value.d)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        guard !isLocked else {
            return
        }
        for object in copiedObject.objects {
            if let string = object as? String {
                if let v = Double(string)?.cf {
                    let value = v.clip(min: minValue, max: maxValue)
                    guard value != self.value else {
                        continue
                    }
                    set(value, oldValue: self.value)
                    return
                }
            }
        }
    }
    
    private var oldValue = 0.0.cf, oldPoint = CGPoint()
    func drag(with event: DragEvent) {
        guard !isLocked else {
            return
        }
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knobLayer.backgroundColor = Color.edit.cgColor
            oldValue = value
            oldPoint = p
            setValueHandler?(HandlerObject(slider: self,
                                           value: value, oldValue: oldValue, type: .begin))
            value = self.value(at: p, oldValue: oldValue)
            setValueHandler?(HandlerObject(slider: self,
                                           value: value, oldValue: oldValue, type: .sending))
        case .sending:
            value = self.value(at: p, oldValue: oldValue)
            setValueHandler?(HandlerObject(slider: self,
                                           value: value, oldValue: oldValue, type: .sending))
        case .end:
            value = self.value(at: p, oldValue: oldValue)
            if value != oldValue {
                registeringUndoManager?.registerUndo(withTarget: self) { [value, oldValue] in
                    $0.set(oldValue, oldValue: value)
                }
            }
            setValueHandler?(HandlerObject(slider: self,
                                           value: value, oldValue: oldValue, type: .end))
            knobLayer.backgroundColor = Color.knob.cgColor
        }
    }
    
    func set(_ value: CGFloat, oldValue: CGFloat) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldValue, oldValue: value) }
        setValueHandler?(HandlerObject(slider: self,
                                       value: oldValue, oldValue: oldValue, type: .begin))
        self.value = value
        setValueHandler?(HandlerObject(slider: self,
                                       value: value, oldValue: oldValue, type: .end))
    }
}
