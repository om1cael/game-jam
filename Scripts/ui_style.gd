extends RefCounted
## Estilo visual compartilhado do FALLEN ASTRO (menu, HUD e overlays).
## Paleta marciana: tons quentes de ferrugem/âmbar com ciano apenas para dados.

const PANEL_BG: Color = Color(0.082, 0.04, 0.042, 0.96)
const PANEL_BG_SOLID: Color = Color(0.082, 0.04, 0.042, 0.99)
const BORDER: Color = Color(0.62, 0.28, 0.18)
const BORDER_BRIGHT: Color = Color(1.0, 0.64, 0.36)
const ACCENT: Color = Color(1.0, 0.62, 0.34)
const CREAM: Color = Color(0.97, 0.88, 0.74)
const TEXT: Color = Color(0.9, 0.8, 0.7)
const MUTED: Color = Color(0.72, 0.56, 0.48)
const DATA: Color = Color(0.36, 0.84, 0.82)
const GOOD: Color = Color(0.45, 0.85, 0.55)
const WARN: Color = Color(1.0, 0.76, 0.3)
const DANGER: Color = Color(0.93, 0.29, 0.22)
const OUTLINE: Color = Color(0.05, 0.02, 0.02, 0.92)

static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null

static func body_font() -> Font:
	return _load_font("res://fonts/Poppins-Medium.ttf")

static func title_font() -> Font:
	return _load_font("res://fonts/Poppins-Bold.ttf")

static func mono_font() -> Font:
	return _load_font("res://fonts/DejaVuSansMono-Bold.ttf")

static func apply_font(control: Control, font: Font) -> void:
	if font != null:
		control.add_theme_font_override("font", font)

static func box(bg: Color, border: Color, border_left: int = 1, corner: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = border_left
	style.set_corner_radius_all(corner)
	return style

static func panel_style(solid: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(PANEL_BG_SOLID if solid else PANEL_BG, BORDER, 4, 3)
	style.border_width_top = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 18
	return style

static func hud_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = box(Color(0.075, 0.036, 0.038, 0.88), BORDER, 3, 2)
	style.border_width_top = 2
	style.border_color = Color(0.62, 0.28, 0.18, 0.9)
	return style

static func bar_background() -> StyleBoxFlat:
	var style: StyleBoxFlat = box(Color(0.03, 0.016, 0.018, 0.98), Color(0.4, 0.19, 0.13, 0.9), 1, 1)
	return style

static func bar_fill(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(1)
	style.border_width_bottom = 2
	style.border_color = color.darkened(0.35)
	return style

static func health_color(ratio: float) -> Color:
	if ratio > 0.6:
		return GOOD
	if ratio > 0.34:
		return WARN
	return DANGER

static func button_styles(kind: String = "normal") -> Dictionary:
	var base: Color = Color(0.13, 0.062, 0.058, 0.98)
	var edge: Color = BORDER
	var hover_bg: Color = Color(0.26, 0.11, 0.075, 1.0)
	if kind == "primary":
		base = Color(0.5, 0.2, 0.12, 1.0)
		edge = BORDER_BRIGHT
		hover_bg = Color(0.68, 0.28, 0.16, 1.0)
	elif kind == "danger":
		base = Color(0.22, 0.06, 0.06, 1.0)
		edge = DANGER
		hover_bg = Color(0.38, 0.09, 0.08, 1.0)
	var normal: StyleBoxFlat = box(base, edge, 3)
	var hover: StyleBoxFlat = box(hover_bg, BORDER_BRIGHT, 6)
	var pressed: StyleBoxFlat = box(hover_bg.darkened(0.3), CREAM, 6)
	var focus: StyleBoxFlat = box(Color(0.0, 0.0, 0.0, 0.0), CREAM, 6)
	focus.draw_center = false
	var disabled: StyleBoxFlat = box(Color(0.07, 0.04, 0.04, 0.7), Color(0.25, 0.14, 0.12, 0.7), 3)
	for style: StyleBoxFlat in [normal, hover, pressed, disabled]:
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"focus": focus,
		"disabled": disabled
	}

static func style_button(button: Button, kind: String = "normal") -> void:
	var styles: Dictionary = button_styles(kind)
	for state: String in styles:
		button.add_theme_stylebox_override(state, styles[state] as StyleBox)
	button.add_theme_color_override("font_color", CREAM if kind == "primary" else TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.33, 0.3))

static func build_theme(ui_scale: float) -> Theme:
	var result: Theme = Theme.new()
	var body: Font = body_font()
	var title: Font = title_font()
	if body != null:
		result.default_font = body
	result.default_font_size = roundi(15.0 * ui_scale)
	if title != null:
		result.set_font("font", "Button", title)
		result.set_font("font", "OptionButton", title)
	var styles: Dictionary = button_styles("normal")
	for state: String in styles:
		result.set_stylebox(state, "Button", styles[state] as StyleBox)
		result.set_stylebox(state, "OptionButton", (styles[state] as StyleBox).duplicate() as StyleBox)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_focus_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color(0.45, 0.33, 0.3))
	result.set_font_size("font_size", "Button", roundi(16.0 * ui_scale))
	result.set_color("font_color", "Label", TEXT)
	result.set_font_size("font_size", "Label", roundi(15.0 * ui_scale))
	result.set_color("font_color", "CheckBox", TEXT)
	result.set_color("font_hover_color", "CheckBox", CREAM)
	result.set_font_size("font_size", "CheckBox", roundi(15.0 * ui_scale))
	result.set_color("font_color", "OptionButton", TEXT)
	result.set_color("font_hover_color", "OptionButton", CREAM)
	result.set_font_size("font_size", "OptionButton", roundi(15.0 * ui_scale))
	var popup_panel: StyleBoxFlat = box(PANEL_BG_SOLID, BORDER_BRIGHT, 1, 2)
	popup_panel.content_margin_left = 6.0
	popup_panel.content_margin_right = 6.0
	popup_panel.content_margin_top = 6.0
	popup_panel.content_margin_bottom = 6.0
	result.set_stylebox("panel", "PopupMenu", popup_panel)
	result.set_stylebox("hover", "PopupMenu", box(Color(0.3, 0.13, 0.08, 1.0), BORDER_BRIGHT, 3, 1))
	result.set_color("font_color", "PopupMenu", TEXT)
	result.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	result.set_font_size("font_size", "PopupMenu", roundi(15.0 * ui_scale))
	var slider_track: StyleBoxFlat = box(Color(0.03, 0.016, 0.018, 1.0), Color(0.4, 0.19, 0.13), 1, 2)
	slider_track.content_margin_top = 4.0
	slider_track.content_margin_bottom = 4.0
	var slider_fill: StyleBoxFlat = box(Color(0.86, 0.42, 0.22), Color(0.86, 0.42, 0.22), 1, 2)
	slider_fill.content_margin_top = 4.0
	slider_fill.content_margin_bottom = 4.0
	var slider_fill_hot: StyleBoxFlat = slider_fill.duplicate() as StyleBoxFlat
	slider_fill_hot.bg_color = ACCENT
	slider_fill_hot.border_color = ACCENT
	result.set_stylebox("slider", "HSlider", slider_track)
	result.set_stylebox("grabber_area", "HSlider", slider_fill)
	result.set_stylebox("grabber_area_highlight", "HSlider", slider_fill_hot)
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = Color(0.62, 0.28, 0.18, 0.7)
	line.thickness = 1
	result.set_stylebox("separator", "HSeparator", line)
	result.set_constant("separation", "HSeparator", roundi(10.0 * ui_scale))
	return result
