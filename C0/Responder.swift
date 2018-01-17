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

protocol Undoable {
    var undoManager: UndoManager? { get }
    var registeringUndoManager: UndoManager? { get }
    var disabledRegisterUndo: Bool { get }
    func undo() -> Bool
    func redo() -> Bool
}
extension Undoable {
    var undoManager: UndoManager? {
        return nil
    }
    var registeringUndoManager: UndoManager? {
        return disabledRegisterUndo ? nil : undoManager
    }
    var disabledRegisterUndo: Bool {
        return false
    }
    func undo() -> Bool {
        guard let undoManger = registeringUndoManager else {
            return false
        }
        if undoManger.canUndo {
            undoManger.undo()
            return true
        } else {
            return false
        }
    }
    func redo() -> Bool {
        guard let undoManger = registeringUndoManager else {
            return false
        }
        if undoManger.canRedo {
            undoManger.redo()
            return true
        } else {
            return false
        }
    }
}

protocol Editable {
    func copy(with event: KeyInputEvent) -> CopiedObject?
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool
    func delete(with event: KeyInputEvent) -> Bool
    func new(with event: KeyInputEvent) -> Bool
    func moveCursor(with event: MoveEvent) -> Bool
    func keyInput(with event: KeyInputEvent) -> Bool
    func run(with event: ClickEvent) -> Bool
    func bind(with event: RightClickEvent) -> Bool
    func lookUp(with event: TapEvent) -> Referenceable?
}
extension Editable {
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return nil
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        return false
    }
    func new(with event: KeyInputEvent) -> Bool {
        return false
    }
    func moveCursor(with event: MoveEvent) -> Bool {
        return false
    }
    func keyInput(with event: KeyInputEvent) -> Bool {
        return false
    }
    func run(with event: ClickEvent) -> Bool {
        return false
    }
    func bind(with event: RightClickEvent) -> Bool {
        return false
    }
    func lookUp(with event: TapEvent) -> Referenceable? {
        return nil
    }
}

protocol Selectable {
    func select(with event: DragEvent) -> Bool
    func deselect(with event: DragEvent) -> Bool
    func selectAll(with event: KeyInputEvent) -> Bool
    func deselectAll(with event: KeyInputEvent) -> Bool
}
extension Selectable {
    func select(with event: DragEvent) -> Bool {
        return false
    }
    func deselect(with event: DragEvent) -> Bool {
        return false
    }
    func selectAll(with event: KeyInputEvent) -> Bool {
        return false
    }
    func deselectAll(with event: KeyInputEvent) -> Bool {
        return false
    }
}

protocol Transformable {
    func move(with event: DragEvent) -> Bool
    func moveZ(with event: DragEvent) -> Bool
    func warp(with event: DragEvent) -> Bool
    func transform(with event: DragEvent) -> Bool
}
extension Transformable {
    func move(with event: DragEvent) -> Bool {
        return false
    }
    func moveZ(with event: DragEvent) -> Bool {
        return false
    }
    func warp(with event: DragEvent) -> Bool {
        return false
    }
    func transform(with event: DragEvent) -> Bool {
        return false
    }
}

protocol ViewEditable {
    func scroll(with event: ScrollEvent) -> Bool
    func zoom(with event: PinchEvent) -> Bool
    func rotate(with event: RotateEvent) -> Bool
    func resetView(with event: DoubleTapEvent) -> Bool
}
extension ViewEditable {
    func scroll(with event: ScrollEvent) -> Bool {
        return false
    }
    func zoom(with event: PinchEvent) -> Bool {
        return false
    }
    func rotate(with event: RotateEvent) -> Bool {
        return false
    }
    func resetView(with event: DoubleTapEvent) -> Bool {
        return false
    }
}

protocol Strokable {
    func stroke(with event: DragEvent) -> Bool
    func lassoErase(with event: DragEvent) -> Bool
    func moveInStrokable(with event: DragEvent) -> Bool
}
extension Strokable {
    func stroke(with event: DragEvent) -> Bool {
        return false
    }
    func lassoErase(with event: DragEvent) -> Bool {
        return false
    }
    func moveInStrokable(with event: DragEvent) -> Bool {
        return false
    }
}

protocol PointEditable {
    func insertPoint(with event: KeyInputEvent) -> Bool
    func removePoint(with event: KeyInputEvent) -> Bool
    func movePoint(with event: DragEvent) -> Bool
    func moveVertex(with event: DragEvent) -> Bool
}
extension PointEditable {
    func insertPoint(with event: KeyInputEvent) -> Bool {
        return false
    }
    func removePoint(with event: KeyInputEvent) -> Bool {
        return false
    }
    func movePoint(with event: DragEvent) -> Bool {
        return false
    }
    func moveVertex(with event: DragEvent) -> Bool {
        return false
    }
}

enum EditQuasimode {
    case select, deselect, move, moveZ, transform, warp, movePoint, moveVertex, stroke, lassoErase
}

/**
 # Issue
 - コピー・ペーストなどのアクション対応を拡大
 - Eventを使用しないアクション設計
 */
protocol Respondable: class, Referenceable, Undoable, Editable, Selectable,
PointEditable, Transformable, ViewEditable, Strokable {
    var isIndicated: Bool { get set }
    var isSubIndicated: Bool  { get set }
    var dataModel: DataModel? { get set }
    var editQuasimode: EditQuasimode { get set }
    var cursor: Cursor { get }
    var cursorPoint: CGPoint { get }
}
extension Respondable {
    var cursor: Cursor {
        return .arrow
    }
    func lookUp(with event: TapEvent) -> Referenceable? {
        return self
    }
}

final class Responder: Layer, Respondable {
    static let name = Localization(english: "Responder", japanese: "レスポンダ")
}
