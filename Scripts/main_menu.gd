extends Control

const UI_ICONS: Texture2D = preload("res://Sprites/UI/ui_icons.svg")
const UIStyle = preload("res://Scripts/ui_style.gd")
const SHIP_TEXTURE: Texture2D = preload("res://Sprites/ship.png")
const GROUND_TEXTURE: Texture2D = preload("res://Sprites/ground_tile_map.png")
const LASER_TEXTURE: Texture2D = preload("res://Sprites/laser.png")
const PLAYER_SHEET: Texture2D = preload("res://Sprites/Player/directions/down_left_walk.png")
const SCENE_ENEMIES: Array[Texture2D] = [
	preload("res://Sprites/Enemy/Variants/normal_walk.png"),
	preload("res://Sprites/Enemy/Variants/fast_walk.png"),
	preload("res://Sprites/Enemy/Variants/armored_walk.png"),
	preload("res://Sprites/Enemy/Variants/aggressive_walk.png")
]

var panel: PanelContainer
var screen_root: Control
var transition_layer: CanvasLayer
var background_time: float = 0.0
var menu_theme: Theme
var current_page: String = "main"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_theme = _create_menu_theme()
	theme = menu_theme
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	AudioManager.play_menu_music()
	transition_layer = CanvasLayer.new()
	add_child(transition_layer)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_show_main()

func _process(delta: float) -> void:
	background_time += delta
	queue_redraw()

func _draw_sheet_frame(texture: Texture2D, frame: int, foot: Vector2, pixel_scale: float, tint: Color = Color.WHITE) -> void:
	var frame_size: Vector2 = Vector2(128.0, 120.0)
	var destination: Rect2 = Rect2(foot - Vector2(frame_size.x * 0.5, 108.0) * pixel_scale, frame_size * pixel_scale)
	draw_texture_rect_region(texture, destination, Rect2(float(frame % 4) * 128.0, 0.0, 128.0, 120.0), tint)

func _draw_ridge(viewport_size: Vector2, base_y: float, amplitude: float, color: Color, phase: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var step: float = 18.0
	var x: float = 0.0
	while x <= viewport_size.x + step:
		var wave: float = sin(x * 0.006 + phase) * 0.55 + sin(x * 0.017 + phase * 2.3) * 0.3 + sin(x * 0.041 + phase * 0.7) * 0.15
		points.append(Vector2(x, roundf((base_y - (wave * 0.5 + 0.5) * amplitude) / 6.0) * 6.0))
		x += step
	points.append(Vector2(viewport_size.x + step, viewport_size.y))
	points.append(Vector2(0.0, viewport_size.y))
	draw_colored_polygon(points, color)

func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var compact_layout: bool = viewport_size.x < 900.0
	var pixel_scale: float = float(maxi(1, int(viewport_size.y / 540.0)))
	var horizon: float = viewport_size.y * 0.74
	# céu em faixas (do negro violeta ao horizonte empoeirado)
	var sky_bands: int = 28
	for band: int in sky_bands:
		var band_top: float = horizon * float(band) / float(sky_bands)
		var band_height: float = horizon / float(sky_bands) + 1.0
		var blend: float = pow(float(band) / float(sky_bands - 1), 1.7)
		draw_rect(Rect2(0.0, band_top, viewport_size.x, band_height), Color(0.035, 0.026, 0.07).lerp(Color(0.62, 0.22, 0.14), blend))
	for index: int in 80:
		var star_x: float = fposmod(float(index * 197 + 41), maxf(1.0, viewport_size.x))
		var star_y: float = fposmod(float(index * 113 + 27), maxf(1.0, horizon * 0.7))
		var twinkle: float = 0.5 + 0.5 * sin(background_time * (0.7 + float(index % 5) * 0.16) + float(index))
		var star_size: float = 3.0 if index % 9 == 0 else 2.0
		draw_rect(Rect2(roundf(star_x), roundf(star_y), star_size, star_size), Color(1.0, 0.86, 0.7, twinkle * 0.8))
	# sol pálido com halo azul (pôr do sol marciano) e lua Fobos
	var sun: Vector2 = Vector2(viewport_size.x * (0.74 if not compact_layout else 0.5), horizon - 34.0 * pixel_scale)
	for halo: int in 6:
		draw_circle(sun, (70.0 - float(halo) * 10.0) * pixel_scale, Color(0.45, 0.68, 1.0, 0.05 + float(halo) * 0.012))
	draw_circle(sun, 13.0 * pixel_scale, Color(0.82, 0.92, 1.0))
	draw_circle(sun, 9.0 * pixel_scale, Color(1.0, 1.0, 1.0))
	var moon: Vector2 = Vector2(viewport_size.x * 0.88, horizon * 0.28 + sin(background_time * 0.2) * 3.0)
	draw_circle(moon, 14.0 * pixel_scale, Color(0.52, 0.4, 0.38))
	draw_circle(moon + Vector2(-4.0, -4.0) * pixel_scale, 9.0 * pixel_scale, Color(0.66, 0.52, 0.48))
	draw_circle(moon + Vector2(5.0, 3.0) * pixel_scale, 3.0 * pixel_scale, Color(0.38, 0.28, 0.28))
	# montanhas em 3 camadas
	_draw_ridge(viewport_size, horizon + 4.0, 90.0 * pixel_scale * 0.5, Color(0.36, 0.13, 0.13), 0.7)
	_draw_ridge(viewport_size, horizon + 14.0, 70.0 * pixel_scale * 0.5, Color(0.25, 0.085, 0.095), 2.1)
	_draw_ridge(viewport_size, horizon + 26.0, 44.0 * pixel_scale * 0.5, Color(0.16, 0.055, 0.07), 4.4)
	# chão (textura do jogo) com escurecimento em direção à base
	var ground_top: float = horizon + 26.0
	var tile_size: float = 48.0 * pixel_scale
	var tile_x: float = 0.0
	var tile_index: int = 0
	while tile_x < viewport_size.x:
		var tile_y: float = ground_top
		var row: int = 0
		while tile_y < viewport_size.y:
			var variant: int = (tile_index * 3 + row * 5) % 4
			draw_texture_rect_region(GROUND_TEXTURE, Rect2(tile_x, tile_y, tile_size, tile_size), Rect2(float(variant) * 48.0, 0.0, 48.0, 48.0), Color(0.62, 0.42, 0.4))
			tile_y += tile_size
			row += 1
		tile_x += tile_size
		tile_index += 1
	for fade: int in 8:
		draw_rect(Rect2(0.0, ground_top + (viewport_size.y - ground_top) * float(fade) / 8.0, viewport_size.x, (viewport_size.y - ground_top) / 8.0 + 1.0), Color(0.03, 0.01, 0.02, 0.1 + 0.07 * float(fade)))
	draw_line(Vector2(0.0, ground_top), Vector2(viewport_size.x, ground_top), Color(1.0, 0.5, 0.3, 0.35), 2.0)
	# personagens: ordenados por profundidade (pé mais baixo na frente)
	var ground_span: float = viewport_size.y - ground_top
	var frame_tick: int = int(background_time * 8.0)
	var scene_x: float = viewport_size.x * (0.74 if not compact_layout else 0.5)
	var ship_foot: Vector2 = Vector2(scene_x + 190.0 * pixel_scale * (0.0 if compact_layout else 1.0), ground_top + ground_span * 0.42)
	draw_circle(ship_foot + Vector2(0.0, 2.0), 38.0 * pixel_scale, Color(0.05, 0.01, 0.02, 0.35))
	var ship_size: Vector2 = SHIP_TEXTURE.get_size() * pixel_scale * 2.4
	draw_texture_rect(SHIP_TEXTURE, Rect2(ship_foot - Vector2(ship_size.x * 0.5, ship_size.y - 4.0), ship_size), false)
	var blink: float = 1.0 if fmod(background_time, 1.2) < 0.25 else 0.2
	draw_circle(ship_foot + Vector2(-58.0, -52.0) * pixel_scale, 3.0 * pixel_scale, Color(1.0, 0.25, 0.2, blink))
	draw_circle(ship_foot + Vector2(58.0, -52.0) * pixel_scale, 3.0 * pixel_scale, Color(0.3, 1.0, 0.5, blink))
	var player_foot: Vector2 = Vector2(scene_x - 20.0 * pixel_scale, ground_top + ground_span * 0.6)
	var actors: Array[Dictionary] = []
	actors.append({"foot": player_foot, "kind": "player"})
	for enemy_index: int in SCENE_ENEMIES.size():
		var sway: float = sin(background_time * (0.22 + float(enemy_index) * 0.05) + float(enemy_index) * 1.9)
		var enemy_foot: Vector2 = Vector2(
			scene_x - 250.0 * pixel_scale * (0.65 + 0.28 * float(enemy_index)) + sway * 60.0 * pixel_scale,
			ground_top + ground_span * (0.5 + 0.14 * float(enemy_index % 3))
		)
		actors.append({"foot": enemy_foot, "kind": "enemy", "index": enemy_index})
	actors.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return (first["foot"] as Vector2).y < (second["foot"] as Vector2).y
	)
	for actor: Dictionary in actors:
		var foot: Vector2 = actor["foot"]
		if actor["kind"] == "player":
			var idle_bob: float = sin(background_time * 3.0) * 1.5 * pixel_scale
			_draw_sheet_frame(PLAYER_SHEET, 0, foot + Vector2(0.0, idle_bob * 0.0), pixel_scale)
		else:
			var enemy_texture: Texture2D = SCENE_ENEMIES[int(actor["index"])]
			_draw_sheet_frame(enemy_texture, frame_tick + int(actor["index"]) * 2, foot, pixel_scale * 0.85)
	# tiro do astronauta atravessando a cena
	var shot_time: float = fmod(background_time, 3.4)
	if shot_time < 1.2:
		var shot_x: float = player_foot.x - 40.0 * pixel_scale - shot_time * 900.0
		var shot_rect: Rect2 = Rect2(shot_x, player_foot.y - 52.0 * pixel_scale, 76.0 * pixel_scale * 0.5, 14.0 * pixel_scale)
		draw_texture_rect(LASER_TEXTURE, shot_rect, false, Color(1.0, 0.8, 0.6, 1.0 - shot_time / 1.2))
	# poeira em suspensão
	for mote: int in 36:
		var mote_x: float = fposmod(float(mote * 131) - background_time * (10.0 + float(mote % 5) * 4.0), maxf(1.0, viewport_size.x))
		var mote_y: float = fposmod(float(mote * 89) + sin(background_time * 0.4 + float(mote)) * 14.0, maxf(1.0, viewport_size.y))
		draw_rect(Rect2(roundf(mote_x), roundf(mote_y), 2.0, 2.0), Color(1.0, 0.62, 0.42, 0.22))
	# detalhes de moldura
	draw_line(Vector2(28.0, 28.0), Vector2(84.0, 28.0), Color(1.0, 0.57, 0.3, 0.82), 2.0)
	draw_line(Vector2(viewport_size.x - 84.0, 28.0), Vector2(viewport_size.x - 28.0, 28.0), Color(1.0, 0.57, 0.3, 0.48), 1.0)
	for vignette_step: int in 10:
		var inset: float = float(vignette_step) * 12.0 + 6.0
		draw_rect(
			Rect2(inset, inset, viewport_size.x - inset * 2.0, viewport_size.y - inset * 2.0),
			Color(0.0, 0.0, 0.0, 0.055),
			false,
			12.0
		)

func _show_main() -> void:
	current_page = "main"
	var box: VBoxContainer = _new_panel(
		"FALLEN ASTRO",
		"MARTE  /  SETOR 09-A",
		true
	)
	var campaign_status: Label = Label.new()
	campaign_status.text = "RECORDE  %06d   ·   PEÇAS  %d/4" % [
		GameState.high_score,
		GameState.ship_parts.size()
	]
	campaign_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	campaign_status.add_theme_font_size_override("font_size", roundi(14.0 * _ui_scale()))
	campaign_status.add_theme_color_override("font_color", UIStyle.ACCENT)
	box.add_child(campaign_status)
	box.add_child(_new_menu_divider())
	var new_game_button: Button = _add_button(box, "NOVA CAMPANHA", _show_difficulty)
	UIStyle.style_button(new_game_button, "primary")
	new_game_button.custom_minimum_size.y = 54.0 * _ui_scale()
	new_game_button.grab_focus()
	var continue_button: Button = _add_button(box, "CONTINUAR", _continue_campaign)
	continue_button.disabled = not GameState.load_campaign()
	if continue_button.disabled:
		continue_button.tooltip_text = "Nenhuma campanha salva disponível."
	box.add_child(_new_menu_divider())
	_add_button(box, "AJUSTES", _show_settings)
	_add_button(box, "CRÉDITOS", _show_credits)
	_add_button(box, "SAIR", _quit)

func _show_difficulty() -> void:
	current_page = "difficulty"
	var box: VBoxContainer = _new_panel(
		"Dificuldade",
		"RISCO DA EXPEDIÇÃO"
	)
	var options: Array[Dictionary] = [
		{"id": "easy", "label": "FÁCIL", "details": "4 VIDAS  ·  LEVE"},
		{"id": "medium", "label": "MÉDIO", "details": "3 VIDAS  ·  PADRÃO"},
		{"id": "hard", "label": "DIFÍCIL", "details": "3 VIDAS  ·  INTENSO"},
		{"id": "hardcore", "label": "HARDCORE", "details": "2 VIDAS  ·  EXTREMO"}
	]
	var threat_icons: Array[int] = [0, 1, 7, 8]
	var threat_colors: Array[Color] = [UIStyle.GOOD, UIStyle.WARN, Color(1.0, 0.5, 0.25), UIStyle.DANGER]
	for option_index: int in options.size():
		var option: Dictionary = options[option_index]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var threat_icon: TextureRect = _new_icon(threat_icons[option_index], Vector2(30, 30) * _ui_scale())
		threat_icon.modulate = threat_colors[option_index]
		row.add_child(threat_icon)
		var details: Label = Label.new()
		details.text = str(option["details"])
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		details.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale()))
		details.add_theme_color_override("font_color", threat_colors[option_index].lerp(UIStyle.TEXT, 0.35))
		row.add_child(details)
		box.add_child(row)
		var difficulty_id: String = str(option["id"])
		_add_button(box, str(option["label"]), _new_campaign.bind(difficulty_id))
	_add_button(box, "VOLTAR", _show_main)

func _show_settings() -> void:
	current_page = "settings"
	var box: VBoxContainer = _new_panel("AJUSTES", "ÁUDIO  /  VÍDEO")
	_add_slider(box, "Volume geral", "master_volume")
	_add_slider(box, "Música", "music_volume")
	_add_slider(box, "Efeitos sonoros", "sfx_volume")
	var fullscreen: CheckBox = CheckBox.new()
	fullscreen.text = "Tela cheia"
	fullscreen.button_pressed = bool(GameState.settings["fullscreen"])
	fullscreen.toggled.connect(func(enabled: bool) -> void:
		GameState.settings["fullscreen"] = enabled
		AudioManager.apply_settings()
	)
	box.add_child(fullscreen)
	var resolution: OptionButton = OptionButton.new()
	for item: Dictionary in [
		{"label": "1280 × 720", "size": Vector2i(1280, 720)},
		{"label": "1600 × 900", "size": Vector2i(1600, 900)},
		{"label": "1920 × 1080", "size": Vector2i(1920, 1080)}
	]:
		resolution.add_item(item["label"])
		resolution.set_item_metadata(resolution.item_count - 1, item["size"])
	var current_resolution: Vector2i = GameState.settings["resolution"]
	for index: int in resolution.item_count:
		if resolution.get_item_metadata(index) == current_resolution:
			resolution.select(index)
	resolution.item_selected.connect(func(index: int) -> void:
		GameState.settings["resolution"] = resolution.get_item_metadata(index)
	)
	box.add_child(_labeled_control("Resolução", resolution))
	_add_button(box, "APLICAR", func() -> void:
		GameState.save_settings()
		AudioManager.apply_settings()
	)
	_add_button(box, "PADRÕES", _restore_defaults)
	_add_button(box, "VOLTAR", _show_main)

func _show_credits() -> void:
	current_page = "credits"
	var box: VBoxContainer = _new_panel(
		"CRÉDITOS",
		"FALLEN ASTRO  ·  ASTROLOPE\n\nARTE, CÓDIGO E ÁUDIO DO PROJETO.\n\nMade by AstroLope"
	)
	_add_button(box, "VOLTAR", _show_main)

func _restore_defaults() -> void:
	GameState.settings = {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.8,
		"fullscreen": false,
		"resolution": Vector2i(1280, 720)
	}
	GameState.save_settings()
	AudioManager.apply_settings()
	_show_settings()

func _new_campaign(difficulty: String) -> void:
	GameState.set_difficulty(difficulty)
	GameState.start_new_campaign()
	_transition_to("res://Scenes/game.tscn")

func _continue_campaign() -> void:
	if GameState.load_campaign():
		_transition_to("res://Scenes/game.tscn")

func _quit() -> void:
	get_tree().quit()

func _transition_to(path: String) -> void:
	var fade: ColorRect = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_layer.add_child(fade)
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.25)
	tween.tween_callback(func() -> void:
		var error: int = get_tree().change_scene_to_file(path)
		if error != OK:
			push_error("Não foi possível abrir a cena %s: %s" % [path, error_string(error)])
	)

func _new_panel(title: String, subtitle: String, is_main_menu: bool = false) -> VBoxContainer:
	if is_instance_valid(screen_root):
		screen_root.queue_free()
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_size: Vector2 = get_viewport_rect().size
	var ui_scale: float = _ui_scale()
	add_child(screen_root)
	panel = PanelContainer.new()
	panel.name = "MissionPanel"
	var panel_width: float = minf(560.0, maxf(300.0, viewport_size.x - 32.0))
	panel_width = minf(panel_width, 500.0) if viewport_size.x >= 900.0 else panel_width
	var left_aligned: bool = viewport_size.x >= 900.0
	panel.anchor_left = 0.0 if left_aligned else 0.5
	panel.anchor_top = 0.035 if is_main_menu else 0.07
	panel.anchor_right = 0.0 if left_aligned else 0.5
	panel.anchor_bottom = 0.965 if is_main_menu else 0.93
	panel.offset_left = 40.0 if left_aligned else -panel_width * 0.5
	panel.offset_right = 40.0 + panel_width if left_aligned else panel_width * 0.5
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(UIStyle.PANEL_BG, UIStyle.BORDER)
	)
	screen_root.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", roundi(22.0 * ui_scale))
	margin.add_theme_constant_override("margin_right", roundi(22.0 * ui_scale))
	margin.add_theme_constant_override("margin_top", roundi(22.0 * ui_scale))
	margin.add_theme_constant_override("margin_bottom", roundi(20.0 * ui_scale))
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Content"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", roundi(8.0 * ui_scale))
	scroll.add_child(box)
	var heading: Label = Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_theme_font_size_override(
		"font_size",
		roundi(float(40 if is_main_menu else 28) * ui_scale)
	)
	UIStyle.apply_font(heading, UIStyle.title_font())
	heading.add_theme_color_override("font_color", UIStyle.CREAM)
	heading.add_theme_color_override("font_outline_color", Color(0.36, 0.1, 0.05))
	heading.add_theme_constant_override("outline_size", roundi(8.0 * ui_scale) if is_main_menu else roundi(4.0 * ui_scale))
	box.add_child(heading)
	if is_main_menu:
		var title_pulse: Tween = heading.create_tween().set_loops()
		title_pulse.tween_property(heading, "modulate", Color(1.0, 0.86, 0.72), 1.6).set_trans(Tween.TRANS_SINE)
		title_pulse.tween_property(heading, "modulate", Color.WHITE, 1.6).set_trans(Tween.TRANS_SINE)
	var caption: Label = Label.new()
	caption.text = subtitle
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", roundi(11.0 * ui_scale))
	caption.add_theme_color_override("font_color", UIStyle.DATA)
	box.add_child(caption)
	box.add_child(_new_menu_divider())
	if is_main_menu:
		var controls: Label = Label.new()
		controls.text = (
			"WASD  mover  ·  Mouse  mirar\n"
			+ "1–3 armas  ·  R esquiva  ·  T recarga\n"
			+ "Q/F habilidades  ·  E nave  ·  ESC pausa"
		)
		controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls.add_theme_font_size_override("font_size", roundi(11.0 * ui_scale))
		controls.add_theme_color_override("font_color", UIStyle.MUTED)
		box.add_child(controls)
		var credit: Label = Label.new()
		credit.text = "MADE BY ASTROLOPE"
		credit.add_theme_font_size_override("font_size", roundi(10.0 * ui_scale))
		credit.add_theme_color_override("font_color", Color(0.78, 0.5, 0.36))
		box.add_child(credit)
	panel.modulate.a = 0.0
	var page_fade: Tween = panel.create_tween()
	page_fade.tween_property(panel, "modulate:a", 1.0, 0.22)
	return box

func _new_icon(icon_index: int, icon_size: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	var atlas_texture: AtlasTexture = AtlasTexture.new()
	atlas_texture.atlas = UI_ICONS
	atlas_texture.region = Rect2(icon_index * 16, 0, 16, 16)
	icon.texture = atlas_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = icon_size
	return icon

func _new_menu_divider() -> HSeparator:
	var divider: HSeparator = HSeparator.new()
	return divider

func _make_panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = UIStyle.panel_style()
	style.bg_color = background
	style.border_color = border
	return style

func _on_viewport_size_changed() -> void:
	menu_theme = _create_menu_theme()
	theme = menu_theme
	call_deferred("_refresh_current_page")

func _refresh_current_page() -> void:
	match current_page:
		"main":
			_show_main()
		"difficulty":
			_show_difficulty()
		"settings":
			_show_settings()
		"credits":
			_show_credits()

func _add_button(parent: VBoxContainer, title: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 44.0 * _ui_scale()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _add_slider(parent: VBoxContainer, title: String, setting: String) -> void:
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(GameState.settings[setting])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label: Label = Label.new()
	value_label.text = "%d%%" % roundi(slider.value * 100.0)
	value_label.custom_minimum_size.x = 48.0 * _ui_scale()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", UIStyle.ACCENT)
	slider.value_changed.connect(func(value: float) -> void:
		GameState.settings[setting] = value
		value_label.text = "%d%%" % roundi(value * 100.0)
		AudioManager.apply_settings()
	)
	var slider_row: HBoxContainer = HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 10)
	slider_row.add_child(slider)
	slider_row.add_child(value_label)
	parent.add_child(_labeled_control(title, slider_row))

func _labeled_control(title: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size.x = 145.0 * _ui_scale()
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _ui_scale() -> float:
	var viewport_width: float = get_viewport_rect().size.x
	var window_width: float = float(DisplayServer.window_get_size().x)
	return viewport_width / maxf(1.0, window_width)

func _create_menu_theme() -> Theme:
	return UIStyle.build_theme(_ui_scale())
