import SwiftUI

struct NetworkLogsView: View {
    @State private var logs: [NetworkLog] = []
    @State private var isLoading = false
    
    var body: some View {
        List {
            if logs.isEmpty {
                Text("debug.logs.no_logs")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(logs) { log in
                    NavigationLink(destination: NetworkLogDetailView(log: log)) {
                        LogListRow(log: log)
                    }
                }
            }
        }
        .navigationTitle("debug.logs.title")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { clearLogs() }) {
                    Image(systemName: "trash")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { refreshLogs() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await loadLogs()
        }
        .refreshable {
            await loadLogs()
        }
    }
    
    private func loadLogs() async {
        logs = await NetworkLogger.shared.getLogs()
    }
    
    private func clearLogs() {
        Task {
            await NetworkLogger.shared.clear()
            await loadLogs()
        }
    }
    
    private func refreshLogs() {
        Task {
            await loadLogs()
        }
    }
}

private struct LogListRow: View {
    let log: NetworkLog
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.method)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(urlPath(from: log.url))
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                
                HStack {
                    if let status = log.statusCode {
                        Text("\(status)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(log.statusColor)
                    } else {
                        Text("ERR")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    Text(String(format: "%.0f ms", log.duration * 1000))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(log.date.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func urlPath(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.path + (url.query.map { "?\($0)" } ?? "")
    }
}

struct NetworkLogDetailView: View {
    let log: NetworkLog
    
    var body: some View {
        List {
            Section(header: Text("debug.logs.section.general")) {
                InfoRow(label: "URL", value: log.url)
                InfoRow(label: "Method", value: log.method)
                InfoRow(label: "Status", value: "\(log.statusCode ?? 0)")
                InfoRow(label: "Duration", value: String(format: "%.3f s", log.duration))
                InfoRow(label: "Date", value: log.date.formatted())
            }
            
            if let error = log.error {
                Section(header: Text("debug.logs.section.error")) {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            if let headers = log.requestHeaders, !headers.isEmpty {
                Section(header: Text("debug.logs.section.req_headers")) {
                    ForEach(headers.sorted(by: <), id: \.key) { key, value in
                        InfoRow(label: key, value: value)
                    }
                }
            }
            
            if let body = log.requestBody, !body.isEmpty {
                Section(header: Text("debug.logs.section.req_body")) {
                    Text(body)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
            if let headers = log.responseHeaders, !headers.isEmpty {
                Section(header: Text("debug.logs.section.res_headers")) {
                    ForEach(headers.sorted(by: <), id: \.key) { key, value in
                        InfoRow(label: key, value: value)
                    }
                }
            }
            
            if let body = log.responseBody, !body.isEmpty {
                Section(header: Text("debug.logs.section.res_body")) {
                    Text(body)
                        .font(.system(.caption, design: .monospaced))
                        .contextMenu {
                            Button(String(localized: "common.copy")) {
                                UIPasteboard.general.string = body
                            }
                        }
                }
            }
        }
        .navigationTitle("debug.logs.request_details")
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
        .contextMenu {
            Button(String(localized: "common.copy")) {
                UIPasteboard.general.string = value
            }
        }
    }
}
