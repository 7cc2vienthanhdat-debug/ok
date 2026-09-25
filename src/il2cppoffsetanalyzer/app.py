import toga
from toga.style import Pack
from toga.style.pack import COLUMN, ROW


class Il2CppOffsetAnalyzer(toga.App):

    def startup(self):
        self.main_window = toga.App.MainWindow(title="Sandbox Explorer")

        # Khung giao diện chính với phong cách tối giản, hiện đại
        main_box = toga.Box(
            style=Pack(
                direction=COLUMN,
                padding=20,
                background_color="#1c1c1e"
            )
        )

        # Tiêu đề ứng dụng
        title_label = toga.Label(
            "iOS Sandbox Explorer",
            style=Pack(
                font_weight="bold",
                font_size=18,
                color="#ffffff",
                padding_bottom=15
            ),
        )

        # Nút bấm tìm kiếm Sandbox
        self.scan_button = toga.Button(
            "Tìm kiếm & Liệt kê Sandbox",
            on_press=self.scan_sandboxes,
            style=Pack(
                background_color="#0a84ff",
                color="#ffffff",
                padding_bottom=15,
                height=40
            ),
        )

        # Khu vực hiển thị kết quả quét (Giao diện đẹp, chữ rõ ràng)
        self.result_output = toga.MultilineTextInput(
            value=(
                "=== HƯỚNG DẪN ===\n"
                "Bấm nút 'Tìm kiếm & Liệt kê Sandbox' bên trên\n"
                "để quét các vùng chứa dữ liệu ứng dụng.\n\n"
            ),
            style=Pack(
                flex=1,
                background_color="#2c2c2e",
                color="#ffffff"
            ),
        )

        # Đưa các thành phần vào khung chính
        main_box.add(title_label)
        main_box.add(self.scan_button)
        main_box.add(self.result_output)

        self.main_window.content = main_box
        self.main_window.show()

    def scan_sandboxes(self, widget):
        # Mô phỏng quá trình giao tiếp hệ thống sandbox theo yêu cầu
        self.result_output.value = (
            "⏳ Đang quét các vùng Sandbox khả dụng...\n"
            "----------------------------------------\n"
            "⚠️ Lưu ý hệ điều hành iOS:\n"
            "Do cơ chế bảo mật App Sandbox trên thiết bị không jailbreak,\n"
            "ứng dụng chỉ có quyền truy cập vào không gian lưu trữ riêng của chính nó.\n\n"
            "📁 Các đường dẫn Sandbox mẫu trong vùng chứa:\n"
            " - /var/mobile/Containers/Data/Application/\n"
            " - /Documents/\n"
            " - /Library/Caches/\n\n"
            "✅ Trạng thái: Đã quét xong phân vùng hiện tại."
        )


def main():
    return Il2CppOffsetAnalyzer()
