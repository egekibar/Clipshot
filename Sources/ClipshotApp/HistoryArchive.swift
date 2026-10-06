import ClipshotHistory
import ClipshotMarkup
import CoreGraphics
import Foundation

/// Geçmiş for the app. One serial queue does the disk work in the order it was asked for (a capture's marks are
/// saved only after the capture itself), and `onChange` tells the window on the main thread.
final class HistoryArchive {
    let store: HistoryStore
    /// After every change, on the main thread.
    var onChange: () -> Void = {}
    private let queue = DispatchQueue(label: "com.egekibar.clipshot.history", qos: .utility)

    init(directory: URL = HistoryArchive.defaultDirectory) {
        store = HistoryStore(directory: directory)
    }

    /// ~/Library/Application Support/Clipshot/History
    static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Clipshot/History", isDirectory: true)
    }

    /// Returns the new item's id at once; the files are written on the queue.
    func add(_ image: CGImage, scale: CGFloat) -> UUID {
        let id = UUID()
        let date = Date()
        perform { store in
            do {
                try store.add(image, scale: scale, id: id, date: date)
            } catch {
                AppLog.app.error("history: could not save a capture: \(String(describing: error), privacy: .public)")
            }
        }
        return id
    }

    func update(_ id: UUID, marks: [Mark]) {
        perform { store in try? store.update(id, marks: marks) }
    }

    func delete(_ id: UUID) {
        perform { store in store.delete(id) }
    }

    func deleteAll() {
        perform { store in store.deleteAll() }
    }

    func prune(keepingDays days: Int) {
        perform { store in
            let removed = store.prune(keepingDays: days, now: Date())
            if removed > 0 { AppLog.app.notice("history: \(removed, privacy: .public) old screenshot(s) removed") }
        }
    }

    /// Read after every write asked for before.
    func items() -> [HistoryItem] {
        queue.sync { store.items() }
    }

    func image(of id: UUID) -> CGImage? {
        queue.sync { store.image(of: id) }
    }

    private func perform(_ work: @escaping @Sendable (HistoryStore) -> Void) {
        let store = store
        queue.async { [weak self] in
            work(store)
            DispatchQueue.main.async { self?.onChange() }
        }
    }
}
