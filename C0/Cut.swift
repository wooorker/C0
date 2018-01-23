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
    var editNode: Node
    
    var time: Beat {
        didSet {
            rootNode.time = time
        }
    }
    var duration: Beat
    
    init(rootNode: Node = Node(tracks: [NodeTrack(animation: Animation(duration: 0))]),
         editNode: Node = Node(),
         time: Beat = 0) {
       
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
        self.duration = rootNode.maxDuration
        rootNode.time = time
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
    
    let animationEditor: AnimationEditor
    let cutItem: CutItem
    init(_ cutItem: CutItem, baseWidth: CGFloat,
         timeHeight: CGFloat, knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat,
         maxLineWidth: CGFloat, height: CGFloat) {
        
        self.cutItem = cutItem
        self.baseWidth = baseWidth
        self.timeHeight = timeHeight
        self.knobHalfHeight = knobHalfHeight
        self.subKnobHalfHeight = subKnobHalfHeight
        self.maxLineWidth = maxLineWidth
        self.height = height
        
        let midY = height / 2, track = cutItem.cut.editNode.editTrack
        animationEditor = AnimationEditor(track.animation,
                                          beginBaseTime: cutItem.time,
                                          origin: CGPoint(x: 0, y: midY - timeHeight / 2))
        
        super.init()
        replace(children: [animationEditor])
        updateChildren()
        
        animationEditor.splitKeyframeLabelHandler = { [unowned self] keyframe, index in
            self.cutItem.cut.editNode.editTrack.isEmptyGeometryWithCells(at: keyframe.time) ?
                .main : .sub
        }
        animationEditor.lineColorHandler = { [unowned self] _ in
            self.cutItem.cut.editNode.editTrack.transformItem != nil ? .camera : .content
        }
        animationEditor.knobColorHandler = { [unowned self] in
            self.cutItem.cut.editNode.editTrack.drawingItem.keyDrawings[$0].roughLines.isEmpty ?
                .knob : .timelineRough
        }
        animationEditor.noRemovedHandler = { [unowned self] _ in
            self.removeTrack()
            return true
        }
    }
    
    static func noEditedLineLayers(with track: NodeTrack,
                                   width: CGFloat, y: CGFloat, h: CGFloat,
                                   baseWidth: CGFloat, keyHeight: CGFloat = 2,
                                   from animationEditor: AnimationEditor) -> [Layer] {
        
        let lineColor = track.isHidden ?
            (track.transformItem != nil ? Color.camera.multiply(white: 0.75) : Color.background) :
            (track.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.content)
        let animation = track.animation
        
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: y, width: width, height: h))
        for (i, keyframe) in animation.keyframes.enumerated() {
            if i > 0 {
                let x = animationEditor.x(withTime: keyframe.time)
                let w = keyframe.label == .sub ? baseWidth - 4 : baseWidth
                path.addRect(CGRect(x: x - w / 2, y: y - keyHeight / 2,
                                    width: w, height: h + keyHeight))
            }
        }
        
        let layer = PathLayer()
        layer.fillColor = lineColor
        layer.path = path
        return [layer]
    }
    
    var noEditedLines = [Layer]()
    
    var baseWidth: CGFloat {
        didSet {
            animationEditor.baseWidth = baseWidth
            updateChildren()
        }
    }
    let timeHeight: CGFloat, knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat
    let maxLineWidth: CGFloat, height: CGFloat
    
    func updateChildren() {
        let midY = height / 2
        let w = animationEditor.x(withTime: cutItem.cut.duration), h = 1.0.cf
        let maxNodeIndex = cutItem.cut.rootNode.children.count - 1
        let nodeIndex = cutItem.cut.rootNode.children.index(of: cutItem.cut.editNode)!
        let trackIndex = cutItem.cut.editNode.editTrackIndex
        frame.size = CGSize(width: w, height: height)
        
        var noEditedLines = [Layer]()
        var y = midY - timeHeight / 2 - 2
        var ni = nodeIndex, ti = trackIndex
        while ni >= 0 {
            let node = cutItem.cut.rootNode.children[ni]
            for i in (0 ..< ti).reversed() {
                let lines = CutEditor.noEditedLineLayers(with: node.tracks[i],
                                                         width: w, y: y, h: h,
                                                         baseWidth: baseWidth, from: animationEditor)
                noEditedLines += lines
                y -= 2 + h
                if y <= bounds.minY {
                    break
                }
            }
            ni -= 1
            if ni >= 0 {
                ti = cutItem.cut.rootNode.children[ni].tracks.count
            }
            y -= 3
        }
        ni = nodeIndex
        ti = trackIndex + 1
        y = midY + timeHeight / 2 + 2
        while ni <= maxNodeIndex {
            let node = cutItem.cut.rootNode.children[ni]
            if ti < node.tracks.count {
                for i in ti ..< node.tracks.count {
                    let lines = CutEditor.noEditedLineLayers(with: node.tracks[i],
                                                             width: w, y: y - h, h: h,
                                                             baseWidth: baseWidth,
                                                             from: animationEditor)
                    noEditedLines += lines
                    y += 2 + h
                    if y >= bounds.maxY {
                        break
                    }
                }
            }
            ni += 1
            ti = 0
            y += 3
        }
        self.noEditedLines = noEditedLines
        
        replace(children: noEditedLines + [animationEditor])
    }
    func updateWithDuration() {
        cutItem.cut.duration = cutItem.cut.maxDuration
        cutItem.cutDataModel.isWrite = true
        updateChildren()
    }
    func updateWithCutTime() {
        animationEditor.beginBaseTime = cutItem.time
    }
    func updateIfChangedTrack() {
        animationEditor.animation = cutItem.cut.editNode.editTrack.animation
        updateChildren()
    }
    
    struct NodeAndTrack: Equatable {
        let node: Node, trackIndex: Int
        static func ==(lhs: CutEditor.NodeAndTrack, rhs: CutEditor.NodeAndTrack) -> Bool {
            return lhs.node == rhs.node && lhs.trackIndex == rhs.trackIndex
        }
    }
    func nodeAndTrackIndex(with nodeAndTrack: NodeAndTrack) -> Int {
        var index = 0
        func maxNodeAndTrackIndexRecursion(_ node: Node, stop: inout Bool) {
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
        maxNodeAndTrackIndexRecursion(cutItem.cut.rootNode, stop: &stop)
        return index - 1
    }
    func nodeAndTrack(atNodeAndTrackIndex nodeAndTrackIndex: Int) -> NodeAndTrack {
        var index = -1
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
        maxNodeAndTrackIndexRecursion(cutItem.cut.rootNode, stop: &stop)
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
            if isUseUpdateChildren {
                updateIfChangedTrack()
            }
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
    
    private var isScrollTrack = false
    func scroll(with event: ScrollEvent) -> Bool {
        if event.sendType  == .begin {
            isScrollTrack = cutItem.cut.editNode.tracks.count == 1 ?
                false : abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
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
                                                   nodeAndTrack: oldEditNodeAndTrack,
                                                   oldNodeAndTrack: editNodeAndTrack,
                                                   type: .sending))
                isUseUpdateChildren = true
                updateIfChangedTrack()
            }
        case .end:
            guard let oldEditNodeAndTrack = scrollObject.oldNodeAndTrack else {
                return
            }
            scrollObject.deltaScrollY += event.scrollDeltaPoint.y
            let maxIndex = maxNodeAndTrackIndex
            let i = (scrollObject.oldNodeAndTrackIndex - Int(scrollObject.deltaScrollY / 10))
                .clip(min: 0, max: maxIndex)
            if i != scrollObject.nodeAndTrackIndex {
                isUseUpdateChildren = false
                editNodeAndTrack = nodeAndTrack(atNodeAndTrackIndex: i)
                scrollHandler?(ScrollBinding(cutEditor: self,
                                                   nodeAndTrack: oldEditNodeAndTrack,
                                                   oldNodeAndTrack: editNodeAndTrack,
                                                   type: .end))
                isUseUpdateChildren = true
                updateIfChangedTrack()
            }
            if i != scrollObject.oldNodeAndTrackIndex {
                undoManager?.registerUndo(withTarget: self) { [old = editNodeAndTrack] in
                    $0.set(oldEditNodeAndTrack, old: old)
                }
            }
            scrollObject.oldNodeAndTrack = nil
        }
    }
    private func set(_ editNodeAndTrack: NodeAndTrack, old oldEditNodeAndTrack: NodeAndTrack) {
        undoManager?.registerUndo(withTarget: self) {
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
        updateIfChangedTrack()
    }
}
