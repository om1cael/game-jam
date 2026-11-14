extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://Scenes/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://Scenes/boss.tscn")
const MEDKIT_SCENE: PackedScene = preload("res://Scenes/medkit.tscn")
const SHIP_SCENE: PackedScene = preload("res://Scenes/ship.tscn")
const SHIP_ARROW_SCRIPT: Script = preload("res://Scripts/ship_arrow.gd")
const MARS_TERRAIN_SCRIPT: Script = preload("res://Scripts/mars_terrain.gd")
const UI_ICONS: Texture2D = preload("res://Sprites/UI/ui_icons.svg")
const UIStyle = preload("res://Scripts/ui_style.gd")
const PLAYER_PORTRAIT: Texture2D = preload("res://Sprites/Player/walk/sprite_0.png")
const ENEMY_PORTRAIT: Texture2D = preload("res://Sprites/Enemy/Walk/sprite_0.png")
const WEAPON_TEXTURES: Array[Texture2D] = [
	preload("res://Sprites/Weapons/rifle.png"),
	preload("res://Sprites/Weapons/shotgun.png"),
	preload("res://Sprites/Weapons/ion_cannon.png")
]
const CHUNK_SIZE: int = 12
const CHUNK_RADIUS: int = 2
const MEDKIT_DROP_CHANCE: float = 0.2
const MAX_ACTIVE_MEDKITS: int = 8
const PART_LABELS: Array[String] = [
	"REATOR",
	"BATERIA",
	"RÁDIO",
	"ESCOTILHA"
]

enum RunState { INTRO, WAVES, INTERMISSION, BOSS, REWARD, EXPLORE, GAME_OVER, VICTORY }

var run_state: int = RunState.INTRO
var player: CharacterBody2D
var arena_center: Vector2 = Vector2.ZERO
var ship_world_position: Vector2 = Vector2.ZERO
var ship: Node2D
var tile_layer: TileMapLayer
var terrain_layer: Node2D
var generated_chunks: Dictionary = {}
var current_chunk: Vector2i = Vector2i(2147483647, 2147483647)
var round_number: int = 1
var horde_count: int = 3
var wave_index: int = -1
var spawn_remaining: int = 0
var active_enemies: int = 0
var spawn_timer: float = 0.0
var toast_timer: float = 0.0
var active_boss: Node
var hud_layer: CanvasLayer
var hud_root: Control
var round_label: Label
var score_label: Label
var health_label: Label
var health_bar: ProgressBar
var wave_label: Label
var wave_icon: TextureRect
var player_status_panel: Panel
var cargo_panel: Panel
var weapon_panel: Panel
var player_portrait: TextureRect
var parts_label: Label
var part_icons: Array[TextureRect] = []
var current_weapon_icon: TextureRect
var weapon_slot_icons: Array[TextureRect] = []
var ability_icons: Array[TextureRect] = []
var dodge_label: Label
var emp_label: Label
var overdrive_label: Label
var ammo_label: Label
var ship_label: Label
var ship_arrow: Control
var boss_name_label: Label
var health_fill_style: StyleBoxFlat
var boss_health_bar: ProgressBar
var toast_label: Label
var overlay_layer: CanvasLayer
var overlay_body: Label
var overlay: ColorRect
var reward_upgrade_selected: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_node("Player") as CharacterBody2D
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena_center = player.global_position
	ship_world_position = arena_center + Vector2(0.0, -104.0)
	tile_layer = get_node("TileMapLayer") as TileMapLayer
	_setup_procedural_world()
	ship = SHIP_SCENE.instantiate() as Node2D
	ship.global_position = ship_world_position
	add_child(ship)
	player.connect("died", _on_player_died)
	for existing_enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if existing_enemy != player:
			existing_enemy.queue_free()
	_build_hud()
	AudioManager.play_game_music()
	round_number = clampi(GameState.current_round, 1, 5)
	if GameState.ship_parts.size() < round_number - 1:
		push_warning("Progresso inconsistente; a campanha será retomada na rodada compatível com as peças salvas.")
		round_number = GameState.ship_parts.size() + 1
		GameState.current_round = round_number
		GameState.save_data()
	if GameState.campaign_active and GameState.ship_parts.size() >= round_number and round_number < 5:
		round_number += 1
		_enter_exploration()
	else:
		_start_round()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_update_world_chunks()
	if run_state == RunState.WAVES:
		spawn_timer -= delta
		if spawn_remaining > 0 and active_enemies < _max_active_enemies() and spawn_timer <= 0.0:
			_spawn_enemy()
			spawn_remaining -= 1
			spawn_timer = maxf(0.3, 0.56 - float(round_number - 1) * 0.04)
		if spawn_remaining == 0 and active_enemies == 0:
			_complete_wave()
	if run_state == RunState.EXPLORE:
		var distance_to_ship: float = player.global_position.distance_to(ship_world_position)
		ship_label.visible = get_viewport_rect().size.x >= 640.0
		if distance_to_ship <= 120.0:
			ship_label.text = "NAVE  ·  E"
		else:
			ship_label.text = "SIGA A SETA"
	else:
		ship_label.visible = false
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.visible = false
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not (event is InputEventKey and event.echo):
		if run_state == RunState.EXPLORE and player.global_position.distance_to(ship_world_position) <= 120.0:
			_launch_next_round()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if run_state == RunState.GAME_OVER or run_state == RunState.VICTORY or run_state == RunState.REWARD:
			return
		if get_tree().paused:
			_resume_game()
		else:
			_show_pause_menu()

func _start_round() -> void:
	if round_number > 5:
		return
	GameState.current_round = round_number
	GameState.campaign_active = true
	GameState.save_data()
	run_state = RunState.INTERMISSION
	wave_index = -1
	horde_count = round_number + 2
	_show_toast("RODADA %d / 5" % round_number, 2.0)
	await get_tree().create_timer(1.6, false).timeout
	if run_state == RunState.INTERMISSION:
		_begin_wave()

func _begin_wave() -> void:
	wave_index += 1
	run_state = RunState.WAVES
	var base_spawn_count: int = round_number + wave_index + 3
	var difficulty: Dictionary = GameState.get_difficulty_config()
	spawn_remaining = maxi(1, roundi(base_spawn_count * float(difficulty["spawn_pressure"])))
	spawn_timer = 0.2
	_show_toast("HORDA %d / %d" % [wave_index + 1, horde_count], 2.0)

func _complete_wave() -> void:
	if run_state != RunState.WAVES:
		return
	run_state = RunState.INTERMISSION
	if wave_index < horde_count - 1:
		_show_toast("HORDA ELIMINADA", 1.7)
		await get_tree().create_timer(1.35, false).timeout
		if run_state == RunState.INTERMISSION:
			_begin_wave()
	else:
		_show_toast("SETOR LIMPO", 1.8)
		await get_tree().create_timer(1.55, false).timeout
		if run_state == RunState.INTERMISSION:
			_start_boss()

func _start_boss() -> void:
	run_state = RunState.BOSS
	_show_toast("CHEFE DETECTADO", 2.0)
	var boss: CharacterBody2D = BOSS_SCENE.instantiate() as CharacterBody2D
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	boss.global_position = _random_offscreen_position(170.0)
	boss.connect("health_changed", _on_boss_health_changed)
	boss.connect("defeated", _on_boss_defeated)
	boss.call("configure", round_number)
	active_boss = boss
	add_child(boss)
	boss_name_label.text = "CHEFE: %s | FASE %d" % [boss.get("boss_name"), boss.get("phase")]
	boss_health_bar.max_value = float(boss.get("maximum_health"))
	boss_health_bar.value = float(boss.get("health"))
	boss_name_label.visible = true
	boss_health_bar.visible = true

func _spawn_enemy() -> void:
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate() as CharacterBody2D
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.global_position = _random_offscreen_position(110.0)
	enemy.connect("defeated", _on_enemy_defeated)
	add_child(enemy)
	enemy.call("configure_variant", _choose_variant(), round_number)
	active_enemies += 1

func _max_active_enemies() -> int:
	var difficulty: Dictionary = GameState.get_difficulty_config()
	var base_limit: int = 5 + floori(float(round_number - 1) / 2.0)
	return maxi(3, roundi(base_limit * float(difficulty["spawn_pressure"])))

func _random_offscreen_position(margin: float) -> Vector2:
	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	var zoom: Vector2 = camera.zoom
	var half_view: Vector2 = get_viewport_rect().size * 0.5 / zoom
	var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var distance_to_horizontal_edge: float = half_view.x / maxf(absf(direction.x), 0.001)
	var distance_to_vertical_edge: float = half_view.y / maxf(absf(direction.y), 0.001)
	var distance_to_edge: float = minf(distance_to_horizontal_edge, distance_to_vertical_edge)
	var edge_component: float = absf(direction.x) if distance_to_horizontal_edge < distance_to_vertical_edge else absf(direction.y)
	return camera.global_position + direction * (distance_to_edge + margin / maxf(edge_component, 0.1))

func _setup_procedural_world() -> void:
	tile_layer.clear()
	tile_layer.modulate = Color.WHITE
	terrain_layer = Node2D.new()
	terrain_layer.name = "MarsTerrain"
	terrain_layer.set_script(MARS_TERRAIN_SCRIPT)
	terrain_layer.z_index = 0
	add_child(terrain_layer)
	move_child(terrain_layer, 1)
	_update_world_chunks()

func _update_world_chunks() -> void:
	var cell: Vector2i = tile_layer.local_to_map(tile_layer.to_local(player.global_position))
	var player_chunk: Vector2i = Vector2i(
		floori(float(cell.x) / CHUNK_SIZE),
		floori(float(cell.y) / CHUNK_SIZE)
	)
	if player_chunk == current_chunk:
		return
	current_chunk = player_chunk
	for y_offset: int in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for x_offset: int in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			var chunk: Vector2i = player_chunk + Vector2i(x_offset, y_offset)
			if not generated_chunks.has(chunk):
				_generate_chunk(chunk)
	for chunk_variant: Variant in generated_chunks.keys():
		var chunk: Vector2i = chunk_variant
		if absi(chunk.x - player_chunk.x) > CHUNK_RADIUS or absi(chunk.y - player_chunk.y) > CHUNK_RADIUS:
			_erase_chunk(chunk)

func _generate_chunk(chunk: Vector2i) -> void:
	for y_offset: int in CHUNK_SIZE:
		for x_offset: int in CHUNK_SIZE:
			var cell: Vector2i = chunk * CHUNK_SIZE + Vector2i(x_offset, y_offset)
			var tile_variant: int = absi((cell.x * 73856093) ^ (cell.y * 19349663)) % 4
			tile_layer.set_cell(cell, 0, Vector2i(tile_variant, 0))
	var cell_size: Vector2 = Vector2(tile_layer.tile_set.tile_size)
	var chunk_origin: Vector2 = tile_layer.map_to_local(chunk * CHUNK_SIZE) - cell_size * 0.5
	var world_origin: Vector2 = to_local(tile_layer.to_global(chunk_origin))
	terrain_layer.call("generate_chunk", chunk, world_origin, float(CHUNK_SIZE) * cell_size.x)
	generated_chunks[chunk] = true

func _erase_chunk(chunk: Vector2i) -> void:
	for y_offset: int in CHUNK_SIZE:
		for x_offset: int in CHUNK_SIZE:
			var cell: Vector2i = chunk * CHUNK_SIZE + Vector2i(x_offset, y_offset)
			tile_layer.erase_cell(cell)
	terrain_layer.call("erase_chunk", chunk)
	generated_chunks.erase(chunk)

func _choose_variant() -> String:
	var roll: float = randf()
	if round_number == 1:
		return "NORMAL"
	if round_number == 2:
		if roll < 0.12:
			return "BURROWER"
		return "ARMORED" if roll < 0.3 else "NORMAL"
	if round_number == 3:
		if roll < 0.14:
			return "SPITTER"
		if roll < 0.25:
			return "BURROWER"
		if roll < 0.4:
			return "AGGRESSIVE"
		return "ARMORED" if roll < 0.58 else "NORMAL"
	if round_number == 4:
		if roll < 0.12:
			return "SPITTER"
		if roll < 0.24:
			return "BURROWER"
		if roll < 0.38:
			return "FAST"
		if roll < 0.5:
			return "MUTATED"
		if roll < 0.65:
			return "AGGRESSIVE"
		if roll < 0.82:
			return "ARMORED"
		return "NORMAL"
	if roll < 0.1:
		return "SPITTER"
	if roll < 0.2:
		return "BURROWER"
	if roll < 0.32:
		return "ELITE"
	if roll < 0.44:
		return "MUTATED"
	if roll < 0.56:
		return "FAST"
	if roll < 0.68:
		return "AGGRESSIVE"
	if roll < 0.82:
		return "ARMORED"
	return "NORMAL"

func _on_enemy_defeated(_enemy: Node2D, variant: String, points: int) -> void:
	active_enemies = maxi(0, active_enemies - 1)
	GameState.add_score(points)
	if randf() < MEDKIT_DROP_CHANCE and get_tree().get_nodes_in_group("pickup").size() < MAX_ACTIVE_MEDKITS:
		var medkit: Area2D = MEDKIT_SCENE.instantiate() as Area2D
		medkit.process_mode = Node.PROCESS_MODE_PAUSABLE
		medkit.global_position = _enemy.global_position
		add_child(medkit)
	GameState.save_data()
	_show_toast("+%d  ·  %s" % [points, variant], 1.3)
	_update_hud()

func _on_boss_health_changed(current_health: float, maximum_health: float) -> void:
	boss_health_bar.max_value = maximum_health
	boss_health_bar.value = current_health

func _on_boss_defeated(_name: String, points: int) -> void:
	if run_state != RunState.BOSS:
		return
	active_boss = null
	active_enemies = 0
	boss_health_bar.visible = false
	boss_name_label.visible = false
	_clear_hostile_projectiles()
	GameState.add_score(points + 500)
	GameState.save_data()
	if round_number <= 4:
		var part: String = GameState.claim_component(round_number)
		GameState.current_round = round_number
		GameState.save_data()
		_show_reward(part)
	else:
		if GameState.ship_parts.size() != GameState.PART_NAMES.size():
			push_error("A campanha não pode terminar: faltam componentes da nave.")
			_show_overlay("PEÇAS PENDENTES", "%d / 4" % GameState.ship_parts.size(), [
				{"text": "VOLTAR AO MENU", "action": _return_to_menu}
			])
			return
		_finish_campaign()

func _show_reward(part: String) -> void:
	run_state = RunState.REWARD
	reward_upgrade_selected = false
	get_tree().paused = true
	player.call("heal", 1)
	var piece_label: String = part if not part.is_empty() else "COMPONENTE JÁ REGISTRADO"
	var rapid_level: int = GameState.weapon_upgrade_level("rapid_fire") + 1
	var heavy_level: int = GameState.weapon_upgrade_level("heavy_rounds") + 1
	var barrel_level: int = GameState.weapon_upgrade_level("long_barrel") + 1
	var magazine_level: int = GameState.weapon_upgrade_level("extended_magazine") + 1
	var upgrade_choices: Array[Dictionary] = [
		{
			"id": "rapid_fire",
			"text": "CADÊNCIA  +18%  ·  NV %d" % rapid_level
		},
		{
			"id": "heavy_rounds",
			"text": "DANO  +4  ·  NV %d" % heavy_level
		},
		{
			"id": "long_barrel",
			"text": "VELOCIDADE  +25%  ·  NV %d" % barrel_level
		},
		{
			"id": "extended_magazine",
			"text": "MUNIÇÃO  +  ·  NV %d" % magazine_level
		}
	]
	var buttons: Array[Dictionary] = []
	for choice: Dictionary in upgrade_choices:
		buttons.append({
			"text": choice["text"],
			"action": _select_weapon_upgrade.bind(str(choice["id"]), part)
		})
	var choice_body: String = "%s  ·  %d / 4 PEÇAS\nPONTOS  %06d"
	_show_overlay(
		"ESCOLHA UMA MELHORIA",
		choice_body % [
			piece_label,
			GameState.ship_parts.size(),
			GameState.score
		],
		buttons
	)
	GameState.save_data()

func _select_weapon_upgrade(upgrade_id: String, part: String) -> void:
	if run_state != RunState.REWARD or reward_upgrade_selected:
		return
	if not GameState.apply_weapon_upgrade(upgrade_id):
		return
	reward_upgrade_selected = true
	player.call("refresh_weapon_appearance")
	var gun: Node = player.get_node_or_null("GunPivot/Gun")
	if gun != null:
		gun.call("refresh_upgrade_stats")
	_show_reward_summary(part, upgrade_id)

func _show_reward_summary(part: String, upgrade_id: String) -> void:
	var upgrade_names: Dictionary = {
		"rapid_fire": "CADÊNCIA",
		"heavy_rounds": "DANO",
		"long_barrel": "VELOCIDADE",
		"extended_magazine": "MUNIÇÃO"
	}
	var piece_label: String = part if not part.is_empty() else "COMPONENTE JÁ REGISTRADO"
	var reward_body: String = (
		"%s  ·  NV %d\n%s  ·  %d / 4 PEÇAS\nPONTOS  %06d"
	)
	_show_overlay(
		"ARMA MELHORADA",
		reward_body % [
			upgrade_names[upgrade_id],
			GameState.weapon_upgrade_level(upgrade_id),
			piece_label,
			GameState.ship_parts.size(),
			GameState.score
		],
		[
			{"text": "CONTINUAR", "action": _continue_exploring},
			{"text": "MENU", "action": _return_to_menu}
		]
	)
	GameState.save_data()

func _continue_exploring() -> void:
	if run_state != RunState.REWARD:
		return
	get_tree().paused = false
	round_number = mini(GameState.ship_parts.size() + 1, 5)
	GameState.current_round = round_number - 1
	GameState.save_data()
	run_state = RunState.EXPLORE
	_remove_overlay()
	_show_toast("ÁREA SEGURA  ·  SIGA A SETA", 4.0)

func _enter_exploration() -> void:
	run_state = RunState.EXPLORE
	horde_count = round_number + 2
	spawn_remaining = 0
	active_enemies = 0
	_clear_hostile_projectiles()
	ship_label.visible = true
	_show_toast("SETOR CONCLUÍDO  ·  SIGA A SETA", 4.0)

func _launch_next_round() -> void:
	if run_state != RunState.EXPLORE:
		return
	round_number = mini(GameState.ship_parts.size() + 1, 5)
	GameState.current_round = round_number
	GameState.save_data()
	ship_label.visible = false
	ship_arrow.visible = false
	_start_round()

func _finish_campaign() -> void:
	run_state = RunState.VICTORY
	_clear_hostile_projectiles()
	get_tree().paused = true
	GameState.add_score(2500)
	GameState.campaign_active = false
	GameState.current_round = 5
	GameState.save_data()
	_show_overlay("NAVE RECONSTRUÍDA", "SISTEMAS  ·  ONLINE", [])
	await get_tree().create_timer(1.0, true).timeout
	if run_state != RunState.VICTORY:
		return
	overlay_body.text = "DECOLAGEM"
	await get_tree().create_timer(1.2, true).timeout
	if run_state != RunState.VICTORY:
		return
	_show_victory()

func _show_victory() -> void:
	_show_overlay("FUGA CONCLUÍDA", "%06d  ·  RECORDE %06d" % [GameState.score, GameState.high_score], [
		{"text": "NOVA CAMPANHA", "action": _restart_campaign},
		{"text": "MENU", "action": _return_to_menu}
	])

func _on_player_died() -> void:
	if run_state == RunState.GAME_OVER:
		return
	run_state = RunState.GAME_OVER
	AudioManager.play_death_music()
	spawn_remaining = 0
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	_clear_hostile_projectiles()
	GameState.save_data()
	_show_overlay("SINAL PERDIDO", "%06d PONTOS  ·  SETOR %d/5" % [GameState.score, round_number], [
		{"text": "TENTAR DE NOVO", "action": _restart_campaign},
		{"text": "MENU", "action": _return_to_menu}
	])

func _show_pause_menu() -> void:
	if run_state == RunState.GAME_OVER or run_state == RunState.VICTORY:
		return
	get_tree().paused = true
	_show_overlay("PAUSADO", "", [
		{"text": "VOLTAR AO JOGO", "action": _resume_game},
		{"text": "AJUSTES", "action": _show_settings_overlay},
		{"text": "REINICIAR", "action": _restart_campaign},
		{"text": "MENU", "action": _return_to_menu}
	])

func _resume_game() -> void:
	get_tree().paused = false
	_remove_overlay()

func _show_settings_overlay() -> void:
	_show_overlay("CONFIGURAÇÕES", "", [])
	var settings_box: VBoxContainer = overlay.get_node("Center/Panel/Margin/Scroll/Content")
	_add_slider(settings_box, "Volume geral", "master_volume")
	_add_slider(settings_box, "Música", "music_volume")
	_add_slider(settings_box, "Efeitos sonoros", "sfx_volume")
	var fullscreen: CheckBox = CheckBox.new()
	fullscreen.text = "Tela cheia"
	fullscreen.button_pressed = bool(GameState.settings["fullscreen"])
	fullscreen.add_theme_font_size_override("font_size", roundi(15.0 * _ui_scale()))
	fullscreen.toggled.connect(func(enabled: bool) -> void:
		GameState.settings["fullscreen"] = enabled
		AudioManager.apply_settings()
	)
	settings_box.add_child(fullscreen)
	var resolution: OptionButton = OptionButton.new()
	resolution.add_theme_font_size_override("font_size", roundi(15.0 * _ui_scale()))
	var resolutions: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
	for item: Vector2i in resolutions:
		resolution.add_item("%d x %d" % [item.x, item.y])
		resolution.set_item_metadata(resolution.item_count - 1, item)
	for index: int in resolution.item_count:
		if resolution.get_item_metadata(index) == GameState.settings["resolution"]:
			resolution.select(index)
	resolution.item_selected.connect(func(index: int) -> void:
		GameState.settings["resolution"] = resolution.get_item_metadata(index)
	)
	settings_box.add_child(resolution)
	var apply_button: Button = _add_overlay_button(settings_box, "APLICAR", func() -> void:
		GameState.save_settings()
		AudioManager.apply_settings()
	)
	apply_button.grab_focus()
	_add_overlay_button(settings_box, "VOLTAR", _show_pause_menu)

func _restart_campaign() -> void:
	get_tree().paused = false
	GameState.start_new_campaign()
	var error: int = get_tree().change_scene_to_file("res://Scenes/game.tscn")
	if error != OK:
		push_error("Falha ao reiniciar a campanha: %s" % error_string(error))

func _return_to_menu() -> void:
	get_tree().paused = false
	AudioManager.play_menu_music()
	var error: int = get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	if error != OK:
		push_error("Falha ao abrir o menu principal: %s" % error_string(error))

func _clear_hostile_projectiles() -> void:
	for projectile: Node in get_tree().get_nodes_in_group("hostile_projectile"):
		projectile.queue_free()

func _build_hud() -> void:
	var ui_scale: float = _ui_scale()
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud_layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(hud_root)
	player_status_panel = _new_hud_panel(Vector2.ZERO, Vector2.ZERO)
	cargo_panel = _new_hud_panel(Vector2.ZERO, Vector2.ZERO)
	weapon_panel = _new_hud_panel(Vector2.ZERO, Vector2.ZERO)
	player_portrait = _new_texture_rect(PLAYER_PORTRAIT, Vector2.ZERO, Vector2(56, 56) * ui_scale)
	round_label = _new_hud_label("SETOR 1 / 5", Vector2.ZERO, 280, 22)
	round_label.add_theme_font_size_override("font_size", roundi(14.0 * ui_scale))
	score_label = _new_hud_label("000000", Vector2.ZERO, 180, 18)
	score_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	health_label = _new_hud_label("3 / 3", Vector2.ZERO, 70, 20)
	health_label.add_theme_font_size_override("font_size", roundi(13.0 * ui_scale))
	var health_icon: TextureRect = _new_hud_icon(0, Vector2(22, 22) * ui_scale)
	health_icon.name = "HealthIcon"
	health_bar = ProgressBar.new()
	health_bar.max_value = 3.0
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_fill_style = UIStyle.bar_fill(UIStyle.GOOD)
	health_bar.add_theme_stylebox_override("background", UIStyle.bar_background())
	health_bar.add_theme_stylebox_override("fill", health_fill_style)
	hud_root.add_child(health_bar)
	wave_label = _new_hud_label("HORDA 1 / 3  ·  0", Vector2.ZERO, 280, 24)
	wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_font_size_override("font_size", roundi(15.0 * ui_scale))
	wave_icon = _new_hud_icon(1, Vector2(18, 18) * ui_scale)
	wave_icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_icon.tooltip_text = "CONTATOS HOSTIS"
	dodge_label = _new_hud_label("R  ✓", Vector2.ZERO, 52, 18)
	dodge_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dodge_label.add_theme_color_override("font_color", Color(0.97, 0.67, 0.4))
	emp_label = _new_hud_label("Q  ✓", Vector2.ZERO, 52, 18)
	emp_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	emp_label.add_theme_color_override("font_color", Color(0.45, 0.83, 1.0))
	overdrive_label = _new_hud_label("F  ✓", Vector2.ZERO, 52, 18)
	overdrive_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	overdrive_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.37))
	ammo_label = _new_hud_label("10 / 10", Vector2.ZERO, 150, 26)
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.add_theme_color_override("font_color", Color(0.7, 0.94, 0.65))
	ammo_label.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	current_weapon_icon = _new_texture_rect(
		WEAPON_TEXTURES[0],
		Vector2.ZERO,
		Vector2(68, 34) * ui_scale
	)
	current_weapon_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	for weapon_index: int in WEAPON_TEXTURES.size():
		var weapon_icon: TextureRect = _new_texture_rect(
			WEAPON_TEXTURES[weapon_index],
			Vector2.ZERO,
			Vector2(42, 28) * ui_scale
		)
		weapon_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		weapon_icon.tooltip_text = "%d  ·  %s" % [
			weapon_index + 1,
			["RIFLE", "ESCOPETA", "CANHÃO IÔNICO"][weapon_index]
		]
		weapon_slot_icons.append(weapon_icon)
	for ability_index: int in 3:
		var ability_icon: TextureRect = _new_hud_icon(
			6 + ability_index,
			Vector2(24, 24) * ui_scale
		)
		ability_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		ability_icons.append(ability_icon)
	dodge_label.tooltip_text = "R  ·  ROLAMENTO"
	emp_label.tooltip_text = "Q  ·  PULSO DE RUPTURA"
	overdrive_label.tooltip_text = "F  ·  SOBRECARGA"
	ship_arrow = Control.new()
	ship_arrow.name = "ShipDirectionArrow"
	ship_arrow.set_script(SHIP_ARROW_SCRIPT)
	ship_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ship_arrow.process_mode = Node.PROCESS_MODE_PAUSABLE
	ship_arrow.visible = false
	hud_root.add_child(ship_arrow)
	ship_label = _new_hud_label("", Vector2.ZERO, 360, 28)
	ship_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ship_label.add_theme_color_override("font_color", Color(1.0, 0.77, 0.51))
	ship_label.visible = false
	parts_label = _new_hud_label("NAVE 0/4", Vector2.ZERO, 100, 20)
	parts_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	parts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parts_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	for part_index: int in PART_LABELS.size():
		var part_icon: TextureRect = _new_hud_icon(
			2 + part_index,
			Vector2(24, 24) * ui_scale
		)
		part_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		part_icon.tooltip_text = PART_LABELS[part_index]
		part_icons.append(part_icon)
	boss_name_label = _new_hud_label("", Vector2(0, 122), 680, 26)
	boss_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.visible = false
	boss_health_bar = ProgressBar.new()
	boss_health_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_health_bar.show_percentage = false
	boss_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health_bar.add_theme_stylebox_override("background", UIStyle.bar_background())
	boss_health_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(Color(0.92, 0.39, 0.23)))
	boss_health_bar.visible = false
	hud_root.add_child(boss_health_bar)
	toast_label = _new_hud_label("", Vector2(0, 198), 650, 34)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", roundi(20.0 * ui_scale))
	toast_label.visible = false
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()

func _layout_hud() -> void:
	if not is_instance_valid(hud_root):
		return
	var window_size: Vector2 = DisplayServer.window_get_size()
	var ui_scale: float = _ui_scale()
	round_label.add_theme_font_size_override("font_size", roundi(14.0 * ui_scale))
	score_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	health_label.add_theme_font_size_override("font_size", roundi(13.0 * ui_scale))
	wave_label.add_theme_font_size_override("font_size", roundi(15.0 * ui_scale))
	for label: Label in [dodge_label, emp_label, overdrive_label, boss_name_label]:
		label.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	ammo_label.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	parts_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	toast_label.add_theme_font_size_override("font_size", roundi(20.0 * ui_scale))
	var compact_layout: bool = window_size.x < 980.0
	var status_width: float = minf(370.0, maxf(270.0, window_size.x * 0.42))
	player_status_panel.position = Vector2(12.0, 12.0) * ui_scale
	player_status_panel.size = Vector2(status_width, 104.0) * ui_scale
	player_portrait.position = Vector2(24.0, 22.0) * ui_scale
	player_portrait.size = Vector2(58.0, 58.0) * ui_scale
	round_label.position = Vector2(92.0, 20.0) * ui_scale
	round_label.size = Vector2(status_width - 104.0, 22.0) * ui_scale
	score_label.position = Vector2(92.0, 45.0) * ui_scale
	score_label.size = Vector2(status_width - 104.0, 18.0) * ui_scale
	health_label.position = Vector2(120.0, 70.0) * ui_scale
	health_label.size = Vector2(58.0, 20.0) * ui_scale
	var health_icon: Control = hud_root.get_node("HealthIcon")
	health_icon.position = Vector2(92.0, 68.0) * ui_scale
	health_bar.position = Vector2(184.0, 74.0) * ui_scale
	health_bar.size = Vector2(maxf(52.0, status_width - 208.0), 8.0) * ui_scale

	var narrow_layout: bool = window_size.x < 620.0
	var cargo_width: float = window_size.x - 24.0 if narrow_layout else minf(224.0, maxf(184.0, window_size.x * 0.28))
	var cargo_x: float = 12.0 if narrow_layout else window_size.x - cargo_width - 12.0
	var cargo_y: float = 124.0 if narrow_layout else 12.0
	cargo_panel.position = Vector2(cargo_x, cargo_y) * ui_scale
	cargo_panel.size = Vector2(cargo_width, 64.0) * ui_scale
	parts_label.offset_left = (-cargo_width + 16.0) * ui_scale
	parts_label.offset_top = (cargo_y + 10.0) * ui_scale
	parts_label.offset_right = -16.0 * ui_scale
	parts_label.offset_bottom = (cargo_y + 30.0) * ui_scale
	parts_label.size.x = (cargo_width - 32.0) * ui_scale
	var part_spacing: float = (cargo_width - 40.0) / float(PART_LABELS.size())
	for index: int in part_icons.size():
		var icon: TextureRect = part_icons[index]
		icon.offset_right = (-cargo_width + 18.0 + part_spacing * float(index + 1)) * ui_scale
		icon.offset_left = icon.offset_right - 24.0 * ui_scale
		icon.offset_top = (cargo_y + 34.0) * ui_scale
		icon.offset_bottom = (cargo_y + 58.0) * ui_scale

	var wave_y: float = 200.0 if narrow_layout else (124.0 if compact_layout else 22.0)
	wave_icon.offset_left = -158.0 * ui_scale
	wave_icon.offset_top = (wave_y + 3.0) * ui_scale
	wave_icon.offset_right = -140.0 * ui_scale
	wave_icon.offset_bottom = (wave_y + 21.0) * ui_scale
	wave_label.offset_left = -140.0 * ui_scale
	wave_label.offset_top = wave_y * ui_scale
	wave_label.offset_right = 140.0 * ui_scale
	wave_label.offset_bottom = (wave_y + 24.0) * ui_scale
	var weapon_width: float = minf(448.0, maxf(336.0, window_size.x - 24.0))
	var weapon_height: float = 124.0
	weapon_panel.position = Vector2(
		window_size.x - weapon_width - 12.0,
		window_size.y - weapon_height - 12.0
	) * ui_scale
	weapon_panel.size = Vector2(weapon_width, weapon_height) * ui_scale
	current_weapon_icon.offset_left = (-weapon_width + 18.0) * ui_scale
	current_weapon_icon.offset_top = (-weapon_height + 12.0) * ui_scale
	current_weapon_icon.offset_right = (-weapon_width + 86.0) * ui_scale
	current_weapon_icon.offset_bottom = (-weapon_height + 48.0) * ui_scale
	ammo_label.offset_left = (-weapon_width + 98.0) * ui_scale
	ammo_label.offset_top = (-weapon_height + 16.0) * ui_scale
	ammo_label.offset_right = -18.0 * ui_scale
	ammo_label.offset_bottom = (-weapon_height + 44.0) * ui_scale
	var slot_start: float = -weapon_width + 18.0
	for index: int in weapon_slot_icons.size():
		var icon: TextureRect = weapon_slot_icons[index]
		icon.offset_left = (slot_start + float(index) * 50.0) * ui_scale
		icon.offset_top = -72.0 * ui_scale
		icon.offset_right = icon.offset_left + 42.0 * ui_scale
		icon.offset_bottom = -44.0 * ui_scale
	var ability_spacing: float = minf(78.0, (weapon_width - 168.0) / 3.0)
	var ability_start: float = -weapon_width + 168.0
	for index: int in ability_icons.size():
		var icon: TextureRect = ability_icons[index]
		icon.offset_left = (ability_start + float(index) * ability_spacing) * ui_scale
		icon.offset_top = -72.0 * ui_scale
		icon.offset_right = icon.offset_left + 24.0 * ui_scale
		icon.offset_bottom = -48.0 * ui_scale
	var ability_labels: Array[Label] = [dodge_label, emp_label, overdrive_label]
	for index: int in ability_labels.size():
		var label: Label = ability_labels[index]
		label.offset_left = (ability_start + float(index) * ability_spacing + 26.0) * ui_scale
		label.offset_top = -70.0 * ui_scale
		label.offset_right = label.offset_left + (ability_spacing - 26.0) * ui_scale
		label.offset_bottom = -48.0 * ui_scale

	ship_label.offset_left = 12.0 * ui_scale
	ship_label.offset_top = -44.0 * ui_scale
	ship_label.offset_right = minf(312.0, window_size.x - weapon_width - 24.0) * ui_scale
	ship_label.offset_bottom = -16.0 * ui_scale
	var boss_y: float = 238.0 if narrow_layout else (164.0 if compact_layout else 72.0)
	var boss_width: float = minf(380.0, maxf(220.0, window_size.x * 0.42))
	boss_name_label.offset_left = -boss_width * 0.5 * ui_scale
	boss_name_label.offset_top = boss_y * ui_scale
	boss_name_label.offset_right = boss_width * 0.5 * ui_scale
	boss_name_label.offset_bottom = (boss_y + 26.0) * ui_scale
	boss_health_bar.offset_left = -boss_width * 0.5 * ui_scale
	boss_health_bar.offset_top = (boss_y + 30.0) * ui_scale
	boss_health_bar.offset_right = boss_width * 0.5 * ui_scale
	boss_health_bar.offset_bottom = (boss_y + 48.0) * ui_scale
	var toast_y: float = boss_y + 66.0
	toast_label.offset_left = -minf(260.0, window_size.x * 0.42) * ui_scale
	toast_label.offset_top = toast_y * ui_scale
	toast_label.offset_right = minf(260.0, window_size.x * 0.42) * ui_scale
	toast_label.offset_bottom = (toast_y + 34.0) * ui_scale

func _ui_scale() -> float:
	var viewport_width: float = get_viewport_rect().size.x
	var window_width: float = float(DisplayServer.window_get_size().x)
	return viewport_width / maxf(1.0, window_width)

func _new_hud_label(text: String, position: Vector2, width: float, height: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(width, height)
	label.add_theme_font_size_override("font_size", roundi(16.0 * _ui_scale()))
	UIStyle.apply_font(label, UIStyle.mono_font())
	label.add_theme_color_override("font_color", Color(0.97, 0.88, 0.76))
	label.add_theme_color_override("font_outline_color", UIStyle.OUTLINE)
	label.add_theme_constant_override("outline_size", 3)
	hud_root.add_child(label)
	return label

func _new_texture_rect(texture: Texture2D, icon_position: Vector2, icon_size: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.position = icon_position
	icon.size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(icon)
	return icon

func _new_hud_icon(icon_index: int, icon_size: Vector2) -> TextureRect:
	var icon: TextureRect = _new_texture_rect(UI_ICONS, Vector2.ZERO, icon_size)
	var atlas_texture: AtlasTexture = AtlasTexture.new()
	atlas_texture.atlas = UI_ICONS
	atlas_texture.region = Rect2(icon_index * 16, 0, 16, 16)
	icon.texture = atlas_texture
	return icon

func _new_hud_panel(position: Vector2, panel_size: Vector2) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = position
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UIStyle.hud_panel_style()
	panel.add_theme_stylebox_override("panel", style)
	hud_root.add_child(panel)
	return panel

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	var gun: Node = player.get_node_or_null("GunPivot/Gun")
	if gun != null:
		var reload_timer: float = float(gun.get("reload_timer"))
		var weapon_index: int = clampi(int(gun.get("weapon_index")), 0, WEAPON_TEXTURES.size() - 1)
		current_weapon_icon.texture = WEAPON_TEXTURES[weapon_index]
		current_weapon_icon.tooltip_text = "%s  ·  TECLA %d" % [
			["RIFLE", "ESCOPETA", "CANHÃO IÔNICO"][weapon_index],
			weapon_index + 1
		]
		if reload_timer > 0.0:
			ammo_label.text = "RECARGA  %.1f s" % reload_timer
		else:
			ammo_label.text = "%02d / %02d" % [
				int(gun.get("ammo_in_magazine")),
				int(gun.get("magazine_capacity"))
			]
		var ammo_ratio: float = float(int(gun.get("ammo_in_magazine"))) / maxf(1.0, float(int(gun.get("magazine_capacity"))))
		if reload_timer > 0.0:
			ammo_label.add_theme_color_override("font_color", UIStyle.WARN)
		elif ammo_ratio <= 0.25:
			ammo_label.add_theme_color_override("font_color", UIStyle.DANGER)
		else:
			ammo_label.add_theme_color_override("font_color", Color(0.7, 0.94, 0.65))
		for index: int in weapon_slot_icons.size():
			weapon_slot_icons[index].modulate = (
				Color.WHITE if index == weapon_index else Color(0.52, 0.57, 0.56, 0.72)
			)
	score_label.text = "PONTOS  %06d" % GameState.score
	health_label.text = "%.0f / %.0f" % [
		ceilf(float(player.get("lifes"))),
		float(player.get("max_life"))
	]
	health_bar.max_value = float(player.get("max_life"))
	health_bar.value = float(player.get("lifes"))
	var health_ratio: float = float(player.get("lifes")) / maxf(0.01, float(player.get("max_life")))
	health_fill_style.bg_color = UIStyle.health_color(health_ratio)
	health_fill_style.border_color = health_fill_style.bg_color.darkened(0.35)
	if health_ratio <= 0.34:
		var danger_pulse: float = 0.72 + 0.28 * sin(float(Time.get_ticks_msec()) * 0.012)
		health_bar.modulate = Color(1.0, danger_pulse, danger_pulse)
		health_label.add_theme_color_override("font_color", UIStyle.DANGER)
	else:
		health_bar.modulate = Color.WHITE
		health_label.add_theme_color_override("font_color", Color(0.97, 0.88, 0.76))
	var difficulty_config: Dictionary = GameState.get_difficulty_config()
	round_label.text = "SETOR %d / 5  ·  %s" % [
		round_number,
		str(difficulty_config["label"]).to_upper()
	]
	if run_state == RunState.BOSS and is_instance_valid(active_boss):
		boss_name_label.text = "%s  ·  FASE %d" % [
			active_boss.get("boss_name"),
			active_boss.get("phase")
		]
	var roll_cooldown: float = float(player.get("roll_cooldown"))
	dodge_label.text = "R  ✓" if roll_cooldown <= 0.0 else "R  %.0f" % ceilf(roll_cooldown)
	dodge_label.modulate.a = 1.0 if roll_cooldown <= 0.0 else 0.64
	var emp_cooldown: float = float(player.get("emp_cooldown"))
	emp_label.text = "Q  ✓" if emp_cooldown <= 0.0 else "Q  %.0f" % ceilf(emp_cooldown)
	emp_label.modulate.a = 1.0 if emp_cooldown <= 0.0 else 0.64
	var overdrive_timer: float = float(player.get("overdrive_timer"))
	var overdrive_cooldown: float = float(player.get("overdrive_cooldown"))
	if overdrive_timer > 0.0:
		overdrive_label.text = "F  %.0f" % ceilf(overdrive_timer)
		overdrive_label.modulate.a = 1.0
	else:
		if overdrive_cooldown <= 0.0:
			overdrive_label.text = "F  ✓"
			overdrive_label.modulate.a = 1.0
		else:
			overdrive_label.text = "F  %.0f" % ceilf(overdrive_cooldown)
			overdrive_label.modulate.a = 0.64
	if run_state == RunState.EXPLORE:
		wave_label.text = "EXPLORAÇÃO  ·  SETOR %d" % round_number
		ship_arrow.visible = true
		ship_arrow.call("set_positions", ship_world_position, player.global_position)
	elif run_state == RunState.BOSS:
		ship_arrow.visible = false
		if is_instance_valid(active_boss):
			wave_label.text = "CHEFE  ·  FASE %d" % int(active_boss.get("phase"))
		else:
			wave_label.text = "CHEFE"
	else:
		ship_arrow.visible = false
		wave_label.text = "HORDA %d / %d  ·  %02d" % [
			maxi(1, wave_index + 1),
			horde_count,
			active_enemies + spawn_remaining
		]
	parts_label.text = "NAVE  %d / 4" % GameState.ship_parts.size()
	for index: int in part_icons.size():
		var part_icon: TextureRect = part_icons[index]
		var collected: bool = GameState.ship_parts.has(PART_LABELS[index])
		part_icon.modulate = Color.WHITE if collected else Color(0.48, 0.5, 0.48, 0.68)
		part_icon.tooltip_text = "%s  ·  %s" % [
			PART_LABELS[index],
			"RECUPERADO" if collected else "PENDENTE"
		]

func _show_toast(message: String, duration: float) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_label.modulate.a = 0.0
	var toast_tween: Tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.16)
	toast_timer = duration

func _show_overlay(title: String, body: String, buttons: Array) -> void:
	_remove_overlay()
	var ui_scale: float = _ui_scale()
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.theme = UIStyle.build_theme(ui_scale)
	overlay.color = Color(0.03, 0.012, 0.014, 0.86)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_layer.add_child(overlay)
	var center: Control = Control.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_width: float = maxf(0.0, minf(560.0 * ui_scale, viewport_size.x - 32.0 * ui_scale))
	var window_size: Vector2 = DisplayServer.window_get_size()
	var panel_height: float = 225.0 + float(buttons.size()) * 48.0
	if not body.is_empty():
		panel_height += 52.0
	if title == "CONFIGURAÇÕES":
		panel_height = 470.0
	panel_height = minf(panel_height, maxf(240.0, window_size.y - 32.0))
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * ui_scale * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * ui_scale * 0.5
	var style: StyleBoxFlat = UIStyle.panel_style(true)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	overlay.modulate.a = 0.0
	var overlay_fade: Tween = overlay.create_tween()
	overlay_fade.tween_property(overlay, "modulate:a", 1.0, 0.18)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	var horizontal_margin: int = mini(
		roundi(28.0 * ui_scale),
		maxi(roundi(12.0 * ui_scale), floori((panel_width - 180.0 * ui_scale) * 0.5))
	)
	margin.add_theme_constant_override("margin_left", horizontal_margin)
	margin.add_theme_constant_override("margin_right", horizontal_margin)
	margin.add_theme_constant_override("margin_top", roundi(22.0 * ui_scale))
	margin.add_theme_constant_override("margin_bottom", roundi(18.0 * ui_scale))
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", roundi(12.0 * ui_scale))
	scroll.add_child(content)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", roundi(14.0 * ui_scale))
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	var state_art: TextureRect = TextureRect.new()
	state_art.texture = _overlay_texture(title)
	state_art.custom_minimum_size = Vector2(58, 58) * ui_scale
	state_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	state_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	state_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	state_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(state_art)
	var title_stack: VBoxContainer = VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	var eyebrow: Label = Label.new()
	eyebrow.text = "FALLEN ASTRO  ·  SETOR 09-A"
	eyebrow.add_theme_font_size_override("font_size", roundi(10.0 * ui_scale))
	eyebrow.add_theme_color_override("font_color", UIStyle.DATA)
	title_stack.add_child(eyebrow)
	var heading: Label = Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", roundi(24.0 * ui_scale))
	UIStyle.apply_font(heading, UIStyle.title_font())
	heading.add_theme_color_override("font_color", UIStyle.CREAM)
	heading.add_theme_color_override("font_outline_color", Color(0.36, 0.1, 0.05))
	heading.add_theme_constant_override("outline_size", roundi(4.0 * ui_scale))
	title_stack.add_child(heading)
	header.add_child(title_stack)
	content.add_child(header)
	var divider: HSeparator = HSeparator.new()
	content.add_child(divider)
	overlay_body = Label.new()
	overlay_body.text = body
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	overlay_body.add_theme_color_override("font_color", UIStyle.TEXT)
	content.add_child(overlay_body)
	for button_index: int in buttons.size():
		var button_data: Dictionary = buttons[button_index]
		var button_action: Callable = button_data["action"]
		var button: Button = _add_overlay_button(content, str(button_data["text"]), button_action)
		if button_index == 0:
			button.grab_focus()

func _overlay_texture(title: String) -> Texture2D:
	var normalized_title: String = title.to_upper()
	if normalized_title.contains("PEÇAS"):
		return _atlas_icon(5)
	if normalized_title.contains("CHEFE") or normalized_title.contains("SINAL"):
		return ENEMY_PORTRAIT
	if normalized_title.contains("MELHORIA") or normalized_title.contains("ARMA"):
		return WEAPON_TEXTURES[0]
	if normalized_title.contains("NAVE") or normalized_title.contains("FUGA"):
		return _atlas_icon(5)
	return PLAYER_PORTRAIT

func _atlas_icon(icon_index: int) -> AtlasTexture:
	var atlas_texture: AtlasTexture = AtlasTexture.new()
	atlas_texture.atlas = UI_ICONS
	atlas_texture.region = Rect2(icon_index * 16, 0, 16, 16)
	return atlas_texture

func _add_overlay_button(parent: VBoxContainer, title: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	var ui_scale: float = _ui_scale()
	button.custom_minimum_size.y = 42.0 * ui_scale
	var button_kind: String = "normal"
	if ["CONTINUAR", "VOLTAR AO JOGO", "TENTAR DE NOVO", "NOVA CAMPANHA"].has(title):
		button_kind = "primary"
	elif title == "REINICIAR":
		button_kind = "danger"
	UIStyle.style_button(button, button_kind)
	button.add_theme_font_size_override("font_size", roundi(15.0 * ui_scale))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _add_slider(parent: VBoxContainer, title: String, setting: String) -> void:
	var ui_scale: float = _ui_scale()
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size.x = 150.0 * ui_scale
	label.add_theme_font_size_override("font_size", roundi(15.0 * ui_scale))
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(GameState.settings[setting])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label: Label = Label.new()
	value_label.text = "%d%%" % roundi(slider.value * 100.0)
	value_label.custom_minimum_size.x = 48.0 * ui_scale
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", roundi(15.0 * ui_scale))
	value_label.add_theme_color_override("font_color", UIStyle.ACCENT)
	slider.value_changed.connect(func(value: float) -> void:
		GameState.settings[setting] = value
		value_label.text = "%d%%" % roundi(value * 100.0)
		AudioManager.apply_settings()
	)
	row.add_child(slider)
	row.add_child(value_label)
	parent.add_child(row)

func _remove_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
