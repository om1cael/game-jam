import os, shutil
from pix import *
import player, enemies, bosses, world
P = '/home/claude/proj/Sprites'
def save(img, rel): 
    os.makedirs(os.path.dirname(f'{P}/{rel}'), exist_ok=True); img.save(f'{P}/{rel}')

sh = player.player_sheets()
for name, im in sh.items(): save(im, f'Player/directions/{name}_walk.png')
down = sh['down']
for i in range(4): save(down.crop((i * 128, 0, i * 128 + 128, 120)), f'Player/walk/sprite_{i}.png')
for k in enemies.KINDS: save(enemies.enemy_sheet(k), f'Enemy/Variants/{k}_walk.png')
nf = enemies.enemy_sheet('normal')
for i in range(8): save(nf.crop(((i % 4) * 128, 0, (i % 4) * 128 + 128, 120)), f'Enemy/Walk/sprite_{i}.png')
for n in bosses.BOSSES: save(bosses.boss_sheet(n), f'Boss/{n}_walk.png')
r, s_, i_ = world.weapon_sheet(world.rifle()), world.weapon_sheet(world.shotgun()), world.weapon_sheet(world.ion())
save(r, 'Weapons/rifle.png'); save(s_, 'Weapons/shotgun.png'); save(i_, 'Weapons/ion_cannon.png'); save(r, 'Player/gun.png')
save(world.laser(), 'laser.png')
save(world.ground_sheet(), 'ground_tile_map.png')
save(world.ship(), 'ship.png'); save(world.medkit(), 'medkit.png')
open(f'{P}/UI/ui_icons.svg', 'w').write(world.icons_svg(world.icons()))
os.makedirs('/home/claude/proj/fonts', exist_ok=True)
for f in ('Poppins-Bold.ttf', 'Poppins-Medium.ttf'):
    shutil.copy(f'/usr/share/fonts/truetype/google-fonts/{f}', f'/home/claude/proj/fonts/{f}')
shutil.copy('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', '/home/claude/proj/fonts/DejaVuSansMono-Bold.ttf')
print('assets ok')
