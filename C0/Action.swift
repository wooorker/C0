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
//コマンドハイライト、無効コマンドの編集無効表示
//表示範囲内でのコマンド適用
//ショートカットキー変更可能化
//頻度の少ないコマンドをボタンまたはプルダウンボタン化
//コマンドのモードレス性の向上（コピー・ペースト対応の範囲を拡大など）

import Foundation
import QuartzCore
import AppKit.NSFont

struct ActionNode {
    static var `default`: ActionNode {
        return ActionNode(children: [
            ActionNode(actions: [
                Action(name: "Undo".localized, quasimode: [.command], key: .z, keyInput: { $0.undo() }),
                Action(name: "Redo".localized, quasimode: [.shift, .command], key: .z, keyInput: { $0.redo() })
                ]),
            ActionNode(actions: [
                Action(name: "Cut".localized, quasimode: [.command], key: .x, keyInput: { $0.cut() }),
                Action(name: "Copy".localized, quasimode: [.command], key: .c, keyInput: { $0.copy() }),
                Action(name: "Paste".localized, description:
                    "If cell, replace line of cell with same ID with line of paste cell".localized,
                       quasimode: [.command], key: .v, keyInput: { $0.paste() }),
                Action(name: "Delete".localized, description:
                    "If slider, Initialize value, if canvas, delete line preferentially".localized,
                       key: .delete, keyInput: { $0.delete() })
                ]),
            ActionNode(actions: [
                Action(name: "Move to Previous Keyframe".localized, key: .z, keyInput: { $0.moveToPrevious() }),
                Action(name: "Move to Next Keyframe".localized, key: .x, keyInput: { $0.moveToNext() }),
                Action(name: "Play".localized, key: .space, keyInput: { $0.play() })
                ]),
            ActionNode(actions: [
                Action(name: "Paste Material".localized, description:
                    "Paste material into indicated cell".localized,
                       key: .v, keyInput: { $0.pasteMaterial() }),
                Action(name: "Paste cell without connect".localized, description:
                    "Completely replicate and paste copied cells".localized,
                       quasimode: [.shift], key: .v, keyInput: { $0.pasteCell() })
                ]),
            ActionNode(actions: [
                Action(name: "Split Color".localized, description:
                    "Distribute ID of color of indicated cell newly (maintain ID relationship within same selection)".localized,
                       key: .b, keyInput: { $0.splitColor() }),
                Action(name: "Split Other Than Color".localized, description:
                    "Distribute ID of material of indicated cell without changing color ID (Maintain ID relationship within same selection)".localized,
                       quasimode: [.shift], key: .b, keyInput: { $0.splitOtherThanColor() })
                ]),
            ActionNode(actions: [
                Action(name: "Add Cell with Lines".localized, description:
                    "".localized,
                       key: .a, keyInput: { $0.addCellWithLines() }),
                Action(name: "Add & Clip Cell with Lines".localized, description:
                    "Clip created cell into  indicated cell (If cell to clip is selected, include selected cells in other groups)".localized,
                       key: .r, keyInput: { $0.addAndClipCellWithLines() }),
                Action(name: "Lasso Select".localized, description:
                    "Select line or cell surrounded by last drawn line".localized,
                       key: .s, keyInput: { $0.lassoSelect() } ),
                Action(name: "Lasso Delete".localized, description:
                    "Delete line or cell or plane surrounded by last drawn line".localized,
                       key: .d, keyInput: { $0.lassoDelete() }),
                Action(name: "Lasso Delete Selection".localized, description:
                    "Delete selection of line or cell surrounded by last drawn line".localized,
                       key: .f, keyInput: { $0.lassoDeleteSelect() }),
                Action(name: "Clip Cell in Selection".localized, description:
                    "Clip indicated cell into selection, if no selection, unclip indicated cell".localized,
                       key: .g, keyInput: { $0.clipCellInSelection() }),
                ]),
            ActionNode(actions: [
                Action(name: "Hide".localized, description:
                    "If canvas, Semitransparent display & invalidation judgment of indicated cell, if timeline, hide edit group".localized,
                       key: .h, keyInput: { $0.hide() }),
                Action(name: "Show".localized, description:
                    "If canvas, show all cells, if timeline, show edit group".localized,
                       key: .j, keyInput: { $0.show() }),
                ]),
            ActionNode(actions: [
                Action(name: "Change to Rough".localized, description:
                    "If selecting line, move only that line to rough layer".localized,
                       key: .q, keyInput: { $0.changeToRough() }),
                Action(name: "Remove Rough".localized, key: .w, keyInput: { $0.removeRough() }),
                Action(name: "Swap Rough".localized, description:
                    "Exchange with drawn line and line of rough layer".localized,
                       key: .e, keyInput: { $0.swapRough() })
                ]),
            ActionNode(actions: [
                Action(name: "Add Line Point".localized, description:
                    "".localized,
                       quasimode: [.shift], key: .a, keyInput: { $0.addPoint() }),
                Action(name: "Remove Line Point".localized, description:
                    "".localized,
                       quasimode: [.shift], key: .d, keyInput: { $0.deletePoint() }),
                Action(name: "Move Line Point".localized, description:
                    "".localized,
                       quasimode: [.shift],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .movePoint : .none }, drag: { $0.movePoint(with: $1) }),
                Action(name: "Warp Line".localized, description:
                    "Warp indicated cell by dragging".localized,
                       quasimode: [.shift, .option],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .warp : .none }, drag: { $0.warpLine(with: $1) }),
                Action(name: "Snap Line Point".localized, description:
                    "".localized,
                       quasimode: [.shift, .control],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .snapPoint : .none }, drag: { $0.snapPoint(with: $1) })
                ]),
            ActionNode(actions: [
                Action(name: "Move Z".localized, description:
                    "Change overlapping order of indicated cells by up and down drag".localized,
                       quasimode: [.option],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .moveZ : .none }, drag: { $0.moveZ(with: $1) }),
                Action(name: "Move".localized, description:
                    "If canvas, move indicated cell by dragging, if timeline, change group order by up and down dragging".localized,
                       quasimode: [.control],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .move : .none }, drag: { $0.move(with: $1) }),
                Action(name: "Transform".localized, description:
                    "Transform indicated cell with selected property by dragging".localized,
                       quasimode: [.control, .option],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .transform : .none }, drag: { $0.transform(with: $1) }),
                Action(name: "Rotate Transform".localized, description:
                    "".localized,
                       quasimode: [.shift, .control, .option],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .rotate : .none }, drag: { $0.rotateTransform(with: $1) })
                ]),
            //            ActionNode(actions: [
            //                Action(name: "Slow".localized, description:
            //                    "If canvas, decrease of stroke control point, if color picker, decrease drag speed".localized,
            //                       quasimode: [.command], drag: { $0.slowDrag(with: $1) })
            //                ]),
            ActionNode(actions: [
                Action(name: "Scroll".localized, description:
                    "If canvas, move XY, if timeline, selection time with left and right scroll, selection group with up and down scroll".localized,
                       gesture: .scroll),
                Action(name: "Zoom".localized, description:
                    "If canvas, Zoom in/ out, if timeline, change frame size".localized,
                       gesture: .pinch),
                Action(name: "Rotate".localized, description:
                    "Canvas only".localized,
                       gesture: .rotate),
                Action(name: "Reset View".localized, description: "Initialize changed display by gesture other than time and group selection".localized,
                       gesture: .doubleTap)
                ]),
            ActionNode(actions: [
                Action(name: "Look Up".localized, gesture: .tap)
                ]),
            ])
    }
    
    var name: String, action: Action?, children: [ActionNode]
    private(set) var keyActions = [Action](), clickActions = [Action](), rightClickActions = [Action](), dragActions = [Action]()
    
    init(name: String = "", action: Action? = nil, children: [ActionNode] = []) {
        self.name = name
        self.action = action
        self.children = children
        updateActions()
    }
    init(actions: [Action]) {
        name = ""
        action = nil
        children = actions.map { ActionNode(action: $0) }
        updateActions()
    }
    
    mutating func updateActions() {
        for child in children {
            keyActions += child.keyActions
            clickActions += child.clickActions
            rightClickActions += child.rightClickActions
            dragActions += child.dragActions
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
}

struct Action: Equatable {
    struct Quasimode: OptionSet {
        var rawValue: Int32
        static let shift = Quasimode(rawValue: 1), command = Quasimode(rawValue: 2)
        static let control = Quasimode(rawValue:4), option = Quasimode(rawValue: 8)
        
        var displayString: String {
            var string = intersection(.option) != [] ? "option" : ""
            if intersection(.control) != [] {
                string += string.isEmpty ? "control" : " control"
            }
            if intersection(.shift) != [] {
                string += string.isEmpty ? "shift" : " shift"
            }
            if intersection(.command) != [] {
                string += string.isEmpty ? "command" : " command"
            }
            return string
        }
    }
    
    struct Key {
        let code: UInt16, string: String
        static let
        a = Key(code: 0, string: "A"), s = Key(code: 1, string: "S"), d = Key(code: 2, string: "D"), f = Key(code: 3, string: "F"),
        h = Key(code: 4, string: "H"), g = Key(code: 5, string: "G"),  z = Key(code: 6, string: "Z"), x = Key(code: 7, string: "X"),
        c = Key(code: 8, string: "C"), v = Key(code: 9, string: "V"), b = Key(code: 11, string: "B"),
        q = Key(code: 12, string: "Q"), w = Key(code: 13, string: "W"), e = Key(code: 14, string: "E"), r = Key(code: 15, string: "R"),
        y = Key(code: 16, string: "Y"), t = Key(code: 17, string: "t"), num1 = Key(code: 18, string: "1"), num2 = Key(code: 19, string: "2"),
        num3 = Key(code: 20, string: "3"), num4 = Key(code: 21, string: "4"), num6 = Key(code: 22, string: "6"), num5 = Key(code: 23, string: "5"),
        equals = Key(code: 24, string: "="), num9 = Key(code: 25, string: "9"), num7 = Key(code: 26, string: "7"), minus = Key(code: 27, string: "-"),
        num8 = Key(code: 28, string: "8"), num0 = Key(code: 29, string: "0"), rightBracket = Key(code: 30, string: "]"), o = Key(code: 31, string: "O"),
        u = Key(code: 32, string: "U"), leftBracket = Key(code: 33, string: "["), i = Key(code: 34, string: "I"), p = Key(code: 35, string: "P"),
        `return` = Key(code: 36, string: "return"), l = Key(code: 37, string: "L"), j = Key(code: 38, string: "J"), apostrophe = Key(code: 39, string: "`"),
        k = Key(code: 40, string: "K"), semicolon = Key(code: 41, string: ";"), frontslash = Key(code: 42, string: "\\"), comma = Key(code: 43, string: ","),
        backslash = Key(code: 44, string: "/"), n = Key(code: 45, string: "N"), m = Key(code: 46, string: "M"), period = Key(code: 47, string: "."),
        tab = Key(code: 48, string: "tab"), space = Key(code: 49, string: "space"), backApostrophe = Key(code: 50, string: "^"), delete = Key(code: 51, string: "delete"),
        escape = Key(code: 53, string: "esc"), command = Key(code: 55, string: "command"),
        shiht = Key(code: 56, string: "shiht"), option = Key(code: 58, string: "option"), control = Key(code: 59, string: "control"),
        up = Key(code: 126, string: "↑"), down = Key(code: 125, string: "↓"), left = Key(code: 123, string: "←"), right = Key(code: 124, string: "→")
    }
    
    enum Gesture: UInt16 {
        case keyInput, click, rightClick, drag, scroll, pinch, rotate, tap, doubleTap
        var displayString: String {
            switch self {
            case .keyInput, .drag:
                return ""
            case .click:
                return "Tap".localized
            case .rightClick:
                return "Two Finger Tap".localized
            case .scroll:
                return "Two Finger Drag".localized
            case .pinch:
                return "Two Finger Pinch".localized
            case .rotate:
                return "Two Finger Rotate".localized
            case .tap:
                return "\"Look up\" Gesture".localized
            case .doubleTap:
                return "Two Finger Double Tap".localized
            }
        }
    }
    
    var name: String, description: String, quasimode: Quasimode, key: Key?, gesture: Gesture
    var keyInput: ((View) -> Void)?, changeQuasimode: ((View, Bool) -> Void)?, drag: ((View, DragEvent) -> Void)?
    
    init(name: String = "", description: String = "", quasimode: Quasimode = [], key: Key? = nil, gesture: Gesture = .keyInput,
         keyInput: ((View) -> Void)? = nil, changeQuasimode: ((View, Bool) -> Void)? = nil, drag: ((View, DragEvent) -> Void)? = nil) {
        self.name = name
        self.description = description
        self.quasimode = quasimode
        self.key = key
        if keyInput != nil {
            self.gesture = .keyInput
        } else if drag != nil {
            self.gesture = .drag
        } else {
            self.gesture = gesture
        }
        self.keyInput = keyInput
        self.changeQuasimode = changeQuasimode
        self.drag = drag
    }
    
    var displayCommandString: String {
        var displayString = quasimode.displayString
        if let keyDisplayString = key?.string {
            displayString += displayString.isEmpty ? keyDisplayString : " " + keyDisplayString
        }
        if !gesture.displayString.isEmpty {
            displayString += displayString.isEmpty ? gesture.displayString : " " + gesture.displayString
        }
        return displayString
    }
    
    func canTextKeyInput() -> Bool {
        return key != nil && !quasimode.contains(.command)
    }
    
    static func == (lhs: Action, rhs: Action) -> Bool {
        return lhs.name == rhs.name
    }
}

final class ActionEditor: View {
    var textEditors = [StringView]()
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
                    let actionsItem = View()
                    actionsItem.frame = CGRect(x: 0, y: y, width: actionNodeWidth, height: h)
                    makeTextEditor(actionNode: $0, backgroundColor: backgroundColor, in: actionsItem)
                    return actionsItem
                }
                self.children = children
                frame.size = CGSize(width: actionNodeWidth, height: height)
            }
        }
    }
    private func makeTextEditor(actionNode: ActionNode, backgroundColor: CGColor, in actionsItem: View) {
        var y = actionsItem.frame.height - commandPadding/2
        actionsItem.layer.backgroundColor = backgroundColor
        let children: [View] = actionNode.children.flatMap {
            let h = commandFont.pointSize + commandPadding
            y -= h
            if let action = $0.action {
                let tv = StringView(frame: CGRect(x: 0, y: y, width: actionNodeWidth, height: h), textLine: TextLine(string: action.name, color: commandColor.cgColor, isVerticalCenter: true))
                if !action.description.isEmpty {
                    tv.description =  action.description
                }
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
        actionsItem.children = children
    }
}

protocol Event {
    var locationInWindow: CGPoint { get }
    var time: TimeInterval { get }
}
struct MoveEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
}
struct DragEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    let pressure: CGFloat
}
struct ScrollEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    let scrollDeltaPoint: CGPoint, scrollMomentum: NSEventPhase
}
struct PinchEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    let magnification: CGFloat
}
struct RotateEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    let rotation: CGFloat
}
