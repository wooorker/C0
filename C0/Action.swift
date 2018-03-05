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

struct ActionManager {
    var actions = [
        Action(
            name: Localization(english: "Undo", japanese: "取り消す"),
            quasimode: [.command], key: .z,
            keyInput: { (setter, getter, event) in getter.undo() }
        ),
        Action(
            name: Localization(english: "Redo", japanese: "やり直す"),
            quasimode: [.command, .shift], key: .z,
            keyInput: { (setter, getter, event) in getter.redo() }
        ),
        Action(),
        Action(
            name: Localization(english: "Cut", japanese: "カット"),
            quasimode: [.command], key: .x,
            keyInput: { (setter, getter, event) in
                let copiedObject = getter.copy(with: event)
                if let copiedObject = copiedObject, getter.delete(with: event) {
                    return setter.paste(copiedObject, with: event)
                } else {
                    return false
                }
            }
        ),
        Action(
            name: Localization(english: "Copy", japanese: "コピー"),
            quasimode: [.command], key: .c,
            keyInput: {
                if let copyObject = $1.copy(with: $2) {
                    return $0.paste(copyObject, with: $2)
                } else {
                    return false
                }
            }
        ),
        Action(
            name: Localization(english: "Paste", japanese: "ペースト"),
            quasimode: [.command], key: .v,
            keyInput: {
                if let copyObject = $0.copy(with: $2) {
                    return $1.paste(copyObject, with: $2)
                } else {
                    return false
                }
            }
        ),
        Action(
            name: Localization(english: "New", japanese: "新規"),
            quasimode: [.command], key: .d,
            keyInput: { $1.new(with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "Indicate", japanese: "指し示す"),
            gesture: .moveCursor
        ),
        Action(
            name: Localization(english: "Select", japanese: "選択"),
            quasimode: [.command], editQuasimode: .select,
            drag: { $1.select(with: $2) }
        ),
        Action(
            name: Localization(english: "Deselect", japanese: "選択解除"),
            quasimode: [.command, .shift], editQuasimode: .deselect,
            drag: { $1.deselect(with: $2) }
        ),
        Action(
            name: Localization(english: "Select All", japanese: "すべて選択"),
            quasimode: [.command], key: .a,
            keyInput: { $1.selectAll(with: $2) }
        ),
        Action(
            name: Localization(english: "Deselect All", japanese: "すべて選択解除"),
            quasimode: [.command, .shift], key: .a,
            keyInput: { $1.deselectAll(with: $2) }
        ),
        Action(
            name: Localization(english: "Bind", japanese: "バインド"),
            gesture: .rightClick, drag: { $1.bind(with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "Run", japanese: "実行"),
            gesture: .click
        ),
        Action(),
        Action(
            name: Localization(english: "Move", japanese: "移動"),
            drag: { $1.move(with: $2) }
        ),
        Action(
            name: Localization(english: "Transform", japanese: "変形"),
            quasimode: [.option], editQuasimode: .transform,
            drag: { $1.transform(with: $2) }
        ),
        Action(
            name: Localization(english: "Warp", japanese: "歪曲"),
            quasimode: [.option, .shift], editQuasimode: .warp,
            drag: { $1.warp(with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "Insert Edit Point", japanese: "編集点を追加"),
            quasimode: [.control], key: .d,
            keyInput: { $1.insertPoint(with: $2) }
        ),
        Action(
            name: Localization(english: "Remove Edit Point", japanese: "編集点を削除"),
            quasimode: [.control], key: .x,
            keyInput: { $1.removePoint(with: $2) }
        ),
        Action(
            name: Localization(english: "Move Edit Point", japanese: "編集点を移動"),
            quasimode: [.control], editQuasimode: .movePoint,
            drag: { $1.movePoint(with: $2) }
        ),
        Action(
            name: Localization(english: "Move Vertex", japanese: "頂点を移動"),
            quasimode: [.control, .shift], editQuasimode: .moveVertex,
            drag: { $1.moveVertex(with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "Stroke (Canvas Only)",
                               japanese: "ストローク (キャンバスのみ)"),
            gesture: .drag, drag: { $1.move(with: $2) }
        ),
        Action(
            name: Localization(english: "Lasso Erase", japanese: "囲み消し"),
            quasimode: [.shift], editQuasimode: .lassoErase,
            drag: { $1.lassoErase(with: $2) }
        ),
        Action(
            name: Localization(english: "Move (Canvas Only)", japanese: "移動 (キャンバスのみ)"),
            quasimode: [.command, .option], editQuasimode: .stroke,
            drag: { $1.moveInStrokable(with: $2) }
        ),
        Action(
            name: Localization(english: "Move Z", japanese: "Z移動"),
            quasimode: [.control, .option], editQuasimode: .moveZ,
            drag: { $1.moveZ(with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "Scroll", japanese: "スクロール"),
            description: Localization(
                english: "Depends on system preference.", japanese: "OSの環境設定に依存"
            ),
            gesture: .scroll
        ),
        Action(
            name: Localization(english: "Zoom", japanese: "ズーム"),
            description: Localization(
                english: "Depends on system preference.",
                japanese: "OSの環境設定に依存"
            ),
            gesture: .pinch
        ),
        Action(
            name: Localization(english: "Rotate", japanese: "回転"),
            description: Localization(
                english: "Depends on system preference.", japanese: "OSの環境設定に依存"
            ),
            gesture: .rotate
        ),
        Action(
            name: Localization(english: "Reset View", japanese: "表示を初期化"),
            description: Localization(
                english: "Depends on system preference.", japanese: "OSの環境設定に依存"
            ),
            gesture: .doubleTap
        ),
        Action(),
        Action(
            name: Localization(english: "Look Up", japanese: "調べる"),
            description: Localization(
                english: "Depends on system preference.", japanese: "OSの環境設定に依存"
            ),
            gesture: .tap
        )
    ]
    
    private(set) var moveActions = [Action]()
    private(set) var keyActions = [Action](), dragActions = [Action]()
    private(set) var clickActions = [Action](), rightClickActions = [Action]()
    private(set) var scrollActions = [Action](), pinchActions = [Action]()
    private(set) var rotateActions = [Action](), tapActions = [Action]()
    init() {
        actions.forEach {
            switch $0.gesture {
            case .keyInput:
                keyActions.append($0)
            case .click:
                clickActions.append($0)
            case .rightClick:
                rightClickActions.append($0)
            case .drag:
                dragActions.append($0)
            default:
                break
            }
        }
    }
    
    func actionWith(_ gesture: Action.Gesture, _ event: Event) -> Action? {
        func action(with actions: [Action]) -> Action? {
            for action in actions {
                if action.canSend(with: event) {
                    return action
                }
            }
            return nil
        }
        switch gesture {
        case .keyInput:
            if let action = action(with: keyActions) {
                return action
            } else {
                return Action(quasimode: event.quasimode, key: event.key,
                              keyInput: { $1.keyInput(with: $2) })
            }
        case .click:
            return action(with: clickActions)
        case .rightClick:
            return action(with: rightClickActions)
        case .drag:
            return action(with: dragActions)
        default:
            return nil
        }
    }
}

/**
 # Issue
 - トラックパッドの環境設定を無効化または表示反映
 */
struct Action {
    struct Quasimode: OptionSet {
        var rawValue: Int32
        static let shift = Quasimode(rawValue: 1), command = Quasimode(rawValue: 2)
        static let control = Quasimode(rawValue:4), option = Quasimode(rawValue: 8)
        
        var displayString: String {
            func string(_ quasimode: Quasimode, _ name: String) -> String {
                return intersection(quasimode).isEmpty ? "" : name
            }
            return string(.shift, "shift")
                .union(string(.option, "option"))
                .union(string(.control, "control"))
                .union(string(.command, "command"))
        }
    }
    
    enum Key: String {
        case
        a = "A", s = "S", d = "D", f = "F", h = "H", g = "G",  z = "Z", x = "X",
        c = "C", v = "V", b = "B", q = "Q", w = "W", e = "E", r = "R", y = "Y", t = "T",
        no1 = "1", no2 = "2", no3 = "3", no4 = "4", no6 = "6", no5 = "5", equals = "=", no9 = "9",
        no7 = "7", minus = "-", no8 = "8", no0 = "0", rightBracket = "]", o = "O",
        u = "U", leftBracket = "[", i = "I", p = "P", `return` = "return", l = "L", j = "J",
        apostrophe = "`", k = "K", semicolon = ";", frontslash = "\\", comma = ",",
        backslash = "/", n = "N", m = "M", period = ".", tab = "tab",
        space = "space", backApostrophe = "^", delete = "delete", escape = "esc",
        command = "command", shiht = "shiht", option = "option", control = "control",
        up = "↑", down = "↓", left = "←", right = "→"
    }
    
    enum Gesture: Int8 {
        case
        none, keyInput, moveCursor, click, rightClick,
        drag, scroll, pinch, rotate, tap, doubleTap, penDrag
        var displayString: Localization {
            switch self {
            case .none, .keyInput:
                return Localization()
            case .moveCursor:
                return Localization(english: "Pointing", japanese: "ポインティング")
            case .drag:
                return Localization(english: "Drag", japanese: "ドラッグ")
            case .penDrag:
                return Localization(english: "Pen Drag", japanese: "ペンドラッグ")
            case .click:
                return Localization(english: "Click", japanese: "クリック")
            case .rightClick:
                return Localization(english: "Secondary Click", japanese: "副ボタンクリック")
            case .scroll:
                return Localization(english: "Scroll Drag", japanese: "スクロールドラッグ")
            case .pinch:
                return Localization(english: "Zoom Drag", japanese: "拡大／縮小ドラッグ")
            case .rotate:
                return Localization(english: "Rotate Drag", japanese: "回転ドラッグ")
            case .tap:
                return Localization(english: "Look Up Click", japanese: "調べるクリック")
            case .doubleTap:
                return Localization(english: "Smart Zoom Click", japanese: "スマートズームクリック")
            }
        }
    }
    
    enum SendType {
        case begin, sending, end
    }
    
    var name: Localization, description: Localization
    var quasimode: Quasimode, key: Key?, editQuasimode: EditQuasimode, gesture: Gesture
    var keyInput: ((_ sender: Respondable, _ getter: Respondable, KeyInputEvent) -> Bool)?
    var drag: ((_ sender: Respondable, _ getter: Respondable, DragEvent) -> Bool)?
    
    init(name: Localization = Localization(), description: Localization = Localization(),
         quasimode: Quasimode = [], key: Key? = nil,
         editQuasimode: EditQuasimode = .move, gesture: Gesture = .none,
         keyInput: ((_ sender: Respondable, _ getter: Respondable, KeyInputEvent) -> Bool)? = nil,
         drag: ((_ sender: Respondable, _ getter: Respondable, DragEvent) -> Bool)? = nil) {
        
        self.name = name
        self.description = description
        self.quasimode = quasimode
        self.key = key
        self.editQuasimode = editQuasimode
        if keyInput != nil {
            self.gesture = .keyInput
        } else if drag != nil {
            if gesture != .rightClick && gesture != .penDrag {
                self.gesture = .drag
            } else {
                self.gesture = gesture
            }
        } else {
            self.gesture = gesture
        }
        self.keyInput = keyInput
        self.drag = drag
    }
    
    var displayCommandString: Localization {
        var displayString = Localization(quasimode.displayString)
        if let keyDisplayString = key?.rawValue {
            displayString += Localization(displayString.isEmpty ?
                keyDisplayString : " " + keyDisplayString)
        }
        let gestureDisplayString = gesture.displayString
        if !gestureDisplayString.isEmpty {
            displayString += displayString.isEmpty ?
                gestureDisplayString : Localization(" ") + gestureDisplayString
        }
        return displayString
    }
    
    func canTextKeyInput() -> Bool {
        return key != nil && !quasimode.contains(.command)
    }
    func canSend(with event: Event) -> Bool {
        func contains(with quasimode: Action.Quasimode) -> Bool {
            let flipQuasimode = quasimode.symmetricDifference([.shift, .command, .control, .option])
            return event.quasimode.contains(quasimode) &&
                event.quasimode.intersection(flipQuasimode).isEmpty
        }
        if let key = key {
            return event.key == key && contains(with: quasimode)
        } else {
            return contains(with: quasimode)
        }
    }
}
extension Action: Equatable {
    static func ==(lhs: Action, rhs: Action) -> Bool {
        return lhs.name == rhs.name
    }
}

final class ActionEditor: Layer, Respondable, Localizable {
    static let name = Localization(english: "Action Manager Editor", japanese: "アクション管理エディタ")
    
    var locale = Locale.current {
        didSet {
            updateChildren()
        }
    }
    
    static let defaultWidth = 190 + Layout.basicPadding * 2
    
    let actionManager = ActionManager()
    
    let nameLabel = Label(text: Localization(english: "Action Manager", japanese: "アクション管理"),
                          font: .bold)
    let isHiddenEditor = EnumEditor(names: [Localization(english: "Hidden", japanese: "表示なし"),
                                            Localization(english: "Shown", japanese: "表示あり")])
    var isHiddenActions = false {
        didSet {
            guard isHiddenActions != oldValue else {
                return
            }
            isHiddenEditor.selectionIndex = isHiddenActions ? 0 : 1
            updateChildren()
        }
    }
    var actionItems = [ActionItem]()
    
    func updateChildren() {
        let padding = Layout.basicPadding
        if isHiddenActions {
            actionItems = []
            nameLabel.frame.origin = CGPoint(x: padding, y: padding * 2)
            isHiddenEditor.frame = CGRect(x: nameLabel.frame.width + padding * 2,
                                          y: padding,
                                          width: 80.0,
                                          height: Layout.basicHeight)
            replace(children: [nameLabel, isHiddenEditor])
            frame.size = CGSize(width: actionWidth, height: Layout.basicHeight + padding * 2)
        } else {
            let aaf = ActionEditor.actionItemsAndFrameWith(actionManager: actionManager,
                                                           actionWidth: actionWidth - padding * 2,
                                                           minY: padding)
            self.actionItems = aaf.actionItems
            nameLabel.frame.origin = CGPoint(x: padding,
                                               y: aaf.size.height + padding * 3)
            isHiddenEditor.frame = CGRect(x: nameLabel.frame.width + padding * 2,
                                          y: aaf.size.height + padding * 2,
                                          width: 80.0, height: Layout.basicHeight)
            replace(children: [nameLabel, isHiddenEditor] + actionItems)
            frame.size = CGSize(width: actionWidth,
                                height: aaf.size.height + Layout.basicHeight + padding * 3)
        }
    }
    
    override init() {
        super.init()
        isHiddenEditor.selectionIndex = 1
        isHiddenEditor.binding = { [unowned self] in
            self.isHiddenActions = $0.index == 0
            self.isHiddenActionBinding?(self.isHiddenActions)
        }
        updateChildren()
    }
    
    var isHiddenActionBinding: ((Bool) -> (Void))? = nil
    
    var actionWidth = ActionEditor.defaultWidth, commandFont = Font.action
    
    static func actionItemsAndFrameWith(actionManager: ActionManager,
                                        actionWidth: CGFloat,
                                        minY: CGFloat) -> (actionItems: [ActionItem], size: CGSize) {
        let padding = Layout.basicPadding
        var y = minY
        let actionItems: [ActionItem] = actionManager.actions.reversed().flatMap {
            guard $0.gesture != .none else {
                y += Layout.basicPadding
                return nil
            }
            let actionItem = ActionItem(action: $0, frame: CGRect(x: padding, y: y,
                                                                  width: actionWidth, height: 0))
            y += actionItem.frame.height
            return actionItem
        }
        return (actionItems, CGSize(width: actionWidth, height: y - minY))
    }
    
    func actionItems(with quasimode: Action.Quasimode) -> [ActionItem] {
        return actionItems.filter { $0.action.quasimode == quasimode }
    }
    func actionItems(with action: Action) -> [ActionItem] {
        return actionItems.filter { $0.action == action }
    }
}

final class ActionItem: Layer, Respondable {
    static let name = Localization(english: "Action Item", japanese: "アクションアイテム")
    
    var action: Action
    
    var nameLabel: Label, commandLabel: Label
    init(action: Action, frame: CGRect) {
        self.action = action
        let nameLabel = Label(text: action.name, description: action.description)
        let commandLabel = Label(text: action.displayCommandString, font: .action,
                                 frameAlignment: .right)
        self.nameLabel = nameLabel
        self.commandLabel = commandLabel
        let padding = Layout.basicPadding
        nameLabel.frame.origin = CGPoint(x: padding, y: padding)
        commandLabel.frame.origin = CGPoint(x: frame.width - commandLabel.frame.width - padding,
                                            y: padding)
        super.init()
        instanceDescription = action.description
        self.frame = CGRect(x: frame.minX, y: frame.minY,
                            width: frame.width, height: nameLabel.frame.height + padding * 2)
        replace(children: [nameLabel, commandLabel])
    }
}

protocol Event {
    var sendType: Action.SendType { get }
    var location: CGPoint { get }
    var time: Double { get }
    var quasimode: Action.Quasimode { get }
    var key: Action.Key? { get }
}
struct BasicEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Second
    let quasimode: Action.Quasimode, key: Action.Key?
}
typealias MoveEvent = BasicEvent
typealias TapEvent = BasicEvent
typealias DoubleTapEvent = BasicEvent
struct KeyInputEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Second
    let quasimode: Action.Quasimode, key: Action.Key?
    func with(sendType: Action.SendType) -> KeyInputEvent {
        return KeyInputEvent(sendType: sendType, location: location,
                             time: time, quasimode: quasimode, key: key)
    }
}
struct DragEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Second
    let quasimode: Action.Quasimode, key: Action.Key?
    let pressure: CGFloat
}
typealias ClickEvent = DragEvent
typealias RightClickEvent = DragEvent
struct ScrollEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Second
    let quasimode: Action.Quasimode, key: Action.Key?
    let scrollDeltaPoint: CGPoint, scrollMomentumType: Action.SendType?
    let beginNormalizedPosition: CGPoint
}
struct PinchEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Second
    let quasimode: Action.Quasimode, key: Action.Key?
    let magnification: CGFloat
}
struct RotateEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Second
    let quasimode: Action.Quasimode, key: Action.Key?
    let rotation: CGFloat
}
