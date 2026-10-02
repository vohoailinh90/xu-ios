import SwiftUI
import XuCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flexibleMonthlyBudget") private var budgetVietnam: Int = 0
    @AppStorage("flexibleMonthlyBudget.japan") private var budgetJapan: Int = 0
    @AppStorage("smallNumbersAreThousands") private var smallNumbersAreThousands = true
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam
    @AppStorage(AppSettings.Key.reminderEnabled, store: AppSettings.defaults) private var reminderEnabled = false
    @AppStorage(AppSettings.Key.reminderMinutes, store: AppSettings.defaults)
    private var reminderMinutes = AppSettings.defaultReminderMinutes
    @State private var reminderDenied = false
    @State private var showPaywall = false
    private let store = ProStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showPaywall = true } label: {
                        Label(language.t(store.isPro ? .proOwned : .proTitle), systemImage: "sparkles")
                    }
                }
                Section {
                    Picker(language.t(.language), selection: $language) {
                        ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                    }
                } footer: {
                    Text(language.t(.languageFooter))
                }
                Section {
                    Picker(language.t(.market), selection: $market) {
                        ForEach(Market.allCases) { Text($0.name(in: language)).tag($0) }
                    }
                } footer: {
                    Text(language.t(.marketFooter))
                }
                Section {
                    TextField(language.t(.budgetPlaceholder, market == .japan ? "30000" : "3000000"),
                              value: market == .japan ? $budgetJapan : $budgetVietnam, format: .number)
                        .keyboardType(.numberPad)
                } header: {
                    Text(language.t(.budgetHeader, market.currency.symbol(in: language)))
                } footer: {
                    Text(language.t(.budgetFooter))
                }
                if market == .vietnam {
                    Section {
                        Toggle(language.t(.smallNumbersToggle), isOn: $smallNumbersAreThousands)
                    }
                }
                Section {
                    Toggle(language.t(.reminderToggle), isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker(language.t(.reminderTime), selection: reminderTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, language.locale)
                    }
                } footer: {
                    Text(language.t(reminderDenied ? .reminderDenied : .reminderFooter))
                }
                Section {
                    NavigationLink {
                        QuickChipsManager()
                    } label: {
                        Label(language.t(.quickChips), systemImage: "pin")
                    }
                    Label(language.t(.tipWidget), systemImage: "square.grid.2x2")
                    Label(language.t(.tipActionButton), systemImage: "button.horizontal.top.press")
                    if #available(iOS 18.0, *) {
                        Label(language.t(.tipControl), systemImage: "switch.2")
                    }
                    NavigationLink {
                        ApplePayGuideView()
                    } label: {
                        Label(language.t(.tipApplePay), systemImage: "creditcard")
                    }
                } header: {
                    Text(language.t(.fasterEntry))
                } footer: {
                    // Chỉ hiện khi đã đủ vài lần đo, để con số có nghĩa.
                    let timings = AppSettings.entryTimings
                    if timings.count >= 5, let median = timings.median {
                        Text(language.t(.entryTimingSummary,
                                        median.formatted(.number.precision(.fractionLength(1)).locale(language.locale)),
                                        "\(timings.count)"))
                    }
                }
                Section {
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Label(language.t(.privacyTitle), systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle(language.t(.settings))
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .toolbar { Button(language.t(.done)) { dismiss() } }
            .onChange(of: language) { PreferenceChanges.apply() }
            .onChange(of: market) { PreferenceChanges.apply() }
            .onChange(of: reminderEnabled) {
                guard reminderEnabled else { ReminderScheduler.refresh(); return }
                Task {
                    let granted = await ReminderScheduler.enable()
                    reminderDenied = !granted
                    if !granted { reminderEnabled = false }
                }
            }
            .onChange(of: reminderMinutes) { ReminderScheduler.refresh() }
        }
    }

    /// Giờ nhắc lưu dạng số phút trong ngày; DatePicker cần Date.
    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
        }
    }
}
