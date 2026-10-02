import SwiftUI
import SwiftData
import XuCore

/// Quản lý khoản quen (E7): sửa, bỏ ghim, kéo để sắp xếp, thêm mới hoặc ghim từ gợi ý.
/// Gợi ý tính trên máy từ các khoản chi lặp lại trong 30 ngày (`ChipSuggester`), không gửi gì đi.
struct QuickChipsManager: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \QuickChip.sortOrder) private var chips: [QuickChip]
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam

    @State private var suggestions: [ChipSuggester.Suggestion] = []
    @State private var editing: ChipDraft?

    private var isFull: Bool { chips.count >= ChipSuggester.maxPinned }

    var body: some View {
        List {
            Section {
                if chips.isEmpty {
                    Text(language.t(.noChipsYet)).foregroundStyle(.secondary)
                }
                ForEach(chips) { chip in
                    Button { editing = ChipDraft(chip: chip) } label: {
                        ChipLine(emoji: chip.emoji, title: chip.title, amount: chip.amount, currency: chip.currency,
                                 language: language)
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: move)
                .onDelete(perform: remove)
                if !isFull {
                    Button { editing = ChipDraft(market: market) } label: {
                        Label(language.t(.addChip), systemImage: "plus")
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.t(isFull ? .chipLimitReached : .chipsFooter, "\(ChipSuggester.maxPinned)"))
                    if !ProStore.shared.isPro {
                        Text(language.t(.proWidgetNote, "\(ProPlan.freeWidgetChipLimit)"))
                    }
                }
            }

            if !suggestions.isEmpty, !isFull {
                Section(language.t(.chipSuggestions)) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        HStack {
                            let category = CategoryCatalog.resolve(id: suggestion.categoryID)
                            VStack(alignment: .leading, spacing: 2) {
                                ChipLine(emoji: category.emoji, title: suggestion.title, amount: suggestion.amount,
                                         currency: suggestion.currency, language: language)
                                Text(language.t(.chipSuggestionDays, "\(suggestion.days)"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Button(language.t(.pinChip)) { pin(suggestion) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .navigationTitle(language.t(.quickChips))
        .toolbar { EditButton() }
        .sheet(item: $editing) { QuickChipEditor(draft: $0) }
        // Ghim, sửa hay bỏ ghim đều làm đổi danh sách gợi ý.
        .task(id: chips.map(\.signature)) { refreshSuggestions() }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = chips
        ordered.move(fromOffsets: source, toOffset: destination)
        try? QuickChipStore.reorder(ordered, in: context)
    }

    private func remove(at offsets: IndexSet) {
        try? QuickChipStore.remove(offsets.map { chips[$0] }, in: context)
    }

    private func pin(_ suggestion: ChipSuggester.Suggestion) {
        let category = CategoryCatalog.resolve(id: suggestion.categoryID)
        try? QuickChipStore.add(title: suggestion.title, emoji: category.emoji, amount: suggestion.amount,
                                currency: suggestion.currency, categoryID: suggestion.categoryID, in: context)
    }

    private func refreshSuggestions() {
        let calendar = Calendar.current
        let today = DayKey(Date(), calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: Date())) ?? .distantPast
        // Cũ → mới: ChipSuggester lấy cách viết và danh mục của lần ghi sau cùng trong ngày.
        let records = (try? context.fetch(FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.occurredAt >= start && $0.isIncome == false },
            sortBy: [SortDescriptor(\.occurredAt), SortDescriptor(\.createdAt)]
        ))) ?? []
        let entries = records.map {
            ChipSuggester.Entry(note: $0.note, amount: $0.amount, currency: $0.currency, categoryID: $0.categoryID,
                                isIncome: $0.isIncome, day: $0.day(in: calendar))
        }
        let pinned = chips.map { ChipSuggester.Pinned(title: $0.title, amount: $0.amount, currency: $0.currency) }
        suggestions = ChipSuggester.suggest(entries: entries, pinned: pinned, today: today, calendar: calendar)
    }
}

private struct ChipLine: View {
    let emoji: String
    let title: String
    let amount: Int64
    let currency: Currency
    let language: AppLanguage

    var body: some View {
        HStack {
            Text(emoji)
            Text(title).lineLimit(1)
            Spacer()
            Text(MoneyFormatter.compact(amount, currency: currency, language: language))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

private extension QuickChip {
    var signature: String { "\(id)|\(title)|\(amount)|\(currencyCode)" }
}

/// Dữ liệu đang sửa: một khoản quen có sẵn, hoặc khoản mới theo tiền của nơi chi tiêu.
struct ChipDraft: Identifiable {
    let id = UUID()
    let chip: QuickChip?
    var title: String
    var emoji: String
    var amount: Int
    var currency: Currency
    var categoryID: String

    init(chip: QuickChip) {
        self.chip = chip
        title = chip.title
        emoji = chip.emoji
        amount = Int(chip.amount)
        currency = chip.currency
        categoryID = chip.categoryID
    }

    init(market: Market) {
        chip = nil
        title = ""
        emoji = ""
        amount = 0
        currency = market.currency
        categoryID = CategoryCatalog.otherExpenseID
    }
}

struct QuickChipEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi

    @State private var draft: ChipDraft
    /// Người dùng đã tự chọn danh mục thì không đoán lại theo tên nữa.
    @State private var pickedCategory = false
    @State private var showCategoryPicker = false

    init(draft: ChipDraft) {
        _draft = State(initialValue: draft)
        _pickedCategory = State(initialValue: draft.chip != nil)
    }

    private var category: CategoryDefinition { CategoryCatalog.resolve(id: draft.categoryID) }
    private var title: String { draft.title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(language.t(.chipTitleField), text: $draft.title)
                    TextField(language.t(.chipEmojiField), text: $draft.emoji, prompt: Text(category.emoji))
                    HStack {
                        TextField(language.t(.amountField), value: $draft.amount, format: .number)
                            .keyboardType(.numberPad)
                        Picker(language.t(.currencyField), selection: $draft.currency) {
                            ForEach(Currency.allCases) { Text($0.name(in: language)).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    Button { showCategoryPicker = true } label: {
                        LabeledContent(language.t(.categoryField)) {
                            Text(category.emoji + " " + category.name(in: language))
                        }
                        .foregroundStyle(.primary)
                    }
                }
                if draft.chip != nil {
                    Section {
                        Button(language.t(.unpinChip), role: .destructive, action: unpin)
                    }
                }
            }
            .navigationTitle(language.t(draft.chip == nil ? .newChip : .quickChips))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.t(.save), action: save).disabled(title.isEmpty || draft.amount <= 0)
                }
            }
            .onChange(of: draft.title) {
                guard !pickedCategory, let match = Ledger.parser(in: context).matcher.match(note: title),
                      match.kind == .expense else { return }
                draft.categoryID = match.id
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPicker(kind: .expense) { id in
                    draft.categoryID = id
                    pickedCategory = true
                    showCategoryPicker = false
                }
                .presentationDetents([.medium])
            }
        }
    }

    /// Một emoji; để trống thì dùng emoji của danh mục.
    private var emoji: String {
        draft.emoji.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? category.emoji
    }

    private func save() {
        let amount = Int64(draft.amount)
        if let chip = draft.chip {
            try? QuickChipStore.update(chip, title: title, emoji: emoji, amount: amount, currency: draft.currency,
                                       categoryID: draft.categoryID, in: context)
        } else {
            try? QuickChipStore.add(title: title, emoji: emoji, amount: amount, currency: draft.currency,
                                    categoryID: draft.categoryID, in: context)
        }
        dismiss()
    }

    private func unpin() {
        if let chip = draft.chip { try? QuickChipStore.remove([chip], in: context) }
        dismiss()
    }
}
