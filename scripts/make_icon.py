"""Genere les icones du depot CraneBulk : trois conteneurs empiles et un plus."""
from PIL import Image, ImageDraw
import sys

SIZE = 1024  # rendu large puis reduit, pour un antialiasing propre
BG_TOP = (44, 106, 224)
BG_BOTTOM = (30, 62, 158)
WHITE = (255, 255, 255)


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def build():
    # Fond en degrade vertical.
    bg = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(bg)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        draw.line(
            [(0, y), (SIZE, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)),
        )

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    img.paste(bg, (0, 0), rounded_mask(SIZE, int(SIZE * 0.225)))

    d = ImageDraw.Draw(img)

    # Trois cartes empilees en perspective : les conteneurs multiples.
    card_w, card_h = int(SIZE * 0.42), int(SIZE * 0.28)
    radius = int(SIZE * 0.045)
    stroke = int(SIZE * 0.028)
    base_x, base_y = int(SIZE * 0.15), int(SIZE * 0.18)
    offset = int(SIZE * 0.072)

    # Les deux cartes du fond en contour seul, la carte avant pleine.
    for i in (2, 1):
        x, y = base_x + offset * i, base_y + offset * i
        d.rounded_rectangle(
            [x, y, x + card_w, y + card_h],
            radius=radius, outline=WHITE, width=stroke,
        )
    d.rounded_rectangle(
        [base_x, base_y, base_x + card_w, base_y + card_h],
        radius=radius, fill=WHITE,
    )

    # Signe plus en bas a droite. Un disque de la couleur du fond est pose
    # dessous : il detache le plus de la pile de cartes au lieu de le laisser
    # se confondre avec elle.
    cx, cy = int(SIZE * 0.735), int(SIZE * 0.735)
    t = cy / (SIZE - 1)
    gap_color = tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM))
    gap_r = int(SIZE * 0.205)
    d.ellipse([cx - gap_r, cy - gap_r, cx + gap_r, cy + gap_r], fill=gap_color)

    arm, thick = int(SIZE * 0.115), int(SIZE * 0.034)
    d.rounded_rectangle([cx - arm, cy - thick, cx + arm, cy + thick],
                        radius=thick, fill=WHITE)
    d.rounded_rectangle([cx - thick, cy - arm, cx + thick, cy + arm],
                        radius=thick, fill=WHITE)
    return img


def main(out_dir):
    icon = build()
    for name, size in (("CydiaIcon.png", 512), ("icon.png", 256)):
        icon.resize((size, size), Image.LANCZOS).save(f"{out_dir}/{name}")
        print(f"ecrit : {out_dir}/{name} ({size}x{size})")


if __name__ == "__main__":
    main(sys.argv[1])
