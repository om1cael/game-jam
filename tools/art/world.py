import math, random
from pix import *

# ---------------- armas (apontadas para a direita, 32x30 lógico -> 128x120) ----------------
def rifle():
    cv = Canvas()
    steel, dark, ora, wood = ramp('#8a909a'), ramp('#3d4048'), ramp('#e0662f'), ramp('#6b4332')
    cv.paint(cv.poly_m([(5, 13), (12, 13), (12, 19), (7, 20)]), wood)
    cv.paint(cv.poly_m([(12, 18), (15, 18), (14, 25), (11, 24)]), dark)
    cv.paint(cv.rect_m(16, 18, 19, 24), dark)
    cv.paint(cv.rect_m(11, 12, 21, 19), ramp('#6c7078'), spec=True)
    cv.paint(cv.rect_m(20, 13, 31, 16), steel)
    cv.paint(cv.rect_m(21, 16, 28, 18), ora, shade=False)
    cv.paint(cv.rect_m(28, 12, 31, 17), dark)
    cv.paint(cv.rect_m(13, 9, 20, 12), ramp('#2d3036'))
    cv.px(20, 10, (110, 240, 255)); cv.px(19, 10, (110, 240, 255))
    cv.px(30, 14, (255, 150, 60))
    cv.outline(0.2); return cv

def shotgun():
    cv = Canvas()
    wood, steel, dark = ramp('#9a6338'), ramp('#7f858e'), ramp('#3a3d44')
    cv.paint(cv.poly_m([(4, 13), (12, 12), (12, 19), (6, 21)]), wood)
    cv.paint(cv.poly_m([(12, 18), (16, 18), (15, 25), (11, 24)]), ramp('#5a3a2c'))
    cv.paint(cv.rect_m(11, 11, 20, 19), ramp('#545a63'), spec=True)
    cv.paint(cv.rect_m(19, 12, 31, 16), steel)
    cv.paint(cv.rect_m(19, 16, 29, 18), ramp('#5b6068'))
    cv.paint(cv.rect_m(21, 16, 27, 20), wood)
    cv.paint(cv.rect_m(28, 11, 31, 17), dark)
    cv.paint(cv.rect_m(30, 12, 32, 16), ramp('#17181c'), shade=False)
    for x in (23, 25): cv.px(x, 18, (60, 36, 24))
    cv.outline(0.2); return cv

def ion():
    cv = Canvas()
    body, dark, cy = ramp('#3d6a80'), ramp('#1f3a49'), ramp('#58e8f2')
    cv.paint(cv.poly_m([(4, 14), (10, 12), (10, 19), (5, 19)]), dark)
    cv.paint(cv.poly_m([(11, 18), (15, 18), (14, 25), (10, 24)]), dark)
    cv.paint(cv.rect_m(9, 10, 22, 20), body, spec=True)
    cv.paint(cv.rect_m(11, 12, 20, 18), dark)
    cv.paint(cv.rect_m(12, 13, 19, 17), ramp('#9ff6ff'), shade=False)
    cv.paint(cv.rect_m(21, 11, 28, 19), ramp('#2c4b5d'))
    for x in (22, 25):
        cv.paint(cv.rect_m(x, 9, x + 2, 21), cy, shade=False)
    cv.paint(cv.poly_m([(27, 9), (31, 7), (31, 23), (27, 21)]), ramp('#58a8b8'))
    cv.paint(cv.ellipse_m(30, 15, 2, 3), ramp('#e8ffff'), shade=False)
    cv.px(14, 15, (255, 255, 255))
    cv.outline(0.2); return cv

def weapon_sheet(cv): return cv.sheet_frame(4)

# ---------------- laser (128x64) ----------------
def laser():
    w, h = 128, 64
    x = np.linspace(0, 1, w)[None, :]
    y = np.linspace(-1, 1, h)[:, None]
    taper = np.clip(x * 1.25, 0, 1) ** 0.8
    head = np.clip((1 - x) * 9, 0, 1)
    halfw = 0.78 * taper
    env = np.clip(1 - (np.abs(y) / (halfw + 1e-3)) ** 2, 0, 1) * head
    core = np.clip(1 - (np.abs(y) / (0.18 * taper + 1e-3)) ** 2, 0, 1) * head
    a = np.clip(env * 0.85 + core, 0, 1)
    img = np.zeros((h, w, 4), np.uint8)
    glow = np.array([255, 160, 70], float); hot = np.array([255, 250, 225], float)
    m = core[..., None]
    rgb = glow * (1 - m) + hot * m
    img[..., :3] = rgb.astype(np.uint8)
    img[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(img)

# ---------------- chão (48x48 = 24x24 lógico x2), sem emendas ----------------
def tor_noise(n, cells, rng):
    g = rng.random((cells, cells))
    xi = np.linspace(0, cells, n, endpoint=False)
    x0 = np.floor(xi).astype(int); t = xi - x0
    t = t * t * (3 - 2 * t)
    x1 = (x0 + 1) % cells
    rows = g[:, x0] * (1 - t) + g[:, x1] * t
    r = np.zeros((n, n))
    for yi in range(n):
        y0 = int(np.floor(xi[yi])); ty = t[yi]; y1 = (y0 + 1) % cells
        r[yi] = rows[y0] * (1 - ty) + rows[y1] * ty
    return r

def ground_tile(seed):
    rng = np.random.default_rng(seed); r = random.Random(seed)
    n = 24
    f = tor_noise(n, 3, rng) * 0.6 + tor_noise(n, 6, rng) * 0.4
    pal = [hexc(c) for c in ('#7e2c24', '#92362a', '#a6402f', '#b84b35', '#c75a3d')]
    idx = np.clip(((f - f.min()) / (f.max() - f.min()) * 5).astype(int), 0, 4)
    # dithering suave entre faixas
    for y in range(n):
        for x in range(n):
            if (x + y) % 2 == 0 and r.random() < 0.18:
                idx[y, x] = max(0, min(4, idx[y, x] + r.choice((-1, 1))))
    img = np.zeros((n, n, 4), np.uint8)
    for y in range(n):
        for x in range(n):
            img[y, x] = (*pal[idx[y, x]], 255)
    def put(x, y, c):
        img[y % n, x % n] = (*c, 255)
    for _ in range(9):                 # seixos com brilho e sombra
        x, y = r.randrange(n), r.randrange(n)
        put(x, y, (150, 62, 48)); put(x + 1, y, (150, 62, 48)); put(x, y - 1, (214, 112, 78)); put(x + 1, y + 1, (96, 34, 32))
    for _ in range(14):                # grãos claros
        put(r.randrange(n), r.randrange(n), (222, 128, 88))
    for _ in range(10):                # grãos escuros
        put(r.randrange(n), r.randrange(n), (100, 36, 32))
    for _ in range(3):                 # ondulação de areia
        x, y = r.randrange(n), r.randrange(n)
        for k in range(5):
            put(x + k, y + (k // 3), (180, 80, 56))
    return Image.fromarray(img).resize((48, 48), Image.NEAREST)

def ground_sheet():
    out = Image.new('RGBA', (192, 48))
    for i in range(4):
        out.paste(ground_tile(11 + i * 7), (i * 48, 0))
    return out

# ---------------- nave (24x30 lógico x3 = 72x90) ----------------
def ship():
    cv = Canvas(24, 30)
    body, ora, dark = ramp('#efd9b8'), ramp('#d9582c'), ramp('#6b3a30')
    for s in (-1, 1):   # aletas
        x = 12 + s * 6
        cv.paint(cv.poly_m([(x - s * 2, 14), (x + s * 5, 24), (x + s * 5, 28), (x - s * 2, 24)]), ora)
        cv.paint(cv.rect_m(x + s * 4 - (1 if s > 0 else 0), 22, x + s * 4 + (2 if s > 0 else 1), 28), dark)
    cv.paint(cv.rect_m(8, 11, 16, 25), body, spec=True)
    cv.paint(cv.ellipse_m(12, 9, 4, 8), body)
    cv.paint(cv.poly_m([(12, 0), (16, 8), (8, 8)]), ora)
    cv.paint(cv.ellipse_m(12, 14, 3, 3), ramp('#2a3a45'))
    cv.paint(cv.ellipse_m(12, 14, 2, 2), ramp('#58d8e8'), shade=False)
    cv.px(11, 13, (230, 255, 255))
    cv.paint(cv.rect_m(8, 19, 16, 21), ora, shade=False)
    cv.paint(cv.rect_m(9, 25, 15, 28), dark)
    cv.paint(cv.rect_m(10, 28, 14, 29), ramp('#2c1a1e'), shade=False)
    cv.outline(0.22)
    return cv.sheet_frame(3)

# ---------------- medkit (12x12 lógico x2) ----------------
def medkit():
    cv = Canvas(12, 12)
    cv.paint(cv.rect_m(1, 2, 11, 11), ramp('#f4ecd8'), spec=True)
    cv.paint(cv.rect_m(4, 0, 8, 2), ramp('#9aa0a8'))
    cv.paint(cv.rect_m(5, 3, 7, 10), ramp('#3fcf7a'), shade=False)
    cv.paint(cv.rect_m(3, 5, 9, 8), ramp('#3fcf7a'), shade=False)
    cv.outline(0.22)
    return cv.sheet_frame(2)

# ---------------- ícones de UI (16x16) ----------------
def icons():
    cvs = []
    def new(): return Canvas(16, 16)
    c = new()   # 0 vida
    c.paint(c.ellipse_m(5, 5.5, 3.6, 3.4), ramp('#ef5b4b'), shade=False); c.paint(c.ellipse_m(11, 5.5, 3.6, 3.4), ramp('#ef5b4b'), shade=False)
    c.paint(c.poly_m([(1.4, 6.5), (14.6, 6.5), (8, 14)]), ramp('#ef5b4b'), shade=False)
    c.px(4, 4, (255, 200, 190)); c.px(5, 3, (255, 200, 190)); cvs.append(c)
    c = new()   # 1 horda (caveira)
    c.paint(c.ellipse_m(8, 6.5, 5.5, 5), ramp('#f1e3c8')); c.paint(c.rect_m(5, 9, 11, 14), ramp('#e2d2b2'))
    for x in (5.5, 9.5): c.paint(c.rect_m(x, 6, x + 2, 9), ramp('#2a1418'), shade=False)
    c.px(8, 10, (60, 30, 30)); c.px(7, 12, (120, 90, 80)); c.px(9, 12, (120, 90, 80)); cvs.append(c)
    c = new()   # 2 reator
    c.paint(c.ellipse_m(8, 8, 6.5, 6.5), ramp('#d9582c')); c.paint(c.ellipse_m(8, 8, 4.2, 4.2), ramp('#2a3a45'))
    c.paint(c.ellipse_m(8, 8, 2.6, 2.6), ramp('#58f0f0'), shade=False); c.px(7, 7, (235, 255, 255)); cvs.append(c)
    c = new()   # 3 bateria
    c.paint(c.rect_m(3, 3, 13, 15), ramp('#5b6772')); c.paint(c.rect_m(6, 1, 10, 3), ramp('#c8ced4'))
    c.paint(c.poly_m([(9, 5), (5, 10), (8, 10), (7, 14), (11, 8), (8, 8)]), ramp('#ffd24a'), shade=False); cvs.append(c)
    c = new()   # 4 rádio
    c.paint(c.rect_m(2, 7, 14, 15), ramp('#8d6a4c')); c.paint(c.line_m([(10, 7), (13, 1)], 1), ramp('#c8ced4'), shade=False)
    c.paint(c.ellipse_m(6, 11, 2.6, 2.6), ramp('#2a3a45')); c.px(6, 11, (110, 240, 255)); c.paint(c.rect_m(10, 9, 13, 10), ramp('#f2c14e'), shade=False)
    c.paint(c.rect_m(10, 12, 13, 13), ramp('#f2c14e'), shade=False); cvs.append(c)
    c = new()   # 5 escotilha
    c.paint(c.ellipse_m(8, 8, 7, 7), ramp('#9aa2aa')); c.paint(c.ellipse_m(8, 8, 5, 5), ramp('#5b6670'))
    c.paint(c.line_m([(3, 8), (13, 8)], 1), ramp('#d9582c'), shade=False); c.paint(c.line_m([(8, 3), (8, 13)], 1), ramp('#d9582c'), shade=False)
    c.paint(c.ellipse_m(8, 8, 2, 2), ramp('#ffb347'), shade=False); cvs.append(c)
    c = new()   # 6 rolamento
    for a in range(0, 300, 18):
        x = 8 + 5.5 * math.cos(math.radians(a - 60)); y = 8 + 5.5 * math.sin(math.radians(a - 60))
        c.px(x, y, (255, 178, 110)); c.px(x + 1, y, (255, 178, 110))
    c.paint(c.poly_m([(10, 1), (15, 5), (9, 6)]), ramp('#ffd9a8'), shade=False); c.paint(c.ellipse_m(8, 8, 1.6, 1.6), ramp('#ffb347'), shade=False); cvs.append(c)
    c = new()   # 7 pulso EMP
    for r_, col in ((6.6, (88, 200, 255)), (4.4, (140, 230, 255))):
        for a in range(0, 360, 12):
            c.px(8 + r_ * math.cos(math.radians(a)), 8 + r_ * math.sin(math.radians(a)), col)
    c.paint(c.ellipse_m(8, 8, 1.8, 1.8), ramp('#e8ffff'), shade=False); cvs.append(c)
    c = new()   # 8 sobrecarga
    c.paint(c.poly_m([(10, 0), (3, 9), (7, 9), (5, 15), (13, 6), (9, 6)]), ramp('#ffb83a'), shade=False)
    c.px(8, 3, (255, 245, 200)); c.px(7, 5, (255, 245, 200)); cvs.append(c)
    for c in cvs: c.outline(0.25)
    return cvs

def icons_svg(cvs):
    rects = []
    for i, c in enumerate(cvs):
        a = c.img
        for y in range(16):
            x = 0
            while x < 16:
                if a[y, x, 3] > 0:
                    col = tuple(a[y, x, :3]); x2 = x
                    while x2 + 1 < 16 and a[y, x2 + 1, 3] > 0 and tuple(a[y, x2 + 1, :3]) == col: x2 += 1
                    rects.append('<rect x="%d" y="%d" width="%d" height="1" fill="#%02x%02x%02x"/>' % (i * 16 + x, y, x2 - x + 1, *col))
                    x = x2 + 1
                else:
                    x += 1
    return '<svg xmlns="http://www.w3.org/2000/svg" width="144" height="16" viewBox="0 0 144 16" shape-rendering="crispEdges">\n' + '\n'.join(rects) + '\n</svg>\n'

if __name__ == '__main__':
    prev = Image.new('RGBA', (900, 330), (70, 28, 26, 255))
    for k, f in enumerate((rifle, shotgun, ion)):
        prev.alpha_composite(weapon_sheet(f()), (k * 130, 0))
    prev.alpha_composite(laser().resize((128, 64)), (400, 20))
    g = ground_sheet(); prev.alpha_composite(g, (0, 130))
    prev.alpha_composite(ship(), (420, 100)); prev.alpha_composite(medkit(), (520, 100))
    ic = icons(); strip = Image.new('RGBA', (144, 16))
    for i, c in enumerate(ic): strip.alpha_composite(Image.fromarray(c.img), (i * 16, 0))
    prev.alpha_composite(strip.resize((144 * 4, 64), Image.NEAREST), (0, 200))
    # teste de emenda do chão 3x3
    t = Image.new('RGBA', (144, 144))
    for i in range(3):
        for j in range(3): t.paste(ground_tile(11), (i * 48, j * 48))
    prev.alpha_composite(t, (620, 130))
    prev.save('/tmp/world_new.png')
