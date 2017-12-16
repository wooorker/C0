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

final class GlobalVariable {
    static let shared = GlobalVariable()
    var backingScaleFactor = 1.0.cf
    var locale = Locale.current
}

final class Drager {
    private var downPosition = CGPoint(), oldFrame = CGRect()
    func drag(with event: DragEvent, _ responder: Respondable, in parent: Respondable?) {
        if let parent = parent {
            let p = parent.point(from: event)
            switch event.sendType {
            case .begin:
                downPosition = p
                oldFrame = responder.frame
            case .sending:
                let dp =  p - downPosition
                CATransaction.disableAnimation {
                    responder.frame.origin = CGPoint(x: oldFrame.origin.x + dp.x,
                                                     y: oldFrame.origin.y + dp.y)
                }
            case .end:
                let dp =  p - downPosition
                responder.frame.origin = CGPoint(x: round(oldFrame.origin.x + dp.x),
                                                 y: round(oldFrame.origin.y + dp.y))
            }
        } else {
            parent?.drag(with: event)
        }
    }
}
final class Scroller {
    func scroll(with event: ScrollEvent, responder: Respondable) {
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
    
    var layer: CALayer
    init(layer: CALayer = CALayer.interfaceLayer(),
         children: [Respondable] = [], frame: CGRect = CGRect()) {
        
        layer.frame = frame
        self.children = children
        layer.masksToBounds = true
        self.layer = layer
        if !children.isEmpty {
            update(withChildren: children, oldChildren: [])
        }
    }
    var canPasteImage = false
    let minPasteImageWidth = 400.0.cf
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        if canPasteImage {
            let p = self.point(from: event)
            for object in copiedObject.objects {
                if let url = object as? URL {
                    children.append(makeImageEditor(url: url, position: p))
                }
            }
        }
    }
    func makeImageEditor(url :URL, position p: CGPoint) -> ImageEditor {
        let imageEditor = ImageEditor(url: url)
        if let size = imageEditor.image?.size {
            let maxWidth = max(size.width, size.height)
            let ratio = minPasteImageWidth < maxWidth ? minPasteImageWidth / maxWidth : 1
            let width = ceil(size.width * ratio), height = ceil(size.height * ratio)
            imageEditor.frame = CGRect(x: round(p.x - width / 2),
                                       y: round(p.y - height / 2),
                                       width: width,
                                       height: height)
        }
        return imageEditor
    }
}

final class VersionEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Version Editor", japanese: "バージョンエディタ")
    static let feature = Localization(english: """
Show undoable count and undoed count in parent group.

*In the future software version, it will be possible to register and delete the version.
""",
                                      japanese: """
親グループでの取り消し可能回数、取り消し済み回数を表示。

*将来のソフトウェアバージョンで、バージョンの登録、削除が可能になる予定。
""")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    private var undoGroupToken: NSObjectProtocol?
    private var undoToken: NSObjectProtocol?, redoToken: NSObjectProtocol?
    var undoManager: UndoManager? {
        didSet {
            removeNotification()
            let nc = NotificationCenter.default
            
            undoGroupToken = nc.addObserver(forName: .NSUndoManagerDidCloseUndoGroup,
                                            object: undoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.undoManager {
                    
                    if undoManager.groupingLevel == 0 {
                        self.undoCount += 1
                        self.allCount = self.undoCount
                        self.updateLabel()
                    }
                }
            }
            
            undoToken = nc.addObserver(forName: .NSUndoManagerDidUndoChange,
                                       object: undoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.undoManager {
                    
                    self.undoCount -= 1
                    self.updateLabel()
                }
            }
            
            redoToken = nc.addObserver(forName: .NSUndoManagerDidRedoChange,
                                       object: undoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.undoManager {
                    
                    self.undoCount += 1
                    self.updateLabel()
                }
            }
            
            updateLabel()
        }
    }
    var locale = Locale.current {
        didSet {
            updateLabel()
        }
    }
    
    var undoCount = 0, allCount = 0
    
    let layer = CALayer.interfaceLayer()
    let label: Label
    init() {
        layer.masksToBounds = true
        label = Label()
        children = [label]
        update(withChildren: children, oldChildren: [])
    }
    deinit {
        removeNotification()
    }
    func removeNotification() {
        if let token = undoGroupToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = undoToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = redoToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateLabel()
        }
    }
    func updateLabel() {
        CATransaction.disableAnimation {
            if undoCount < allCount {
                label.text.localization = Localization(english: "Version(", japanese: "バージョン(")
                    + Localization("\(allCount), \(undoCount))")
                label.text.textFrame.color = .red
            } else {
                label.text.localization = Localization(english: "Version(", japanese: "バージョン(")
                    + Localization("\(allCount))")
                label.text.textFrame.color = .locked
            }
            label.frame.origin = CGPoint(x: Layout.basicPadding,
                                         y: (frame.height - label.frame.height) / 2)
        }
    }
}

final class Button: LayerRespondable, Equatable {
    static let name = Localization(english: "Button", japanese: "ボタン")
    static let feature = Localization(english: "Run text in the button: Click",
                                      japanese: "ボタン内のテキストを実行: クリック")
    var valueDescription: Localization {
        return label.text.localization
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    let label: Label
    
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(), highlight = Highlight()
    
    init(frame: CGRect = CGRect(), name: Localization = Localization(),
         isLeftAlignment: Bool = false, leftPadding: CGFloat = Layout.basicPadding,
         clickHandler: ((Button) -> (Void))? = nil) {
        
        self.clickHandler = clickHandler
        self.label = Label(text: name, color: .locked)
        self.isLeftAlignment = isLeftAlignment
        self.leftPadding = leftPadding
        label.frame.origin = CGPoint(
            x: isLeftAlignment ? leftPadding : round((frame.width - label.frame.width) / 2),
            y: round((frame.height - label.frame.height) / 2)
        )
        layer.frame = frame
        children = [label]
        update(withChildren: children, oldChildren: [])
        
        highlight.layer.frame = bounds.inset(by: 0.5)
        layer.addSublayer(highlight.layer)
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateChildren()
        }
    }
    var editBounds: CGRect {
        let fitSize = label.text.fitSize
        return CGRect(x: 0,
                      y: 0,
                      width: fitSize.width + leftPadding + Layout.basicPadding,
                      height: fitSize.height + Layout.basicPadding * 2)
    }
    
    var isLeftAlignment: Bool
    var leftPadding: CGFloat {
        didSet {
            updateChildren()
        }
    }
    func updateChildren() {
        label.frame.origin = CGPoint(
            x: isLeftAlignment ? leftPadding : round((frame.width - label.frame.width) / 2),
            y: round((frame.height - label.frame.height) / 2)
        )
        highlight.layer.frame = bounds.inset(by: 0.5)
    }
    
    var clickHandler: ((Button) -> (Void))?
    func click(with event: DragEvent) {
        highlight.setIsHighlighted(true, animate: false)
        if highlight.isHighlighted {
            clickHandler?(self)
            highlight.setIsHighlighted(false, animate: true)
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [label.text.string])
    }
}

final class Panel: LayerRespondable {
    static let name = Localization(english: "Panel", japanese: "パネル")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var undoManager: UndoManager?
    
    let openPointRadius = 2.0.cf
    var openPoint = CGPoint() {
        didSet {
            CATransaction.disableAnimation {
                let padding = isUseHedding ? heddingHeight / 2 : 0
                frame.origin = CGPoint(x: openPoint.x - padding,
                                       y: openPoint.y + padding - frame.height)
                
            }
        }
    }
    var openViewPoint = CGPoint()
    var contents: [Respondable] {
        didSet {
            CATransaction.disableAnimation {
                frame.size = Panel.contentsSizeAndVerticalAlignment(contents: contents,
                                                                    isUseHedding: isUseHedding,
                                                                    heddingHeight: heddingHeight)
                children = contents
                let r = openPointRadius, padding = heddingHeight / 2
                openPointLayer?.frame = CGRect(x: padding - r, y: bounds.maxY - padding - r,
                                               width: r * 2, height: r * 2)
            }
        }
    }
    private static func contentsSizeAndVerticalAlignment(contents: [Respondable],
                                                         isUseHedding: Bool,
                                                         heddingHeight: CGFloat) -> CGSize {
        let padding = Layout.basicPadding
        let size = contents.reduce(CGSize()) {
            return CGSize(width: max($0.width, $1.frame.size.width),
                          height: $0.height + $1.frame.height)
        }
        let ps = CGSize(width: size.width + padding * 2,
                        height: size.height + heddingHeight + padding)
        let h = isUseHedding ? heddingHeight : 0
        _ = contents.reduce(ps.height - h) {
            $1.frame.origin = CGPoint(x: padding, y: $0 - $1.frame.height)
            return $0 - $1.frame.height
        }
        return ps
    }
    
    var isSubIndication = false {
        didSet {
            if !isSubIndication {
                removeFromParent()
            }
        }
    }
    
    weak var indicationParent: Respondable? {
        didSet {
            undoManager = indicationParent?.undoManager
//            let root = rootRespondable
//            if !root.children.contains(where: { $0 === self }) {
//                root.children.append(self)
//            }
        }
    }
    
    let heddingHeight = 14.0.cf
    let isUseHedding: Bool
    private let openPointLayer: CALayer?
    let layer = CALayer.interfaceLayer()
    init(contents: [Respondable] = [], isUseHedding: Bool) {
        self.isUseHedding = isUseHedding
        
        let size = Panel.contentsSizeAndVerticalAlignment(contents: contents,
                                                          isUseHedding: isUseHedding,
                                                          heddingHeight: heddingHeight)
        
        if isUseHedding {
            let openPointLayer = CALayer(), r = openPointRadius, padding = heddingHeight / 2
            openPointLayer.isOpaque = true
            openPointLayer.backgroundColor = Color.content.cgColor
            openPointLayer.cornerRadius = r
            openPointLayer.frame = CGRect(
                x: padding - r, y: size.height - padding - r,
                width: r * 2, height: r * 2
            )
            self.openPointLayer = openPointLayer
            layer.backgroundColor = Color.background.multiply(alpha: 0.6).cgColor
            
            let origin = CGPoint(x: openPoint.x - padding, y: openPoint.y + padding - size.height)
            layer.frame = CGRect(origin: origin, size: size)
        } else {
            openPointLayer = nil
            layer.backgroundColor = Color.background.cgColor
            layer.frame = CGRect(origin: CGPoint(), size: size)
        }
        self.contents = contents
        children = contents
        if !children.isEmpty {
            update(withChildren: children, oldChildren: [])
        }
        
        if let openPointLayer = openPointLayer {
            layer.addSublayer(openPointLayer)
        }
    }
}
final class PopupBox: LayerRespondable {
    static let name = Localization(english: "Popup Button", japanese: "ポップアップボタン")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var isSubIndicationHandler: ((Bool) -> (Void))?
    var isSubIndication = false {
        didSet {
            CATransaction.disableAnimation {
                isSubIndicationHandler?(isSubIndication)
                if isSubIndication {
                    let root = rootRespondable
                    if root !== self {
                        panel.frame.origin = root.convert(CGPoint(x: 0, y: -panel.frame.height),
                                                          from: self)
                        if panel.parent == nil {
                            root.children.append(panel)
                        }
                    }
                } else {
                    panel.removeFromParent()
                }
            }
        }
    }
    
    private let arrowLayer: CAShapeLayer = {
        let arrowLayer = CAShapeLayer()
        arrowLayer.strokeColor = Color.border.cgColor
        arrowLayer.fillColor = nil
        arrowLayer.lineWidth = 2
        return arrowLayer
    }()
    
    let label: Label
    let layer = CALayer.interfaceLayer()
    init(frame: CGRect, text: Localization, panel: Panel = Panel(isUseHedding: false)) {
        self.label = Label(text: text, color: .locked)
        label.frame.origin = CGPoint(x: round((frame.width - label.frame.width) / 2),
                                     y: round((frame.height - label.frame.height) / 2))
        self.panel = panel
        layer.frame = frame
        children = [label]
        update(withChildren: children, oldChildren: [])
        updateArrowPosition()
        layer.addSublayer(arrowLayer)
        panel.indicationParent = self
    }
    var panel: Panel
    
    var arrowWidth = 16.0.cf {
        didSet {
            updateArrowPosition()
        }
    }
    var arrowRadius = 3.0.cf
    func updateArrowPosition() {
        let d = (arrowRadius * 2) / sqrt(3) + 0.5
        let path = CGMutablePath()
        path.move(to: CGPoint(x: arrowWidth / 2 - d, y: bounds.midY + arrowRadius * 0.8))
        path.addLine(to: CGPoint(x: arrowWidth / 2, y: bounds.midY - arrowRadius * 0.8))
        path.addLine(to: CGPoint(x: arrowWidth / 2 + d, y: bounds.midY + arrowRadius * 0.8))
        arrowLayer.path = path
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            label.frame.origin = CGPoint(
                x: arrowWidth,
                y: round((newValue.height - label.frame.height) / 2)
            )
            updateArrowPosition()
        }
    }
    var editBounds: CGRect {
        return label.text.textFrame.typographicBounds
    }
}

protocol PulldownButtonDelegate: class {
    func changeValue(_ pulldownButton: PulldownButton,
                     index: Int, oldIndex: Int, type: Action.SendType)
}
final class PulldownButton: LayerRespondable, Equatable, Localizable {
    static let name = Localization(english: "Pulldown Button", japanese: "プルダウンボタン")
    static let feature = Localization(english: "Select Index: Up and down drag",
                                      japanese: "インデックスを選択: 上下ドラッグ")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            menu.allChildren { ($0 as? Localizable)?.locale = locale }
        }
    }
    
    let label: Label
    let knobLayer = CALayer.slideLayer(width: 8, height: 8, lineWidth: 1)
    private let lineLayer: CAShapeLayer = {
        let lineLayer = CAShapeLayer()
        lineLayer.fillColor = Color.content.cgColor
        return lineLayer
    }()
    let layer = CALayer.interfaceLayer()
    init(frame: CGRect = CGRect(), names: [Localization] = [],
         selectionIndex: Int = 0, isEnabledCation: Bool = false,
         description: Localization = Localization()) {
        
        self.instanceDescription = description
        self.menu = Menu(names: names, knobPaddingWidth: knobPaddingWidth, width: frame.width)
        self.isEnabledCation = isEnabledCation
        self.label = Label(text: names[selectionIndex], color: .locked)
        
        children = [label]
        update(withChildren: children, oldChildren: [])
        
        label.frame.origin = CGPoint(x: knobPaddingWidth,
                                     y: round((frame.height - label.frame.height) / 2))
        layer.frame = frame
        updateKnobPosition()
        layer.addSublayer(lineLayer)
        layer.addSublayer(knobLayer)
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            label.frame.origin.y = round((newValue.height - label.frame.height) / 2)
            layer.frame = newValue
            if menu.width != newValue.width {
                menu.width = newValue.width
            }
            updateKnobPosition()
        }
    }
    var editBounds: CGRect {
        return label.text.textFrame.typographicBounds
    }
    func updateKnobPosition() {
        lineLayer.path = CGPath(rect: CGRect(x: knobPaddingWidth / 2 - 1, y: 0,
                                             width: 2, height: bounds.height / 2), transform: nil)
        knobLayer.position = CGPoint(x: knobPaddingWidth / 2, y: bounds.midY)
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
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [String(selectionIndex)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let string = object as? String, let i = Int(string) {
                let oldIndex = selectionIndex
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .begin)
                selectionIndex = i
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
                return
            }
        }
    }
    
    var willOpenMenuHandler: ((PulldownButton) -> (Void))? = nil
    var menu: Menu
    private var isDrag = false, oldIndex = 0, beginPoint = CGPoint()
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            isDrag = false
            beginPoint = p
            let root = rootRespondable
            if root !== self {
                willOpenMenuHandler?(self)
                CATransaction.disableAnimation {
                    label.layer.isHidden = true
                    lineLayer.isHidden = true
                    knobLayer.isHidden = true
                    menu.frame.origin = root.convert(CGPoint(x: 0, y: -menu.frame.height + p.y),
                                                     from: self)
                    root.children.append(menu)
                }
            }
            delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .begin)
            
            oldIndex = selectionIndex
            
            let i = indexWith(-(p.y - beginPoint.y))
            let si = i
            if si != selectionIndex {
                selectionIndex = si
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .sending)
            }
            
        case .sending:
            isDrag = true
            let i = indexWith(-(p.y - beginPoint.y))
            let si = i
            if si != selectionIndex {
                selectionIndex = si
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .sending)
            }
        case .end:
            if isDrag {
                isDrag = false
                let i = indexWith(-(p.y - beginPoint.y))
                selectionIndex = i
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
            } else if selectionIndex != oldIndex {
                selectionIndex = oldIndex
                delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
            }
            CATransaction.disableAnimation {
                label.layer.isHidden = false
                lineLayer.isHidden = false
                knobLayer.isHidden = false
            }
            closeMenu(animate: false)
        }
    }
    private func closeMenu(animate: Bool) {
        menu.removeFromParent()
    }
    func indexWith(_ y: CGFloat) -> Int {
        return Int(y / menu.menuHeight).clip(min: 0, max: menu.names.count - 1)
    }
    var isEnabledCation = false
    
    var knobPaddingWidth = 16.0.cf
    private var oldFontColor: Color?
    var selectionIndex = 0 {
        didSet {
            guard selectionIndex != oldValue else {
                return
            }
            menu.selectionIndex = selectionIndex
            label.text.localization = menu.names[selectionIndex]
            if isEnabledCation && selectionIndex != oldValue {
                if selectionIndex == 0 {
                    if let oldFontColor = oldFontColor {
                        label.text.textFrame.color = oldFontColor
                    }
                } else {
                    oldFontColor = label.text.textFrame.color
                    label.text.textFrame.color = Color.red
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
    
    var locale = Locale.current {
        didSet {
            items.forEach { $0.label.text.locale = locale }
        }
    }
    
    var width = 0.0.cf {
        didSet {
            updateItems()
        }
    }
    var menuHeight = Layout.basicHeight
    let knobPaddingWidth: CGFloat
    let layer = CALayer.interfaceLayer()
    init(names: [Localization] = [], knobPaddingWidth: CGFloat = 18.0.cf, width: CGFloat) {
        self.names = names
        self.knobPaddingWidth = knobPaddingWidth
        self.width = width
        updateItems()
    }
    let selectionLayer: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = Color.translucentEdit.cgColor
        return layer
    } ()
    private let lineLayer: CAShapeLayer = {
        let lineLayer = CAShapeLayer()
        lineLayer.fillColor = Color.content.cgColor
        return lineLayer
    }()
    var selectionKnobLayer = CALayer.slideLayer(width: 8, height: 8, lineWidth: 1)
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            items.forEach { $0.allChildren { $0.contentsScale = newValue } }
        }
    }
    
    var names = [Localization]() {
        didSet {
            updateItems()
        }
    }
    private(set) var items = [Button]()
    func updateItems() {
        CATransaction.disableAnimation {
            if names.isEmpty {
                self.frame.size = CGSize(width: 10, height: 10)
                self.items = []
                self.children = []
            } else {
                let h = menuHeight * names.count.cf
                var y = h
                let items: [Button] = names.map {
                    y -= menuHeight
                    return Button(frame: CGRect(x: 0, y: y, width: width, height: menuHeight),
                                  name: $0,
                                  isLeftAlignment: true,
                                  leftPadding: knobPaddingWidth)
                }
                frame.size = CGSize(width: width, height: h)
                self.items = items
                self.children = items
                selectionKnobLayer.position = CGPoint(x: knobPaddingWidth / 2,
                                                      y: items[selectionIndex].frame.midY)
                let path = CGMutablePath()
                path.addRect(CGRect(x: knobPaddingWidth / 2 - 1,
                                    y: menuHeight / 2,
                                    width: 2,
                                    height: bounds.height - menuHeight))
                items.forEach {
                    path.addRect(CGRect(x: knobPaddingWidth / 2 - 2,
                                        y: $0.frame.midY - 2,
                                        width: 4,
                                        height: 4))
                }
                lineLayer.path = path
                let selectionLabel = items[selectionIndex]
                selectionLayer.frame = selectionLabel.frame
                selectionKnobLayer.position = CGPoint(x: knobPaddingWidth / 2,
                                                      y: selectionLabel.frame.midY)
                
                layer.addSublayer(lineLayer)
                layer.addSublayer(selectionKnobLayer)
                layer.addSublayer(selectionLayer)
            }
        }
    }
    var selectionIndex = 0 {
        didSet {
            guard selectionIndex != oldValue else {
                return
            }
            CATransaction.disableAnimation {
                let selectionLabel = items[selectionIndex]
                selectionLayer.frame = selectionLabel.frame
                selectionKnobLayer.position = CGPoint(x: knobPaddingWidth / 2,
                                                      y: selectionLabel.frame.midY)
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

protocol ProgressDelegate: class {
    func delete(_ progressBar: Progress)
}
final class Progress: LayerRespondable, Localizable {
    static let name = Localization(english: "Progress", japanese: "進捗")
    static let feature = Localization(english: "Stop: Send \"Cut\" action",
                                      japanese: "停止: \"カット\"アクションを送信")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            updateString(with: locale)
        }
    }
    
    weak var delegate: ProgressDelegate?
    
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer, barLayer = CALayer(), barBackgroundLayer = CALayer()
    
    let label: Label
    
    init(frame: CGRect = CGRect(), backgroundColor: Color = Color.background,
         name: String = "", type: String = "", state: Localization? = nil) {
        
        self.name = name
        self.type = type
        self.state = state
        self.drawLayer = DrawLayer(backgroundColor: backgroundColor)
        label = Label()
        label.frame.origin = CGPoint(x: Layout.basicPadding,
                                     y: round((frame.height - label.frame.height) / 2))
        children = [label]
        update(withChildren: children, oldChildren: [])
        
        layer.masksToBounds = true
        layer.frame = frame
        barLayer.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        barBackgroundLayer.backgroundColor = Color.edit.cgColor
        barLayer.backgroundColor = Color.content.cgColor
        layer.addSublayer(barBackgroundLayer)
        layer.addSublayer(barLayer)
        updateChildren()
    }
    
    var value = 0.0.cf {
        didSet {
            updateChildren()
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
    var computationTime = 5.0
    var name = "" {
        didSet {
            updateString(with: locale)
        }
    }
    var type = "" {
        didSet {
            updateString(with: locale)
        }
    }
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
    func updateChildren() {
        CATransaction.disableAnimation {
            let padding = Layout.basicPadding
            barBackgroundLayer.frame = CGRect(x: padding, y: padding - 1,
                                              width: (bounds.width - padding * 2), height: 1)
            barLayer.frame = CGRect(x: padding, y: padding - 1,
                                    width: floor((bounds.width - padding * 2) * value), height: 1)
            updateString(with: locale)
        }
        
    }
    func updateString(with locale: Locale) {
        var string = ""
        if let state = state {
            string += state.string(with: locale)
        } else if let remainingTime = remainingTime {
            let minutes = Int(ceil(remainingTime)) / 60
            let seconds = Int(ceil(remainingTime)) - minutes * 60
            if minutes == 0 {
                let translator = Localization(english: "%@sec left",
                                              japanese: "あと%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator, String(seconds))
            } else {
                let translator = Localization(english: "%@min %@sec left",
                                              japanese: "あと%@分%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator,
                                                               String(minutes), String(seconds))
            }
        }
        label.text.string = type + "(" + name + "), "
            + string + (string.isEmpty ? "" : ", ") + "\(Int(value * 100)) %"
        label.frame.origin = CGPoint(x: Layout.basicPadding,
                                     y: round((frame.height - label.frame.height) / 2))
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
    
    var layer = CALayer()
    init(image: CGImage? = nil) {
        self.image = image
        layer.minificationFilter = kCAFilterTrilinear
        layer.magnificationFilter = kCAFilterTrilinear
    }
    init(url: URL?) {
        self.url = url
        if let url = url {
            self.image = ImageEditor.image(with: url)
            layer.contents = image
        }
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
                self.image = ImageEditor.image(with: url)
            }
        }
    }
    static func image(with url: URL) -> CGImage? {
        guard
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return nil
        }
        return image
    }
    func delete(with event: KeyInputEvent) {
        removeFromParent()
    }
    enum DragType {
        case move, resizeMinXMinY, resizeMaxXMinY, resizeMinXMaxY, resizeMaxXMaxY
    }
    var dragType = DragType.move, downPosition = CGPoint(), oldFrame = CGRect()
    var resizeWidth = 10.0.cf, ratio = 1.0.cf
    func drag(with event: DragEvent) {
        if let parent = parent {
            let p = parent.point(from: event), ip = point(from: event)
            switch event.sendType {
            case .begin:
                if CGRect(x: 0, y: 0, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMinXMinY
                } else if CGRect(x:  bounds.width - resizeWidth, y: 0,
                                 width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMaxXMinY
                } else if CGRect(x: 0, y: bounds.height - resizeWidth,
                                 width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMinXMaxY
                } else if CGRect(x: bounds.width - resizeWidth, y: bounds.height - resizeWidth,
                                 width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMaxXMaxY
                } else {
                    dragType = .move
                }
                downPosition = p
                oldFrame = frame
                ratio = frame.height / frame.width
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
                    frame.size.height = frame.size.width * ratio
                case .resizeMaxXMinY:
                    frame.origin.y = oldFrame.origin.y + dp.y
                    frame.size.width = oldFrame.width + dp.x
                    frame.size.height = frame.size.width * ratio
                case .resizeMinXMaxY:
                    frame.origin.x = oldFrame.origin.x + dp.x
                    frame.size.width = oldFrame.width - dp.x
                    frame.size.height = frame.size.width * ratio
                case .resizeMaxXMaxY:
                    frame.size.width = oldFrame.width + dp.x
                    frame.size.height = frame.size.width * ratio
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
    init(backgroundColor: Color = .background, borderColor: Color? = .border) {
        super.init()
        self.contentsScale = GlobalVariable.shared.backingScaleFactor
        self.needsDisplayOnBoundsChange = true
        self.drawsAsynchronously = true
        self.anchorPoint = CGPoint()
        self.isOpaque = true
        self.borderWidth = 0.5
        self.backgroundColor = backgroundColor.cgColor
        self.borderColor = borderColor?.cgColor ?? self.backgroundColor
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
        layer.borderColor = Color.border.cgColor
        layer.borderWidth = l
        layer.cornerRadius = r
        layer.bounds = CGRect(x: 0, y: 0, width: r * 2, height: r * 2)
        layer.actions = ["backgroundColor": NSNull()]
        return layer
    }
    static func slideLayer(width w: CGFloat = 5, height h: CGFloat = 10,
                           lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color.knob.cgColor
        layer.borderColor = Color.border.cgColor
        layer.borderWidth = l
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        layer.actions = ["backgroundColor": NSNull()]
        return layer
    }
    static func selectionLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color.select.cgColor
        layer.borderColor = Color.selectBorder.cgColor
        layer.borderWidth = 1
        return layer
    }
    static func deselectionLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color.deselect.cgColor
        layer.borderColor = Color.deselectBorder.cgColor
        layer.borderWidth = 1
        return layer
    }
    static func interfaceLayer(backgroundColor: Color? = nil,
                               borderColor: Color? = .border) -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        layer.borderWidth = 0.5
        layer.backgroundColor = backgroundColor?.cgColor
        layer.borderColor = borderColor?.cgColor ?? layer.backgroundColor
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
    static func disableAnimation(_ handler: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        handler()
        CATransaction.commit()
    }
}


extension CGAffineTransform {
    static func centering(from fromFrame: CGRect,
                          to toFrame: CGRect) -> (scale: CGFloat, affine: CGAffineTransform) {
        
        guard !fromFrame.isEmpty && !toFrame.isEmpty else {
            return (1, CGAffineTransform.identity)
        }
        var affine = CGAffineTransform.identity
        let fromRatio = fromFrame.width / fromFrame.height, toRatio = toFrame.width / toFrame.height
        if fromRatio > toRatio {
            let xScale = toFrame.width / fromFrame.size.width
            let y = toFrame.origin.y + (toFrame.height - fromFrame.height * xScale) / 2
            affine = affine.translatedBy(x: toFrame.origin.x, y: y)
            affine = affine.scaledBy(x: xScale, y: xScale)
            return (xScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        } else {
            let yScale = toFrame.height / fromFrame.size.height
            let x = toFrame.origin.x + (toFrame.width - fromFrame.width * yScale) / 2
            affine = affine.translatedBy(x: x, y: toFrame.origin.y)
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
        let xCount = Int(frame.width / size.width)
        let yCount = Int(frame.height / (size.height * 2))
        for xi in 0 ..< xCount {
            let x = frame.maxX - (xi + 1).cf * size.width
            let fy = xi % 2 == 0 ? size.height : 0
            for yi in 0 ..< yCount {
                let y = frame.minY + yi.cf * size.height * 2 + fy
                path.addRect(CGRect(x: x, y: y, width: size.width, height: size.height))
            }
        }
        return path
    }
}

extension CGContext {
    static func bitmap(with size: CGSize,
                       colorSpace: CGColorSpace? = CGColorSpace(name: CGColorSpace.sRGB)
        ) -> CGContext? {
        
        guard let colorSpace = colorSpace else {
            return nil
        }
        return CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                         bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                         bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    }
    func addBezier(_ bezier: Bezier3) {
        move(to: bezier.p0)
        addCurve(to: bezier.p1, control1: bezier.cp0, control2: bezier.cp1)
    }
    func flipHorizontal(by width: CGFloat) {
        translateBy(x: width, y: 0)
        scaleBy(x: -1, y: 1)
    }
    func drawBlurWith(color fillColor: Color, width: CGFloat, strength: CGFloat,
                      isLuster: Bool, path: CGPath, scale: CGFloat, rotation: CGFloat) {
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
        beginTransparencyLayer(in: boundingBoxOfClipPath.intersection(pathBounds),
                               auxiliaryInfo: nil)
        if isLuster {
            setShadow(offset: CGSize(), blur: width * scale, color: lineColor.cgColor)
        } else {
            let shadowY = hypot(pathBounds.size.width, pathBounds.size.height)
            translateBy(x: 0, y: shadowY)
            let shadowOffset = CGSize(width: shadowY * scale * sin(rotation),
                                      height: -shadowY * scale * cos(rotation))
            setShadow(offset: shadowOffset, blur: width * scale / 2, color: lineColor.cgColor)
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
