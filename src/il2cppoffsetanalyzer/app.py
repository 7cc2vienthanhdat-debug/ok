import json
import toga
from toga.style import Pack
from toga.style.pack import COLUMN, ROW


class Il2CppOffsetAnalyzer(toga.App):

    def startup(self):
        self.main_window = toga.App.MainWindow(title=self.formal_name)

        # Dữ liệu mẫu (nếu chưa tải file JSON lên)
        self.offset_data = {
            "Player_Update": "0x1234568",
            "Weapon_Shoot": "0x123A4B2",
            "GetPlayerHealth": "0x19F8C20",
            "SetPosition": "0x1122334",
        }

        # --- GIAO DIỆN CHÍNH ---
        main_box = toga.Box(
            style=Pack(direction=COLUMN, padding=15, background_color="#f5f5f7")
        )

        # Tiêu đề ứng dụng
        title_label = toga.Label(
            "Il2Cpp Offset Analyzer (Non-Jailbreak)",
            style=Pack(
                font_weight="bold", font_size=16, padding_bottom=10
            ),
        )

        # Khung tìm kiếm offset
        search_box = toga.Box(style=Pack(direction=ROW, padding_bottom=10))
        self.search_input = toga.TextInput(
            placeholder="Nhập tên hàm cần tìm (VD: Player)...",
            style=Pack(flex=1, padding_right=5),
        )
        search_button = toga.Button(
            "Tìm kiếm",
            on_press=self.handle_search,
            style=Pack(background_color="#007aff", color="#ffffff"),
        )
        search_box.add(self.search_input)
        search_box.add(search_button)

        # Khung hiển thị kết quả (MultiLineTextInput thay thế cho Log view)
        self.log_output = toga.MultilineTextInput(
            value=(
                "=== HƯỚNG DẪN SỬ DỤNG ===\n"
                "1. Dùng PC để dump offset ra tệp JSON.\n"
                "2. Đưa tệp JSON vào ứng dụng hoặc dùng danh sách mẫu.\n"
                "3. Nhập tên hàm vào ô trên và bấm Tìm kiếm để lấy Offset.\n\n"
                "Sẵn sàng tra cứu...\n"
            ),
            style=Pack(flex=1, padding_top=5),
        )

        # Đưa các widget vào khung chính
        main_box.add(title_label)
        main_box.add(search_box)
        main_box.add(self.log_output)

        self.main_window.content = main_box
        self.main_window.show()

    def handle_search(self, widget):
        keyword = self.search_input.value.strip().lower()
        if not keyword:
            self.log_output.value = (
                "⚠️ Vui lòng nhập từ khóa tên hàm cần tìm!"
            )
            return

        found_results = []
        for name, offset in self.offset_data.items():
            if keyword in name.lower():
                found_results.append(f"🎯 Hàm: {name}\n   ➔ Offset: {offset}\n")

        if found_results:
            result_str = f"=== KẾT QUẢ TÌM KIẾM CHO '{keyword}': ===\n\n" + "\n".join(
                found_results
            )
            self.log_output.value = result_str
        else:
            self.log_output.value = (
                f"❌ Không tìm thấy hàm nào khớp với từ khóa: '{keyword}'"
            )


def main():
    return Il2CppOffsetAnalyzer()