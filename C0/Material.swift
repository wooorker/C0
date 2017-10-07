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
//マテリアルアニメーション
//コントラストなどのカラー編集
//アルファチェーン（連続する同じアルファのセル同士を同一の平面として描画）
//アナログ風の透過光
//マクロライト

import Foundation
import QuartzCore

final class Material: NSObject, NSCoding, Interpolatable {
    enum MaterialType: Int8, ByteCoding {
        case normal, lineless, blur, luster, glow, screen, multiply
        var isDrawLine: Bool {
            return self == .normal
        }
        var blendMode: CGBlendMode {
            switch self {
            case .normal, .lineless, .blur:
                return .normal
            case .luster, .glow:
                return .plusLighter
            case .screen:
                return .screen
            case .multiply:
                return .multiply
            }
        }
    }
    let color: Color, type: MaterialType, lineWidth: CGFloat, lineStrength: CGFloat, opacity: CGFloat, id: UUID, fillColor: CGColor, lineColor: CGColor
    init(color: Color = Color(), type: MaterialType = MaterialType.normal, lineWidth: CGFloat = SceneDefaults.strokeLineWidth, lineStrength: CGFloat = 0, opacity: CGFloat = 1) {
        self.color = color
        self.type = type
        self.lineWidth = lineWidth
        self.lineStrength = lineStrength
        self.opacity = opacity
        self.id = UUID()
        self.fillColor = color.nsColor.cgColor
        self.lineColor = Material.lineColorWith(color: color, lineStrength: lineStrength)
        super.init()
    }
    private init(color: Color = Color(), type: MaterialType = MaterialType.normal, lineWidth: CGFloat = SceneDefaults.strokeLineWidth, lineStrength: CGFloat = 0, opacity: CGFloat = 1, id: UUID = UUID(), fillColor: CGColor) {
        self.color = color
        self.type = type
        self.lineWidth = lineWidth
        self.lineStrength = lineStrength
        self.opacity = opacity
        self.id = id
        self.fillColor = fillColor
        self.lineColor = Material.lineColorWith(color: color, lineStrength: lineStrength)
        super.init()
    }
    private init(color: Color = Color(), type: MaterialType = MaterialType.normal, lineWidth: CGFloat = SceneDefaults.strokeLineWidth, lineStrength: CGFloat = 0, opacity: CGFloat = 1, id: UUID = UUID(), fillColor: CGColor, lineColor: CGColor) {
        self.color = color
        self.type = type
        self.lineWidth = lineWidth
        self.lineStrength = lineStrength
        self.opacity = opacity
        self.id = id
        self.fillColor = fillColor
        self.lineColor = lineColor
        super.init()
    }
    
    static let dataType = "C0.Material.1", colorKey = "0", typeKey = "1", lineWidthKey = "2", lineStrengthKey = "3", opacityKey = "4", idKey = "5"
    init?(coder: NSCoder) {
        color = coder.decodeStruct(forKey: Material.colorKey) ?? Color()
        type = coder.decodeStruct(forKey: Material.typeKey) ?? .normal
        lineWidth = coder.decodeDouble(forKey: Material.lineWidthKey).cf
        lineStrength = coder.decodeDouble(forKey: Material.lineStrengthKey).cf
        opacity = coder.decodeDouble(forKey: Material.opacityKey).cf
        id = coder.decodeObject(forKey: Material.idKey) as? UUID ?? UUID()
        fillColor = color.nsColor.cgColor
        lineColor = Material.lineColorWith(color: color, lineStrength: lineStrength)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(color, forKey: Material.colorKey)
        coder.encodeStruct(type, forKey: Material.typeKey)
        coder.encode(lineWidth.d, forKey: Material.lineWidthKey)
        coder.encode(lineStrength.d, forKey: Material.lineStrengthKey)
        coder.encode(opacity.d, forKey: Material.opacityKey)
        coder.encode(id, forKey: Material.idKey)
    }
    
    static func lineColorWith(color: Color, lineStrength: CGFloat) -> CGColor {
        return lineStrength == 0 ? Color().nsColor.cgColor : color.withLightness(CGFloat.linear(0, color.lightness, t: lineStrength)).nsColor.cgColor
    }
    func withNewID() -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor, lineColor: lineColor)
    }
    func withColor(_ color: Color) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    func withType(_ type: MaterialType) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor, lineColor: lineColor)
    }
    func withLineWidth(_ lineWidth: CGFloat) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor, lineColor: lineColor)
    }
    func withLineStrength(_ lineStrength: CGFloat) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor)
    }
    func withOpacity(_ opacity: CGFloat) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor)
    }
    
    static func linear(_ f0: Material, _ f1: Material, t: CGFloat) -> Material {
        let color = Color.linear(f0.color, f1.color, t: t)
        let type = f0.type
        let lineWidth = CGFloat.linear(f0.lineWidth, f1.lineWidth, t: t)
        let lineStrength = CGFloat.linear(f0.lineStrength, f1.lineStrength, t: t)
        let opacity = CGFloat.linear(f0.opacity, f1.opacity, t: t)
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func firstMonospline(_ f1: Material, _ f2: Material, _ f3: Material, with msx: MonosplineX) -> Material {
        let color = Color.firstMonospline(f1.color, f2.color, f3.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.firstMonospline(f1.lineWidth, f2.lineWidth, f3.lineWidth, with: msx)
        let lineStrength = CGFloat.firstMonospline(f1.lineStrength, f2.lineStrength, f3.lineStrength, with: msx)
        let opacity = CGFloat.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: msx)
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func monospline(_ f0: Material, _ f1: Material, _ f2: Material, _ f3: Material, with msx: MonosplineX) -> Material {
        let color = Color.monospline(f0.color, f1.color, f2.color, f3.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.monospline(f0.lineWidth, f1.lineWidth, f2.lineWidth, f3.lineWidth, with: msx)
        let lineStrength = CGFloat.monospline(f0.lineStrength, f1.lineStrength, f2.lineStrength, f3.lineStrength, with: msx)
        let opacity = CGFloat.monospline(f0.opacity, f1.opacity, f2.opacity, f3.opacity, with: msx)
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func endMonospline(_ f0: Material, _ f1: Material, _ f2: Material, with msx: MonosplineX) -> Material {
        let color = Color.endMonospline(f0.color, f1.color, f2.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.endMonospline(f0.lineWidth, f1.lineWidth, f2.lineWidth, with: msx)
        let lineStrength = CGFloat.endMonospline(f0.lineStrength, f1.lineStrength, f2.lineStrength, with: msx)
        let opacity = CGFloat.endMonospline(f0.opacity, f1.opacity, f2.opacity, with: msx)
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
}

final class MaterialEditor: Responder, ColorPickerDelegate, SliderDelegate, PulldownButtonDelegate {
    weak var sceneEditor: SceneEditor!
    
    private let colorPicker = ColorPicker(frame: SceneLayout.materialColorFrame)
    private let typeButton = PulldownButton(frame: SceneLayout.materialTypeFrame, names: [
        Localization(english: "Normal", japanese: "通常"),
        Localization(english: "Lineless", japanese: "線なし"),
        Localization(english: "Blur", japanese: "ぼかし"),
        Localization(english: "Luster", japanese: "光沢"),
        Localization(english: "Glow", japanese: "発光"),
        Localization(english: "Screen", japanese: "スクリーン"),
        Localization(english: "Multiply", japanese: "乗算")
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
    private let animationEditor: Responder = {
        let editor = Responder()
        editor.layer.frame = SceneLayout.materialAnimationFrame
        return editor
    }()
    
    static let emptyMaterial = Material()
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.backgroundColor = nil
        layer.frame = SceneLayout.materialFrame
        colorPicker.delegate = self
        typeButton.delegate = self
        lineWidthSlider.delegate = self
        lineStrengthSlider.delegate = self
        opacitySlider.delegate = self
        colorPicker.description = "Material color: Ring is hue, width is saturation, height is luminance".localized
        typeButton.description = "Material Type".localized
        lineWidthSlider.description = "Material Line Width".localized
        lineStrengthSlider.description = "Material Line Strength".localized
        opacitySlider.description = "Material Opacity".localized
        children = [colorPicker, typeButton, lineWidthSlider, lineStrengthSlider, opacitySlider, animationEditor]
    }
    
    var material = MaterialEditor.emptyMaterial {
        didSet {
            if material.id != oldValue.id {
                sceneEditor.sceneEntity.preference.scene.material = material
                sceneEditor.sceneEntity.isUpdatePreference = true
                colorPicker.color = material.color
                typeButton.selectionIndex = Int(material.type.rawValue)
                lineWidthSlider.value = material.lineWidth
                opacitySlider.value = material.opacity
                lineStrengthSlider.value = material.lineStrength
                sceneEditor.canvas.setNeedsDisplay()
            }
        }
    }
    
    var isEditing = false {
        didSet {
            sceneEditor.canvas.materialEditorType = isEditing ? .preview : (indication ? .selection : .none)
        }
    }
    override var indication: Bool {
        didSet {
            sceneEditor.canvas.materialEditorType = isEditing ? .preview : (indication ? .selection : .none)
        }
    }
    
    override func copy(with event: KeyInputEvent) {
        copy(material, from: self)
    }
    func copy(_ material: Material, from responder: Responder) {
        _setMaterial(material, oldMaterial: material)
        Screen.current?.copy(material.data, forType: Material.dataType, from: responder)
    }
    override func paste(with event: KeyInputEvent) {
        if let data = Screen.current?.copyData(forType: Material.dataType), let material = Material.with(data) {
            paste(material, withSelection: self.material, useSelection: false)
        }
    }
    func paste(_ material: Material, withSelection selectionMaterial: Material, useSelection: Bool) {
        let materialTuples = materialTuplesWith(material: selectionMaterial, useSelection: useSelection,
                                                in: sceneEditor.timeline.selectionCutEntity, sceneEditor.sceneEntity.cutEntities)
        for materialTuple in materialTuples.values {
            _setMaterial(material, in: materialTuple)
        }
    }
    func paste(_ color: Color, withSelection selectionMaterial: Material, useSelection: Bool) {
        let colorTuples = colorTuplesWith(color: selectionMaterial.color, useSelection: useSelection,
                                          in: sceneEditor.timeline.selectionCutEntity, sceneEditor.sceneEntity.cutEntities)
        _setColor(color, in: colorTuples)
    }
    func splitMaterial(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, in: sceneEditor.timeline.selectionCutEntity)
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withColor(materialTuple.material.color.withNewID()), in: materialTuple)
        }
    }
    func splitColor(with cells: [Cell]) {
        let colorTuples = colorTuplesWith(cells: cells, in: sceneEditor.timeline.selectionCutEntity)
        for colorTuple in colorTuples {
            let newColor = colorTuple.color.withNewID()
            for materialTuple in colorTuple.materialTuples.values {
                setMaterial(materialTuple.material.withColor(newColor), in: materialTuple)
            }
        }
    }
    func splitOtherThanColor(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, in: sceneEditor.timeline.selectionCutEntity)
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withColor(materialTuple.material.color), in: materialTuple)
        }
    }
    private func _setMaterial(_ material: Material, oldMaterial: Material, in cells: [Cell], _ cutEntity: CutEntity) {
        undoManager.registerUndo(withTarget: self) { $0._setMaterial(oldMaterial, oldMaterial: material, in: cells, cutEntity) }
        for cell in cells {
            cell.material = material
        }
        cutEntity.isUpdateMaterial = true
        if cutEntity === sceneEditor.canvas.cutEntity {
            sceneEditor.canvas.setNeedsDisplay()
        }
    }
    func select(_ material: Material) {
        _setMaterial(material, oldMaterial: self.material)
    }
    private func _setMaterial(_ material: Material, oldMaterial: Material) {
        undoManager.registerUndo(withTarget: self) { $0._setMaterial(oldMaterial, oldMaterial: material) }
        self.material = material
    }
    
    enum EditType {
        case color, material, correction
    }
    var editType = EditType.color {
        didSet{
            if editType != oldValue {
                sceneEditor.canvas.setNeedsDisplay()
            }
        }
    }
    
    enum ViewType {
        case none, selection, preview
    }
    private struct ColorTuple {
        var color: Color, materialTuples: [UUID: MaterialTuple]
    }
    private struct MaterialTuple {
        var material: Material, cutTuples: [CutTuple]
    }
    private struct CutTuple {
        var cutEntity: CutEntity, cells: [Cell]
    }
    
    private var materialTuples = [UUID: MaterialTuple](), colorTuples = [ColorTuple](), oldMaterialTuple: MaterialTuple?, oldMaterial: Material?
    private func colorTuplesWith(color: Color?, useSelection: Bool = false, in cutEntity: CutEntity, _ cutEntities: [CutEntity]) -> [ColorTuple] {
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
            var color: Color, cells: [Cell]
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
    private func colorTuplesWith(color: Color, in cutEntities: [CutEntity]) -> [ColorTuple] {
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
    
    private func changeMaterialWith(isColorTuple: Bool, type: Action.SendType) {
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
        sceneEditor.canvas.setNeedsDisplay()
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
    
    func changeColor(_ colorPicker: ColorPicker, color: Color, oldColor: Color, type: Action.SendType) {
        switch type {
        case .begin:
            isEditing = true
            colorTuples = colorTuplesWith(color: oldColor, in: sceneEditor.timeline.selectionCutEntity, sceneEditor.sceneEntity.cutEntities)
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
    private func setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                setMaterial(materialTuple.material.withColor(color), in: materialTuple)
            }
        }
    }
    private func _setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                _setMaterial(materialTuple.material.withColor(color), in: materialTuple)
            }
        }
    }
    
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType) {
        let materialType = Material.MaterialType(rawValue: Int8(index)) ?? .normal
        switch type {
        case .begin:
            isEditing = true
            materialTuples = materialTuplesWith(material: material, in: sceneEditor.timeline.selectionCutEntity, sceneEditor.sceneEntity.cutEntities)
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
    
    private var oldColor = Color()
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
        switch slider {
        case lineWidthSlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material, in: sceneEditor.timeline.selectionCutEntity, sceneEditor.sceneEntity.cutEntities)
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
                materialTuples = materialTuplesWith(material: material, in: sceneEditor.timeline.selectionCutEntity, sceneEditor.sceneEntity.cutEntities)
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
                materialTuples = materialTuplesWith(material: material, in: sceneEditor.timeline.selectionCutEntity, sceneEditor.sceneEntity.cutEntities)
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
}
