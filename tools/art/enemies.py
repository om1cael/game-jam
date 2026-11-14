import math
from pix import *

def legs(cv, hip_y, spread, length, thick, phase, col, pairs=3, step=2.0, out=1.0):
    """pernas articuladas (2 segmentos) para ambos os lados; pés no chão em y=26."""
    dark = ramp(mix(hexc(col), (255, 255, 255), 0.2))
    for side in (-1, 1):
        for k in range(pairs):
            t = (k + 0.5) / pairs
            hy = hip_y + (t - 0.5) * 5
            ph = phase + k * 1.9 + (0 if side > 0 else math.pi)
            lift = max(0.0, math.sin(ph)) * 3.4
            fx = 16 + side * (spread + length * (0.55 + 0.35 * t) + math.cos(ph) * step * 1.0)
            fy = 26 - lift - (1 - t) * 1.5
            kx = 16 + side * (spread + length * 0.45 + 1.5)
            ky = hy - 2.5 - lift * 0.3
            m = cv.line_m([(16 + side * spread * 0.6, hy), (kx, ky), (fx, fy)], thick)
            cv.paint(m, dark, shade=False)
            cv.px(fx, fy, dark[0])

def eyes(cv, pos, col, glow=False):
    for (x, y) in pos:
        cv.px(x, y, col); cv.px(x + 1, y, col)
        cv.px(x, y + 1, mix(col, (0, 0, 0), 0.5)); cv.px(x + 1, y + 1, mix(col, (0, 0, 0), 0.5))

def base_body(cv, cx, cy, rx, ry, col, spec=True):
    cv.paint(cv.ellipse_m(cx, cy, rx, ry), col, spec=spec)

def finish(cv, bob=0):
    cv.outline(0.22)
    cv.shadow(16, 27.3, 9.5, 2.5, 115)
    return cv

def spikes(cv, pts, col):
    for (x, y, dx, dy) in pts:
        m = cv.poly_m([(x - 1, y), (x + 1, y), (x + dx, y + dy)])
        cv.paint(m, col, shade=False)

def draw_enemy(kind, phase):
    cv = Canvas()
    s = math.sin(phase); bob = abs(s) * 1.6
    by = 15 - bob
    if kind == 'normal':           # rastejante: carapaça laranja, mandíbulas
        legs(cv, by + 3, 6, 6, 2, phase, '#6b3a2a', pairs=2)
        base_body(cv, 16, by + 1, 8.5, 7, '#e07a3a')
        cv.paint(cv.ellipse_m(16, by - 1.5, 6, 4.2), ramp('#f3a65a'), spec=True)
        cv.paint(cv.rect_m(11, by + 3, 21, by + 5), ramp('#8d4a2c'), shade=False)
        cv.paint(cv.ellipse_m(16, by + 5.5, 4.8, 3.2), ramp('#5a2e22'))
        eyes(cv, [(12.5, by + 4), (17.5, by + 4)], (255, 232, 120))
        spikes(cv, [(11, by + 9, -1, 3), (21, by + 9, 1, 3)], ramp('#f5d9a8'))
    elif kind == 'armored':        # blindado: placas azul-aço, olhar laranja
        legs(cv, by + 4, 7, 5, 2, phase, '#2e4a63', pairs=3, step=1.4)
        base_body(cv, 16, by + 1, 10, 7.5, '#4f7aa0')
        for i in range(3):
            cv.paint(cv.rect_m(8 + i * 5, by - 5, 12 + i * 5, by + 3), ramp('#7fa6c8'), spec=False)
        cv.paint(cv.rect_m(10, by + 3, 22, by + 7), ramp('#2c3f55'))
        cv.paint(cv.rect_m(12, by + 4, 20, by + 6), ramp('#ff9a3c'), shade=False)
        cv.px(16, by + 5, (255, 240, 190))
    elif kind == 'aggressive':     # agressivo: vermelho espinhoso
        legs(cv, by + 3, 5, 9, 2, phase * 1.3, '#4a1418', pairs=2, step=3)
        spikes(cv, [(10, by - 4, -3, -6), (16, by - 6, 0, -7), (22, by - 4, 3, -6)], ramp('#ffd27a'))
        base_body(cv, 16, by + 1, 8, 6.5, '#d8362b')
        cv.paint(cv.ellipse_m(16, by - 1, 5.2, 3.5), ramp('#ff6a4a'), spec=True)
        cv.paint(cv.poly_m([(9, by + 5), (13, by + 4), (12, by + 10)]), ramp('#f6e3b0'), shade=False)
        cv.paint(cv.poly_m([(23, by + 5), (19, by + 4), (20, by + 10)]), ramp('#f6e3b0'), shade=False)
        eyes(cv, [(11.5, by + 1), (18.5, by + 1)], (255, 250, 160))
    elif kind == 'fast':           # veloz: esguio, verde, antenas
        legs(cv, by + 3, 4, 10, 1, phase * 1.5, '#2d5b2a', pairs=3, step=3.2)
        base_body(cv, 16, by + 2, 5.5, 8, '#79c04a')
        cv.paint(cv.ellipse_m(16, by - 2, 4, 5), ramp('#a8e36b'), spec=True)
        cv.paint(cv.rect_m(14, by + 4, 18, by + 8), ramp('#355f2c'))
        eyes(cv, [(13, by + 1), (17.5, by + 1)], (255, 80, 80))
        spikes(cv, [(13, by - 7, -3, -5), (19, by - 7, 3, -5)], ramp('#d6f08a'))
    elif kind == 'mutated':        # mutante: roxo, vários olhos, saco brilhante
        legs(cv, by + 3, 5, 8, 1, phase, '#4a2a6a', pairs=4, step=2.2)
        base_body(cv, 16, by + 1, 8.5, 7.5, '#8a52c2')
        cv.paint(cv.ellipse_m(16, by - 1, 5, 4.5), ramp('#ff7ad0'), spec=True)
        eyes(cv, [(10, by + 4), (13.5, by + 5.5), (18, by + 5.5), (21.5, by + 4)], (190, 255, 240))
        eyes(cv, [(15, by + 2)], (255, 240, 120))
        for (x, y) in [(9, by - 4), (22, by - 3)]:
            cv.paint(cv.ellipse_m(x, y, 2, 2), ramp('#ffb0f0'), shade=False)
    elif kind == 'elite':          # elite: casco escuro com crista dourada e núcleo ciano
        legs(cv, by + 3, 6, 7, 2, phase, '#1b3d4d', pairs=2, step=1.6)
        spikes(cv, [(12, by - 6, -2, -6), (16, by - 8, 0, -8), (20, by - 6, 2, -6)], ramp('#f2c14e'))
        base_body(cv, 16, by + 1, 9, 7.5, '#25596b')
        cv.paint(cv.ellipse_m(16, by - 0.5, 5.5, 4.5), ramp('#38e8e0'), spec=True)
        cv.paint(cv.rect_m(12, by + 3, 20, by + 6), ramp('#112a35'))
        eyes(cv, [(13, by + 4), (17.5, by + 4)], (255, 220, 90))
        ob = phase
        for k in range(2):
            a = ob + k * math.pi
            cv.paint(cv.ellipse_m(16 + math.cos(a) * 11.5, by - 5 + math.sin(a) * 2.5, 1.7, 1.7), ramp('#f2c14e'), shade=False)
    elif kind == 'spitter':        # cuspidor: oliva, bolsa ácida brilhante
        legs(cv, by + 3, 5, 6, 2, phase, '#3f4a22', pairs=3, step=1.8)
        base_body(cv, 16, by + 3, 7.5, 6, '#8a9a3a')
        cv.paint(cv.ellipse_m(16, by - 3.5, 6, 5.5), ramp('#6fe05a'), spec=True)
        cv.paint(cv.ellipse_m(16, by - 3.5, 3.2, 3), ramp('#c9ff7a'), shade=False)
        cv.paint(cv.ellipse_m(16, by + 6, 3.5, 2.5), ramp('#3a4420'))
        eyes(cv, [(12.5, by + 2.5), (17.5, by + 2.5)], (255, 255, 140))
        spikes(cv, [(11, by - 6, -2, -4), (21, by - 6, 2, -4)], ramp('#d9e58a'))
    elif kind == 'burrower':       # escavador: marrom, garras grandes
        legs(cv, by + 4, 4, 5, 2, phase, '#4b2b1c', pairs=2, step=1.4)
        base_body(cv, 16, by + 2, 8, 6.5, '#8b5a34')
        cv.paint(cv.ellipse_m(16, by, 5.3, 4.2), ramp('#b98552'), spec=True)
        for side in (-1, 1):
            cx = 16 + side * 10.5
            cv.paint(cv.poly_m([(cx - 2, by + 1), (cx + 2, by + 1), (cx + side * 1.5, by + 10), (cx - side * 2.5, by + 9)]), ramp('#d8b98a'))
        cv.paint(cv.poly_m([(14, by + 4), (18, by + 4), (16, by + 11)]), ramp('#e8e0cc'), shade=False)
        eyes(cv, [(12.5, by + 1.5), (17.5, by + 1.5)], (255, 150, 70))
        for (x, y) in [(6, 22), (27, 23), (9, 25), (24, 25)]:
            cv.px(x, y, (140, 70, 50))
    return finish(cv)

KINDS = ['normal', 'armored', 'aggressive', 'fast', 'mutated', 'elite', 'spitter', 'burrower']

def enemy_sheet(kind):
    frames = [draw_enemy(kind, i / 4 * 2 * math.pi).sheet_frame(4) for i in range(4)]
    return sheet(frames, 4, 4, 128, 120)

if __name__ == '__main__':
    prev = Image.new('RGBA', (512, 120 * 8), (70, 28, 26, 255))
    for k, n in enumerate(KINDS):
        prev.alpha_composite(enemy_sheet(n), (0, k * 120))
    prev.save('/tmp/enemies_new.png')
