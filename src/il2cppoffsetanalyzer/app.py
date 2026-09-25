import json
import traceback
import toga
from toga.style import Pack
from toga.style.pack import COLUMN, ROW


class Il2CppOffsetAnalyzer(toga.App):

    def startup(self):
        self.main_window = toga.App.MainWindow(title=self.formal_name)

        try:
            # Dữ liệu mẫu tra cứu
            self.offset_data = {
                "Player_Update": "0x1234568",
                "Weapon_Shoot": "0x123A4B2",
                "GetPlayerHealth": "0x19F8C20",
                "SetPosition": "0x1122334",
            }

            # --- GIAO DIỆN CHÍNH ---
            main_box = toga.Box(style=Pack(direction=COLUMN, padding=10))

            title_label = toga.Label(
                "Il2Cpp Offset Analyzer", style=Pack(font_weight="bold", font_size=14, padding_bottom=5)
            )

            search_box = toga.Box(style=Pack(direction=ROW, padding_bottom=5))
            self.search_input = toga.TextInput(
                placeholder="Nhập tên hàm...",
                style=Pack(flex=1, padding_right=5),
            )
            search_button = toga.Button("Tìm", on_press=self.handle_search)
            search_box.add(self.search_input)
            search_box.add(search_button)

            self.log_output = toga.MultilineTextInput(
                value="Ứng dụng khởi động thành công!\nHãy nhập tên hàm để tìm kiếm offset.\n",
                style=Pack(flex=1),
            )

            main_box.add(title_label)
            main_box.add(search_box)
            main_box.add(self.log_output)

            self.main_window.content = main_box

        except Exception as e:
            # Nếu có lỗi khi khởi tạo giao diện, hiển thị thẳng lên màn hình thay vì văng app
            err_box = toga.Box(style=Pack(direction=COLUMN, padding=10))
            err_label = toga.Label(f"Lỗi khởi động: {str(e)}", style=Pack(color="red"))
            err_box.add(err_label)
            self.main_window.content = err_box

        self.main_window.show()

    def handle_search(self, widget):
        try:
            keyword = self.search_input.value.strip().lower()
            if not keyword:
                self.log_output.value = "⚠️ Vui lòng nhập từ khóa!"
                return

            found_results = []
            for name, offset in self.offset_data.items():
                if keyword in name.lower():
                    found_results.append(f"🎯 {name} -> {offset}")

            if found_results:
                self.log_output.value = "\n".join(found_results)
            else:
                self.log_output.value = f"❌ Không tìm thấy: '{keyword}'"
        except Exception as ex:
            self.log_output.value = f"Lỗi xử lý: {str(ex)}"


def main():
    return Il2CppOffsetAnalyzer()
