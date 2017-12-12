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

struct ActionManager {
    var actions = [
        Action(
            name: Localization(english: "Undo", japanese: "取り消す"),
            quasimode: [.command], key: .z,
            keyInput: { (setter, getter, event) in getter.undoManager?.undo() }
        ),
        Action(
            name: Localization(english: "Redo", japanese: "やり直す"),
            quasimode: [.command, .shift], key: .z,
            keyInput: { (setter, getter, event) in getter.undoManager?.redo() }
        ),
        Action(),
        Action(
            name: Localization(english: "Cut", japanese: "カット"),
            quasimode: [.command], key: .x,
            keyInput: { (setter, getter, event) in
                let copiedObject = getter.copy(with: event)
                getter.delete(with: event)
                setter.paste(copiedObject, with: event)
            }
        ),
        Action(
            name: Localization(english: "Copy", japanese: "コピー"),
            quasimode: [.command], key: .c,
            keyInput: { $0.paste($1.copy(with: $2), with: $2) }
        ),
        Action(
            name: Localization(english: "Paste", japanese: "ペースト"),
            quasimode: [.command], key: .v,
            keyInput: { $1.paste($0.copy(with: $2), with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "Indication", japanese: "指し示す"),
            gesture: .moveCursor
        ),
        Action(
            name: Localization(english: "Select", japanese: "選択"),
            quasimode: [.command], editQuasimode: .select,
            drag: { $1.select(with: $2) }
        ),
        Action(
            name: Localization(english: "Deselect", japanese: "選択解除"),
            quasimode: [.command, .option], editQuasimode: .deselect,
            drag: { $1.deselect(with: $2) }
        ),
        Action(
            name: Localization(english: "Select All", japanese: "すべて選択"),
            quasimode: [.command], key: .a,
            keyInput: { $1.selectAll(with: $2) }
        ),
        Action(
            name: Localization(english: "Deselect All", japanese: "すべて選択解除"),
            quasimode: [.command, .option], key: .a,
            keyInput: { $1.deselectAll(with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "New", japanese: "新規"),
            quasimode: [.command], key: .d,
            keyInput: { $1.new(with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "Add Edit Point", japanese: "編集点を追加"),
            quasimode: [.control], key: .d,
            keyInput: { $1.addPoint(with: $2) }
        ),
        Action(
            name: Localization(english: "Remove Edit Point", japanese: "編集点を削除"),
            quasimode: [.control], key: .x,
            keyInput: { $1.deletePoint(with: $2) }
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
            name: Localization(english: "Move", japanese: "移動"),
            quasimode: [.shift], editQuasimode: .move,
            drag: { $1.move(with: $2) }
        ),
        Action(
            name: Localization(english: "Move Z", japanese: "Z移動"),
            quasimode: [.shift, .option], editQuasimode: .moveZ,
            drag: { $1.moveZ(with: $2) }
        ),
        Action(
            name: Localization(english: "Warp", japanese: "歪曲"),
            quasimode: [.option], editQuasimode: .warp,
            drag: { $1.warp(with: $2) }
        ),
        Action(
            name: Localization(english: "Transform", japanese: "変形"),
            quasimode: [.option, .command], editQuasimode: .transform,
            drag: { $1.transform(with: $2) }
        ),
        Action(),
        Action(
            name: Localization(english: "Run", japanese: "実行"),
            gesture: .click
        ),
        Action(
            name: Localization(english: "Show Property", japanese: "プロパティを表示"),
            gesture: .rightClick, drag: { $1.showProperty(with: $2) }
        ),
        Action(
            name: Localization(english: "Move Knob", japanese: "ノブ移動"),
            drag: { $1.drag(with: $2) }
        ),
        Action(
            name: Localization(english: "Stroke (Canvas Only)", japanese: "ストローク (キャンバスのみ)"),
            drag: { $1.drag(with: $2) }
        ),
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
                english: "Depends on system preference.", japanese: "OSの環境設定に依存"
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
            name: Localization(english: "Reset View", japanese: "表示をリセット"),
            description: Localization(
                english: "Depends on system preference.", japanese: "OSの環境設定に依存"
            ),
            gesture: .doubleTap
        ),
        Action(
            name: Localization(english: "Look Up", japanese: "調べる"),
            description: Localization(
                english: "Depends on system preference.", japanese: "OSの環境設定に依存"
            ),
            gesture: .tap
        ),
        
        //delete
        Action(
            name: Localization("clipCellInSelection"),
            quasimode: [.command], key: .e,
            keyInput: { $1.clipCellInSelection(with: $2) }
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
                return Action(
                    quasimode: event.quasimode, key: event.key,
                    keyInput: { $1.keyInput(with: $2) }
                )
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
        drag, scroll, pinch, rotate, tap, doubleTap
        var displayString: Localization {
            switch self {
            case .none, .keyInput:
                return Localization()
            case .moveCursor:
                return Localization(english: "Move Cursor", japanese: "カーソルを移動")
            case .drag:
                return Localization(english: "Drag", japanese: "ドラッグ")
            case .click:
                return Localization(english: "Click", japanese: "クリック")
            case .rightClick:
                return Localization(english: "Two Finger Click", japanese: "2本指でクリック")
            case .scroll:
                return Localization(english: "Two Finger Drag", japanese: "2本指でドラッグ")
            case .pinch:
                return Localization(english: "Two Finger Pinch", japanese: "2本指でピンチ")
            case .rotate:
                return Localization(english: "Two Finger Rotate", japanese: "2本指で回転")
            case .tap:
                return Localization(english: "\"Look up\" Gesture", japanese: "\"調べる\"ジェスチャー")
            case .doubleTap:
                return Localization(english: "Two Finger Double Tap", japanese: "2本指でダブルタップ")
            }
        }
    }
    
    enum SendType {
        case begin, sending, end
    }
    
    var name: Localization, description: Localization
    var quasimode: Quasimode, key: Key?, editQuasimode: EditQuasimode, gesture: Gesture
    var keyInput: ((_ sender: Respondable, _ getter: Respondable, KeyInputEvent) -> Void)?
    var drag: ((_ sender: Respondable, _ getter: Respondable, DragEvent) -> Void)?
    
    init(name: Localization = Localization(), description: Localization = Localization(),
         quasimode: Quasimode = [], key: Key? = nil,
         editQuasimode: EditQuasimode = .none, gesture: Gesture = .none,
         keyInput: ((_ sender: Respondable, _ getter: Respondable, KeyInputEvent) -> Void)? = nil,
         drag: ((_ sender: Respondable, _ getter: Respondable, DragEvent) -> Void)? = nil) {
        
        self.name = name
        self.description = description
        self.quasimode = quasimode
        self.key = key
        self.editQuasimode = editQuasimode
        
        if keyInput != nil {
            self.gesture = .keyInput
        } else if drag != nil {
            if gesture != .rightClick {
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

final class ActionEditor: LayerRespondable, PulldownButtonDelegate, Localizable {
    static let name = Localization(english: "Action Manager Editor", japanese: "アクション管理エディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            updateChildren()
        }
    }
    
    static let defaultWidth = 190 + Layout.basicPadding * 2
    
    let layer = CALayer.interfaceLayer(borderColor: .border)
    let defaultBorderColor: CGColor? = Color.border.cgColor
    let actionManager = ActionManager()
    
    let actionlabel = Label(text: Localization(english: "Action Manager(", japanese: "アクション管理("))
    let isHiddenButton = PulldownButton(names: [Localization(english: "Hidden", japanese: "表示なし"),
                                                Localization(english: "Shown", japanese: "表示あり")])
    let actionCommalabel = Label(text: Localization(","))
    let actionEndlabel = Label(text: Localization(")"))
    var isHiddenActions = false {
        didSet {
            guard isHiddenActions != oldValue else {
                return
            }
            isHiddenButton.selectionIndex = isHiddenActions ? 0 : 1
            updateChildren()
        }
    }
    var actionItems = [ActionItem]()
    
    func updateChildren() {
        CATransaction.disableAnimation {
            let padding = Layout.basicPadding
            if isHiddenActions {
                self.actionItems = []
                actionlabel.frame.origin = CGPoint(
                    x: padding,
                    y: padding * 2
                )
                isHiddenButton.frame = CGRect(
                    x: actionlabel.frame.width + padding, y: padding,
                    width: 80.0, height: Layout.basicHeight
                )
                actionEndlabel.frame.origin = CGPoint(
                    x: actionlabel.frame.width + isHiddenButton.frame.width + padding,
                    y: padding * 2
                )
                self.children = [actionlabel, isHiddenButton, actionEndlabel]
                self.frame.size = CGSize(width: actionWidth, height: Layout.basicHeight + padding * 2)
            } else {
                let commaHeight = Layout.basicHeight - padding * 2
                let aaf = ActionEditor.actionItemsAndFrameWith(
                    actionManager: actionManager,
                    actionWidth: actionWidth - padding * 2, minY: commaHeight + padding
                )
                self.actionItems = aaf.actionItems
                actionlabel.frame.origin = CGPoint(
                    x: padding,
                    y: aaf.size.height + commaHeight + padding * 3
                )
                isHiddenButton.frame = CGRect(
                    x: actionlabel.frame.width + padding,
                    y: aaf.size.height + commaHeight + padding * 2,
                    width: 80.0, height: Layout.basicHeight
                )
                actionCommalabel.frame.origin = CGPoint(
                    x: actionlabel.frame.width + isHiddenButton.frame.width + padding,
                    y: aaf.size.height + commaHeight + padding * 3
                )
                actionEndlabel.frame.origin = CGPoint(
                    x: padding,
                    y: padding
                )
                self.children = [actionlabel, isHiddenButton, actionCommalabel] as [Respondable] +
                    actionItems as [Respondable] + [actionEndlabel] as [Respondable]
                self.frame.size = CGSize(width: actionWidth, height: aaf.size.height +
                    Layout.basicHeight + commaHeight + padding * 3)
            }
        }
    }
    
    init() {
        isHiddenButton.selectionIndex = 1
        isHiddenButton.delegate = self
        updateChildren()
    }
    
    var isHiddenActionBinding: ((Bool) -> (Void))? = nil
    func changeValue(_ pulldownButton: PulldownButton,
                     index: Int, oldIndex: Int, type: Action.SendType) {
        
        isHiddenActions = index == 0
        isHiddenActionBinding?(isHiddenActions)
    }
    
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

final class ActionItem: LayerRespondable {
    static let name = Localization(english: "Action Item", japanese: "アクションアイテム")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var action: Action
    
    var layer = CALayer.interfaceLayer()
    var nameLabel: Label, commandLabel: Label
    init(action: Action, frame: CGRect) {
        self.action = action
        let nameLabel = Label(text: action.name, color: .locked,
                              description: action.description)
        let commandLabel = Label(text: action.displayCommandString,
                                 font: .action, color: .locked, alignment: .right)
        self.nameLabel = nameLabel
        self.commandLabel = commandLabel
        let padding = Layout.basicPadding
        nameLabel.frame.origin = CGPoint(x: padding, y: padding)
        commandLabel.frame.origin = CGPoint(x: frame.width - commandLabel.text.frame.width - padding,
                                            y: padding)
        layer.frame = CGRect(x: frame.minX, y: frame.minY,
                             width: frame.width, height: nameLabel.frame.height + padding * 2)
        self.children = [nameLabel, commandLabel]
        update(withChildren: children, oldChildren: [])
    }
}

protocol Event {
    var sendType: Action.SendType { get }
    var location: CGPoint { get }
    var time: Double { get }
    var quasimode: Action.Quasimode { get }
    var key: Action.Key? { get }
}
struct MoveEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double
    let quasimode: Action.Quasimode, key: Action.Key?
}
struct KeyInputEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double
    let quasimode: Action.Quasimode, key: Action.Key?
    func with(sendType: Action.SendType) -> KeyInputEvent {
        return KeyInputEvent(sendType: sendType, location: location,
                             time: time, quasimode: quasimode, key: key)
    }
}
struct DragEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double
    let quasimode: Action.Quasimode, key: Action.Key?
    let pressure: CGFloat
}
typealias ClickEvent = DragEvent
typealias RightClickEvent = DragEvent
struct ScrollEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double
    let quasimode: Action.Quasimode, key: Action.Key?
    let scrollDeltaPoint: CGPoint, scrollMomentumType: Action.SendType?
}
struct PinchEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double
    let quasimode: Action.Quasimode, key: Action.Key?
    let magnification: CGFloat
}
struct RotateEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double
    let quasimode: Action.Quasimode, key: Action.Key?
    let rotation: CGFloat
}
struct TapEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double
    let quasimode: Action.Quasimode, key: Action.Key?
}
struct DoubleTapEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double
    let quasimode: Action.Quasimode, key: Action.Key?
}
