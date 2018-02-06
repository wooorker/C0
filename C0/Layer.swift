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

protocol Layerable {
    func layer(withBounds bounds: CGRect) -> Layer
}

final class Screen {
    static let shared = Screen()
    var backingScaleFactor = 1.0.cf
}

/**
 # Issue
 ## Version 0.4
 - QuartzCoreを廃止し、MetalでGPUレンダリング
 - リニアワークフロー、マクロ拡散光
 - GradientLayer, PathLayerなどをLayerに統合
 */
class Layer {
    fileprivate var caLayer: CALayer
    init() {
        caLayer = CALayer.interface()
    }
    fileprivate init(_ caLayer: CALayer) {
        self.caLayer = caLayer
    }
    fileprivate init(_ caLayer: CALayer, fillColor: Color?) {
        self.caLayer = caLayer
        self.fillColor = fillColor
    }
    
    class var selection: Layer {
        let layer = Layer()
        layer.fillColor = .select
        layer.lineColor = .selectBorder
        return layer
    }
    static var deselection: Layer {
        let layer = Layer()
        layer.fillColor = .deselect
        layer.lineColor = .deselectBorder
        return layer
    }
    
    private(set) weak var parent: Layer?
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
        children.forEach { child in
            child.parent = self
            child.allChildrenAndSelf { $0.contentsScale = contentsScale }
        }
    }
    func removeFromParent() {
        guard let parent = parent else {
            return
        }
        caLayer.removeFromSuperlayer()
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
    func allParentsAndSelf(handler: (Layer, inout Bool) -> Void) {
        var stop = false
        handler(self, &stop)
        if stop {
            return
        }
        parent?.allParentsAndSelf(handler: handler)
    }
    var root: Layer {
        return parent?.root ?? self
    }
    
    var defaultBounds: CGRect {
        return CGRect()
    }
    private var isUseDidSetBounds = true, isUseDidSetFrame = true
    var bounds = CGRect() {
        didSet {
            guard isUseDidSetBounds && bounds != oldValue else {
                return
            }
            isUseDidSetFrame = false
            frame.size = bounds.size
            caLayer.bounds = bounds
            isUseDidSetFrame = true
        }
    }
    var frame = CGRect() {
        didSet {
            guard isUseDidSetFrame && frame != oldValue else {
                return
            }
            isUseDidSetBounds = false
            bounds.size = frame.size
            caLayer.frame = frame
            isUseDidSetBounds = true
        }
    }
    var position: CGPoint {
        get {
            return caLayer.position
        }
        set {
            caLayer.position = newValue
        }
    }
    
    var isHidden: Bool {
        get {
            return caLayer.isHidden
        }
        set {
            caLayer.isHidden = newValue
        }
    }
    var opacity: CGFloat {
        get {
            return caLayer.opacity.cf
        }
        set {
            caLayer.opacity = Float(newValue)
        }
    }
    
    var cornerRadius: CGFloat {
        get {
            return caLayer.cornerRadius
        }
        set {
            caLayer.cornerRadius = newValue
        }
    }
    var isClipped: Bool {
        get {
            return caLayer.masksToBounds
        }
        set {
            caLayer.masksToBounds = newValue
        }
    }
    
    var image: CGImage? {
        get {
            guard let contents = caLayer.contents else {
                return nil
            }
            return (contents as! CGImage)
        }
        set {
            caLayer.contents = newValue
            if newValue != nil {
                caLayer.minificationFilter = kCAFilterTrilinear
                caLayer.magnificationFilter = kCAFilterTrilinear
            } else {
                caLayer.minificationFilter = kCAFilterLinear
                caLayer.magnificationFilter = kCAFilterLinear
            }
        }
    }
    var fillColor: Color? {
        didSet {
            guard fillColor != oldValue else {
                return
            }
            set(fillColor: fillColor?.cgColor)
        }
    }
    fileprivate func set(fillColor: CGColor?) {
        caLayer.backgroundColor = fillColor
    }
    var contentsScale: CGFloat {
        get {
            return caLayer.contentsScale
        }
        set {
            guard newValue != caLayer.contentsScale else {
                return
            }
            caLayer.contentsScale = newValue
        }
    }
    
    var lineColor: Color? = .border {
        didSet {
            guard lineColor != oldValue else {
                return
            }
            set(lineWidth: lineColor != nil ? lineWidth : 0)
            set(lineColor: lineColor?.cgColor)
        }
    }
    var lineWidth = 0.5.cf {
        didSet {
            set(lineWidth: lineColor != nil ? lineWidth : 0)
        }
    }
    fileprivate func set(lineColor: CGColor?) {
        caLayer.borderColor = lineColor
    }
    fileprivate func set(lineWidth: CGFloat) {
        caLayer.borderWidth = lineWidth
    }
    
    func contains(_ p: CGPoint) -> Bool {
        return bounds.contains(p) && !isHidden
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
    
    var instanceDescription = Localization()
    
    var isIndicated = false {
        didSet {
            updateLineColorWithIsIndicated()
        }
    }
    var noIndicatedLineColor: Color? = .border {
        didSet {
            updateLineColorWithIsIndicated()
        }
    }
    var indicatedLineColor: Color? = .indicated {
        didSet {
            updateLineColorWithIsIndicated()
        }
    }
    private func updateLineColorWithIsIndicated() {
        lineColor = isIndicated ? indicatedLineColor : noIndicatedLineColor
    }
    
    var isSubIndicated = false
    weak var subIndicatedParent: Layer?
    func allSubIndicatedParentsAndSelf(handler: (Layer) -> Void) {
        handler(self)
        (subIndicatedParent ?? parent)?.allSubIndicatedParentsAndSelf(handler: handler)
    }
    
    var undoManager: UndoManager? {
        return subIndicatedParent?.undoManager ?? parent?.undoManager
    }
    
    var dataModel: DataModel? {
        didSet {
            children.forEach { $0.dataModel = dataModel }
        }
    }
    
    var editQuasimode = EditQuasimode.move {
        didSet {
            children.forEach { $0.editQuasimode = editQuasimode }
        }
    }
    
    var cursorPoint: CGPoint {
        if let parent = parent {
            return convert(parent.cursorPoint, from: parent)
        } else {
            return CGPoint()
        }
    }
}
extension Layer: Equatable {
    static func ==(lhs: Layer, rhs: Layer) -> Bool {
        return lhs === rhs
    }
}

class PathLayer: Layer {
    override init() {
        let caLayer = CAShapeLayer()
        caLayer.actions = CALayer.disabledAnimationActions
        caShapeLayer = caLayer
        super.init(caLayer)
        caLayer.fillColor = nil
        caLayer.lineWidth = 0
        caLayer.strokeColor = lineColor?.cgColor
    }
    private var caShapeLayer: CAShapeLayer
    var path: CGPath? {
        get {
            return caShapeLayer.path
        }
        set {
            caShapeLayer.path = newValue
        }
    }
    fileprivate override func set(fillColor: CGColor?) {
        caShapeLayer.fillColor = fillColor
    }
    fileprivate override func set(lineColor: CGColor?) {
        caShapeLayer.strokeColor = lineColor
    }
    fileprivate override func set(lineWidth: CGFloat) {
        caShapeLayer.lineWidth = lineWidth
    }
}

struct Gradient {
    var colors = [Color]()
    var locations = [Double]()
    var startPoint = CGPoint(), endPoint = CGPoint(x: 1, y: 0)
}
class GradientLayer: Layer {
    override init() {
        var actions = CALayer.disabledAnimationActions
        actions["colors"] = NSNull()
        actions["locations"] = NSNull()
        actions["startPoint"] = NSNull()
        actions["endPoint"] = NSNull()
        let caLayer = CAGradientLayer()
        caLayer.actions = actions
        caGradientLayer = caLayer
        super.init(caLayer)
    }
    private var caGradientLayer: CAGradientLayer
    var gradient: Gradient? {
        didSet {
            let caLayer = caGradientLayer
            if let gradient = gradient {
                caLayer.colors = gradient.colors.isEmpty ? nil : gradient.colors.map { $0.cgColor }
                caLayer.locations = gradient.locations.isEmpty ?
                    nil : gradient.locations.map { NSNumber(value: $0) }
                caLayer.startPoint = gradient.startPoint
                caLayer.endPoint = gradient.endPoint
            } else {
                caLayer.colors = nil
            }
        }
    }
}

class DrawLayer: Layer {
    override init() {
        let caLayer = _CADrawLayer()
        caDrawLayer = caLayer
        super.init(caLayer, fillColor: .background)
    }
    private var caDrawLayer: _CADrawLayer
    var drawBlock: ((_ in: CGContext) -> Void)? {
        didSet {
            caDrawLayer.drawBlock = drawBlock
        }
    }
    func draw() {
        caLayer.setNeedsDisplay()
    }
    func draw(_ rect: CGRect) {
        caLayer.setNeedsDisplay(rect)
    }
    func render(in ctx: CGContext) {
        caDrawLayer.safetyRender(in: ctx)
    }
}

final class HighlightLayer: Layer {
    override init() {
        super.init()
        caLayer.actions = nil
        caLayer.backgroundColor = Color.black.cgColor
        caLayer.borderWidth = 0
        caLayer.opacity = 0.23
        caLayer.isHidden = true
    }
    var isHighlighted: Bool {
        return !caLayer.isHidden
    }
    func setIsHighlighted(_ h: Bool, animate: Bool) {
        if !animate {
            CATransaction.disableAnimation {
                caLayer.isHidden = !h
            }
        } else {
            CATransaction.setCompletionBlock {
                self.caLayer.isHidden = !h
            }
        }
    }
}

extension C0View {
    func backingLayer(with c0Layer: Layer) -> CALayer {
        c0Layer.caLayer.backgroundColor = Color.background.cgColor
        c0Layer.caLayer.borderColor = Color.border.cgColor
        c0Layer.caLayer.borderWidth = Screen.shared.backingScaleFactor
        return c0Layer.caLayer
    }
}

private final class _CADrawLayer: CALayer {
    init(backgroundColor: Color = .background, borderColor: Color? = .border) {
        super.init()
        self.needsDisplayOnBoundsChange = true
        self.drawsAsynchronously = true
        self.anchorPoint = CGPoint()
        self.isOpaque = true
        self.borderWidth = borderColor == nil ? 0.0 : 0.5
        self.backgroundColor = backgroundColor.cgColor
        self.borderColor = borderColor?.cgColor
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
            self.isOpaque = backgroundColor != nil
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
    func safetySetNeedsDisplay(_ handler: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        handler()
        setNeedsDisplay()
        CATransaction.commit()
    }
    func safetyRender(in ctx: CGContext) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setNeedsDisplay()
        render(in: ctx)
        CATransaction.commit()
    }
}

extension CALayer {
    static let disabledAnimationActions = ["backgroundColor": NSNull(),
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
        layer.actions = disabledAnimationActions
        return layer
    }
    static func interface(backgroundColor: Color? = nil,
                          borderColor: Color? = .border) -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        layer.actions = disabledAnimationActions
        layer.borderWidth = borderColor == nil ? 0.0 : 0.5
        layer.backgroundColor = backgroundColor?.cgColor
        layer.borderColor = borderColor?.cgColor
        return layer
    }
    static func knob(radius r: CGFloat = 5, lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.actions = disabledAnimationActions
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
        layer.actions = disabledAnimationActions
        layer.backgroundColor = Color.knob.cgColor
        layer.borderColor = Color.border.cgColor
        layer.borderWidth = l
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        return layer
    }
    
    static var selection: CALayer {
        let layer = CALayer()
        layer.actions = disabledAnimationActions
        layer.backgroundColor = Color.select.cgColor
        layer.borderColor = Color.selectBorder.cgColor
        layer.borderWidth = 1
        return layer
    }
    static var deselection: CALayer {
        let layer = CALayer()
        layer.actions = disabledAnimationActions
        layer.backgroundColor = Color.deselect.cgColor
        layer.borderColor = Color.deselectBorder.cgColor
        layer.borderWidth = 1
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

extension CATransaction {
    static func disableAnimation(_ handler: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        handler()
        CATransaction.commit()
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
    func drawBlur(withBlurRadius blurRadius: CGFloat, to ctx: CGContext) {
        if let image = makeImage() {
            let ciImage = CIImage(cgImage: image)
            let cictx = CIContext(cgContext: ctx, options: nil)
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(Float(blurRadius), forKey: kCIInputRadiusKey)
            if let outputImage = filter?.outputImage {
                cictx.draw(outputImage,
                           in: ctx.boundingBoxOfClipPath, from: outputImage.extent)
            }
        }
    }
}
