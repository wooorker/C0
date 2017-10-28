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

final class Node: NSObject {
    weak var parent: Node?
    var children = [Node]()
    
    var rootCell: Cell
    var transform: Transform
    var material: Material {
        didSet {
//            func bluerFilter() -> [CIFilter]? {
//                let blurFilter = CIFilter()
//                
//            }
//            layer.opacity = Float(material.opacity)
//            switch material.type {
//            case .normal, .lineless:
//                layer.compositingFilter = nil
//                layer.filters = []
//            case .blur:
//                layer.compositingFilter = nil
//                layer.filters = bluerFilter()
//            case .luster:
//                layer.filters = bluerFilter()
//            case .add:
//                layer.compositingFilter = CIFilter(name: "")
//                layer.filters = bluerFilter()
//            case .subtract:
//                layer.compositingFilter = CIFilter(name: "")
//                layer.filters = bluerFilter()
//            }
        }
    }
    init(rootCell: Cell = Cell(), transform: Transform = Transform(), material: Material = Material()) {
        self.rootCell = rootCell
        self.transform = transform
        self.material = material
    }
    
    var editAnimationIndex = 0
    
    func render(in ctx: CGContext) {
//        let cictx = CIContext(cgContext: ctx, options: nil)
//        let filter = CIFilter()
//        if let outputImage = filter.outputImage {
//            cictx.draw(filter.outputImage, in: ctx.boundingBoxOfClipPath, from: ctx.boundingBoxOfClipPath)
//        }
    }
}

final class NodeEditor: LayerRespondable {
    static let name = Localization(english: "Node Editor", japanese: "ノードエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    
    var undoManager: UndoManager?
    
    let layer = CALayer.interfaceLayer()
    
    init(frame: CGRect) {
        layer.frame = frame
    }
}
