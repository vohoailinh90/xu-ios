import AppIntents

/// Mở Xu thẳng vào ô ghi — nút trong Trung tâm điều khiển / màn hình khoá (iOS 18, docs/02 W4). Cùng đường với widget
/// `xu://new` và "Ghi thêm" trên thông báo: đóng mọi màn đang che rồi focus ô nhập (`HomeView.startLogging`).
/// Không ghi gì cả: người dùng gõ câu trong app như mọi khi. File này phải thuộc CẢ target app lẫn widget.
struct OpenQuickEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Mở ô ghi chi tiêu"
    static let description = IntentDescription("Mở Xu, con trỏ nằm sẵn trong ô ghi.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppSettings.requestFocus()
        return .result()
    }
}
