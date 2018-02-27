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
 - EnumEditorに変更 (RawRepresentable利用)
 - ノブの滑らかな移動
 */
final class PulldownButton: Layer, Respondable, Localizable {
    static let name = Localization(english: "Enumerated Type Editor", japanese: "列挙型エディタ")
    static let feature = Localization(english: "Select Index: Up and down drag",
                                      japanese: "インデックスを選択: 上下ドラッグ")
    
    var locale = Locale.current {
        didSet {
            menu.allChildrenAndSelf { ($0 as? Localizable)?.locale = locale }
        }
    }
    
    let label: Label
    let knob = DiscreteKnob(CGSize(width: 8, height: 8), lineWidth: 1)
    private let lineLayer: PathLayer = {
        let lineLayer = PathLayer()
        lineLayer.fillColor = .content
        return lineLayer
    } ()
    init(frame: CGRect = CGRect(), names: [Localization] = [],
         selectionIndex: Int = 0, cationIndex: Int? = nil,
         description: Localization = Localization()) {
        
        self.menu = Menu(names: names, knobPaddingWidth: knobPaddingWidth, width: frame.width)
        self.cationIndex = cationIndex
        self.label = Label(color: .locked)
        
        super.init()
        instanceDescription = description
        self.frame = frame
        replace(children: [label, lineLayer, knob])
        updateKnobPosition()
        updateLabel()
    }
    
    override var defaultBounds: CGRect {
        return label.textFrame.typographicBounds
    }
    override var bounds: CGRect {
        didSet {
            label.frame.origin.y = round((bounds.height - label.frame.height) / 2)
            if menu.width != bounds.width {
                menu.width = bounds.width
            }
            updateKnobPosition()
        }
    }
    func updateKnobPosition() {
        lineLayer.path = CGPath(rect: CGRect(x: knobPaddingWidth / 2 - 1, y: 0,
                                             width: 2, height: bounds.height / 2), transform: nil)
        knob.position = CGPoint(x: knobPaddingWidth / 2, y: bounds.midY)
    }
    override var contentsScale: CGFloat {
        didSet {
            menu.contentsScale = contentsScale
        }
    }
    
    struct Binding {
        let pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType
    }
    var setIndexHandler: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    var defaultValue = 0
    func delete(with event: KeyInputEvent) -> Bool {
        let oldIndex = selectionIndex, index = defaultValue
        guard index != oldIndex else {
            return false
        }
        set(index: index, oldIndex: oldIndex)
        return true
    }
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [String(selectionIndex)])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let string = object as? String, let index = Int(string) {
                let oldIndex = selectionIndex
                guard index != oldIndex else {
                    continue
                }
                set(index: index, oldIndex: oldIndex)
                return true
            }
        }
        return false
    }
    func set(index: Int, oldIndex: Int) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(index: oldIndex, oldIndex: index)
        }
        setIndexHandler?(Binding(pulldownButton: self,
                                       index: oldIndex, oldIndex: oldIndex, type: .begin))
        self.selectionIndex = index
        setIndexHandler?(Binding(pulldownButton: self,
                                       index: index, oldIndex: oldIndex, type: .end))
    }
    
    var willOpenMenuHandler: ((PulldownButton) -> ())? = nil
    var menu: Menu
    private var isDrag = false, oldIndex = 0, beginPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            isDrag = false
            
            beginPoint = p
            let root = self.root
            if root !== self {
                willOpenMenuHandler?(self)
                label.isHidden = true
                lineLayer.isHidden = true
                knob.isHidden = true
                menu.frame.origin = root.convert(CGPoint(x: 0, y: -menu.frame.height + p.y),
                                                 from: self)
                root.append(child: menu)
            }
            
            oldIndex = selectionIndex
            setIndexHandler?(Binding(pulldownButton: self,
                                           index: oldIndex, oldIndex: oldIndex, type: .begin))
            
            let index = self.index(withY: -(p.y - beginPoint.y))
            if index != selectionIndex {
                selectionIndex = index
                setIndexHandler?(Binding(pulldownButton: self,
                                               index: index, oldIndex: oldIndex, type: .sending))
            }
        case .sending:
            isDrag = true
            let index = self.index(withY: -(p.y - beginPoint.y))
            if index != selectionIndex {
                selectionIndex = index
                setIndexHandler?(Binding(pulldownButton: self,
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
            setIndexHandler?(Binding(pulldownButton: self,
                                           index: index, oldIndex: oldIndex, type: .end))
            
            label.isHidden = false
            lineLayer.isHidden = false
            knob.isHidden = false
            closeMenu(animate: false)
        }
        return true
    }
    private func closeMenu(animate: Bool) {
        menu.removeFromParent()
    }
    func index(withY y: CGFloat) -> Int {
        return Int(y / menu.menuHeight).clip(min: 0, max: menu.names.count - 1)
    }
    var cationIndex: Int?
    
    var knobPaddingWidth = 16.0.cf
    private var oldFontColor: Color?
    var selectionIndex = 0 {
        didSet {
            guard selectionIndex != oldValue else {
                return
            }
            menu.selectionIndex = selectionIndex
            if selectionIndex != oldValue {
                updateLabel()
            }
        }
    }
    private func updateLabel() {
        label.localization = menu.names[selectionIndex]
        label.frame.origin = CGPoint(x: knobPaddingWidth,
                                     y: round((frame.height - label.frame.height) / 2))
        if let cationIndex = cationIndex {
            if selectionIndex != cationIndex {
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

final class Menu: Layer, Respondable, Localizable {
    static let name = Localization(english: "Menu", japanese: "メニュー")
    
    var locale = Locale.current {
        didSet {
            items.forEach { $0.label.locale = locale }
        }
    }
    
    var selectionIndex = 0 {
        didSet {
            guard selectionIndex != oldValue else {
                return
            }
            let selectionLabel = items[selectionIndex]
            selectionLayer.frame = selectionLabel.frame
            selectionKnob.position = CGPoint(x: knobPaddingWidth / 2,
                                             y: selectionLabel.frame.midY)
        }
    }
    
    var width = 0.0.cf {
        didSet {
            updateItems()
        }
    }
    var menuHeight = Layout.basicHeight {
        didSet {
            updateItems()
        }
    }
    let knobPaddingWidth: CGFloat
    
    let selectionLayer: Layer = {
        let layer = Layer()
        layer.fillColor = .translucentEdit
        return layer
    } ()
    let lineLayer: PathLayer = {
        let lineLayer = PathLayer()
        lineLayer.fillColor = .content
        return lineLayer
    } ()
    let selectionKnob = DiscreteKnob(CGSize(width: 8, height: 8), lineWidth: 1)
    
    var names = [Localization]() {
        didSet {
            updateItems()
        }
    }
    private(set) var items = [LabelBox]()
    private func updateItems() {
        if names.isEmpty {
            self.frame.size = CGSize(width: 10, height: 10)
            self.items = []
            replace(children: [])
        } else {
            let h = menuHeight * names.count.cf
            var y = h
            let items: [LabelBox] = names.map {
                y -= menuHeight
                return LabelBox(frame: CGRect(x: 0, y: y, width: width, height: menuHeight),
                                name: $0,
                                isLeftAlignment: true,
                                leftPadding: knobPaddingWidth)
            }
            let path = CGMutablePath()
            path.addRect(CGRect(x: knobPaddingWidth / 2 - 1,
                                y: menuHeight / 2,
                                width: 2,
                                height: h - menuHeight))
            items.forEach {
                path.addRect(CGRect(x: knobPaddingWidth / 2 - 2,
                                    y: $0.frame.midY - 2,
                                    width: 4,
                                    height: 4))
            }
            lineLayer.path = path
            let selectionLabel = items[selectionIndex]
            selectionLayer.frame = selectionLabel.frame
            selectionKnob.position = CGPoint(x: knobPaddingWidth / 2,
                                             y: selectionLabel.frame.midY)
            frame.size = CGSize(width: width, height: h)
            self.items = items
            replace(children: items + [lineLayer, selectionKnob, selectionLayer])
        }
    }
    
    init(names: [Localization] = [], knobPaddingWidth: CGFloat = 18.0.cf, width: CGFloat) {
        self.names = names
        self.knobPaddingWidth = knobPaddingWidth
        self.width = width
        super.init()
        fillColor = .background
        updateItems()
    }
}
