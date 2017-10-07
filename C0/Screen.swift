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
 ## 0.3.0
 * セル、線を再設計
 * 点の追加、点の削除、点の移動と線の変形、スナップを再設計
 * セルの追加時の線の置き換えを廃止、編集セルを廃止、編集表示を再設計
 * マテリアルのコピーによるバインドを廃止、クリックでマテリアルを選択
 * 線の描画、分割を改善
 * 変形、歪曲の再設計
 * コマンドを整理
 * 描画の一部を高速化
 */

//# Issue
//with: event廃止
//Swift4への対応
//汎用性、モードレス性に基づいたオブジェクト設計
//描画高速化（GPUを積極活用するように再設計する。Metal APIを利用）
//CALayerのdrawsAsynchronouslyのメモリリーク修正（GPU描画に変更）
//DCI-P3色空間
//リニアワークフロー（移行した場合、「スクリーン」は「発光」に統合）
//カット単位での読み込み
//安全性の高いデータベース設計（保存が途中で中断された場合に、マテリアルの保存が部分的に行われていない状態になる）
//強制アンラップの抑制
//guard文
//カプセル化を強化（SceneEditorDelegate実装など）
//保存高速化
//安全なシリアライズ（NSObject, NSCodingを取り除く。Swift4のCodableを使用）
//Collectionプロトコル（allCellsやallBeziers、allEditPointsなどに適用）
//privateを少なくし、関数のネストなどを増やす
//TextEditorとLabelの統合
//TimelineEditorなどをリファクタリング
//ProtocolなResponder
//ModelとViewを統合
//永続データ構造に近づける
//Main.storyboard, Localizable.strings, Assets.xcassetsの廃止
//AppKit脱却
//様々なメディアファイルに対応
//クローン実装
//Union選択（選択の結合を明示的に行う）
//コピーオブジェクト表示
//コピーUndo
//パネルにindication表示を付ける
//カーソルが離れると閉じるプルダウンボタン
//スロー操作時の値の変更を相対的にする
//ラジオボタンの導入
//ボタンの可視性の改善
//スクロールの可視性の改善・位置表示（元の位置までの距離などを表示）
//トラックパッドの環境設定を無効化または表示反映
//書き出し時間表示の精度を改善
//ファイルシステムのモードレス化
//音楽（シーケンサー付き）・効果音
//スローコマンドを廃止
//current: Screen?  → shared: Screen
//screenからsceneViewを取り除く

import Foundation
import QuartzCore

import AppKit.NSDocumentController
import AppKit.NSCursor
import AppKit.NSPasteboard
import AppKit.NSPasteboardItem

class Screen {
    weak var screenView: ScreenView!
    static var current: Screen? {
        return (NSDocumentController.shared().currentDocument as? Document)?.screenView.screen
    }
    init() {
        indicationResponder = rootResponder
    }
    
    let rootResponder = Responder()
    var panel = Responder() {
        didSet {
            rootResponder.children = [content, panel]
        }
    }
    var content = Responder() {
        didSet {
            rootResponder.children = [content, panel]
        }
    }
    var indicationResponder = Responder() {
        didSet {
            oldValue.allParents {
                $0.indication = false
            }
            indicationResponder.allParents {
                $0.indication = true
            }
        }
    }
    
    var frame = CGRect() {
        didSet {
            CATransaction.disableAnimation {
                content.frame = frame
            }
        }
    }
    var backingScaleFactor = 1.0.cf {
        didSet {
            rootResponder.allResponders {
                $0.contentsScale = backingScaleFactor
            }
        }
    }
    
    var locale = Locale.current {
        didSet {
            if locale.identifier != oldValue.identifier {
                rootResponder.allResponders {
                    $0.updateString(with: locale)
                }
            }
        }
    }
    
    func setIndicationResponder(with p: CGPoint) {
        let hitResponder = rootResponder.atPoint(p) ?? content
        if indicationResponder !== hitResponder {
            indicationResponder = hitResponder
        }
    }
    func setIndicationResponderFromCurrentPoint() {
        setIndicationResponder(with: cursorPoint)
    }
    func setCursor(with p: CGPoint) {
        let cursor = indicationResponder.cursor(with: convert(p, to: indicationResponder))
        if cursor != NSCursor.current() {
            cursor.set()
        }
    }
    func setCursorFromCurrentPoint() {
        setCursor(with: cursorPoint)
    }
    var cursorPoint: CGPoint {
        return screenView.cursorPoint
    }
    
    func convert(_ p: CGPoint, from responder: Responder) -> CGPoint {
        return rootResponder.layer.convert(p, from: responder.layer)
    }
    func convert(_ p: CGPoint, to responder: Responder) -> CGPoint {
        return responder.layer.convert(p, from: rootResponder.layer)
    }
    func convert(_ rect: CGRect, from responder: Responder) -> CGRect {
        return rootResponder.layer.convert(rect, from: responder.layer)
    }
    func convert(_ rect: CGRect, to responder: Responder) -> CGRect {
        return responder.layer.convert(rect, from: rootResponder.layer)
    }
    
    var actionNode = ActionNode.default
    
    var undoManager = UndoManager()
    
    func copy(_ string: String, from responder: Responder) {
        let pasteboard = NSPasteboard.general()
        pasteboard.declareTypes([NSStringPboardType], owner: nil)
        pasteboard.setString(string, forType: NSStringPboardType)
    }
    func copy(_ data: Data, forType type: String, from responder: Responder) {
        let pasteboard = NSPasteboard.general()
        pasteboard.declareTypes([type], owner: nil)
        pasteboard.setData(data, forType: type)
    }
    func copy(_ typeData: [String: Data], from responder: Responder) {
        let items: [NSPasteboardItem] = typeData.map {
            let item = NSPasteboardItem()
            item.setData($0.value, forType: $0.key)
            return item
        }
        let pasteboard = NSPasteboard.general()
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
    func copyString() -> String? {
        return NSPasteboard.general().string(forType: NSStringPboardType)
    }
    func copyData(forType type: String) -> Data? {
        return NSPasteboard.general().data(forType: type)
    }
    
//    let minPasteImageWidth = 400.0.cf
//    func pasteInContent(with event: KeyInputEvent) {
//        let pasteboard = NSPasteboard.general()
//        let urlOptions: [String : Any] = [NSPasteboardURLReadingContentsConformToTypesKey: NSImage.imageTypes()]
//        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: urlOptions) as? [URL], !urls.isEmpty {
//            let p = rootResponder.cursorPoint
//            for url in urls {
//                content.addChild(makeImageEditor(url: url, position: p))
//            }
//        }
//    }
//    private func makeImageEditor(url :URL, position p: CGPoint) -> ImageEditor {
//        let imageEditor = ImageEditor()
//        imageEditor.image = NSImage(byReferencing: url)
//        let size = imageEditor.image.bitmapSize
//        let maxWidth = max(size.width, size.height)
//        let ratio = minPasteImageWidth < maxWidth ? minPasteImageWidth/maxWidth : 1
//        let width = ceil(size.width*ratio), height = ceil(size.height*ratio)
//        imageEditor.frame = CGRect(x: round(p.x - width/2), y: round(p.y - height/2), width: width, height: height)
//        return imageEditor
//    }
    
    func addResponderInRootPanel(_ responder: Responder, point: CGPoint, from fromResponder: Responder) {
        CATransaction.disableAnimation {
            responder.frame.origin = rootResponder.convert(point, from: fromResponder)
            panel.addChild(responder)
        }
    }
    func showDescription(_ description: String, from responder: Responder) {
        screenView.showDescription(description, from: responder)
    }
}
