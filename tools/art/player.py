import math
from pix import *

SUIT = ramp('#e0662f')
SUIT_D = ramp('#b84a24')
HELM = ramp('#f1e3c8')
VISOR = ramp('#2fb4c4')
PACK = ramp('#7d7f86')
BOOT = ramp('#3e3b47')
GLOVE = ramp('#d9cdb4')
PANEL = ramp('#3fd0d6')

def ell(cv, cx, cy, cz, rx, ry, rz, th):
    c, s = math.cos(th), math.sin(th)
    x = cx * c + cz * s
    depth = -cx * s + cz * c
    w = math.sqrt((rx * c) ** 2 + (rz * s) ** 2)
    return x, cy, depth, max(w, 0.8), ry

def draw_player(view_deg, phase, base=27, ox=16):
    th = math.radians(view_deg)
    cv = Canvas()
    s = math.sin(phase)
    bob = -abs(s) * 0.9
    parts = []
    def add(col, cx, cy, cz, rx, ry, rz, spec=False):
        cy *= 0.84; ry *= 0.86
        x, y, d, w, h = ell(cv, cx, cy, cz, rx, ry, rz, th)
        parts.append((d, col, ox + x, base + y + bob * (1 if cy < -8 else 0), w, h, spec))
    for i in (-1, 1):                               # pernas
        sw = i * 3.0 * s
        lift = max(0.0, -i * math.cos(phase)) * 1.2 if abs(s) > 0.02 or True else 0
        add(SUIT_D, i * 2.5, -5.2 - lift * 0.5, sw, 2.2, 4.6, 2.2)
        add(BOOT, i * 2.5, -1.4 - lift, sw + 0.8, 2.5, 1.7, 3.0)
    for i in (-1, 1):                               # braços
        sw = -i * 2.8 * s
        add(SUIT, i * 6.6, -13.8, sw, 1.9, 4.4, 1.9)
        add(GLOVE, i * 6.6, -9.4, sw, 2.0, 1.9, 2.0)
    add(PACK, 0, -14.2, -4.8, 4.2, 5.2, 2.3)       # mochila
    add(PANEL, 2.0, -17.5, -6.6, 0.9, 1.1, 0.5)
    add(SUIT, 0, -13.5, 0, 5.5, 6.3, 3.9, True)    # torso
    add(PANEL, 0, -14.6, 3.7, 2.1, 1.7, 0.6)       # painel do peito
    add(ramp('#f6efe0'), 0, -17.6, 0, 4.4, 1.1, 3.8)  # gola
    add(HELM, 0, -22.2, 0, 5.8, 5.4, 5.3, True)    # capacete
    add(VISOR, 0, -21.9, 3.2, 4.1, 3.0, 2.5)       # visor
    add(ramp('#ffb347'), 5.3, -22.6, 0.5, 1.1, 1.1, 1.1)  # lanterna
    for d, col, x, y, w, h, spec in sorted(parts, key=lambda p: p[0]):
        cv.paint(cv.ellipse_m(x, y, w, h), col, spec=spec)
    # brilho do visor
    if True:
        for d, col, x, y, w, h, spec in parts:
            if col is VISOR and d > 0.6:
                cv.px(x - w * 0.45, y - h * 0.45, (226, 252, 255))
                cv.px(x - w * 0.45 + 1, y - h * 0.45, (170, 236, 244))
    cv.outline(0.22)
    cv.shadow(ox, base + 0.6, 8.5, 2.6)
    return cv

VIEWS = {  # ângulo de visão (frente=0; esquerda=-90; costas=180)
    'down': 0, 'down_left': -45, 'left': -90, 'up_left': -135, 'up': 180,
    'up_right': 135, 'right': 90, 'down_right': 45,
}

def player_sheets():
    out = {}
    for name, deg in VIEWS.items():
        frames = [draw_player(deg, i / 4 * 2 * math.pi + math.pi / 2).sheet_frame(4) for i in range(4)]
        out[name] = sheet(frames, 4, 4, 128, 120)
    return out

if __name__ == '__main__':
    sh = player_sheets()
    prev = Image.new('RGBA', (512, 120 * 8), (70, 28, 26, 255))
    for k, n in enumerate(VIEWS):
        prev.alpha_composite(sh[n], (0, k * 120))
    prev.save('/tmp/player_new.png')
