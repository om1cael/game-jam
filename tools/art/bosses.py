import math
from pix import *

W, H, G = 64, 60, 54   # tela lógica (x2 = 128x120), chão em y=54
HOT = (255, 190, 110)

def pose(row, i):
    """row: 0 mover, 1 parado, 2 preparar, 3 atacar -> parâmetros de pose."""
    p = i / 4 * 2 * math.pi
    s = math.sin(p)
    if row == 0:
        return dict(p=p, bob=abs(s) * 2.5, raise_=0.0, glow=0.1, flash=0.0, lean=s * 1.5, step=1.0)
    if row == 1:
        return dict(p=p, bob=s * 1.2, raise_=0.0, glow=0.15 + 0.1 * s, flash=0.0, lean=0.0, step=0.0)
    if row == 2:
        k = (i + 1) / 4
        return dict(p=p, bob=-k * 1.0, raise_=k, glow=0.3 + 0.7 * k, flash=0.0, lean=-k * 2, step=0.0)
    k = [1.0, 0.65, 0.35, 0.12][i]
    return dict(p=p, bob=0.0, raise_=-k, glow=0.6 * k + 0.2, flash=k, lean=k * 3, step=0.0)

def guardian(P):          # robô-golem ciano
    cv = Canvas(W, H)
    s = math.sin(P['p']); st = P['step']
    body = ramp('#25b5a5'); dark = ramp('#17756f'); pl = ramp('#7fe3d2')
    by = G - 4 - P['bob']
    for side in (-1, 1):  # pernas
        sw = side * s * 3 * st
        cv.paint(cv.rect_m(32 + side * 9 - 5 + sw * 0.3, by - 14 - max(0, side * s) * 2 * st, 32 + side * 9 + 5 + sw * 0.3, by + 4), dark)
        cv.paint(cv.rect_m(32 + side * 9 - 6 + sw, by, 32 + side * 9 + 6 + sw, by + 5), ramp('#0f4a52'))
    cv.paint(cv.rect_m(20, by - 30, 44, by - 11), body, spec=True)      # tronco
    cv.paint(cv.rect_m(24, by - 27, 40, by - 14), ramp('#1a8f89'))
    core = mix((70, 240, 255), HOT, min(1, P['glow']))
    cv.paint(cv.ellipse_m(32, by - 21, 4.5, 4.5), ramp(core), spec=True)
    cv.paint(cv.rect_m(21, by - 12, 43, by - 8), dark)
    for side in (-1, 1):  # ombros e braços
        ang = (-P['raise_'] * 14) + (4 if P['raise_'] < 0 else 0)
        ax = 32 + side * 17 + P['lean'] * 0.3
        ay = by - 28 + (-P['raise_'] * -8)
        cv.paint(cv.ellipse_m(ax, ay, 7, 6), pl, spec=True)
        hand_y = ay + 10 - P['raise_'] * 17
        cv.paint(cv.rect_m(ax - 3.5, ay + 2, ax + 3.5, hand_y), body)
        cv.paint(cv.ellipse_m(ax, hand_y + 2, 5, 4.5), dark)
    cv.paint(cv.rect_m(25, by - 41, 39, by - 29), pl, spec=True)       # cabeça
    cv.paint(cv.rect_m(27, by - 37, 37, by - 33), ramp(mix((255, 90, 70), (255, 235, 150), P['glow'])), shade=False)
    cv.px(32, by - 44, (255, 240, 180)); cv.paint(cv.rect_m(31, by - 46, 33, by - 41), dark, shade=False)
    return cv

def predator(P):          # fera quadrúpede laranja (perfil, olhando à direita)
    cv = Canvas(W, H)
    s = math.sin(P['p']); st = P['step']
    body = ramp('#e8552b'); belly = ramp('#f6a45a'); dark = ramp('#7a2a22'); sp = ramp('#ffd27a')
    lx = P['lean'] * 0.7 + 1
    by = G - 14 - P['bob'] + (P['raise_'] * 3)
    for k, (x, ph) in enumerate([(18, 0), (24, math.pi), (40, math.pi), (46, 0)]):
        sw = math.sin(P['p'] + ph) * 4 * st
        lift = max(0, math.cos(P['p'] + ph)) * 4 * st
        back = k in (0, 1)
        cv.paint(cv.line_m([(x + lx * 0.5, by + 6), (x + sw * 0.6 + lx * 0.5, by + 10), (x + sw + lx * 0.5, G - lift)], 3), dark if back else ramp('#a23428'), shade=False)
    cv.paint(cv.poly_m([(10 + lx, by - 4), (24 + lx, by - 12), (42 + lx, by - 11), (47 + lx, by - 2), (42 + lx, by + 8), (22 + lx, by + 9), (10 + lx, by + 4)]), body, spec=True)
    cv.paint(cv.ellipse_m(32 + lx, by + 5, 14, 3.5), belly, shade=False)
    for k in range(5):  # espinhos
        x = 18 + k * 6 + lx
        cv.paint(cv.poly_m([(x - 2, by - 10 - k % 2), (x + 2, by - 10 - k % 2), (x + 0.5, by - 17 - (k % 2) * 2)]), sp, shade=False)
    cv.paint(cv.poly_m([(10 + lx, by - 2), (2 + lx, by - 9 - P['raise_'] * 3), (5 + lx, by + 2)]), dark, shade=False)   # cauda
    open_ = 3 + max(0, P['raise_']) * 6 + max(0, P['flash']) * 6
    hx = 46 + lx + P['flash'] * 2
    cv.paint(cv.ellipse_m(hx, by - 3, 8, 7), body, spec=True)
    cv.paint(cv.poly_m([(hx + 2, by - 1), (hx + 14, by + 1 - open_ * 0.2), (hx + 12, by + 3), (hx + 2, by + 3)]), ramp('#f08a3a'))
    cv.paint(cv.poly_m([(hx + 2, by + 3), (hx + 12, by + 4 + open_ * 0.6), (hx + 9, by + 7 + open_ * 0.6), (hx + 1, by + 6)]), ramp('#c63a26'))
    for tx in (hx + 6, hx + 10):
        cv.paint(cv.poly_m([(tx - 1, by + 3), (tx + 1, by + 3), (tx, by + 5 + open_ * 0.2)]), ramp('#fff3d6'), shade=False)
    cv.paint(cv.rect_m(hx + 1, by - 6, hx + 5, by - 3), ramp(mix((255, 235, 120), (255, 255, 255), P['flash'])), shade=False)
    return cv

def colossus(P):          # mech de bronze, largo e pesado
    cv = Canvas(W, H)
    s = math.sin(P['p']); st = P['step']
    body = ramp('#c98a4c'); dark = ramp('#7a4a28'); pl = ramp('#e8b878'); steel = ramp('#59616b')
    by = G - 3 - P['bob']
    for side in (-1, 1):
        sw = side * s * 3 * st
        cv.paint(cv.rect_m(32 + side * 11 - 7 + sw, by - 12, 32 + side * 11 + 7 + sw, by + 3), dark)
        cv.paint(cv.rect_m(32 + side * 11 - 8 + sw, by + 1, 32 + side * 11 + 8 + sw, by + 5), steel)
    cv.paint(cv.ellipse_m(32, by - 22, 22, 15), body, spec=True)
    cv.paint(cv.rect_m(16, by - 26, 48, by - 14), pl)
    cv.paint(cv.rect_m(20, by - 20, 44, by - 16), dark)
    glow = mix((255, 200, 90), (255, 255, 230), P['flash'])
    cv.paint(cv.rect_m(25, by - 26, 39, by - 22), ramp(glow), shade=False)
    for rx_ in (19, 45):
        cv.px(rx_, by - 24, (60, 30, 18)); cv.px(rx_, by - 17, (60, 30, 18))
    for side in (-1, 1):
        ay = by - 30 + P['raise_'] * -6
        ax = 32 + side * 24 + P['lean'] * 0.4
        cv.paint(cv.ellipse_m(ax, ay, 8, 6), pl, spec=True)
        hy = ay + 13 - P['raise_'] * 16
        cv.paint(cv.rect_m(ax - 4, ay + 3, ax + 4, hy), body)
        cv.paint(cv.rect_m(ax - 7, hy, ax + 7, hy + 10), steel, spec=True)
        cv.paint(cv.rect_m(ax - 5, hy + 2, ax + 5, hy + 5), dark, shade=False)
    cv.paint(cv.ellipse_m(32, by - 36, 7, 6), steel, spec=True)
    cv.paint(cv.rect_m(27, by - 37, 37, by - 34), ramp(mix((255, 110, 60), (255, 240, 180), P['glow'])), shade=False)
    return cv

def commander(P):         # cristal roxo flutuante com drones
    cv = Canvas(W, H)
    p = P['p']; fl = P['bob'] + math.sin(p) * 2
    cy = 28 - fl - P['raise_'] * 3
    cry = ramp('#7d4fd0'); lt = ramp('#b48cf2'); core = mix((90, 250, 235), HOT, min(1, P['glow']))
    spread = 1.0 + P['raise_'] * 0.5 + (-P['flash']) * 0.3
    for k in range(4):
        a = p * 0.5 + k * math.pi / 2
        ox = math.cos(a) * 22 * spread; oy = math.sin(a) * 6 * spread
        cv.paint(cv.ellipse_m(32 + ox, cy + oy - 2, 4.5, 4.5), ramp('#3f2a7a'), spec=True)
        cv.paint(cv.ellipse_m(32 + ox, cy + oy - 2, 2, 2), ramp(mix((120, 255, 240), HOT, P['glow'])), shade=False)
    cv.paint(cv.poly_m([(32, cy - 24), (44, cy - 4), (32, cy + 18), (20, cy - 4)]), cry, spec=True)
    cv.paint(cv.poly_m([(32, cy - 24), (38, cy - 12), (32, cy - 2), (26, cy - 12)]), lt, shade=False)
    cv.paint(cv.poly_m([(32, cy - 12), (37, cy - 4), (32, cy + 6), (27, cy - 4)]), ramp(core), shade=False)
    cv.paint(cv.poly_m([(26, cy + 14), (38, cy + 14), (32, cy + 24)]), ramp('#4b2f94'), shade=False)
    cv.shadow(32, G + 1, 12 - fl * 0.3, 3, 100)
    return cv

def entity(P):            # entidade azul alada
    cv = Canvas(W, H)
    p = P['p']; fl = P['bob'] * 0.6 + math.sin(p) * 2
    cy = 28 - fl
    wing = ramp('#2f7fe0'); wl = ramp('#8fd0ff'); core = ramp(mix((120, 255, 255), HOT, P['glow']))
    flap = math.sin(p) * 6 + P['raise_'] * 10 - P['flash'] * 4
    for side in (-1, 1):
        pts = [(32 + side * 6, cy - 4),
               (32 + side * 28, cy - 22 - flap), (32 + side * 24, cy - 6 - flap * 0.5),
               (32 + side * 31, cy + 2 - flap * 0.3), (32 + side * 20, cy + 6),
               (32 + side * 24, cy + 16), (32 + side * 8, cy + 10)]
        cv.paint(cv.poly_m(pts), wing, spec=True)
        cv.paint(cv.poly_m([(32 + side * 8, cy - 2), (32 + side * 22, cy - 15 - flap * 0.8), (32 + side * 18, cy - 3), (32 + side * 9, cy + 3)]), wl, shade=False)
    cv.paint(cv.poly_m([(32, cy - 18), (40, cy - 4), (32, cy + 14), (24, cy - 4)]), ramp('#1f56b8'), spec=True)
    cv.paint(cv.poly_m([(32, cy - 10), (36, cy - 3), (32, cy + 5), (28, cy - 3)]), core, shade=False)
    cv.paint(cv.ellipse_m(32, cy - 24, 4, 1.5), ramp('#d8f4ff'), shade=False)
    cv.shadow(32, G + 1, 13 - fl * 0.3, 3, 100)
    return cv

BOSSES = {'guardian': guardian, 'predator': predator, 'colossus': colossus, 'commander': commander, 'entity': entity}
AURA = {'guardian': (90, 240, 220), 'predator': (255, 120, 60), 'colossus': (255, 200, 110), 'commander': (180, 120, 255), 'entity': (110, 190, 255)}

def boss_sheet(name):
    fn = BOSSES[name]
    out = Image.new('RGBA', (512, 480), (0, 0, 0, 0))
    for row in range(4):
        for i in range(4):
            P = pose(row, i)
            cv = fn(P)
            cv.outline(0.22)
            if name not in ('commander', 'entity'):
                cv.shadow(32, G + 1, 17, 3.2, 115)
            if P['glow'] > 0.45 and row >= 2:
                aura(cv, 32, 28, 0, AURA[name], 0.35 + 0.4 * P['glow'])
            if P['flash'] > 0.0:
                tint(cv, (255, 244, 224), 0.28 * P['flash'])
            out.alpha_composite(cv.sheet_frame(2), (i * 128, row * 120))
    return out

if __name__ == '__main__':
    prev = Image.new('RGBA', (512 * 3, 480 * 2), (70, 28, 26, 255))
    for k, n in enumerate(BOSSES):
        prev.alpha_composite(boss_sheet(n), ((k % 3) * 512, (k // 3) * 480))
    prev.save('/tmp/bosses_new.png')
