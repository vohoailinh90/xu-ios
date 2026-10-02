import AppIntents

/// Hiện sẵn trong Siri, app Phím tắt và Spotlight ngay khi cài app; gán được vào Action Button.
/// Câu lệnh viết bằng tiếng Việt (ngôn ngữ gốc của app); bản tiếng Anh/Nhật nằm trong `AppShortcuts.xcstrings`
/// (cùng thư mục), mỗi câu gốc một bản dịch. Thêm câu mới thì thêm cả bản dịch. Cần thử trên máy thật với Siri
/// đặt từng thứ tiếng (docs/08).
struct XuShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Ghi chi tiêu với \(.applicationName)",
                "\(.applicationName) ghi khoản chi"
            ],
            shortTitle: "Ghi chi tiêu",
            systemImageName: "plus.circle.fill"
        )
    }
}
