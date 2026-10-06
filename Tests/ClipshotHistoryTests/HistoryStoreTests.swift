import ClipshotMarkup
import ClipshotTestSupport
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import ClipshotHistory

/// A history folder of its own under the temp directory, removed when the test ends.
final class ScratchHistory {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipshot-history-\(UUID().uuidString)", isDirectory: true)
    var store: HistoryStore { HistoryStore(directory: directory) }
    var files: [String] { ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted() }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

@Suite("HistoryStore")
struct HistoryStoreTests {
    let scratch = ScratchHistory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let day: TimeInterval = 86_400
    let box = Mark(tool: .box, color: .red, points: [CGPoint(x: 2, y: 2), CGPoint(x: 18, y: 8)])

    func thumbnail(_ id: UUID) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(scratch.store.thumbnailURL(of: id) as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    @Test func aCaptureIsKeptWithItsDateAndScale() throws {
        let item = try scratch.store.add(solidImage(width: 40, height: 20, gray: 1), scale: 2, date: now)
        #expect(scratch.store.items() == [HistoryItem(id: item.id, date: now, scale: 2, marks: [])])
        let image = try #require(scratch.store.image(of: item.id))
        #expect(image.width == 40 && image.height == 20)
        #expect(FileManager.default.fileExists(atPath: scratch.store.thumbnailURL(of: item.id).path))
    }

    @Test func newestComesFirst() throws {
        let older = try scratch.store.add(solidImage(width: 4, height: 4, gray: 1), scale: 1, date: now - 60)
        let newer = try scratch.store.add(solidImage(width: 4, height: 4, gray: 1), scale: 1, date: now)
        #expect(scratch.store.items().map(\.id) == [newer.id, older.id])
    }

    /// Marks drawn later are saved with the item, survive a relaunch, and show in its thumbnail.
    @Test func marksAreSavedAndShowInTheThumbnail() throws {
        let item = try scratch.store.add(solidImage(width: 40, height: 20, gray: 1), scale: 2, date: now)
        try scratch.store.update(item.id, marks: [box])
        #expect(HistoryStore(directory: scratch.directory).items().first?.marks == [box])
        #expect(isRed(pixel(try thumbnail(item.id), x: 4, y: 10)))  // the box's left edge, 2 pt = 4 px
    }

    @Test func thumbnailsStaySmall() throws {
        let item = try scratch.store.add(solidImage(width: 2000, height: 1000, gray: 1), scale: 2, date: now)
        let thumbnail = try thumbnail(item.id)
        #expect(thumbnail.width == HistoryStore.thumbnailMaxPixels && thumbnail.height == 240)
    }

    /// Nothing older than the chosen number of days stays on disk.
    @Test func pruneDeletesWhatIsOlderThanTheRetention() throws {
        let old = try scratch.store.add(solidImage(width: 4, height: 4, gray: 1), scale: 1, date: now - 4 * day)
        let recent = try scratch.store.add(solidImage(width: 4, height: 4, gray: 1), scale: 1, date: now - 2 * day)
        #expect(scratch.store.prune(keepingDays: 3, now: now) == 1)
        #expect(scratch.store.items().map(\.id) == [recent.id])
        #expect(!scratch.files.contains { $0.hasPrefix(old.id.uuidString) })
    }

    /// A capture interrupted before its record was written still goes once it is old enough.
    @Test func pruneAlsoRemovesLeftoversWithoutARecord() throws {
        try FileManager.default.createDirectory(at: scratch.directory, withIntermediateDirectories: true)
        let leftover = scratch.directory.appendingPathComponent("\(UUID().uuidString).png")
        try Data("png".utf8).write(to: leftover)
        try FileManager.default.setAttributes([.modificationDate: now - 5 * day], ofItemAtPath: leftover.path)
        scratch.store.prune(keepingDays: 3, now: now)
        #expect(scratch.files.isEmpty)
    }

    @Test func deleteRemovesEveryFileOfTheItem() throws {
        let item = try scratch.store.add(solidImage(width: 4, height: 4, gray: 1), scale: 1, date: now)
        scratch.store.delete(item.id)
        #expect(scratch.store.items().isEmpty)
        #expect(scratch.files.isEmpty)
    }

    @Test func deleteAllEmptiesTheHistory() throws {
        try scratch.store.add(solidImage(width: 4, height: 4, gray: 1), scale: 1, date: now)
        try scratch.store.add(solidImage(width: 4, height: 4, gray: 1), scale: 1, date: now)
        scratch.store.deleteAll()
        #expect(scratch.store.items().isEmpty)
        #expect(scratch.files.isEmpty)
    }

    /// A damaged record hides only its own item.
    @Test func unreadableRecordIsSkipped() throws {
        let item = try scratch.store.add(solidImage(width: 4, height: 4, gray: 1), scale: 1, date: now)
        try FileManager.default.createDirectory(at: scratch.directory, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: scratch.directory.appendingPathComponent("\(UUID().uuidString).json"))
        #expect(scratch.store.items().map(\.id) == [item.id])
    }
}

@Suite("HistorySections")
struct HistorySectionsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        calendar.locale = Locale(identifier: "tr_TR")
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func item(_ date: Date) -> HistoryItem { HistoryItem(id: UUID(), date: date, scale: 2, marks: []) }

    /// One section per day, newest first: "Bugün", "Dün", then the date with its weekday.
    @Test func groupsByDayWithTurkishTitles() {
        let items = [item(date(6, 14)), item(date(6, 9)), item(date(5, 20)), item(date(3, 10))]
        let sections = HistorySections.group(items, now: date(6, 15), calendar: calendar)
        #expect(sections.map(\.title) == ["Bugün", "Dün", "3 Ekim Cumartesi"])
        #expect(sections.map { $0.items.count } == [2, 1, 1])
    }

    @Test func timeIsHoursAndMinutes() {
        #expect(HistorySections.time(of: date(6, 9, 5), calendar: calendar) == "09:05")
    }
}
