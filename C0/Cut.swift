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
        editMaterial, changingMaterial
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
                font: .bold, color: .warning
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

final class CutEditor: LayerRespondable, Equatable {
    static let name = Localization(english: "Cut Editor", japanese: "カットエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    let animationEditor: AnimationEditor
    let layer = CALayer.interface(borderColor: nil)
    let borderLayer = CALayer.interface(backgroundColor: nil)
    let cutItem: CutItem
    init(_ cutItem: CutItem, baseWidth: CGFloat,
         timeHeight: CGFloat, knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat,
         maxLineWidth: CGFloat, height: CGFloat) {
        
        self.cutItem = cutItem
        
        let midY = height / 2
        
        let track = cutItem.cut.editNode.editTrack
        
        let ae = AnimationEditor(track.animation, origin: CGPoint(x: 0, y: midY - timeHeight / 2))
        animationEditor = ae
        children = [ae]
        let w = ae.x(withTime: cutItem.cut.duration)
        let index = cutItem.cut.editNode.editTrackIndex, h = 1.0.cf
        let cutBounds = CGRect(x: 0,
                               y: 0,
                               width: w,
                               height: height)
        
        layer.frame = cutBounds
        
        let clipBounds = CGRect(x: cutBounds.minX + 1,
                                y: timeHeight + Layout.basicPadding,
                                width: cutBounds.width - 2,
                                height: cutBounds.height - timeHeight * 2)
        
        let editTrackLayer = CALayer.disabledAnimation
        editTrackLayer.backgroundColor = Color.translucentEdit.cgColor
        editTrackLayer.frame = CGRect(x: clipBounds.minX, y: midY - 4,
                                      width: clipBounds.width, height: 8)
        
        var noEditedLines = [CALayer]()
        var y = midY + timeHeight / 2 + 2
        for i in (0 ..< index).reversed() {
            let lines = CutEditor.noEditedLines(with: cutItem.cut.editNode.tracks[i],
                                                width: w, y: y, h: h,
                                                baseWidth: baseWidth, from: ae)
            noEditedLines += lines
            y += 2 + h
            if y >= clipBounds.maxY {
                break
            }
        }
        y = midY - timeHeight / 2 - 2
        if index + 1 < cutItem.cut.editNode.tracks.count {
            for i in index + 1 ..< cutItem.cut.editNode.tracks.count {
                let lines = CutEditor.noEditedLines(with: cutItem.cut.editNode.tracks[i],
                                                    width: w, y: y - h, h: h,
                                                    baseWidth: baseWidth, from: ae)
                noEditedLines += lines
                y -= 2 + h
                if y <= clipBounds.minY {
                    break
                }
            }
        }
        
        update(withChildren: children, oldChildren: [])
        layer.sublayers = [borderLayer, editTrackLayer] + noEditedLines + [ae.layer]
        
        ae.splitKeyframeLabelHandler = { [unowned self] keyframe, index in
            self.cutItem.cut.editNode.editTrack.isEmptyGeometryWithCells(at: keyframe.time) ?
                .main : .sub
        }
        ae.lineColorHandler = { [unowned self] _ in
            self.cutItem.cut.editNode.editTrack.transformItem != nil ? .camera : .content
        }
        ae.knobColorHandler = { [unowned self] in
            self.cutItem.cut.editNode.editTrack.drawingItem.keyDrawings[$0].roughLines.isEmpty ?
                .knob : .timelineRough
        }
    }
    
    static func noEditedLines(with track: NodeTrack,
                              width: CGFloat, y: CGFloat, h: CGFloat,
                              baseWidth: CGFloat,
                              from animationEditor: AnimationEditor) -> [CALayer] {
        
        let lineColor = track.isHidden ?
            (track.transformItem != nil ? Color.camera.multiply(white: 0.75) : Color.background) :
            (track.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.content)
        let animation = track.animation
        
        let layer = CAShapeLayer()
        layer.fillColor = lineColor.cgColor
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: y, width: width, height: h))
        
        for (i, keyframe) in animation.keyframes.enumerated() {
            if i > 0 {
                let x = animationEditor.x(withTime: keyframe.time)
                path.addRect(CGRect(x: x, y: y - 1, width: baseWidth, height: h + 2))
            }
        }
        layer.path = path
        return [layer]
    }
    
    func update() {
        
    }
    var allKeyframeTimes = [Beat]()
    
    func removeTrackOrCut() {
        let node = cutItem.cut.editNode
        if node.tracks.count > 1 {
//            removeTrack(at: node.editTrackIndex, in: node, in: cutItem)
        }
    }
    
    //NodesEditor
    let itemHeight = 8.0.cf
    private var oldIndex = 0, oldP = CGPoint()
    var moveQuasimode = false
    var oldTracks = [NodeTrack]()
    func move(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldTracks = cutItem.cut.editNode.tracks
            oldIndex = cutItem.cut.editNode.editTrackIndex
            oldP = p
        case .sending:
            let d = p.y - oldP.y
            let i = (oldIndex + Int(d / itemHeight)).clip(min: 0,
                                                          max: cutItem.cut.editNode.tracks.count)
            let oi = cutItem.cut.editNode.editTrackIndex
            let animation = cutItem.cut.editNode.editTrack
            cutItem.cut.editNode.tracks.remove(at: oi)
            cutItem.cut.editNode.tracks.insert(animation, at: oi < i ? i - 1 : i)
            update()
        case .end:
            let d = p.y - oldP.y
            let i = (oldIndex + Int(d / itemHeight)).clip(min: 0,
                                                          max: cutItem.cut.editNode.tracks.count)
            let oi = cutItem.cut.editNode.editTrackIndex
            if oldIndex != i {
                var tracks = cutItem.cut.editNode.tracks
                tracks.remove(at: oi)
                tracks.insert(cutItem.cut.editNode.editTrack, at: oi < i ? i - 1 : i)
//                set(tracks: tracks, oldTracks: oldTracks, in: cutItem, time: time)
            } else if oi != i {
                cutItem.cut.editNode.tracks.remove(at: oi)
                cutItem.cut.editNode.tracks.insert(cutItem.cut.editNode.editTrack,
                                                   at: oi < i ? i - 1 : i)
                update()
            }
            oldTracks = []
        }
    }
    private func set(tracks: [NodeTrack], oldTracks: [NodeTrack],
                     in cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(tracks: oldTracks, oldTracks: tracks, in: cutItem)
        }
        cutItem.cut.editNode.tracks = tracks
        cutItem.cutDataModel.isWrite = true
        update()
    }
    
    var scrollHandler: ((Timeline, CGPoint, ScrollEvent) -> ())?
    private var isTrackScroll = false, deltaScrollY = 0.0.cf, scrollCutItem: CutItem?
    func scroll(with event: ScrollEvent) {
        scroll(with: event, isUseMomentum: true)
    }
    func scroll(with event: ScrollEvent, isUseMomentum: Bool) {
        if event.sendType  == .begin {
            isTrackScroll = cutItem.cut.editNode.tracks.count == 1 ?
                false : abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        guard isTrackScroll else {
            parent?.scroll(with: event)
            return
        }
        guard event.scrollMomentumType == nil else {
            return
        }
        let point = self.point(from: event)
        switch event.sendType {
        case .begin:
            oldIndex = cutItem.cut.editNode.editTrackIndex
            oldP = point
            deltaScrollY = 0
            scrollCutItem = cutItem
        case .sending:
            deltaScrollY += event.scrollDeltaPoint.y
            let maxIndex = cutItem.cut.editNode.tracks.count - 1
            let i = (oldIndex + Int(deltaScrollY / 10)).clip(min: 0, max: maxIndex)
            if cutItem.cut.editNode.editTrackIndex != i {
                cutItem.cut.editNode.editTrackIndex = i
                update()
            }
        case .end:
            guard let scrollCutItem = scrollCutItem else {
                return
            }
            let node = scrollCutItem.cut.editNode
            let i = (oldIndex + Int(deltaScrollY / 10)).clip(min: 0,
                                                             max: node.tracks.count - 1)
            if oldIndex != i {
//                set(editTrackIndex: i, oldEditTrackIndex: oldIndex, in: node)
            } else if node.editTrackIndex != i {
                node.editTrackIndex = i
                update()
            }
            self.scrollCutItem = nil
        }
    }
}

