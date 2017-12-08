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

import Foundation.NSFileWrapper

final class DataModel {
    let key: String, isDirectory: Bool
    private var fileWrapper: FileWrapper
    init(key: String) {
        self.key = key
        self.fileWrapper = FileWrapper()
        self.fileWrapper.preferredFilename = key
        self.isDirectory = false
        self.children = [:]
    }
    init(key: String, directoryWithChildren children: [DataModel]) {
        self.key = key
        var dictionary = [String: FileWrapper]()
        children.forEach { dictionary[$0.key] = $0.fileWrapper }
        self.fileWrapper = FileWrapper(directoryWithFileWrappers: dictionary)
        self.isDirectory = true
        var keyChildren = [String: DataModel]()
        children.forEach { keyChildren[$0.key] = $0 }
        self.children = keyChildren
        children.forEach { $0.parent = self }
    }
    init(key: String, fileWrapper: FileWrapper) {
        self.key = key
        self.fileWrapper = fileWrapper
        if fileWrapper.isDirectory {
            self.isDirectory = true
            if let fileWrappers = fileWrapper.fileWrappers {
                var children = [String: DataModel]()
                fileWrappers.forEach { children[$0.key] = DataModel(key: $0.key, fileWrapper: $0.value) }
                self.children = children
                children.forEach { $0.value.parent = self }
            } else {
                self.children = [:]
            }
        } else {
            self.isDirectory = false
            self.children = [:]
        }
    }
    
    private(set) weak var parent: DataModel?
    private(set) var children: [String: DataModel]
    
    var noDuplicateChildrenKey: String {
        return fileWrapper.fileWrappers?.keys.max() ?? "0"
    }
    func set(_ dataModels: [DataModel]) {
        guard isDirectory else {
            fatalError()
        }
        guard !dataModels.isEmpty else {
            self.children.forEach { $0.value.parent = nil }
            self.children = [:]
            return
        }
        var dictionary = [String: FileWrapper]()
        dataModels.forEach { dictionary[$0.key] = $0.fileWrapper }
        self.fileWrapper = FileWrapper(directoryWithFileWrappers: dictionary)
        var keyChildren = [String: DataModel]()
        dataModels.forEach { keyChildren[$0.key] = $0 }
        self.children = keyChildren
        dataModels.forEach { $0.parent = self }
    }
    func insert(_ dataModel: DataModel) {
        guard isDirectory && children[dataModel.key] == nil else {
            fatalError()
        }
        dataModel.fileWrapper.preferredFilename = dataModel.key
        fileWrapper.addFileWrapper(dataModel.fileWrapper)
        children[dataModel.key] = dataModel
        dataModel.parent = self
    }
    func remove(_ dataModel: DataModel) {
        guard isDirectory && children[dataModel.key] != nil else {
            fatalError()
        }
        fileWrapper.removeFileWrapper(dataModel.fileWrapper)
        dataModel.parent = nil
        children[dataModel.key] = nil
    }
    
    private(set) var isRead = false
    private var object: CopyData?
    func readObject<T: CopyData>() -> T? {
        guard !isRead else {
            return object as? T
        }
        if let data = fileWrapper.regularFileContents, let object = T.with(data) {
            self.isRead = true
            self.object = object
            return object
        }
        return nil
    }
    
    var didChangeIsWriteHandler: ((DataModel, Bool) -> Void)? = nil
    var isWrite = false {
        didSet {
            if isWrite != oldValue {
                didChangeIsWriteHandler?(self, isWrite)
            }
        }
    }
    var dataHandler: () -> Data? = { nil }
    func writeFileWrapper() -> FileWrapper {
        if isWrite {
            if let data = dataHandler(), let parentFileWrapper = parent?.fileWrapper {
                parentFileWrapper.removeFileWrapper(fileWrapper)
                fileWrapper = FileWrapper(regularFileWithContents: data)
                fileWrapper.preferredFilename = key
                parentFileWrapper.addFileWrapper(fileWrapper)
            }
            self.isWrite = false
        }
        children.forEach { _ = $0.value.writeFileWrapper() }
        return fileWrapper
    }
}
