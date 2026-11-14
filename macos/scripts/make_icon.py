"""Icône d'AZA Sessions : un potard dans un carré arrondi façon macOS.

Régénère macos/AppIcon.png (1024 px) ; build.sh en tire l'.icns.
Usage : python macos/scripts/make_icon.py macos/AppIcon.png
Demande Pillow et la police JetBrains Mono Bold (chemin ci-dessous).
"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 2048                      # dessin à 2x, réduit ensuite (anticrénelage)
ORANGE = (232, 89, 12)
OUT = sys.argv[1]

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# Carré arrondi Big Sur : 824/1024 du canevas, rayon ~185/1024, ombre portée
inset = int(S * 100 / 1024)
box = (inset, inset, S - inset, S - inset)
radius = int(S * 185 / 1024)
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((box[0], box[1] + 24, box[2], box[3] + 24), radius, fill=(0, 0, 0, 150))
img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(36)))

bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
for y in range(S):
    t = y / S
    c = int(30 - 18 * t)
    gd.line([(0, y), (S, y)], fill=(c, c - 1, c - 3, 255))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle(box, radius, fill=255)
bg.paste(grad, (0, 0), mask)
img = Image.alpha_composite(img, bg)
# Liseré intérieur discret — sur un calque fondu : dessiné directement, une
# couleur semi-transparente REMPLACE les pixels et perce l'icône.
rim = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(rim).rounded_rectangle((box[0] + 6, box[1] + 6, box[2] - 6, box[3] - 6), radius - 6,
                                      outline=(255, 255, 255, 22), width=6)
img = Image.alpha_composite(img, rim)
d = ImageDraw.Draw(img)

# Le potard
cx, cy, r = S // 2, int(S * 0.45), int(S * 0.255)
ring = (cx - r, cy - r, cx + r, cy + r)
d.arc(ring, 135, 405, fill=(58, 54, 50, 255), width=int(S * 0.034))          # course complète
d.arc(ring, 135, 345, fill=ORANGE + (255,), width=int(S * 0.034))            # réglage
# graduations
for i in range(11):
    a = math.radians(135 + i * 27)
    r1, r2 = r + int(S * 0.045), r + int(S * 0.07)
    d.line([(cx + r1 * math.cos(a), cy + r1 * math.sin(a)),
            (cx + r2 * math.cos(a), cy + r2 * math.sin(a))],
           fill=(110, 104, 96, 255) if i % 5 else (170, 160, 150, 255), width=int(S * 0.008))
# bouton
kr = int(r * 0.66)
d.ellipse((cx - kr, cy - kr, cx + kr, cy + kr), fill=(24, 23, 22, 255), outline=(70, 66, 62, 255), width=int(S * 0.006))
a = math.radians(345)
d.line([(cx + kr * 0.18 * math.cos(a), cy + kr * 0.18 * math.sin(a)),
        (cx + kr * 0.86 * math.cos(a), cy + kr * 0.86 * math.sin(a))],
       fill=ORANGE + (255,), width=int(S * 0.022))

# AZA
font = ImageFont.truetype("/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Bold.ttf", int(S * 0.15))
text = "AZA"
spacing = int(S * 0.03)
widths = [d.textlength(ch, font=font) for ch in text]
total = sum(widths) + spacing * (len(text) - 1)
x = cx - total / 2
ty = int(S * 0.735)
for ch, w in zip(text, widths):
    d.text((x, ty), ch, font=font, fill=(214, 208, 196, 255), anchor="lm")
    x += w + spacing

img.resize((1024, 1024), Image.LANCZOS).save(OUT)
print("écrit", OUT)
