import Foundation
import SwiftData
import XuCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Thêm, sửa, bỏ ghim, sắp xếp khoản quen (E7). Mọi thay đổi đánh dấu `chipsCustomized`
/// để Xu không tự đặt lại khoản quen mặc định, và vẽ lại widget ngay.
@MainActor
enum QuickChipStore {
    enum StoreError: Error { case limitReached, missingAmount }

    static func add(title: String, emoji: String, amount: Int64, currency: Currency, categoryID: String,
                    in context: ModelContext) throws {
        guard amount > 0 else { throw StoreError.missingAmount }
        let chips = try context.fetch(FetchDescriptor<QuickChip>(sortBy: [SortDescriptor(\.sortOrder)]))
        guard chips.count < ChipSuggester.maxPinned else { throw StoreError.limitReached }
        context.insert(QuickChip(title: title, emoji: emoji, amount: amount, currency: currency,
                                 categoryID: categoryID, sortOrder: (chips.last?.sortOrder ?? -1) + 1))
        try commit(context)
    }

    static func update(_ chip: QuickChip, title: String, emoji: String, amount: Int64, currency: Currency,
                       categoryID: String, in context: ModelContext) throws {
        guard amount > 0 else { throw StoreError.missingAmount }
        chip.title = title
        chip.emoji = emoji
        chip.amount = amount
        chip.currencyCode = currency.code
        chip.categoryID = categoryID
        try commit(context)
    }

    static func remove(_ chips: [QuickChip], in context: ModelContext) throws {
        for chip in chips { context.delete(chip) }
        try commit(context)
    }

    /// `ordered` là danh sách sau khi kéo thả; đánh lại `sortOrder` 0, 1, 2…
    static func reorder(_ ordered: [QuickChip], in context: ModelContext) throws {
        for (index, chip) in ordered.enumerated() where chip.sortOrder != index {
            chip.sortOrder = index
        }
        try commit(context)
    }

    private static func commit(_ context: ModelContext) throws {
        AppSettings.chipsCustomized = true
        try context.save()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
