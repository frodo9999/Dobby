import SwiftUI

/// AI-powered natural language inventory discovery.
/// Presented as a sheet from the Search tab — zero changes to SearchView layout.
struct AIDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var isLoading = false
    @State private var result: DiscoveryResult?
    @State private var errorMessage: String?
    @FocusState private var queryFieldFocused: Bool

    private let chips = ["有吃的吗", "有什么可以喝的", "厨房里有什么", "有快过期的食品吗", "有洗碗液吗", "有药吗"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Query input
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundStyle(Color.purple)
                        TextField("问问 AI，例如：有牛奶吗", text: $query)
                            .focused($queryFieldFocused)
                            .submitLabel(.search)
                            .onSubmit { Task { await search() } }
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Example chips
                    if result == nil && !isLoading {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("试试这些")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(chips, id: \.self) { chip in
                                    Button {
                                        query = chip
                                        Task { await search() }
                                    } label: {
                                        Text(chip)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.purple.opacity(0.12))
                                            .foregroundStyle(Color.purple)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Loading
                    if isLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("AI 正在思考…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    }

                    // Error
                    if let error = errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Result
                    if let result, !isLoading {
                        DiscoveryResultView(result: result)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI 问问")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task { await search() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(query.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .purple)
                    }
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .onAppear { queryFieldFocused = true }
        }
    }

    // MARK: - Search

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        queryFieldFocused = false
        isLoading = true
        errorMessage = nil
        result = nil

        do {
            result = try await DiscoveryService.discover(query: trimmed)
        } catch {
            errorMessage = "查询失败：\(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - Result View

private struct DiscoveryResultView: View {
    let result: DiscoveryResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Answer header
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: result.found ? "checkmark.circle.fill" : "questionmark.circle.fill")
                    .foregroundStyle(result.found ? .green : .secondary)
                    .font(.title3)
                Text(result.answer)
                    .font(.body)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Item list
            if !result.items.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(result.items.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            let category = ItemCategory.allCases.first { $0.rawValue == item.category }
                            Image(systemName: category?.icon ?? "archivebox")
                                .frame(width: 32, height: 32)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(Color.purple)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.body)
                                Text(item.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("×\(item.quantity)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let matchType = item.matchType {
                                    Text(matchType.label)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(matchType.color.opacity(0.15))
                                        .foregroundStyle(matchType.color)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)

                        if index < result.items.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Explanation
            if let explanation = result.explanation, !explanation.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Flow Layout (wrapping chip row)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
