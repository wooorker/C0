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

class Layer: Referenceable {
    static let name = Localization(english: "Layer", japanese: "レイヤー")
    var instanceDescription = Localization()
    
    var caLayer = CALayer.interface()
    init() {
    }
    
    weak var parent: Layer?
    private(set) var children = [Layer]()
    func append(child: Layer) {
        child.removeFromParent()
        caLayer.addSublayer(child.caLayer)
        children.append(child)
        child.parent = self
        child.allChildrenAndSelf { $0.contentsScale = contentsScale }
    }
    func insert(child: Layer, at index: Int) {
        child.removeFromParent()
        caLayer.insertSublayer(child.caLayer, at: UInt32(index))
        children.insert(child, at: index)
        child.parent = self
        child.allChildrenAndSelf { $0.contentsScale = contentsScale }
    }
    func replace(children: [Layer]) {
        let oldChildren = self.children
        oldChildren.forEach { child in
            if !children.contains(where: { $0 === child }) {
                child.removeFromParent()
            }
        }
        caLayer.sublayers = children.flatMap { $0.caLayer }
        self.children = children
        children.forEach {
            $0.parent = self
            $0.allChildrenAndSelf { child in child.contentsScale = contentsScale }
        }
    }
    func removeFromParent() {
        guard let parent = parent else {
            return
        }
        if let index = parent.children.index(where: { $0 === self }) {
            parent.children.remove(at: index)
        }
        self.parent = nil
    }
    func allChildrenAndSelf(_ handler: (Layer) -> Void) {
        func allChildrenRecursion(_ child: Layer, _ handler: (Layer) -> Void) {
            child.children.forEach { allChildrenRecursion($0, handler) }
            handler(child)
        }
        allChildrenRecursion(self, handler)
    }
    func allParentsAndSelf(handler: (Layer) -> Void) {
        handler(self)
        parent?.allParentsAndSelf(handler: handler)
    }
    var root: Layer {
        return parent?.root ?? self
    }
    
    var isIndication = false
    var isSubIndication = false
    weak var indicationParent: Layer?
    func allIndicationParentsAndSelf(handler: (Layer) -> Void) {
        handler(self)
        (indicationParent ?? parent)?.allIndicationParentsAndSelf(handler: handler)
    }
    
    var dataModel: DataModel? {
        didSet {
            children.forEach { $0.dataModel = dataModel }
        }
    }
    
    var editQuasimode = EditQuasimode.none
    var cursor: Cursor {
        return Cursor.arrow
    }
    var cursorPoint: CGPoint {
        if let parent = parent {
            return convert(parent.cursorPoint, from: parent)
        } else {
            return CGPoint()
        }
    }
    
    var editBounds: CGRect {
        return CGRect()
    }
    private var useDidSetBounds = true, useDidSetFrame = true
    var bounds = CGRect() {
        didSet {
            guard useDidSetBounds && bounds != oldValue else {
                return
            }
            useDidSetFrame = false
            frame.size = bounds.size
            caLayer.bounds = bounds
            useDidSetFrame = true
        }
    }
    var frame = CGRect() {
        didSet {
            guard useDidSetFrame && frame != oldValue else {
                return
            }
            useDidSetBounds = false
            bounds.size = frame.size
            caLayer.frame = frame
            useDidSetBounds = true
        }
    }
    var path: CGPath? {
        get {
            return (caLayer as? CAShapeLayer)?.path
        }
        set {
            (caLayer as? CAShapeLayer)?.path = newValue
        }
    }
    var filters: [CIFilter] {
        get {
            return (caLayer.filters as? [CIFilter]) ?? []
        }
        set {
            caLayer.filters = newValue
        }
    }
    var blendType: CIFilter? {
        get {
            return caLayer.compositingFilter as? CIFilter
        }
        set {
            caLayer.compositingFilter = newValue
        }
    }
    
    var contentsScale = 1.0.cf {
        didSet {
            caLayer.contentsScale = contentsScale
            children.forEach { $0.contentsScale = contentsScale }
        }
    }
    
    func updateBorder(isIndication: Bool) {
        borderLayer.borderColor = isIndication ? Color.indication.cgColor : defaultBorderColor
        borderLayer.borderWidth = defaultBorderColor == nil ? (isIndication ? 0.5 : 0) : 0.5
    }
    var borderLayer: CALayer {
        return caLayer
    }
    var defaultBorderColor: CGColor? {
        return Color.border.cgColor
    }
    
    func contains(_ p: CGPoint) -> Bool {
        return bounds.contains(p)
    }
    func at(_ point: CGPoint) -> Layer? {
        guard contains(point) else {
            return nil
        }
        for child in children.reversed() {
            let inPoint = child.convert(point, from: self)
            if let layer = child.at(inPoint) {
                return layer
            }
        }
        return self
    }
    func point(from event: Event) -> CGPoint {
        return convert(event.location, from: nil)
    }
    func convert(_ point: CGPoint, from layer: Layer?) -> CGPoint {
        guard self !== layer else {
            return point
        }
        let result = layer?.convertToRoot(point, stop: self) ?? (point: point, isRoot: true)
        return !result.isRoot ?
            result.point : result.point - convertToRoot(CGPoint(), stop: nil).point
    }
    func convert(_ point: CGPoint, to layer: Layer?) -> CGPoint {
        guard self !== layer else {
            return point
        }
        let result = convertToRoot(point, stop: layer)
        if !result.isRoot {
            return result.point
        } else if let layer = layer {
            return result.point - layer.convertToRoot(CGPoint(), stop: nil).point
        } else {
            return result.point
        }
    }
    private func convertToRoot(_ point: CGPoint,
                               stop layer: Layer?) -> (point: CGPoint, isRoot: Bool) {
        if let parent = parent {
            let parentPoint = point - bounds.origin + frame.origin
            return parent === layer ?
                (parentPoint, false) : parent.convertToRoot(parentPoint, stop: layer)
        } else {
            return (point, true)
        }
    }
    func convert(_ rect: CGRect, from layer: Layer?) -> CGRect {
        return CGRect(origin: convert(rect.origin, from: layer), size: rect.size)
    }
    func convert(_ rect: CGRect, to layer: Layer?) -> CGRect {
        return CGRect(origin: convert(rect.origin, to: layer), size: rect.size)
    }
    
    var undoManager: UndoManager?
    var disabledRegisterUndo = false
    var registeringUndoManager: UndoManager? {
        return disabledRegisterUndo ? nil : undoManager ?? parent?.undoManager
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return parent?.copy(with: event) ?? CopiedObject()
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        parent?.paste(copiedObject, with: event)
    }
    func delete(with event: KeyInputEvent) {
        parent?.delete(with: event)
    }
    func new(with event: KeyInputEvent) {
        parent?.new(with: event)
    }
    
    func selectAll(with event: KeyInputEvent) {
        parent?.selectAll(with: event)
    }
    func deselectAll(with event: KeyInputEvent) {
        parent?.deselectAll(with: event)
    }
    func select(with event: DragEvent) {
        parent?.select(with: event)
    }
    func deselect(with event: DragEvent) {
        parent?.deselect(with: event)
    }
    
    func moveZ(with event: DragEvent) {
        parent?.moveZ(with: event)
    }
    func move(with event: DragEvent) {
        parent?.move(with: event)
    }
    func warp(with event: DragEvent) {
        parent?.warp(with: event)
    }
    func transform(with event: DragEvent) {
        parent?.transform(with: event)
    }
    
    func moveCursor(with event: MoveEvent) {
        parent?.moveCursor(with: event)
    }
    func keyInput(with event: KeyInputEvent) {
        parent?.keyInput(with: event)
    }
    func click(with event: ClickEvent) {
        parent?.click(with: event)
    }
    func bind(with event: RightClickEvent) {
        parent?.bind(with: event)
    }
    func drag(with event: DragEvent) {
        parent?.drag(with: event)
    }
    func scroll(with event: ScrollEvent) {
        parent?.scroll(with: event)
    }
    func zoom(with event: PinchEvent) {
        parent?.zoom(with: event)
    }
    func rotate(with event: RotateEvent) {
        parent?.rotate(with: event)
    }
    func reset(with event: DoubleTapEvent) {
        parent?.reset(with: event)
    }
    func lookUp(with event: TapEvent) -> Referenceable {
        return self
    }
    
    func addPoint(with event: KeyInputEvent) {
        parent?.addPoint(with: event)
    }
    func deletePoint(with event: KeyInputEvent) {
        parent?.deletePoint(with: event)
    }
    func movePoint(with event: DragEvent) {
        parent?.movePoint(with: event)
    }
    func moveVertex(with event: DragEvent) {
        parent?.moveVertex(with: event)
    }
    
    func lassoDelete(with event: DragEvent) {
        parent?.lassoDelete(with: event)
    }
}

final class DrawLayer: CALayer {
    init(backgroundColor: Color = .background, borderColor: Color? = .border) {
        super.init()
        self.contentsScale = GlobalVariable.shared.backingScaleFactor
        self.needsDisplayOnBoundsChange = true
        self.drawsAsynchronously = true
        self.anchorPoint = CGPoint()
        self.isOpaque = true
        self.borderWidth = 0.5
        self.backgroundColor = backgroundColor.cgColor
        self.borderColor = borderColor?.cgColor ?? self.backgroundColor
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
    override var backgroundColor: CGColor? {
        didSet {
            if backgroundColor == nil {
                self.borderColor = Color(white: 0, alpha: 0).cgColor
                self.isOpaque = false
            } else {
                self.borderColor = backgroundColor
                self.isOpaque = true
            }
            setNeedsDisplay()
        }
    }
    override var contentsScale: CGFloat {
        didSet {
            setNeedsDisplay()
        }
    }
    var drawBlock: ((_ in: CGContext) -> Void)?
    override func draw(in ctx: CGContext) {
        if let backgroundColor = backgroundColor {
            ctx.setFillColor(backgroundColor)
            ctx.fill(ctx.boundingBoxOfClipPath)
        }
        drawBlock?(ctx)
    }
}

extension CALayer {
    static let disableAnimationActions = ["backgroundColor": NSNull(),
                                          "content": NSNull(),
                                          "sublayers": NSNull(),
                                          "frame": NSNull(),
                                          "bounds": NSNull(),
                                          "position": NSNull(),
                                          "hidden": NSNull(),
                                          "opacity": NSNull(),
                                          "borderColor": NSNull(),
                                          "borderWidth": NSNull()]
    static var disabledAnimation: CALayer {
        let layer = CALayer()
        layer.actions = disableAnimationActions
        return layer
    }
    static func knob(radius r: CGFloat = 5, lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.actions = disableAnimationActions
        layer.backgroundColor = Color.knob.cgColor
        layer.borderColor = Color.border.cgColor
        layer.borderWidth = l
        layer.cornerRadius = r
        layer.bounds = CGRect(x: 0, y: 0, width: r * 2, height: r * 2)
        return layer
    }
    static func discreteKnob(width w: CGFloat = 5, height h: CGFloat = 10,
                           lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.actions = disableAnimationActions
        layer.backgroundColor = Color.knob.cgColor
        layer.borderColor = Color.border.cgColor
        layer.borderWidth = l
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        return layer
    }
    static var selection: CALayer {
        let layer = CALayer()
        layer.actions = disableAnimationActions
        layer.backgroundColor = Color.select.cgColor
        layer.borderColor = Color.selectBorder.cgColor
        layer.borderWidth = 1
        return layer
    }
    static var deselection: CALayer {
        let layer = CALayer()
        layer.actions = disableAnimationActions
        layer.backgroundColor = Color.deselect.cgColor
        layer.borderColor = Color.deselectBorder.cgColor
        layer.borderWidth = 1
        return layer
    }
    static func interface(backgroundColor: Color? = nil,
                          borderColor: Color? = .border) -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        layer.actions = disableAnimationActions
        layer.borderWidth = borderColor == nil ? 0.0 : 0.5
        layer.backgroundColor = backgroundColor?.cgColor
        layer.borderColor = borderColor?.cgColor ?? layer.backgroundColor
        return layer
    }
    
    func allSublayers(_ handler: (CALayer) -> Void) {
        func allSublayersRecursion(_ layer: CALayer, _ handler: (CALayer) -> Void) {
            if let sublayers = layer.sublayers {
                for sublayer in sublayers {
                    allSublayersRecursion(sublayer, handler)
                }
            }
            handler(layer)
        }
        allSublayersRecursion(self, handler)
    }
}

extension CGPath {
    static func checkerboard(with size: CGSize, in frame: CGRect) -> CGPath {
        let path = CGMutablePath()
        let xCount = Int(frame.width / size.width)
        let yCount = Int(frame.height / (size.height * 2))
        for xi in 0 ..< xCount {
            let x = frame.minX + xi.cf * size.width
            let fy = xi % 2 == 0 ? size.height : 0
            for yi in 0 ..< yCount {
                let y = frame.minY + yi.cf * size.height * 2 + fy
                path.addRect(CGRect(x: x, y: y, width: size.width, height: size.height))
            }
        }
        return path
    }
}

extension CGContext {
    static func bitmap(with size: CGSize,
                       colorSpace: CGColorSpace? = CGColorSpace(name: CGColorSpace.sRGB)
        ) -> CGContext? {
        
        guard let colorSpace = colorSpace else {
            return nil
        }
        return CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                         bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                         bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    }
}

extension CGContext {
    func drawBlurWith(color fillColor: Color, width: CGFloat, strength: CGFloat,
                      isLuster: Bool, path: CGPath, scale: CGFloat, rotation: CGFloat) {
        let nFillColor: Color
        if fillColor.alpha < 1 {
            saveGState()
            setAlpha(CGFloat(fillColor.alpha))
            nFillColor = fillColor.with(alpha: 1)
        } else {
            nFillColor = fillColor
        }
        let pathBounds = path.boundingBoxOfPath.insetBy(dx: -width, dy: -width)
        let lineColor = strength == 1 ? nFillColor : nFillColor.multiply(alpha: Double(strength))
        beginTransparencyLayer(in: boundingBoxOfClipPath.intersection(pathBounds),
                               auxiliaryInfo: nil)
        if isLuster {
            setShadow(offset: CGSize(), blur: width * scale, color: lineColor.cgColor)
        } else {
            let shadowY = hypot(pathBounds.size.width, pathBounds.size.height)
            translateBy(x: 0, y: shadowY)
            let shadowOffset = CGSize(width: shadowY * scale * sin(rotation),
                                      height: -shadowY * scale * cos(rotation))
            setShadow(offset: shadowOffset, blur: width * scale / 2, color: lineColor.cgColor)
            setLineWidth(width)
            setLineJoin(.round)
            setStrokeColor(lineColor.cgColor)
            addPath(path)
            strokePath()
            translateBy(x: 0, y: -shadowY)
        }
        setFillColor(nFillColor.cgColor)
        addPath(path)
        fillPath()
        endTransparencyLayer()
        if fillColor.alpha < 1 {
            restoreGState()
        }
    }
}
