import SwiftUI
import UIKit

/// Tệp đang được chia sẻ (xuất CSV). Giữ trong state của `HomeView` để đóng được bảng chia sẻ khi khoá Face ID.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Bảng chia sẻ của iOS cho một tệp. Trình bày bằng `.sheet(item:)` thay vì `ShareLink` để app đóng được nó khi khoá:
/// `ShareLink` đã mở rồi thì không thu hồi được.
struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
