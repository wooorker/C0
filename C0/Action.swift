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

struct ActionNode {
    static let `default` = ActionNode(
        children: [
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "Undo", japanese: "取り消す"),
                        quasimode: [.command], key: .z,
                        keyInput: { $1.undo(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Redo", japanese: "やり直す"),
                        quasimode: [.shift, .command], key: .z,
                        keyInput: { $1.redo(with: $2) }
                    )
                ]
            ),
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "Cut", japanese: "カット"),
                        quasimode: [.command], key: .x,
                        keyInput: { $0.paste($1.cut(with: $2), with: $2) }
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
                    )
                ]
            ),
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "Indication", japanese: "指し示す"),
                        gesture: .moveCursor
                    ),
                    Action(
                        name: Localization(english: "Select", japanese: "選択"),
                        quasimode: [.shift],
                        editQuasimode: .select, drag: { $1.select(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Deselect", japanese: "選択解除"),
                        quasimode: [.shift, .command],
                        editQuasimode: .deselect, drag: { $1.deselect(with: $2) }
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
                    )
                ]
            ),
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "New", japanese: "新規"),
                        quasimode: [.command], key: .e,
                        keyInput: { $1.addCellWithLines(with: $2) }
                    )
//                    Action(
//                        name: Localization(english: "Add & Clip Cell with Lines", japanese: "線からセルを追加&クリップ"),
//                        description: Localization(
//                            english: "Clip created cell into  indicated cell (If cell to clip is selected, include selected cells in other groups)",
//                            japanese: "生成したセルを指し示したセルにクリップ (クリップするセルが選択中の場合は他のグループにある選択セルも含む)"
//                        ),
//                        key: .r, keyInput: { $1.addAndClipCellWithLines(with: $2) }
//                    ),
//                    Action(
//                        name: Localization(english: "Lasso Delete", japanese: "囲み消し"),
////                        description: Localization(
////                            english: "Delete line, cell, or plane surrounded by last drawn line",
////                            japanese: "最後に引かれた線で囲まれた線やセル、平面を削除"
////                        ),
//                        quasimode: [.command], key: .d,
//                        keyInput: { $1.lassoDelete(with: $2) }
//                    ),
//                    Action(
//                        name: Localization(english: "Clip Cell in Selection", japanese: "選択の中へセルをクリップ"),
//                        description: Localization(
//                            english: "Clip indicated cell into selection, if no selection, unclip indicated cell",
//                            japanese:  "指し示したセルを選択の中へクリップ、選択がない場合は指し示したセルのクリップを解除"
//                        ),
//                        key: .g, keyInput: { $1.clipCellInSelection(with: $2) }
//                    )
                ]
            ),
            ActionNode(
                actions: [
                    //                    Action(
                    //                        name: Localization(english: "Move to Previous", japanese: "前へ移動"),
                    //                        key: .z, keyInput: { $1.moveToPrevious(with: $2) }
                    //                    ),
                    //                    Action(
                    //                        name: Localization(english: "Move to Next", japanese: "次へ移動"),
                    //                        key: .x, keyInput: { $1.moveToNext(with: $2) }
                    //                    ),
                    Action(
                        name: Localization(english: "Play", japanese: "再生"),
                        quasimode: [.command], key: .no3,
                        keyInput: { $1.play(with: $2) }
                    )
                ]
            ),
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "Hide", japanese: "隠す"),
                        quasimode: [.command], key: .no1,
                        keyInput: { $1.hide(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Show", japanese: "表示"),
                        quasimode: [.command], key: .no2,
                        keyInput: { $1.show(with: $2) }
                    )
                ]
            ),
//            ActionNode(
//                actions: [
//                    Action(
//                        name: Localization(english: "Change to Rough", japanese: "下描き化"),
//                        description: Localization(
//                            english: "If selecting line, move only that line to rough layer",
//                            japanese: "線を選択している場合、その線のみを下描き層に移動"
//                        ),
//                        key: .q, keyInput: { $1.changeToRough(with: $2) }
//                    ),
//                    Action(
//                        name: Localization(english: "Remove Rough", japanese: "下描きを削除"),
//                        key: .w, keyInput: { $1.removeRough(with: $2) }
//                    ),
//                    Action(
//                        name: Localization(english: "Swap Rough", japanese: "下描きと交換"),
//                        description: Localization(
//                            english: "Exchange with drawn line and line of rough layer",
//                            japanese: "引かれた線と下書き層の線を交換"
//                        ),
//                        key: .e, keyInput: { $1.swapRough(with: $2) }
//                    )
//                ]
//            ),
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "Add Edit Point", japanese: "編集点を追加"),
                        quasimode: [.control], key: .e,
                        keyInput: { $1.addPoint(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Remove Edit Point", japanese: "編集点を削除"),
                        quasimode: [.control], key: .d,
                        keyInput: { $1.deletePoint(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Move Edit Point", japanese: "編集点を移動"),
                        quasimode: [.control], editQuasimode: .movePoint,
                        drag: { $1.movePoint(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Move Vertex", japanese: "頂点を移動"),
                        quasimode: [.shift, .control], editQuasimode: .moveVertex,
                        drag: { $1.moveVertex(with: $2) }
                    )
                ]
            ),
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "Move", japanese: "移動"),
                        quasimode: [.command],
                        editQuasimode: .move, drag: { $1.move(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Move Z", japanese: "Z移動"),
                        quasimode: [.command, .option],
                        editQuasimode: .moveZ, drag: { $1.moveZ(with: $2) }
                    ),
                ]
            ),
            ActionNode(
                    actions: [
                    Action(
                        name: Localization(english: "Warp", japanese: "歪曲"),
                        quasimode: [.option],
                        editQuasimode: .warp, drag: { $1.warp(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Transform", japanese: "変形"),
                        quasimode: [.option, .shift],
                        editQuasimode: .transform, drag: { $1.transform(with: $2) }
                    )
                ]
            ),
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "Run", japanese: "実行"),
                        gesture: .click
                    ),
                    Action(
                        name: Localization(english: "Show Property", japanese: "プロパティを表示"),
                        gesture: .rightClick, drag: { $1.showProperty(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Trace", japanese: "なぞる"),
                        gesture: .drag, drag: { $1.drag(with: $2) }
                    ),
                    Action(
                        name: Localization(english: "Scroll", japanese: "スクロール"),
                        gesture: .scroll
                    ),
                    Action(
                        name: Localization(english: "Zoom", japanese: "ズーム"),
                        gesture: .pinch
                    ),
                    Action(
                        name: Localization(english: "Rotate", japanese: "回転"),
                        gesture: .rotate
                    ),
                    Action(
                        name: Localization(english: "Reset View", japanese: "表示をリセット"),
                        gesture: .doubleTap
                    )
                ]
            ),
            ActionNode(
                actions: [
                    Action(
                        name: Localization(english: "Look Up", japanese: "調べる"),
                        gesture: .tap
                    )
                ]
            )
        ]
    )
    
    var name: String, action: Action?, children: [ActionNode]
    private(set) var keyActions = [Action](), clickActions = [Action](), rightClickActions = [Action](), dragActions = [Action]()
    
    init(name: String = "", action: Action? = nil, children: [ActionNode] = []) {
        self.name = name
        self.action = action
        self.children = children
        updateActions()
    }
    init(actions: [Action]) {
        self.name = ""
        self.action = nil
        self.children = actions.map { ActionNode(action: $0) }
        updateActions()
    }
    mutating func updateActions() {
        children.forEach {
            keyActions += $0.keyActions
            clickActions += $0.clickActions
            rightClickActions += $0.rightClickActions
            dragActions += $0.dragActions
        }
        if let action = action {
            switch action.gesture {
            case .keyInput:
                keyActions.append(action)
            case .click:
                clickActions.append(action)
            case .rightClick:
                rightClickActions.append(action)
            case .drag:
                dragActions.append(action)
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
            return action(with: keyActions)
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

struct Action: Equatable {
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
        a = "A", s = "S", d = "D", f = "F", h = "H", g = "G",  z = "Z", x = "X", c = "C", v = "V", b = "B", q = "Q", w = "W",
        e = "E", r = "R", y = "Y", t = "T", no1 = "1", no2 = "2", no3 = "3", no4 = "4", no6 = "6", no5 = "5", equals = "=", no9 = "9",
        no7 = "7", minus = "-", no8 = "8", no0 = "0", rightBracket = "]", o = "O", u = "U", leftBracket = "[", i = "I", p = "P",
        `return` = "return", l = "L", j = "J", apostrophe = "`", k = "K", semicolon = ";", frontslash = "\\", comma = ",",
        backslash = "/", n = "N", m = "M", period = ".", tab = "tab", space = "space", backApostrophe = "^", delete = "delete",
        escape = "esc", command = "command", shiht = "shiht", option = "option", control = "control",
        up = "↑", down = "↓", left = "←", right = "→"
    }
    
    enum Gesture: UInt16 {
        case none, keyInput, moveCursor, click, rightClick, drag, scroll, pinch, rotate, tap, doubleTap
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
    
    var name: Localization, description: Localization, quasimode: Quasimode, key: Key?, gesture: Gesture
    var keyInput: ((_ sender: Respondable, _ getter: Respondable, _ event: KeyInputEvent) -> Void)?
    var editQuasimode: EditQuasimode
    var drag: ((_ sender: Respondable, _ getter: Respondable, _ event: DragEvent) -> Void)?
    
    init(
        name: Localization = Localization(), description: Localization = Localization(),
        quasimode: Quasimode = [], key: Key? = nil, gesture: Gesture = .keyInput,
        keyInput: ((_ sender: Respondable, _ getter: Respondable, _ event: KeyInputEvent) -> Void)? = nil,
        editQuasimode: EditQuasimode = .none,
        drag: ((_ sender: Respondable, _ getter: Respondable, _ event: DragEvent) -> Void)? = nil
    ) {
        self.name = name
        self.description = description
        self.quasimode = quasimode
        self.key = key
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
        self.editQuasimode = editQuasimode
        self.drag = drag
    }
    
    var displayCommandString: Localization {
        var displayString = Localization(quasimode.displayString)
        if let keyDisplayString = key?.rawValue {
            displayString += Localization(displayString.isEmpty ? keyDisplayString : " " + keyDisplayString)
        }
        let gestureDisplayString = gesture.displayString
        if !gestureDisplayString.isEmpty {
            displayString += displayString.isEmpty ? gestureDisplayString : Localization(" ") + gestureDisplayString
        }
        return displayString
    }
    
    func canTextKeyInput() -> Bool {
        return key != nil && !quasimode.contains(.command)
    }
    
    static func == (lhs: Action, rhs: Action) -> Bool {
        return lhs.name == rhs.name
    }
    
    func canSend(with event: Event) -> Bool {
        func contains(with quasimode: Action.Quasimode) -> Bool {
            let flipQuasimode = quasimode.symmetricDifference([.shift, .command, .control, .option])
            return event.quasimode.contains(quasimode) && event.quasimode.intersection(flipQuasimode) == []
        }
        if let key = key {
            return event.key == key && contains(with: quasimode)
        } else {
            return contains(with: quasimode)
        }
    }
}

final class ActionEditor: LayerRespondable {
    static let name = Localization(english: "Action Editor", japanese: "アクションエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    let layer = CALayer.interfaceLayer(borderColor: .border)
    
    init() {
        let caf = ActionEditor.childrenAndFrameWith(
            actionNode: actionNode, actionNodeWidth: actionNodeWidth, padding: padding,
            commandFont: commandFont, commandColor: commandColor, commandPadding: commandPadding,
            backgroundColor: backgroundColor
        )
        self.children = caf.children
        update(withChildren: children, oldChildren: [])
        self.frame.size = caf.size
    }
    
    var defaultBorderColor: CGColor? = Color.border.cgColor
    
    var textEditors = [Label]()
    var actionNodeWidth = 180.0.cf, padding = Layout.basicPadding, commandPadding = 10.0.cf
    var commandFont = Font.action, commandColor = Color.locked, backgroundColor = Color.background
    var actionNode = ActionNode.default {
        didSet {
            let caf = ActionEditor.childrenAndFrameWith(
                actionNode: actionNode, actionNodeWidth: actionNodeWidth, padding: padding,
                commandFont: commandFont, commandColor: commandColor, commandPadding: commandPadding,
                backgroundColor: backgroundColor
            )
            CATransaction.disableAnimation {
                self.children = caf.children
                self.frame.size = caf.size
            }
        }
    }
    static func childrenAndFrameWith(
        actionNode: ActionNode, actionNodeWidth: CGFloat, padding: CGFloat,
        commandFont: Font, commandColor: Color, commandPadding: CGFloat, backgroundColor: Color
    ) -> (children: [LayerRespondable], size: CGSize) {
        var y = 0.0.cf
        let commandHeight = commandFont.size + commandPadding
        let actionLabel = Label(
            text: Localization(english: "Action", japanese: "アクション"),
            font: .small, color: .locked, paddingWidth: 0
        )
        let allHeight = actionNode.children.reduce(0.0.cf) { $0 + commandHeight*$1.children.count.cf + padding * 2 } - padding
        actionLabel.frame.origin = CGPoint(
            x: round((actionNodeWidth + padding * 2 - actionLabel.frame.width) / 2),
            y: allHeight + padding * 2
        )
        y = allHeight + padding
        let children: [LayerRespondable] = [actionLabel] + actionNode.children.map {
            let actionsHeight = commandHeight*$0.children.count.cf + padding * 2
            var actionsY = actionsHeight - padding
            let actionsChildren: [Respondable] = $0.children.flatMap {
                guard let action = $0.action else {
                    return nil
                }
                actionsY -= commandHeight
                return ActionItem(
                    action: action, frame: CGRect(x: padding, y: actionsY, width: actionNodeWidth - padding * 2, height: commandHeight),
                    actionFont: commandFont, actionFontColor: commandColor
                )
            }
            let groupHeight = y - actionsHeight
            y -= actionsHeight
            return GroupResponder(
                layer: CALayer.interfaceLayer(), children: actionsChildren,
                frame: CGRect(x: padding, y: groupHeight, width: actionNodeWidth, height: actionsHeight)
            )
        }
        return (children, CGSize(width: actionNodeWidth + padding*2, height: allHeight + actionLabel.frame.height + padding*3))
    }
    
    func actionItems(with quasimode: Action.Quasimode) -> [ActionItem] {
        var actionItems = [ActionItem]()
        allChildren {
            if let actionItem = $0 as? ActionItem {
                if actionItem.action.quasimode == quasimode {
                    actionItems.append(actionItem)
                }
            }
        }
        return actionItems
    }
    func actionItems(with action: Action) -> [ActionItem] {
        var actionItems = [ActionItem]()
        allChildren {
            if let actionItem = $0 as? ActionItem {
                if actionItem.action == action {
                    actionItems.append(actionItem)
                }
            }
        }
        return actionItems
    }
}
final class ActionItem: LayerRespondable, Localizable {
    static let name = Localization(english: "Action Item", japanese: "アクションアイテム")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    var action: Action
    
    var locale = Locale.current {
        didSet {
            CATransaction.disableAnimation {
                let cw = ceil(commandLabel.textLine.stringBounds.width) + nameLabel.textLine.paddingSize.width*2
                commandLabel.frame = CGRect(x: nameLabel.bounds.width - cw, y: 0, width: cw, height: nameLabel.bounds.height)
            }
        }
    }
    var layer = CALayer.interfaceLayer(backgroundColor: .background)
    var nameLabel: Label, commandLabel: Label
    init(action: Action, frame: CGRect, actionFont: Font, actionFontColor: Color) {
        self.action = action
        let tv = Label(
            frame: CGRect(origin: CGPoint(), size: frame.size),
            text: action.name,
            textLine: TextLine(string: action.name.currentString, color: actionFontColor, isVerticalCenter: true),
            description: action.description
        )
        let cv = Label(
            text: action.displayCommandString,
            textLine: TextLine(string: action.displayCommandString.currentString, font: actionFont, color: actionFontColor, alignment: .right),
            backgroundColor: .background
        )
        self.nameLabel = tv
        self.commandLabel = cv
        let cw = ceil(cv.textLine.stringBounds.width) + tv.textLine.paddingSize.width*2
        cv.frame = CGRect(x: tv.bounds.width - cw, y: 0, width: cw, height: tv.bounds.height)
        layer.frame = frame
        
        tv.children = [cv]
        self.children = [tv]
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
    let sendType: Action.SendType, location: CGPoint, time: Double, quasimode: Action.Quasimode, key: Action.Key?
}
struct DragEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double, quasimode: Action.Quasimode, key: Action.Key?
    let pressure: CGFloat
}
struct ScrollEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double, quasimode: Action.Quasimode, key: Action.Key?
    let scrollDeltaPoint: CGPoint, scrollMomentumType: Action.SendType?
}
struct PinchEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double, quasimode: Action.Quasimode, key: Action.Key?
    let magnification: CGFloat
}
struct RotateEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double, quasimode: Action.Quasimode, key: Action.Key?
    let rotation: CGFloat
}
struct TapEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double, quasimode: Action.Quasimode, key: Action.Key?
}
struct DoubleTapEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double, quasimode: Action.Quasimode, key: Action.Key?
}
struct KeyInputEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Double, quasimode: Action.Quasimode, key: Action.Key?
    func with(sendType: Action.SendType) -> KeyInputEvent {
        return KeyInputEvent(sendType: sendType, location: location, time: time, quasimode: quasimode, key: key)
    }
}
