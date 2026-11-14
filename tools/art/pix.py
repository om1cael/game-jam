"""Mini-motor de pixel art: formas com sombreamento (luz no canto superior esquerdo) e contorno seletivo."""
import math
import numpy as np
from PIL import Image, ImageDraw

def hexc(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))

def ramp(h):
    """(luz, base, sombra, profunda) com luz quente e sombra fria."""
    c = hexc(h) if isinstance(h, str) else h
    return (mix(c, (255, 232, 190), 0.38), c, mix(c, (46, 14, 52), 0.40), mix(c, (26, 8, 34), 0.66))

def shift(a, dy, dx):
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys, ye = max(dy, 0), h + min(dy, 0)
    xs, xe = max(dx, 0), w + min(dx, 0)
    out[ys:ye, xs:xe] = a[ys - dy:ye - dy, xs - dx:xe - dx]
    return out

class Canvas:
    def __init__(self, w=32, h=30):
        self.w, self.h = w, h
        self.img = np.zeros((h, w, 4), np.uint8)

    # ---------- máscaras ----------
    def mask(self, fn):
        m = Image.new('L', (self.w, self.h), 0)
        fn(ImageDraw.Draw(m))
        return np.array(m) > 0

    def ellipse_m(self, cx, cy, rx, ry):
        return self.mask(lambda d: d.ellipse([cx - rx, cy - ry, cx + rx - 0.01, cy + ry - 0.01], fill=255))

    def rect_m(self, x0, y0, x1, y1):
        xa, xb = sorted((round(x0), round(x1)))
        ya, yb = sorted((round(y0), round(y1)))
        return self.mask(lambda d: d.rectangle([xa, ya, max(xa, xb - 1), max(ya, yb - 1)], fill=255))

    def poly_m(self, pts):
        return self.mask(lambda d: d.polygon([(round(x), round(y)) for x, y in pts], fill=255))

    def line_m(self, pts, width=1):
        return self.mask(lambda d: d.line([(round(x), round(y)) for x, y in pts], fill=255, width=width))

    # ---------- pintura ----------
    def paint(self, m, col, shade=True, spec=False):
        hi, base, lo, deep = col if isinstance(col, tuple) and isinstance(col[0], tuple) else ramp(col)
        im = self.img
        im[m] = (*base, 255)
        if shade:
            big = m.sum() > 40
            dark = m & (~shift(m, -1, 0) | ~shift(m, 0, -1))
            if big:
                band = m & ~shift(m, -2, -2)
                im[band & m] = (*lo, 255)
            im[dark] = (*(deep if big else lo), 255)
            light = m & (~shift(m, 1, 0) | ~shift(m, 0, 1))
            im[light & ~dark] = (*hi, 255)
            if spec:
                ys, xs = np.where(m)
                if len(xs):
                    i = np.argmin(ys * 2 + xs)
                    y0, x0 = ys[i] + 1, xs[i] + 1
                    if 0 <= y0 < self.h and 0 <= x0 < self.w and m[y0, x0]:
                        im[y0, x0] = (255, 250, 235, 255)

    def px(self, x, y, c, a=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img[y, x] = (*c, a)

    def outline(self, dark=0.28, only_outer=True):
        a = self.img[..., 3] > 0
        res = self.img.copy()
        filled = np.zeros(a.shape, bool)
        for dy, dx in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            src = shift(self.img, dy, dx)
            sel = (src[..., 3] > 0) & ~a & ~filled
            res[sel, :3] = (src[sel, :3] * dark).astype(np.uint8)
            res[sel, 3] = 255
            filled |= sel
        self.img = res

    def shadow(self, cx, cy, rx, ry, alpha=120):
        under = np.zeros_like(self.img)
        m = self.ellipse_m(cx, cy, rx, ry)
        under[m] = (14, 8, 12, alpha)
        a = self.img[..., 3] > 0
        under[a] = self.img[a]
        self.img = under

    def sheet_frame(self, k):
        return Image.fromarray(self.img).resize((self.w * k, self.h * k), Image.NEAREST)

def sheet(frames, cols, k, fw, fh, rows=1):
    out = Image.new('RGBA', (fw * cols, fh * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, ((i % cols) * fw, (i // cols) * fh))
    return out

def aura(cv, cx, cy, r, col, strength=0.5, steps=4):
    """Brilho que acompanha a silhueta (anéis de 1px com alpha decrescente) + leve mistura interna."""
    op = cv.img[..., 3] > 0
    grown = op.copy()
    for i in range(steps):
        nxt = grown | shift(grown, 1, 0) | shift(grown, -1, 0) | shift(grown, 0, 1) | shift(grown, 0, -1)
        ring = nxt & ~grown
        a = max(0.0, min(0.95, strength * (1.0 - i / steps) * 1.4))
        cv.img[ring, :3] = col
        cv.img[ring, 3] = int(255 * a)
        grown = nxt
    cv.img[op, :3] = (cv.img[op, :3] * (1 - strength * 0.18) + np.array(col) * strength * 0.18).astype(np.uint8)

def tint(cv, col, amt):
    m = cv.img[..., 3] > 0
    cv.img[m, :3] = (cv.img[m, :3] * (1 - amt) + np.array(col) * amt).astype(np.uint8)
