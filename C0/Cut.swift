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

/**
 # Issue
 - 変更通知
 */
final class Cut: NSObject, NSCoding {
    enum ViewType: Int8 {
        case
        preview, edit,
        editPoint, editVertex, editMoveZ,
        editWarp, editTransform, editSelection, editDeselection,
        editMaterial, changingMaterial
    }
    
    var rootNode: Node
    var editNode: Node {
        didSet {
            if editNode != oldValue {
                oldValue.isEdited = false
                editNode.isEdited = true
            }
        }
    }
    
    var time: Beat {
        didSet {
            rootNode.time = time
        }
    }
    var duration: Beat
    
    init(rootNode: Node = Node(tracks: [NodeTrack(animation: Animation(duration: 0))]),
         editNode: Node = Node(name: Localization(english: "Node 0",
                                                  japanese: "ノード0").currentString),
         time: Beat = 0) {
       
        editNode.editTrack.name = Localization(english: "Track 0", japanese: "トラック0").currentString
        if rootNode.children.isEmpty {
            rootNode.children.append(editNode)
        }
        self.rootNode = rootNode
        self.editNode = editNode
        self.time = time
        self.duration = rootNode.maxDuration
        rootNode.time = time
        rootNode.isEdited = true
        editNode.isEdited = true
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case rootNode, editNode, time, duration
    }
    init?(coder: NSCoder) {
        rootNode = coder.decodeObject(forKey: CodingKeys.rootNode.rawValue) as? Node ?? Node()
        editNode = coder.decodeObject(forKey: CodingKeys.editNode.rawValue) as? Node ?? Node()
        rootNode.isEdited = true
        editNode.isEdited = true
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
                font: .bold, color: .warning
            )
            let sb = textLine.typographicBounds.insetBy(dx: -10, dy: -2).integral
            textLine.draw(in: CGRect(x: bounds.minX + (bounds.width - sb.width) / 2,
                                     y: bounds.minY + bounds.height - sb.height - borderWidth,
                                     width: sb.width, height: sb.height),
                          in: ctx)
        }
    }
    
    var cells: [Cell] {
        var cells = [Cell]()
        rootNode.allChildrenAndSelf { cells += $0.rootCell.allCells }
        return cells
    }
    
    var maxDuration: Beat {
        var maxDuration = editNode.editTrack.animation.duration
        rootNode.children.forEach { node in
            node.tracks.forEach {
                let duration = $0.animation.duration
                if duration > maxDuration {
                    maxDuration = duration
                }
            }
        }
        return maxDuration
    }
}
extension Cut: Copying {
    func copied(from copier: Copier) -> Cut {
        return Cut(rootNode: copier.copied(rootNode), editNode: copier.copied(editNode),
                   time: time)
    }
}
extension Cut: Referenceable {
    static let name = Localization(english: "Cut", japanese: "カット")
}

final class CutEditor: Layer, Respondable {
    static let name = Localization(english: "Cut Editor", japanese: "カットエディタ")
    
    private(set) var editAnimationEditor: AnimationEditor {
        didSet {
            oldValue.isSmall = true
            editAnimationEditor.isSmall = false
            updateChildren()
        }
    }
    private(set) var animationEditors: [AnimationEditor]
    
    func animationEditor(with nodeAndTrack: NodeAndTrack) -> AnimationEditor {
        let index = nodeAndTrackIndex(with: nodeAndTrack)
        return animationEditors[index]
    }
    func animationEditors(with node: Node) -> [AnimationEditor] {
        var animationEditors = [AnimationEditor]()
        tracks(from: node) { (track, i) in
            animationEditors.append(self.animationEditors[i])
        }
        return animationEditors
    }
    func tracks(handler: (Node, NodeTrack, Int) -> ()) {
        CutEditor.tracks(with: cutItem, handler: handler)
    }
    func tracks(from node: Node, handler: (NodeTrack, Int) -> ()) {
        CutEditor.tracks(from: node, with: cutItem, handler: handler)
    }
    static func tracks(with node: Node, handler: (Node, NodeTrack, Int) -> ()) {
        var i = 0
        node.allChildrenAndSelf { aNode in
            aNode.tracks.forEach { track in
                handler(aNode, track, i)
                i += 1
            }
        }
    }
    static func tracks(with cutItem: CutItem, handler: (Node, NodeTrack, Int) -> ()) {
        var i = 0
        cutItem.cut.rootNode.allChildren { node in
            node.tracks.forEach { track in
                handler(node, track, i)
                i += 1
            }
        }
    }
    static func tracks(from node: Node, with cutItem: CutItem, handler: (NodeTrack, Int) -> ()) {
        tracks(with: cutItem) { (aNode, track, i) in
            if node == aNode {
                handler(track, i)
            }
        }
    }
    static func animationEditor(with track: NodeTrack, beginBaseTime: Beat,
                                baseTimeInterval: Beat, isSmall: Bool) -> AnimationEditor {
        return AnimationEditor(track.animation,
                               beginBaseTime: beginBaseTime,
                               baseTimeInterval: baseTimeInterval,
                               isSmall: isSmall)
    }
    func newAnimationEditor(with track: NodeTrack, node: Node, isSmall: Bool) -> AnimationEditor {
        let animationEditor = CutEditor.animationEditor(with: track, beginBaseTime: cutItem.time,
                                                        baseTimeInterval: baseTimeInterval,
                                                        isSmall: isSmall)
        bind(in: animationEditor, from: node, from: track)
        return animationEditor
    }
    func newAnimationEditors(with node: Node) -> [AnimationEditor] {
        var animationEditors = [AnimationEditor]()
        CutEditor.tracks(with: node) { (node, track, index) in
            let animationEditor = CutEditor.animationEditor(with: track, beginBaseTime: cutItem.time,
                                                            baseTimeInterval: baseTimeInterval,
                                                            isSmall: false)
            bind(in: animationEditor, from: node, from: track)
            animationEditors.append(animationEditor)
        }
        return animationEditors
    }
    
    let cutItem: CutItem
    init(_ cutItem: CutItem,
         baseWidth: CGFloat, baseTimeInterval: Beat,
         knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat, maxLineWidth: CGFloat, height: CGFloat) {
        
        self.cutItem = cutItem
        self.baseWidth = baseWidth
        self.baseTimeInterval = baseTimeInterval
        self.knobHalfHeight = knobHalfHeight
        self.subKnobHalfHeight = subKnobHalfHeight
        self.maxLineWidth = maxLineWidth
        
        let editNode = cutItem.cut.editNode
        var animationEditors = [AnimationEditor](), editAnimationEditor = AnimationEditor()
        CutEditor.tracks(with: cutItem) { (node, track, index) in
            let isEdit = node === editNode && track == editNode.editTrack
            let animationEditor = AnimationEditor(track.animation,
                                                  beginBaseTime: cutItem.time,
                                                  baseTimeInterval: baseTimeInterval,
                                                  isSmall: !isEdit)
            animationEditors.append(animationEditor)
            if isEdit {
                editAnimationEditor = animationEditor
            }
        }
        self.animationEditors = animationEditors
        self.editAnimationEditor = editAnimationEditor
        
        super.init()
        replace(children: animationEditors)
        frame.size.height = height
        updateChildren()
        updateWithDuration()
        
        animationEditors.enumerated().forEach { (i, animationEditor) in
            let nodeAndTrack = self.nodeAndTrack(atNodeAndTrackIndex: i)
            bind(in: animationEditor, from: nodeAndTrack.node, from: nodeAndTrack.track)
        }
    }
    
    func bind(in animationEditor: AnimationEditor, from node: Node, from track: NodeTrack) {
        animationEditor.splitKeyframeLabelHandler = { (keyframe, _) in
            track.isEmptyGeometryWithCells(at: keyframe.time) ? .main : .sub
        }
        animationEditor.lineColorHandler = { _ in
            track.transformItem != nil ? .camera : .content
        }
        animationEditor.smallLineColorHandler = {
            track.transformItem != nil ? .camera : .content
        }
        animationEditor.knobColorHandler = {
            track.drawingItem.keyDrawings[$0].roughLines.isEmpty ? .knob : .timelineRough
        }
    }
    
    var baseTimeInterval = Beat(1, 16) {
        didSet {
            animationEditors.forEach { $0.baseTimeInterval = baseTimeInterval }
            updateWithDuration()
        }
    }
    
    var isEdit = false {
        didSet {
            animationEditors.forEach { $0.isEdit = isEdit }
        }
    }
    
    var baseWidth: CGFloat {
        didSet {
            animationEditors.forEach { $0.baseWidth = baseWidth }
            updateChildren()
            updateWithDuration()
        }
    }
    let knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat
    let maxLineWidth: CGFloat
    
    func x(withTime time: Beat) -> CGFloat {
        return DoubleBeat(time / baseTimeInterval).cf * baseWidth
    }
    
    func updateChildren() {
        guard let index = animationEditors.index(of: editAnimationEditor) else {
            return
        }
        let midY = frame.height / 2
        var y = midY - editAnimationEditor.frame.height / 2
        editAnimationEditor.frame.origin = CGPoint(x: 0, y: y)
        for i in (0 ..< index).reversed() {
            let animationEditor = animationEditors[i]
            y -= animationEditor.frame.height
            animationEditor.frame.origin = CGPoint(x: 0, y: y)
        }
        y = midY + editAnimationEditor.frame.height / 2
        for i in (index + 1 ..< animationEditors.count) {
            let animationEditor = animationEditors[i]
            animationEditor.frame.origin = CGPoint(x: 0, y: y)
            y += animationEditor.frame.height
        }
    }
    func updateWithDuration() {
        frame.size.width = x(withTime: cutItem.cut.duration)
    }
    func updateWithCutTime() {
        tracks { animationEditors[$2].beginBaseTime = cutItem.time }
    }
    func updateIfChangedEditTrack() {
        editAnimationEditor.animation = cutItem.cut.editNode.editTrack.animation
        updateChildren()
    }
    
    func updateWithTime() {
        tracks { animationEditors[$2].updateKeyframeIndex(with: $1.animation) }
    }
    
    struct NodeAndTrack: Equatable {
        let node: Node, trackIndex: Int
        var track: NodeTrack {
            return node.tracks[trackIndex]
        }
        static func ==(lhs: CutEditor.NodeAndTrack, rhs: CutEditor.NodeAndTrack) -> Bool {
            return lhs.node == rhs.node && lhs.trackIndex == rhs.trackIndex
        }
    }
    func nodeAndTrackIndex(with nodeAndTrack: NodeAndTrack) -> Int {
        var index = 0
        func maxNodeAndTrackIndexRecursion(_ node: Node, stop: inout Bool) {
            if stop {
                return
            }
            if node == nodeAndTrack.node {
                index += nodeAndTrack.trackIndex
                stop = true
                return
            }
            node.children.forEach { maxNodeAndTrackIndexRecursion($0, stop: &stop) }
            if !stop {
                index += node.tracks.count
            }
        }
        var stop = false
        cutItem.cut.rootNode.children.forEach {
            maxNodeAndTrackIndexRecursion($0, stop: &stop)
        }
        return index
    }
    func nodeAndTrack(atNodeAndTrackIndex nodeAndTrackIndex: Int) -> NodeAndTrack {
        var index = 0
        var nodeAndTrack = NodeAndTrack(node: cutItem.cut.rootNode, trackIndex: 0)
        func maxNodeAndTrackIndexRecursion(_ node: Node, stop: inout Bool) {
            if stop {
                return
            }
            let newIndex = index + node.tracks.count
            if index <= nodeAndTrackIndex && newIndex > nodeAndTrackIndex {
                nodeAndTrack = NodeAndTrack(node: node, trackIndex: nodeAndTrackIndex - index)
                stop = true
                return
            }
            index = newIndex
            node.children.forEach { maxNodeAndTrackIndexRecursion($0, stop: &stop) }
        }
        var stop = false
        cutItem.cut.rootNode.children.forEach {
            maxNodeAndTrackIndexRecursion($0, stop: &stop)
        }
        return nodeAndTrack
    }
    var isUseUpdateChildren = true
    var editNodeAndTrack: NodeAndTrack {
        get {
            let node = cutItem.cut.editNode
            return NodeAndTrack(node: node, trackIndex: node.editTrackIndex)
        }
        set {
            cutItem.cut.editNode = newValue.node
            if newValue.trackIndex < newValue.node.tracks.count {
                newValue.node.editTrackIndex = newValue.trackIndex
            }
            editAnimationEditor = animationEditors[editNodeAndTrackIndex]
        }
    }
    var editNodeAndTrackIndex: Int {
        return nodeAndTrackIndex(with: editNodeAndTrack)
    }
    var maxNodeAndTrackIndex: Int {
        func maxNodeAndTrackIndexRecursion(_ node: Node) -> Int {
            let count = node.children.reduce(0) { $0 + maxNodeAndTrackIndexRecursion($1) }
            return count + node.tracks.count
        }
        return maxNodeAndTrackIndexRecursion(cutItem.cut.rootNode) - 2
    }
    
    func insert(_ node: Node, at index: Int, _ animationEditors: [AnimationEditor], parent: Node) {
        parent.children.insert(node, at: index)
        let nodeAndTrackIndex = self.nodeAndTrackIndex(with: NodeAndTrack(node: node, trackIndex: 0))
        self.animationEditors.insert(contentsOf: animationEditors, at: nodeAndTrackIndex)
        var children = self.children
        children.insert(contentsOf: animationEditors as [Layer], at: nodeAndTrackIndex)
        replace(children: children)
        updateChildren()
    }
    func remove(at index: Int, _ animationEditors: [AnimationEditor], parent: Node) {
        let node = parent.children[index]
        let animationIndex = nodeAndTrackIndex(with: NodeAndTrack(node: node, trackIndex: 0))
        let maxAnimationIndex = animationIndex + animationEditors.count
        parent.children.remove(at: index)
        self.animationEditors.removeSubrange(animationIndex..<maxAnimationIndex)
        var children = self.children
        children.removeSubrange(animationIndex..<maxAnimationIndex)
        replace(children: children)
        updateChildren()
    }
    func insert(_ track: NodeTrack, _ animationEditor: AnimationEditor,
                in nodeAndTrack: NodeAndTrack) {
        let i = nodeAndTrackIndex(with: nodeAndTrack)
        nodeAndTrack.node.tracks.insert(track, at: nodeAndTrack.trackIndex)
        animationEditors.insert(animationEditor, at: i)
        append(child: animationEditor)
        updateChildren()
    }
    func removeTrack(at nodeAndTrack: NodeAndTrack) {
        let i = nodeAndTrackIndex(with: nodeAndTrack)
        nodeAndTrack.node.tracks.remove(at: nodeAndTrack.trackIndex)
        animationEditors[i].removeFromParent()
        animationEditors.remove(at: i)
        updateChildren()
    }
    func set(editTrackIndex: Int, in node: Node) {
        editNodeAndTrack = NodeAndTrack(node: node, trackIndex: editTrackIndex)
    }
    func moveNode(from oldIndex: Int, fromParemt oldParent: Node,
                  to index: Int, toParent parent: Node) {
        let node = oldParent.children[oldIndex]
        let moveAnimationEditors = self.animationEditors(with: node)
        let oldAnimationIndex = self.nodeAndTrackIndex(with: NodeAndTrack(node: node, trackIndex: 0))
        
        let nodeAndTrack = parent.children.count == 0 || index - 1 < 0 ?
            NodeAndTrack(node: parent, trackIndex: 0) :
            NodeAndTrack(node: parent.children[index - 1], trackIndex: 0)
        let animationIndex = self.nodeAndTrackIndex(with: nodeAndTrack) + 1
        let newAnimationIndex = oldAnimationIndex < animationIndex ?
            animationIndex - moveAnimationEditors.count : animationIndex
        
        oldParent.children.remove(at: oldIndex)
        parent.children.insert(node, at: parent == oldParent && oldIndex < index ? index - 1 : index)
        
        var animationEditors = self.animationEditors
        animationEditors.removeSubrange(
            oldAnimationIndex..<(animationIndex + moveAnimationEditors.count))
        animationEditors.insert(contentsOf: moveAnimationEditors, at: newAnimationIndex)
        self.animationEditors = animationEditors
        updateChildren()
    }
    func moveTrack(from oldIndex: Int, to index: Int, in node: Node) {
        let editTrack = node.tracks[oldIndex]
        var tracks = node.tracks
        tracks.remove(at: oldIndex)
        tracks.insert(editTrack, at: oldIndex < index ? index - 1 : index)
        node.tracks = tracks
        
        let oldAnimationIndex = nodeAndTrackIndex(with: NodeAndTrack(node: node, trackIndex: oldIndex))
        let animationIndex = nodeAndTrackIndex(with: NodeAndTrack(node: node, trackIndex: index))
        let editAnimationEditor = self.animationEditors[oldAnimationIndex]
        let newAnimationIndex = oldAnimationIndex < animationIndex ?
            animationIndex - 1 : animationIndex
        var animationEditors = self.animationEditors
        animationEditors.remove(at: oldAnimationIndex)
        animationEditors.insert(editAnimationEditor, at: newAnimationIndex)
        self.animationEditors = animationEditors
        updateChildren()
    }
    
    var disabledRegisterUndo = true
    
    var removeTrackHandler: ((CutEditor, Int, Node) -> ())?
    func removeTrack() {
        let node = cutItem.cut.editNode
        if node.tracks.count > 1 {
            removeTrackHandler?(self, node.editTrackIndex, node)
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [cutItem.cut.copied])
    }
    
    var pasteHandler: ((CutEditor, CopiedObject) -> (Bool))?
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        return pasteHandler?(self, copiedObject) ?? false
    }
    
    var deleteHandler: ((CutEditor) -> (Bool))?
    func delete(with event: KeyInputEvent) -> Bool {
        return deleteHandler?(self) ?? false
    }
    
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        if (event.sendType == .begin && p.x >= editAnimationEditor.frame.maxX) ||
            event.sendType != .begin {
            
            return editAnimationEditor.move(with: event)
        } else {
            return false
        }
    }
    
    private var isScrollTrack = false
    func scroll(with event: ScrollEvent) -> Bool {
        if event.sendType  == .begin {
            isScrollTrack = abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        guard isScrollTrack else {
            return false
        }
        scrollTrack(with: event)
        return true
    }
    
    struct ScrollBinding {
        let cutEditor: CutEditor
        let nodeAndTrack: NodeAndTrack, oldNodeAndTrack: NodeAndTrack
        let type: Action.SendType
    }
    var scrollHandler: ((ScrollBinding) -> ())?
    
    private struct ScrollObject {
        var oldP = CGPoint(), deltaScrollY = 0.0.cf
        var nodeAndTrackIndex = 0, oldNodeAndTrackIndex = 0
        var oldNodeAndTrack: NodeAndTrack?
    }
    private var scrollObject = ScrollObject()
    func scrollTrack(with event: ScrollEvent) {
        guard event.scrollMomentumType == nil else {
            return
        }
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            scrollObject = ScrollObject()
            scrollObject.oldP = p
            scrollObject.deltaScrollY = 0
            let editNodeAndTrack = self.editNodeAndTrack
            scrollObject.oldNodeAndTrack = editNodeAndTrack
            scrollObject.oldNodeAndTrackIndex = nodeAndTrackIndex(with: editNodeAndTrack)
            scrollHandler?(ScrollBinding(cutEditor: self,
                                         nodeAndTrack: editNodeAndTrack,
                                         oldNodeAndTrack: editNodeAndTrack,
                                         type: .begin))
        case .sending:
            guard let oldEditNodeAndTrack = scrollObject.oldNodeAndTrack else {
                return
            }
            scrollObject.deltaScrollY += event.scrollDeltaPoint.y
            let maxIndex = maxNodeAndTrackIndex
            let i = (scrollObject.oldNodeAndTrackIndex - Int(scrollObject.deltaScrollY / 10))
                .clip(min: 0, max: maxIndex)
            if i != scrollObject.nodeAndTrackIndex {
                isUseUpdateChildren = false
                scrollObject.nodeAndTrackIndex = i
                editNodeAndTrack = nodeAndTrack(atNodeAndTrackIndex: i)
                scrollHandler?(ScrollBinding(cutEditor: self,
                                             nodeAndTrack: editNodeAndTrack,
                                             oldNodeAndTrack: oldEditNodeAndTrack,
                                             type: .sending))
                isUseUpdateChildren = true
            }
        case .end:
            guard let oldEditNodeAndTrack = scrollObject.oldNodeAndTrack else {
                return
            }
            scrollObject.deltaScrollY += event.scrollDeltaPoint.y
            let maxIndex = maxNodeAndTrackIndex
            let i = (scrollObject.oldNodeAndTrackIndex - Int(scrollObject.deltaScrollY / 10))
                .clip(min: 0, max: maxIndex)
            isUseUpdateChildren = false
            editNodeAndTrack = nodeAndTrack(atNodeAndTrackIndex: i)
            scrollHandler?(ScrollBinding(cutEditor: self,
                                         nodeAndTrack: editNodeAndTrack,
                                         oldNodeAndTrack: oldEditNodeAndTrack,
                                         type: .end))
            isUseUpdateChildren = true
            if i != scrollObject.oldNodeAndTrackIndex {
                registeringUndoManager?.registerUndo(withTarget: self) { [old = editNodeAndTrack] in
                    $0.set(oldEditNodeAndTrack, old: old)
                }
            }
            scrollObject.oldNodeAndTrack = nil
        }
    }
    private func set(_ editNodeAndTrack: NodeAndTrack, old oldEditNodeAndTrack: NodeAndTrack) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldEditNodeAndTrack, old: editNodeAndTrack)
        }
        scrollHandler?(ScrollBinding(cutEditor: self,
                                     nodeAndTrack: oldEditNodeAndTrack,
                                     oldNodeAndTrack: oldEditNodeAndTrack,
                                     type: .begin))
        isUseUpdateChildren = false
        self.editNodeAndTrack = editNodeAndTrack
        scrollHandler?(ScrollBinding(cutEditor: self,
                                     nodeAndTrack: oldEditNodeAndTrack,
                                     oldNodeAndTrack: editNodeAndTrack,
                                     type: .end))
        isUseUpdateChildren = true
    }
}
