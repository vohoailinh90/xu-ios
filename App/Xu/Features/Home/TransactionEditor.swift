import SwiftUI
import SwiftData
import XuCore

/// Sửa một khoản đã ghi: số tiền, loại tiền, thu/chi, danh mục, ghi chú, ngày — hoặc xoá.
/// Đổi danh mục thì Xu học từ khoá như khi sửa trên thẻ xem trước (US-2).
struct TransactionEditor: View {
    let record: TransactionRecord

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi

    @State private var note: String
    @State private var amount: Int
    @State private var currency: Currency
    @State private var isIncome: Bool
    @State private var categoryID: String
    @State private var day: Date
    @State private var showCategoryPicker = false
    @State private var errorMessage: String?

    init(record: TransactionRecord) {
        self.record = record
        _note = State(initialValue: record.note)
        _amount = State(initialValue: Int(record.amount))
        _currency = State(initialValue: record.currency)
        _isIncome = State(initialValue: record.isIncome)
        _categoryID = State(initialValue: record.categoryID)
        // Ngày đã chốt lúc ghi, không phải `occurredAt` đọc theo múi giờ hiện tại.
        _day = State(initialValue: record.day().date(in: .current))
    }

    private var category: CategoryDefinition { CategoryCatalog.resolve(id: categoryID) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(language.t(.noteField), text: $note)
                    HStack {
                        TextField(language.t(.amountField), value: $amount, format: .number)
                            .keyboardType(.numberPad)
                        Picker(language.t(.currencyField), selection: $currency) {
                            ForEach(Currency.allCases) { Text($0.name(in: language)).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    Toggle(language.t(.incomeToggle), isOn: $isIncome)
                    Button { showCategoryPicker = true } label: {
                        LabeledContent(language.t(.categoryField)) {
                            Text(category.emoji + " " + category.name(in: language))
                        }
                        .foregroundStyle(.primary)
                    }
                    DatePicker(language.t(.dateField), selection: $day, displayedComponents: .date)
                        .environment(\.locale, language.locale)
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button(language.t(.deleteEntry), role: .destructive, action: delete)
                }
            }
            .navigationTitle(language.t(.editEntry))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.t(.save), action: save).disabled(amount <= 0)
                }
            }
            .onChange(of: isIncome) {
                // Đổi thu ↔ chi mà danh mục không còn hợp loại thì về "Khác" của loại mới.
                let kind: CategoryKind = isIncome ? .income : .expense
                if category.kind != kind {
                    categoryID = isIncome ? CategoryCatalog.otherIncomeID : CategoryCatalog.otherExpenseID
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPicker(kind: isIncome ? .income : .expense) { id in
                    categoryID = id
                    showCategoryPicker = false
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if categoryID != record.categoryID, !trimmedNote.isEmpty {
                try Ledger.learn(note: trimmedNote, categoryID: categoryID, in: context)
            }
            try Ledger.update(record, amount: Int64(amount), currency: currency, isIncome: isIncome,
                              categoryID: categoryID, note: trimmedNote, day: day, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        try? Ledger.delete(record, in: context)
        dismiss()
    }
}
