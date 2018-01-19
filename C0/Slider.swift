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

protocol Slidable {
    var value: CGFloat { get set }
    var defaultValue: CGFloat { get }
    var minValue: CGFloat { get }
    var maxValue: CGFloat { get }
    var exp: CGFloat { get }
    var isInverted: Bool { get }
    var isVertical: Bool { get }
}

/**
 # Issue
 - 数を包括するNumberオブジェクトを設計、NumberEditorおよびRelativeNumberEditorに変更
 */
final class Slider: Layer, Respondable, Slidable {
    static let name = Localization(english: "Slider", japanese: "スライダー")
    
    var value = 0.0.cf {
        didSet {
            update()
        }
    }
    
    var defaultValue = 0.0.cf
    var minValue: CGFloat {
        didSet {
            update()
        }
    }
    var maxValue: CGFloat {
        didSet {
            update()
        }
    }
    
    var exp = 1.0.cf {
        didSet {
            update()
        }
    }
    var isInverted = false {
        didSet {
            update()
        }
    }
    var isVertical = false {
        didSet {
            update()
        }
    }
    var valueInterval = 0.0.cf
    
    var knobY = 0.0.cf {
        didSet {
            update()
        }
    }
    var padding = 8.0.cf {
        didSet {
            update()
        }
    }
    
    let knob = Knob()
    var backgroundLayers = [Layer]() {
        didSet {
            replace(children: backgroundLayers + [knob])
        }
    }
    
    init(frame: CGRect = CGRect(),
         value: CGFloat = 0, defaultValue: CGFloat = 0,
         min: CGFloat = 0, max: CGFloat = 1,
         isInverted: Bool = false, isVertical: Bool = false,
         exp: CGFloat = 1, valueInterval: CGFloat = 0,
         description: Localization = Localization()) {
        
        self.value = value.clip(min: min, max: max)
        self.defaultValue = defaultValue
        self.minValue = min
        self.maxValue = max
        self.isInverted = isInverted
        self.isVertical = isVertical
        self.exp = exp
        self.valueInterval = valueInterval
        
        super.init()
        instanceDescription = description
        append(child: knob)
        self.frame = frame
    }
    
    override var bounds: CGRect {
        didSet {
            update()
        }
    }
    private func update() {
        guard minValue < maxValue else {
            return
        }
        let t = (value - minValue) / (maxValue - minValue)
        if isVertical {
            let y = padding + (bounds.height - padding * 2)
                * pow(isInverted ? 1 - t : t, 1 / exp)
            knob.position = CGPoint(x: bounds.midX, y: y)
        } else {
            let x = padding + (bounds.width - padding * 2)
                * pow(isInverted ? 1 - t : t, 1 / exp)
            knob.position = CGPoint(x: x, y: knobY == 0 ? bounds.midY : knobY)
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
            let h = bounds.height - padding * 2
            if h > 0 {
                let y = (point.y - padding).clip(min: 0, max: h)
                v = (maxValue - minValue) * pow((isInverted ? (h - y) : y) / h, exp) + minValue
            } else {
                v = minValue
            }
        } else {
            let w = bounds.width - padding * 2
            if w > 0 {
                let x = (point.x - padding).clip(min: 0, max: w)
                v = (maxValue - minValue) * pow((isInverted ? (w - x) : x) / w, exp) + minValue
            } else {
                v = minValue
            }
        }
        return intervalValue(withValue: v).clip(min: minValue, max: maxValue)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    func delete(with event: KeyInputEvent) -> Bool {
        let value = defaultValue.clip(min: minValue, max: maxValue)
        guard value != self.value else {
            return false
        }
        set(value, oldValue: self.value)
        return true
    }
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [String(value.d)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let string = object as? String {
                if let value = Double(string)?.cf {
                    guard value != self.value else {
                        continue
                    }
                    set(value, oldValue: self.value)
                    return true
                }
            }
        }
        return false
    }
    
    private var oldValue = 0.0.cf, oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .edit
            oldValue = value
            oldPoint = p
            binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .begin))
            value = self.value(at: p)
            binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .sending))
        case .sending:
            value = self.value(at: p)
            binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .sending))
        case .end:
            value = self.value(at: p)
            if value != oldValue {
                registeringUndoManager?.registerUndo(withTarget: self) { [value, oldValue] in
                    $0.set(oldValue, oldValue: value)
                }
            }
            binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ value: CGFloat, oldValue: CGFloat) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldValue, oldValue: value) }
        binding?(Binding(slider: self, value: oldValue, oldValue: oldValue, type: .begin))
        self.value = value
        binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .end))
    }
}

final class NumberSlider: Layer, Respondable, Slidable {
    static let name = Localization(english: "Number Slider", japanese: "数値スライダー")
    static let feature = Localization(english: "Change value: Left and right drag",
                                      japanese: "値を変更: 左右ドラッグ")
    
    var value = 0.0.cf {
        didSet {
            updateWithValue()
        }
    }
    
    var unit = "" {
        didSet {
            updateWithValue()
        }
    }
    var numberOfDigits = 0 {
        didSet {
            updateWithValue()
        }
    }
    
    var defaultValue = 0.0.cf
    var minValue: CGFloat {
        didSet {
            updateWithValue()
        }
    }
    var maxValue: CGFloat {
        didSet {
            updateWithValue()
        }
    }
    
    var exp = 1.0.cf, isInverted = false, isVertical = false
    var valueInterval = 0.0.cf
    
    private var knobLineFrame = CGRect()
    private let labelPaddingX = Layout.basicPadding, knobY = 3.5.cf
    private var valueX = 2.0.cf
    
    private let knob = DiscreteKnob(CGSize(square: 6), lineWidth: 1)
    private let lineLayer: Layer = {
        let lineLayer = Layer()
        lineLayer.lineColor = .content
        return lineLayer
    } ()
    
    let label: Label
    
    init(frame: CGRect = CGRect(), value: CGFloat = 0, defaultValue: CGFloat = 0,
         min: CGFloat = 0, max: CGFloat = 1, isInverted: Bool = false,
         isVertical: Bool = false, exp: CGFloat = 1, valueInterval: CGFloat = 0,
         numberOfDigits: Int = 0, unit: String = "", font: Font = .default,
         description: Localization = Localization()) {
        
        self.unit = unit
        self.value = value.clip(min: min, max: max)
        self.defaultValue = defaultValue
        self.minValue = min
        self.maxValue = max
        self.isInverted = isInverted
        self.isVertical = isVertical
        self.exp = exp
        self.valueInterval = valueInterval
        self.numberOfDigits = numberOfDigits
        label = Label(font: font)
        label.frame.origin = CGPoint(x: labelPaddingX,
                                     y: round((frame.height - label.frame.height) / 2))
        
        super.init()
        instanceDescription = description
        isClipped = true
        replace(children: [label, lineLayer, knob])
        self.frame = frame
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        knobLineFrame = CGRect(x: 5, y: 3, width: bounds.width - 10, height: 1)
        lineLayer.frame = knobLineFrame
        label.frame.origin.y = round((bounds.height - label.frame.height) / 2)
        
        updateWithValue()
    }
    private func updateWithValue() {
        if value - floor(value) > 0 {
            label.localization = Localization(String(format: numberOfDigits == 0 ?
                "%g" : "%.\(numberOfDigits)f", value) + "\(unit)")
        } else {
            label.localization = Localization("\(Int(value))" + "\(unit)")
        }
        if value < defaultValue {
            let x = (knobLineFrame.width / 2) * (value - minValue) / (defaultValue - minValue)
                + knobLineFrame.minX
            knob.position = CGPoint(x: round(x), y: knobY)
        } else {
            let x = (knobLineFrame.width / 2) * (value - defaultValue) / (maxValue - defaultValue)
                + knobLineFrame.midX
            knob.position = CGPoint(x: round(x), y: knobY)
        }
    }
    
    private func value(withDelta delta: CGFloat) -> CGFloat {
        let d = (delta / valueX) * valueInterval
        if exp == 1 {
            return d.interval(scale: valueInterval)
        } else {
            return (d >= 0 ? pow(d, exp) : -pow(abs(d), exp)).interval(scale: valueInterval)
        }
    }
    private func value(at p: CGPoint, oldValue: CGFloat) -> CGFloat {
        let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
        let v = oldValue.interval(scale: valueInterval) + value(withDelta: isInverted ? -d : d)
        return v.clip(min: minValue, max: maxValue)
    }
    
    var isLocked = false {
        didSet {
            if isLocked != oldValue {
                opacity = isLocked ? 0.35 : 1
            }
        }
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let slider: NumberSlider, value: CGFloat, oldValue: CGFloat, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    func delete(with event: KeyInputEvent) -> Bool {
        let value = defaultValue.clip(min: minValue, max: maxValue)
        guard value != self.value else {
            return false
        }
        set(value, oldValue: self.value)
        return true
    }
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [String(value.d)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        guard !isLocked else {
            return false
        }
        for object in copiedObject.objects {
            if let string = object as? String {
                if let v = Double(string)?.cf {
                    let value = v.clip(min: minValue, max: maxValue)
                    guard value != self.value else {
                        continue
                    }
                    set(value, oldValue: self.value)
                    return true
                }
            }
        }
        return false
    }
    
    private var oldValue = 0.0.cf, oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        guard !isLocked else {
            return false
        }
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .edit
            oldValue = value
            oldPoint = p
            binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .begin))
            value = self.value(at: p, oldValue: oldValue)
            binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .sending))
        case .sending:
            value = self.value(at: p, oldValue: oldValue)
            binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .sending))
        case .end:
            value = self.value(at: p, oldValue: oldValue)
            if value != oldValue {
                registeringUndoManager?.registerUndo(withTarget: self) { [value, oldValue] in
                    $0.set(oldValue, oldValue: value)
                }
            }
            binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ value: CGFloat, oldValue: CGFloat) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldValue, oldValue: value) }
        binding?(Binding(slider: self, value: oldValue, oldValue: oldValue, type: .begin))
        self.value = value
        binding?(Binding(slider: self, value: value, oldValue: oldValue, type: .end))
    }
}
