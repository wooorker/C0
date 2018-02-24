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

final class Drager {
    private var downPosition = CGPoint(), oldFrame = CGRect()
    func drag(with event: DragEvent, _ responder: Layer, in parent: Layer) {
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
    }
}
final class Scroller {
    func scroll(with event: ScrollEvent, responder: Layer) {
        responder.frame.origin += event.scrollDeltaPoint
    }
}

final class Padding: Layer, Respondable {
    static let name = Localization(english: "Padding", japanese: "パディング")
    override init() {
        super.init()
        self.frame = CGRect(origin: CGPoint(),
                            size: CGSize(width: Layout.basicPadding, height: Layout.basicPadding))
    }
}

final class Knob: Layer {
    init(radius: CGFloat = 5, lineWidth: CGFloat = 1) {
        super.init()
        fillColor = .knob
        lineColor = .border
        self.lineWidth = lineWidth
        self.radius = radius
    }
    var radius: CGFloat {
        get {
            return min(bounds.width, bounds.height) / 2
        }
        set {
            frame = CGRect(x: position.x - newValue, y: position.y - newValue,
                           width: newValue * 2, height: newValue * 2)
            cornerRadius = newValue
        }
    }
}
final class DiscreteKnob: Layer {
    init(_ size: CGSize = CGSize(width: 5, height: 10), lineWidth: CGFloat = 1) {
        super.init()
        fillColor = .knob
        lineColor = .border
        self.lineWidth = lineWidth
        frame.size = size
    }
}

final class DrawingResponder: DrawLayer, Respondable {
    static let name = Localization(english: "Drawing Responder", japanese: "描画レスポンダ")
}

final class GroupResponder: Layer, Respondable {
    static let name = Localization(english: "Group", japanese: "グループ")
    
    init(children: [Layer] = [], frame: CGRect = CGRect()) {
        super.init()
        self.frame = frame
        replace(children: children)
    }
    
    var bindHandler: ((GroupResponder, RightClickEvent) -> (Bool))?
    func bind(with event: RightClickEvent) -> Bool {
        return bindHandler?(self, event) ?? false
    }
    
    var moveHandler: ((GroupResponder, DragEvent) -> (Bool))?
    func move(with event: DragEvent) -> Bool {
        return moveHandler?(self, event) ?? false
    }
}

final class Button: Layer, Respondable {
    static let name = Localization(english: "Button", japanese: "ボタン")
    static let feature = Localization(english: "Run text in the button: Click",
                                      japanese: "ボタン内のテキストを実行: クリック")
    var valueDescription: Localization {
        return label.localization
    }
    
    let label: Label
    let highlight = HighlightLayer()
    
    init(frame: CGRect = CGRect(), name: Localization = Localization(),
         isLeftAlignment: Bool = true, leftPadding: CGFloat = Layout.basicPadding,
         runHandler: ((Button) -> (Bool))? = nil) {
        
        self.runHandler = runHandler
        self.label = Label(text: name, color: .locked)
        self.isLeftAlignment = isLeftAlignment
        self.leftPadding = leftPadding
        label.frame.origin = CGPoint(
            x: isLeftAlignment ? leftPadding : round((frame.width - label.frame.width) / 2),
            y: round((frame.height - label.frame.height) / 2)
        )
        
        super.init()
        self.frame = frame
        highlight.frame = bounds.inset(by: 0.5)
        replace(children: [label, highlight])
    }
    
    override var defaultBounds: CGRect {
        let fitSize = label.fitSize
        return CGRect(x: 0,
                      y: 0,
                      width: fitSize.width + leftPadding + Layout.basicPadding,
                      height: fitSize.height + Layout.basicPadding * 2)
    }
    override var bounds: CGRect {
        didSet {
            updateChildren()
        }
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
        highlight.frame = bounds.inset(by: 0.5)
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [label.string])
    }
    
    var runHandler: ((Button) -> (Bool))?
    func run(with event: ClickEvent) -> Bool {
        highlight.setIsHighlighted(true, animate: false)
        let isChanged = runHandler?(self) ?? false
        if highlight.isHighlighted {
            highlight.setIsHighlighted(false, animate: true)
        }
        return isChanged
    }
}

/**
 # Issue
 - コピーオブジェクトの自由な貼り付け
 */
final class PastableResponder: Layer, Respondable {
    static let name = Localization(english: "Group", japanese: "グループ")
    
    init(children: [Layer] = [], frame: CGRect = CGRect()) {
        super.init()
        self.frame = frame
        replace(children: children)
    }
    var canPasteImage = false
    let minPasteImageWidth = 400.0.cf
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        var isChanged = false
        if canPasteImage {
            let p = self.point(from: event)
            for object in copiedObject.objects {
                if let url = object as? URL {
                    append(child: makeImageEditor(url: url, position: p))
                    isChanged = true
                }
            }
        }
        return isChanged
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

/**
 # Issue
 - リファレンス表示の具体化
 */
final class ReferenceEditor: Layer, Respondable {
    static let name = Localization(english: "Reference Editor", japanese: "情報エディタ")
    static let feature = Localization(english: "Close: Move cursor to outside",
                                      japanese: "閉じる: カーソルを外に出す")
    
    var reference: Referenceable? {
        didSet {
            updateWithReference()
        }
    }
    
    let minWidth = 200.0.cf
    
    init(reference: Referenceable? = nil) {
        self.reference = reference
        super.init()
        fillColor = .background
        updateWithReference()
    }
    
    private func updateWithReference() {
        if let reference = reference {
            let cas = ReferenceEditor.childrenAndSize(with: reference, width: minWidth)
            replace(children: cas.children)
            frame = CGRect(x: frame.origin.x, y: frame.origin.y - (cas.size.height - frame.height),
                           width: cas.size.width, height: cas.size.height)
        } else {
            replace(children: [])
        }
    }
    private static func childrenAndSize(with reference: Referenceable,
                                width: CGFloat) -> (children: [Layer], size: CGSize) {
        
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
final class ObjectEditor: Layer, Respondable, Localizable {
    static let name = Localization(english: "Object Editor", japanese: "オブジェクトエディタ")
    
    var locale = Locale.current {
        didSet {
            updateFrameWith(origin: frame.origin,
                            thumbnailWidth: thumbnailWidth, height: frame.height)
        }
    }
    
    let object: Any
    
    static let thumbnailWidth = 40.0.cf
    let thumbnailEditor: Layer, label: Label, thumbnailWidth: CGFloat
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
        self.thumbnailEditor = (object as? ResponderExpression)?
            .responder(withBounds: thumbnailBounds) ?? GroupResponder()
        
        super.init()
        instanceDescription = (object as? Referenceable)?.valueDescription ?? Localization()
        replace(children: [label, thumbnailEditor])
        updateFrameWith(origin: origin, thumbnailWidth: thumbnailWidth, height: height)
    }
    func updateFrameWith(origin: CGPoint, thumbnailWidth: CGFloat, height: CGFloat) {
        let thumbnailHeight = height - Layout.basicPadding * 2
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        let width = label.frame.width + thumbnailSize.width + Layout.basicPadding * 3
        frame = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        label.frame.origin = CGPoint(x: Layout.basicPadding, y: Layout.basicPadding)
        self.thumbnailEditor.frame = CGRect(x: label.frame.maxX + Layout.basicPadding,
                                            y: Layout.basicPadding,
                                            width: thumbnailSize.width,
                                            height: thumbnailSize.height)
    }
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [object])
    }
}
final class CopiedObjectEditor: Layer, Respondable, Localizable {
    static let name = Localization(english: "Copied Object Editor", japanese: "コピーオブジェクトエディタ")
    
    var locale = Locale.current {
        didSet {
            noneLabel.locale = locale
            updateChildren()
        }
    }
    
    var rootUndoManager = UndoManager()
    override var undoManager: UndoManager? {
        return rootUndoManager
    }
    
    var changeCount = 0
    
    var objectEditors = [ObjectEditor]() {
        didSet {
            let padding = Layout.basicPadding
            nameLabel.frame.origin = CGPoint(x: padding, y: padding * 2)
            if objectEditors.isEmpty {
                replace(children: [nameLabel, versionEditor, versionCommaLabel, noneLabel])
                let cs = [versionEditor, Padding(), versionCommaLabel, noneLabel]
                _ = Layout.leftAlignment(cs, minX: nameLabel.frame.maxX + padding,
                                         height: frame.height)
            } else {
                replace(children: [nameLabel, versionEditor, versionCommaLabel] + objectEditors)
                let cs = [versionEditor, Padding(), versionCommaLabel] + objectEditors as [Layer]
                _ = Layout.leftAlignment(cs, minX: nameLabel.frame.maxX + padding,
                                         height: frame.height)
            }
        }
    }
    let nameLabel = Label(text: Localization(english: "Copy Manager", japanese: "コピー管理"),
                                             font: .bold)
    let versionEditor = VersionEditor()
    let versionCommaLabel = Label(text: Localization(english: "Copied:", japanese: "コピー済み:"))
    let noneLabel = Label(text: Localization(english: "Empty", japanese: "空"))
    override init() {
        versionEditor.frame = CGRect(x: 0, y: 0, width: 120, height: Layout.basicHeight)
        versionEditor.rootUndoManager = rootUndoManager
        super.init()
        isClipped = true
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
    
    func delete(with event: KeyInputEvent) -> Bool {
        guard !copiedObject.objects.isEmpty else {
            return false
        }
        setCopiedObject(CopiedObject(), oldCopiedObject: copiedObject)
        return true
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        setCopiedObject(copiedObject, oldCopiedObject: self.copiedObject)
        return true
    }
    private func setCopiedObject(_ copiedObject: CopiedObject, oldCopiedObject: CopiedObject) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setCopiedObject(oldCopiedObject, oldCopiedObject: copiedObject)
        }
        self.copiedObject = copiedObject
    }
}

/**
 # Issue
 - バージョン管理UndoManagerを導入
 */
final class VersionEditor: Layer, Respondable, Localizable {
    static let name = Localization(english: "Version Editor", japanese: "バージョンエディタ")
    static let feature = Localization(english: "Show undoable count and undoed count in parent group",
                                      japanese: "親グループでの取り消し可能回数、取り消し済み回数を表示")
    
    private var undoGroupToken: NSObjectProtocol?
    private var undoToken: NSObjectProtocol?, redoToken: NSObjectProtocol?
    var rootUndoManager: UndoManager? {
        didSet {
            removeNotification()
            let nc = NotificationCenter.default
            
            undoGroupToken = nc.addObserver(forName: .NSUndoManagerDidCloseUndoGroup,
                                            object: rootUndoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.rootUndoManager {
                    
                    if undoManager.groupingLevel == 0 {
                        self.undoCount += 1
                        self.allCount = self.undoCount
                        self.updateLabel()
                    }
                }
            }
            
            undoToken = nc.addObserver(forName: .NSUndoManagerDidUndoChange,
                                       object: rootUndoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.rootUndoManager {
                    
                    self.undoCount -= 1
                    self.updateLabel()
                }
            }
            
            redoToken = nc.addObserver(forName: .NSUndoManagerDidRedoChange,
                                       object: rootUndoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.rootUndoManager {
                    
                    self.undoCount += 1
                    self.updateLabel()
                }
            }
            
            updateLabel()
        }
    }
    override var undoManager: UndoManager? {
        return rootUndoManager
    }
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    var undoCount = 0, allCount = 0
    
    let nameLabel = Label(text: Localization(english: "Version", japanese: "バージョン"), font: .bold)
    let allCountLabel = Label(text: Localization("0"))
    let currentCountLabel = Label(color: .warning)
    override init() {
        allCountLabel.noIndicatedLineColor = .border
        allCountLabel.indicatedLineColor = .indicated
        currentCountLabel.noIndicatedLineColor = .border
        currentCountLabel.indicatedLineColor = .indicated
        
        _ = Layout.leftAlignment([nameLabel, Padding(), allCountLabel],
                                 height: Layout.basicHeight)
        super.init()
        isClipped = true
        replace(children: [nameLabel, allCountLabel])
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
    
    override var bounds: CGRect {
        didSet {
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

final class PopupBox: Layer, Respondable, Localizable {
    static let name = Localization(english: "Popup Box", japanese: "ポップアップボックス")
    
    var locale = Locale.current {
        didSet {
            panel.allChildrenAndSelf { ($0 as? Localizable)?.locale = locale }
        }
    }
    
    var isSubIndicatedHandler: ((Bool) -> (Void))?
    override var isSubIndicated: Bool {
        didSet {
            guard isSubIndicated != oldValue else {
                return
            }
            isSubIndicatedHandler?(isSubIndicated)
            if !isSubIndicated && panel.parent != nil {
                panel.removeFromParent()
            }
        }
    }
    
    private let arrowLayer: PathLayer = {
        let arrowLayer = PathLayer()
        arrowLayer.lineColor = .content
        arrowLayer.lineWidth = 2
        return arrowLayer
    } ()
    
    let label: Label
    init(frame: CGRect, text: Localization, panel: Panel = Panel(isUseHedding: false)) {
        label = Label(text: text, color: .locked)
        label.frame.origin = CGPoint(x: round((frame.width - label.frame.width) / 2),
                                     y: round((frame.height - label.frame.height) / 2))
        self.panel = panel
        
        super.init()
        self.frame = frame
        replace(children: [label, arrowLayer])
        panel.subIndicatedParent = self
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
    
    override var defaultBounds: CGRect {
        return label.textFrame.typographicBounds
    }
    override var bounds: CGRect {
        didSet {
            label.frame.origin = CGPoint(x: arrowWidth,
                                         y: round((bounds.height - label.frame.height) / 2))
            updateArrowPosition()
        }
    }
    
    func run(with event: ClickEvent) -> Bool {
        if panel.parent == nil {
            let root = self.root
            if root !== self {
                panel.frame.origin = root.convert(CGPoint(x: 0, y: -panel.frame.height),
                                                  from: self)
                if panel.parent == nil {
                    root.append(child: panel)
                }
            }
        }
        return true
    }
}
final class Panel: Layer, Respondable {
    static let name = Localization(english: "Panel", japanese: "パネル")
    
    let openPointRadius = 2.0.cf
    var openPoint = CGPoint() {
        didSet {
            let padding = isUseHedding ? heddingHeight / 2 : 0
            frame.origin = CGPoint(x: openPoint.x - padding,
                                   y: openPoint.y + padding - frame.height)
        }
    }
    var openViewPoint = CGPoint()
    var contents: [Layer] {
        didSet {
            frame.size = Panel.contentsSizeAndVerticalAlignment(contents: contents,
                                                                isUseHedding: isUseHedding,
                                                                heddingHeight: heddingHeight)
            replace(children: contents)
            
            let padding = heddingHeight / 2
            openPointLayer?.position = CGPoint(x: padding, y: bounds.maxY - padding)
            if let openPointLayer = openPointLayer {
                append(child: openPointLayer)
            }
        }
    }
    private static func contentsSizeAndVerticalAlignment(contents: [Layer],
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
    
    override weak var subIndicatedParent: Layer? {
        didSet {
            if isUseHedding, let root = subIndicatedParent?.root {
                if !root.children.contains(where: { $0 === self }) {
                    root.append(child: self)
                }
            }
        }
    }
    
    override var isSubIndicated: Bool {
        didSet {
            if isUseHedding && !isSubIndicated {
                removeFromParent()
            }
        }
    }
    
    let heddingHeight = 14.0.cf
    let isUseHedding: Bool
    private let openPointLayer: Knob?
    init(contents: [Layer] = [], isUseHedding: Bool) {
        self.isUseHedding = isUseHedding
        let size = Panel.contentsSizeAndVerticalAlignment(contents: contents,
                                                          isUseHedding: isUseHedding,
                                                          heddingHeight: heddingHeight)
        if isUseHedding {
            let openPointLayer = Knob(), padding = heddingHeight / 2
            openPointLayer.radius = openPointRadius
            openPointLayer.fillColor = .content
            openPointLayer.lineColor = nil
            openPointLayer.position = CGPoint(x: padding, y: size.height - padding)
            self.openPointLayer = openPointLayer
            self.contents = contents
            
            super.init()
            fillColor = Color.background.multiply(alpha: 0.6)
            let origin = CGPoint(x: openPoint.x - padding, y: openPoint.y + padding - size.height)
            frame = CGRect(origin: origin, size: size)
            replace(children: contents)
            append(child: openPointLayer)
        } else {
            openPointLayer = nil
            self.contents = contents
            
            super.init()
            fillColor = .background
            frame = CGRect(origin: CGPoint(), size: size)
            replace(children: contents)
        }
    }
}

final class DiscreteSizeEditor: Layer, Respondable {
    static let name = Localization(english: "Size Editor", japanese: "サイズエディタ")
    
    private let wLabel = Label(text: Localization("w:"))
    private let widthSlider = NumberSlider(frame: Layout.valueFrame,
                                           min: 1, max: 10000, valueInterval: 1,
                                           description: Localization(english: "Scene width",
                                                                     japanese: "シーンの幅"))
    private let hLabel = Label(text: Localization("h:"))
    private let heightSlider = NumberSlider(frame: Layout.valueFrame,
                                            min: 1, max: 10000, valueInterval: 1,
                                            description: Localization(english: "Scene height",
                                                                      japanese: "シーンの高さ"))
    init(description: Localization = Localization()) {
        super.init()
        instanceDescription = description
        let size = Layout.leftAlignment([wLabel, widthSlider, Padding(), hLabel, heightSlider],
                                        height: Layout.basicHeight + Layout.basicPadding * 2)
        frame.size = CGSize(width: size.width + Layout.basicPadding, height: size.height)
        replace(children: [wLabel, widthSlider, hLabel, heightSlider])
        
        widthSlider.binding = { [unowned self] in self.setSize(with: $0) }
        heightSlider.binding = { [unowned self] in self.setSize(with: $0) }
    }
    
    var size = CGSize() {
        didSet {
            if size != oldValue {
                widthSlider.value = size.width
                heightSlider.value = size.height
            }
        }
    }
    
    var defaultSize = CGSize()
    
    struct Binding {
        let editor: DiscreteSizeEditor
        let size: CGSize, oldSize: CGSize, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    private var oldSize = CGSize()
    private func setSize(with obj: NumberSlider.Binding) {
        if obj.type == .begin {
            oldSize = size
            binding?(Binding(editor: self, size: oldSize, oldSize: oldSize, type: .begin))
        } else {
            size = obj.slider == widthSlider ?
                size.with(width: obj.value) : size.with(height: obj.value)
            binding?(Binding(editor: self, size: size, oldSize: oldSize, type: obj.type))
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [size])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let size = object as? CGSize {
                guard size != self.size else {
                    continue
                }
                set(size, oldSize: self.size)
                return true
            }
        }
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        let size = defaultSize
        guard size != self.size else {
            return false
        }
        set(size, oldSize: self.size)
        return true
    }
    
    func set(_ size: CGSize, oldSize: CGSize) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldSize, oldSize: size) }
        binding?(Binding(editor: self, size: size, oldSize: oldSize, type: .begin))
        self.size = size
        binding?(Binding(editor: self, size: size, oldSize: oldSize, type: .end))
    }
}

final class PointEditor: Layer, Respondable {
    static let name = Localization(english: "Point Editor", japanese: "ポイントエディタ")
    
    var backgroundLayers = [Layer]() {
        didSet {
            replace(children: backgroundLayers + [knob])
        }
    }
    
    let knob = Knob()
    init(frame: CGRect = CGRect(), description: Localization = Localization()) {
        super.init()
        instanceDescription = description
        self.frame = frame
        append(child: knob)
    }
    
    override var bounds: CGRect {
        didSet {
            knob.position = position(from: point)
        }
    }
    
    var isOutOfBounds = false {
        didSet {
            if isOutOfBounds != oldValue {
                knob.fillColor = isOutOfBounds ? .warning : .knob
            }
        }
    }
    var padding = 5.0.cf
    
    var defaultPoint = CGPoint()
    var pointAABB = AABB(minX: 0, maxX: 1, minY: 0, maxY: 1) {
        didSet {
            guard pointAABB.maxX - pointAABB.minX > 0 && pointAABB.maxY - pointAABB.minY > 0 else {
                fatalError("Division by zero")
            }
        }
    }
    var point = CGPoint() {
        didSet {
            isOutOfBounds = !pointAABB.contains(point)
            if point != oldValue {
                knob.position = isOutOfBounds ?
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
    
    struct Binding {
        let editor: PointEditor, point: CGPoint, oldPoint: CGPoint, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [point])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let point = object as? CGPoint {
                guard point != self.point else {
                    continue
                }
                set(point, oldPoint: self.point)
                return true
            }
        }
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        let point = defaultPoint
        guard point != self.point else {
            return false
        }
        set(point, oldPoint: self.point)
        return true
    }
    
    private var oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = self.point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .editing
            oldPoint = point
            binding?(Binding(editor: self, point: point, oldPoint: oldPoint, type: .begin))
            point = clippedPoint(with: self.point(withPosition: p))
            binding?(Binding(editor: self, point: point, oldPoint: oldPoint, type: .sending))
        case .sending:
            point = clippedPoint(with: self.point(withPosition: p))
            binding?(Binding(editor: self, point: point, oldPoint: oldPoint, type: .sending))
        case .end:
            point = clippedPoint(with: self.point(withPosition: p))
            if point != oldPoint {
                registeringUndoManager?.registerUndo(withTarget: self) { [point, oldPoint] in
                    $0.set(oldPoint, oldPoint: point)
                }
            }
            binding?(Binding(editor: self, point: point, oldPoint: oldPoint, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    func set(_ point: CGPoint, oldPoint: CGPoint) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldPoint, oldPoint: point) }
        binding?(Binding(editor: self, point: point, oldPoint: oldPoint, type: .begin))
        self.point = point
        binding?(Binding(editor: self, point: point, oldPoint: oldPoint, type: .end))
    }
}

final class Progress: Layer, Respondable, Localizable {
    static let name = Localization(english: "Progress", japanese: "進捗")
    static let feature = Localization(english: "Stop: Send \"Cut\" action",
                                      japanese: "停止: \"カット\"アクションを送信")
    
    var locale = Locale.current {
        didSet {
            updateString(with: locale)
        }
    }
    
    let barLayer = Layer()
    let barBackgroundLayer = Layer()
    
    let label: Label
    
    init(frame: CGRect = CGRect(), backgroundColor: Color = .background,
         name: String = "", type: String = "", state: Localization? = nil) {
        
        self.name = name
        self.type = type
        self.state = state
        label = Label()
        label.frame.origin = CGPoint(x: Layout.basicPadding,
                                     y: round((frame.height - label.frame.height) / 2))
        barLayer.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        barBackgroundLayer.fillColor = .editing
        barLayer.fillColor = .content
        
        super.init()
        self.frame = frame
        isClipped = true
        replace(children: [label, barBackgroundLayer, barLayer])
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
    
    var deleteHandler: ((Progress) -> (Bool))?
    weak var operation: Operation?
    func delete(with event: KeyInputEvent) -> Bool {
        if let operation = operation {
            operation.cancel()
        }
        return deleteHandler?(self) ?? false
    }
}

final class ImageEditor: Layer, Respondable {
    static let name = Localization(english: "Image Editor", japanese: "画像エディタ")
    
    init(image: CGImage? = nil) {
        super.init()
        self.image = image
    }
    init(url: URL?) {
        super.init()
        self.url = url
        if let url = url {
            self.image = ImageEditor.image(with: url)
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
    func delete(with event: KeyInputEvent) -> Bool {
        removeFromParent()
        return true
    }
    enum DragType {
        case move, resizeMinXMinY, resizeMaxXMinY, resizeMinXMaxY, resizeMaxXMaxY
    }
    var dragType = DragType.move, downPosition = CGPoint(), oldFrame = CGRect()
    var resizeWidth = 10.0.cf, ratio = 1.0.cf
    func move(with event: DragEvent) -> Bool {
        guard let parent = parent else {
            return false
        }
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
        return true
    }
}
