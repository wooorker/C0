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
//カメラと変形の統合
//「揺れ」の振動数の設定

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
    var time = 0
    var key: String
    var cut = Cut()
    init(cut: Cut = Cut(), time: Int = 0, key: String = "0") {
        self.cut = cut
        self.time = time
        self.key = key
        super.init()
        cutDataModel.dataHandler = { [unowned self] in self.cut.data }
    }
    
    static let timeKey = "0", keyKey = "1"
    init?(coder: NSCoder) {
        time = coder.decodeInteger(forKey: CutItem.timeKey)
        key = coder.decodeObject(forKey: CutItem.keyKey) as? String ?? "0"
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(time, forKey: CutItem.timeKey)
        coder.encode(key, forKey: CutItem.keyKey)
    }
}

final class Cut: NSObject, ClassCopyData {
    static let name = Localization(english: "Cut", japanese: "カット")
    
    enum ViewType: Int8 {
        case preview, edit, editPoint, editVertex, editMoveZ, editWarp, editTransform, editMaterial, editingMaterial
    }
    
    var rootNode: Node
    var editNode: Node
    
    
    
    var time: Int {
        didSet {
            rootNode.time = time
        }
    }
    var timeLength: Int {
        didSet {
            rootNode.timeLength = timeLength
        }
    }
    
    init(
        rootNode: Node = Node(), editNode: Node = Node(),
        time: Int = 0, timeLength: Int = 24
    ) {
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
        super.init()
    }
    
    static let rootNodeKey = "0", editNodeKey = "1",  timeKey = "3", timeLengthKey = "4"
    init?(coder: NSCoder) {
        rootNode = coder.decodeObject(forKey: Cut.rootNodeKey) as? Node ?? Node()
        editNode = coder.decodeObject(forKey: Cut.editNodeKey) as? Node ?? Node()
        time = coder.decodeInteger(forKey: Cut.timeKey)
        timeLength = coder.decodeInteger(forKey: Cut.timeLengthKey)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(rootNode, forKey: Cut.rootNodeKey)
        coder.encode(editNode, forKey: Cut.editNodeKey)
        coder.encode(time, forKey: Cut.timeKey)
        coder.encode(timeLength, forKey: Cut.timeLengthKey)
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
}
