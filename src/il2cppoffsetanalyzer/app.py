import toga
from toga.style import Pack
from toga.style.pack import COLUMN, ROW, CENTER, LEFT, RIGHT

class Il2CppOffsetAnalyzer(toga.App):
    def startup(self):
        self.main_window = toga.MainWindow(title="Il2Cpp Offset Analyzer", size=(450, 550))
        
        # Khung chứa tổng thể (Căn lề và khoảng cách rộng rãi)
        main_box = toga.Box(style=Pack(direction=COLUMN, padding=20, flex=1))

        # 1. Tiêu đề ứng dụng nổi bật
        title_label = toga.Label(
            "⚡ IL2CPP OFFSET ANALYZER", 
            style=Pack(padding=(0, 0, 15, 0), font_weight="bold", text_align=CENTER)
        )
        main_box.add(title_label)

        # 2. Nhóm chọn file Metadata
        meta_box = toga.Box(style=Pack(direction=COLUMN, padding=10))
        self.meta_label = toga.Label("Chưa chọn tệp global-metadata.dat", style=Pack(padding=(0, 0, 5, 0), color="#666666"))
        btn_meta = toga.Button("📁 Chọn File Metadata", on_press=self.select_metadata, style=Pack(padding=2))
        meta_box.add(btn_meta)
        meta_box.add(self.meta_label)
        main_box.add(meta_box)

        # 3. Nhóm chọn file UnityFramework / libil2cpp
        binary_box = toga.Box(style=Pack(direction=COLUMN, padding=10))
        self.binary_label = toga.Label("Chưa chọn tệp UnityFramework", style=Pack(padding=(0, 0, 5, 0), color="#666666"))
        btn_binary = toga.Button("📁 Chọn File UnityFramework", on_press=self.select_binary, style=Pack(padding=2))
        binary_box.add(btn_binary)
        binary_box.add(self.binary_label)
        main_box.add(binary_box)

        # 4. Nút thực thi chính (Làm nổi bật)
        btn_run = toga.Button("🚀 BẮT ĐẦU PHÂN TÍCH OFFSET", on_press=self.run_analysis, style=Pack(padding=(15, 0, 10, 0)))
        main_box.add(btn_run)

        # 5. Khung log kết quả hiển thị bên dưới
        log_label = toga.Label("Trạng thái quá trình:", style=Pack(padding=(5, 0, 2, 0), font_weight="bold"))
        main_box.add(log_label)
        
        self.log_output = toga.MultilineTextInput(readonly=True, style=Pack(flex=1, padding=5))
        self.log_output.value = "Sẵn sàng... Vui lòng chọn đủ 2 tệp để bắt đầu.\n"
        main_box.add(self.log_output)

        self.main_window.content = main_box
        self.main_window.show()

    def select_metadata(self, widget):
        self.meta_label.text = "Đã chọn: global-metadata.dat"
        self.log_output.value += "[+] Đã tải thông tin tệp Metadata thành công.\n"

    def select_binary(self, widget):
        self.binary_label.text = "Đã chọn: UnityFramework"
        self.log_output.value += "[+] Đã tải thông tin tệp Nhị phân thành công.\n"

    def run_analysis(self, widget):
        self.log_output.value += "[*] Đang tiến hành quét và trích xuất offset...\n"
        # Logic phân tích offset sẽ đặt ở đây

def main():
    return Il2CppOffsetAnalyzer()