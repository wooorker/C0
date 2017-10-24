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

protocol SceneEntityDelegate: class {
    func changedUpdateWithPreference(_ sceneEntity: SceneEntity)
}
final class SceneEntity {
    let preferenceKey = "preference", cutsKey = "cuts", materialsKey = "materials"
    
    weak var delegate: SceneEntityDelegate?
    
    var preference = Preference(), cutEntities = [CutEntity]()
    
    init() {
        let cutEntity = CutEntity()
        cutEntity.sceneEntity = self
        cutEntities = [cutEntity]
        
        cutsFileWrapper = FileWrapper(directoryWithFileWrappers: [String(0): cutEntity.fileWrapper])
        materialsFileWrapper = FileWrapper(directoryWithFileWrappers: [String(0): cutEntity.materialWrapper])
        rootFileWrapper = FileWrapper(
            directoryWithFileWrappers: [
                preferenceKey : preferenceFileWrapper,
                cutsKey: cutsFileWrapper,
                materialsKey: materialsFileWrapper
            ]
        )
    }
    
    var rootFileWrapper = FileWrapper() {
        didSet {
            if let fileWrappers = rootFileWrapper.fileWrappers {
                if let fileWrapper = fileWrappers[preferenceKey] {
                    preferenceFileWrapper = fileWrapper
                }
                if let fileWrapper = fileWrappers[cutsKey] {
                    cutsFileWrapper = fileWrapper
                }
                if let fileWrapper = fileWrappers[materialsKey] {
                    materialsFileWrapper = fileWrapper
                }
            }
        }
    }
    var preferenceFileWrapper = FileWrapper()
    var cutsFileWrapper = FileWrapper() {
        didSet {
            if let fileWrappers = cutsFileWrapper.fileWrappers {
                let sortedFileWrappers = fileWrappers.sorted {
                    $0.key.localizedStandardCompare($1.key) == .orderedAscending
                }
                cutEntities = sortedFileWrappers.map {
                    return CutEntity(fileWrapper: $0.value, index: Int($0.key) ?? 0, sceneEntity: self)
                }
            }
        }
    }
    var materialsFileWrapper = FileWrapper() {
        didSet {
            if let fileWrappers = materialsFileWrapper.fileWrappers {
                let sortedFileWrappers = fileWrappers.sorted {
                    $0.key.localizedStandardCompare($1.key) == .orderedAscending
                }
                for (i, cutEntity) in cutEntities.enumerated() {
                    if i < sortedFileWrappers.count {
                        cutEntity.materialWrapper = sortedFileWrappers[i].value
                    }
                }
            }
        }
    }
    
    func read() {
        for cutEntity in cutEntities {
            cutEntity.read()
        }
    }
    
    func write() {
        writePreference()
        for cutEntity in cutEntities {
            cutEntity.write()
        }
    }
    
    func allWrite() {
        isUpdatePreference = true
        writePreference()
        for cutEntity in cutEntities {
            cutEntity.isUpdate = true
            cutEntity.isUpdateMaterial = true
            cutEntity.write()
        }
    }
    
    var isUpdatePreference = false {
        didSet {
            if isUpdatePreference != oldValue {
                delegate?.changedUpdateWithPreference(self)
            }
        }
    }
    func readPreference() {
        if let data = preferenceFileWrapper.regularFileContents, let preference = Preference.with(data) {
            self.preference = preference
        }
    }
    func writePreference() {
        if isUpdatePreference {
            writePreference(with: preference.data)
            isUpdatePreference = false
        }
    }
    func writePreference(with data: Data) {
        rootFileWrapper.removeFileWrapper(preferenceFileWrapper)
        preferenceFileWrapper = FileWrapper(regularFileWithContents: data)
        preferenceFileWrapper.preferredFilename = preferenceKey
        rootFileWrapper.addFileWrapper(preferenceFileWrapper)
    }
    
    func insert(_ cutEntity: CutEntity, at index: Int) {
        if index < cutEntities.count {
            for i in (index ..< cutEntities.count).reversed() {
                let cutEntity = cutEntities[i]
                cutsFileWrapper.removeFileWrapper(cutEntity.fileWrapper)
                cutEntity.fileWrapper.preferredFilename = String(i + 1)
                cutsFileWrapper.addFileWrapper(cutEntity.fileWrapper)
                
                materialsFileWrapper.removeFileWrapper(cutEntity.materialWrapper)
                cutEntity.materialWrapper.preferredFilename = String(i + 1)
                materialsFileWrapper.addFileWrapper(cutEntity.materialWrapper)
                
                cutEntity.index = i + 1
            }
        }
        cutEntity.fileWrapper.preferredFilename = String(index)
        cutEntity.index = index
        cutEntity.materialWrapper.preferredFilename = String(index)
        
        cutsFileWrapper.addFileWrapper(cutEntity.fileWrapper)
        materialsFileWrapper.addFileWrapper(cutEntity.materialWrapper)
        cutEntities.insert(cutEntity, at: index)
        cutEntity.sceneEntity = self
    }
    func removeCutEntity(at index: Int) {
        let cutEntity = cutEntities[index]
        cutsFileWrapper.removeFileWrapper(cutEntity.fileWrapper)
        materialsFileWrapper.removeFileWrapper(cutEntity.materialWrapper)
        cutEntity.sceneEntity = nil
        cutEntities.remove(at: index)
        
        for i in index ..< cutEntities.count {
            let cutEntity = cutEntities[i]
            cutsFileWrapper.removeFileWrapper(cutEntity.fileWrapper)
            cutEntity.fileWrapper.preferredFilename = String(i)
            cutsFileWrapper.addFileWrapper(cutEntity.fileWrapper)
            
            materialsFileWrapper.removeFileWrapper(cutEntity.materialWrapper)
            cutEntity.materialWrapper.preferredFilename = String(i)
            materialsFileWrapper.addFileWrapper(cutEntity.materialWrapper)
            
            cutEntity.index = i
        }
    }
    var cuts: [Cut] {
        return cutEntities.map { $0.cut }
    }
    
    func cutIndex(withTime time: Int) -> (index: Int, interTime: Int, isOver: Bool) {
        var t = 0
        for (i, cutEntity) in cutEntities.enumerated() {
            let nt = t + cutEntity.cut.timeLength
            if time < nt {
                return (i, time - t, false)
            }
            t = nt
        }
        return (cutEntities.count - 1, time - t, true)
    }
}

final class CutEntity: Equatable {
    weak var sceneEntity: SceneEntity!
    
    var cut: Cut, index: Int
    var fileWrapper = FileWrapper(), materialWrapper = FileWrapper()
    var isUpdate = false, isUpdateMaterial = false, useWriteMaterial = false, isReadContent = true
    
    init(fileWrapper: FileWrapper, index: Int, sceneEntity: SceneEntity? = nil) {
        cut = Cut()
        self.fileWrapper = fileWrapper
        self.index = index
        self.sceneEntity = sceneEntity
    }
    init(cut: Cut = Cut(), index: Int = 0) {
        self.cut = cut
        self.index = index
    }
    
    func read() {
        if let s = fileWrapper.preferredFilename {
            index = Int(s) ?? 0
        } else {
            index = 0
        }
        isReadContent = false
        readContent()
    }
    func readContent() {
        if !isReadContent {
            if let data = fileWrapper.regularFileContents, let cut = Cut.with(data) {
                self.cut = cut
            }
            if let materialsData = materialWrapper.regularFileContents, !materialsData.isEmpty {
                if let materialCellIDs = NSKeyedUnarchiver.unarchiveObject(with: materialsData) as? [MaterialCellID] {
                    cut.materialCellIDs = materialCellIDs
                    useWriteMaterial = true
                }
            }
            isReadContent = true
        }
    }
    func write() {
        if isUpdate {
            writeCut(with: cut.data)
            isUpdate = false
            isUpdateMaterial = false
            if useWriteMaterial {
                writeMaterials(with: Data())
                useWriteMaterial = false
            }
        }
        if isUpdateMaterial {
            writeMaterials(with: NSKeyedArchiver.archivedData(withRootObject: cut.materialCellIDs))
            isUpdateMaterial = false
            useWriteMaterial = true
        }
    }
    func writeCut(with data: Data) {
        sceneEntity.cutsFileWrapper.removeFileWrapper(fileWrapper)
        fileWrapper = FileWrapper(regularFileWithContents: data)
        fileWrapper.preferredFilename = String(index)
        sceneEntity.cutsFileWrapper.addFileWrapper(fileWrapper)
    }
    func writeMaterials(with data: Data) {
        sceneEntity.materialsFileWrapper.removeFileWrapper(materialWrapper)
        materialWrapper = FileWrapper(regularFileWithContents: data)
        materialWrapper.preferredFilename = String(index)
        sceneEntity.materialsFileWrapper.addFileWrapper(materialWrapper)
        
        isUpdateMaterial = false
    }
    
    static func == (lhs: CutEntity, rhs: CutEntity) -> Bool {
        return lhs === rhs
    }
}

final class MaterialCellID: NSObject, NSCoding {
    var material: Material, cellIDs: [UUID]
    
    init(material: Material, cellIDs: [UUID]) {
        self.material = material
        self.cellIDs = cellIDs
        super.init()
    }
    
    static let materialKey = "0", cellIDsKey = "1"
    init?(coder: NSCoder) {
        material = coder.decodeObject(forKey: MaterialCellID.materialKey) as? Material ?? Material()
        cellIDs = coder.decodeObject(forKey: MaterialCellID.cellIDsKey) as? [UUID] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(material, forKey: MaterialCellID.materialKey)
        coder.encode(cellIDs, forKey: MaterialCellID.cellIDsKey)
    }
}
