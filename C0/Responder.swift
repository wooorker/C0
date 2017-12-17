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

/*
 ## 0.3
 * セルと線を再設計
 * 線の描画を改善
 * 線の分割を改善
 * 点の追加、点の削除、点の移動と線の変形、スナップを再設計
 * 線端の傾きスナップ実装
 * セルの追加時の線の置き換え、編集セルを廃止
 * マテリアルのコピーによるバインドを廃止
 * 変形、歪曲の再設計
 * コマンドを整理
 * コピー表示、取り消し表示
 * シーン設定
 * 書き出し表示修正
 * プロパティのポップアップ表示
 * すべてのインディケーション表示
 * マテリアルの合成機能修正
 * Display P3サポート
 * キーフレームラベルの導入
 * キャンバス上でのスクロール時間移動
 * キャンバスの選択修正、「すべてを選択」「すべてを選択解除」アクションを追加
 * インディケーション再生
 * テキスト設計やGUIの基礎設計を修正
 * キーフレームの複数選択に対応
 * Swift4 (Codableを部分的に導入)
 * サウンドの書き出し
 △ ビートタイムライン
 △ ノード導入
 △ Z移動の修正
 △ セルのコピー、分割、表示設定の修正
 △ カット単位での読み込み、保存
 △ マテリアルアニメーション
 △ セル補間選択
 △ スナップスクロール
 △ ストローク修正、スローの廃止
 △ リファレンス表示の具体化
 
 ## 0.4
 X MetalによるGPUレンダリング（リニアワークフロー、マクロ拡散光）
 
 ## 1.0
 X 安定版
 
 # Issue
 SliderなどのUndo実装
 DelegateをClosureに変更
 カプセル化（var sceneEditor!の排除）
 0秒キーフレーム
 モードレス文字入力、字幕
 コピー・ペーストなどのアクション対応を拡大
 スクロールの可視性の改善 (元の位置までの距離などを表示)
 複数のサウンド
 (with: event)のない、protocolによるモードレスアクション
 NodeTrackのItemのイミュータブル化
 コピーオブジェクトの自由な貼り付け
 コピーの階層化
 QuartzCore, CoreGraphics廃止
 トラックパッドの環境設定を無効化または表示反映
 バージョン管理UndoManager
 様々なメディアファイルに対応
 ファイルシステムのモードレス化
 効果音編集
 シーケンサー
 */

import Foundation
import QuartzCore

enum EditQuasimode {
    case none, movePoint, moveVertex, move, moveZ, warp, transform, select, deselect, lassoDelete
}

protocol Localizable: class {
    var locale: Locale { get set }
}

protocol Undoable {
    var undoManager: UndoManager? { get set }
}
protocol Editable {
    func copy(with event: KeyInputEvent) -> CopiedObject
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent)
    func delete(with event: KeyInputEvent)
    func new(with event: KeyInputEvent)
}
protocol Selectable {
    func select(with event: DragEvent)
    func deselect(with event: DragEvent)
    func selectAll(with event: KeyInputEvent)
    func deselectAll(with event: KeyInputEvent)
}
protocol PointEditable {
    func addPoint(with event: KeyInputEvent)
    func deletePoint(with event: KeyInputEvent)
    func movePoint(with event: DragEvent)
}

protocol Respondable: class, Referenceable, Undoable, Editable, Selectable, PointEditable {
    weak var parent: Respondable? { get set }
    var children: [Respondable] { get set }
    func update(withChildren children: [Respondable], oldChildren: [Respondable])
    func removeFromParent()
    func allChildren(_ handler: (Respondable) -> Void)
    func allParents(handler: (Respondable) -> Void)
    var rootRespondable: Respondable { get }
    
    var dataModel: DataModel? { get set }
    
    func set(_ editQuasimode: EditQuasimode, with event: Event)
    var editQuasimode: EditQuasimode { get set }
    var cursor: Cursor { get }
    var contentsScale: CGFloat { get set }
    var defaultBorderColor: CGColor? { get }
    
    var frame: CGRect { get set }
    var bounds: CGRect { get set }
    var editBounds: CGRect { get }
    func contains(_ p: CGPoint) -> Bool
    func at(_ point: CGPoint) -> Respondable?
    func point(from event: Event) -> CGPoint
    func convert(_ point: CGPoint, from responder: Respondable?) -> CGPoint
    func convert(_ point: CGPoint, to responder: Respondable?) -> CGPoint
    func convert(_ rect: CGRect, from responder: Respondable?) -> CGRect
    func convert(_ rect: CGRect, to responder: Respondable?) -> CGRect
    
    var isIndication: Bool { get set }
    var isSubIndication: Bool { get set }
    weak var indicationParent: Respondable? { get set }
    func allIndicationParents(handler: (Respondable) -> Void)
    
    func moveVertex(with event: DragEvent)
    func snapPoint(with event: DragEvent)
    func moveZ(with event: DragEvent)
    func move(with event: DragEvent)
    func warp(with event: DragEvent)
    func transform(with event: DragEvent)
    func moveCursor(with event: MoveEvent)
    func keyInput(with event: KeyInputEvent)
    func click(with event: ClickEvent)
    func showProperty(with event: RightClickEvent)
    func drag(with event: DragEvent)
    func scroll(with event: ScrollEvent)
    func zoom(with event: PinchEvent)
    func rotate(with event: RotateEvent)
    func reset(with event: DoubleTapEvent)
    func lookUp(with event: TapEvent) -> Referenceable
    
    func lassoDelete(with event: DragEvent)
    func clipCellInSelection(with event: KeyInputEvent)
}
extension Respondable {
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs === rhs
    }
    
    var dataModel: DataModel? {
        get {
            return nil
        }
        set {
            children.forEach { $0.dataModel = newValue }
        }
    }
    
    func allChildren(_ handler: (Respondable) -> Void) {
        func allChildrenRecursion(_ responder: Respondable, _ handler: (Respondable) -> Void) {
            responder.children.forEach { allChildrenRecursion($0, handler) }
            handler(responder)
        }
        allChildrenRecursion(self, handler)
    }
    func allParents(handler: (Respondable) -> Void) {
        handler(self)
        parent?.allParents(handler: handler)
    }
    var rootRespondable: Respondable {
        return parent?.rootRespondable ?? self
    }
    func update(withChildren children: [Respondable], oldChildren: [Respondable]) {
        oldChildren.forEach { responder in
            if !children.contains(where: { $0 === responder }) {
                responder.removeFromParent()
            }
        }
        children.forEach { $0.parent = self }
        allChildren { $0.dataModel = dataModel }
    }
    func removeFromParent() {
        guard let parent = parent else {
            return
        }
        if let index = parent.children.index(where: { $0 === self }) {
            parent.children.remove(at: index)
        }
        self.parent = nil
    }
    
    func set(_ editQuasimode: EditQuasimode, with event: Event) {
    }
    var editQuasimode: EditQuasimode {
        get {
            return .none
        }
        set {
        }
    }
    var cursor: Cursor {
        return Cursor.arrow
    }
    
    var contentsScale: CGFloat {
        get {
            return 1
        }
        set {
        }
    }
    var defaultBorderColor: CGColor? {
        return nil
    }
    
    func contains(_ p: CGPoint) -> Bool {
        return bounds.contains(p)
    }
    func at(_ point: CGPoint) -> Respondable? {
        guard contains(point) else {
            return nil
        }
        for child in children.reversed() {
            let inPoint = child.convert(point, from: self)
            if let responder = child.at(inPoint) {
                return responder
            }
        }
        return self
    }
    func point(from event: Event) -> CGPoint {
        return convert(event.location, from: nil)
    }
    func convert(_ point: CGPoint, from responder: Respondable?) -> CGPoint {
        guard self !== responder else {
            return point
        }
        let result = responder?.convertToRoot(point, stop: self) ?? (point: point, isRoot: true)
        return !result.isRoot ?
            result.point : result.point - convertToRoot(CGPoint(), stop: nil).point
    }
    func convert(_ point: CGPoint, to responder: Respondable?) -> CGPoint {
        guard self !== responder else {
            return point
        }
        let result = convertToRoot(point, stop: responder)
        if !result.isRoot {
            return result.point
        } else if let responder = responder {
            return result.point - responder.convertToRoot(CGPoint(), stop: nil).point
        } else {
            return result.point
        }
    }
    private func convertToRoot(_ point: CGPoint,
                               stop responder: Respondable?) -> (point: CGPoint, isRoot: Bool) {
        if let parent = parent {
            let parentPoint = point - bounds.origin + frame.origin
            return parent === responder ?
                (parentPoint, false) : parent.convertToRoot(parentPoint, stop: responder)
        } else {
            return (point, true)
        }
    }
    func convert(_ rect: CGRect, from responder: Respondable?) -> CGRect {
        return CGRect(origin: convert(rect.origin, from: responder), size: rect.size)
    }
    func convert(_ rect: CGRect, to responder: Respondable?) -> CGRect {
        return CGRect(origin: convert(rect.origin, to: responder), size: rect.size)
    }
    
    var frame: CGRect {
        get {
            return CGRect()
        }
        set {
        }
    }
    var bounds: CGRect {
        get {
            return CGRect()
        }
        set {
        }
    }
    var editBounds: CGRect {
        return CGRect()
    }
    
    weak var indicationParent: Respondable? {
        get {
            return parent
        }
        set {
        }
    }
    func allIndicationParents(handler: (Respondable) -> Void) {
        handler(self)
        indicationParent?.allIndicationParents(handler: handler)
    }
    var isIndication: Bool {
        get {
            return false
        }
        set {
        }
    }
    var isSubIndication: Bool {
        get {
            return false
        }
        set {
        }
    }
    
    var undoManager: UndoManager? {
        get {
            return parent?.undoManager
        }
        set {
        }
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return parent?.copy(with: event) ?? CopiedObject()
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        parent?.paste(copiedObject, with: event)
    }
    func delete(with event: KeyInputEvent) {
        parent?.delete(with: event)
    }
    func selectAll(with event: KeyInputEvent) {
        parent?.selectAll(with: event)
    }
    func deselectAll(with event: KeyInputEvent) {
        parent?.deselectAll(with: event)
    }
    func new(with event: KeyInputEvent) {
        parent?.new(with: event)
    }
    func addPoint(with event: KeyInputEvent) {
        parent?.addPoint(with: event)
    }
    func deletePoint(with event: KeyInputEvent) {
        parent?.deletePoint(with: event)
    }
    func movePoint(with event: DragEvent) {
        parent?.movePoint(with: event)
    }
    func moveVertex(with event: DragEvent) {
        parent?.moveVertex(with: event)
    }
    func snapPoint(with event: DragEvent) {
        parent?.snapPoint(with: event)
    }
    func moveZ(with event: DragEvent) {
        parent?.moveZ(with: event)
    }
    func move(with event: DragEvent) {
        parent?.move(with: event)
    }
    func warp(with event: DragEvent) {
        parent?.warp(with: event)
    }
    func transform(with event: DragEvent) {
        parent?.transform(with: event)
    }
    func select(with event: DragEvent) {
        parent?.select(with: event)
    }
    func deselect(with event: DragEvent) {
        parent?.deselect(with: event)
    }
    func moveCursor(with event: MoveEvent) {
        parent?.moveCursor(with: event)
    }
    func keyInput(with event: KeyInputEvent) {
        parent?.keyInput(with: event)
    }
    func click(with event: ClickEvent) {
        parent?.click(with: event)
    }
    func showProperty(with event: RightClickEvent) {
        parent?.showProperty(with: event)
    }
    func drag(with event: DragEvent) {
        parent?.drag(with: event)
    }
    func scroll(with event: ScrollEvent) {
        parent?.scroll(with: event)
    }
    func zoom(with event: PinchEvent) {
        parent?.zoom(with: event)
    }
    func rotate(with event: RotateEvent) {
        parent?.rotate(with: event)
    }
    func reset(with event: DoubleTapEvent) {
        parent?.reset(with: event)
    }
    func lookUp(with event: TapEvent) -> Referenceable {
        return self
    }
    
    func lassoDelete(with event: DragEvent) {
        parent?.lassoDelete(with: event)
    }
    func clipCellInSelection(with event: KeyInputEvent) {
        parent?.clipCellInSelection(with: event)
    }
}

protocol LayerRespondable: Respondable {
    var layer: CALayer { get }
}
extension LayerRespondable {
    func update(withChildren children: [Respondable], oldChildren: [Respondable]) {
        CATransaction.disableAnimation {
            oldChildren.forEach { responder in
                if !children.contains(where: { $0 === responder }) {
                    responder.removeFromParent()
                }
            }
            children.forEach { $0.parent = self }
            layer.sublayers = children.flatMap { ($0 as? LayerRespondable)?.layer }
        }
    }
    func removeFromParent() {
        guard let parent = parent else {
            return
        }
        if let index = parent.children.index(where: { $0 === self }) {
            parent.children.remove(at: index)
        }
        self.parent = nil
        layer.removeFromSuperlayer()
    }
    
    var isIndication: Bool {
        get {
            return false
        }
        set {
            updateBorder(isIndication: newValue)
        }
    }
    func updateBorder(isIndication: Bool) {
        CATransaction.disableAnimation {
            layer.borderColor = isIndication ? Color.indication.cgColor : defaultBorderColor
            layer.borderWidth = layer.borderColor == nil ? 0 : 0.5
        }
    }
    var defaultBorderColor: CGColor? {
        return Color.border.cgColor
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
        }
    }
    var bounds: CGRect {
        get {
            return layer.bounds
        }
        set {
            layer.bounds = newValue
        }
    }
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        }
        set {
            layer.contentsScale = newValue
        }
    }
}
