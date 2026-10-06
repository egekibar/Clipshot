import ClipshotMarkup
import CoreGraphics
import Foundation
import ImageIO

/// One screenshot in Geçmiş.
public struct HistoryItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    /// When it was captured.
    public var date: Date
    /// Pixels per point of the screenshot.
    public var scale: CGFloat
    /// The marks it was last copied or left with; reopening it puts them back, still editable.
    public var marks: [Mark]

    public init(id: UUID, date: Date, scale: CGFloat, marks: [Mark]) {
        self.id = id
        self.date = date
        self.scale = scale
        self.marks = marks
    }
}

public enum HistoryError: Error, Equatable, Sendable {
    case missing
    case cannotWrite
}

/// Geçmiş on disk. Per screenshot: `<id>.png` as captured, `<id>-thumb.png` small and with its marks, and
/// `<id>.json` (date, scale, marks), written last: an item exists once its record does.
///
/// A value over a folder: safe from any thread as long as one caller writes at a time (the app keeps every call on
/// one serial queue).
public struct HistoryStore: Sendable {
    /// A thumbnail's longest side, in pixels: sharp in the grid's cells on a Retina screen.
    public static let thumbnailMaxPixels = 480
    public let directory: URL

    private struct Record: Codable {
        var id: UUID
        var date: Date
        var scale: CGFloat
        var marks: [Mark]
    }

    public init(directory: URL) {
        self.directory = directory
    }

    public func imageURL(of id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).png") }
    public func thumbnailURL(of id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString)-thumb.png") }
    func recordURL(of id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }

    @discardableResult
    public func add(_ image: CGImage, scale: CGFloat, id: UUID = UUID(), date: Date) throws -> HistoryItem {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try write(image, to: imageURL(of: id))
        let item = HistoryItem(id: id, date: date, scale: scale, marks: [])
        try writeThumbnail(of: image, for: item)
        try writeRecord(of: item)
        return item
    }

    /// New marks for an item: its record and thumbnail follow.
    public func update(_ id: UUID, marks: [Mark]) throws {
        guard var item = readRecord(at: recordURL(of: id)), let image = image(of: id) else {
            throw HistoryError.missing
        }
        item.marks = marks
        try writeThumbnail(of: image, for: item)
        try writeRecord(of: item)
    }

    /// Newest first. An unreadable record hides only its own item.
    public func items() -> [HistoryItem] {
        fileNames().filter { $0.hasSuffix(".json") }
            .compactMap { readRecord(at: directory.appendingPathComponent($0)) }
            .sorted { $0.date > $1.date }
    }

    /// The screenshot as it was captured, without marks.
    public func image(of id: UUID) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(imageURL(of: id) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    public func delete(_ id: UUID) {
        for url in [recordURL(of: id), imageURL(of: id), thumbnailURL(of: id)] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func deleteAll() {
        for name in fileNames() { try? FileManager.default.removeItem(at: directory.appendingPathComponent(name)) }
    }

    /// Deletes everything older than `days` days: items by their capture date, files without a readable record (a
    /// capture interrupted before its record was written) by their own age. Returns how many items went.
    @discardableResult
    public func prune(keepingDays days: Int, now: Date) -> Int {
        let cutoff = now.addingTimeInterval(-TimeInterval(days) * 86_400)
        let records = Dictionary(items().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var expired = Set<UUID>()
        for name in fileNames() {
            if let id = UUID(uuidString: String(name.prefix(36))), let record = records[id] {
                if record.date < cutoff { expired.insert(id) }
                continue
            }
            let url = directory.appendingPathComponent(name)
            let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            if let modified, modified < cutoff { try? FileManager.default.removeItem(at: url) }
        }
        for id in expired { delete(id) }
        return expired.count
    }

    // MARK: - Files

    private func fileNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    private func readRecord(at url: URL) -> HistoryItem? {
        guard let data = try? Data(contentsOf: url), let record = try? JSONDecoder().decode(Record.self, from: data)
        else { return nil }
        return HistoryItem(id: record.id, date: record.date, scale: record.scale, marks: record.marks)
    }

    private func writeRecord(of item: HistoryItem) throws {
        let record = Record(id: item.id, date: item.date, scale: item.scale, marks: item.marks)
        try JSONEncoder().encode(record).write(to: recordURL(of: item.id), options: .atomic)
    }

    private func write(_ image: CGImage, to url: URL) throws {
        guard let data = MarkupRenderer.pngData(image) else { throw HistoryError.cannotWrite }
        try data.write(to: url, options: .atomic)
    }

    /// The screenshot with its marks, shrunk so its longest side is at most `thumbnailMaxPixels`.
    private func writeThumbnail(of image: CGImage, for item: HistoryItem) throws {
        let marked =
            item.marks.isEmpty ? image : MarkupRenderer.render(image, marks: item.marks, scale: item.scale) ?? image
        let factor = min(1, CGFloat(Self.thumbnailMaxPixels) / CGFloat(max(marked.width, marked.height)))
        let width = max(1, Int((CGFloat(marked.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(marked.height) * factor).rounded()))
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw HistoryError.cannotWrite }
        context.interpolationQuality = .high
        context.draw(marked, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let thumbnail = context.makeImage() else { throw HistoryError.cannotWrite }
        try write(thumbnail, to: thumbnailURL(of: item.id))
    }
}

/// Geçmiş's grid: one section per day, newest first.
public enum HistorySections {
    public struct Section: Equatable, Sendable {
        public var title: String
        public var items: [HistoryItem]
    }

    /// "Bugün", "Dün", then the date with its weekday ("3 Ekim Cumartesi"), in Turkish like the rest of the app.
    public static func group(_ items: [HistoryItem], now: Date, calendar: Calendar) -> [Section] {
        var sections: [Section] = []
        for item in items.sorted(by: { $0.date > $1.date }) {
            let title = title(for: item.date, now: now, calendar: calendar)
            if sections.last?.title == title {
                sections[sections.count - 1].items.append(item)
            } else {
                sections.append(Section(title: title, items: [item]))
            }
        }
        return sections
    }

    public static func time(of date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    static func title(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Bugün" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Dün"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM EEEE"
        return formatter.string(from: date)
    }
}
