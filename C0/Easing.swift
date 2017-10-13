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

struct Easing: Equatable, ByteCoding, Referenceable, Drawable {
    static let type = ObjectType(identifier: "Easing", name: Localization(english: "Easing", japanese: "イージング"))
    let cp0: CGPoint, cp1: CGPoint
    
    init(cp0: CGPoint = CGPoint(), cp1: CGPoint = CGPoint(x: 1, y: 1)) {
        self.cp0 = cp0
        self.cp1 = cp1
    }
    
    func split(with t: CGFloat) -> (b0: Easing, b1: Easing) {
        if isDefault {
            return (Easing(), Easing())
        }
        let sb = bezier.split(withT: t)
        let p = sb.b0.p1
        let b0Affine = CGAffineTransform(scaleX: 1/p.x, y: 1/p.y)
        let b1Affine = CGAffineTransform(scaleX: 1/(1 - p.x), y: 1/(1 - p.y)).translatedBy(x: -p.x, y: -p.y)
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
    static func == (lhs: Easing, rhs: Easing) -> Bool {
        return lhs.cp0 == rhs.cp0 && lhs.cp1 == rhs.cp1
    }
    func path(in pb: CGRect) -> CGPath {
        let b = bezier
        let cp1 = CGPoint(x: pb.minX + b.cp0.x*pb.width, y: pb.minY + b.cp0.y*pb.height), cp2 = CGPoint(x: pb.minX + b.cp1.x*pb.width, y: pb.minY + b.cp1.y*pb.height)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: pb.minX, y: pb.minY))
        path.addCurve(to: CGPoint(x: pb.maxX, y: pb.maxY), control1: cp1, control2: cp2)
        return path
    }
    
    func draw(with bounds: CGRect, in ctx: CGContext) {
        let path = self.path(in: bounds.inset(by: 5))
        ctx.addPath(path)
        ctx.setStrokeColor(Defaults.fontColor.cgColor)
        ctx.setLineWidth(2)
        ctx.strokePath()
    }
}

protocol EasingEditorDelegate: class {
    func changeEasing(_ easingEditor: EasingEditor, easing: Easing, oldEasing: Easing, type: Action.SendType)
}
final class EasingEditor: LayerRespondable {
    static let type = ObjectType(identifier: "EasingEditor", name: Localization(english: "Easing Editor", japanese: "イージングエディタ"))
    static let description = Localization(english: "Horizontal: Time, Vertical axis: Correction time", japanese: "横軸: 時間, 縦軸: 補正後の時間")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: EasingEditorDelegate?
    
    private let paddingSize = CGSize(width: 10, height: 7)
    private let cp0BackLayer = CALayer(), cp1BackLayer = CALayer(), easingLayer = CAShapeLayer()
    private let cp0KnobLayer = CALayer.knobLayer(), cp1KnobLayer = CALayer.knobLayer(), axisLayer = CAShapeLayer()
    
    let layer = CALayer.interfaceLayer()
    init(frame: CGRect = CGRect()) {
        layer.frame = frame
        
        easingLayer.fillColor = nil
        easingLayer.strokeColor = Defaults.contentEditColor.cgColor
        easingLayer.lineWidth = 2
        
        cp0BackLayer.backgroundColor = Defaults.subEditColor.cgColor
        cp1BackLayer.backgroundColor = Defaults.subEditColor.cgColor
        cp0BackLayer.frame = CGRect(x: paddingSize.width, y: paddingSize.height, width: (frame.width - paddingSize.width*2)/2, height: (frame.height - paddingSize.height*2)/2)
        cp1BackLayer.frame = CGRect(x: frame.width/2, y: paddingSize.height + (frame.height - paddingSize.height*2)/2, width: (frame.width - paddingSize.width*2)/2, height: (frame.height - paddingSize.height*2)/2)
        
        axisLayer.fillColor = nil
        axisLayer.strokeColor = Defaults.contentEditColor.cgColor
        axisLayer.lineWidth = 1
        let path = CGMutablePath()
        path.addLines(between: [
            CGPoint(x: paddingSize.width, y: frame.height - paddingSize.height),
            CGPoint(x: paddingSize.width, y: paddingSize.height),
            CGPoint(x: frame.width - paddingSize.width, y: paddingSize.height)
            ])
        axisLayer.path = path
        layer.sublayers = [cp0BackLayer, cp1BackLayer, axisLayer, easingLayer, cp0KnobLayer, cp1KnobLayer]
        updateSublayers()
    }
    
    private func updateSublayers() {
        CATransaction.disableAnimation {
            let cp0pb = cp0BackLayer.frame, cp1pb = cp1BackLayer.frame
            cp0KnobLayer.position = CGPoint(x: cp0pb.minX + easing.cp0.x*cp0pb.width, y: cp0pb.minY + easing.cp0.y*cp0pb.height)
            cp1KnobLayer.position = CGPoint(x: cp1pb.minX + easing.cp1.x*cp1pb.width, y: cp1pb.minY + easing.cp1.y*cp1pb.height)
            easingLayer.path = easing.path(in: bounds.insetBy(dx: paddingSize.width, dy: paddingSize.height))
        }
    }
    private enum EasingControl {
        case cp0, cp1
    }
    private func easingControl(with p: CGPoint) -> EasingControl {
        let px = p.x - paddingSize.width, py = p.y - paddingSize.height
        let w = bounds.width - paddingSize.width*2, h = bounds.height - paddingSize.height*2
        return py < -(h/w)*px + h ? .cp0 : .cp1
    }
    private func cp0(with point: CGPoint) -> CGPoint {
        let pb = cp0BackLayer.frame
        return CGPoint(x: ((point.x - pb.minX)/pb.width).clip(min: 0, max: 1), y: ((point.y - pb.minY)/pb.height).clip(min: 0, max: 1))
    }
    private func cp1(with point: CGPoint) -> CGPoint {
        let pb = cp1BackLayer.frame
        return CGPoint(x: ((point.x - pb.minX)/pb.width).clip(min: 0, max: 1), y: ((point.y - pb.minY)/pb.height).clip(min: 0, max: 1))
    }
    
    var easing = Easing() {
        didSet {
            updateSublayers()
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(datas: [Easing.type: [easing.data]], object: easing)
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        if let data = copyObject.datas[Easing.type]?.first {
            oldEasing = easing
            delegate?.changeEasing(self, easing: easing, oldEasing: oldEasing, type: .begin)
            easing = Easing(data: data)
            delegate?.changeEasing(self, easing: easing, oldEasing: oldEasing, type: .end)
        }
    }
    func delete(with event: KeyInputEvent) {
        oldEasing = easing
        let newEasing = Easing()
        if oldEasing != newEasing {
            oldCp = easing.cp0
            delegate?.changeEasing(self, easing: easing, oldEasing: oldEasing, type: .begin)
            easing = Easing()
            delegate?.changeEasing(self, easing: easing, oldEasing: oldEasing, type: .end)
        }
    }
    private var oldEasing = Easing(), oldCp = CGPoint(), ec = EasingControl.cp0
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldEasing = easing
            oldCp = easing.cp0
            ec = easingControl(with: p)
            delegate?.changeEasing(self, easing: easing, oldEasing: oldEasing, type: .begin)
            setEasingWith(p, ec)
            delegate?.changeEasing(self, easing: easing, oldEasing: oldEasing, type: .sending)
            switch ec {
            case .cp0:
                cp0KnobLayer.backgroundColor = Defaults.editingColor.cgColor
            case .cp1:
                cp1KnobLayer.backgroundColor = Defaults.editingColor.cgColor
            }
        case .sending:
            setEasingWith(p, ec)
            delegate?.changeEasing(self, easing: easing, oldEasing: oldEasing, type: .sending)
        case .end:
            setEasingWith(p, ec)
            delegate?.changeEasing(self, easing: easing, oldEasing: oldEasing, type: .end)
            switch ec {
            case .cp0:
                cp0KnobLayer.backgroundColor = Defaults.contentColor.cgColor
            case .cp1:
                cp1KnobLayer.backgroundColor = Defaults.contentColor.cgColor
            }
        }
    }
    private func setEasingWith(_ p: CGPoint, _ ec: EasingControl) {
        switch ec {
        case .cp0:
            easing = Easing(cp0: cp0(with: p), cp1: oldEasing.cp1)
        case .cp1:
            easing = Easing(cp0: oldEasing.cp0, cp1: cp1(with: p))
        }
    }
}
