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

final class CutItem: Codable {
    var cutDataModel = DataModel(key: "0") {
        didSet {
            if let cut: Cut = cutDataModel.readObject() {
                self.cut = cut
            }
            cutDataModel.dataHandler = { [unowned self] in self.cut.jsonData }
        }
    }
    var time = Beat(0)
    var key: String
    var cut = Cut()
    init(cut: Cut = Cut(), time: Beat = 0, key: String = "0") {
        self.cut = cut
        self.time = time
        self.key = key
        cutDataModel.dataHandler = { [unowned self] in self.cut.jsonData }
    }
    
    private enum CodingKeys: String, CodingKey {
        case time, key
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        time = try values.decode(Beat.self, forKey: .time)
        key = try values.decode(String.self, forKey: .key)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(time, forKey: .time)
        try container.encode(key, forKey: .key)
    }
}
extension CutItem: Equatable {
    static func ==(lhs: CutItem, rhs: CutItem) -> Bool {
        return lhs === rhs
    }
}
extension CutItem: Copying {
    func copied(from copier: Copier) -> CutItem {
        return CutItem(cut: copier.copied(cut), time: time, key: key)
    }
}

final class Cut: Codable {
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
    var duration: Beat {
        didSet {
            rootNode.duration = duration
        }
    }
    
    init(rootNode: Node = Node(), editNode: Node = Node(), time: Beat = 0, duration: Beat = 1) {
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
        self.duration = duration
        rootNode.time = time
        rootNode.duration = duration
    }
    
    private enum CodingKeys: String, CodingKey {
        case rootNode, editNode, time, duration
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        rootNode = try values.decode(Node.self, forKey: .rootNode)
        editNode = try values.decode(Node.self, forKey: .editNode)
        time = try values.decode(Beat.self, forKey: .time)
        duration = try values.decode(Beat.self, forKey: .duration)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rootNode, forKey: .rootNode)
        try container.encodeConditional(editNode, forKey: .editNode)
        try container.encode(time, forKey: .time)
        try container.encode(duration, forKey: .duration)
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
extension Cut: Equatable {
    static func ==(lhs: Cut, rhs: Cut) -> Bool {
        return lhs === rhs
    }
}
extension Cut: Copying {
    func copied(from copier: Copier) -> Cut {
        return Cut(rootNode: copier.copied(rootNode), editNode: copier.copied(editNode),
                   time: time, duration: duration)
    }
}
extension Cut: Referenceable {
    static let name = Localization(english: "Cut", japanese: "カット")
}
extension Cut: DynamicCodable {
    var dynamicCodableObject: DynamicCodableObject {
        return DynamicCut(self)
    }
}
final class DynamicCut: NSObject, DynamicCodableObject {
    var codable: Codable
    init(_ codable: Cut) {
        self.codable = codable
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(codable.jsonData)
    }
    init?(coder aDecoder: NSCoder) {
        if let data = aDecoder.decodeData(), let codable = Cut(jsonData: data) {
            self.codable = codable
        } else {
            return nil
        }
    }
}
