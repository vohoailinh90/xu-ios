import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flexibleMonthlyBudget") private var flexibleBudget: Int = 0
    @AppStorage("smallNumbersAreThousands") private var smallNumbersAreThousands = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ví dụ: 3000000", value: $flexibleBudget, format: .number)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Ngân sách tiêu vặt mỗi tháng")
                } footer: {
                    Text("Chỉ tính cà phê, mua sắm, giải trí… Xu chia đều cho những ngày còn lại. Để 0 nếu chưa muốn dùng.")
                }
                Section {
                    Toggle("Hiểu \"phở 45\" là 45.000đ", isOn: $smallNumbersAreThousands)
                }
                Section("Nhập nhanh hơn") {
                    Label("Thêm widget Xu ra màn hình chính", systemImage: "square.grid.2x2")
                    Label("Gán \"Ghi chi tiêu\" vào Action Button (Cài đặt › Nút Tác vụ › Phím tắt)", systemImage: "button.horizontal.top.press")
                    Label("Tự ghi khi quẹt Apple Pay (Phím tắt › Tự động hóa › Giao dịch)", systemImage: "creditcard")
                }
            }
            .navigationTitle("Cài đặt")
            .toolbar { Button("Xong") { dismiss() } }
        }
    }
}
