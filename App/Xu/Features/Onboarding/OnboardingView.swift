import SwiftUI
import SwiftData
import XuCore

/// Onboarding 3 màn (docs/02, S1), chỉ hiện lần mở đầu, bỏ qua được ở mọi màn:
/// 1. ngôn ngữ + nơi chi tiêu + gõ thử câu đầu tiên, 2. ngân sách tiêu vặt, 3. chọn một thói quen.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam
    @AppStorage(AppSettings.Key.reminderEnabled, store: AppSettings.defaults) private var reminderEnabled = false
    @AppStorage("smallNumbersAreThousands") private var smallNumbersAreThousands = true
    @AppStorage("flexibleMonthlyBudget") private var budgetVietnam: Int = 0
    @AppStorage("flexibleMonthlyBudget.japan") private var budgetJapan: Int = 0

    @State private var step = 0
    @State private var sample = ""
    @State private var savedFirst = false
    @State private var habit: HabitTemplate?
    @FocusState private var sampleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TabView(selection: $step) {
                    welcome.tag(0)
                    budget.tag(1)
                    habits.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if step < 2 { withAnimation { step += 1 } } else { finish() }
                } label: {
                    Text(language.t(step < 2 ? .next : .getStarted)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding(.bottom)
            .toolbar {
                Button(language.t(.skip)) { finish() }
            }
            .onChange(of: language) { PreferenceChanges.apply() }
            .onChange(of: market) { PreferenceChanges.apply() }
            .onChange(of: step) { sampleFocused = step == 0 && !savedFirst }
            .onAppear { sampleFocused = true }
        }
    }

    // MARK: Màn 1 — chào, ngôn ngữ, nơi chi tiêu, gõ thử

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(language.t(.onboardingWelcome)).font(.largeTitle.bold())
                Text(language.t(.onboardingIntro)).foregroundStyle(.secondary)

                Picker(language.t(.language), selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
                    Text(language.t(.market)).font(.subheadline.bold())
                    Picker(language.t(.market), selection: $market) {
                        ForEach(Market.allCases) { Text($0.name(in: language)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(language.t(.onboardingTry)).font(.subheadline.bold())
                    // Giống ô nhập chính: tự bật bàn phím, Enter là lưu (quy tắc 2 giây).
                    TextField(language.entryPlaceholder(for: market), text: $sample)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($sampleFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !savedFirst, let preview, preview.isComplete { saveFirst(preview) }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    if let preview {
                        Text(previewText(preview)).font(.callout)
                        if savedFirst {
                            Text(language.t(.onboardingSaved)).font(.callout.bold())
                        } else if preview.isComplete {
                            Button(language.t(.onboardingSaveFirst)) { saveFirst(preview) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var preview: QuickEntryResult? {
        let text = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let parser = QuickEntryParser(options: .init(smallNumbersAreThousands: smallNumbersAreThousands, market: market))
        return parser.parse(text)
    }

    private func previewText(_ result: QuickEntryResult) -> String {
        let amount = result.amount.map {
            MoneyFormatter.signed($0, isIncome: result.isIncome, currency: result.currency, language: language)
        } ?? language.t(.noAmountYet)
        return [result.category.emoji + " " + result.category.name(in: language), amount,
                DayLabel.text(for: result.date, language: language)].joined(separator: " · ")
    }

    private func saveFirst(_ result: QuickEntryResult) {
        guard (try? Ledger.save(result, rawInput: sample, source: .quickText, in: context)) != nil else { return }
        savedFirst = true
    }

    // MARK: Màn 2 — ngân sách tiêu vặt

    private var budget: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.t(.onboardingBudgetTitle)).font(.title2.bold())
            HStack {
                TextField(language.t(.budgetPlaceholder, market == .japan ? "30000" : "3000000"),
                          value: market == .japan ? $budgetJapan : $budgetVietnam, format: .number)
                    .keyboardType(.numberPad)
                    .font(.title3)
                Text(market.currency.symbol(in: language)).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            Text(language.t(.budgetFooter)).font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    // MARK: Màn 3 — một thói quen + nhắc buổi tối

    private var habits: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(language.t(.onboardingHabitTitle)).font(.title2.bold())
                Text(language.t(.onboardingHabitHint)).font(.callout).foregroundStyle(.secondary)
                ForEach(HabitTemplate.allCases.filter { $0 != .logDaily }, id: \.self) { template in
                    Button {
                        habit = habit == template ? nil : template
                    } label: {
                        HStack {
                            Text(template.emoji + " " + template.title(in: language))
                            Spacer()
                            if habit == template { Image(systemName: "checkmark.circle.fill") }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                Toggle(language.t(.reminderToggle), isOn: $reminderEnabled)
                    .padding(.top, 8)
                Text(language.t(.reminderFooter)).font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    // MARK: Xong

    private func finish() {
        if let habit {
            let existing = (try? context.fetch(FetchDescriptor<MoneyHabit>())) ?? []
            if !existing.contains(where: { $0.template == habit }) {
                context.insert(MoneyHabit(template: habit))
                try? context.save()
            }
        }
        if reminderEnabled {
            Task {
                // Không cho phép thông báo thì tắt lại công tắc, Cài đặt sẽ hiện hướng dẫn.
                if !(await ReminderScheduler.enable()) {
                    AppSettings.defaults.set(false, forKey: AppSettings.Key.reminderEnabled)
                }
            }
        }
        onFinish()
    }
}
