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

//# Issue
//ラジオボタンの導入

import Foundation
import QuartzCore

final class GlobalVariable {
    static let shared = GlobalVariable()
    var backingScaleFactor = 1.0.cf
    var locale = Locale.current
}

final class Drager {
    private var downPosition = CGPoint(), oldFrame = CGRect()
    func drag(with event: DragEvent, _ responder: LayerRespondable, in parent: LayerRespondable?) {
        if let parent = parent {
            let p = parent.point(from: event)
            switch event.sendType {
            case .begin:
                downPosition = p
                oldFrame = responder.frame
            case .sending:
                let dp =  p - downPosition
                CATransaction.disableAnimation {
                    responder.frame.origin = CGPoint(x: oldFrame.origin.x + dp.x, y: oldFrame.origin.y + dp.y)
                }
            case .end:
                let dp =  p - downPosition
                responder.frame.origin = CGPoint(x: round(oldFrame.origin.x + dp.x), y: round(oldFrame.origin.y + dp.y))
            }
        } else {
            parent?.drag(with: event)
        }
    }
}
final class Scroller {
    func scroll(with event: ScrollEvent, responder: LayerRespondable) {
        CATransaction.disableAnimation {
            responder.frame.origin += event.scrollDeltaPoint
        }
    }
}

final class GroupResponder: LayerRespondable {
    static let name = Localization(english: "Group", japanese: "グループ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    var layer: CALayer
    init(layer: CALayer = CALayer(), children: [Respondable] = [], frame: CGRect = CGRect()) {
        layer.frame = frame
        self.children = children
        self.layer = layer
        if !children.isEmpty {
            update(withChildren: children, oldChildren: [])
        }
    }
    let minPasteImageWidth = 400.0.cf
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        let p = self.point(from: event)
        for object in copyObject.objects {
            if let url = object as? URL {
                children.append(makeImageEditor(url: url, position: p))
            }
        }
    }
    func makeImageEditor(url :URL, position p: CGPoint) -> ImageEditor {
        let imageEditor = ImageEditor(url: url)
        if let size = imageEditor.image?.size {
            let maxWidth = max(size.width, size.height)
            let ratio = minPasteImageWidth < maxWidth ? minPasteImageWidth/maxWidth : 1
            let width = ceil(size.width*ratio), height = ceil(size.height*ratio)
            imageEditor.frame = CGRect(x: round(p.x - width/2), y: round(p.y - height/2), width: width, height: height)
        }
        return imageEditor
    }
}

final class UndoEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Undo Editor", japanese: "取り消しエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    private var token: NSObjectProtocol?
    var undoManager: UndoManager? {
        didSet {
            if let token = token {
                NotificationCenter.default.removeObserver(token)
            }
            token = NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSUndoManagerCheckpoint, object: undoManager, queue: nil,
                using: { [unowned self] _ in self.updateLabel()  }
            )
            updateLabel()
        }
    }
    var locale = Locale.current {
        didSet {
            updateLabel()
        }
    }
    
    let layer = CALayer.interfaceLayer()
    let label: Label
    init(backgroundColor: Color) {
        layer.backgroundColor = backgroundColor.cgColor
        label = Label(string: "", font: .small, color: .smallFont, backgroundColor: backgroundColor, isSizeToFit: false)
        label.textLine.isHorizontalCenter = false
        children = [label]
        update(withChildren: children, oldChildren: [])
    }
    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            label.frame = bounds.inset(by: Layout.basicPadding)
            updateLabel()
        }
    }
    func updateLabel() {
        if let undoManager = undoManager {
            CATransaction.disableAnimation {
                let canUndoString = undoManager.canUndo ?
                    Localization(english: "Can Undo", japanese: "取り消しあり") : Localization(english: "Cannot Undo", japanese: "取り消しなし")
                let canRedoString = undoManager.canRedo ?
                    Localization(english: "Can Redo", japanese: "やり直しあり") : Localization(english: "Cannot Redo", japanese: "やり直しなし")
                label.text = canUndoString + Localization(", ") + canRedoString
            }
        }
    }
}

protocol ButtonDelegate: class {
    func clickButton(_ button: Button)
}
final class Button: LayerRespondable, Equatable, Localizable {
    static let name = Localization(english: "Button", japanese: "ボタン")
    static let description = Localization(english: "Send Action", japanese: "アクションを送信")
    var description: Localization {
        return name
    }
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            textLine.string = name.string(with: locale)
        }
    }
    
    weak var sendDelegate: ButtonDelegate?
    
    var name = Localization()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer, highlight = Highlight()
    
    init(frame: CGRect = CGRect(), backgroundColor: Color, title: String = "", name: Localization = Localization()) {
        self.drawLayer = DrawLayer(backgroundColor: backgroundColor)
        self.name = name
        self.textLine = TextLine(string: name.currentString, isHorizontalCenter: true)
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
        highlight.layer.frame = bounds.inset(by: 0.5)
        layer.addSublayer(highlight.layer)
    }
    
    let cursor = Cursor.pointingHand
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            highlight.layer.frame = bounds.inset(by: 0.5)
        }
    }
    var editBounds: CGRect {
        return textLine.stringBounds
    }
    
    func click(with event: DragEvent) {
        highlight.setIsHighlighted(true, animate: false)
        if highlight.isHighlighted {
            sendDelegate?.clickButton(self)
            highlight.setIsHighlighted(false, animate: true)
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [textLine.string])
    }
}

protocol PulldownButtonDelegate: class {
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType)
}
final class PulldownButton: LayerRespondable, Equatable, Localizable {
    static let name = Localization(english: "Pulldown Button", japanese: "プルダウンボタン")
    static let description = Localization(english: "Select Index: Up and down drag", japanese: "インデックスを選択: 上下ドラッグ")
    var description: Localization
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            menu.locale = locale
            textLine.string = isSelectable ? menu.names[selectionIndex].string(with: locale) : name.string(with: locale)
        }
    }
    
    private let arrowLayer: CAShapeLayer = {
        let arrowLayer = CAShapeLayer()
        arrowLayer.strokeColor = Color.knobBorder.cgColor
        arrowLayer.fillColor = nil
        arrowLayer.lineWidth = 2
        return arrowLayer
    }()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer, highlight = Highlight()
    var isSelectable: Bool
    
    var name: Localization
    
    init(
        frame: CGRect = CGRect(), backgroundColor: Color = Color.background0,
        isEnabledCation: Bool = false, isSelectable: Bool = true,
        name: Localization = Localization(), names: [Localization] = [], description: Localization = Localization()
    ) {
        self.drawLayer = DrawLayer(backgroundColor: backgroundColor)
        self.description = description
        self.menu = Menu(names: names, width: isSelectable ? frame.width : nil, isSelectable: isSelectable)
        self.name = name
        self.isSelectable = isSelectable
        self.isEnabledCation = isEnabledCation
        self.textLine = TextLine(
            string: isSelectable ? (names.first?.currentString ?? "") : name.currentString,
            paddingWidth: arowWidth, isVerticalCenter: true
        )
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
        highlight.layer.frame = bounds.inset(by: 0.5)
        updateArrowPosition()
        layer.sublayers = [arrowLayer, highlight.layer]
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            if isSelectable && menu.width != newValue.width {
                menu.width = newValue.width
            }
            highlight.layer.frame = bounds.inset(by: 0.5)
            updateArrowPosition()
        }
    }
    var editBounds: CGRect {
        return textLine.stringBounds
    }
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            menu.contentsScale = newValue
        }
    }
    weak var delegate: PulldownButtonDelegate?
    
    var defaultValue = 0
    func delete(with event: KeyInputEvent) {
        let oldIndex = selectionIndex, newIndex = defaultValue
        if oldIndex != newIndex {
            delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .begin)
            selectionIndex = defaultValue
            delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
        }
    }
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [String(selectionIndex)])
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let string = object as? String {
                if let i = Int(string) {
                    let oldIndex = selectionIndex
                    delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .begin)
                    selectionIndex = i
                    delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
                    return
                }
            }
        }
    }
    
    var willOpenMenuHandler: ((PulldownButton) -> (Void))? = nil
    var menu: Menu
    private var timer = LockTimer(), isDrag = false, oldIndex = 0
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            if timer.inUse {
                timer.stop()
                closeMenu(animate: false)
            }
            isDrag = false
            highlight.setIsHighlighted(true, animate: false)
            if let root = rootRespondable as? LayerRespondable {
                willOpenMenuHandler?(self)
                CATransaction.disableAnimation {
                    menu.frame.origin = root.convert(CGPoint(x: 0, y: -menu.frame.height), from: self)
                    root.children.append(menu)
                }
            }
        case .sending:
            if !isDrag {
                oldIndex = selectionIndex
                delegate?.changeValue(self, index: selectionIndex, oldIndex: selectionIndex, type: .begin)
                isDrag = true
            }
            let i = indexWith(-p.y)
            selectionIndex = i ?? oldIndex
            menu.editIndex = i
            delegate?.changeValue(self, index: selectionIndex, oldIndex: selectionIndex, type: .sending)
        case .end:
            if !isDrag {
                timer.begin(0.2, repeats: false) { [unowned self] in
                    self.closeMenu(animate: true)
                }
            } else {
                isDrag = false
                let i = indexWith(-p.y)
                selectionIndex = i ?? oldIndex
                menu.editIndex = nil
                if i != nil || isSelectable {
                    delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
                }
                closeMenu(animate: false)
            }
        }
    }
    private func closeMenu(animate: Bool) {
        menu.removeFromParent()
        highlight.setIsHighlighted(false, animate: animate)
    }
    func indexWith(_ y: CGFloat) -> Int? {
        let i = y/menu.menuHeight
        return i >= 0 ? min(Int(i), menu.names.count - 1) : nil
    }
    var isEnabledCation = false
    func updateArrowPosition() {
        let d = arowRadius*2/sqrt(3) + 0.5
        let path = CGMutablePath()
        path.move(to: CGPoint(x: arowWidth/2 - d, y: bounds.midY + arowRadius*0.8))
        path.addLine(to: CGPoint(x: arowWidth/2, y: bounds.midY - arowRadius*0.8))
        path.addLine(to: CGPoint(x: arowWidth/2 + d, y: bounds.midY + arowRadius*0.8))
        arrowLayer.path = path
    }
    var arowWidth = 16.0.cf {
        didSet {
            updateArrowPosition()
        }
    }
    private var drawArow = true, arowRadius = 3.0.cf, oldFontColor: Color?
    var selectionIndex = 0 {
        didSet {
            if !isDrag {
                menu.selectionIndex = selectionIndex
            }
            if isSelectable {
                textLine.string = menu.names[selectionIndex].currentString
                if isEnabledCation && selectionIndex != oldValue {
                    if selectionIndex == 0 {
                        if let oldFontColor = oldFontColor {
                            textLine.color = oldFontColor
                        }
                    } else {
                        oldFontColor = textLine.color
                        textLine.color = Color.red
                    }
                }
            }
        }
    }
}

final class Menu: LayerRespondable, Localizable {
    static let name = Localization(english: "Menu", japanese: "メニュー")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            for label in nameLabels {
                label.locale = locale
                if isAutoWidth {
                    self.width = width(with: names)
                    updateNameLabels()
                }
            }
        }
    }
    
    var isAutoWidth: Bool
    var width = 0.0.cf {
        didSet {
            updateNameLabels()
        }
    }
    var menuHeight = 17.0.cf, knobWidth = 18.0.cf
    var isSelectable: Bool {
        didSet {
            selectionKnobLayer.isHidden = !isSelectable
        }
    }
    let layer = CALayer.interfaceLayer(borderColor: .panelBorder)
    init(names: [Localization] = [], width: CGFloat?, isSelectable: Bool = true) {
        self.isSelectable = isSelectable
        self.names = names
        self.isAutoWidth = width == nil
        self.width = width ?? self.width(with: names)
        selectionKnobLayer.isHidden = !isSelectable
        updateNameLabels()
    }
    var selectionKnobLayer = CALayer.slideLayer(width: 8, height: 8, lineWidth: 1)
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            for menuLabel in nameLabels {
                menuLabel.contentsScale = newValue
            }
        }
    }
    
    var names = [Localization]() {
        didSet {
            if isAutoWidth {
                self.width = width(with: names)
            }
            updateNameLabels()
        }
    }
    var nameLabels = [Label]()
    func width(with names: [Localization]) -> CGFloat {
        return names.reduce(0.0.cf) { max($0, TextLine(string: $1.currentString, paddingWidth: knobWidth).width) } + knobWidth*2
    }
    func updateNameLabels() {
        CATransaction.disableAnimation {
            if names.isEmpty {
                self.frame.size = CGSize(width: 10, height: 10)
                self.nameLabels = []
                self.children = []
            } else {
                let h = menuHeight*names.count.cf
                var y = h
                let nameLabels: [Label] = names.map {
                    y -= menuHeight
                    return Label(
                        frame: CGRect(x: 0, y: y, width: width, height: menuHeight),
                        text: $0,
                        textLine: TextLine(string: $0.currentString, paddingWidth: knobWidth)
                    )
                }
                frame.size = CGSize(width: width, height: h)
                self.nameLabels = nameLabels
                self.children = nameLabels
                selectionKnobLayer.position = CGPoint(x: knobWidth/2, y: nameLabels[selectionIndex].frame.midY)
                layer.addSublayer(selectionKnobLayer)
            }
        }
    }
    var selectionIndex = 0 {
        didSet {
            if selectionIndex != oldValue {
                CATransaction.disableAnimation {
                    selectionKnobLayer.position = CGPoint(x: knobWidth/2, y: nameLabels[selectionIndex].frame.midY)
                }
            }
        }
    }
    var editIndex: Int? {
        didSet {
            if editIndex != oldValue {
                CATransaction.disableAnimation {
                    if let i = editIndex {
                        nameLabels[i].drawLayer.backgroundColor = Color.editBackground.cgColor
                    }
                    if let oi = oldValue {
                        nameLabels[oi].drawLayer.backgroundColor = Color.background0.cgColor
                    }
                }
            }
        }
    }
}

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
    var description: Localization
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: SliderDelegate?
    
    var value = 0.0.cf {
        didSet {
            updateKnobPosition()
        }
    }
    
    let layer: CALayer, knobLayer = CALayer.knobLayer()
    
    init(
        frame: CGRect = CGRect(), backgroundColor: Color,
        value: CGFloat = 0, defaultValue: CGFloat = 0,
        min: CGFloat = 0, max: CGFloat = 1, isInvert: Bool = false, isVertical: Bool = false, exp: CGFloat = 1, valueInterval: CGFloat = 0,
        description: Localization = Localization()
    ) {
        self.layer = CALayer.interfaceLayer(backgroundColor: backgroundColor)
        self.value = value.clip(min: min, max: max)
        self.defaultValue = defaultValue
        self.minValue = min
        self.maxValue = max
        self.isInvert = isInvert
        self.isVertical = isVertical
        self.exp = exp
        self.valueInterval = valueInterval
        self.description = description
        
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
                let t = (value - minValue)/(maxValue - minValue)
                if isVertical {
                    knobLayer.position = CGPoint(
                        x: bounds.midX,
                        y: viewPadding + (bounds.height - viewPadding*2)*pow(isInvert ? 1 - t : t, 1/exp)
                    )
                } else {
                    knobLayer.position = CGPoint(
                        x: viewPadding + (bounds.width - viewPadding*2)*pow(isInvert ? 1 - t : t, 1/exp),
                        y: knobY == 0 ? bounds.midY : knobY
                    )
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
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [String(value.d)])
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
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
            knobLayer.backgroundColor = Color.knobEditing.cgColor
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
            let t = floor(v/valueInterval)*valueInterval
            if v - t > valueInterval/2 {
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
                let h = bounds.height - viewPadding*2
                if h > 0 {
                    let y = (point.y - viewPadding).clip(min: 0, max: h)
                    v = (maxValue - minValue)*pow((isInvert ? (h - y) : y)/h, exp) + minValue
                } else {
                    v = minValue
                }
            } else {
                let w = bounds.width - viewPadding*2
                if w > 0 {
                    let x = (point.x - viewPadding).clip(min: 0, max: w)
                    v = (maxValue - minValue)*pow((isInvert ? (w - x) : x)/w, exp) + minValue
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
    var description: Localization
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: NumberSliderDelegate?
    
    var value = 0.0.cf {
        didSet {
            updateText()
        }
    }
    var textLine: TextLine {
        didSet {
            drawLayer.setNeedsDisplay()
        }
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(backgroundColor: .background1)
    init(
        frame: CGRect = CGRect(), value: CGFloat = 0, defaultValue: CGFloat = 0,
        min: CGFloat = 0, max: CGFloat = 1, isInvert: Bool = false, isVertical: Bool = false, exp: CGFloat = 1, valueInterval: CGFloat = 0,
        numberOfDigits: Int = 0, unit: String = "", font: Font = .small, description: Localization = Localization()
        ) {
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
        self.description = description
        self.textLine = TextLine(font: font, paddingWidth: 4)
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
    }
    let cursor = Cursor.leftRight
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
        }
    }
    func updateText() {
        CATransaction.disableAnimation {
            if value - floor(value) > 0 {
                textLine.string = String(format: numberOfDigits == 0 ? "%g" : "%.\(numberOfDigits)f", value) + "\(unit)"
            } else {
                textLine.string = "\(Int(value))" + "\(unit)"
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
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [String(value.d)])
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
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
        return ((delta/valueX)*valueInterval).interval(scale: valueInterval)
    }
}

protocol ProgressBarDelegate: class {
    func delete(_ progressBar: ProgressBar)
}
final class ProgressBar: LayerRespondable, Localizable {
    static let name = Localization(english: "Progress Bar", japanese: "プログレスバー")
    static let description = Localization(english: "Stop: Send \"Cut\" action", japanese: "停止: \"カット\"アクションを送信")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            updateString(with: locale)
        }
    }
    
    weak var delegate: ProgressBarDelegate?
    
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer, barLayer = CALayer()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    
    init(frame: CGRect = CGRect(), backgroundColor: Color = Color.background1, state: Localization? = nil) {
        self.state = state
        self.drawLayer = DrawLayer(backgroundColor: backgroundColor)
        textLine = TextLine(font: .small, color: .smallFont, isVerticalCenter: true)
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
        barLayer.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        barLayer.backgroundColor = Color.translucentContent.cgColor
        layer.addSublayer(barLayer)
        updateString(with: locale)
    }
    
    var value = 0.0.cf {
        didSet {
            CATransaction.disableAnimation {
                barLayer.frame = CGRect(x: 0, y: 0, width: floor(bounds.width*value), height: bounds.height)
                updateString(with: locale)
            }
        }
    }
    func begin() {
        startDate = Date()
    }
    func end() {}
    var startDate: Date?
    var remainingTime: Double? {
        didSet {
            updateString(with: Locale.current)
        }
    }
    var computationTime = 5.0, name = ""
    var state: Localization? {
        didSet {
            updateString(with: locale)
        }
    }
    weak var operation: Operation?
    func delete(with event: KeyInputEvent) {
        if let operation = operation {
            operation.cancel()
        }
        delegate?.delete(self)
    }
    func updateString(with locale: Locale) {
        var string = ""
        if let state = state {
            string += state.string(with: locale)
        } else if let remainingTime = remainingTime {
            let minutes = Int(ceil(remainingTime))/60
            let seconds = Int(ceil(remainingTime)) - minutes*60
            if minutes == 0 {
                let translator = Localization(english: "%@sec left", japanese: "あと%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator, String(seconds))
            } else {
                let translator = Localization(english: "%@min %@sec left", japanese: "あと%@分%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator, String(minutes), String(seconds))
            }
        }
        textLine.string = string + (string.isEmpty ? "" : " ") + "\(Int(value * 100)) %"
    }
}

final class ImageEditor: LayerRespondable {
    static let name = Localization(english: "Image Editor", japanese: "画像エディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    var layer = CALayer()
    init(image: CGImage? = nil) {
        self.image = image
        layer.minificationFilter = kCAFilterTrilinear
        layer.magnificationFilter = kCAFilterTrilinear
    }
    init(url: URL?) {
        self.url = url
        layer.minificationFilter = kCAFilterTrilinear
        layer.magnificationFilter = kCAFilterTrilinear
    }
    
    var image: CGImage? {
        didSet {
            layer.contents = image
        }
    }
    var url: URL? {
        didSet {
            if let url = url {
                guard
                    let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                    let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                        return
                }
                self.image = image
            }
        }
    }
    func delete(with event: KeyInputEvent) {
        removeFromParent()
    }
    enum DragType {
        case move, resizeMinXMinY, resizeMaxXMinY, resizeMinXMaxY, resizeMaxXMaxY
    }
    var dragType = DragType.move, downPosition = CGPoint(), oldFrame = CGRect(), resizeWidth = 10.0.cf, ratio = 1.0.cf
    func drag(with event: DragEvent) {
        if let parent = parent as? LayerRespondable {
            let p = parent.point(from: event), ip = point(from: event)
            switch event.sendType {
            case .begin:
                if CGRect(x: 0, y: 0, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMinXMinY
                } else if CGRect(x:  bounds.width - resizeWidth, y: 0, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMaxXMinY
                } else if CGRect(x: 0, y: bounds.height - resizeWidth, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMinXMaxY
                } else if CGRect(x: bounds.width - resizeWidth, y: bounds.height - resizeWidth, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMaxXMaxY
                } else {
                    dragType = .move
                }
                downPosition = p
                oldFrame = frame
                ratio = frame.height/frame.width
            case .sending, .end:
                let dp =  p - downPosition
                var frame = self.frame
                switch dragType {
                case .move:
                    frame.origin = CGPoint(x: oldFrame.origin.x + dp.x, y: oldFrame.origin.y + dp.y)
                case .resizeMinXMinY:
                    frame.origin.x = oldFrame.origin.x + dp.x
                    frame.origin.y = oldFrame.origin.y + dp.y
                    frame.size.width = oldFrame.width - dp.x
                    frame.size.height = frame.size.width*ratio
                case .resizeMaxXMinY:
                    frame.origin.y = oldFrame.origin.y + dp.y
                    frame.size.width = oldFrame.width + dp.x
                    frame.size.height = frame.size.width*ratio
                case .resizeMinXMaxY:
                    frame.origin.x = oldFrame.origin.x + dp.x
                    frame.size.width = oldFrame.width - dp.x
                    frame.size.height = frame.size.width*ratio
                case .resizeMaxXMaxY:
                    frame.size.width = oldFrame.width + dp.x
                    frame.size.height = frame.size.width*ratio
                }
                CATransaction.disableAnimation {
                    self.frame = event.sendType == .end ? frame.integral : frame
                }
            }
        }
    }
}

struct Highlight {
    init() {
        layer.backgroundColor = Color.black.cgColor
        layer.opacity = 0.23
        layer.isHidden = true
    }
    let layer = CALayer()
    var isHighlighted: Bool {
        return !layer.isHidden
    }
    func setIsHighlighted(_ h: Bool, animate: Bool) {
        if !animate {
            CATransaction.disableAnimation {
                layer.isHidden = !h
            }
        } else {
            CATransaction.setCompletionBlock {
                self.layer.isHidden = !h
            }
        }
    }
}

final class DrawLayer: CALayer {
    init(backgroundColor: Color? = .white) {
        super.init()
        self.backgroundColor = backgroundColor?.cgColor
        self.contentsScale = GlobalVariable.shared.backingScaleFactor
        self.isOpaque = true
        self.needsDisplayOnBoundsChange = true
        self.drawsAsynchronously = true
        self.anchorPoint = CGPoint()
        self.borderWidth = 0.5
        self.borderColor = backgroundColor?.cgColor
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func action(forKey event: String) -> CAAction? {
        return event == "contents" ? nil : super.action(forKey: event)
    }
    override var backgroundColor: CGColor? {
        didSet {
            self.borderColor = backgroundColor
            setNeedsDisplay()
        }
    }
    override var contentsScale: CGFloat {
        didSet {
            setNeedsDisplay()
        }
    }
    var drawBlock: ((_ in: CGContext) -> Void)?
    override func draw(in ctx: CGContext) {
        if let backgroundColor = backgroundColor {
            ctx.setFillColor(backgroundColor)
            ctx.fill(ctx.boundingBoxOfClipPath)
        }
        drawBlock?(ctx)
    }
}

extension CALayer {
    static func knobLayer(radius r: CGFloat = 5, lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color.knob.cgColor
        layer.borderColor = Color.knobBorder.cgColor
        layer.borderWidth = l
        layer.cornerRadius = r
        layer.bounds = CGRect(x: 0, y: 0, width: r*2, height: r*2)
        layer.actions = ["backgroundColor": NSNull()]
        return layer
    }
    static func slideLayer(width w: CGFloat = 5, height h: CGFloat = 10, lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color.knob.cgColor
        layer.borderColor = Color.knobBorder.cgColor
        layer.borderWidth = l
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        layer.actions = ["backgroundColor": NSNull()]
        return layer
    }
    static func selectionLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color(red: 0, green: 0.7, blue: 1, alpha: 0.3).cgColor
        layer.borderColor = Color(red: 0.1, green: 0.4, blue: 1, alpha: 0.5).cgColor
        layer.borderWidth = 1
        return layer
    }
    static func interfaceLayer(backgroundColor: Color = .background1, borderColor: Color? = nil) -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        if let borderColor = borderColor {
            layer.borderWidth = 0.5
            layer.borderColor = borderColor.cgColor
        }
        layer.backgroundColor = backgroundColor.cgColor
        return layer
    }
    func allSublayers(_ handler: (CALayer) -> Void) {
        func allSublayersRecursion(_ layer: CALayer, _ handler: (CALayer) -> Void) {
            if let sublayers = layer.sublayers {
                for sublayer in sublayers {
                    allSublayersRecursion(sublayer, handler)
                }
            }
            handler(layer)
        }
        allSublayersRecursion(self, handler)
    }
}

extension CATransaction {
    static func disableAnimation(_ handler: (Void) -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        handler()
        CATransaction.commit()
    }
}


extension CGAffineTransform {
    static func centering(from fromFrame: CGRect, to toFrame: CGRect) -> (scale: CGFloat, affine: CGAffineTransform) {
        guard !fromFrame.isEmpty && !toFrame.isEmpty else {
            return (1, CGAffineTransform.identity)
        }
        var affine = CGAffineTransform.identity
        let fromRatio = fromFrame.width/fromFrame.height, toRatio = toFrame.width/toFrame.height
        if fromRatio > toRatio {
            let xScale = toFrame.width/fromFrame.size.width
            affine = affine.translatedBy(x: toFrame.origin.x, y: toFrame.origin.y + (toFrame.height - fromFrame.height*xScale)/2)
            affine = affine.scaledBy(x: xScale, y: xScale)
            return (xScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        } else {
            let yScale = toFrame.height/fromFrame.size.height
            affine = affine.translatedBy(x: toFrame.origin.x + (toFrame.width - fromFrame.width*yScale)/2, y: toFrame.origin.y)
            affine = affine.scaledBy(x: yScale, y: yScale)
            return (yScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        }
    }
    func flippedHorizontal(by width: CGFloat) -> CGAffineTransform {
        return translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
    }
}

extension CGImage {
    var size: CGSize {
        return CGSize(width: width, height: height)
    }
}

extension CGPath {
    static func checkerboard(with size: CGSize, in frame: CGRect) -> CGPath {
        let path = CGMutablePath()
        let xCount = Int(frame.width/size.width) , yCount = Int(frame.height/(size.height*2))
        for xi in 0 ..< xCount {
            let x = frame.maxX - (xi + 1).cf*size.width
            let fy = xi % 2 == 0 ? size.height : 0
            for yi in 0 ..< yCount {
                let y = frame.minY + yi.cf*size.height*2 + fy
                path.addRect(CGRect(x: x, y: y, width: size.width, height: size.height))
            }
        }
        return path
    }
}

extension CGContext {
    static func bitmap(with size: CGSize, colorSpace: CGColorSpace? = CGColorSpace(name: CGColorSpace.sRGB)) -> CGContext? {
        guard let colorSpace = colorSpace else {
            return nil
        }
        return CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    }
    func addBezier(_ b: Bezier3) {
        move(to: b.p0)
        addCurve(to: b.p1, control1: b.cp0, control2: b.cp1)
    }
    func flipHorizontal(by width: CGFloat) {
        translateBy(x: width, y: 0)
        scaleBy(x: -1, y: 1)
    }
    func drawBlurWith(
        color fillColor: Color, width: CGFloat, strength: CGFloat, isLuster: Bool, path: CGPath,
        scale: CGFloat, rotation: CGFloat
    ) {
        let nFillColor: Color
        if fillColor.alpha < 1 {
            saveGState()
            setAlpha(CGFloat(fillColor.alpha))
            nFillColor = fillColor.with(alpha: 1)
        } else {
            nFillColor = fillColor
        }
        let pathBounds = path.boundingBoxOfPath.insetBy(dx: -width, dy: -width)
        let lineColor = strength == 1 ? nFillColor : nFillColor.multiply(alpha: Double(strength))
        beginTransparencyLayer(in: boundingBoxOfClipPath.intersection(pathBounds), auxiliaryInfo: nil)
        if isLuster {
            setShadow(offset: CGSize(), blur: width*scale, color: lineColor.cgColor)
        } else {
            let shadowY = hypot(pathBounds.size.width, pathBounds.size.height)
            translateBy(x: 0, y: shadowY)
            let shadowOffset = CGSize(width: shadowY*scale*sin(rotation), height: -shadowY*scale*cos(rotation))
            setShadow(offset: shadowOffset, blur: width*scale/2, color: lineColor.cgColor)
            setLineWidth(width)
            setLineJoin(.round)
            setStrokeColor(lineColor.cgColor)
            addPath(path)
            strokePath()
            translateBy(x: 0, y: -shadowY)
        }
        setFillColor(nFillColor.cgColor)
        addPath(path)
        fillPath()
        endTransparencyLayer()
        if fillColor.alpha < 1 {
            restoreGState()
        }
    }
}
