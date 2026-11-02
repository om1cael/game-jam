extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://Scenes/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://Scenes/boss.tscn")
const MEDKIT_SCENE: PackedScene = preload("res://Scenes/medkit.tscn")
const SHIP_SCENE: PackedScene = preload("res://Scenes/ship.tscn")
const SHIP_ARROW_SCRIPT: Script = preload("res://Scripts/ship_arrow.gd")
const MARS_TERRAIN_SCRIPT: Script = preload("res://Scripts/mars_terrain.gd")
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
var wave_label: Label
var parts_label: Label
var dodge_label: Label
var ship_label: Label
var ship_arrow: Control
var boss_name_label: Label
var boss_health_bar: ProgressBar
var toast_label: Label
var overlay_layer: CanvasLayer
var overlay_body: Label
var overlay: ColorRect

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
			spawn_timer = maxf(0.52, 0.78 - float(round_number - 1) * 0.035)
		if spawn_remaining == 0 and active_enemies == 0:
			_complete_wave()
	if run_state == RunState.EXPLORE:
		var distance_to_ship: float = player.global_position.distance_to(ship_world_position)
		ship_label.visible = true
		if distance_to_ship <= 120.0:
			ship_label.text = "NAVE  |  E: INICIAR RODADA %d" % round_number
		else:
			ship_label.text = "SIGA A SETA ATÉ A NAVE"
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
	await get_tree().create_timer(1.8, false).timeout
	if run_state == RunState.INTERMISSION:
		_begin_wave()

func _begin_wave() -> void:
	wave_index += 1
	run_state = RunState.WAVES
	spawn_remaining = round_number + wave_index + 2
	spawn_timer = 0.2
	_show_toast("HORDA %d / %d — CONTATOS DETECTADOS" % [wave_index + 1, horde_count], 2.0)

func _complete_wave() -> void:
	if run_state != RunState.WAVES:
		return
	run_state = RunState.INTERMISSION
	if wave_index < horde_count - 1:
		_show_toast("HORDA ELIMINADA — PREPARE-SE", 1.7)
		await get_tree().create_timer(1.8, false).timeout
		if run_state == RunState.INTERMISSION:
			_begin_wave()
	else:
		_show_toast("TODAS AS HORDAS ELIMINADAS", 1.8)
		await get_tree().create_timer(1.8, false).timeout
		if run_state == RunState.INTERMISSION:
			_start_boss()

func _start_boss() -> void:
	run_state = RunState.BOSS
	_show_toast("ALERTA — CHEFE DETECTADO", 2.0)
	var boss: CharacterBody2D = BOSS_SCENE.instantiate() as CharacterBody2D
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	boss.global_position = _random_offscreen_position(170.0)
	boss.connect("health_changed", _on_boss_health_changed)
	boss.connect("defeated", _on_boss_defeated)
	boss.call("configure", round_number)
	active_boss = boss
	add_child(boss)
	boss_name_label.text = "CHEFE: %s" % boss.get("boss_name")
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
	return 4 + floori(float(round_number - 1) / 2.0)

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
	tile_layer.modulate = Color(1.0, 0.55, 0.47)
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
			tile_layer.set_cell(cell, 0, Vector2i.ZERO)
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
		return "ARMORED" if roll < 0.25 else "NORMAL"
	if round_number == 3:
		if roll < 0.22:
			return "AGGRESSIVE"
		return "ARMORED" if roll < 0.4 else "NORMAL"
	if round_number == 4:
		if roll < 0.17:
			return "FAST"
		if roll < 0.31:
			return "MUTATED"
		if roll < 0.51:
			return "AGGRESSIVE"
		if roll < 0.69:
			return "ARMORED"
		return "NORMAL"
	if roll < 0.15:
		return "ELITE"
	if roll < 0.32:
		return "MUTATED"
	if roll < 0.49:
		return "FAST"
	if roll < 0.66:
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
	_show_toast("+%d  |  %s ELIMINADO" % [points, variant], 1.3)
	_update_hud()

func _on_boss_health_changed(current_health: float, maximum_health: float) -> void:
	boss_health_bar.max_value = maximum_health
	boss_health_bar.value = current_health

func _on_boss_defeated(_name: String, points: int) -> void:
	if run_state != RunState.BOSS:
		return
	active_boss = null
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
			_show_overlay("PROGRESSO INCOMPLETO", "A entidade foi derrotada, mas faltam componentes da nave.", [
				{"text": "VOLTAR AO MENU", "action": _return_to_menu}
			])
			return
		_finish_campaign()

func _show_reward(part: String) -> void:
	run_state = RunState.REWARD
	get_tree().paused = true
	player.call("heal", 1)
	var piece_label: String = part if not part.is_empty() else "COMPONENTE JÁ REGISTRADO"
	_show_overlay("CHEFE DERROTADO", "PEÇA RECUPERADA\n%s\n\nPontuação: %d\nPeças da nave: %d / 4\nExplore o planeta e volte à nave quando quiser iniciar a próxima rodada." % [piece_label, GameState.score, GameState.ship_parts.size()], [
		{"text": "CONTINUAR EXPLORANDO", "action": _continue_exploring},
		{"text": "SALVAR E VOLTAR AO MENU", "action": _return_to_menu}
	])
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
	_show_toast("ÁREA SEGURA — A PRÓXIMA RODADA COMEÇA NA NAVE", 4.0)

func _enter_exploration() -> void:
	run_state = RunState.EXPLORE
	horde_count = round_number + 2
	spawn_remaining = 0
	active_enemies = 0
	_clear_hostile_projectiles()
	ship_label.visible = true
	_show_toast("RODADA CONCLUÍDA — SIGA A SETA ATÉ A NAVE", 4.0)

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
	_show_overlay("NAVE RECONSTRUÍDA", "REATOR: ONLINE\nBATERIA: ONLINE\nRÁDIO: ONLINE\nESCOTILHA: SELADA", [])
	await get_tree().create_timer(1.0, true).timeout
	if run_state != RunState.VICTORY:
		return
	overlay_body.text = "SISTEMAS DA NAVE ATIVADOS\nSEQUÊNCIA DE DECOLAGEM INICIADA"
	await get_tree().create_timer(1.2, true).timeout
	if run_state != RunState.VICTORY:
		return
	_show_victory()

func _show_victory() -> void:
	_show_overlay("FUGA CONCLUÍDA", "FALLEN ASTRO\n\nPontuação final: %d\nRecorde: %d\n\nVocê escapou do planeta." % [GameState.score, GameState.high_score], [
		{"text": "JOGAR NOVAMENTE", "action": _restart_campaign},
		{"text": "MENU PRINCIPAL", "action": _return_to_menu}
	])

func _on_player_died() -> void:
	if run_state == RunState.GAME_OVER:
		return
	run_state = RunState.GAME_OVER
	spawn_remaining = 0
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	_clear_hostile_projectiles()
	GameState.save_data()
	_show_overlay("SINAL PERDIDO", "GAME OVER\n\nPontuação: %d\nRodada alcançada: %d / 5" % [GameState.score, round_number], [
		{"text": "TENTAR NOVAMENTE", "action": _restart_campaign},
		{"text": "MENU PRINCIPAL", "action": _return_to_menu}
	])

func _show_pause_menu() -> void:
	if run_state == RunState.GAME_OVER or run_state == RunState.VICTORY:
		return
	get_tree().paused = true
	_show_overlay("JOGO PAUSADO", "A sobrevivência pode esperar.", [
		{"text": "CONTINUAR", "action": _resume_game},
		{"text": "CONFIGURAÇÕES", "action": _show_settings_overlay},
		{"text": "REINICIAR CAMPANHA", "action": _restart_campaign},
		{"text": "VOLTAR AO MENU", "action": _return_to_menu}
	])

func _resume_game() -> void:
	get_tree().paused = false
	_remove_overlay()

func _show_settings_overlay() -> void:
	_show_overlay("CONFIGURAÇÕES", "", [])
	var settings_box: VBoxContainer = overlay.get_node("Center/Panel/Margin/Content")
	_add_slider(settings_box, "Volume geral", "master_volume")
	_add_slider(settings_box, "Música", "music_volume")
	_add_slider(settings_box, "Efeitos sonoros", "sfx_volume")
	var fullscreen: CheckBox = CheckBox.new()
	fullscreen.text = "Tela cheia"
	fullscreen.button_pressed = bool(GameState.settings["fullscreen"])
	fullscreen.toggled.connect(func(enabled: bool) -> void:
		GameState.settings["fullscreen"] = enabled
		AudioManager.apply_settings()
	)
	settings_box.add_child(fullscreen)
	var resolution: OptionButton = OptionButton.new()
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
	_add_overlay_button(settings_box, "APLICAR", func() -> void:
		GameState.save_settings()
		AudioManager.apply_settings()
	)
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
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud_layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(hud_root)
	round_label = _new_hud_label("RODADA 1 / 5", Vector2(24, 18), 240, 26)
	score_label = _new_hud_label("PONTUAÇÃO 000000", Vector2(24, 52), 260, 22)
	health_label = _new_hud_label("VIDA 3 / 3", Vector2(24, 82), 220, 22)
	wave_label = _new_hud_label("HORDA 1 / 3 | INIMIGOS 0", Vector2(24, 112), 340, 22)
	dodge_label = _new_hud_label("R  ROLAMENTO PRONTO", Vector2.ZERO, 260, 24)
	dodge_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dodge_label.offset_left = 24
	dodge_label.offset_top = -42
	dodge_label.offset_right = 284
	dodge_label.offset_bottom = -18
	dodge_label.add_theme_color_override("font_color", Color(0.97, 0.67, 0.4))
	ship_arrow = Control.new()
	ship_arrow.name = "ShipDirectionArrow"
	ship_arrow.set_script(SHIP_ARROW_SCRIPT)
	ship_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ship_arrow.process_mode = Node.PROCESS_MODE_PAUSABLE
	ship_arrow.visible = false
	hud_root.add_child(ship_arrow)
	ship_label = _new_hud_label("", Vector2.ZERO, 500, 32)
	ship_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ship_label.offset_left = -250
	ship_label.offset_top = -76
	ship_label.offset_right = 250
	ship_label.offset_bottom = -44
	ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship_label.add_theme_color_override("font_color", Color(1.0, 0.77, 0.51))
	ship_label.visible = false
	parts_label = _new_hud_label("", Vector2(0, 18), 310, 92)
	parts_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	parts_label.offset_left = -330
	parts_label.offset_right = -20
	parts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_name_label = _new_hud_label("", Vector2(0, 122), 440, 26)
	boss_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_name_label.offset_left = -220
	boss_name_label.offset_right = 220
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.visible = false
	boss_health_bar = ProgressBar.new()
	boss_health_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_health_bar.offset_left = -220
	boss_health_bar.offset_top = 152
	boss_health_bar.offset_right = 220
	boss_health_bar.offset_bottom = 170
	boss_health_bar.show_percentage = false
	var boss_bar_background: StyleBoxFlat = StyleBoxFlat.new()
	boss_bar_background.bg_color = Color(0.12, 0.055, 0.05, 0.92)
	boss_bar_background.set_corner_radius_all(3)
	var boss_bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	boss_bar_fill.bg_color = Color(0.84, 0.27, 0.16)
	boss_bar_fill.set_corner_radius_all(3)
	boss_health_bar.add_theme_stylebox_override("background", boss_bar_background)
	boss_health_bar.add_theme_stylebox_override("fill", boss_bar_fill)
	boss_health_bar.visible = false
	hud_root.add_child(boss_health_bar)
	toast_label = _new_hud_label("", Vector2(0, 198), 650, 34)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -325
	toast_label.offset_right = 325
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.visible = false
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)

func _new_hud_label(text: String, position: Vector2, width: float, height: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(width, height)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.94, 0.84, 0.73))
	hud_root.add_child(label)
	return label

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	round_label.text = "RODADA %d / 5" % round_number
	score_label.text = "PONTUAÇÃO %06d" % GameState.score
	health_label.text = "VIDA %.1f / 3.0" % float(player.get("lifes"))
	var roll_cooldown: float = float(player.get("roll_cooldown"))
	dodge_label.text = "R  ROLAMENTO PRONTO" if roll_cooldown <= 0.0 else "R  RECARGA %.1f s" % roll_cooldown
	if run_state == RunState.EXPLORE:
		wave_label.text = "RODADA %d LIBERADA | PREPARE-SE" % (round_number - 1)
		ship_arrow.visible = true
		ship_arrow.call("set_positions", ship_world_position, player.global_position)
	elif run_state == RunState.BOSS:
		ship_arrow.visible = false
		wave_label.text = "CHEFE | %s" % active_boss.get("boss_name") if is_instance_valid(active_boss) else "CHEFE"
	else:
		ship_arrow.visible = false
		wave_label.text = "HORDA %d / %d | INIMIGOS %d" % [maxi(1, wave_index + 1), horde_count, active_enemies + spawn_remaining]
	var parts: Array[String] = []
	for part: String in PART_LABELS:
		parts.append("%s %s" % ["[X]" if GameState.ship_parts.has(part) else "[ ]", part])
	parts_label.text = "NAVE: %d / 4\n%s" % [GameState.ship_parts.size(), "\n".join(parts)]

func _show_toast(message: String, duration: float) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_timer = duration

func _show_overlay(title: String, body: String, buttons: Array) -> void:
	_remove_overlay()
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.025, 0.014, 0.014, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_layer.add_child(overlay)
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(460.0, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.043, 0.04, 0.98)
	style.border_color = Color(0.56, 0.25, 0.17, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var heading: Label = Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.98, 0.76, 0.57))
	content.add_child(heading)
	overlay_body = Label.new()
	overlay_body.text = body
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.add_theme_font_size_override("font_size", 16)
	overlay_body.add_theme_color_override("font_color", Color(0.9, 0.83, 0.75))
	content.add_child(overlay_body)
	for button_data: Dictionary in buttons:
		var button_action: Callable = button_data["action"]
		_add_overlay_button(content, str(button_data["text"]), button_action)

func _add_overlay_button(parent: VBoxContainer, title: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title.capitalize()
	button.custom_minimum_size.y = 42
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.073, 0.06, 0.96)
	normal.border_color = Color(0.48, 0.22, 0.15, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.12, 0.075, 0.99)
	hover.border_color = Color(0.86, 0.43, 0.23)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color(0.95, 0.85, 0.75))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.81))
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _add_slider(parent: VBoxContainer, title: String, setting: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(GameState.settings[setting])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		GameState.settings[setting] = value
		AudioManager.apply_settings()
	)
	row.add_child(slider)
	parent.add_child(row)

func _remove_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
