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
 # Issue
 前後キーフレームからの傾斜スナップ
 */

import CoreGraphics
import QuartzCore

struct Easing: Codable {
    var cp0 = CGPoint(), cp1 = CGPoint(x: 1, y: 1)
    
    func with(cp0: CGPoint) -> Easing {
        return Easing(cp0: cp0, cp1: cp1)
    }
    func with(cp1: CGPoint) -> Easing {
        return Easing(cp0: cp0, cp1: cp1)
    }
    
    func split(with t: CGFloat) -> (b0: Easing, b1: Easing) {
        guard !isDefault else {
            return (Easing(), Easing())
        }
        let sb = bezier.split(withT: t)
        let p = sb.b0.p1
        let b0Affine = CGAffineTransform(scaleX: 1 / p.x, y: 1 / p.y)
        let b1Affine = CGAffineTransform(scaleX: 1 / (1 - p.x),
                                         y: 1 / (1 - p.y)).translatedBy(x: -p.x, y: -p.y)
        let nb0 = Easing(cp0: sb.b0.cp0.applying(b0Affine), cp1: sb.b0.cp1.applying(b0Affine))
        let nb1 = Easing(cp0: sb.b1.cp0.applying(b1Affine), cp1: sb.b1.cp1.applying(b1Affine))
        return (nb0, nb1)
    }
    func convertT(_ t: CGFloat) -> CGFloat {
        return bezier.y(withX: t)
    }
    var bezier: Bezier3 {
        return Bezier3(p0: CGPoint(), cp0: cp0, cp1: cp1, p1: CGPoint(x: 1, y: 1))
    }
    var isDefault: Bool {
        return cp0 == CGPoint() && cp1 == CGPoint(x: 1, y: 1)
    }
    var isLinear: Bool {
        return cp0.x == cp0.y && cp1.x == cp1.y
    }
    func path(in pb: CGRect) -> CGPath {
        let b = bezier
        let cp0 = CGPoint(x: pb.minX + b.cp0.x * pb.width, y: pb.minY + b.cp0.y * pb.height)
        let cp1 = CGPoint(x: pb.minX + b.cp1.x * pb.width, y: pb.minY + b.cp1.y * pb.height)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: pb.minX, y: pb.minY))
        path.addCurve(to: CGPoint(x: pb.maxX, y: pb.maxY), control1: cp0, control2: cp1)
        return path
    }
}
extension Easing: Equatable {
    static func ==(lhs: Easing, rhs: Easing) -> Bool {
        return lhs.cp0 == rhs.cp0 && lhs.cp1 == rhs.cp1
    }
}
extension Easing: Referenceable {
    static let name = Localization(english: "Easing", japanese: "イージング")
}
extension Easing: Drawable {
    func responder(with bounds: CGRect) -> Respondable {
        let drawLayer = DrawLayer()
        drawLayer.drawBlock = { [unowned drawLayer] ctx in
            self.draw(with: drawLayer.bounds, in: ctx)
        }
        return GroupResponder(layer: drawLayer, frame: bounds)
    }
    func draw(with bounds: CGRect, in ctx: CGContext) {
        let path = self.path(in: bounds.inset(by: 5))
        ctx.addPath(path)
        ctx.setStrokeColor(Color.font.cgColor)
        ctx.setLineWidth(2)
        ctx.strokePath()
    }
}

final class EasingEditor: LayerRespondable {
    static let name = Localization(english: "Easing Editor", japanese: "イージングエディタ")
    static let feature = Localization(english: "Horizontal axis: Time\nVertical axis: Correction time",
                                      japanese: "横軸: 時間\n縦軸: 補正後の時間")
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]()
    
    private let axisLayer = CAShapeLayer(), easingLayer = CAShapeLayer()
    private let knobLineLayer = CAShapeLayer()
    let cp0Editor = PointEditor(description: Localization(english: "Control Point0",
                                                          japanese: "コントロールポイント0"))
    let cp1Editor = PointEditor(description: Localization(english: "Control Point1",
                                                          japanese: "コントロールポイント1"))
    let xLabel = Label(text: Localization("t"))
    let yLabel = Label(text: Localization("t'"))
    let layer = CALayer.interface()
    init(frame: CGRect = CGRect(), description: Localization = Localization()) {
        self.instanceDescription = description
        layer.frame = frame
        
        axisLayer.fillColor = nil
        axisLayer.strokeColor = Color.content.cgColor
        axisLayer.lineWidth = 1
        
        knobLineLayer.fillColor = nil
        knobLineLayer.strokeColor = Color.content.cgColor
        knobLineLayer.lineWidth = 1
        
        easingLayer.fillColor = nil
        easingLayer.strokeColor = Color.content.cgColor
        easingLayer.lineWidth = 2
        
        replace(children: [xLabel, yLabel, cp0Editor, cp1Editor])
        layer.sublayers = [xLabel.layer, yLabel.layer,
                           knobLineLayer, easingLayer, axisLayer,
                           cp0Editor.layer, cp1Editor.layer]
        update(with: bounds)
        
        cp0Editor.setPointHandler = { [unowned self] in self.setEasing(with: $0) }
        cp1Editor.setPointHandler = { [unowned self] in self.setEasing(with: $0) }
    }
    
    var padding = Layout.basicPadding {
        didSet {
            update(with: bounds)
        }
    }
    func update(with bounds: CGRect) {
        cp0Editor.frame = CGRect(x: padding,
                                 y: padding,
                                 width: (frame.width - padding * 2) / 2,
                                 height: (frame.height - padding * 2) / 2)
        cp1Editor.frame = CGRect(x: frame.width / 2,
                                 y: padding + (frame.height - padding * 2) / 2,
                                 width: (frame.width - padding * 2) / 2,
                                 height: (frame.height - padding * 2) / 2)
        let path = CGMutablePath()
        let sp = Layout.smallPadding
        path.addLines(between: [CGPoint(x: padding + cp0Editor.padding,
                                        y: frame.height - padding - yLabel.frame.height - sp),
                                CGPoint(x: padding + cp0Editor.padding,
                                        y: padding + cp0Editor.padding),
                                CGPoint(x: frame.width - padding - xLabel.frame.width - sp,
                                        y: padding + cp0Editor.padding)])
        axisLayer.path = path
        xLabel.frame.origin = CGPoint(x: frame.width - padding - xLabel.frame.width,
                                      y: padding)
        yLabel.frame.origin = CGPoint(x: padding,
                                      y: frame.height - padding - yLabel.frame.height)
        updateEasingLayer()
    }
    func updateEasingLayer() {
        guard !bounds.isEmpty else {
            return
        }
        cp0Editor.point = easing.cp0
        cp1Editor.point = easing.cp1
        easingLayer.path = easing.path(in: bounds.insetBy(dx: padding + cp0Editor.padding,
                                                          dy: padding + cp0Editor.padding))
        let knobLinePath = CGMutablePath()
        knobLinePath.addLines(between: [CGPoint(x: cp0Editor.frame.minX + cp0Editor.padding,
                                                y: cp0Editor.frame.minY + cp0Editor.padding),
                                        cp0Editor.knobLayer.position + cp0Editor.frame.origin])
        knobLinePath.addLines(between: [CGPoint(x: cp1Editor.frame.maxX - cp1Editor.padding,
                                                y: cp1Editor.frame.maxY - cp1Editor.padding),
                                        cp1Editor.knobLayer.position + cp1Editor.frame.origin])
        knobLineLayer.path = knobLinePath
    }
    
    var easing = Easing() {
        didSet {
            if easing != oldValue {
                updateEasingLayer()
            }
        }
    }
    
    var disabledRegisterUndo = false
    
    struct HandlerObject {
       let easingEditor: EasingEditor, easing: Easing, oldEasing: Easing, type: Action.SendType
    }
    var setEasingHandler: ((HandlerObject) -> ())?
    
    private func setEasing(with obj: PointEditor.HandlerObject) {
        if obj.type == .begin {
            oldEasing = easing
            setEasingHandler?(HandlerObject(easingEditor: self,
                                            easing: oldEasing, oldEasing: oldEasing, type: .begin))
        } else {
            easing = obj.pointEditor == cp0Editor ?
                easing.with(cp0: obj.point) : easing.with(cp1: obj.point)
            setEasingHandler?(HandlerObject(easingEditor: self,
                                            easing: easing, oldEasing: oldEasing, type: obj.type))
        }
    }
    
    private var oldEasing = Easing()
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [easing])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let easing = object as? Easing {
                guard easing != self.easing else {
                    continue
                }
                set(easing, oldEasing: self.easing)
                return
            }
        }
    }
    func delete(with event: KeyInputEvent) {
        let easing = Easing()
        guard easing != self.easing else {
            return
        }
        set(easing, oldEasing: self.easing)
    }
    
    func set(_ easing: Easing, oldEasing: Easing) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldEasing, oldEasing: easing) }
        setEasingHandler?(HandlerObject(easingEditor: self,
                                        easing: oldEasing, oldEasing: oldEasing, type: .begin))
        self.easing = easing
        setEasingHandler?(HandlerObject(easingEditor: self,
                                        easing: easing, oldEasing: oldEasing, type: .end))
    }
}
