extends Control

var panel: PanelContainer
var screen_root: CenterContainer
var transition_layer: CanvasLayer
var background_time: float = 0.0
var menu_theme: Theme

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_theme = _create_menu_theme()
	theme = menu_theme
	AudioManager.play_menu_music()
	transition_layer = CanvasLayer.new()
	add_child(transition_layer)
	_show_main()

func _process(delta: float) -> void:
	background_time += delta
	queue_redraw()

func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for band: int in 12:
		var band_top: float = viewport_size.y * float(band) / 12.0
		var band_bottom: float = viewport_size.y * float(band + 1) / 12.0
		var blend: float = float(band) / 11.0
		draw_rect(
			Rect2(0.0, band_top, viewport_size.x, band_bottom - band_top + 1.0),
			Color(0.075, 0.025, 0.045).lerp(Color(0.26, 0.085, 0.07), blend)
		)
	for index: int in 52:
		var x: float = fposmod(float(index * 197 + 41), maxf(1.0, viewport_size.x))
		var y: float = fposmod(float(index * 113 + 27), maxf(1.0, viewport_size.y * 0.82))
		var twinkle: float = 0.55 + 0.45 * sin(background_time * (0.7 + float(index % 5) * 0.16) + float(index))
		draw_circle(Vector2(x, y), 0.8 + float(index % 3) * 0.45, Color(1.0, 0.74, 0.53, twinkle * 0.62))
	var planet_center: Vector2 = Vector2(viewport_size.x * 0.82, viewport_size.y * 0.37)
	var planet_radius: float = minf(viewport_size.x, viewport_size.y) * 0.18
	draw_circle(planet_center, planet_radius * 1.16, Color(0.92, 0.25, 0.11, 0.08))
	draw_circle(planet_center, planet_radius, Color(0.48, 0.16, 0.12))
	draw_circle(planet_center + Vector2(-planet_radius * 0.18, -planet_radius * 0.22), planet_radius * 0.62, Color(0.75, 0.27, 0.16, 0.55))
	draw_arc(planet_center, planet_radius, PI, TAU, 64, Color(1.0, 0.62, 0.34, 0.72), 2.0, true)
	var horizon: float = viewport_size.y * 0.82
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, horizon + 16.0),
		Vector2(viewport_size.x * 0.16, horizon - 26.0),
		Vector2(viewport_size.x * 0.3, horizon + 9.0),
		Vector2(viewport_size.x * 0.47, horizon - 39.0),
		Vector2(viewport_size.x * 0.62, horizon + 6.0),
		Vector2(viewport_size.x * 0.8, horizon - 30.0),
		Vector2(viewport_size.x, horizon + 10.0),
		Vector2(viewport_size.x, viewport_size.y),
		Vector2(0.0, viewport_size.y)
	]), Color(0.105, 0.035, 0.035, 0.94))
	draw_line(Vector2(0.0, horizon + 16.0), Vector2(viewport_size.x, horizon + 10.0), Color(0.88, 0.32, 0.15, 0.42), 1.0)
	draw_line(Vector2(28.0, 28.0), Vector2(78.0, 28.0), Color(1.0, 0.57, 0.3, 0.82), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 49.0), "MARS  /  SETOR 09", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.91, 0.63, 0.48, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(28.0, viewport_size.y - 24.0), "Made By AstroLope", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.96, 0.76, 0.63, 0.92))

func _show_main() -> void:
	var box: VBoxContainer = _new_panel("FALLEN ASTRO", "Sobreviva. Recupere sua nave. Encontre o caminho de volta.")
	var new_game_button: Button = _add_button(box, "Novo jogo", _new_campaign)
	var primary_style: StyleBoxFlat = StyleBoxFlat.new()
	primary_style.bg_color = Color(0.48, 0.19, 0.12)
	primary_style.border_color = Color(0.91, 0.48, 0.27)
	primary_style.set_border_width_all(1)
	primary_style.set_corner_radius_all(7)
	new_game_button.add_theme_stylebox_override("normal", primary_style)
	var primary_hover: StyleBoxFlat = primary_style.duplicate() as StyleBoxFlat
	primary_hover.bg_color = Color(0.61, 0.25, 0.15)
	primary_hover.set_border_width_all(2)
	new_game_button.add_theme_stylebox_override("hover", primary_hover)
	var continue_button: Button = _add_button(box, "Continuar", _continue_campaign)
	continue_button.disabled = not GameState.load_campaign()
	_add_button(box, "Configurações", _show_settings)
	_add_button(box, "Créditos", _show_credits)
	_add_button(box, "Sair", _quit)

func _show_settings() -> void:
	var box: VBoxContainer = _new_panel("Configurações", "Áudio e vídeo")
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
	_add_button(box, "Aplicar", func() -> void:
		GameState.save_settings()
		AudioManager.apply_settings()
	)
	_add_button(box, "Restaurar padrões", _restore_defaults)
	_add_button(box, "Voltar", _show_main)

func _show_credits() -> void:
	var box: VBoxContainer = _new_panel("Créditos", "FALLEN ASTRO\nTop-down survival shooter\n\nArte original do projeto preservada.\nMúsicas: intro.mp3 e in_game.mp3")
	_add_button(box, "Voltar", _show_main)

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

func _new_campaign() -> void:
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

func _new_panel(title: String, subtitle: String) -> VBoxContainer:
	if is_instance_valid(panel):
		panel.queue_free()
	if is_instance_valid(screen_root):
		screen_root.queue_free()
	screen_root = CenterContainer.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.105, 0.043, 0.04, 0.96)
	panel_style.border_color = Color(0.56, 0.25, 0.17, 0.88)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	screen_root.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var heading: Label = Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36 if title == "FALLEN ASTRO" else 27)
	heading.add_theme_color_override("font_color", Color(0.98, 0.76, 0.57))
	box.add_child(heading)
	if title == "FALLEN ASTRO":
		var edition: Label = Label.new()
		edition.text = "EXPEDIÇÃO DE SOBREVIVÊNCIA  /  SETOR 09"
		edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		edition.add_theme_font_size_override("font_size", 12)
		edition.add_theme_color_override("font_color", Color(0.83, 0.46, 0.32))
		box.add_child(edition)
	var caption: Label = Label.new()
	caption.text = subtitle
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color(0.83, 0.75, 0.68))
	box.add_child(caption)
	var separator: HSeparator = HSeparator.new()
	box.add_child(separator)
	if title == "FALLEN ASTRO":
		var controls: Label = Label.new()
		controls.text = "WASD  mover     Mouse  mirar e atirar\nR  rolar"
		controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls.add_theme_font_size_override("font_size", 13)
		controls.add_theme_color_override("font_color", Color(0.77, 0.61, 0.52))
		box.add_child(controls)
	return box

func _add_button(parent: VBoxContainer, title: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _add_slider(parent: VBoxContainer, title: String, setting: String) -> void:
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(GameState.settings[setting])
	slider.value_changed.connect(func(value: float) -> void:
		GameState.settings[setting] = value
		AudioManager.apply_settings()
	)
	parent.add_child(_labeled_control(title, slider))

func _labeled_control(title: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size.x = 145
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _create_menu_theme() -> Theme:
	var result: Theme = Theme.new()
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.073, 0.06, 0.96)
	normal.border_color = Color(0.48, 0.22, 0.15, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.12, 0.075, 0.99)
	hover.border_color = Color(0.86, 0.43, 0.23)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.4, 0.15, 0.09)
	pressed.border_color = Color(0.96, 0.61, 0.34)
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.095, 0.055, 0.05, 0.7)
	disabled.border_color = Color(0.25, 0.14, 0.12, 0.7)
	result.set_stylebox("normal", "Button", normal)
	result.set_stylebox("hover", "Button", hover)
	result.set_stylebox("pressed", "Button", pressed)
	result.set_stylebox("disabled", "Button", disabled)
	result.set_color("font_color", "Button", Color(0.95, 0.85, 0.75))
	result.set_color("font_hover_color", "Button", Color(1.0, 0.93, 0.81))
	result.set_color("font_pressed_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color(0.47, 0.39, 0.35))
	result.set_font_size("font_size", "Button", 16)
	result.set_color("font_color", "Label", Color(0.91, 0.83, 0.74))
	result.set_font_size("font_size", "Label", 15)
	result.set_color("font_color", "CheckBox", Color(0.91, 0.83, 0.74))
	result.set_font_size("font_size", "CheckBox", 15)
	result.set_color("font_color", "OptionButton", Color(0.95, 0.85, 0.75))
	result.set_font_size("font_size", "OptionButton", 15)
	return result
