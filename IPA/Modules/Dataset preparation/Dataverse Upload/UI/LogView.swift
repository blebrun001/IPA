//  Scrollable log surface that mirrors upload progress, highlighting retry and
//  cancellation messages while auto-scrolling to the most recent entries.
import SwiftUI

/// Scrollable console-style log with highlighted retry or cancellation notices.
public struct LogView: View {
    let entries: [String]
    let retryMessage: String
    let cancelMessage: String

    public init(entries: [String], retryMessage: String, cancelMessage: String) {
        self.entries = entries
        self.retryMessage = retryMessage
        self.cancelMessage = cancelMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !retryMessage.isEmpty || !cancelMessage.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !retryMessage.isEmpty {
                        Text(retryMessage)
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.orange.opacity(0.12))
                            )
                    }
                    if !cancelMessage.isEmpty {
                        Text(cancelMessage)
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.red.opacity(0.12))
                            )
                    }
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if entries.isEmpty {
                            Text("—")
                                .font(.system(.footnote, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.thinMaterial)
                                )
                        } else {
                            ForEach(entries.indices, id: \.self) { idx in
                                Text(entries[idx])
                                    .font(.system(.footnote, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(.thinMaterial)
                                    )
                                    .id(idx)
                            }
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                    }
                }
                .frame(minHeight: 160)
                .onChange(of: entries.count) { _, _ in
                    DispatchQueue.main.async {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
                .task(id: entries.count) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
        }
    }
}
