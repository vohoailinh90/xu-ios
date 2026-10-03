import LocalAuthentication
import Observation
import SwiftUI
import XuCore

/// Khoá Face ID (docs/02, S4): tắt sẵn, là tính năng Xu Pro (`ProPlan.canChangeFaceIDLock`).
///
/// - Chỉ che phần **xem**: danh sách, biểu đồ, thói quen, cài đặt, xuất CSV. Ô ghi chi tiêu không bao giờ bị khoá,
///   và Face ID không bao giờ tự bật ra lúc đang gõ — chỉ hỏi khi người dùng chạm "Mở khoá".
/// - Dùng `.deviceOwnerAuthentication`: Face ID, không được thì mật mã iPhone. Xu chỉ nhận đúng/sai từ iOS, không nhận
///   dữ liệu sinh trắc học.
/// - Không bao giờ nhốt người dùng ngoài dữ liệu của chính họ: máy không còn mật mã thì tự mở khoá.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()

    /// Đang khoá: phần xem bị che tới khi mở khoá. Mở app từ đầu mà khoá đang bật thì khoá ngay.
    private(set) var isLocked: Bool
    /// Che tạm khi app không còn ở phía trước (ảnh chụp trong App Switcher). Quay lại app là hết, không cần mở khoá lại.
    private(set) var isShielded = false
    private var isAuthenticating = false

    private init() {
        isLocked = AppSettings.faceIDLockEnabled && Self.canAuthenticate
    }

    /// Phần xem có đang bị che không.
    var isCovered: Bool { isLocked || isShielded }

    /// iPhone có mật mã (hoặc Face ID/Touch ID) để mở khoá không.
    static var canAuthenticate: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        guard AppSettings.faceIDLockEnabled else { return lockDisabled() }
        switch phase {
        case .active:
            isShielded = false
        case .inactive:
            // Hộp thoại Face ID của iOS cũng làm app "inactive": đừng che chính nó.
            if !isAuthenticating { isShielded = true }
        case .background:
            isShielded = true
            if Self.canAuthenticate { isLocked = true }
        @unknown default:
            break
        }
    }

    /// Chạm "Mở khoá".
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        guard Self.canAuthenticate else { isLocked = false; return }
        if await authenticate() { isLocked = false }
    }

    /// Bật khoá trong Cài đặt: xác thực được một lần rồi mới bật, để không tự khoá mình ngoài cửa.
    func confirmEnabling() async -> Bool {
        guard Self.canAuthenticate, !isAuthenticating else { return false }
        return await authenticate()
    }

    func lockDisabled() {
        isLocked = false
        isShielded = false
    }

    private func authenticate() async -> Bool {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            return try await LAContext().evaluatePolicy(.deviceOwnerAuthentication,
                                                        localizedReason: AppSettings.language.t(.faceIDReason))
        } catch {
            // Huỷ hay sai: vẫn khoá, người dùng chạm "Mở khoá" để thử lại.
            return false
        }
    }
}

extension View {
    /// Che view này khi khoá Face ID đang bật và đang khoá. Dùng cho các **sheet** xem dữ liệu, không bao giờ cho ô ghi
    /// hay khoản quen. Trên Home thì thay riêng các mục xem (`HomeView`), vì khoản quen là đường ghi, không được che.
    func faceIDGate() -> some View { FaceIDGated(content: self) }
}

/// Biểu tượng khoá, lời nhắn và nút "Mở khoá" — dùng cho lớp phủ của sheet và cho mục thay thế trên Home.
/// Chỉ khi thật sự đang khoá mới có nút; che tạm (App Switcher) thì chỉ có biểu tượng.
struct FaceIDLockedContent: View {
    private let lock = AppLock.shared
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary)
            if lock.isLocked {
                Text(language.t(.faceIDLockedHint))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(language.t(.faceIDUnlock)) { Task { await lock.unlock() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Là `View` (không phải `ViewModifier`) để giữ `AppLock.shared` như `ProStore.shared` ở các màn khác.
private struct FaceIDGated<Content: View>: View {
    let content: Content
    private let lock = AppLock.shared

    var body: some View {
        let covered = lock.isCovered
        // Chỉ phủ lên, không gỡ view ra: không mất vị trí cuộn hay nội dung đang mở khi chỉ che tạm.
        content
            .accessibilityHidden(covered)
            .overlay {
                if covered {
                    FaceIDLockedContent()
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                }
            }
    }
}
