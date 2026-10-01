import AppIntents

/// Hiện sẵn trong Siri, app Phím tắt và Spotlight ngay khi cài app; gán được vào Action Button.
/// Siri hỗ trợ tiếng Việt từ iOS 18.4: nhớ bản địa hóa các câu lệnh trong AppShortcuts.xcstrings
/// và thử trên máy thật với Siri đặt tiếng Việt.
struct XuShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Ghi chi tiêu với \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "\(.applicationName)で支出を記録"
            ],
            shortTitle: "Ghi chi tiêu",
            systemImageName: "plus.circle.fill"
        )
    }
}
