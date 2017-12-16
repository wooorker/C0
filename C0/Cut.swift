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

final class CutItem: NSObject, NSCoding {
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
    
    private enum CodingKeys: String, CodingKey {
        case time, key
    }
    init?(coder: NSCoder) {
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        key = coder.decodeObject(forKey: CodingKeys.key.rawValue) as? String ?? "0"
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encode(key, forKey: CodingKeys.key.rawValue)
    }
}
extension CutItem: Copying {
    func copied(from copier: Copier) -> CutItem {
        return CutItem(cut: copier.copied(cut), time: time, key: key)
    }
}

final class Cut: NSObject, NSCoding {
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
    
    init(rootNode: Node = Node(), editNode: Node = Node(),
         time: Beat = 0, duration: Beat = 1) {
       
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
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case rootNode, editNode, time, duration
    }
    init?(coder: NSCoder) {
        rootNode = coder.decodeObject(forKey: CodingKeys.rootNode.rawValue) as? Node ?? Node()
        editNode = coder.decodeObject(forKey: CodingKeys.editNode.rawValue) as? Node ?? Node()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        duration = coder.decodeDecodable(Beat.self, forKey: CodingKeys.duration.rawValue) ?? 0
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(rootNode, forKey: CodingKeys.rootNode.rawValue)
        coder.encode(editNode, forKey: CodingKeys.editNode.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encodeEncodable(duration, forKey: CodingKeys.duration.rawValue)
    }
    
    var imageBounds: CGRect {
        return rootNode.imageBounds
    }
    
    func draw(scene: Scene, viewType: Cut.ViewType, in ctx: CGContext) {
        ctx.saveGState()
        if viewType == .preview {
            rootNode.draw(scene: scene, viewType: viewType,
                          scale: 1, rotation: 0,
                          viewScale: 1, viewRotation: 0,
                          in: ctx)
        } else {
            ctx.concatenate(scene.viewTransform.affineTransform)
            rootNode.draw(scene: scene, viewType: viewType,
                          scale: 1, rotation: 0,
                          viewScale: scene.scale, viewRotation: scene.viewTransform.rotation,
                          in: ctx)
        }
        ctx.restoreGState()
    }
    
    func drawCautionBorder(scene: Scene, bounds: CGRect, in ctx: CGContext) {
        func drawBorderWith(bounds: CGRect, width: CGFloat, color: Color, in ctx: CGContext) {
            ctx.setFillColor(color.cgColor)
            ctx.fill([CGRect(x: bounds.minX, y: bounds.minY,
                             width: width, height: bounds.height),
                      CGRect(x: bounds.minX + width, y: bounds.minY,
                             width: bounds.width - width * 2, height: width),
                      CGRect(x: bounds.minX + width, y: bounds.maxY - width,
                             width: bounds.width - width * 2, height: width),
                      CGRect(x: bounds.maxX - width, y: bounds.minY,
                             width: width, height: bounds.height)]
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
            textLine.draw(in: CGRect(x: bounds.minX + (bounds.width - sb.width) / 2,
                                     y: bounds.minY + bounds.height - sb.height - borderWidth,
                                     width: sb.width, height: sb.height),
                          in: ctx)
        }
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
