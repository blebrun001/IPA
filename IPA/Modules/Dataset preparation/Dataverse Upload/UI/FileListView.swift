//  Selection list UI for the files and directories queued for upload, offering
//  quick add/remove actions, security-scoped bookmark creation, and drag-and-drop.
import SwiftUI
import UniformTypeIdentifiers

/// Displays the list of items queued for upload and lets the user manage them.
struct FileListView: View {
    @Binding var items: [UploadItem]
    @State private var isDropTarget = false

    init(items: Binding<[UploadItem]>) {
        self._items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label(items.isEmpty ? "Drop files or folders" : "\(items.count) item(s)", systemImage: "tray.full")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                ControlGroup {
                    Button("Add…", action: pickItems)
                    Button("Clear") { items.removeAll() }
                        .disabled(items.isEmpty)
                }
                .controlSize(.small)
            }

            if items.isEmpty {
                EmptySelectionView()
                    .frame(minHeight: 160, maxHeight: 260)
                    .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(items) { it in
                        let url = URL(fileURLWithPath: it.path)
                        Label {
                            Text(url.lastPathComponent)
                                .font(.body.weight(.medium))
                            Text(it.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: url.hasDirectoryPath ? "folder" : "doc")
                                .symbolVariant(.fill)
                        }
                        .lineLimit(1)
                        .help(it.path)
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                }
                .frame(minHeight: 160, maxHeight: 260)
                .listStyle(.inset)
            }
        }
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDropTarget ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.4),
                        style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1,
                                           dash: isDropTarget ? [6] : []))
                .animation(.easeInOut(duration: 0.2), value: isDropTarget)
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTarget, perform: handleDrop(providers:))
    }

    /// Present a security-scoped file picker and merge the selection with the current list.
    private func pickItems() {
        let panel = NSOpenPanel()
        panel.title = "Add files or folders"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.begin { resp in
            guard resp == .OK else { return }
            mergeItems(with: panel.urls)
        }
    }

    /// Merge dropped providers into the list of items.
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        let fileIdentifier = UTType.fileURL.identifier
        for provider in providers where provider.hasItemConformingToTypeIdentifier(fileIdentifier) {
            provider.loadItem(forTypeIdentifier: fileIdentifier, options: nil) { item, _ in
                guard let anyItem = item else { return }

                let url: URL?
                if let data = anyItem as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let urlItem = anyItem as? URL {
                    url = urlItem
                } else if let nsurl = anyItem as? NSURL {
                    url = nsurl as URL
                } else {
                    url = nil
                }

                guard let resolvedURL = url else { return }
                DispatchQueue.main.async {
                    mergeItems(with: [resolvedURL])
                }
            }
            handled = true
        }
        return handled
    }

    /// Create upload items from URLs, merge with existing selection, and sort them.
    private func mergeItems(with urls: [URL]) {
        let newly: [UploadItem] = urls.compactMap { url in
            let bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                                 includingResourceValuesForKeys: nil,
                                                 relativeTo: nil)
            return UploadItem(path: url.path, bookmark: bookmark)
        }
        guard !newly.isEmpty else { return }
        let combined = Set(items).union(Set(newly))
        items = Array(combined).sorted { $0.path < $1.path }
    }

    /// Placeholder shown when no files have been staged.
    private struct EmptySelectionView: View {
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("Drag folders or click “Add…” to stage files for upload.", comment: "Empty selection hint"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
