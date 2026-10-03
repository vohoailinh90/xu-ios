import SwiftUI
import SwiftData
import XuCore

/// Thanh nhập nhanh — trái tim của app. Mục tiêu: gõ "cà phê 35k" + Enter ≤ 2 giây.
/// Quy tắc: tự focus, xem trước ngay khi gõ, Enter là lưu, lưu xong vẫn giữ bàn phím.
struct QuickEntryBar: View {
    /// Tăng giá trị này (ví dụ khi mở từ widget `xu://new`) để focus lại ô nhập.
    var focusTrigger: Int = 0
    /// Ô nhập đang có chữ chưa lưu — để màn khác không chen hộp thoại vào giữa lúc đang ghi (ví dụ hỏi đánh giá).
    /// Chỉ cập nhật khi chuyển giữa rỗng và có chữ, không phải mỗi lần gõ.
    @Binding var hasDraft: Bool

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

    /// Câu có nhiều số tiền ("ăn trưa 45k tip 5k"): các khoản nếu tách ra (E8). Rỗng nếu chỉ có một khoản.
    private var splitParts: [QuickEntryResult] {
        guard preview?.hasMultipleAmounts == true else { return [] }
        // Khoản không nhận ra danh mục lấy danh mục thẻ xem trước đang hiện, kể cả khi đã chọn tay.
        let parts = parser.split(text.trimmingCharacters(in: .whitespacesAndNewlines),
                                 fallbackCategoryID: categoryOverride)
        return parts.count > 1 ? parts : []
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
            // Gợi ý thêm một chạm, không thay Enter: Enter vẫn lưu một khoản như thẻ xem trước.
            let parts = splitParts
            if !parts.isEmpty {
                SplitSuggestion(parts: parts, language: language) { submitSplit(parts) }
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
        .onChange(of: focusTrigger) {
            // Mở từ widget, thông báo hay Trung tâm điều khiển (`HomeView.startLogging`): bảng chọn danh mục của
            // chính ô nhập cũng không được che ô ghi. Đóng rồi focus, như khi chọn xong danh mục.
            showCategoryPicker = false
            focused = true
        }
        .onChange(of: text) { oldText, newText in
            errorMessage = nil
            let draft = !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasDraft != draft { hasDraft = draft }
            // Xoá hết ô nhập hay thay bằng câu khác là bỏ câu cũ: danh mục đã chọn tay không được dính sang câu sau
            // (và không được học sai), thời gian ghi đo lại từ đầu.
            if newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                categoryOverride = nil
                typingStartedAt = nil
            } else if typingStartedAt == nil || EntryTimingLog.startsNewSentence(from: oldText, to: newText, parser: parser) {
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
        save([result])
    }

    /// "Tách thành N khoản": lưu từng khoản của câu trong một lần. Danh mục chọn tay trên thẻ xem trước là của
    /// khoản đầu — khoản thẻ đang hiện.
    private func submitSplit(_ parts: [QuickEntryResult]) {
        var parts = parts
        if let categoryOverride, !parts.isEmpty {
            parts[0].categoryID = categoryOverride
            parts[0].isIncome = CategoryCatalog.resolve(id: categoryOverride).kind == .income
        }
        save(parts)
    }

    private func save(_ results: [QuickEntryResult]) {
        do {
            if categoryOverride != nil, let first = results.first {
                try Ledger.learn(note: first.note, categoryID: first.categoryID, in: context)
            }
            let records = try Ledger.save(results, rawInput: text, source: .quickText, in: context)
            // Một câu là một lần ghi, dù tách thành mấy khoản.
            let timing = typingStartedAt.flatMap { AppSettings.entryTimings.record(Date().timeIntervalSince($0)) }
            typingStartedAt = nil
            toast = SavedToast(records: records, language: language, timing: timing)
            text = ""
            categoryOverride = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        focused = true
    }

    private func undo(_ toast: SavedToast) {
        let records = toast.recordIDs.compactMap { id in
            try? context.fetch(FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.id == id })).first
        }
        if !records.isEmpty, (try? Ledger.delete(records, in: context)) != nil {
            // Khoản đã xoá được thì lần đo của nó cũng không tính; xoá không được thì giữ cả hai.
            if let timing = toast.timing { AppSettings.entryTimings.remove(timing) }
        }
        self.toast = nil
    }
}

struct SavedToast: Equatable {
    /// Các khoản vừa lưu từ một câu (nhiều khoản nếu đã tách), để hoàn tác xoá hết.
    let recordIDs: [UUID]
    /// Câu hiện trên toast, dựng lúc lưu.
    let message: String
    /// Lần đo thời gian ghi của câu này (nếu có), để hoàn tác thì xoá luôn.
    var timing: Double?
}

extension SavedToast {
    init(records: [TransactionRecord], language: AppLanguage, timing: Double?) {
        recordIDs = records.map(\.id)
        if records.count == 1, let record = records.first {
            message = language.t(.savedToast, record.category.emoji,
                                 MoneyFormatter.signed(record.amount, isIncome: record.isIncome,
                                                       currency: record.currency, language: language, compact: true),
                                 record.note.isEmpty ? record.category.name(in: language) : record.note)
        } else {
            message = language.t(.savedManyToast, "\(records.count)",
                                 amountList(records.map { (amount: $0.amount, isIncome: $0.isIncome, currency: $0.currency) },
                                            language: language))
        }
        self.timing = timing
    }
}

/// "45k, 5k": số tiền gọn của các khoản tách ra.
private func amountList(_ items: [(amount: Int64, isIncome: Bool, currency: Currency)], language: AppLanguage) -> String {
    items.map { MoneyFormatter.signed($0.amount, isIncome: $0.isIncome, currency: $0.currency,
                                      language: language, compact: true) }
        .joined(separator: language == .ja ? "、" : ", ")
}

/// Gợi ý tách câu nhiều số tiền thành từng khoản: một chạm là lưu hết (E8, docs/04).
private struct SplitSuggestion: View {
    let parts: [QuickEntryResult]
    let language: AppLanguage
    let onSplit: () -> Void

    var body: some View {
        Button(action: onSplit) {
            HStack(spacing: 6) {
                Image(systemName: "scissors")
                Text(language.t(.splitEntries, "\(parts.count)"))
                Text(amountList(parts.compactMap { part in
                    part.amount.map { (amount: $0, isIncome: part.isIncome, currency: part.currency) }
                }, language: language))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToastView: View {
    let toast: SavedToast
    let language: AppLanguage
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(toast.message)
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
                Text(DayLabel.text(for: result, language: language)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var amountText: String {
        guard let amount = result.amount else { return language.t(.noAmountYet) }
        return MoneyFormatter.signed(amount, isIncome: result.isIncome, currency: result.currency, language: language)
    }
}
