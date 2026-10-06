import AppKit
import ClipshotHistory

/// "Geçmiş": the kept screenshots in a grid, one section per day. A click opens one in the marking panel; the context
/// menu copies or deletes it.
public final class HistoryWindowController: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate,
    NSWindowDelegate
{
    /// What the window needs from Geçmiş and does through the app.
    public struct Actions {
        public var items: () -> [HistoryItem]
        public var thumbnailURL: (UUID) -> URL
        public var historyDays: () -> Int
        public var open: (HistoryItem) -> Void
        public var copy: (HistoryItem) -> Void
        public var delete: (HistoryItem) -> Void
        public var showSettings: () -> Void
        /// After the window closed.
        public var closed: () -> Void

        public init(
            items: @escaping () -> [HistoryItem], thumbnailURL: @escaping (UUID) -> URL,
            historyDays: @escaping () -> Int, open: @escaping (HistoryItem) -> Void,
            copy: @escaping (HistoryItem) -> Void, delete: @escaping (HistoryItem) -> Void,
            showSettings: @escaping () -> Void, closed: @escaping () -> Void
        ) {
            self.items = items
            self.thumbnailURL = thumbnailURL
            self.historyDays = historyDays
            self.open = open
            self.copy = copy
            self.delete = delete
            self.showSettings = showSettings
            self.closed = closed
        }
    }

    private let actions: Actions
    private(set) var window: NSWindow?
    private let collectionView = HistoryCollectionView()
    private let emptyLabel = NSTextField(
        wrappingLabelWithString: "Henüz ekran görüntüsü yok.\n⌘P ile bir alan seçtiğinde burada görünür.")
    private let footerLabel = NSTextField(labelWithString: "")
    private var sections: [HistorySections.Section] = []

    private static let itemIdentifier = NSUserInterfaceItemIdentifier("HistoryCell")
    private static let headerIdentifier = NSUserInterfaceItemIdentifier("HistoryHeader")

    public init(actions: Actions) {
        self.actions = actions
    }

    public var isVisible: Bool { window?.isVisible == true }

    public func show() {
        prepare()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// The window, built and filled but not shown.
    func prepare() {
        if window == nil { window = makeWindow() }
        reload()
    }

    /// Re-reads Geçmiş; cheap enough to run after every change while the window is up.
    public func reload() {
        guard window != nil else { return }
        sections = HistorySections.group(actions.items(), now: Date(), calendar: .current)
        collectionView.reloadData()
        emptyLabel.isHidden = !sections.isEmpty
        let days = actions.historyDays()
        footerLabel.stringValue = "Son \(days) günün ekran görüntüleri tutulur; daha eskiler kendiliğinden silinir."
    }

    public func windowWillClose(_ notification: Notification) {
        actions.closed()
    }

    // MARK: - Data source

    public func numberOfSections(in collectionView: NSCollectionView) -> Int { sections.count }

    public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath)
        -> NSCollectionViewItem
    {
        let cell = collectionView.makeItem(withIdentifier: Self.itemIdentifier, for: indexPath)
        if let cell = cell as? HistoryCell {
            let item = sections[indexPath.section].items[indexPath.item]
            cell.show(
                thumbnail: NSImage(contentsOf: actions.thumbnailURL(item.id)),
                time: HistorySections.time(of: item.date, calendar: .current), isMarked: !item.marks.isEmpty)
        }
        return cell
    }

    public func collectionView(
        _ collectionView: NSCollectionView,
        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
        at indexPath: IndexPath
    ) -> NSView {
        let view = collectionView.makeSupplementaryView(
            ofKind: kind, withIdentifier: Self.headerIdentifier, for: indexPath)
        (view as? HistoryHeader)?.title.stringValue = sections[indexPath.section].title
        return view
    }

    // MARK: - Delegate

    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.deselectItems(at: indexPaths)
        guard let indexPath = indexPaths.first else { return }
        actions.open(sections[indexPath.section].items[indexPath.item])
    }

    private func item(at indexPath: IndexPath?) -> HistoryItem? {
        guard let indexPath, indexPath.section < sections.count,
            indexPath.item < sections[indexPath.section].items.count
        else { return nil }
        return sections[indexPath.section].items[indexPath.item]
    }

    // MARK: - Context menu

    private func contextMenu(for indexPath: IndexPath) -> NSMenu? {
        guard let item = item(at: indexPath) else { return nil }
        let menu = NSMenu()
        let open = NSMenuItem(title: "Aç", action: #selector(menuOpen(_:)), keyEquivalent: "")
        let copy = NSMenuItem(title: "Kopyala", action: #selector(menuCopy(_:)), keyEquivalent: "")
        let delete = NSMenuItem(title: "Sil", action: #selector(menuDelete(_:)), keyEquivalent: "")
        for entry in [open, copy, delete] {
            entry.target = self
            entry.representedObject = item.id
        }
        menu.addItem(open)
        menu.addItem(copy)
        menu.addItem(.separator())
        menu.addItem(delete)
        return menu
    }

    private func item(withID sender: NSMenuItem) -> HistoryItem? {
        guard let id = sender.representedObject as? UUID else { return nil }
        return sections.lazy.flatMap(\.items).first { $0.id == id }
    }

    @objc private func menuOpen(_ sender: NSMenuItem) { item(withID: sender).map(actions.open) }
    @objc private func menuCopy(_ sender: NSMenuItem) { item(withID: sender).map(actions.copy) }
    @objc private func menuDelete(_ sender: NSMenuItem) { item(withID: sender).map(actions.delete) }

    @objc private func settingsClicked() { actions.showSettings() }

    // MARK: - Window

    private func makeWindow() -> NSWindow {
        let window = HistoryWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Geçmiş"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 320)
        window.delegate = self
        window.center()

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 220, height: 168)
        layout.minimumInteritemSpacing = 14
        layout.minimumLineSpacing = 18
        layout.sectionInset = NSEdgeInsets(top: 6, left: 18, bottom: 18, right: 18)
        layout.headerReferenceSize = NSSize(width: 0, height: 34)
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(HistoryCell.self, forItemWithIdentifier: Self.itemIdentifier)
        collectionView.register(
            HistoryHeader.self, forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: Self.headerIdentifier)
        collectionView.menuProvider = { [weak self] indexPath in self?.contextMenu(for: indexPath) }

        let scroll = NSScrollView()
        scroll.documentView = collectionView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        footerLabel.textColor = .secondaryLabelColor
        footerLabel.font = .systemFont(ofSize: 11)
        let settings = NSButton(title: "Ayarlar…", target: self, action: #selector(settingsClicked))
        settings.bezelStyle = .push
        settings.controlSize = .small
        let footer = NSStackView(views: [footerLabel, NSView(), settings])
        footer.orientation = .horizontal
        footer.edgeInsets = NSEdgeInsets(top: 8, left: 18, bottom: 10, right: 14)
        footer.translatesAutoresizingMaskIntoConstraints = false
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        for view in [scroll, emptyLabel, divider, footer] { content.addSubview(view) }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: divider.topAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            divider.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        return window
    }
}

/// Esc (and ⌘.) closes Geçmiş the way its close button does. Both arrive here as `cancelOperation`, whether the grid
/// or the window itself has the keyboard.
final class HistoryWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
}

/// Knows which item a right-click landed on.
final class HistoryCollectionView: NSCollectionView {
    var menuProvider: (IndexPath) -> NSMenu? = { _ in nil }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let indexPath = indexPathForItem(at: point) else { return nil }
        return menuProvider(indexPath)
    }
}

/// One screenshot: its thumbnail (with its marks) and the time it was taken.
final class HistoryCell: NSCollectionViewItem {
    private let thumbnail = NSImageView()
    private let time = NSTextField(labelWithString: "")
    private let badge = NSImageView()

    override func loadView() {
        let root = HoverView()
        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.wantsLayer = true
        thumbnail.layer?.cornerRadius = 6
        thumbnail.layer?.masksToBounds = true
        thumbnail.layer?.borderWidth = 1
        thumbnail.layer?.borderColor = NSColor.separatorColor.cgColor
        thumbnail.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        time.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        time.textColor = .secondaryLabelColor
        badge.image = NSImage(systemSymbolName: "pencil.tip.crop.circle", accessibilityDescription: "İşaretli")
        badge.contentTintColor = .secondaryLabelColor
        badge.toolTip = "İşaretli"
        for view in [thumbnail, time, badge] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        NSLayoutConstraint.activate([
            thumbnail.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            thumbnail.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            thumbnail.topAnchor.constraint(equalTo: root.topAnchor),
            thumbnail.heightAnchor.constraint(equalToConstant: 140),
            time.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 2),
            time.topAnchor.constraint(equalTo: thumbnail.bottomAnchor, constant: 6),
            badge.leadingAnchor.constraint(equalTo: time.trailingAnchor, constant: 5),
            badge.centerYAnchor.constraint(equalTo: time.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 13),
            badge.heightAnchor.constraint(equalToConstant: 13),
        ])
        root.onHover = { [weak self] hovering in
            self?.thumbnail.layer?.borderColor =
                (hovering ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
            self?.thumbnail.layer?.borderWidth = hovering ? 2 : 1
        }
        root.toolTip = "Açmak için tıkla"
        view = root
    }

    func show(thumbnail image: NSImage?, time text: String, isMarked: Bool) {
        thumbnail.image = image
        time.stringValue = text
        badge.isHidden = !isMarked
    }
}

/// A view that reports the mouse entering and leaving it.
final class HoverView: NSView {
    var onHover: (Bool) -> Void = { _ in }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// A day's title over its screenshots.
final class HistoryHeader: NSView, NSCollectionViewElement {
    let title = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
