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

/**
 # Issue
 - 変更通知またはイミュータブル化またはstruct化
 */
final class Drawing: NSObject, NSCoding {
    var lines: [Line], roughLines: [Line], selectionLineIndexes: [Int]
    init(lines: [Line] = [], roughLines: [Line] = [], selectionLineIndexes: [Int] = []) {
        self.lines = lines
        self.roughLines = roughLines
        self.selectionLineIndexes = selectionLineIndexes
    }
    
    private enum CodingKeys: String, CodingKey {
        case lines, roughLines, selectionLineIndexes
    }
    init?(coder: NSCoder) {
        lines = coder.decodeDecodable([Line].self, forKey: CodingKeys.lines.rawValue) ?? []
        roughLines = coder.decodeDecodable([Line].self, forKey: CodingKeys.roughLines.rawValue) ?? []
        selectionLineIndexes = coder.decodeObject(
            forKey: CodingKeys.selectionLineIndexes.rawValue) as? [Int] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(lines, forKey: CodingKeys.lines.rawValue)
        coder.encodeEncodable(roughLines, forKey: CodingKeys.roughLines.rawValue)
        coder.encode(selectionLineIndexes, forKey: CodingKeys.selectionLineIndexes.rawValue)
    }
    
    func imageBounds(withLineWidth lineWidth: CGFloat) -> CGRect {
        return Line.imageBounds(with: lines, lineWidth: lineWidth)
            .unionNoEmpty(Line.imageBounds(with: roughLines, lineWidth: lineWidth))
    }
    
    func nearestLine(at p: CGPoint) -> Line? {
        var minD² = CGFloat.infinity, minLine: Line?
        lines.forEach {
            let d² = $0.minDistance²(at: p)
            if d² < minD² {
                minD² = d²
                minLine = $0
            }
        }
        return minLine
    }
    func isNearestSelectionLineIndexes(at p: CGPoint) -> Bool {
        guard !selectionLineIndexes.isEmpty else {
            return false
        }
        var minD² = CGFloat.infinity, minIndex = 0
        lines.enumerated().forEach {
            let d² = $0.element.minDistance²(at: p)
            if d² < minD² {
                minD² = d²
                minIndex = $0.offset
            }
        }
        return selectionLineIndexes.contains(minIndex)
    }
    var editLines: [Line] {
        return selectionLineIndexes.isEmpty ? lines : selectionLineIndexes.map { lines[$0] }
    }
    var uneditLines: [Line] {
        guard  !selectionLineIndexes.isEmpty else {
            return []
        }
        return (0 ..< lines.count)
            .filter { !selectionLineIndexes.contains($0) }
            .map { lines[$0] }
    }
    
    func drawEdit(lineWidth: CGFloat, lineColor: Color, in ctx: CGContext) {
        drawRough(lineWidth: lineWidth, lineColor: Color.rough, in: ctx)
        draw(lineWidth: lineWidth, lineColor: lineColor, in: ctx)
        drawSelectionLines(lineWidth: lineWidth + 1.5, lineColor: Color.selection, in: ctx)
    }
    func drawRough(lineWidth: CGFloat, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cgColor)
        roughLines.forEach { $0.draw(size: lineWidth, in: ctx) }
    }
    func draw(lineWidth: CGFloat, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cgColor)
        lines.forEach { $0.draw(size: lineWidth, in: ctx) }
    }
    func drawSelectionLines(lineWidth: CGFloat, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cgColor)
        selectionLineIndexes.forEach { lines[$0].draw(size: lineWidth, in: ctx) }
    }
}
extension Drawing: Referenceable {
    static let name = Localization(english: "Drawing", japanese: "線画")
}
extension Drawing: Copying {
    func copied(from copier: Copier) -> Drawing {
        return Drawing(lines: lines, roughLines: roughLines,
                       selectionLineIndexes: selectionLineIndexes)
    }
}
extension Drawing: Layerable {
    func layer(withBounds bounds: CGRect) -> Layer {
        let layer = DrawLayer()
        layer.drawBlock = { [unowned self, unowned layer] ctx in
            self.draw(with: layer.bounds, in: ctx)
        }
        layer.bounds = bounds
        return layer
    }
    func draw(with bounds: CGRect, in ctx: CGContext) {
        let imageBounds = self.imageBounds(withLineWidth: 1)
        let c = CGAffineTransform.centering(from: imageBounds, to: bounds.inset(by: 5))
        ctx.concatenate(c.affine)
        draw(lineWidth: 0.5/c.scale, lineColor: Color.strokeLine, in: ctx)
        drawRough(lineWidth: 0.5/c.scale, lineColor: Color.rough, in: ctx)
    }
}
