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
import AppKit.NSColor

struct SceneLayout {
    static let buttonsWidth = 120.0.cf, buttonHeight = 24.0.cf, height = buttonHeight*5.cf
    static let timelineWidth = 430.0.cf, timelineButtonsWidth = 142.0.cf, materialWidth = 205.0.cf, rightWidth = 205.0.cf
    static let materialLeftWidth = 85.0.cf, easingWidth = 100.0.cf, transformWidth = 32.0.cf
    
    static let timelineFrame = CGRect(x: 0, y: 0, width: timelineWidth, height: buttonHeight*4)
    static let timelineEditFrame = CGRect(x: 0, y: buttonHeight, width: timelineWidth, height: buttonHeight*3)
    static let timelineAddCutFrame = CGRect(x: 0, y: 0, width: timelineButtonsWidth, height: buttonHeight)
    static let timelineSplitKeyframeFrame = CGRect(x: timelineButtonsWidth, y: 0, width: timelineButtonsWidth + 4, height: buttonHeight)
    static let timelineAddGroupFrame = CGRect(x: timelineButtonsWidth*2 + 4, y: 0, width: timelineButtonsWidth, height: buttonHeight)
    
    static let materialFrame =  CGRect(x: 0, y: 0, width: materialWidth, height: height)
    static let materialColorFrame = CGRect(x: materialLeftWidth, y: 0, width: height, height: height)
    static let materialTypeFrame = CGRect(x: 0, y: buttonHeight*4, width: materialLeftWidth, height: buttonHeight)
    static let materialLineWidthFrame = CGRect(x: 0, y: buttonHeight*3, width: materialLeftWidth, height: buttonHeight)
    static let materialLineStrengthFrame = CGRect(x: 0, y: buttonHeight*2, width: materialLeftWidth, height: buttonHeight)
    static let materialOpacityFrame = CGRect(x: 0, y: buttonHeight, width: materialLeftWidth, height: buttonHeight)
    static let materialLuminanceFrame = CGRect(x: 10 - 4, y: 0, width: materialLeftWidth - buttonHeight - 10, height: buttonHeight)
    static let materialBlendHueFrame = CGRect(x: materialLeftWidth - buttonHeight - 4, y: 0, width: buttonHeight, height: buttonHeight)
    static let materialAnimationFrame = CGRect(x: 0, y: 0, width: materialLeftWidth, height: buttonHeight)
    
    static let keyframeFrame = CGRect(x: 0, y: 0, width: rightWidth, height: buttonHeight*2)
    static let keyframeEasingFrame = CGRect(x: 0, y: 0, width: easingWidth, height: buttonHeight*2)
    static let keyframeInterpolationFrame = CGRect(x: easingWidth, y: buttonHeight, width: rightWidth - easingWidth, height: buttonHeight)
    static let keyframeLoopFrame = CGRect(x: easingWidth, y: 0, width: rightWidth - easingWidth, height: buttonHeight)
    
    static let viewTypeFrame = CGRect(x: 0, y: 0, width: rightWidth, height: buttonHeight*4)
    static let viewTypeIsShownPreviousFrame = CGRect(x: 0, y: buttonHeight*3, width: rightWidth, height: buttonHeight)
    static let viewTypeIsShownNextFrame = CGRect(x: 0, y: buttonHeight*2, width: rightWidth, height: buttonHeight)
    static let viewTypeIsFlippedHorizontalFrame = CGRect(x: 0, y: buttonHeight, width: rightWidth, height: buttonHeight)
    
    static let transformFrame = CGRect(x: 0, y: 0, width: timelineWidth, height: buttonHeight)
    static let tarsnformValueFrame = CGRect(x: 0, y: 0, width: transformWidth, height: buttonHeight)
    
    static let soundFrame = CGRect(x: 0, y: 0, width: rightWidth, height: buttonHeight)
}
struct SceneDefaults {
    static let roughColor = NSColor(red: 0, green: 0.5, blue: 1, alpha: 0.15).cgColor
    static let subRoughColor = NSColor(red: 0, green: 0.5, blue: 1, alpha: 0.1).cgColor
    static let previousColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.1).cgColor
    static let subPreviousColor = NSColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.025).cgColor
    static let previousSkinColor = SceneDefaults.previousColor.copy(alpha: 1)!
    static let subPreviousSkinColor = SceneDefaults.subPreviousColor.copy(alpha: 0.08)!
    static let nextColor = NSColor(red: 0.2, green: 0.8, blue: 0, alpha: 0.1).cgColor
    static let subNextColor = NSColor(red: 0.4, green: 1, blue: 0, alpha: 0.025).cgColor
    static let nextSkinColor = SceneDefaults.nextColor.copy(alpha: 1)!
    static let subNextSkinColor = SceneDefaults.subNextColor.copy(alpha: 0.08)!
    static let selectionColor = NSColor(red: 0.1, green: 0.7, blue: 1, alpha: 1).cgColor
    static let interpolationColor = NSColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 1).cgColor
    static let subSelectionColor = NSColor(red: 0.8, green: 0.95, blue: 1, alpha: 0.6).cgColor
    static let subSelectionSkinColor =  SceneDefaults.subSelectionColor.copy(alpha: 0.3)!
    static let selectionSkinLineColor =  SceneDefaults.subSelectionColor.copy(alpha: 1.0)!
    
    static let editMaterialColor = NSColor(red: 1, green: 0.5, blue: 0, alpha: 0.2).cgColor
    static let editMaterialColorColor = NSColor(red: 1, green: 0.75, blue: 0, alpha: 0.2).cgColor
    
    static let cellBorderNormalColor = NSColor(white: 0, alpha: 0.15).cgColor
    static let cellBorderColor = NSColor(white: 0, alpha: 0.2).cgColor
    static let cellIndicationNormalColor = SceneDefaults.selectionColor.copy(alpha: 0.9)!
    static let cellIndicationColor = SceneDefaults.selectionColor.copy(alpha: 0.4)!
    
    static let controlPointInColor = Defaults.contentColor.cgColor
    static let controlPointOutColor = Defaults.editColor.cgColor
    static let controlPointCapInColor = NSColor(red: 1, green: 1, blue: 0, alpha: 1).cgColor
    static let controlPointCapOutColor = Defaults.editColor.cgColor
    static let controlPointJointInColor = NSColor(red: 1, green: 0, blue: 0, alpha: 1).cgColor
    static let controlPointOtherJointInColor = NSColor(red: 1, green: 0.5, blue: 1, alpha: 1).cgColor
    static let controlPointJointOutColor = Defaults.editColor.cgColor
    static let controlPointUnionInColor = NSColor(red: 0, green: 1, blue: 0.2, alpha: 1).cgColor
    static let controlPointUnionOutColor = Defaults.editColor.cgColor
    static let controlPointPathInColor = NSColor(red: 0, green: 1, blue: 1, alpha: 1).cgColor
    static let controlPointPathOutColor = Defaults.editColor.cgColor
    
    static let editControlPointInColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.8).cgColor
    static let editControlPointOutColor = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 0.3).cgColor
    static let contolLineInColor = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 0.3).cgColor
    static let contolLineOutColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.3).cgColor
    
    static let moveZColor = NSColor(red: 1, green: 0, blue: 0, alpha: 1).cgColor
    static let moveZSelectionColor = NSColor(red: 1, green: 0.5, blue: 0, alpha: 1).cgColor
    
    static let cameraColor = NSColor(red: 0.7, green: 0.6, blue: 0, alpha: 1).cgColor
    static let cameraBorderColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.5).cgColor
    static let cutBorderColor = NSColor(red: 0.3, green: 0.46, blue: 0.7, alpha: 0.5).cgColor
    static let cutSubBorderColor = NSColor(white: 1, alpha: 0.5).cgColor
    
    static let backgroundColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
    
    static let strokeLineWidth = 1.35.cf, strokeLineColor = NSColor(white: 0, alpha: 1).cgColor
    static let playBorderColor = NSColor(white: 0.3, alpha: 1).cgColor
    
    static let speechBorderColor = NSColor(white: 0, alpha: 1).cgColor
    static let speechFillColor = NSColor(white: 1, alpha: 1).cgColor
    static let speechFont = NSFont.boldSystemFont(ofSize: 25) as CTFont
}

//# Issue
//サイズとフレームレートの自由化
//書き出しの種類を増やす
final class Scene: NSObject, NSCoding {
    var cameraFrame: CGRect {
        didSet {
            affineTransform = viewTransform.affineTransform(with: cameraFrame)
        }
    }
    var frameRate: Int, time: Int, material: Material, isShownPrevious: Bool, isShownNext: Bool, soundItem: SoundItem
    var viewTransform: ViewTransform {
        didSet {
            affineTransform = viewTransform.affineTransform(with: cameraFrame)
        }
    }
    private(set) var affineTransform: CGAffineTransform?
    
    init(cameraFrame: CGRect = CGRect(x: 0, y: 0, width: 640, height: 360), frameRate: Int = 24, time: Int = 0, material: Material = Material(), isShownPrevious: Bool = false, isShownNext: Bool = false, soundItem: SoundItem = SoundItem(), viewTransform: ViewTransform = ViewTransform()) {
        self.cameraFrame = cameraFrame
        self.frameRate = frameRate
        self.time = time
        self.material = material
        self.isShownPrevious = isShownPrevious
        self.isShownNext = isShownNext
        self.soundItem = soundItem
        self.viewTransform = viewTransform
        
        affineTransform = viewTransform.affineTransform(with: cameraFrame)
        super.init()
    }
    
    static let dataType = "C0.Scene.1", cameraFrameKey = "0", frameRateKey = "1", timeKey = "2", materialKey = "3", isShownPreviousKey = "4", isShownNextKey = "5", soundItemKey = "7", viewTransformKey = "6"
    init?(coder: NSCoder) {
        cameraFrame = coder.decodeRect(forKey: Scene.cameraFrameKey)
        frameRate = coder.decodeInteger(forKey: Scene.frameRateKey)
        time = coder.decodeInteger(forKey: Scene.timeKey)
        material = coder.decodeObject(forKey: Scene.materialKey) as? Material ?? Material()
        isShownPrevious = coder.decodeBool(forKey: Scene.isShownPreviousKey)
        isShownNext = coder.decodeBool(forKey: Scene.isShownNextKey)
        soundItem = coder.decodeObject(forKey: Scene.soundItemKey) as? SoundItem ?? SoundItem()
        viewTransform = coder.decodeStruct(forKey: Scene.viewTransformKey) ?? ViewTransform()
        affineTransform = viewTransform.affineTransform(with: cameraFrame)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cameraFrame, forKey: Scene.cameraFrameKey)
        coder.encode(frameRate, forKey: Scene.frameRateKey)
        coder.encode(time, forKey: Scene.timeKey)
        coder.encode(material, forKey: Scene.materialKey)
        coder.encode(isShownPrevious, forKey: Scene.isShownPreviousKey)
        coder.encode(isShownNext, forKey: Scene.isShownNextKey)
        coder.encode(soundItem, forKey: Scene.soundItemKey)
        coder.encodeStruct(viewTransform, forKey: Scene.viewTransformKey)
    }
    
    func convertTime(frameTime ft: Int) -> TimeInterval {
        return TimeInterval(ft)/TimeInterval(frameRate)
    }
    func convertFrameTime(time t: TimeInterval) -> Int {
        return Int(t*TimeInterval(frameRate))
    }
    var secondTime: (second: Int, frame: Int) {
        let second = time/frameRate
        return (second, time - second*frameRate)
    }
}
struct ViewTransform: ByteCoding {
    var position = CGPoint(), scale = 1.0.cf, rotation = 0.0.cf, isFlippedHorizontal = false
    var isIdentity: Bool {
        return position == CGPoint() && scale == 1 && rotation == 0
    }
    func affineTransform(with bounds: CGRect) -> CGAffineTransform? {
        if scale == 1 && rotation == 0 && position == CGPoint() && !isFlippedHorizontal {
            return nil
        }
        var affine = CGAffineTransform.identity
        affine = affine.translatedBy(x: bounds.midX + position.x, y: bounds.midY + position.y)
        affine = affine.rotated(by: rotation)
        affine = affine.scaledBy(x: scale, y: scale)
        affine = affine.translatedBy(x: -bounds.midX, y: -bounds.midY)
        if isFlippedHorizontal {
            affine = affine.flippedHorizontal(by: bounds.width)
        }
        return affine
    }
}

final class SceneView: View {
    private let isHiddenCommandKey = "isHiddenCommand"
    
    let clipView = View(), cutView = CutView(), timelineView = TimelineView(), speechView = SpeechView()
    let materialView = MaterialView(), keyframeView = KeyframeView(), transformView = TransformView(), soundView = SoundView(), viewTypesView = ViewTypesView()
    let renderView = RenderView(), commandView = CommandView()
    var timeline: Timeline {
        return timelineView.timeline
    }
    
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.backgroundColor = nil
        clipView.layer.backgroundColor = nil
        cutView.sceneView = self
        timelineView.sceneView = self
        transformView.sceneView = self
        speechView.sceneView = self
        materialView.sceneView = self
        keyframeView.sceneView = self
        viewTypesView.sceneView = self
        renderView.sceneView = self
        soundView.sceneView = self
        soundView.description = "Set sound with paste sound file, switch mute with hide / show command, delete sound with delete command".localized
        clipView.children = [cutView, timelineView, materialView, keyframeView, transformView, speechView, viewTypesView, soundView, renderView, commandView]
        children = [clipView]
        updateSubviews()
    }
    
    func updateSubviews() {
        let ih = timelineView.frame.height + SceneLayout.buttonHeight*2
        let tx = materialView.frame.width, gx = materialView.frame.width + timelineView.frame.width
        let kx = gx, h = ih + cutView.frame.height
        CATransaction.disableAnimation {
            cutView.frame.origin = CGPoint(x: 0, y: ih)
            materialView.frame.origin = CGPoint(x: 0, y: ih - materialView.frame.height)
            timelineView.frame.origin = CGPoint(x: tx, y: ih - timelineView.frame.height)
            keyframeView.frame.origin = CGPoint(x: kx, y: ih - keyframeView.frame.height)
            viewTypesView.frame.origin = CGPoint(x: gx, y: ih - keyframeView.frame.height - viewTypesView.frame.height)
            transformView.frame.origin = CGPoint(x: tx, y: ih - timelineView.frame.height - transformView.frame.height)
            soundView.frame.origin = CGPoint(x: kx, y: ih - timelineView.frame.height - transformView.frame.height)
            speechView.frame.origin = CGPoint(x: tx, y: ih - timelineView.frame.height - speechView.frame.height - transformView.frame.height)
            renderView.frame = CGRect(x: 0, y: 0, width: cutView.frame.width, height: ih - materialView.frame.height)
            commandView.frame.origin = CGPoint(x: cutView.frame.width, y: h - commandView.frame.height)
            clipView.bounds = CGRect(x: 0, y: 0, width: cutView.frame.width + commandView.frame.width, height: h)
        }
    }
    
    var displayActionNode: ActionNode {
        get {
            return commandView.displayActionNode
        }
        set {
            commandView.displayActionNode = newValue
            updateSubviews()
        }
    }
    var sceneEntity = SceneEntity() {
        didSet {
            timeline.sceneEntity = sceneEntity
            scene = sceneEntity.preference.scene
            cutView.scene = sceneEntity.preference.scene
            timeline.scene = sceneEntity.preference.scene
            materialView.material = sceneEntity.preference.scene.material
            viewTypesView.isShownPreviousButton.selectionIndex = sceneEntity.preference.scene.isShownPrevious ? 1 : 0
            viewTypesView.isShownNextButton.selectionIndex = sceneEntity.preference.scene.isShownNext ? 1 : 0
            viewTypesView.isFlippedHorizontalButton.selectionIndex = sceneEntity.preference.scene.viewTransform.isFlippedHorizontal ? 1 : 0
            soundView.scene = sceneEntity.preference.scene
        }
    }
    var scene = Scene(), padding = 10.0.cf
    override var frame: CGRect {
        didSet {
            let minX = floor(bounds.midX - clipView.frame.width/2), maxY = floor(bounds.midY - clipView.frame.height/2) + clipView.frame.height
            let p = CGPoint(x: minX < padding ? padding : minX, y: maxY > bounds.height - padding ? bounds.height - padding - clipView.frame.height : floor(bounds.midY - clipView.frame.height/2))
            if p != clipView.frame.origin {
                clipView.frame.origin = p
            }
        }
    }
    
    override func undo() {
        if timeline.isPlaying {
            timeline.stop()
        } else {
            super.undo()
        }
    }
    override func redo() {
        if timeline.isPlaying {
            timeline.stop()
        } else {
            super.redo()
        }
    }
    
    override func moveToPrevious() {
        timeline.moveToPrevious()
    }
    override func moveToNext() {
        timeline.moveToNext()
    }
    override func play() {
        timeline.play()
    }
    
    override func changeToRough() {
        cutView.changeToRough()
    }
    override func removeRough() {
        cutView.removeRough()
    }
    override func swapRough() {
        cutView.swapRough()
    }
    
    override func scroll(with event: ScrollEvent) {
        timeline.scroll(with: event)
    }
}

final class MaterialView: View,  ColorViewDelegate, SliderDelegate, PulldownButtonDelegate, TempSliderDelegate {
    weak var sceneView: SceneView!
    
    private let colorView = ColorView(frame: SceneLayout.materialColorFrame)
    private let typeButton = PulldownButton(frame: SceneLayout.materialTypeFrame, names: [
        "Normal".localized,
        "Lineless".localized,
        "Blur".localized,
        "Luster".localized,
        "Glow".localized,
        "Screen".localized,
        "Multiply".localized
        ])
    private let lineWidthSlider: Slider = {
        let slider = Slider(frame: SceneLayout.materialLineWidthFrame, min: SceneDefaults.strokeLineWidth, max: 500, exp: 2)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = Defaults.contentEditColor.cgColor
        shapeLayer.path = {
            let path = CGMutablePath(), halfWidth = 5.0.cf
            path.addLines(between: [
                CGPoint(x: slider.viewPadding,y: slider.frame.height/2),
                CGPoint(x: slider.frame.width - slider.viewPadding, y: slider.frame.height/2 - halfWidth),
                CGPoint(x: slider.frame.width - slider.viewPadding, y: slider.frame.height/2 + halfWidth)
                ])
            return path
        } ()
        
        slider.layer.sublayers = [shapeLayer, slider.knobLayer]
        return slider
    } ()
    private let lineStrengthSlider: Slider = {
        let slider = Slider(frame: SceneLayout.materialLineStrengthFrame, min: 0, max: 1)
        let halfWidth = 5.0.cf, fillColor = Defaults.subEditColor
        let width = slider.frame.width - slider.viewPadding*2
        let frame = CGRect(x: slider.viewPadding, y: slider.frame.height/2 - halfWidth, width: width, height: halfWidth*2)
        let size = CGSize(width: halfWidth, height: halfWidth)
        let count = Int(frame.width/(size.width*2))
        
        let sublayers: [CALayer] = (0 ..< count).map { i in
            let lineLayer = CALayer(), icf = i.cf
            lineLayer.backgroundColor = fillColor.cgColor
            lineLayer.borderColor = Defaults.contentEditColor.blended(withFraction: icf/(count - 1).cf, of: fillColor)?.cgColor
            lineLayer.borderWidth = 2
            lineLayer.frame = CGRect(x: frame.minX + icf*(size.width*2 + 1), y: frame.minY, width: size.width*2, height: size.height*2)
            return lineLayer
        }
        
        slider.layer.sublayers = sublayers + [slider.knobLayer]
        return slider
    } ()
    private let opacitySlider: Slider = {
        let slider = Slider(frame: SceneLayout.materialOpacityFrame, value: 1, defaultValue: 1, min: 0, max: 1, invert: true)
        let halfWidth = 5.0.cf
        let width = slider.frame.width - slider.viewPadding*2
        let frame = CGRect(x: slider.viewPadding, y: slider.frame.height/2 - halfWidth, width: width, height: halfWidth*2)
        let size = CGSize(width: halfWidth, height: halfWidth)
        
        let backLayer = CALayer()
        backLayer.backgroundColor = Defaults.contentEditColor.cgColor
        backLayer.frame = frame
        
        let checkerboardLayer = CAShapeLayer()
        checkerboardLayer.fillColor = Defaults.subEditColor.cgColor
        checkerboardLayer.path = CGPath.checkerboard(with: size, in: frame)
        
        let colorLayer = CAGradientLayer()
        colorLayer.startPoint = CGPoint(x: 0, y: 0)
        colorLayer.endPoint = CGPoint(x: 1, y: 0)
        colorLayer.colors = [
            Defaults.contentEditColor.cgColor,
            Defaults.contentEditColor.withAlphaComponent(0).cgColor
        ]
        colorLayer.frame = frame
        
        slider.layer.sublayers = [backLayer, checkerboardLayer, colorLayer, slider.knobLayer]
        return slider
    } ()
    private let luminanceSlider: TempSlider = {
        let tempSlider = TempSlider(frame: SceneLayout.materialLuminanceFrame, isRadial: false)
        let width = tempSlider.frame.width - tempSlider.padding*2
        
        let lightnessLayer = CAGradientLayer()
        lightnessLayer.startPoint = CGPoint(x: 0, y: 0)
        lightnessLayer.endPoint = CGPoint(x: 1, y: 0)
        lightnessLayer.colors = [
            NSColor(white: 0, alpha: 1).cgColor,
            NSColor(white: 0.65, alpha: 1).cgColor,
            NSColor(white: 1, alpha: 1).cgColor
        ]
        lightnessLayer.frame = CGRect(x: tempSlider.padding, y: tempSlider.frame.height/2 - 2, width: width, height: 4)
        tempSlider.imageLayer = lightnessLayer
        
        return tempSlider
    } ()
    private let blendHueSlider: TempSlider = {
        let tempSlider = TempSlider(isRadial: true)
        let frame = SceneLayout.materialBlendHueFrame
        
        let colorLayer = DrawLayer(fillColor: Defaults.subBackgroundColor.cgColor)
        let colorCircle = ColorCircle(width: 2, bounds: CGRect(origin: CGPoint(), size: frame.size).inset(by: 4))
        colorLayer.frame = frame
        colorLayer.drawBlock = { ctx in
            colorCircle.draw(in: ctx)
        }
        tempSlider.layer = colorLayer
        
        return tempSlider
    } ()
    private let animationView: View = {
        let view = View()
        view.layer.frame = SceneLayout.materialAnimationFrame
        return view
    }()
    
    static let emptyMaterial = Material()
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.backgroundColor = nil
        layer.frame = SceneLayout.materialFrame
        colorView.delegate = self
        typeButton.delegate = self
        lineWidthSlider.delegate = self
        lineStrengthSlider.delegate = self
        opacitySlider.delegate = self
        luminanceSlider.delegate = self
        blendHueSlider.delegate = self
        colorView.description = "Material color: Ring is hue, width is saturation, height is luminance".localized
        typeButton.description = "Material Type".localized
        lineWidthSlider.description = "Material Line Width".localized
        lineStrengthSlider.description = "Material Line Strength".localized
        opacitySlider.description = "Material Opacity".localized
        children = [colorView, typeButton, lineWidthSlider, lineStrengthSlider, opacitySlider, animationView]
    }
    
    var material = MaterialView.emptyMaterial {
        didSet {
            if material.id != oldValue.id {
                sceneView.sceneEntity.preference.scene.material = material
                sceneView.sceneEntity.isUpdatePreference = true
                colorView.color = material.color
                typeButton.selectionIndex = Int(material.type.rawValue)
                lineWidthSlider.value = material.lineWidth
                opacitySlider.value = material.opacity
                lineStrengthSlider.value = material.lineStrength
                sceneView.cutView.setNeedsDisplay()
            }
        }
    }
    
    var isEditing = false {
        didSet {
            sceneView.cutView.materialViewType = isEditing ? .preview : (indication ? .selection : .none)
        }
    }
    override var indication: Bool {
        didSet {
            sceneView.cutView.materialViewType = isEditing ? .preview : (indication ? .selection : .none)
        }
    }
    
    override func copy() {
        copy(material, from: self)
    }
    func copy(_ material: Material, from view: View) {
        _setMaterial(material, oldMaterial: material)
        screen?.copy(material.data, forType: Material.dataType, from: view)
    }
    override func paste() {
        let pasteboard = NSPasteboard.general()
        if let data = pasteboard.data(forType: Material.dataType), let material = Material.with(data) {
            paste(material, withSelection: self.material, useSelection: false)
        } else {
            screen?.tempNotAction()
        }
    }
    func paste(_ material: Material, withSelection selectionMaterial: Material, useSelection: Bool) {
        let materialTuples = materialTuplesWith(material: selectionMaterial, useSelection: useSelection,
                                                in: sceneView.timeline.selectionCutEntity, sceneView.sceneEntity.cutEntities)
        for materialTuple in materialTuples.values {
            _setMaterial(material, in: materialTuple)
        }
    }
    func paste(_ color: HSLColor, withSelection selectionMaterial: Material, useSelection: Bool) {
        let colorTuples = colorTuplesWith(color: selectionMaterial.color, useSelection: useSelection,
                                                in: sceneView.timeline.selectionCutEntity, sceneView.sceneEntity.cutEntities)
        _setColor(color, in: colorTuples)
    }
    func splitMaterial(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, in: sceneView.timeline.selectionCutEntity)
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withColor(materialTuple.material.color.withNewID()), in: materialTuple)
        }
    }
    func splitColor(with cells: [Cell]) {
        let colorTuples = colorTuplesWith(cells: cells, in: sceneView.timeline.selectionCutEntity)
        for colorTuple in colorTuples {
            let newColor = colorTuple.color.withNewID()
            for materialTuple in colorTuple.materialTuples.values {
                setMaterial(materialTuple.material.withColor(newColor), in: materialTuple)
            }
        }
    }
    func splitOtherThanColor(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, in: sceneView.timeline.selectionCutEntity)
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withColor(materialTuple.material.color), in: materialTuple)
        }
    }
    private func _setMaterial(_ material: Material, oldMaterial: Material, in cells: [Cell], _ cutEntity: CutEntity) {
        undoManager?.registerUndo(withTarget: self) { $0._setMaterial(oldMaterial, oldMaterial: material, in: cells, cutEntity) }
        for cell in cells {
            cell.material = material
        }
        cutEntity.isUpdateMaterial = true
        if cutEntity === sceneView.cutView.cutEntity {
            sceneView.cutView.setNeedsDisplay()
        }
    }
    func select(_ material: Material) {
        _setMaterial(material, oldMaterial: self.material)
    }
    private func _setMaterial(_ material: Material, oldMaterial: Material) {
        undoManager?.registerUndo(withTarget: self) { $0._setMaterial(oldMaterial, oldMaterial: material) }
        self.material = material
    }
    
    enum EditType {
        case color, material, correction
    }
    var editType = EditType.color {
        didSet{
            if editType != oldValue {
                sceneView.cutView.setNeedsDisplay()
            }
        }
    }
    
    enum ViewType {
        case none, selection, preview
    }
    private struct ColorTuple {
        var color: HSLColor, materialTuples: [UUID: MaterialTuple]
    }
    private struct MaterialTuple {
        var material: Material, cutTuples: [CutTuple]
    }
    private struct CutTuple {
        var cutEntity: CutEntity, cells: [Cell]
    }
    
    private var materialTuples = [UUID: MaterialTuple](), colorTuples = [ColorTuple](), oldMaterialTuple: MaterialTuple?, oldMaterial: Material?
    private func colorTuplesWith(color: HSLColor?, useSelection: Bool = false, in cutEntity: CutEntity, _ cutEntities: [CutEntity]) -> [ColorTuple] {
         if useSelection {
            let allSelectionCells = cutEntity.cut.allEditSelectionCellsWithNotEmptyGeometry
            if !allSelectionCells.isEmpty {
                return colorTuplesWith(cells: allSelectionCells, in: cutEntity)
            }
        }
        if let color = color {
            return colorTuplesWith(color: color, in: cutEntities)
        } else {
            return colorTuplesWith(cells: cutEntity.cut.cells, in: cutEntity)
        }
    }
    private func colorTuplesWith(cells: [Cell], in cutEntity: CutEntity) -> [ColorTuple] {
        struct ColorCell {
            var color: HSLColor, cells: [Cell]
        }
        var colorDic = [UUID: ColorCell]()
        for cell in cells {
            if colorDic[cell.material.color.id] != nil {
                colorDic[cell.material.color.id]?.cells.append(cell)
            } else {
                colorDic[cell.material.color.id] = ColorCell(color: cell.material.color, cells: [cell])
            }
        }
        return colorDic.map {
            ColorTuple(color: $0.value.color, materialTuples: materialTuplesWith(cells: $0.value.cells, in: cutEntity))
        }
    }
    private func colorTuplesWith(color: HSLColor, in cutEntities: [CutEntity]) -> [ColorTuple] {
        var materialTuples = [UUID: MaterialTuple]()
        for cutEntity in cutEntities {
            let cells = cutEntity.cut.cells.filter { $0.material.color == color }
            if !cells.isEmpty {
                let mts = materialTuplesWith(cells: cells, in: cutEntity)
                for mt in mts {
                    if materialTuples[mt.key] != nil {
                        materialTuples[mt.key]?.cutTuples += mt.value.cutTuples
                    } else {
                        materialTuples[mt.key] = mt.value
                    }
                }
            }
        }
        return materialTuples.isEmpty ? [] : [ColorTuple(color: color, materialTuples: materialTuples)]
    }
    
    private func materialTuplesWith(cells: [Cell], in cutEntity: CutEntity) -> [UUID: MaterialTuple] {
        var materialDic = [UUID: MaterialTuple]()
        for cell in cells {
            if materialDic[cell.material.id] != nil {
                materialDic[cell.material.id]?.cutTuples[0].cells.append(cell)
            } else {
                materialDic[cell.material.id] = MaterialTuple(material: cell.material, cutTuples: [CutTuple(cutEntity: cutEntity, cells: [cell])])
            }
        }
        return materialDic
    }
    private func materialTuplesWith(material: Material?, useSelection: Bool = false,
                                    in cutEntity: CutEntity, _ cutEntities: [CutEntity]) -> [UUID: MaterialTuple] {
        if useSelection {
            let allSelectionCells = cutEntity.cut.allEditSelectionCellsWithNotEmptyGeometry
            if !allSelectionCells.isEmpty {
                return materialTuplesWith(cells: allSelectionCells, in: cutEntity)
            }
        }
        if let material = material {
            let cutTuples: [CutTuple] = cutEntities.flatMap { cutEntity in
                let cells = cutEntity.cut.cells.filter { $0.material.id == material.id }
                return cells.isEmpty ? nil : CutTuple(cutEntity: cutEntity, cells: cells)
            }
            return cutTuples.isEmpty ? [:] : [material.id: MaterialTuple(material: material, cutTuples: cutTuples)]
        } else {
            return materialTuplesWith(cells: cutEntity.cut.cells, in: cutEntity)
        }
    }
    
    private func selectionMaterialTuple(with colorTuples: [ColorTuple]) -> MaterialTuple? {
        for colorTuple in colorTuples {
            if let tuple = colorTuple.materialTuples[material.id] {
                return tuple
            }
        }
        return nil
    }
    private func selectionMaterialTuple(with materialTuples: [UUID: MaterialTuple]) -> MaterialTuple? {
        return materialTuples[material.id]
    }
    
    private func changeMaterialWith(isColorTuple: Bool, type: DragEvent.SendType) {
        switch type {
        case .begin:
            oldMaterialTuple = isColorTuple ? selectionMaterialTuple(with: colorTuples) : selectionMaterialTuple(with: materialTuples)
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .sending:
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .end:
            if let oldMaterialTuple = oldMaterialTuple {
                _setMaterial(oldMaterialTuple.cutTuples[0].cells[0].material, oldMaterial: oldMaterialTuple.material)
            }
            oldMaterialTuple = nil
        }
        sceneView.cutView.setNeedsDisplay()
    }
    private func setMaterial(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            for cell in cutTuple.cells {
                cell.material = material
            }
        }
    }
    private func _setMaterial(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            _setMaterial(material, oldMaterial: materialTuple.material, in: cutTuple.cells, cutTuple.cutEntity)
        }
    }
    
    func changeColor(_ colorView: ColorView, color: HSLColor, oldColor: HSLColor, type: DragEvent.SendType) {
        switch type {
        case .begin:
            isEditing = true
            colorTuples = colorTuplesWith(color: oldColor, in: sceneView.timeline.selectionCutEntity, sceneView.sceneEntity.cutEntities)
            setColor(color, in: colorTuples)
        case .sending:
            setColor(color, in: colorTuples)
        case .end:
            _setColor(color, in: colorTuples)
            colorTuples = []
            isEditing = false
        }
        changeMaterialWith(isColorTuple: true, type: type)
    }
    private func setColor(_ color: HSLColor, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                setMaterial(materialTuple.material.withColor(color), in: materialTuple)
            }
        }
    }
    private func _setColor(_ color: HSLColor, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                _setMaterial(materialTuple.material.withColor(color), in: materialTuple)
            }
        }
    }
    
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: DragEvent.SendType) {
        let materialType = Material.MaterialType(rawValue: Int8(index)) ?? .normal
        switch type {
        case .begin:
            isEditing = true
            materialTuples = materialTuplesWith(material: material, in: sceneView.timeline.selectionCutEntity, sceneView.sceneEntity.cutEntities)
            setMaterialType(materialType, in: materialTuples)
        case .sending:
            setMaterialType(materialType, in: materialTuples)
        case .end:
            _setMaterialType(materialType, in: materialTuples)
            materialTuples = [:]
            isEditing = false
        }
        changeMaterialWith(isColorTuple: false, type: type)
    }
    private func setMaterialType(_ type: Material.MaterialType, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            setMaterial(materialTuple.material.withType(type), in: materialTuple)
        }
    }
    private func _setMaterialType(_ type: Material.MaterialType, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withType(type), in: materialTuple)
        }
    }
    
    private var oldColor = HSLColor()
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: DragEvent.SendType) {
        switch slider {
        case lineWidthSlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material, in: sceneView.timeline.selectionCutEntity, sceneView.sceneEntity.cutEntities)
                setLineWidth(value, in: materialTuples)
            case .sending:
                setLineWidth(value, in: materialTuples)
            case .end:
                _setLineWidth(value, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
        case lineStrengthSlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material, in: sceneView.timeline.selectionCutEntity, sceneView.sceneEntity.cutEntities)
                setLineStrength(value, in: materialTuples)
            case .sending:
                setLineStrength(value, in: materialTuples)
            case .end:
                _setLineStrength(value, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
        case opacitySlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material, in: sceneView.timeline.selectionCutEntity, sceneView.sceneEntity.cutEntities)
                setOpacity(value, in: materialTuples)
            case .sending:
                setOpacity(value, in: materialTuples)
            case .end:
                _setOpacity(value, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
        default:
            break
        }
        changeMaterialWith(isColorTuple: false, type: type)
    }
    private func setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            setMaterial(materialTuple.material.withLineWidth(lineWidth), in: materialTuple)
        }
    }
    private func _setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withLineWidth(lineWidth), in: materialTuple)
        }
    }
    private func setLineStrength(_ lineStrength: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            setMaterial(materialTuple.material.withLineStrength(lineStrength), in: materialTuple)
        }
    }
    private func _setLineStrength(_ lineStrength: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withLineStrength(lineStrength), in: materialTuple)
        }
    }
    private func setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            setMaterial(materialTuple.material.withOpacity(opacity), in: materialTuple)
        }
    }
    private func _setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withOpacity(opacity), in: materialTuple)
        }
    }
    
    func changeValue(_ tempSlider: TempSlider, point p: CGPoint, oldPoint op: CGPoint, deltaPoint dp: CGPoint, type: DragEvent.SendType) {
        switch type {
        case .begin:
            isEditing = true
            colorTuples = colorTuplesWith(color: nil, in: sceneView.timeline.selectionCutEntity, sceneView.sceneEntity.cutEntities)
            correction(deltaPoint: dp, tempSlider: tempSlider, in: colorTuples)
        case .sending:
            correction(deltaPoint: dp, tempSlider: tempSlider, in: colorTuples)
        case .end:
            _correction(deltaPoint: dp, tempSlider: tempSlider, in: colorTuples)
            colorTuples = []
            isEditing = false
        }
        changeMaterialWith(isColorTuple: true, type: type)
    }
    func correctionColorWith(color: HSLColor, deltaPoint dp: CGPoint, tempSlider: TempSlider) -> HSLColor {
        let correctionBase = 50.0.cf
        switch tempSlider {
        case luminanceSlider:
            let t = (abs(dp.x)/correctionBase).clip(min: 0, max: 1)
            return color.correction(luminance: dp.x > 0 ? 1 : 0, withFraction: t)
        case blendHueSlider:
            let t = (hypot(dp.x, dp.y)/correctionBase).clip(min: 0, max: 1)
            return color.correction(hue: ColorCircle().hue(withAngle: atan2(dp.y, dp.x)), withFraction: t)
        default:
            return color
        }
    }
    private func correction(deltaPoint dp: CGPoint, tempSlider: TempSlider, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            let color = correctionColorWith(color: colorTuple.color, deltaPoint: dp, tempSlider: tempSlider)
            for tuple in colorTuple.materialTuples.values {
                setMaterial(tuple.material.withColor(color), in: tuple)
            }
        }
    }
    private func _correction(deltaPoint dp: CGPoint, tempSlider: TempSlider, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            let color = correctionColorWith(color: colorTuple.color, deltaPoint: dp, tempSlider: tempSlider)
            for tuple in colorTuple.materialTuples.values {
                _setMaterial(tuple.material.withColor(color), in: tuple)
            }
        }
    }
}

final class KeyframeView: View, EasingViewDelegate, PulldownButtonDelegate {
    weak var sceneView: SceneView!
    
    let easingView = EasingView(frame: SceneLayout.keyframeEasingFrame)
    let interpolationButton = PulldownButton(frame: SceneLayout.keyframeInterpolationFrame, names: [
        "Spline".localized,
        "Bound".localized,
        "Linear".localized,
        "Step".localized
        ])
    let loopButton = PulldownButton(frame: SceneLayout.keyframeLoopFrame, names: [
        "No Loop".localized,
        "Began Loop".localized,
        "Ended Loop".localized
        ])
    
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.frame = SceneLayout.keyframeFrame
        easingView.delegate = self
        interpolationButton.delegate = self
        loopButton.delegate = self
        interpolationButton.description = "\"Bound\" uses \"Spline\" without interpolation on previous, when not previous and next, use \"Linear\"".localized
        loopButton.description = "Loop from  \"Began Loop\" keyframe to \"Ended Loop\" keyframe on \"Ended Loop\" keyframe".localized
        children = [easingView, interpolationButton, loopButton]
    }
    
    var keyframe = Keyframe() {
        didSet {
            if !keyframe.equalOption(other: oldValue) {
                updateSubviews()
            }
        }
    }
    func update() {
        keyframe = sceneView.timeline.selectionCutEntity.cut.editGroup.editKeyframe
    }
    private func updateSubviews() {
        loopButton.selectionIndex = KeyframeView.loopIndexWith(keyframe.loop, keyframe: keyframe)
        interpolationButton.selectionIndex = KeyframeView.interpolationIndexWith(keyframe.interpolation)
        easingView.easing = keyframe.easing
    }
    
    static func loopIndexWith(_ loop: Loop, keyframe: Keyframe) -> Int {
        let loop = keyframe.loop
        if !loop.isStart && !loop.isEnd {
            return 0
        } else if loop.isStart {
            return 1
        } else {
            return 2
        }
    }
    static func loopWith(_ index: Int) -> Loop {
        switch index {
        case 0:
            return Loop(isStart: false, isEnd: false)
        case 1:
            return Loop(isStart: true, isEnd: false)
        default:
            return Loop(isStart: false, isEnd: true)
        }
    }
    static func interpolationIndexWith(_ interpolation: Keyframe.Interpolation) -> Int {
        return Int(interpolation.rawValue)
    }
    static func interpolationWith(_ index: Int) -> Keyframe.Interpolation {
        return Keyframe.Interpolation(rawValue: Int8(index)) ?? .spline
    }
    
    private var changekeyframeTuple: (oldKeyframe: Keyframe, index: Int, group: Group, cutEntity: CutEntity)?
    static func changekeyframeTupleWith(_ cutEntity: CutEntity) -> (oldKeyframe: Keyframe, index: Int, group: Group, cutEntity: CutEntity) {
        let group = cutEntity.cut.editGroup
        return (group.editKeyframe, group.editKeyframeIndex, group, cutEntity)
    }
    func changeEasing(_ easingView: EasingView, easing: Easing, oldEasing: Easing, type: DragEvent.SendType) {
        switch type {
        case .begin:
            changekeyframeTuple = KeyframeView.changekeyframeTupleWith(sceneView.timeline.selectionCutEntity)
        case .sending:
            if let ckp = changekeyframeTuple {
                let keyframe = ckp.oldKeyframe.withEasing(easing)
                setKeyframe(keyframe, at: ckp.index, group: ckp.group)
            }
        case .end:
            if let ckp = changekeyframeTuple {
                let keyframe = ckp.oldKeyframe.withEasing(easing)
                setEasing(keyframe, oldKeyframe: ckp.oldKeyframe, at: ckp.index, group: ckp.group, cutEntity: ckp.cutEntity)
                changekeyframeTuple = nil
            }
        }
    }
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: DragEvent.SendType) {
        switch pulldownButton {
        case interpolationButton:
            switch type {
            case .begin:
                changekeyframeTuple = KeyframeView.changekeyframeTupleWith(sceneView.timeline.selectionCutEntity)
            case .sending:
                if let ckp = changekeyframeTuple {
                    let keyframe = ckp.oldKeyframe.withInterpolation(KeyframeView.interpolationWith(index))
                    setKeyframe(keyframe, at: ckp.index, group: ckp.group)
                }
            case .end:
                if let ckp = changekeyframeTuple {
                    let keyframe = ckp.oldKeyframe.withInterpolation(KeyframeView.interpolationWith(index))
                    setInterpolation(keyframe, oldKeyframe: ckp.oldKeyframe, at: ckp.index, group: ckp.group, cutEntity: ckp.cutEntity)
                    changekeyframeTuple = nil
                }
            }
        case loopButton:
            switch type {
            case .begin:
                changekeyframeTuple = KeyframeView.changekeyframeTupleWith(sceneView.timeline.selectionCutEntity)
            case .sending:
                if let ckp = changekeyframeTuple {
                    let keyframe = ckp.oldKeyframe.withLoop(KeyframeView.loopWith(index))
                    setKeyframe(keyframe, at: ckp.index, group: ckp.group)
                }
            case .end:
                if let ckp = changekeyframeTuple {
                    let keyframe = ckp.oldKeyframe.withLoop(KeyframeView.loopWith(index))
                    setLoop(keyframe, oldKeyframe: ckp.oldKeyframe, at: ckp.index, group: ckp.group, cutEntity: ckp.cutEntity)
                    changekeyframeTuple = nil
                }
            }
        default:
            break
        }
    }
    private func setEasing(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, group: Group, cutEntity: CutEntity) {
        undoManager?.registerUndo(withTarget: self) { $0.setEasing(oldKeyframe, oldKeyframe: keyframe, at: i, group: group, cutEntity: cutEntity) }
        setKeyframe(keyframe, at: i, group: group)
        easingView.easing = keyframe.easing
        cutEntity.isUpdate = true
    }
    private func setInterpolation(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, group: Group, cutEntity: CutEntity) {
        undoManager?.registerUndo(withTarget: self) { $0.setInterpolation(oldKeyframe, oldKeyframe: keyframe, at: i, group: group, cutEntity: cutEntity) }
        setKeyframe(keyframe, at: i, group: group)
        interpolationButton.selectionIndex = KeyframeView.interpolationIndexWith(keyframe.interpolation)
        cutEntity.isUpdate = true
    }
    private func setLoop(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, group: Group, cutEntity: CutEntity) {
        undoManager?.registerUndo(withTarget: self) { $0.setLoop(oldKeyframe, oldKeyframe: keyframe, at: i, group: group, cutEntity: cutEntity) }
        setKeyframe(keyframe, at: i, group: group)
        loopButton.selectionIndex = KeyframeView.loopIndexWith(keyframe.loop, keyframe: keyframe)
        cutEntity.isUpdate = true
    }
    func setKeyframe(_ keyframe: Keyframe, at i: Int, group: Group) {
        group.replaceKeyframe(keyframe, at: i)
        update()
        sceneView.timeline.setNeedsDisplay()
        sceneView.cutView.setNeedsDisplay()
    }
}

final class ViewTypesView: View, PulldownButtonDelegate {
    weak var sceneView: SceneView!
    let isShownPreviousButton = PulldownButton(frame: SceneLayout.viewTypeIsShownPreviousFrame, isEnabledCation: true, names: [
        "Hidden Previous".localized,
        "Shown Previous".localized
        ])
    let isShownNextButton = PulldownButton(frame: SceneLayout.viewTypeIsShownNextFrame, isEnabledCation: true, names: [
        "Hidden Next".localized,
        "Shown Next".localized
        ])
    let isFlippedHorizontalButton = PulldownButton(frame: SceneLayout.viewTypeIsFlippedHorizontalFrame, isEnabledCation: true, names: [
        "Unflipped Horizontal".localized,
        "Flipped Horizontal".localized
        ])
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.frame = SceneLayout.viewTypeFrame
        layer.backgroundColor = nil
        isShownPreviousButton.delegate = self
        isShownNextButton.delegate = self
        isFlippedHorizontalButton.delegate = self
        isShownPreviousButton.description = "Hide/Show line drawing of previous keyframe".localized
        isShownNextButton.description = "Hide/Show line drawing of next keyframe".localized
        children = [isShownPreviousButton, isShownNextButton]
    }
    
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: DragEvent.SendType) {
        switch pulldownButton {
        case isShownPreviousButton:
            switch type {
            case .begin:
                break
            case .sending:
                sceneView.cutView.isShownPrevious = index == 1
            case .end:
                if index != oldIndex {
                    setIsShownPrevious(index == 1, oldIsShownPrevious: oldIndex == 1)
                } else {
                    sceneView.cutView.isShownPrevious = index == 1
                }
            }
        case isShownNextButton:
            switch type {
            case .begin:
                break
            case .sending:
                sceneView.cutView.isShownNext = index == 1
            case .end:
                if index != oldIndex {
                    setIsShownNext(index == 1, oldIsShownNext: oldIndex == 1)
                } else {
                    sceneView.cutView.isShownNext = index == 1
                }
            }
        case isFlippedHorizontalButton:
            switch type {
            case .begin:
                break
            case .sending:
                sceneView.cutView.viewTransform.isFlippedHorizontal = index == 1
            case .end:
                if index != oldIndex {
                    setIsFlippedHorizontal(index == 1, oldIsFlippedHorizontal: oldIndex == 1)
                } else {
                    sceneView.cutView.viewTransform.isFlippedHorizontal = index == 1
                }
            }
        default:
            break
        }
    }
    private func setIsShownPrevious(_ isShownPrevious: Bool, oldIsShownPrevious: Bool) {
        undoManager?.registerUndo(withTarget: self) { $0.setIsShownPrevious(oldIsShownPrevious, oldIsShownPrevious: isShownPrevious) }
        isShownPreviousButton.selectionIndex = isShownPrevious ? 1 : 0
        sceneView.cutView.isShownPrevious = isShownPrevious
        sceneView.sceneEntity.isUpdatePreference = true
    }
    private func setIsShownNext(_ isShownNext: Bool, oldIsShownNext: Bool) {
        undoManager?.registerUndo(withTarget: self) { $0.setIsShownNext(oldIsShownNext, oldIsShownNext: isShownNext) }
        isShownNextButton.selectionIndex = isShownNext ? 1 : 0
        sceneView.cutView.isShownNext = isShownNext
        sceneView.sceneEntity.isUpdatePreference = true
    }
    private func setIsFlippedHorizontal(_ isFlippedHorizontal: Bool, oldIsFlippedHorizontal: Bool) {
        undoManager?.registerUndo(withTarget: self) { $0.setIsFlippedHorizontal(oldIsFlippedHorizontal, oldIsFlippedHorizontal: isFlippedHorizontal) }
        isFlippedHorizontalButton.selectionIndex = isFlippedHorizontal ? 1 : 0
        sceneView.cutView.viewTransform.isFlippedHorizontal = isFlippedHorizontal
        sceneView.sceneEntity.isUpdatePreference = true
    }
}

final class TransformView: View, SliderDelegate {
    weak var sceneView: SceneView!
    private let xView = StringView(string: "X:", font: Defaults.smallFont, color: Defaults.smallFontColor.cgColor, paddingWidth: 2, height: SceneLayout.buttonHeight)
    private let yView = StringView(string: "Y:", font: Defaults.smallFont, color: Defaults.smallFontColor.cgColor, paddingWidth: 2, height: SceneLayout.buttonHeight)
    private let zView = StringView(string: "Z:", font: Defaults.smallFont, color: Defaults.smallFontColor.cgColor, paddingWidth: 2, height: SceneLayout.buttonHeight)
    private let thetaView = StringView(string: "θ:", font: Defaults.smallFont, color: Defaults.smallFontColor.cgColor, paddingWidth: 2, height: SceneLayout.buttonHeight)
    private let wiggleXView = StringView(string: "Wiggle ".localized + "X:", font: Defaults.smallFont, color: Defaults.smallFontColor.cgColor, paddingWidth: 2, height: SceneLayout.buttonHeight)
    private let wiggleYView = StringView(string: "Wiggle ".localized + "Y:", font: Defaults.smallFont, color: Defaults.smallFontColor.cgColor, paddingWidth: 2, height: SceneLayout.buttonHeight)
    private let xSlider = Slider(frame: SceneLayout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: -10000, max: 10000, valueInterval: 0.01)
    private let ySlider = Slider(frame: SceneLayout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: -10000, max: 10000, valueInterval: 0.01)
    private let zSlider = Slider(frame: SceneLayout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: -20, max: 20, valueInterval: 0.01)
    private let thetaSlider = Slider(frame: SceneLayout.tarsnformValueFrame, unit: "°", isNumberEdit: true, min: -10000, max: 10000, valueInterval: 0.5)
    private let wiggleXSlider = Slider(frame: SceneLayout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: 0, max: 1000, valueInterval: 0.01)
    private let wiggleYSlider = Slider(frame: SceneLayout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: 0, max: 1000, valueInterval: 0.01)
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.frame = SceneLayout.transformFrame
        xSlider.delegate = self
        ySlider.delegate = self
        zSlider.delegate = self
        thetaSlider.delegate = self
        wiggleXSlider.delegate = self
        wiggleYSlider.delegate = self
        xSlider.description = "Camera position X".localized
        ySlider.description = "Camera position Y".localized
        zSlider.description = "Camera position Z".localized
        thetaSlider.description = "Camera angle".localized
        wiggleXSlider.description = "Camera wiggle X".localized
        wiggleYSlider.description = "Camera wiggle Y".localized
        let children: [View] = [xView, xSlider, yView, ySlider, zView, zSlider, thetaView, thetaSlider, wiggleXView, wiggleXSlider, wiggleYView, wiggleYSlider]
        TransformView.centeredViews(children, in: layer.bounds)
        self.children = children
    }
    private static func centeredViews(_ views: [View], in bounds: CGRect, paddingWidth: CGFloat = 4) {
        let w = views.reduce(-paddingWidth) { $0 +  $1.frame.width + paddingWidth }
        _ = views.reduce(floor((bounds.width - w)/2)) { x, view in
            view.frame.origin = CGPoint(x: x, y: 0)
            return x + view.frame.width + paddingWidth
        }
    }
    
    var transform = Transform() {
        didSet {
            if transform != oldValue {
                updateSubviews()
            }
        }
    }
    func update() {
        transform = sceneView.timeline.selectionCutEntity.cut.editGroup.transformItem?.transform ?? Transform()
    }
    private func updateSubviews() {
        let b = sceneView.scene.cameraFrame
        xSlider.value = transform.position.x/b.width
        ySlider.value = transform.position.y/b.height
        zSlider.value = transform.scale.width
        thetaSlider.value = transform.rotation*180/(.pi)
        wiggleXSlider.value = 10*transform.wiggle.maxSize.width/b.width
        wiggleYSlider.value = 10*transform.wiggle.maxSize.height/b.height
    }
    
    override func copy() {
        screen?.copy(transform.data, forType: Transform.dataType, from: self)
    }
    override func paste() {
        if let data = screen?.copyData(forType: Transform.dataType) {
            let transform = Transform(data: data)
            let cutEntity = sceneView.timeline.selectionCutEntity
            let group = cutEntity.cut.editGroup
            if cutEntity.cut.isInterpolatedKeyframe(with: group) {
                sceneView.timeline.splitKeyframe(with: group)
            }
            setTransform(transform, at: group.editKeyframeIndex, in: group, cutEntity)
        }
    }
    
    private var oldTransform = Transform(), keyIndex = 0, isMadeTransformItem = false
    private weak var oldTransformItem: TransformItem?, group: Group?, cutEntity: CutEntity?
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: DragEvent.SendType) {
        switch type {
        case .begin:
            undoManager?.beginUndoGrouping()
            let cutEntity = sceneView.timeline.selectionCutEntity
            let group = cutEntity.cut.editGroup
            if cutEntity.cut.isInterpolatedKeyframe(with: group) {
                sceneView.timeline.splitKeyframe(with: group)
            }
            let t = transformWith(value: value, slider: slider, oldTransform: transform)
            oldTransformItem = group.transformItem
            if let transformItem = group.transformItem {
                oldTransform = transformItem.transform
                isMadeTransformItem = false
            } else {
                let transformItem = TransformItem.empty(with: group)
                setTransformItem(transformItem, in: group, cutEntity)
                oldTransform = transformItem.transform
                isMadeTransformItem = true
            }
            self.group = group
            self.cutEntity = cutEntity
            keyIndex = group.editKeyframeIndex
            setTransform(t, at: keyIndex, in: group, cutEntity)
        case .sending:
            if let group = group, let cutEntity = cutEntity {
                let t = transformWith(value: value, slider: slider, oldTransform: transform)
                setTransform(t, at: keyIndex, in: group, cutEntity)
            }
        case .end:
            if let group = group, let cutEntity = cutEntity {
                let t = transformWith(value: value, slider: slider, oldTransform: transform)
                setTransform(t, at: keyIndex, in: group, cutEntity)
                if let transformItem = group.transformItem {
                    if transformItem.isEmpty {
                        if isMadeTransformItem {
                            setTransformItem(nil, in: group, cutEntity)
                        } else {
                            setTransformItem(nil, oldTransformItem: oldTransformItem, in: group, cutEntity)
                        }
                    } else {
                        if isMadeTransformItem {
                            setTransformItem(transformItem, oldTransformItem: oldTransformItem, in: group, cutEntity)
                        }
                        if value != oldValue {
                            setTransform(t, oldTransform: oldTransform, at: keyIndex, in: group, cutEntity)
                        } else {
                            setTransform(oldTransform, at: keyIndex, in: group, cutEntity)
                        }
                    }
                }
            }
            undoManager?.endUndoGrouping()
        }
    }
    private func transformWith(value: CGFloat, slider: Slider, oldTransform t: Transform) -> Transform {
        let b = sceneView.scene.cameraFrame
        switch slider {
        case xSlider:
            return t.withPosition(CGPoint(x: value*b.width, y: t.position.y))
        case ySlider:
            return t.withPosition(CGPoint(x: t.position.x, y: value*b.height))
        case zSlider:
            return t.withScale(value)
        case thetaSlider:
            return t.withRotation(value*(.pi/180))
        case wiggleXSlider:
            return t.withWiggle(t.wiggle.withMaxSize(CGSize(width: value*b.width/10, height: t.wiggle.maxSize.height)))
        case wiggleYSlider:
            return t.withWiggle(t.wiggle.withMaxSize(CGSize(width: t.wiggle.maxSize.width, height: value*b.height/10)))
        default:
            return t
        }
    }
    private func setTransformItem(_ transformItem: TransformItem?, in group: Group, _ cutEntity: CutEntity) {
        group.transformItem = transformItem
        sceneView.timeline.setNeedsDisplay()
    }
    private func setTransform(_ transform: Transform, at index: Int, in group: Group, _ cutEntity: CutEntity) {
        group.transformItem?.replaceTransform(transform, at: index)
        cutEntity.cut.updateCamera()
        if cutEntity === sceneView.cutView.cutEntity {
            sceneView.cutView.updateViewAffineTransform()
        }
        self.transform = transform
    }
    private func setTransformItem(_ transformItem: TransformItem?, oldTransformItem: TransformItem?, in group: Group, _ cutEntity: CutEntity) {
        undoManager?.registerUndo(withTarget: self) { $0.setTransformItem(oldTransformItem, oldTransformItem: transformItem, in: group, cutEntity) }
        setTransformItem(transformItem, in: group, cutEntity)
        cutEntity.isUpdate = true
    }
    private func setTransform(_ transform: Transform, oldTransform: Transform, at i: Int, in group: Group, _ cutEntity: CutEntity) {
        undoManager?.registerUndo(withTarget: self) { $0.setTransform(oldTransform, oldTransform: transform, at: i, in: group, cutEntity) }
        setTransform(transform, at: i, in: group, cutEntity)
        cutEntity.isUpdate = true
    }
}

final class SoundView: View {
    var sceneView: SceneView!
    var scene = Scene() {
        didSet {
            updateSoundText(with: scene.soundItem.sound)
        }
    }
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    let drawLayer: DrawLayer
    
    init() {
        drawLayer = DrawLayer(fillColor: Defaults.subBackgroundColor.cgColor)
        textLine = TextLine(string: "No Sound".localized, font: Defaults.smallFont, color: Defaults.smallFontColor.cgColor, isVerticalCenter: true)
        
        super.init(layer: drawLayer)
        
        drawLayer.drawBlock = { [unowned self] ctx in
            if self.scene.soundItem.isHidden {
                ctx.setAlpha(0.25)
            }
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = SceneLayout.soundFrame
    }
    
    override func delete() {
        if scene.soundItem.sound != nil {
            setSound(nil, name: "")
        } else {
            screen?.tempNotAction()
        }
    }
    override func copy() {
        if let sound = scene.soundItem.sound {
            sound.write(to: NSPasteboard.general())
        } else {
            screen?.tempNotAction()
        }
    }
    override func paste() {
        if let sound = NSSound(pasteboard: NSPasteboard.general()) {
            setSound(sound, name: NSPasteboard.general().string(forType: NSPasteboardTypeString) ?? "")
        } else {
            screen?.tempNotAction()
        }
    }
    func setSound(_ sound: NSSound?, name: String) {
        undoManager?.registerUndo(withTarget: self) { [os = scene.soundItem.sound, on = scene.soundItem.name] in $0.setSound(os, name: on) }
        if sound == nil && scene.soundItem.sound?.isPlaying ?? false {
            scene.soundItem.sound?.stop()
        }
        scene.soundItem.sound = sound
        scene.soundItem.name = name
        updateSoundText(with: sound)
        sceneView.sceneEntity.isUpdatePreference = true
    }
    func updateSoundText(with sound: NSSound?) {
        if sound != nil {
            textLine.string = "♫ \(scene.soundItem.name)"
        } else {
            textLine.string = "No Sound".localized
        }
        layer.setNeedsDisplay()
    }
    
    override func show() {
        if scene.soundItem.isHidden {
            setIsHidden(false)
        } else {
            screen?.tempNotAction()
        }
    }
    override func hide() {
        if !scene.soundItem.isHidden {
            setIsHidden(true)
        } else {
            screen?.tempNotAction()
        }
    }
    func setIsHidden(_ isHidden: Bool) {
        undoManager?.registerUndo(withTarget: self) { [oh = scene.soundItem.isHidden] in $0.setIsHidden(oh) }
        scene.soundItem.isHidden = isHidden
        layer.setNeedsDisplay()
        sceneView.sceneEntity.isUpdatePreference = true
    }
}

final class SpeechView: View, TextViewDelegate {
    weak var sceneView: SceneView!
    var text = Text() {
        didSet {
            if text !== oldValue {
                textView.string = text.string
            }
        }
    }
    private let textView = TextView(frame: CGRect())
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.frame = CGRect()
        textView.delegate = self
        children = [textView]
    }
    func update() {
        text = sceneView.timeline.selectionCutEntity.cut.editGroup.textItem?.text ?? Text()
    }
    
    private var textPack: (oldText: Text, textItem: TextItem)?
    func changeText(textView: TextView, string: String, oldString: String, type: TextView.SendType) {
    }
    private func _setTextItem(_ textItem: TextItem?, oldTextItem: TextItem?, in group: Group, _ cutEntity: CutEntity) {
        undoManager?.registerUndo(withTarget: self) { $0._setTextItem(oldTextItem, oldTextItem: textItem, in: group, cutEntity) }
        group.textItem = textItem
        cutEntity.isUpdate = true
        sceneView.timeline.setNeedsDisplay()
    }
    private func _setText(_ text: Text, oldText: Text, at i: Int, in group: Group, _ cutEntity: CutEntity) {
        undoManager?.registerUndo(withTarget: self) { $0._setText(oldText, oldText: text, at: i, in: group, cutEntity) }
        group.textItem?.replaceText(text, at: i)
        group.textItem?.text = text
        sceneView.cutView.updateViewAffineTransform()
        sceneView.cutView.isUpdate = true
        self.text = text
    }
}
