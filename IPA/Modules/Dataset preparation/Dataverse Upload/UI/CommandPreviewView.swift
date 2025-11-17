//  Lightweight summary widget that previews the selected server, dataset, and
//  exclusion settings so users can double-check the upload configuration.
import SwiftUI

/// Read-only summary of the current upload configuration.
public struct CommandPreviewView: View {
    let server: String
    let persistentId: String
    let excludeRegex: String
    let count: Int

    public init(server: String, persistentId: String, excludeRegex: String, count: Int) {
        self.server = server
        self.persistentId = persistentId
        self.excludeRegex = excludeRegex
        self.count = count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Server")
                        .foregroundStyle(.secondary)
                    Text(server.isEmpty ? "—" : server)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("Dataset")
                        .foregroundStyle(.secondary)
                    Text(persistentId.isEmpty ? "—" : persistentId)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("Exclude")
                        .foregroundStyle(.secondary)
                    Text(excludeRegex.isEmpty ? "—" : excludeRegex)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.callout)

            Divider()

            HStack {
                Label("\(count) item(s) selected", systemImage: "tray.full")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if count == 0 {
                    Text("Add files to enable upload")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
