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

/**
 # Issue
 - コピーオブジェクトの自由な貼り付け
 */
final class Box: Layer, Respondable {
    static let name = Localization(english: "Box", japanese: "ボックス")
    
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
    
    var bindHandler: ((Box, RightClickEvent) -> (Bool))?
    func bind(with event: RightClickEvent) -> Bool {
        return bindHandler?(self, event) ?? false
    }
    
    var moveHandler: ((Box, DragEvent) -> (Bool))?
    func move(with event: DragEvent) -> Bool {
        return moveHandler?(self, event) ?? false
    }
}

final class DrawingBox: DrawLayer, Respondable {
    static let name = Localization(english: "Drawing Box", japanese: "描画ボックス")
}

final class TextBox: Layer, Respondable {
    static let name = Localization(english: "Text Box", japanese: "テキストボックス")
    static let feature = Localization(english: "Run text in the box: Click",
                                      japanese: "ボックス内のテキストを実行: クリック")
    var valueDescription: Localization {
        return label.localization
    }
    
    let label: Label
    let highlight = HighlightLayer()
    
    init(frame: CGRect = CGRect(), name: Localization = Localization(),
         isLeftAlignment: Bool = true, leftPadding: CGFloat = Layout.basicPadding,
         runHandler: ((TextBox) -> (Bool))? = nil) {
        
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
    
    var runHandler: ((TextBox) -> (Bool))?
    func run(with event: ClickEvent) -> Bool {
        highlight.setIsHighlighted(true, animate: false)
        let isChanged = runHandler?(self) ?? false
        if highlight.isHighlighted {
            highlight.setIsHighlighted(false, animate: true)
        }
        return isChanged
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
