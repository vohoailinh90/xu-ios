import SwiftUI
import SwiftData
import XuCore

/// Thanh nhập nhanh — trái tim của app. Mục tiêu: gõ "cà phê 35k" + Enter ≤ 2 giây.
/// Quy tắc: tự focus, xem trước ngay khi gõ, Enter là lưu, lưu xong vẫn giữ bàn phím.
struct QuickEntryBar: View {
    /// Tăng giá trị này (ví dụ khi mở từ widget `xu://new`) để focus lại ô nhập.
    var focusTrigger: Int = 0

    @Environment(\.modelContext) private var context
    @Query private var learned: [LearnedKeyword]
    @AppStorage("smallNumbersAreThousands") private var smallNumbersAreThousands = true

    @State private var text = ""
    @State private var categoryOverride: String?
    @State private var showCategoryPicker = false
    @State private var toast: SavedToast?
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private var parser: QuickEntryParser {
        let map = Dictionary(learned.map { ($0.phrase, $0.categoryID) }, uniquingKeysWith: { a, _ in a })
        return QuickEntryParser(options: .init(smallNumbersAreThousands: smallNumbersAreThousands),
                                matcher: CategoryMatcher(learned: map))
    }

    private var preview: QuickEntryResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var result = parser.parse(trimmed)
        if let categoryOverride { result.categoryID = categoryOverride }
        return result
    }

    var body: some View {
        VStack(spacing: 8) {
            if let toast {
                ToastView(toast: toast) { undo(toast) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let preview {
                PreviewCard(result: preview) { showCategoryPicker = true }
            }
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                TextField("cà phê 35k, grab 52k hôm qua…", text: $text)
                    .focused($focused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(submit)
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(preview?.isComplete != true)
                .accessibilityLabel("Lưu")
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .animation(.snappy, value: toast)
        .onAppear { focused = true }
        .onChange(of: focusTrigger) { focused = true }
        .onChange(of: text) { errorMessage = nil }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPicker(kind: preview?.isIncome == true ? .income : .expense) { id in
                categoryOverride = id
                showCategoryPicker = false
                focused = true
            }
            .presentationDetents([.medium])
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            toast = nil
        }
    }

    private func submit() {
        guard let result = preview else { return }
        guard result.isComplete else {
            errorMessage = LedgerError.missingAmount.errorDescription
            focused = true
            return
        }
        do {
            if categoryOverride != nil {
                try Ledger.learn(note: result.note, categoryID: result.categoryID, in: context)
            }
            let record = try Ledger.save(result, rawInput: text, source: .quickText, in: context)
            toast = SavedToast(recordID: record.id, amount: record.amount, isIncome: record.isIncome,
                               title: record.note.isEmpty ? record.category.name : record.note,
                               emoji: record.category.emoji)
            text = ""
            categoryOverride = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        focused = true
    }

    private func undo(_ toast: SavedToast) {
        let id = toast.recordID
        if let record = try? context.fetch(FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.id == id })).first {
            try? Ledger.delete(record, in: context)
        }
        self.toast = nil
    }
}

struct SavedToast: Equatable {
    let recordID: UUID
    let amount: Int64
    let isIncome: Bool
    let title: String
    let emoji: String
}

private struct ToastView: View {
    let toast: SavedToast
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text("\(toast.emoji) Đã ghi \(toast.isIncome ? "+" : "")\(MoneyFormatter.compact(toast.amount)) · \(toast.title)")
                .lineLimit(1)
            Spacer()
            Button("Hoàn tác", action: onUndo).bold()
        }
        .font(.subheadline)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct PreviewCard: View {
    let result: QuickEntryResult
    let onTapCategory: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTapCategory) {
                Text(result.category.emoji + " " + result.category.name)
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Đổi danh mục")

            VStack(alignment: .leading, spacing: 2) {
                Text(result.amount.map { (result.isIncome ? "+" : "") + MoneyFormatter.full($0) } ?? "Chưa có số tiền")
                    .font(.headline)
                    .foregroundStyle(result.amount == nil ? .secondary : .primary)
                Text(dateLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(result.date) { return "Hôm nay" }
        if cal.isDateInYesterday(result.date) { return "Hôm qua" }
        return result.date.formatted(.dateTime.weekday(.wide).day().month())
    }
}
