import SwiftUI
import XuCore

/// Lưới emoji — đổi danh mục bằng một chạm.
struct CategoryPicker: View {
    let kind: CategoryKind
    let onPick: (String) -> Void
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CategoryCatalog.defaults.filter { $0.kind == kind }) { category in
                    Button { onPick(category.id) } label: {
                        VStack(spacing: 6) {
                            Text(category.emoji).font(.largeTitle)
                            Text(category.name(in: language)).font(.caption).multilineTextAlignment(.center).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}
