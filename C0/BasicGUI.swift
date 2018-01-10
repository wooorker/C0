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

protocol Drawable {
    func responder(with bounds: CGRect) -> Respondable
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
                responder.frame.origin = CGPoint(x: oldFrame.origin.x + dp.x,
                                                 y: oldFrame.origin.y + dp.y)
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
        responder.frame.origin += event.scrollDeltaPoint
    }
}

final class Padding: Respondable {
    static let name = Localization(english: "Padding", japanese: "パディング")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    init() {
        frame = CGRect(origin: CGPoint(),
                       size: CGSize(width: Layout.basicPadding, height: Layout.basicPadding))
    }
    var frame: CGRect
}

final class GroupResponder: LayerRespondable {
    static let name = Localization(english: "Group", japanese: "グループ")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var layer: CALayer
    init(layer: CALayer = CALayer.interface(),
         children: [Respondable] = [], frame: CGRect = CGRect()) {
        
        layer.frame = frame
        layer.masksToBounds = true
        self.layer = layer
        replace(children: children)
    }
    var canPasteImage = false
    let minPasteImageWidth = 400.0.cf
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        if canPasteImage {
            let p = self.point(from: event)
            for object in copiedObject.objects {
                if let url = object as? URL {
                    append(child: makeImageEditor(url: url, position: p))
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

final class ReferenceEditor: LayerRespondable {
    static let name = Localization(english: "Reference Editor", japanese: "情報エディタ")
    static let feature = Localization(english: "Close: Move cursor to outside",
                                      japanese: "閉じる: カーソルを外に出す")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    let layer = CALayer.interface(backgroundColor: .background)
    let minWidth = 200.0.cf
    init(reference: Referenceable? = nil) {
        self.reference = reference
        update(with: reference)
    }
    
    var defaultBorderColor: CGColor? = Color.border.cgColor
    
    var reference: Referenceable? {
        didSet {
            update(with: reference)
        }
    }
    func update(with reference: Referenceable?) {
        if let reference = reference {
            let cas = ReferenceEditor.childrenAndSize(with: reference, width: minWidth)
            replace(children: cas.children)
            frame = CGRect(x: frame.origin.x, y: frame.origin.y - (cas.size.height - frame.height),
                           width: cas.size.width, height: cas.size.height)
        } else {
            replace(children: [])
        }
    }
    static func childrenAndSize(with reference: Referenceable,
                                width: CGFloat) -> (children: [Respondable], size: CGSize) {
        
        let type =  Swift.type(of: reference).name, feature = Swift.type(of: reference).feature
        let instanceDescription = reference.instanceDescription
        let description: Localization
        if instanceDescription.isEmpty && feature.isEmpty {
            description = Localization(english: "No description", japanese: "説明なし")
        } else {
            description = !instanceDescription.isEmpty && !feature.isEmpty ?
                instanceDescription + Localization("\n\n") + feature : instanceDescription + feature
        }
        
        let typeLabel = Label(frame: CGRect(x: 0, y: 0, width: width, height: 0),
                              text: type, font: .hedding0)
        let descriptionLabel = Label(frame: CGRect(x: 0, y: 0, width: width, height: 0),
                                     text: description)
        let padding = Layout.basicPadding
        let size = CGSize(width: width + padding * 2,
                          height: typeLabel.frame.height + descriptionLabel.frame.height + padding * 5)
        var y = size.height - typeLabel.frame.height - padding * 2
        typeLabel.frame.origin = CGPoint(x: padding, y: y)
        y -= descriptionLabel.frame.height + padding
        descriptionLabel.frame.origin = CGPoint(x: padding, y: y)
        return ([typeLabel, descriptionLabel], size)
    }
}

protocol Copiable {
    var copied: Self { get }
}
struct CopiedObject {
    var objects: [Any]
    init(objects: [Any] = []) {
        self.objects = objects
    }
}
final class ObjectEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Object Editor", japanese: "オブジェクトエディタ")
    var instanceDescription: Localization {
        return (object as? Referenceable)?.valueDescription ?? Localization()
    }
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var locale = Locale.current {
        didSet {
            updateFrameWith(origin: frame.origin,
                            thumbnailWidth: thumbnailWidth, height: frame.height)
        }
    }
    
    let object: Any
    
    static let thumbnailWidth = 40.0.cf
    let thumbnailEditor: Respondable, label: Label, thumbnailWidth: CGFloat
    let layer = CALayer.interface()
    init(object: Any, origin: CGPoint,
         thumbnailWidth: CGFloat = ObjectEditor.thumbnailWidth, height: CGFloat) {
        
        self.object = object
        if let reference = object as? Referenceable {
            self.label = Label(text: type(of: reference).name, font: .bold)
        } else {
            self.label = Label(text: Localization(String(describing: type(of: object))), font: .bold)
        }
        self.thumbnailWidth = thumbnailWidth
        let thumbnailBounds = CGRect(x: 0, y: 0, width: thumbnailWidth, height: 0)
        self.thumbnailEditor = (object as? Drawable)?
            .responder(with: thumbnailBounds) ?? GroupResponder()
        
        replace(children: [label, thumbnailEditor])
        
        updateFrameWith(origin: origin, thumbnailWidth: thumbnailWidth, height: height)
    }
    func updateFrameWith(origin: CGPoint, thumbnailWidth: CGFloat, height: CGFloat) {
        let thumbnailHeight = height - Layout.basicPadding * 2
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        let width = label.frame.width + thumbnailSize.width + Layout.basicPadding * 3
        layer.frame = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        label.frame.origin = CGPoint(x: Layout.basicPadding, y: Layout.basicPadding)
        self.thumbnailEditor.frame = CGRect(x: label.frame.maxX + Layout.basicPadding,
                                            y: Layout.basicPadding,
                                            width: thumbnailSize.width,
                                            height: thumbnailSize.height)
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [object])
    }
}
final class CopiedObjectEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Copied Object Editor", japanese: "コピーオブジェクトエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var locale = Locale.current {
        didSet {
            noneLabel.locale = locale
            updateChildren()
        }
    }
    
    var undoManager: UndoManager? = UndoManager()
    
    var changeCount = 0
    
    var objectEditors = [ObjectEditor]() {
        didSet {
            let padding = Layout.basicPadding
            nameLabel.frame.origin = CGPoint(x: padding, y: padding * 2)
            if objectEditors.isEmpty {
                replace(children: [nameLabel, versionEditor, versionCommaLabel, noneLabel])
                let cs: [Respondable] = [versionEditor, Padding(),
                                         versionCommaLabel, noneLabel]
                _ = Layout.leftAlignment(cs, minX: nameLabel.frame.maxX + padding, height: frame.height)
            } else {
                replace(children: [nameLabel, versionEditor, versionCommaLabel] as [Respondable]
                    + objectEditors as [Respondable])
                let cs = [versionEditor, Padding(), versionCommaLabel] as [Respondable]
                    + objectEditors as [Respondable]
                _ = Layout.leftAlignment(cs,
                                         minX: nameLabel.frame.maxX + padding, height: frame.height)
            }
        }
    }
    let nameLabel = Label(text: Localization(english: "Copy Manager", japanese: "コピー管理"),
                                             font: .bold)
    let versionEditor = VersionEditor()
    let versionCommaLabel = Label(text: Localization(english: "Copied:", japanese: "コピー済み:"))
    let noneLabel = Label(text: Localization(english: "Empty", japanese: "空"))
    let layer = CALayer.interface()
    init() {
        versionEditor.frame = CGRect(x: 0, y: 0, width: 120, height: Layout.basicHeight)
        versionEditor.undoManager = undoManager
        layer.masksToBounds = true
        
        replace(children: [nameLabel, versionEditor, versionCommaLabel, noneLabel])
    }
    var copiedObject = CopiedObject() {
        didSet {
            changeCount += 1
            updateChildren()
        }
    }
    func updateChildren() {
        let padding = Layout.basicPadding
        var origin = CGPoint(x: padding, y: padding)
        objectEditors = copiedObject.objects.map { object in
            let objectEditor = ObjectEditor(object: object, origin: origin,
                                            height: frame.height - padding * 2)
            origin.x += objectEditor.frame.width + padding
            return objectEditor
        }
    }
    
    func delete(with event: KeyInputEvent) {
        setCopiedObject(CopiedObject(), oldCopiedObject: copiedObject)
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        setCopiedObject(copiedObject, oldCopiedObject: self.copiedObject)
    }
    func setCopiedObject(_ copiedObject: CopiedObject, oldCopiedObject: CopiedObject) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setCopiedObject(oldCopiedObject, oldCopiedObject: copiedObject)
        }
        self.copiedObject = copiedObject
    }
}

/*
 # Issue
 バージョン管理UndoManagerを導入
 */
final class VersionEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Version Editor", japanese: "バージョンエディタ")
    static let feature = Localization(english: "Show undoable count and undoed count in parent group",
                                      japanese: "親グループでの取り消し可能回数、取り消し済み回数を表示")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
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
            updateLayout()
        }
    }
    
    var undoCount = 0, allCount = 0
    
    let layer = CALayer.interface()
    let nameLabel = Label(text: Localization(english: "Version", japanese: "バージョン"), font: .bold)
    let allCountLabel = Label(text: Localization("0"))
    let currentCountLabel = Label(color: .warning)
    init() {
        layer.masksToBounds = true
        allCountLabel.defaultBorderColor = Color.border.cgColor
        currentCountLabel.defaultBorderColor = Color.border.cgColor
        
        replace(children: [nameLabel, allCountLabel])
        
        _ = Layout.leftAlignment([nameLabel, Padding(), allCountLabel],
                                 height: Layout.basicHeight)
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
            updateLayout()
        }
    }
    func updateLabel() {
        if undoCount < allCount {
            allCountLabel.localization = Localization("\(allCount)")
            currentCountLabel.localization = Localization("\(undoCount - allCount)")
            if currentCountLabel.parent == nil {
                replace(children: [nameLabel, allCountLabel, currentCountLabel])
                updateLayout()
            }
        } else {
            allCountLabel.localization = Localization("\(allCount)")
            if currentCountLabel.parent != nil {
                replace(children: [nameLabel, allCountLabel])
                updateLayout()
            }
        }
    }
    func updateLayout() {
        if undoCount < allCount {
            _ = Layout.leftAlignment([nameLabel, Padding(),
                                      allCountLabel, Padding(), currentCountLabel],
                                     height: frame.height)
        } else {
            _ = Layout.leftAlignment([nameLabel, Padding(), allCountLabel],
                                     height: frame.height)
        }
    }
}

final class Button: LayerRespondable, Equatable {
    static let name = Localization(english: "Button", japanese: "ボタン")
    static let feature = Localization(english: "Run text in the button: Click",
                                      japanese: "ボタン内のテキストを実行: クリック")
    var valueDescription: Localization {
        return label.localization
    }
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    let label: Label
    
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(), highlight = Highlight()
    
    init(frame: CGRect = CGRect(), name: Localization = Localization(),
         isLeftAlignment: Bool = true, leftPadding: CGFloat = Layout.basicPadding,
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
        
        replace(children: [label])
        
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
        let fitSize = label.fitSize
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
        return CopiedObject(objects: [label.string])
    }
}

final class Panel: LayerRespondable {
    static let name = Localization(english: "Panel", japanese: "パネル")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var undoManager: UndoManager?
    
    let openPointRadius = 2.0.cf
    var openPoint = CGPoint() {
        didSet {
            let padding = isUseHedding ? heddingHeight / 2 : 0
            frame.origin = CGPoint(x: openPoint.x - padding,
                                   y: openPoint.y + padding - frame.height)
        }
    }
    var openViewPoint = CGPoint()
    var contents: [Respondable] {
        didSet {
            frame.size = Panel.contentsSizeAndVerticalAlignment(contents: contents,
                                                                isUseHedding: isUseHedding,
                                                                heddingHeight: heddingHeight)
            replace(children: contents)
            
            let r = openPointRadius, padding = heddingHeight / 2
            openPointLayer?.frame = CGRect(x: padding - r, y: bounds.maxY - padding - r,
                                           width: r * 2, height: r * 2)
            if let openPointLayer = openPointLayer {
                layer.addSublayer(openPointLayer)
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
            if isUseHedding, let root = indicationParent?.root {
                if !root.children.contains(where: { $0 === self }) {
                    root.append(child: self)
                }
            }
        }
    }
    
    let heddingHeight = 14.0.cf
    let isUseHedding: Bool
    private let openPointLayer: CALayer?
    let layer = CALayer.interface()
    init(contents: [Respondable] = [], isUseHedding: Bool) {
        self.isUseHedding = isUseHedding
        
        let size = Panel.contentsSizeAndVerticalAlignment(contents: contents,
                                                          isUseHedding: isUseHedding,
                                                          heddingHeight: heddingHeight)
        
        if isUseHedding {
            let openPointLayer = CALayer.disabledAnimation
            let r = openPointRadius, padding = heddingHeight / 2
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
        
        replace(children: contents)
        
        if let openPointLayer = openPointLayer {
            layer.addSublayer(openPointLayer)
        }
    }
    
    let scroller = Scroller()
    func scroll(with event: ScrollEvent) {
        if isUseHedding {
            scroller.scroll(with: event, responder: self)
        }
    }
}
final class PopupBox: LayerRespondable {
    static let name = Localization(english: "Popup Button", japanese: "ポップアップボタン")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var isSubIndicationHandler: ((Bool) -> (Void))?
    var isSubIndication = false {
        didSet {
            isSubIndicationHandler?(isSubIndication)
            if isSubIndication {
                let root = self.root
                if root !== self {
                    panel.frame.origin = root.convert(CGPoint(x: 0, y: -panel.frame.height),
                                                      from: self)
                    if panel.parent == nil {
                        root.append(child: panel)
                    }
                }
            } else {
                panel.removeFromParent()
            }
        }
    }
    
    private let arrowLayer: CAShapeLayer = {
        let arrowLayer = CAShapeLayer()
        arrowLayer.strokeColor = Color.content.cgColor
        arrowLayer.fillColor = nil
        arrowLayer.lineWidth = 2
        return arrowLayer
    }()
    
    let label: Label
    let layer = CALayer.interface()
    init(frame: CGRect, text: Localization, panel: Panel = Panel(isUseHedding: false)) {
        label = Label(text: text, color: .locked)
        label.frame.origin = CGPoint(x: round((frame.width - label.frame.width) / 2),
                                     y: round((frame.height - label.frame.height) / 2))
        self.panel = panel
        layer.frame = frame
        
        replace(children: [label])
        layer.addSublayer(arrowLayer)
        panel.indicationParent = self
        updateArrowPosition()
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
        return label.textFrame.typographicBounds
    }
}

final class PulldownButton: LayerRespondable, Equatable, Localizable {
    static let name = Localization(english: "Pulldown Button", japanese: "プルダウンボタン")
    static let feature = Localization(english: "Select Index: Up and down drag",
                                      japanese: "インデックスを選択: 上下ドラッグ")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var locale = Locale.current {
        didSet {
            menu.allChildrenAndSelf { ($0 as? Localizable)?.locale = locale }
        }
    }
    
    let label: Label
    let knobLayer = CALayer.discreteKnob(width: 8, height: 8, lineWidth: 1)
    private let lineLayer: CAShapeLayer = {
        let lineLayer = CAShapeLayer()
        lineLayer.actions = CALayer.disableAnimationActions
        lineLayer.fillColor = Color.content.cgColor
        return lineLayer
    }()
    let layer = CALayer.interface()
    init(frame: CGRect = CGRect(), names: [Localization] = [],
         selectionIndex: Int = 0, isEnabledCation: Bool = false,
         description: Localization = Localization()) {
        
        self.instanceDescription = description
        self.menu = Menu(names: names, knobPaddingWidth: knobPaddingWidth, width: frame.width)
        self.isEnabledCation = isEnabledCation
        self.label = Label(text: names[selectionIndex], color: .locked)
        
        label.frame.origin = CGPoint(x: knobPaddingWidth,
                                     y: round((frame.height - label.frame.height) / 2))
        layer.frame = frame
        replace(children: [label])
        
        layer.addSublayer(lineLayer)
        layer.addSublayer(knobLayer)
        updateKnobPosition()
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
        return label.textFrame.typographicBounds
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
    
    struct HandlerObject {
       let pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType
    }
    var setIndexHandler: ((HandlerObject) -> ())?
    
    var disabledRegisterUndo = false
    
    var defaultValue = 0
    func delete(with event: KeyInputEvent) {
        let oldIndex = selectionIndex, index = defaultValue
        guard index != oldIndex else {
            return
        }
        set(index: index, oldIndex: oldIndex)
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [String(selectionIndex)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let string = object as? String, let index = Int(string) {
                let oldIndex = selectionIndex
                guard index != oldIndex else {
                    continue
                }
                set(index: index, oldIndex: oldIndex)
                return
            }
        }
    }
    func set(index: Int, oldIndex: Int) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(index: oldIndex, oldIndex: index)
        }
        setIndexHandler?(HandlerObject(pulldownButton: self,
                                       index: oldIndex, oldIndex: oldIndex, type: .begin))
        self.selectionIndex = index
        setIndexHandler?(HandlerObject(pulldownButton: self,
                                       index: index, oldIndex: oldIndex, type: .end))
    }
    
    var willOpenMenuHandler: ((PulldownButton) -> ())? = nil
    var menu: Menu
    private var isDrag = false, oldIndex = 0, beginPoint = CGPoint()
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            isDrag = false
            
            beginPoint = p
            let root = self.root
            if root !== self {
                willOpenMenuHandler?(self)
                label.layer.isHidden = true
                lineLayer.isHidden = true
                knobLayer.isHidden = true
                menu.frame.origin = root.convert(CGPoint(x: 0, y: -menu.frame.height + p.y),
                                                 from: self)
                root.append(child: menu)
            }
            
            oldIndex = selectionIndex
            setIndexHandler?(HandlerObject(pulldownButton: self,
                                           index: oldIndex, oldIndex: oldIndex, type: .begin))
            
            let index = self.index(withY: -(p.y - beginPoint.y))
            if index != selectionIndex {
                selectionIndex = index
                setIndexHandler?(HandlerObject(pulldownButton: self,
                                               index: index, oldIndex: oldIndex, type: .sending))
            }
        case .sending:
            isDrag = true
            let index = self.index(withY: -(p.y - beginPoint.y))
            if index != selectionIndex {
                selectionIndex = index
                setIndexHandler?(HandlerObject(pulldownButton: self,
                                               index: index, oldIndex: oldIndex, type: .sending))
            }
        case .end:
            let index = self.index(withY: -(p.y - beginPoint.y))
            if index != selectionIndex {
                selectionIndex = index
            }
            if index != oldIndex {
                registeringUndoManager?.registerUndo(withTarget: self) { [index, oldIndex] in
                    $0.set(index: oldIndex, oldIndex: index)
                }
            }
            setIndexHandler?(HandlerObject(pulldownButton: self,
                                           index: index, oldIndex: oldIndex, type: .end))
            
            label.layer.isHidden = false
            lineLayer.isHidden = false
            knobLayer.isHidden = false
            closeMenu(animate: false)
        }
    }
    private func closeMenu(animate: Bool) {
        menu.removeFromParent()
    }
    func index(withY y: CGFloat) -> Int {
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
            label.localization = menu.names[selectionIndex]
            if isEnabledCation && selectionIndex != oldValue {
                if selectionIndex == 0 {
                    if let oldFontColor = oldFontColor {
                        label.textFrame.color = oldFontColor
                    }
                } else {
                    oldFontColor = label.textFrame.color
                    label.textFrame.color = .warning
                }
            }
        }
    }
}

final class Menu: LayerRespondable, Localizable {
    static let name = Localization(english: "Menu", japanese: "メニュー")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var locale = Locale.current {
        didSet {
            items.forEach { $0.label.locale = locale }
        }
    }
    
    var width = 0.0.cf {
        didSet {
            updateItems()
        }
    }
    var menuHeight = Layout.basicHeight
    let knobPaddingWidth: CGFloat
    let layer = CALayer.interface()
    init(names: [Localization] = [], knobPaddingWidth: CGFloat = 18.0.cf, width: CGFloat) {
        self.names = names
        self.knobPaddingWidth = knobPaddingWidth
        self.width = width
        updateItems()
    }
    let selectionLayer: CALayer = {
        let layer = CALayer.disabledAnimation
        layer.backgroundColor = Color.translucentEdit.cgColor
        return layer
    } ()
    private let lineLayer: CAShapeLayer = {
        let lineLayer = CAShapeLayer()
        lineLayer.fillColor = Color.content.cgColor
        return lineLayer
    } ()
    var selectionKnobLayer = CALayer.discreteKnob(width: 8, height: 8, lineWidth: 1)
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            items.forEach { $0.allChildrenAndSelf { $0.contentsScale = newValue } }
        }
    }
    
    var names = [Localization]() {
        didSet {
            updateItems()
        }
    }
    private(set) var items = [Button]()
    func updateItems() {
        if names.isEmpty {
            self.frame.size = CGSize(width: 10, height: 10)
            self.items = []
            replace(children: [])
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
            replace(children: items)
            
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
    var selectionIndex = 0 {
        didSet {
            guard selectionIndex != oldValue else {
                return
            }
            let selectionLabel = items[selectionIndex]
            selectionLayer.frame = selectionLabel.frame
            selectionKnobLayer.position = CGPoint(x: knobPaddingWidth / 2,
                                                  y: selectionLabel.frame.midY)
        }
    }
}

final class DiscreteSizeEditor: LayerRespondable {
    static let name = Localization(english: "Size Editor", japanese: "サイズエディタ")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    private let wLabel = Label(text: Localization("w:"))
    private let widthSlider = NumberSlider(frame: SceneEditor.valueFrame,
                                           min: 1, max: 10000, valueInterval: 1,
                                           description: Localization(english: "Scene width",
                                                                     japanese: "シーンの幅"))
    private let hLabel = Label(text: Localization("h:"))
    private let heightSlider = NumberSlider(frame: SceneEditor.valueFrame,
                                            min: 1, max: 10000, valueInterval: 1,
                                            description: Localization(english: "Scene height",
                                                                      japanese: "シーンの高さ"))
    
    let layer = CALayer.interface()
    init(description: Localization = Localization()) {
        self.instanceDescription = description
        
        let size = Layout.leftAlignment([wLabel, widthSlider, Padding(), hLabel, heightSlider],
                                        height: Layout.basicHeight + Layout.basicPadding * 2)
        layer.frame.size = CGSize(width: size.width + Layout.basicPadding, height: size.height)
        
        replace(children: [wLabel, widthSlider, hLabel, heightSlider])
        
        widthSlider.setValueHandler = { [unowned self] in self.setSize(with: $0) }
        heightSlider.setValueHandler = { [unowned self] in self.setSize(with: $0) }
    }
    
    var defaultSize = CGSize()
    
    var size = CGSize() {
        didSet {
            if size != oldValue {
                widthSlider.value = size.width
                heightSlider.value = size.height
            }
        }
    }
    
    struct HandlerObject {
        let discreteSizeEditor: DiscreteSizeEditor
        let size: CGSize, oldSize: CGSize, type: Action.SendType
    }
    var setSizeHandler: ((HandlerObject) -> ())?
    
    var disabledRegisterUndo = false
    
    private var oldSize = CGSize()
    private func setSize(with obj: NumberSlider.HandlerObject) {
        if obj.type == .begin {
            oldSize = size
            setSizeHandler?(HandlerObject(discreteSizeEditor: self,
                                          size: oldSize, oldSize: oldSize, type: .begin))
        } else {
            size = obj.slider == widthSlider ?
                size.with(width: obj.value) : size.with(height: obj.value)
            setSizeHandler?(HandlerObject(discreteSizeEditor: self,
                                          size: size, oldSize: oldSize, type: obj.type))
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [size])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let size = object as? CGSize {
                guard size != self.size else {
                    continue
                }
                set(size, oldSize: self.size)
                return
            }
        }
    }
    func delete(with event: KeyInputEvent) {
        let size = defaultSize
        guard size != self.size else {
            return
        }
        set(size, oldSize: self.size)
    }
    
    func set(_ size: CGSize, oldSize: CGSize) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldSize, oldSize: size) }
        setSizeHandler?(HandlerObject(discreteSizeEditor: self,
                                      size: size, oldSize: oldSize, type: .begin))
        self.size = size
        setSizeHandler?(HandlerObject(discreteSizeEditor: self,
                                      size: size, oldSize: oldSize, type: .end))
    }
}

final class PointEditor: LayerRespondable {
    static let name = Localization(english: "Point Editor", japanese: "ポイントエディタ")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    let layer = CALayer.interface(), knobLayer = CALayer.knob()
    init(frame: CGRect = CGRect(), description: Localization = Localization()) {
        self.instanceDescription = description
        layer.frame = frame
        layer.addSublayer(knobLayer)
        update(with: bounds)
    }
    
    func update(with bounds: CGRect) {
        knobLayer.position = position(from: point)
    }
    
    var isOutOfBounds = false {
        didSet {
            if isOutOfBounds != oldValue {
                knobLayer.backgroundColor = isOutOfBounds ?
                    Color.warning.cgColor : Color.knob.cgColor
            }
        }
    }
    var padding = 5.0.cf
    
    var defaultPoint = CGPoint()
    var pointAABB = AABB(minX: 0, maxX: 1, minY: 0, maxY: 1) {
        didSet {
            if pointAABB.maxX - pointAABB.minX <= 0 || pointAABB.maxY - pointAABB.minY <= 0 {
                fatalError()
            }
        }
    }
    var point = CGPoint() {
        didSet {
            isOutOfBounds = !pointAABB.contains(point)
            if point != oldValue {
                knobLayer.position = isOutOfBounds ?
                    position(from: clippedPoint(with: point)) : position(from: point)
            }
        }
    }
    
    func clippedPoint(with point: CGPoint) -> CGPoint {
        return pointAABB.clippedPoint(with: point)
    }
    func point(withPosition position: CGPoint) -> CGPoint {
        let inB = bounds.inset(by: padding)
        let x = pointAABB.width * (position.x - inB.origin.x) / inB.width + pointAABB.minX
        let y = pointAABB.height * (position.y - inB.origin.y) / inB.height + pointAABB.minY
        return CGPoint(x: x, y: y)
    }
    func position(from point: CGPoint) -> CGPoint {
        let inB = bounds.inset(by: padding)
        let x = inB.width * (point.x - pointAABB.minX) / pointAABB.width + inB.origin.x
        let y = inB.height * (point.y - pointAABB.minY) / pointAABB.height + inB.origin.y
        return CGPoint(x: x, y: y)
    }
    
    struct HandlerObject {
        let pointEditor: PointEditor, point: CGPoint, oldPoint: CGPoint, type: Action.SendType
    }
    var setPointHandler: ((HandlerObject) -> ())?
    
    var disabledRegisterUndo = false
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [point])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let point = object as? CGPoint {
                guard point != self.point else {
                    continue
                }
                set(point, oldPoint: self.point)
                return
            }
        }
    }
    func delete(with event: KeyInputEvent) {
        let point = defaultPoint
        guard point != self.point else {
            return
        }
        set(point, oldPoint: self.point)
    }
    
    private var oldPoint = CGPoint()
    func drag(with event: DragEvent) {
        let p = self.point(from: event)
        switch event.sendType {
        case .begin:
            knobLayer.backgroundColor = Color.edit.cgColor
            oldPoint = point
            setPointHandler?(HandlerObject(pointEditor: self,
                                           point: point, oldPoint: oldPoint, type: .begin))
            point = clippedPoint(with: self.point(withPosition: p))
            setPointHandler?(HandlerObject(pointEditor: self,
                                           point: point, oldPoint: oldPoint, type: .sending))
        case .sending:
            point = clippedPoint(with: self.point(withPosition: p))
            setPointHandler?(HandlerObject(pointEditor: self,
                                           point: point, oldPoint: oldPoint, type: .sending))
        case .end:
            point = clippedPoint(with: self.point(withPosition: p))
            if point != oldPoint {
                registeringUndoManager?.registerUndo(withTarget: self) { [point, oldPoint] in
                    $0.set(oldPoint, oldPoint: point)
                }
            }
            setPointHandler?(HandlerObject(pointEditor: self,
                                           point: point, oldPoint: oldPoint, type: .end))
            knobLayer.backgroundColor = Color.knob.cgColor
        }
    }
    
    func set(_ point: CGPoint, oldPoint: CGPoint) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldPoint, oldPoint: point) }
        setPointHandler?(HandlerObject(pointEditor: self,
                                       point: point, oldPoint: oldPoint, type: .begin))
        self.point = point
        setPointHandler?(HandlerObject(pointEditor: self,
                                       point: point, oldPoint: oldPoint, type: .end))
    }
}

final class Progress: LayerRespondable, Localizable {
    static let name = Localization(english: "Progress", japanese: "進捗")
    static let feature = Localization(english: "Stop: Send \"Cut\" action",
                                      japanese: "停止: \"カット\"アクションを送信")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var locale = Locale.current {
        didSet {
            updateString(with: locale)
        }
    }
    
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer, barLayer = CALayer.disabledAnimation
    let barBackgroundLayer = CALayer.disabledAnimation
    
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
        layer.masksToBounds = true
        layer.frame = frame
        barLayer.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        barBackgroundLayer.backgroundColor = Color.edit.cgColor
        barLayer.backgroundColor = Color.content.cgColor
        
        replace(children: [label])
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
    var deleteHandler: ((Progress) -> ())? = nil
    weak var operation: Operation?
    func delete(with event: KeyInputEvent) {
        if let operation = operation {
            operation.cancel()
        }
        deleteHandler?(self)
    }
    func updateChildren() {
        let padding = Layout.basicPadding
        barBackgroundLayer.frame = CGRect(x: padding, y: padding - 1,
                                          width: (bounds.width - padding * 2), height: 1)
        barLayer.frame = CGRect(x: padding, y: padding - 1,
                                width: floor((bounds.width - padding * 2) * value), height: 1)
        updateString(with: locale)
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
        label.string = type + "(" + name + "), "
            + string + (string.isEmpty ? "" : ", ") + "\(Int(value * 100)) %"
        label.frame.origin = CGPoint(x: Layout.basicPadding,
                                     y: round((frame.height - label.frame.height) / 2))
    }
}

final class ImageEditor: LayerRespondable {
    static let name = Localization(english: "Image Editor", japanese: "画像エディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    var layer = CALayer.interface()
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
                
                self.frame = event.sendType == .end ? frame.integral : frame
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

extension CATransaction {
    static func disableAnimation(_ handler: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        handler()
        CATransaction.commit()
    }
}

extension CGImage {
    var size: CGSize {
        return CGSize(width: width, height: height)
    }
}
