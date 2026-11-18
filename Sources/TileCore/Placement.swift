import Foundation
import CoreGraphics
public enum Placement {
    public static func anchor(existing: [Int], focused: Int?, previous: Int?) -> Int? {
        if let focused, existing.contains(focused) { return focused }
        if let previous, existing.contains(previous) { return previous }
        return existing.last
    }
    public static func axis(for rect: CGRect) -> Axis { rect.width >= rect.height ? .horizontal : .vertical }
    public static func target(frames: [Int: CGRect], preferred: Int?, gap: Double) -> Int? {
        func canSplit(_ r: CGRect) -> Bool {
            ((r.width - gap) / 2 >= 480 && r.height >= 300) || ((r.height - gap) / 2 >= 300 && r.width >= 480)
        }
        if let preferred, let frame = frames[preferred], canSplit(frame) { return preferred }
        let ranked = frames.keys.sorted { a, b in
            let first = frames[a]!; let second = frames[b]!
            let firstFits = canSplit(first); let secondFits = canSplit(second)
            if firstFits != secondFits { return firstFits }
            let areaA = first.width * first.height; let areaB = second.width * second.height
            return areaA == areaB ? a < b : areaA > areaB
        }
        return ranked.first
    }
}
