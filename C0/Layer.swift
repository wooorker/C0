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

struct Layer {
    private var useDidSetBounds = true, useDidSetFrame = true
    var bounds: CGRect {
        didSet {
            guard useDidSetBounds && bounds != oldValue else {
                return
            }
            useDidSetFrame = false
            frame.size = bounds.size
            useDidSetFrame = true
        }
    }
    var frame: CGRect {
        didSet {
            guard useDidSetFrame && frame != oldValue else {
                return
            }
            useDidSetBounds = false
            bounds.size = frame.size
            useDidSetBounds = true
        }
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
        layer.borderWidth = 0.5
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
