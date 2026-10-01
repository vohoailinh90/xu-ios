import AppIntents
import SwiftData
import XuCore

/// Nút "khoản quen" trên widget tương tác (iOS 17+): chạm là ghi, không mở app.
/// File này phải thuộc CẢ target app lẫn widget.
struct LogChipIntent: AppIntent {
    static let title: LocalizedStringResource = "Ghi khoản quen"
    static let isDiscoverable = false

    @Parameter(title: "Mã khoản quen") var chipID: String

    init() {}
    init(chipID: UUID) { self.chipID = chipID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: chipID) else { return .result() }
        let context = ModelContext(SharedStore.container)
        let descriptor = FetchDescriptor<QuickChip>(predicate: #Predicate { $0.id == id })
        if let chip = try context.fetch(descriptor).first {
            try Ledger.save(chip: chip, in: context)
        }
        return .result()
    }
}
