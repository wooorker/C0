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

final class CutItem: NSObject, NSCoding, Copying {
    var cutDataModel = DataModel(key: "0") {
        didSet {
            if let cut: Cut = cutDataModel.readObject() {
                self.cut = cut
            }
            cutDataModel.dataHandler = { [unowned self] in self.cut.data }
        }
    }
    var time = Beat(0)
    var key: String
    var cut = Cut()
    init(cut: Cut = Cut(), time: Beat = 0, key: String = "0") {
        self.cut = cut
        self.time = time
        self.key = key
        super.init()
        cutDataModel.dataHandler = { [unowned self] in self.cut.data }
    }
    
    var deepCopy: CutItem {
        return CutItem(cut: cut.deepCopy, time: time, key: key)
    }
    
    static let timeKey = "0", keyKey = "1"
    init?(coder: NSCoder) {
        time = coder.decodeStruct(forKey: CutItem.timeKey) ?? 0
        key = coder.decodeObject(forKey: CutItem.keyKey) as? String ?? "0"
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(time, forKey: CutItem.timeKey)
        coder.encode(key, forKey: CutItem.keyKey)
    }
}

final class Cut: NSObject, ClassCopyData {
    static let name = Localization(english: "Cut", japanese: "カット")
    
    enum ViewType: Int8 {
        case
        preview, edit,
        editPoint, editVertex, editMoveZ,
        editWarp, editTransform, editSelection, editDeselection,
        editMaterial, editingMaterial
    }
    
    var rootNode: Node
    var editNode: Node
    
    var time: Beat {
        didSet {
            rootNode.time = time
        }
    }
    var timeLength: Beat {
        didSet {
            rootNode.timeLength = timeLength
        }
    }
    
    init(rootNode: Node = Node(), editNode: Node = Node(), time: Beat = 0, timeLength: Beat = 1) {
        if rootNode.children.isEmpty {
            let node = Node()
            rootNode.children.append(node)
            self.rootNode = rootNode
            self.editNode = node
        } else {
            self.rootNode = rootNode
            self.editNode = editNode
        }
        self.time = time
        self.timeLength = timeLength
        rootNode.time = time
        rootNode.timeLength = timeLength
        super.init()
    }
    
    static let rootNodeKey = "0", editNodeKey = "1",  timeKey = "3", timeLengthKey = "4"
    init?(coder: NSCoder) {
        rootNode = coder.decodeObject(forKey: Cut.rootNodeKey) as? Node ?? Node()
        editNode = coder.decodeObject(forKey: Cut.editNodeKey) as? Node ?? Node()
        time = coder.decodeStruct(forKey: Cut.timeKey) ?? 0
        timeLength = coder.decodeStruct(forKey: Cut.timeLengthKey) ?? 0
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(rootNode, forKey: Cut.rootNodeKey)
        coder.encode(editNode, forKey: Cut.editNodeKey)
        coder.encodeStruct(time, forKey: Cut.timeKey)
        coder.encodeStruct(timeLength, forKey: Cut.timeLengthKey)
    }
    
    var deepCopy: Cut {
        let copyRootNode = rootNode.noResetDeepCopy
        let copyEditNode = editNode.noResetDeepCopy
        rootNode.resetCopyedNode()
        return Cut(rootNode: copyRootNode, editNode: copyEditNode, time: time, timeLength: timeLength)
    }
    
    var imageBounds: CGRect {
        return rootNode.imageBounds
    }
    
    func draw(scene: Scene, bounds: CGRect, viewType: Cut.ViewType, in ctx: CGContext) {
        ctx.saveGState()
        if viewType == .preview {
            rootNode.draw(scene: scene, viewType: viewType, scale: 1, rotation: 0, viewScale: 1, viewRotation: 0, in: ctx)
        } else {
            ctx.concatenate(scene.viewTransform.affineTransform)
            rootNode.draw(scene: scene, viewType: viewType, scale: 1, rotation: 0, viewScale: scene.scale, viewRotation: scene.viewTransform.rotation, in: ctx)
        }
        ctx.restoreGState()
    }
    
    func drawCautionBorder(scene: Scene, bounds: CGRect, in ctx: CGContext) {
        func drawBorderWith(bounds: CGRect, width: CGFloat, color: Color, in ctx: CGContext) {
            ctx.setFillColor(color.cgColor)
            ctx.fill(
                [
                    CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height),
                    CGRect(x: bounds.minX + width, y: bounds.minY, width: bounds.width - width * 2, height: width),
                    CGRect(x: bounds.minX + width, y: bounds.maxY - width, width: bounds.width - width * 2, height: width),
                    CGRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height)
                ]
            )
        }
        if scene.viewTransform.rotation > .pi / 2 || scene.viewTransform.rotation < -.pi / 2 {
            let borderWidth = 2.0.cf
            drawBorderWith(bounds: bounds, width: borderWidth * 2, color: .warning, in: ctx)
            let textLine = TextFrame(
                string: "\(Int(scene.viewTransform.rotation * 180 / (.pi)))°",
                font: .bold, color: .red
            )
            let sb = textLine.typographicBounds.insetBy(dx: -10, dy: -2).integral
            textLine.draw(
                in: CGRect(
                    x: bounds.minX + (bounds.width - sb.width) / 2,
                    y: bounds.minY + bounds.height - sb.height - borderWidth,
                    width: sb.width, height: sb.height
                ),
                in: ctx
            )
        }
    }
}
