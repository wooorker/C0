/*
 Copyright 2018 S
 
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

/**
 # Issue
 - Versionクラス
 - バージョン管理UndoManager
 - ブランチ機能
 */
final class VersionEditor: Layer, Respondable, Localizable {
    static let name = Localization(english: "Version Editor", japanese: "バージョンエディタ")
    static let feature = Localization(english: "Show undoable count and undoed count in parent editor",
                                      japanese: "親エディタでの取り消し可能回数、取り消し済み回数を表示")
    
    private var undoGroupToken: NSObjectProtocol?
    private var undoToken: NSObjectProtocol?, redoToken: NSObjectProtocol?
    var rootUndoManager: UndoManager? {
        didSet {
            removeNotification()
            let nc = NotificationCenter.default
            
            undoGroupToken = nc.addObserver(forName: .NSUndoManagerDidCloseUndoGroup,
                                            object: rootUndoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.rootUndoManager {
                    
                    if undoManager.groupingLevel == 0 {
                        self.undoCount += 1
                        self.allCount = self.undoCount
                        self.updateLabel()
                    }
                }
            }
            
            undoToken = nc.addObserver(forName: .NSUndoManagerDidUndoChange,
                                       object: rootUndoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.rootUndoManager {
                    
                    self.undoCount -= 1
                    self.updateLabel()
                }
            }
            
            redoToken = nc.addObserver(forName: .NSUndoManagerDidRedoChange,
                                       object: rootUndoManager, queue: nil)
            { [unowned self] notification in
                if let undoManager = notification.object as? UndoManager,
                    undoManager == self.rootUndoManager {
                    
                    self.undoCount += 1
                    self.updateLabel()
                }
            }
            
            updateLabel()
        }
    }
    override var undoManager: UndoManager? {
        return rootUndoManager
    }
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    var undoCount = 0, allCount = 0
    
    let nameLabel = Label(text: Localization(english: "Version", japanese: "バージョン"), font: .bold)
    let allCountLabel = Label(text: Localization("0"))
    let currentCountLabel = Label(color: .warning)
    override init() {
        allCountLabel.noIndicatedLineColor = .border
        allCountLabel.indicatedLineColor = .indicated
        currentCountLabel.noIndicatedLineColor = .border
        currentCountLabel.indicatedLineColor = .indicated
        
        _ = Layout.leftAlignment([nameLabel, Padding(), allCountLabel],
                                 height: Layout.basicHeight)
        super.init()
        isClipped = true
        replace(children: [nameLabel, allCountLabel])
    }
    deinit {
        removeNotification()
    }
    func removeNotification() {
        if let token = undoGroupToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = undoToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = redoToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLabel() {
        if undoCount < allCount {
            allCountLabel.localization = Localization("\(allCount)")
            currentCountLabel.localization = Localization("\(undoCount - allCount)")
            if currentCountLabel.parent == nil {
                replace(children: [nameLabel, allCountLabel, currentCountLabel])
                updateLayout()
            }
        } else {
            allCountLabel.localization = Localization("\(allCount)")
            if currentCountLabel.parent != nil {
                replace(children: [nameLabel, allCountLabel])
                updateLayout()
            }
        }
    }
    func updateLayout() {
        if undoCount < allCount {
            _ = Layout.leftAlignment([nameLabel, Padding(),
                                      allCountLabel, Padding(), currentCountLabel],
                                     height: frame.height)
        } else {
            _ = Layout.leftAlignment([nameLabel, Padding(), allCountLabel],
                                     height: frame.height)
        }
    }
}
