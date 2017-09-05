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

import Cocoa

struct Defaults {
    static let backgroundColor = NSColor(white: 0.84, alpha: 1)
    static let subBackgroundColor = NSColor(white: 0.89, alpha: 1)
    static let subBackgroundColor2 = NSColor(white: 0.905, alpha: 1)
    static let subBackgroundColor3 = NSColor(white: 0.92, alpha: 1)
    static let subBackgroundColor4 = NSColor(white: 0.86, alpha: 1)
    static let translucentSubBackgroundColor = NSColor(white: 0.85, alpha: 0.8)
    static let subSecondBackgroundColor = NSColor(white: 0.87, alpha: 1)
    static let subEditColor = NSColor(white: 0.84, alpha: 1)
    static let subSecondEditColor = NSColor(white: 0.83, alpha: 1)
    static let contentColor = NSColor.white
    static let contentBorderColor = NSColor(white: 0.973, alpha: 1)
    static let contentEditColor = NSColor(white: 0.3, alpha: 1)
    static let indicationSelectionColor = NSColor(white: 0.88, alpha: 1)
    static let editColor = NSColor(white: 0.68, alpha: 1)
    static let editingColor = NSColor(white: 0.9, alpha: 1)
    static let indicationColor = NSColor(red: 0.1, green: 0.7, blue: 1, alpha: 0.3)
    static let selectionColor = NSColor(red: 0.1, green: 0.7, blue: 1, alpha: 1)
    static let menuColor = NSColor(white: 0.96, alpha: 1)
    static let noActionColor = NSColor.red
    static let tempNotActionColor = NSColor.orange
    static let translucentBackgroundColor = NSColor(white: 0, alpha: 0.1)
    static let font = NSFont.systemFont(ofSize: 11) as CTFont
    static let fontColor = NSColor.textColor
    static let smallFont = NSFont.systemFont(ofSize: 10) as CTFont
    static let smallFontColor = NSColor(white: 0.5, alpha: 1)
    static let leftRightCursor = NSCursor.slideCursor()
    static let upDownCursor = NSCursor.slideCursor(isVertical: true)
}

final class ImageView: View {
    init() {
        super.init()
        layer.minificationFilter = kCAFilterTrilinear
        layer.magnificationFilter = kCAFilterTrilinear
    }
    
    var image = NSImage() {
        didSet {
            layer.contents = image
        }
    }
    var url: URL? {
        didSet {
            if let url = url {
                image = NSImage(byReferencing: url)
            }
        }
    }
    override func delete() {
        removeFromParent()
    }
    enum DragType {
        case move, resizeMinXMinY, resizeMaxXMinY, resizeMinXMaxY, resizeMaxXMaxY
    }
    var dragType = DragType.move, downPosition = CGPoint(), oldFrame = CGRect(), resizeWidth = 10.0.cf, ratio = 1.0.cf
    override func drag(with event: DragEvent) {
        if let parent = parent {
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

protocol ButtonDelegate: class {
    func clickButton(_ button: Button)
}
final class Button: View {
    weak var sendDelegate: ButtonDelegate?
    
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    let drawLayer: DrawLayer, highlight = Highlight()
    
    init(frame: CGRect = CGRect(), title: String = "") {
        drawLayer = DrawLayer(fillColor: Defaults.subBackgroundColor.cgColor)
        textLine = TextLine(string: title, isHorizontalCenter: true)
        super.init(layer: drawLayer)
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        drawLayer.frame = frame
        highlight.layer.frame = bounds.inset(by: 0.5)
        drawLayer.addSublayer(highlight.layer)
    }
    
    override func cursor(with p: CGPoint) -> NSCursor {
        return NSCursor.pointingHand()
    }
    
    override func drag(with event: DragEvent) {
        switch event.sendType {
        case .begin:
            highlight.setIsHighlighted(true, animate: false)
        case .sending:
            highlight.setIsHighlighted(contains(point(from: event)), animate: false)
        case .end:
            if contains(point(from: event)) {
                clickButton()
            }
            if highlight.isHighlighted {
                highlight.setIsHighlighted(false, animate: true)
            }
        }
    }
    func clickButton() {
        sendDelegate?.clickButton(self)
    }
    override func copy() {
        screen?.copy(textLine.string, forType: NSStringPboardType, from: self)
    }
}
protocol PulldownButtonDelegate: class {
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: DragEvent.SendType)
}
final class PulldownButton:View {
    private let arrowLayer = CAShapeLayer()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    let drawLayer: DrawLayer, highlight = Highlight()
    
    init(frame: CGRect = CGRect(), isEnabledCation cm: Bool = false, names: [String]) {
        menuView = MenuView(names: names, width: frame.width - 1)
        drawLayer = DrawLayer(fillColor: Defaults.subBackgroundColor.cgColor)
        textLine = TextLine(string: names.first ?? "", paddingWidth: arowWidth, isVerticalCenter: true)
        super.init(layer: drawLayer)
        
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
        highlight.layer.frame = bounds.inset(by: 0.5)
        layer.addSublayer(highlight.layer)
        isSelected = true
        isEnabledCation = cm
        
        updateArrowPosition()
        arrowLayer.strokeColor = Defaults.editColor.cgColor
        arrowLayer.fillColor = nil
        arrowLayer.lineWidth = 2
        layer.addSublayer(arrowLayer)
    }
    
    override var frame: CGRect {
        didSet {
            updateArrowPosition()
        }
    }
    weak var delegate: PulldownButtonDelegate?
    
    var defaultValue = 0
    override func delete() {
        let oldIndex = selectionIndex
        delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .begin)
        selectionIndex = defaultValue
        delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
    }
    override func copy() {
        screen?.copy(String(selectionIndex), forType: NSStringPboardType, from: self)
    }
    override func paste() {
        let pasteboard = NSPasteboard.general()
        if let string = pasteboard.string(forType: NSPasteboardTypeString) {
            if let i = Int(string) {
                let oldIndex = selectionIndex
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .begin)
                selectionIndex = i
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
            }
        }
    }
    
    var menuView: MenuView
    private var timer = LockTimer(), isDrag = false, oldIndex = 0
    override func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            if timer.inUse {
                timer.stop()
                closeMenu(animate: false)
            }
            isDrag = false
            highlight.setIsHighlighted(true, animate: false)
            screen?.addViewInRootPanel(menuView, point: CGPoint(x: 0.5, y: -menuView.frame.height), from: self)
        case .sending:
            if !isDrag {
                oldIndex = selectionIndex
                delegate?.changeValue(self, index: selectionIndex, oldIndex: selectionIndex, type: .begin)
                isDrag = true
            }
            let i = indexWith(-p.y)
            selectionIndex = i ?? oldIndex
            menuView.editIndex = i
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
                menuView.editIndex = nil
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
                closeMenu(animate: false)
            }
        }
    }
    private func closeMenu(animate: Bool) {
        menuView.removeFromParent()
        highlight.setIsHighlighted(false, animate: animate)
    }
    func indexWith(_ y: CGFloat) -> Int? {
        let i = y/menuView.menuHeight
        return i >= 0 ? min(Int(i), menuView.names.count - 1) : nil
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
    private var drawArow = true, isSelected = false, arowRadius = 3.0.cf, oldFontColor: CGColor?
    var selectionIndex = 0 {
        didSet {
            if !isDrag {
                menuView.selectionIndex = selectionIndex
            }
            textLine.string = menuView.names[selectionIndex]
            if isEnabledCation && selectionIndex != oldValue {
                if selectionIndex == 0 {
                    if let oldFontColor = oldFontColor {
                        textLine.color = oldFontColor
                    }
                } else {
                    oldFontColor = textLine.color
                    textLine.color = NSColor.red.cgColor
                }
            }
        }
    }
}
final class MenuView: View {
    var width = 0.0.cf, menuHeight = 17.0.cf, knobWidth = 18.0.cf
    
    init() {
        super.init()
        updateNameViews()
        layer.shadowOpacity = 0.5
    }
    init(names: [String] = [], width: CGFloat) {
        self.names = names
        self.width = width
        super.init()
        updateNameViews()
        layer.shadowOpacity = 0.5
    }
    var selectionKnobLayer = CALayer.slideLayer(width: 8, height: 8, lineWidth: 1)
    
    var names = [String]() {
        didSet {
            updateNameViews()
        }
    }
    var nameViews = [StringView]()
    func updateNameViews() {
        let h = menuHeight*names.count.cf
        var y = h
        let nameViews: [StringView] = names.map {
            y -= menuHeight
            return StringView(frame: CGRect(x: 0, y: y, width: width, height: menuHeight), textLine: TextLine(string: $0, paddingWidth: knobWidth))
        }
        bounds = CGRect(x: 0, y: 0, width: width, height: h)
        self.nameViews = nameViews
        self.children = nameViews
        selectionKnobLayer.position = CGPoint(x: knobWidth/2, y: nameViews[selectionIndex].frame.midY)
        layer.addSublayer(selectionKnobLayer)
    }
    var selectionIndex = 0 {
        didSet {
            if selectionIndex != oldValue {
                CATransaction.disableAnimation {
                    selectionKnobLayer.position = CGPoint(x: knobWidth/2, y: nameViews[selectionIndex].frame.midY)
                }
            }
        }
    }
    var editIndex: Int? {
        didSet {
            if editIndex != oldValue {
                CATransaction.disableAnimation {
                    if let i = editIndex {
                        nameViews[i].drawLayer.fillColor = Defaults.subEditColor.cgColor
                    }
                    if let oi = oldValue {
                        nameViews[oi].drawLayer.fillColor = Defaults.subBackgroundColor.cgColor
                    }
                }
            }
        }
    }
}

protocol TempSliderDelegate: class {
    func changeValue(_ tempSlider: TempSlider, point: CGPoint, oldPoint: CGPoint, deltaPoint: CGPoint, type: DragEvent.SendType)
}
class TempSlider: View {
    weak var delegate: TempSliderDelegate?
    
    let knobLayer = CALayer.knobLayer(radius: 4, lineWidth: 1), editKnobLayer = CALayer.knobLayer(radius: 4, lineWidth: 1)
    var imageLayer: CALayer? {
        didSet {
            if let imageLayer = imageLayer {
                layer.sublayers = [imageLayer, knobLayer, editKnobLayer]
            }
        }
    }
    
    init(frame: CGRect = CGRect(), isRadial: Bool) {
        self.isRadial = isRadial
        super.init()
        layer.frame = frame
        knobLayer.opacity = 0.5
        layer.sublayers = [knobLayer, editKnobLayer]
        resetKnobLayerPosition()
    }
    
    override var layer: CALayer {
        didSet {
            layer.sublayers = [knobLayer, editKnobLayer]
            resetKnobLayerPosition()
        }
    }
    override var frame: CGRect {
        didSet {
            resetKnobLayerPosition()
        }
    }
    func resetKnobLayerPosition() {
        CATransaction.disableAnimation {
            knobLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            editKnobLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
    var isRadial = false, baseWidth = 40.0.cf, padding = 4.0.cf
    private var oldPoint = CGPoint()
    override func drag(with event: DragEvent) {
        let p = point(from: event)
        let dp: CGPoint
        switch event.sendType {
        case .begin:
            oldPoint = p
            dp = CGPoint()
            editKnobLayer.backgroundColor = Defaults.editingColor.cgColor
        case .sending:
            dp = p - oldPoint
            CATransaction.disableAnimation {
                if isRadial {
                    let d = (bounds.width/2 - padding)*(hypot(dp.x, dp.y)/baseWidth).clip(min: 0, max: 1), theta = atan2(dp.y, dp.x)
                    editKnobLayer.position = CGPoint(x: d*cos(theta) + bounds.midX, y: d*sin(theta) + bounds.midY)
                } else {
                    editKnobLayer.position = CGPoint(x: (bounds.width/2 - padding)*(dp.x/baseWidth).clip(min: -1, max: 1) + bounds.midX, y: bounds.midY) }
            }
        case .end:
            dp = p - oldPoint
            resetKnobLayerPosition()
            editKnobLayer.backgroundColor = Defaults.contentColor.cgColor
        }
        delegate?.changeValue(self, point: p, oldPoint: oldPoint, deltaPoint: dp, type: event.sendType)
    }
}

protocol SliderDelegate: class {
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: DragEvent.SendType)
}
final class Slider: View {
    weak var delegate: SliderDelegate?
    
    var value = 0.0.cf {
        didSet {
            if isNumberEdit {
                updateText()
            } else {
                updateKnobPosition()
            }
        }
    }
    var textLine: TextLine? {
        didSet {
            drawLayer?.setNeedsDisplay()
        }
    }
    var drawLayer: DrawLayer?
    let knobLayer = CALayer.knobLayer()
    
    init(frame: CGRect = CGRect(), unit: String = "", isNumberEdit: Bool = false, value: CGFloat = 0, defaultValue: CGFloat = 0,
         min: CGFloat = 0, max: CGFloat = 1, invert: Bool = false, isVertical: Bool = false, exp: CGFloat = 1, valueInterval: CGFloat = 0,
         numberOfDigits: Int = 0, numberFont: CTFont? = Defaults.smallFont) {
        self.isNumberEdit = isNumberEdit
        self.unit = unit
        self.value = value.clip(min: min, max: max)
        self.defaultValue = defaultValue
        self.minValue = min
        self.maxValue = max
        self.invert = invert
        self.isVertical = isVertical
        self.exp = exp
        self.valueInterval = valueInterval
        self.numberOfDigits = numberOfDigits
        super.init()
        
        layer.frame = frame
        if isNumberEdit {
            borderWidth = 0
            let drawLayer = DrawLayer(fillColor: Defaults.subBackgroundColor.cgColor)
            drawLayer.drawBlock = { [unowned self] ctx in
                ctx.setFillColor(Defaults.subBackgroundColor4.cgColor)
                ctx.fill(self.bounds.insetBy(dx: 0, dy: 4))
                self.textLine?.draw(in: self.bounds, in: ctx)
            }
            var textLine = TextLine(paddingWidth: 4)
            if let numberFont = numberFont {
                textLine.font = numberFont
            }
            self.drawLayer = drawLayer
            self.textLine = textLine
            drawLayer.frame = layer.bounds
            layer.addSublayer(drawLayer)
        }
        else {
            updateKnobPosition()
            layer.addSublayer(knobLayer)
        }
    }
    override func cursor(with p: CGPoint) -> NSCursor {
        return isNumberEdit ? Defaults.leftRightCursor : super.cursor(with: p)
    }
    override var contentsScale: CGFloat {
        didSet {
            if isNumberEdit {
                drawLayer?.contentsScale = contentsScale
            }
        }
    }
    var unit = "", numberOfDigits = 0
    var knobY = 0.0.cf, viewPadding = 10.0.cf, isNumberEdit = false
    var defaultValue = 0.0.cf, minValue: CGFloat, maxValue: CGFloat, valueInterval = 0.0.cf, exp = 1.0.cf, invert = false, isVertical = false, slideMinMax = false
    override var frame: CGRect {
        didSet {
            if isNumberEdit {
                updateText()
            } else {
                updateKnobPosition()
            }
        }
    }
    func updateKnobPosition() {
        if minValue < maxValue {
            CATransaction.disableAnimation {
                let t = (value - minValue)/(maxValue - minValue)
                if isVertical {
                    knobLayer.position = CGPoint(x: bounds.midX, y: viewPadding + (bounds.height - viewPadding*2)*pow(invert ? 1 - t : t, 1/exp))
                } else {
                    knobLayer.position = CGPoint(x: viewPadding + (bounds.width - viewPadding*2)*pow(invert ? 1 - t : t, 1/exp), y: knobY == 0 ? bounds.midY : knobY)
                }
            }
        }
    }
    func updateText() {
        CATransaction.disableAnimation {
            if value - floor(value) > 0 {
                textLine?.string = String(format: numberOfDigits == 0 ? "%g" : ".\(numberOfDigits)f", value) + "\(unit)"
            } else {
                textLine?.string = "\(Int(value))" + "\(unit)"
            }
        }
    }
    
    override func delete() {
        oldValue = value
        delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
        value = defaultValue.clip(min: minValue, max: maxValue)
        delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
    }
    override func copy() {
        screen?.copy(String(value.d), forType: NSStringPboardType, from: self)
    }
    override func paste() {
        let pasteboard = NSPasteboard.general()
        if let string = pasteboard.string(forType: NSPasteboardTypeString) {
            if let v = Double(string)?.cf {
                oldValue = value
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
                value = v.clip(min: minValue, max: maxValue)
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
            }
        }
    }
    
    private var oldValue = 0.0.cf, oldMinValue = 0.0.cf, oldMaxValue = 0.0.cf, oldPoint = CGPoint()
    override func drag(with event: DragEvent) {
        if isNumberEdit {
            numberEdit(with: event, valueInterval: valueInterval)
        } else {
            let p = point(from: event)
            switch event.sendType {
            case .begin:
                oldValue = value
                oldMinValue = minValue
                oldMaxValue = maxValue
                oldPoint = p
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
                updateValue(p)
                knobLayer.backgroundColor = Defaults.editingColor.cgColor
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .sending)
            case .sending:
                updateValue(p)
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .sending)
            case .end:
                updateValue(p)
                knobLayer.backgroundColor = Defaults.contentColor.cgColor
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
            }
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
                    v = (maxValue - minValue)*pow((invert ? (h - y) : y)/h, exp) + minValue
                } else {
                    v = minValue
                }
            } else {
                let w = bounds.width - viewPadding*2
                if w > 0 {
                    let x = (point.x - viewPadding).clip(min: 0, max: w)
                    v = (maxValue - minValue)*pow((invert ? (w - x) : x)/w, exp) + minValue
                } else {
                    v = minValue
                }
            }
            value = intervalValue(value: v).clip(min: minValue, max: maxValue)
        }
    }
    
    var valueX = 2.0.cf, valueLog = -2
    override func slowDrag(with event: DragEvent) {
        numberEdit(with: event, valueInterval: valueInterval)
    }
    func numberEdit(with event: DragEvent, valueInterval: CGFloat) {
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

final class ProgressBar: View {
    var barLayer = CALayer()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    
    init(frame: CGRect = CGRect()) {
        let layer = DrawLayer(fillColor: Defaults.subBackgroundColor2.cgColor)
        textLine = TextLine(isHorizontalCenter: true, isVerticalCenter: true)
        super.init(layer: layer)
        layer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
        barLayer.backgroundColor = Defaults.translucentBackgroundColor.cgColor
        layer.addSublayer(barLayer)
    }
    
    var value = 0.0.cf {
        didSet {
            barLayer.frame = CGRect(x: 0, y: 0, width: bounds.size.width*value, height: bounds.size.height)
            if let startDate = startDate {
                let time = abs(startDate.timeIntervalSinceNow)
                if time > computationTime && value > 0 {
                    remainingTime = time/TimeInterval(value) - time
                } else {
                    remainingTime = nil
                }
            } else {
                remainingTime = nil
            }
        }
    }
    func begin() {
        startDate = Date()
    }
    func end() {}
    var startDate: Date?
    var remainingTime: TimeInterval? {
        didSet {
            updateString()
        }
    }
    var computationTime = TimeInterval(5), name = ""
    weak var operation: Operation?
    override func delete() {
        operation?.cancel()
    }
    func updateString() {
        if let remainingTime = remainingTime {
            let minutes = Int(ceil(remainingTime))/60
            let seconds = Int(ceil(remainingTime)) - minutes*60
            if minutes == 0 {
                textLine.string = String(format: "%@sec left".localized, String(seconds))
            } else {
                textLine.string = String(format: "%@min %@sec left".localized, String(minutes), String(seconds))
            }
        } else {
            textLine.string = ""
        }
    }
}

final class CommandView: View {
    var textViews = [StringView]()
    var actionNodeWidth = 190.0.cf, commandPadding = 6.0.cf
    var commandFont = NSFont.systemFont(ofSize: 9), commandColor = Defaults.smallFontColor, backgroundColor = NSColor(white: 0.92, alpha: 1).cgColor
    var displayActionNode = ActionNode() {
        didSet {
            CATransaction.disableAnimation {
                var y = 0.0.cf, height = 0.0.cf
                for child in displayActionNode.children {
                    height += (commandFont.pointSize + commandPadding)*child.children.count.cf + commandPadding
                }
                y = height
                let children: [View] = displayActionNode.children.map {
                    let h = (commandFont.pointSize + commandPadding)*$0.children.count.cf + commandPadding
                    y -= h
                    let actionsView = View()
                    actionsView.frame = CGRect(x: 0, y: y, width: actionNodeWidth, height: h)
                    makeTextView(actionNode: $0, backgroundColor: backgroundColor, in: actionsView)
                    return actionsView
                }
                self.children = children
                frame.size = CGSize(width: actionNodeWidth, height: height)
            }
        }
    }
    private func makeTextView(actionNode: ActionNode, backgroundColor: CGColor, in actionView: View) {
        var y = actionView.frame.height - commandPadding/2
        actionView.layer.backgroundColor = backgroundColor
        let children: [View] = actionNode.children.flatMap {
            let h = commandFont.pointSize + commandPadding
            y -= h
            if let action = $0.action {
                let tv = StringView(frame: CGRect(x: 0, y: y, width: actionNodeWidth, height: h), textLine: TextLine(string: action.name, color: commandColor.cgColor, isVerticalCenter: true))
                tv.drawLayer.fillColor = backgroundColor
                let cv = StringView(textLine: TextLine(string: action.displayCommandString, font: NSFont.boldSystemFont(ofSize: 9), color: commandColor.cgColor, alignment: .right))
                cv.drawLayer.fillColor = backgroundColor
                let cw = ceil(cv.textLine.stringBounds.width) + tv.textLine.paddingSize.width*2
                cv.frame = CGRect(x: tv.bounds.width - cw, y: 0, width: cw, height: h)
                tv.addChild(cv)
                return tv
            } else {
                return nil
            }
        }
        actionView.children = children
    }
}

struct Highlight {
    init() {
        layer.backgroundColor = NSColor.black.cgColor
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
            layer.isHidden = !h
        }
    }
}

final class DrawLayer: CALayer {
    init(fillColor: CGColor) {
        self.fillColor = fillColor
        super.init()
        isOpaque = true
        needsDisplayOnBoundsChange = true
        drawsAsynchronously = true
        anchorPoint = CGPoint()
    }
    override init() {
        super.init()
        isOpaque = true
        needsDisplayOnBoundsChange = true
        drawsAsynchronously = true
        anchorPoint = CGPoint()
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
    override var contentsScale: CGFloat {
        didSet {
            setNeedsDisplay()
        }
    }
    var fillColor = NSColor.white.cgColor {
        didSet {
            setNeedsDisplay()
        }
    }
    var drawBlock: ((_ in: CGContext) -> Void)?
    override func draw(in ctx: CGContext) {
        ctx.setFillColor(fillColor)
        ctx.fill(ctx.boundingBoxOfClipPath)
        drawBlock?(ctx)
    }
}
extension CALayer {
    static func knobLayer(radius r: CGFloat = 5, lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Defaults.contentColor.cgColor
        layer.borderColor = Defaults.editColor.cgColor
        layer.borderWidth = l
        layer.cornerRadius = r
        layer.bounds = CGRect(x: 0, y: 0, width: r*2, height: r*2)
        layer.actions = ["backgroundColor": NSNull()]
        return layer
    }
    static func slideLayer(width w: CGFloat = 5, height h: CGFloat = 10, lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Defaults.contentColor.cgColor
        layer.borderColor = Defaults.editColor.cgColor
        layer.borderWidth = l
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        layer.actions = ["backgroundColor": NSNull()]
        return layer
    }
    static func selectionLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = NSColor(red: 0, green: 0.7, blue: 1, alpha: 0.3).cgColor
        layer.borderColor = NSColor(red: 0.1, green: 0.4, blue: 1, alpha: 0.5).cgColor
        layer.borderWidth = 1
        return layer
    }
    static func interfaceLayer() -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        layer.backgroundColor = Defaults.subBackgroundColor.cgColor
        return layer
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

extension NSCursor {
    static func circleCursor(size s: CGFloat, color: NSColor = NSColor.black, outlineColor: NSColor = NSColor.white) -> NSCursor {
        let lineWidth = 2.0.cf, subLineWidth = 1.0.cf
        let d = subLineWidth + lineWidth/2
        let b = CGRect(x: d, y: d, width: d*2 + s, height: d*2 + s)
        let image = NSImage(size: CGSize(width: s + d*2*2,  height: s + d*2*2)) { ctx in
            ctx.setLineWidth(lineWidth + subLineWidth*2)
            ctx.setFillColor(outlineColor.withAlphaComponent(0.35).cgColor)
            ctx.setStrokeColor(outlineColor.withAlphaComponent(0.8).cgColor)
            ctx.addEllipse(in: b)
            ctx.drawPath(using: .fillStroke)
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(color.cgColor)
            ctx.strokeEllipse(in: b)
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: d*2 + s/2, y: -d*2 - s/2))
    }
    static func slideCursor(color: NSColor = NSColor.black, outlineColor: NSColor = NSColor.white, isVertical: Bool = false) -> NSCursor {
        let lineWidth = 1.0.cf, lineHalfWidth = 4.0.cf, halfHeight = 4.0.cf, halfLineHeight = 1.5.cf
        let aw = floor(halfHeight*sqrt(3)), d = lineWidth/2
        let w = ceil(aw*2 + lineHalfWidth*2 + d), h =  ceil(halfHeight*2 + d)
        let image = NSImage(size: isVertical ? NSSize(width: h,  height: w) : NSSize(width: w,  height: h)) { ctx in
            if isVertical {
                ctx.translateBy(x: h/2, y: w/2)
                ctx.rotate(by: .pi/2)
                ctx.translateBy(x: -w/2, y: -h/2)
            }
            ctx.addLines(between: [
                CGPoint(x: d, y: d + halfHeight), CGPoint(x: d + aw, y: d + halfHeight*2),
                CGPoint(x: d + aw, y: d + halfHeight + halfLineHeight),
                CGPoint(x: d + aw + lineHalfWidth*2, y: d + halfHeight + halfLineHeight),
                CGPoint(x: d + aw + lineHalfWidth*2, y: d + halfHeight*2),
                CGPoint(x: d + aw*2 + lineHalfWidth*2, y: d + halfHeight),
                CGPoint(x: d + aw + lineHalfWidth*2, y: d),
                CGPoint(x: d + aw + lineHalfWidth*2, y: d + halfHeight - halfLineHeight),
                CGPoint(x: d + aw, y: d + halfHeight - halfLineHeight), CGPoint(x: d + aw, y: d)
                ])
            ctx.closePath()
            ctx.setLineJoin(.miter)
            ctx.setLineWidth(lineWidth)
            ctx.setFillColor(color.cgColor)
            ctx.setStrokeColor(outlineColor.cgColor)
            ctx.drawPath(using: .fillStroke)
        }
        return NSCursor(image: image, hotSpot: isVertical ? NSPoint(x: h/2, y: -w/2) : NSPoint(x: w/2, y: -h/2))
    }
}
