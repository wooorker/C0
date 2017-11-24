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
 * 選択修正
 △ テキストの修正
 △ インディケーション再生
 △ ビートタイムライン
 △ スナップスクロール
 △ コピー、分割修正
 △ Z移動の修正
 △ ノード導入
 △ カット単位での読み込み
 △ マテリアルアニメーション
 △ セル補間選択
 X ストローク修正
 X Swift4 (Codable導入)
 X リファレンス表示の具体化
 
 ## 0.4
 X Metalによるリニアワークフローレンダリング
 
 ## 1.0
 X 安定版
 
 # Issue
 SliderなどのUndo実装
 DelegateをClosureに変更
 カプセル化（var sceneEditor!の排除）
 AnimationのItemのイミュータブル化
 正確なディープコピー
 リファクタリング
 コピー・ペーストなどのアクション対応を拡大
 コピーオブジェクトの自由な貼り付け
 コピーの階層化
 文字入力、字幕
 スクロールの可視性の改善 (元の位置までの距離などを表示)
 トラックパッドの環境設定を無効化または表示反映
 バージョン管理UndoManager
 様々なメディアファイルに対応
 ファイルシステムのモードレス化
 シーケンサー
 効果音編集
 (with: event)のない、protocolによる完全なモードレスアクション
*/

import Foundation
import QuartzCore

enum EditQuasimode {
    case none, movePoint, moveVertex, move, moveZ, warp, transform, select, deselect
}

protocol Localizable: class {
    var locale: Locale { get set }
}

protocol Respondable: class, Referenceable {
    weak var parent: Respondable? { get set }
    var children: [Respondable] { get set }
    var dataModel: DataModel? { get set }
    func update(withChildren children: [Respondable], oldChildren: [Respondable])
    func removeFromParent()
    func allChildren(_ handler: (Respondable) -> Void)
    func allParents(handler: (Respondable) -> Void)
    var rootRespondable: Respondable { get }
    func set(_ editQuasimode: EditQuasimode, with event: Event)
    var editQuasimode: EditQuasimode { get set }
    var cursor: Cursor { get }
    func contains(_ p: CGPoint) -> Bool
    func at(_ point: CGPoint) -> Respondable?
    var contentsScale: CGFloat { get set }
    var defaultBorderColor: CGColor? { get }
    func point(from event: Event) -> CGPoint
    func convert(_ point: CGPoint, from responder: Respondable?) -> CGPoint
    func convert(_ point: CGPoint, to responder: Respondable?) -> CGPoint
    func convert(_ rect: CGRect, from responder: Respondable?) -> CGRect
    func convert(_ rect: CGRect, to responder: Respondable?) -> CGRect
    var frame: CGRect { get set }
    var bounds: CGRect { get set }
    var editBounds: CGRect { get }
    var isIndication: Bool { get set }
    var isSubIndication: Bool { get set }
    var undoManager: UndoManager? { get set }
    func copy(with event: KeyInputEvent) -> CopyObject
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent)
    func delete(with event: KeyInputEvent)
    func selectAll(with event: KeyInputEvent)
    func deselectAll(with event: KeyInputEvent)
    func new(with event: KeyInputEvent)
    func addPoint(with event: KeyInputEvent)
    func deletePoint(with event: KeyInputEvent)
    func movePoint(with event: DragEvent)
    func moveVertex(with event: DragEvent)
    func snapPoint(with event: DragEvent)
    func moveZ(with event: DragEvent)
    func move(with event: DragEvent)
    func warp(with event: DragEvent)
    func transform(with event: DragEvent)
    func select(with event: DragEvent)
    func deselect(with event: DragEvent)
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
}
extension Respondable {
    static func == (lhs: Self, rhs: Self) -> Bool {
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
        allChildren {
            $0.dataModel = dataModel
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
    }
    
    func set(_ editQuasimode: EditQuasimode,
             with event: Event) {
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
        return bounds.contains(p + bounds.origin)
    }
    func at(_ point: CGPoint) -> Respondable? {
        for child in children.reversed() {
            let inPoint = child.convert(point, from: self)
            if let responder = child.at(inPoint) {
                return responder
            }
        }
        return contains(point) ? self : nil
    }
    func point(from event: Event) -> CGPoint {
        return convert(event.location, from: nil)
    }
    func convert(_ point: CGPoint, from responder: Respondable?) -> CGPoint {
        guard self !== responder else {
            return point
        }
        let result = responder?.convertToRoot(point, stop: self) ?? (point: point, isRoot: true)
        return !result.isRoot ? result.point : result.point - convertToRoot(CGPoint(), stop: nil).point
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
    private func convertToRoot(_ point: CGPoint, stop responder: Respondable?) -> (point: CGPoint, isRoot: Bool) {
        if let parent = parent {
            let parentPoint = point + bounds.origin + frame.origin
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
    func copy(with event: KeyInputEvent) -> CopyObject {
        return parent?.copy(with: event) ?? CopyObject()
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        parent?.paste(copyObject, with: event)
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
//    func at(_ point: CGPoint) -> Respondable? {
//        guard !layer.isHidden else {
//            return nil
//        }
//        for child in children.reversed() {
//            if let childResponder = child as? LayerRespondable {
//                let inPoint = childResponder.layer.convert(point, from: layer)
//                if let responder = childResponder.at(inPoint) {
//                    return responder
//                }
//            }
//        }
//        return contains(point) ? self : nil
//    }
//    func contains(_ p: CGPoint) -> Bool {
//        return !layer.isHidden ? layer.contains(p) : false
//    }
//    func point(from event: Event) -> CGPoint {
//        return layer.convert(event.location, from: nil)
//    }
//    func convert(_ point: CGPoint, from responder: LayerRespondable?) -> CGPoint {
//        return layer.convert(point, from: responder?.layer)
//    }
//    func convert(_ point: CGPoint, to responder: LayerRespondable?) -> CGPoint {
//        return layer.convert(point, to: responder?.layer)
//    }
}
