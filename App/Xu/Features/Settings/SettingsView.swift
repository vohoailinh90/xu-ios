import SwiftUI
import WidgetKit
import XuCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flexibleMonthlyBudget") private var budgetVietnam: Int = 0
    @AppStorage("flexibleMonthlyBudget.japan") private var budgetJapan: Int = 0
    @AppStorage("smallNumbersAreThousands") private var smallNumbersAreThousands = true
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam

    var body: some View {
        NavigationStack {
            Form {
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
                Section(language.t(.fasterEntry)) {
                    Label(language.t(.tipWidget), systemImage: "square.grid.2x2")
                    Label(language.t(.tipActionButton), systemImage: "button.horizontal.top.press")
                    Label(language.t(.tipApplePay), systemImage: "creditcard")
                }
            }
            .navigationTitle(language.t(.settings))
            .toolbar { Button(language.t(.done)) { dismiss() } }
            .onChange(of: language) { refreshAfterChange() }
            .onChange(of: market) { refreshAfterChange() }
        }
    }

    /// Khoản quen mặc định đổi theo ngôn ngữ/nơi chi tiêu; widget vẽ lại để đổi chữ và loại tiền.
    private func refreshAfterChange() {
        SampleData.refreshSeedsIfUntouched()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
