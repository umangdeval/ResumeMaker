import Foundation

extension Date {
    /// Returns a formatted string like "Jan 2023 – Present" or "Jan 2023 – Dec 2024".
    static func dateRangeString(start: Date, end: Date?, isCurrent: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let startStr = formatter.string(from: start)
        let endStr = isCurrent ? "Present" : end.map { formatter.string(from: $0) } ?? "Present"
        return "\(startStr) – \(endStr)"
    }
}
