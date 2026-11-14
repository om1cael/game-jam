extends Area2D

const BULLET_SCENE: PackedScene = preload("res://Scenes/bullet.tscn")
const OVERDRIVE_INTERVAL_MULTIPLIER: float = 0.5
const MAX_ACTIVE_BULLETS: int = 80
const WEAPON_SPRITES: Array[Texture2D] = [
	preload("res://Sprites/Weapons/rifle.png"),
	preload("res://Sprites/Weapons/shotgun.png"),
	preload("res://Sprites/Weapons/ion_cannon.png")
]
const WEAPONS: Array[Dictionary] = [
	{
		"name": "RIFLE",
		"fire_interval": 0.18,
		"magazine": 10,
		"magazine_upgrade": 5,
		"reload": 1.4,
		"damage": 12,
		"heavy_bonus": 4,
		"speed": 800.0,
		"life": 1.8,
		"pellets": 1,
		"spread": 0.0,
		"color": Color(0.7, 0.96, 0.66)
	},
	{
		"name": "ESCOPETA",
		"fire_interval": 0.62,
		"magazine": 5,
		"magazine_upgrade": 2,
		"reload": 1.75,
		"damage": 7,
		"heavy_bonus": 2,
		"speed": 680.0,
		"life": 0.62,
		"pellets": 5,
		"spread": 0.17,
		"color": Color(1.0, 0.68, 0.34)
	},
	{
		"name": "CANHÃO IÔNICO",
		"fire_interval": 0.78,
		"magazine": 4,
		"magazine_upgrade": 1,
		"reload": 2.0,
		"damage": 34,
		"heavy_bonus": 8,
		"speed": 1080.0,
		"life": 1.8,
		"pellets": 1,
		"spread": 0.0,
		"color": Color(0.48, 0.84, 1.0)
	}
]

var weapon_index: int = 0
var cooldown: float = 0.0
var magazine_capacity: int = 10
var ammo_in_magazine: int = 10
var reload_timer: float = 0.0
var magazine_capacities: Array[int] = []
var ammo_by_weapon: Array[int] = []
var reload_by_weapon: Array[float] = []

func _ready() -> void:
	for index: int in range(WEAPONS.size()):
		var capacity: int = _magazine_for(index)
		magazine_capacities.append(capacity)
		ammo_by_weapon.append(capacity)
		reload_by_weapon.append(0.0)
	_sync_selected_weapon()
	call_deferred("_apply_weapon_sprite")

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	_process_weapon_selection()
	if reload_timer > 0.0:
		reload_timer = maxf(0.0, reload_timer - delta)
		reload_by_weapon[weapon_index] = reload_timer
		if reload_timer == 0.0:
			ammo_in_magazine = magazine_capacity
			ammo_by_weapon[weapon_index] = ammo_in_magazine
	if Input.is_action_just_pressed("reload"):
		start_reload()
	var player: Node = get_tree().get_first_node_in_group("player")
	if (
		player == null
		or bool(player.get("is_dead"))
		or not Input.is_action_pressed("shoot")
		or reload_timer > 0.0
	):
		return
	if ammo_in_magazine <= 0:
		start_reload()
		return
	if cooldown > 0.0 or get_tree().get_nodes_in_group("bullet").size() >= MAX_ACTIVE_BULLETS:
		return
	_fire_weapon(player)

func _process_weapon_selection() -> void:
	for index: int in range(WEAPONS.size()):
		if Input.is_action_just_pressed("weapon_%d" % (index + 1)):
			select_weapon(index)
			return

func select_weapon(index: int) -> void:
	if index < 0 or index >= WEAPONS.size() or index == weapon_index:
		return
	ammo_by_weapon[weapon_index] = ammo_in_magazine
	reload_by_weapon[weapon_index] = reload_timer
	weapon_index = index
	cooldown = 0.0
	_sync_selected_weapon()
	_apply_weapon_sprite()

func _fire_weapon(player: Node) -> void:
	var weapon: Dictionary = WEAPONS[weapon_index]
	var heavy_level: int = GameState.weapon_upgrade_level("heavy_rounds")
	var barrel_level: int = GameState.weapon_upgrade_level("long_barrel")
	var aim: Vector2 = get_global_mouse_position() - $BulletSpawnPos.global_position
	var available_slots: int = MAX_ACTIVE_BULLETS - get_tree().get_nodes_in_group("bullet").size()
	var pellet_count: int = mini(int(weapon["pellets"]), available_slots)
	for pellet_index: int in range(pellet_count):
		var pellet_offset: float = float(pellet_index) - float(pellet_count - 1) * 0.5
		var bullet: Area2D = BULLET_SCENE.instantiate() as Area2D
		bullet.process_mode = Node.PROCESS_MODE_PAUSABLE
		bullet.set("damage", int(weapon["damage"]) + heavy_level * int(weapon["heavy_bonus"]))
		bullet.set("speed", float(weapon["speed"]) * (1.0 + 0.25 * float(barrel_level)))
		bullet.set("lifetime", float(weapon["life"]))
		var bullet_sprite: Sprite2D = bullet.get_node("Sprite2D") as Sprite2D
		bullet_sprite.modulate = weapon["color"]
		if weapon_index == 2:
			bullet.scale = Vector2(1.55, 1.55)
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = $BulletSpawnPos.global_position
		bullet.call("set_direction", aim.rotated(pellet_offset * float(weapon["spread"])))
	ammo_in_magazine -= 1
	ammo_by_weapon[weapon_index] = ammo_in_magazine
	AudioManager.play_sfx("shot")
	var rate_multiplier: float = pow(1.0 / 1.18, float(GameState.weapon_upgrade_level("rapid_fire")))
	var fire_interval: float = float(weapon["fire_interval"]) * rate_multiplier
	if float(player.get("overdrive_timer")) > 0.0:
		fire_interval *= OVERDRIVE_INTERVAL_MULTIPLIER
	cooldown = maxf(0.055, fire_interval)
	if ammo_in_magazine == 0:
		start_reload()

func start_reload() -> void:
	if reload_timer > 0.0 or ammo_in_magazine >= magazine_capacity:
		return
	reload_timer = float(WEAPONS[weapon_index]["reload"])
	reload_by_weapon[weapon_index] = reload_timer

func refresh_upgrade_stats() -> void:
	for index: int in range(WEAPONS.size()):
		var old_capacity: int = magazine_capacities[index]
		var new_capacity: int = _magazine_for(index)
		magazine_capacities[index] = new_capacity
		ammo_by_weapon[index] = mini(
			new_capacity,
			ammo_by_weapon[index] + new_capacity - old_capacity
		)
	_sync_selected_weapon()

func get_weapon_display_name() -> String:
	return "%s  [%d]" % [str(WEAPONS[weapon_index]["name"]), weapon_index + 1]

func _apply_weapon_sprite() -> void:
	var weapon_sprite: Sprite2D = $Sprite2D
	weapon_sprite.texture = WEAPON_SPRITES[weapon_index]

func _magazine_for(index: int) -> int:
	var weapon: Dictionary = WEAPONS[index]
	var upgrade_level: int = GameState.weapon_upgrade_level("extended_magazine")
	return int(weapon["magazine"]) + upgrade_level * int(weapon["magazine_upgrade"])

func _sync_selected_weapon() -> void:
	magazine_capacity = magazine_capacities[weapon_index] if not magazine_capacities.is_empty() else _magazine_for(weapon_index)
	ammo_in_magazine = ammo_by_weapon[weapon_index] if not ammo_by_weapon.is_empty() else magazine_capacity
	reload_timer = reload_by_weapon[weapon_index] if not reload_by_weapon.is_empty() else 0.0
