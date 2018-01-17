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

final class Material: NSObject, NSCoding {
    enum MaterialType: Int8, Codable {
        static let name = Localization(english: "Material Type", japanese: "マテリアルタイプ")
        case normal, lineless, blur, luster, add, subtract
        var isDrawLine: Bool {
            return self == .normal
        }
        var displayString: Localization {
            switch self {
            case .normal:
                return Localization(english: "Normal", japanese: "通常")
            case .lineless:
                return Localization(english: "Lineless", japanese: "線なし")
            case .blur:
                return Localization(english: "Blur", japanese: "ぼかし")
            case .luster:
                return Localization(english: "Luster", japanese: "光沢")
            case .add:
                return Localization(english: "Add", japanese: "加算")
            case .subtract:
                return Localization(english: "Subtract", japanese: "減算")
            }
        }
    }
    
    let type: MaterialType
    let color: Color, lineColor: Color
    let lineWidth: CGFloat, opacity: CGFloat
    let id: UUID
    
    static let defaultLineWidth = 1.0.cf
    init(type: MaterialType = .normal,
         color: Color = Color(), lineColor: Color = .black,
         lineWidth: CGFloat = defaultLineWidth, opacity: CGFloat = 1) {
        
        self.color = color
        self.lineColor = lineColor
        self.type = type
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.id = UUID()
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, color, lineColor, lineWidth, opacity, id
    }
    init?(coder: NSCoder) {
        type = MaterialType(
            rawValue: Int8(coder.decodeInt32(forKey: CodingKeys.type.rawValue))) ?? .normal
        color = coder.decodeDecodable(Color.self, forKey: CodingKeys.color.rawValue) ?? Color()
        lineColor = coder.decodeDecodable(
            Color.self, forKey: CodingKeys.lineColor.rawValue) ?? Color()
        lineWidth = coder.decodeDouble(forKey: CodingKeys.lineWidth.rawValue).cf
        opacity = coder.decodeDouble(forKey: CodingKeys.opacity.rawValue).cf
        id = coder.decodeObject(forKey: CodingKeys.id.rawValue) as? UUID ?? UUID()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(Int32(type.rawValue), forKey: CodingKeys.type.rawValue)
        coder.encodeEncodable(color, forKey: CodingKeys.color.rawValue)
        coder.encodeEncodable(lineColor, forKey: CodingKeys.lineColor.rawValue)
        coder.encode(lineWidth.d, forKey: CodingKeys.lineWidth.rawValue)
        coder.encode(opacity.d, forKey: CodingKeys.opacity.rawValue)
        coder.encode(id, forKey: CodingKeys.id.rawValue)
    }
    
    func with(_ type: MaterialType) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func with(_ color: Color) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func with(lineColor: Color) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func with(lineWidth: CGFloat) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func with(opacity: CGFloat) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func withNewID() -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
}

extension Material: Referenceable {
    static let name = Localization(english: "Material", japanese: "マテリアル")
}
extension Material: Interpolatable {
    static func linear(_ f0: Material, _ f1: Material, t: CGFloat) -> Material {
        guard f0.id != f1.id else {
            return f0
        }
        let type = f0.type
        let color = Color.linear(f0.color, f1.color, t: t)
        let lineColor = Color.linear(f0.lineColor, f1.lineColor, t: t)
        let lineWidth = CGFloat.linear(f0.lineWidth, f1.lineWidth, t: t)
        let opacity = CGFloat.linear(f0.opacity, f1.opacity, t: t)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func firstMonospline(_ f1: Material, _ f2: Material, _ f3: Material,
                                with msx: MonosplineX) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let type = f1.type
        let color = Color.firstMonospline(f1.color, f2.color, f3.color, with: msx)
        let lineColor = Color.firstMonospline(f1.lineColor, f2.lineColor, f3.lineColor, with: msx)
        let lineWidth = CGFloat.firstMonospline(f1.lineWidth, f2.lineWidth, f3.lineWidth, with: msx)
        let opacity = CGFloat.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: msx)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func monospline(_ f0: Material, _ f1: Material, _ f2: Material, _ f3: Material,
                           with msx: MonosplineX) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let type = f1.type
        let color = Color.monospline(f0.color, f1.color, f2.color, f3.color, with: msx)
        let lineColor = Color.monospline(f0.lineColor, f1.lineColor,
                                         f2.lineColor, f3.lineColor, with: msx)
        let lineWidth = CGFloat.monospline(f0.lineWidth, f1.lineWidth,
                                           f2.lineWidth, f3.lineWidth, with: msx)
        let opacity = CGFloat.monospline(f0.opacity, f1.opacity, f2.opacity, f3.opacity, with: msx)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func lastMonospline(_ f0: Material, _ f1: Material, _ f2: Material,
                              with msx: MonosplineX) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let type = f1.type
        let color = Color.lastMonospline(f0.color, f1.color, f2.color, with: msx)
        let lineColor = Color.lastMonospline(f0.lineColor, f1.lineColor, f2.lineColor, with: msx)
        let lineWidth = CGFloat.lastMonospline(f0.lineWidth, f1.lineWidth, f2.lineWidth, with: msx)
        let opacity = CGFloat.lastMonospline(f0.opacity, f1.opacity, f2.opacity, with: msx)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
}
extension Material: Layerable {
    func layer(withBounds bounds: CGRect) -> Layer {
        let layer = Layer()
        layer.bounds = bounds
        layer.fillColor = color
        return layer
    }
}

extension Material.MaterialType {
    var blendMode: CGBlendMode {
        switch self {
        case .normal, .lineless, .blur:
            return .normal
        case .luster, .add:
            return .plusLighter
        case .subtract:
            return .plusDarker
        }
    }
}

/**
 # Issue
 - マテリアルアニメーション
 - Sceneを取り除く
 - 「線の強さ」を追加
 */
final class MaterialEditor: Layer, Respondable {
    static let name = Localization(english: "Material Editor", japanese: "マテリアルエディタ")
    
    lazy var scene = Scene()
    var setMaterialHandler: ((MaterialEditor, Material) -> ())?
    var material = MaterialEditor.defaultMaterial {
        didSet {
            guard material.id != oldValue.id else {
                return
            }
            scene.editMaterial = material
            typeButton.selectionIndex = Int(material.type.rawValue)
            colorEditor.color = material.color
            lineColorEditor.color = material.lineColor
            lineWidthSlider.value = material.lineWidth
            opacitySlider.value = material.opacity
            setMaterialHandler?(self, material)
        }
    }
    static let defaultMaterial = Material()
    
    static let colorEditorWidth = 140.0.cf
    
    let nameLabel = Label(text: Material.name, font: .bold)
    
    let typeButton = PulldownButton(names: [Material.MaterialType.normal.displayString,
                                            Material.MaterialType.lineless.displayString,
                                            Material.MaterialType.blur.displayString,
                                            Material.MaterialType.luster.displayString,
                                            Material.MaterialType.add.displayString,
                                            Material.MaterialType.subtract.displayString],
                                    description: Localization(english: "Type", japanese: "タイプ"))
    let colorEditor = ColorEditor()
    
    let lineWidthSlider = Slider(min: Material.defaultLineWidth, max: 500, exp: 3,
                                 description: Localization(english: "Line Width", japanese: "線の太さ"))
    static func lineWidthLayer(with bounds: CGRect, padding: CGFloat) -> Layer {
        let shapeLayer = PathLayer()
        shapeLayer.fillColor = .content
        shapeLayer.path = {
            let path = CGMutablePath(), halfWidth = 5.0.cf
            path.addLines(between: [CGPoint(x: padding,y: bounds.height / 2),
                                    CGPoint(x: bounds.width - padding,
                                            y: bounds.height / 2 - halfWidth),
                                    CGPoint(x: bounds.width - padding,
                                            y: bounds.height / 2 + halfWidth)])
            return path
        } ()
        return shapeLayer
    }
    
    let opacitySlider = Slider(value: 1, defaultValue: 1, min: 0, max: 1,
                               description: Localization(english: "Opacity", japanese: "不透明度"))
    static func opacitySliderLayers(with bounds: CGRect, padding: CGFloat) -> [Layer] {
        let checkerWidth = 5.0.cf
        let frame = CGRect(x: padding, y: bounds.height / 2 - checkerWidth,
                           width: bounds.width - padding * 2, height: checkerWidth * 2)
        
        let backgroundLayer = GradientLayer()
        backgroundLayer.gradient = Gradient(colors: [.subContent, .content],
                                            locations: [0, 1],
                                            startPoint: CGPoint(x: 0, y: 0),
                                            endPoint: CGPoint(x: 1, y: 0))
        backgroundLayer.frame = frame
        
        let checkerboardLayer = PathLayer()
        checkerboardLayer.fillColor = .content
        checkerboardLayer.path = CGPath.checkerboard(with: CGSize(square: checkerWidth), in: frame)
        
        return [backgroundLayer, checkerboardLayer]
    }
    
    let lineColorLabel = Label(text: Localization(english: "Line Color:", japanese: "線のカラー:"))
    let lineColorEditor = ColorEditor(hLineWidth: 2,
                                      inPadding: 4, outPadding: 4, slPadding: 4, knobRadius: 4)
    
    override init() {
        super.init()
        replace(children: [nameLabel,
                           typeButton,
                           colorEditor, lineColorLabel, lineColorEditor,
                           lineWidthSlider, opacitySlider])
        
        typeButton.disabledRegisterUndo = true
        typeButton.setIndexHandler = { [unowned self] in
            self.changeValue($0.pulldownButton, index: $0.index, oldIndex: $0.oldIndex, type: $0.type)
        }
        
        colorEditor.disabledRegisterUndo = true
        colorEditor.setColorHandler = { [unowned self] in
            self.changeColor($0.colorEditor,
                             color: $0.color, oldColor: $0.oldColor, type: $0.type)
        }
        lineColorEditor.disabledRegisterUndo = true
        lineColorEditor.setColorHandler = { [unowned self] in
            self.changeColor($0.colorEditor,
                             color: $0.color, oldColor: $0.oldColor, type: $0.type)
        }
        
        lineWidthSlider.setValueHandler = { [unowned self] in
            self.changeValue($0.slider, value: $0.value, oldValue: $0.oldValue, type: $0.type)
        }
        opacitySlider.setValueHandler = { [unowned self] in
            self.changeValue($0.slider, value: $0.value, oldValue: $0.oldValue, type: $0.type)
        }
    }
    
    override var defaultBounds: CGRect {
        return CGRect(x: 0, y: 0,
                      width: MaterialEditor.colorEditorWidth,
                      height: MaterialEditor.colorEditorWidth + nameLabel.frame.height
                        + Layout.basicHeight * 4 + Layout.basicPadding * 3)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding, h = Layout.basicHeight
        let cw = bounds.width - padding * 2
        let leftWidth = cw - h * 3
        nameLabel.frame.origin = CGPoint(x: padding, y: padding * 2 + h * 4 + cw)
        typeButton.frame = CGRect(x: padding, y: padding + h * 3 + cw, width: cw, height: h)
        colorEditor.frame = CGRect(x: padding, y: padding + h * 3, width: cw, height: cw)
        lineColorLabel.frame.origin = CGPoint(x: padding + leftWidth - lineColorLabel.frame.width,
                                              y: padding * 2)
        lineColorEditor.frame = CGRect(x: padding + leftWidth, y: padding, width: h * 3, height: h * 3)
        lineWidthSlider.frame = CGRect(x: padding, y: padding + h * 2, width: leftWidth, height: h)
        let lineWidthLayer = MaterialEditor.lineWidthLayer(with: lineWidthSlider.bounds,
                                                           padding: lineWidthSlider.padding)
        lineWidthSlider.backgroundLayers = [lineWidthLayer]
        opacitySlider.frame = CGRect(x: padding, y: padding + h, width: leftWidth, height: h)
        let opacitySliderLayers = MaterialEditor.opacitySliderLayers(with: opacitySlider.bounds,
                                                                     padding: opacitySlider.padding)
        opacitySlider.backgroundLayers = opacitySliderLayers
    }
    
    func splitColor(at point: CGPoint) {
        let node = scene.editCutItem.cut.editNode
        let ict = node.indicatedCellsTuple(with: point,
                                            reciprocalScale: scene.reciprocalScale)
        if !ict.cellItems.isEmpty {
            splitColor(with: ict.cellItems.map { $0.cell })
        }
    }
    func splitOtherThanColor(at point: CGPoint) {
        let node = scene.editCutItem.cut.editNode
        let ict = node.indicatedCellsTuple(with: point,
                                            reciprocalScale: scene.reciprocalScale)
        if !ict.cellItems.isEmpty {
            splitOtherThanColor(with: ict.cellItems.map { $0.cell })
        }
    }
    
    var editPointInScene = CGPoint()
    
    var setIsEditingHandler: ((MaterialEditor, Bool) -> ())?
    var setIsSubIndicatedHandler: ((MaterialEditor, Bool) -> ())?
    var isEditing = false {
        didSet {
            setIsEditingHandler?(self, isEditing)
        }
    }
    override var isSubIndicated: Bool {
        didSet {
            setIsSubIndicatedHandler?(self, isSubIndicated)
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [material])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let material = object as? Material {
                paste(material, withSelection: self.material, useSelection: false)
                return true
            }
        }
        return false
    }
    func paste(_ material: Material, withSelection selectionMaterial: Material, useSelection: Bool) {
        let materialTuples = materialTuplesWith(
            material: selectionMaterial, useSelection: useSelection,
            in: scene.editCutItem, scene.cutItems
        )
        for materialTuple in materialTuples.values {
            _set(material, in: materialTuple)
        }
    }
    func paste(_ color: Color, withSelection selectionMaterial: Material, useSelection: Bool) {
        let colorTuples = colorTuplesWith(
            color: selectionMaterial.color, useSelection: useSelection,
            in: scene.editCutItem, scene.cutItems
        )
        _setColor(color, in: colorTuples)
    }
    func splitMaterial(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, isSelection: true,
                                                in: scene.editCutItem)
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(materialTuple.material.color.withNewID()),
                 in: materialTuple)
        }
    }
    func splitColor(with cells: [Cell]) {
        let colorTuples = colorTuplesWith(cells: cells, isSelection: true,
                                          in: scene.editCutItem)
        for colorTuple in colorTuples {
            let newColor = colorTuple.color.withNewID()
            for materialTuple in colorTuple.materialTuples.values {
                _set(materialTuple.material.with(newColor), in: materialTuple)
            }
        }
        if let material =
            colorTuples.first?.materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _set(material, old: self.material)
        }
    }
    func splitOtherThanColor(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, isSelection: true,
                                                in: scene.editCutItem)
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(materialTuple.material.color),
                 in: materialTuple)
        }
        if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _set(material, old: self.material)
        }
    }
    var setMaterialWithCutItemHandler: ((MaterialEditor, Material, CutItem) -> ())?
    private func _set(_ material: Material, old oldMaterial: Material,
                      in cells: [Cell], _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0._set(oldMaterial, old: material, in: cells, cutItem)
        }
        cells.forEach {
            $0.material = material
        }
        cutItem.cutDataModel.isWrite = true
        setMaterialWithCutItemHandler?(self, material, cutItem)
    }
    func select(_ material: Material) {
        _set(material, old: self.material)
    }
    private func _set(_ material: Material, old oldMaterial: Material) {
        undoManager?.registerUndo(withTarget: self) { $0._set(oldMaterial, old: material) }
        self.material = material
    }
    
    var isAnimation: Bool {
        for materialItem in scene.editCutItem.cut.editNode.editTrack.materialItems {
            if materialItem.keyMaterials.contains(material) {
                return true
            }
        }
        return false
    }
    
    func cells(with cut: Cut) -> [Cell] {
        var cells = [Cell]()
        cut.rootNode.allChildrenAndSelf {
            cells += $0.rootCell.allCells
        }
        return cells
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
        var cutItem: CutItem, cells: [Cell], materialItemTuples: [MaterialItemTuple]
    }
    private struct MaterialItemTuple {
        var track: NodeTrack, materialItem: MaterialItem, editIndexes: [Int]
        static func materialItemTuples(with materialItem: MaterialItem,
                                       isSelection: Bool, in track: NodeTrack
            ) -> [UUID: (material: Material, itemTupe: MaterialItemTuple)] {
            
            var materialItemTuples = [UUID: (material: Material, itemTupe: MaterialItemTuple)]()
            for (i, material) in materialItem.keyMaterials.enumerated() {
                if materialItemTuples[material.id] == nil {
                    let indexes: [Int]
                    if isSelection {
                        indexes = [track.animation.editKeyframeIndex]
                    } else {
                        indexes = (i ..< materialItem.keyMaterials.count)
                            .filter { materialItem.keyMaterials[$0].id == material.id }
                    }
                    materialItemTuples[material.id] = (material,
                                                       MaterialItemTuple(track: track,
                                                                         materialItem: materialItem,
                                                                         editIndexes: indexes))
                }
            }
            return materialItemTuples
        }
    }
    
    private var materialTuples = [UUID: MaterialTuple](), colorTuples = [ColorTuple]()
    private var oldMaterialTuple: MaterialTuple?, oldMaterial: Material?
    private func colorTuplesWith(color: Color?, useSelection: Bool = false,
                                 in cutItem: CutItem, _ cutItems: [CutItem]) -> [ColorTuple] {
        if useSelection {
            let allSelectionCells = cutItem.cut.editNode.allSelectionCellItemsWithNoEmptyGeometry
            if !allSelectionCells.isEmpty {
                return colorTuplesWith(cells: allSelectionCells.map { $0.cell },
                                       isSelection: useSelection, in: cutItem)
            }
        }
        if let color = color {
            return colorTuplesWith(color: color, isSelection: useSelection, in: cutItems)
        } else {
            return colorTuplesWith(cells: cells(with: cutItem.cut),
                                   isSelection: useSelection, in: cutItem)
        }
    }
    private func colorTuplesWith(cells: [Cell], isSelection: Bool,
                                 in cutItem: CutItem) -> [ColorTuple] {
        struct ColorCell {
            var color: Color, cells: [Cell]
        }
        var colorDic = [UUID: ColorCell]()
        for cell in cells {
            if colorDic[cell.material.color.id] != nil {
                colorDic[cell.material.color.id]?.cells.append(cell)
            } else {
                colorDic[cell.material.color.id] = ColorCell(color: cell.material.color,
                                                             cells: [cell])
            }
        }
        return colorDic.map {
            ColorTuple(color: $0.value.color,
                       materialTuples: materialTuplesWith(cells: $0.value.cells,
                                                          isSelection: isSelection, in: cutItem))
        }
    }
    private func colorTuplesWith(color: Color, isSelection: Bool,
                                 in cutItems: [CutItem]) -> [ColorTuple] {
        var materialTuples = [UUID: MaterialTuple]()
        for cutItem in cutItems {
            let cells = self.cells(with: cutItem.cut).filter { $0.material.color == color }
            if !cells.isEmpty {
                let mts = materialTuplesWith(cells: cells, color: color,
                                             isSelection: isSelection, in: cutItem)
                for mt in mts {
                    if materialTuples[mt.key] != nil {
                        materialTuples[mt.key]?.cutTuples += mt.value.cutTuples
                    } else {
                        materialTuples[mt.key] = mt.value
                    }
                }
            }
        }
        return materialTuples.isEmpty ? [] : [ColorTuple(color: color,
                                                         materialTuples: materialTuples)]
    }
    
    private func materialTuplesWith(cells: [Cell], color: Color? = nil,
                                    isSelection: Bool, in cutItem: CutItem) -> [UUID: MaterialTuple] {
        var materialDic = [UUID: MaterialTuple]()
        for cell in cells {
            if materialDic[cell.material.id] != nil {
                materialDic[cell.material.id]?.cutTuples[0].cells.append(cell)
            } else {
                let cutTuples = [CutTuple(cutItem: cutItem, cells: [cell], materialItemTuples: [])]
                materialDic[cell.material.id] = MaterialTuple(material: cell.material,
                                                              cutTuples: cutTuples)
            }
        }
        
        for track in cutItem.cut.editNode.tracks {
            for materialItem in track.materialItems {
                if cells.contains(where: { materialItem.cells.contains($0) }) {
                    let materialItemTuples = MaterialItemTuple.materialItemTuples(
                        with: materialItem, isSelection: isSelection, in: track)
                    for materialItemTuple in materialItemTuples {
                        if let color = color {
                            if materialItemTuple.value.material.color != color {
                                continue
                            }
                        }
                        if materialDic[materialItemTuple.key] != nil {
                            materialDic[materialItemTuple.key]?.cutTuples[0]
                                .materialItemTuples.append(materialItemTuple.value.itemTupe)
                        } else {
                            let materialItemTuples = [materialItemTuple.value.itemTupe]
                            let cutTuples = [CutTuple(cutItem: cutItem, cells: [],
                                                      materialItemTuples: materialItemTuples)]
                            materialDic[materialItemTuple.key] = MaterialTuple(
                                material: materialItemTuple.value.material,
                                cutTuples: cutTuples
                            )
                        }
                    }
                }
            }
        }
        
        return materialDic
    }
    private func materialTuplesWith(material: Material?, useSelection: Bool = false,
                                    in cutItem: CutItem,
                                    _ cutItems: [CutItem]) -> [UUID: MaterialTuple] {
        if useSelection {
            let allSelectionCells = cutItem.cut.editNode.allSelectionCellItemsWithNoEmptyGeometry
            if !allSelectionCells.isEmpty {
                return materialTuplesWith(cells: allSelectionCells.map { $0.cell },
                                          isSelection: useSelection, in: cutItem)
            }
        }
        if let material = material {
            let cutTuples: [CutTuple] = cutItems.flatMap { cutItem in
                let cells = self.cells(with: cutItem.cut).filter { $0.material.id == material.id }
                
                var materialItemTuples = [MaterialItemTuple]()
                for track in cutItem.cut.editNode.tracks {
                    for materialItem in track.materialItems {
                        let indexes = useSelection ?
                            [track.animation.editKeyframeIndex] :
                            materialItem.keyMaterials.enumerated().flatMap {
                                $0.element.id == material.id ? $0.offset : nil }
                        if !indexes.isEmpty {
                            materialItemTuples.append(MaterialItemTuple(track: track,
                                                                        materialItem: materialItem,
                                                                        editIndexes: indexes))
                        }
                    }
                }
                
                return cells.isEmpty && materialItemTuples.isEmpty ?
                    nil : CutTuple(cutItem: cutItem, cells: cells,
                                   materialItemTuples: materialItemTuples)
            }
            return cutTuples.isEmpty ? [:] : [material.id: MaterialTuple(material: material,
                                                                         cutTuples: cutTuples)]
        } else {
            return materialTuplesWith(cells: cells(with: cutItem.cut),
                                      isSelection: useSelection, in: cutItem)
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
            oldMaterialTuple = isColorTuple ?
                selectionMaterialTuple(with: colorTuples) :
                selectionMaterialTuple(with: materialTuples)
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .sending:
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .end:
            if let oldMaterialTuple = oldMaterialTuple {
                _set(oldMaterialTuple.cutTuples[0].cells[0].material,
                     old: oldMaterialTuple.material)
            }
            oldMaterialTuple = nil
        }
    }
    private func set(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            for cell in cutTuple.cells {
                cell.material = material
            }
            for materialItemTuple in cutTuple.materialItemTuples {
                var keyMaterials = materialItemTuple.materialItem.keyMaterials
                materialItemTuple.editIndexes.forEach { keyMaterials[$0] = material }
                materialItemTuple.track.set(keyMaterials, in: materialItemTuple.materialItem)
                materialItemTuple.materialItem.cells.forEach { $0.material = material }
            }
        }
    }
    private func _set(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            _set(material, old: materialTuple.material,
                 in: cutTuple.cells, cutTuple.cutItem)
        }
    }
    
    private func append(_ materialItem: MaterialItem, in track: NodeTrack, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) { $0.remove(materialItem, in: track, cutItem) }
        track.append(materialItem)
        cutItem.cutDataModel.isWrite = true
    }
    private func remove(_ materialItem: MaterialItem, in track: NodeTrack, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.append(materialItem, in: track, cutItem)
        }
        track.remove(materialItem)
        cutItem.cutDataModel.isWrite = true
    }
    
    func changeValue(_ pulldownButton: PulldownButton,
                     index: Int, oldIndex: Int, type: Action.SendType) {
        let materialType = Material.MaterialType(rawValue: Int8(index)) ?? .normal
        switch type {
        case .begin:
            isEditing = true
            materialTuples = materialTuplesWith(material: material,
                                                in: scene.editCutItem, scene.cutItems)
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
    private func changeAnimation(_ pulldownButton: PulldownButton,
                                 index: Int, oldIndex: Int, type: Action.SendType) {
        let isAnimation = self.isAnimation
        if index == 0 && !isAnimation {
            let cutItem =  scene.editCutItem
            let track = cutItem.cut.editNode.editTrack
            let keyMaterials = track.emptyKeyMaterials(with: material)
            let cells = self.cells(with: cutItem.cut).filter { $0.material == material }
            append(MaterialItem(material: material, cells: cells, keyMaterials: keyMaterials),
                   in: track, cutItem)
        } else if isAnimation {
            let cutItem =  scene.editCutItem
            let track = cutItem.cut.editNode.editTrack
            remove(track.materialItems[track.materialItems.count - 1],
                   in: cutItem.cut.editNode.editTrack, cutItem)
        }
    }
    private func setMaterialType(_ type: Material.MaterialType,
                                 in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(type), in: materialTuple)
        }
    }
    private func _setMaterialType(_ type: Material.MaterialType,
                                  in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(type), in: materialTuple)
        }
    }
    
    func changeColor(_ colorEditor: ColorEditor,
                     color: Color, oldColor: Color, type: Action.SendType) {
        switch colorEditor {
        case self.colorEditor:
            switch type {
            case .begin:
                isEditing = true
                colorTuples = colorTuplesWith(color: oldColor,
                                              in: scene.editCutItem, scene.cutItems)
                setColor(color, in: colorTuples)
            case .sending:
                setColor(color, in: colorTuples)
            case .end:
                _setColor(color, in: colorTuples)
                colorTuples = []
                isEditing = false
            }
            changeMaterialWith(isColorTuple: true, type: type)
        case lineColorEditor:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material,
                                                    in: scene.editCutItem, scene.cutItems)
                setLineColor(color, in: materialTuples)
            case .sending:
                setLineColor(color, in: materialTuples)
            case .end:
                _setLineColor(color, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
            changeMaterialWith(isColorTuple: false, type: type)
        default:
            fatalError("No case")
        }
    }
    private func setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                set(materialTuple.material.with(color), in: materialTuple)
            }
        }
    }
    private func _setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                _set(materialTuple.material.with(color), in: materialTuple)
            }
        }
    }
    private func setLineColor(_ lineColor: Color, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(lineColor: lineColor), in: materialTuple)
        }
    }
    private func _setLineColor(_ lineColor: Color, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(lineColor: lineColor), in: materialTuple)
        }
    }
    
    private var oldColor = Color()
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
        switch slider {
        case lineWidthSlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material,
                                                    in: scene.editCutItem, scene.cutItems)
                setLineWidth(value, in: materialTuples)
            case .sending:
                setLineWidth(value, in: materialTuples)
            case .end:
                _setLineWidth(value, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
        case opacitySlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material,
                                                    in: scene.editCutItem, scene.cutItems)
                setOpacity(value, in: materialTuples)
            case .sending:
                setOpacity(value, in: materialTuples)
            case .end:
                _setOpacity(value, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
        default:
            fatalError("No case")
        }
        changeMaterialWith(isColorTuple: false, type: type)
    }
    private func setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(lineWidth: lineWidth), in: materialTuple)
        }
    }
    private func _setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(lineWidth: lineWidth), in: materialTuple)
        }
    }
    private func setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(opacity: opacity), in: materialTuple)
        }
    }
    private func _setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(opacity: opacity), in: materialTuple)
        }
    }
}
