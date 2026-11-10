import io
import tkinter as tk
import webbrowser
from PIL import Image, ImageTk
from urllib.request import urlopen

CAT_IMAGE_URL = (
    "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=300&auto=format&fit=crop&q=80"
)
GIT_URL = "https://github.com/dilmukhamedz-byte"
SMOLGU_URL = "https://smolgu.ru"

class CatApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Интерактивное приложение с котиком")
        self.root.geometry("600x450")
        self.root.minsize(500, 400)
        
        self.is_cat_text = False
        self.initial_text = "Добро пожаловать в приложение!"
        
        top_frame = tk.Frame(root, bg="#f0f0f0", height=60)
        top_frame.pack(side=tk.TOP, fill=tk.X, padx=20, pady=15)
        top_frame.pack_propagate(False)
        
        self.label = tk.Label(top_frame, text=self.initial_text, font=("Arial", 12), bg="#f0f0f0", fg="#333333")
        self.label.pack(side=tk.LEFT, anchor="w")
        
        btn_smolgu = tk.Button(top_frame, text="СмолГУ", command=lambda: webbrowser.open(SMOLGU_URL), bg="#0056b3", fg="white", font=("Arial", 10, "bold"), padx=10, pady=5, cursor="hand2")
        btn_smolgu.pack(side=tk.RIGHT, anchor="e")
        
        btn_git = tk.Button(top_frame, text="Открыть Гит", command=lambda: webbrowser.open(GIT_URL), bg="#24292e", fg="white", font=("Arial", 10, "bold"), padx=10, pady=5, cursor="hand2")
        btn_git.pack(side=tk.RIGHT, expand=True, anchor="center")
        
        self.img_container = tk.Frame(root, bg="white")
        self.img_container.pack(side=tk.BOTTOM, fill=tk.X, padx=20, pady=(0, 42))
        
        self.load_cat_image()

    def load_cat_image(self):
        try:
            with urlopen(CAT_IMAGE_URL) as response:
                image_data = response.read()
            image = Image.open(io.BytesIO(image_data))
            image = image.resize((200, 150), Image.Resampling.LANCZOS)
            self.cat_photo = ImageTk.PhotoImage(image)
            self.img_label = tk.Label(self.img_container, image=self.cat_photo, bg="white", cursor="hand2")
            self.img_label.pack(anchor="center")
            self.img_label.bind("<Button-1>", self.on_cat_click)
        except Exception as e:
            self.img_label = tk.Label(self.img_container, text="[Не удалось загрузить картинку]", font=("Arial", 10), fg="red", cursor="hand2")
            self.img_label.pack(anchor="center")
            self.img_label.bind("<Button-1>", self.on_cat_click)

    def on_cat_click(self, event):
        if self.is_cat_text:
            self.label.config(text=self.initial_text)
            self.is_cat_text = False
        else:
            self.label.config(text="Это котик")
            self.is_cat_text = True

if __name__ == "__main__":
    root = tk.Tk()
    app = CatApp(root)
    root.mainloop()