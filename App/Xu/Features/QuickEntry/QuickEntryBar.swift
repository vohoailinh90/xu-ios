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
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam

    @State private var text = ""
    @State private var categoryOverride: String?
    @State private var showCategoryPicker = false
    @State private var toast: SavedToast?
    @State private var errorMessage: String?
    /// Lúc gõ ký tự đầu tiên của câu đang nhập — để đo thời gian ghi (chỉ lưu trên máy).
    @State private var typingStartedAt: Date?
    @FocusState private var focused: Bool

    private var parser: QuickEntryParser {
        let map = Dictionary(learned.map { ($0.phrase, $0.categoryID) }, uniquingKeysWith: { a, _ in a })
        return QuickEntryParser(options: .init(smallNumbersAreThousands: smallNumbersAreThousands, market: market),
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
                ToastView(toast: toast, language: language) { undo(toast) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let preview {
                PreviewCard(result: preview, language: language) { showCategoryPicker = true }
            }
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                TextField(language.entryPlaceholder(for: market), text: $text)
                    .focused($focused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(submit)
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(preview?.isComplete != true)
                .accessibilityLabel(language.t(.save))
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .animation(.snappy, value: toast)
        .onAppear { focused = true }
        .onChange(of: focusTrigger) { focused = true }
        .onChange(of: text) { oldText, newText in
            errorMessage = nil
            // Xoá hết ô nhập hay thay bằng câu khác là bỏ câu cũ: danh mục đã chọn tay không được dính sang câu sau
            // (và không được học sai), thời gian ghi đo lại từ đầu.
            if newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                categoryOverride = nil
                typingStartedAt = nil
            } else if typingStartedAt == nil || EntryTimingLog.startsNewSentence(from: oldText, to: newText) {
                if typingStartedAt != nil { categoryOverride = nil }
                typingStartedAt = Date()
            }
        }
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
            let timing = typingStartedAt.flatMap { AppSettings.entryTimings.record(Date().timeIntervalSince($0)) }
            typingStartedAt = nil
            toast = SavedToast(recordID: record.id, amount: record.amount, currency: record.currency,
                               isIncome: record.isIncome,
                               title: record.note.isEmpty ? record.category.name(in: language) : record.note,
                               emoji: record.category.emoji, timing: timing)
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
            // Khoản không còn thì lần đo của nó cũng không tính.
            if let timing = toast.timing { AppSettings.entryTimings.remove(timing) }
        }
        self.toast = nil
    }
}

struct SavedToast: Equatable {
    let recordID: UUID
    let amount: Int64
    let currency: Currency
    let isIncome: Bool
    let title: String
    let emoji: String
    /// Lần đo thời gian ghi của khoản này (nếu có), để hoàn tác thì xoá luôn.
    var timing: Double?
}

private struct ToastView: View {
    let toast: SavedToast
    let language: AppLanguage
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(language.t(.savedToast, toast.emoji,
                            MoneyFormatter.signed(toast.amount, isIncome: toast.isIncome, currency: toast.currency,
                                                  language: language, compact: true),
                            toast.title))
                .lineLimit(1)
            Spacer()
            Button(language.t(.undo), action: onUndo).bold()
        }
        .font(.subheadline)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct PreviewCard: View {
    let result: QuickEntryResult
    let language: AppLanguage
    let onTapCategory: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTapCategory) {
                Text(result.category.emoji + " " + result.category.name(in: language))
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .accessibilityHint(language.t(.changeCategory))

            VStack(alignment: .leading, spacing: 2) {
                Text(amountText)
                    .font(.headline)
                    .foregroundStyle(result.amount == nil ? .secondary : .primary)
                Text(DayLabel.text(for: result.date, language: language)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var amountText: String {
        guard let amount = result.amount else { return language.t(.noAmountYet) }
        return MoneyFormatter.signed(amount, isIncome: result.isIncome, currency: result.currency, language: language)
    }
}
