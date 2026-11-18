import Foundation
import CoreGraphics
public enum Axis: Sendable, Equatable { case horizontal, vertical }
public indirect enum Layout: Sendable, Equatable {
    case leaf(Int)
    case split(Axis, Double, Layout, Layout)
    public var ids: [Int] { switch self { case .leaf(let id): return [id]; case .split(_, _, let a, let b): return a.ids + b.ids } }
    public func frames(in rect: CGRect, gap: Double) -> [Int: CGRect] {
        switch self {
        case .leaf(let id): return [id: rect]
        case .split(let axis, let ratio, let a, let b):
            let horizontal = axis == .horizontal
            let length = horizontal ? rect.width : rect.height
            let spacing = min(max(0, gap), length)
            let first = (length - spacing) * min(0.85, max(0.15, ratio))
            var left = rect; var right = rect
            if horizontal { left.size.width = first; right.origin.x += first + spacing; right.size.width = length - first - spacing }
            else { left.size.height = first; right.origin.y += first + spacing; right.size.height = length - first - spacing }
            return a.frames(in: left, gap: gap).merging(b.frames(in: right, gap: gap)) { x, _ in x }
        }
    }
    public func removing(_ id: Int) -> Layout? {
        switch self {
        case .leaf(let value): return value == id ? nil : self
        case .split(let axis, let ratio, let a, let b):
            let left = a.removing(id); let right = b.removing(id)
            if let left, let right { return .split(axis, ratio, left, right) }
            return left ?? right
        }
    }
    public func inserting(_ id: Int, beside target: Int?, axis: Axis) -> Layout {
        guard !ids.contains(id) else { return self }
        let anchor = target.flatMap { ids.contains($0) ? $0 : nil } ?? ids.last!
        return insertingAtKnownLeaf(id, target: anchor, axis: axis)
    }
    private func insertingAtKnownLeaf(_ id: Int, target: Int, axis: Axis) -> Layout {
        switch self {
        case .leaf(let value): return value == target ? .split(axis, 0.5, self, .leaf(id)) : self
        case .split(let direction, let ratio, let a, let b):
            if b.ids.contains(target) { return .split(direction, ratio, a, b.insertingAtKnownLeaf(id, target: target, axis: axis)) }
            return .split(direction, ratio, a.insertingAtKnownLeaf(id, target: target, axis: axis), b)
        }
    }
    public func swapping(_ first: Int, _ second: Int) -> Layout {
        switch self {
        case .leaf(let id): return .leaf(id == first ? second : id == second ? first : id)
        case .split(let axis, let ratio, let a, let b): return .split(axis, ratio, a.swapping(first, second), b.swapping(first, second))
        }
    }
    public func resizing(_ id: Int, delta: Double) -> Layout {
        switch self {
        case .leaf: return self
        case .split(let axis, let ratio, let a, let b):
            if case .leaf(id) = a { return .split(axis, min(0.85, max(0.15, ratio + delta)), a, b) }
            if case .leaf(id) = b { return .split(axis, min(0.85, max(0.15, ratio - delta)), a, b) }
            return .split(axis, ratio, a.resizing(id, delta: delta), b.resizing(id, delta: delta))
        }
    }
    public func resizing(_ id: Int, axis requested: Axis, delta: Double) -> Layout {
        guard case .split(let axis, let ratio, let a, let b) = self, ids.contains(id) else { return self }
        if a.ids.contains(id) {
            let child = a.resizing(id, axis: requested, delta: delta)
            if child != a { return .split(axis, ratio, child, b) }
            if axis == requested { return .split(axis, min(0.85, max(0.15, ratio + delta)), a, b) }
        } else {
            let child = b.resizing(id, axis: requested, delta: delta)
            if child != b { return .split(axis, ratio, a, child) }
            if axis == requested { return .split(axis, min(0.85, max(0.15, ratio - delta)), a, b) }
        }
        return self
    }
    public func rotating(_ id: Int) -> Layout {
        guard case .split(let axis, let ratio, let a, let b) = self else { return self }
        if case .leaf(let value) = a, value == id { return .split(axis == .horizontal ? .vertical : .horizontal, ratio, a, b) }
        if case .leaf(let value) = b, value == id { return .split(axis == .horizontal ? .vertical : .horizontal, ratio, a, b) }
        return .split(axis, ratio, a.rotating(id), b.rotating(id))
    }
}
