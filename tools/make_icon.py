from pathlib import Path

from PIL import Image, ImageDraw

img = Image.new("RGBA", (192, 192), (238, 123, 95, 255))
d = ImageDraw.Draw(img)
d.ellipse((36, 36, 156, 156), fill=(255, 250, 242, 255))
for name in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
    p = Path(f"android/app/src/main/res/mipmap-{name}")
    p.mkdir(parents=True, exist_ok=True)
    img.save(p / "ic_launcher.png")
print("icons ok")
