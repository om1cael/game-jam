extends Control

var target_world_position: Vector2 = Vector2.ZERO
var player_world_position: Vector2 = Vector2.ZERO

func set_positions(target: Vector2, player: Vector2) -> void:
	target_world_position = target
	player_world_position = player
	queue_redraw()

func _draw() -> void:
	var world_distance: float = player_world_position.distance_to(target_world_position)
	if world_distance < 120.0:
		return
	var world_direction: Vector2 = player_world_position.direction_to(target_world_position)
	var screen_direction: Vector2 = get_viewport().get_canvas_transform().basis_xform(world_direction).normalized()
	if screen_direction.is_zero_approx():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_size: Vector2 = viewport_size * 0.5
	var horizontal_limit: float = (half_size.x - 42.0) / maxf(absf(screen_direction.x), 0.001)
	var vertical_limit: float = (half_size.y - 54.0) / maxf(absf(screen_direction.y), 0.001)
	var edge_distance: float = minf(horizontal_limit, vertical_limit)
	var marker_position: Vector2 = half_size + screen_direction * edge_distance
	marker_position = Vector2(roundf(marker_position.x / 4.0) * 4.0, roundf(marker_position.y / 4.0) * 4.0)
	var rotation_angle: float = roundf((screen_direction.angle() + PI * 0.5) / (PI * 0.25)) * (PI * 0.25)
	draw_set_transform(marker_position, rotation_angle, Vector2.ONE)
	var pixel_rows: Array[Vector2i] = [
		Vector2i(-1, -5), Vector2i(-2, -4), Vector2i(-3, -3),
		Vector2i(-4, -2), Vector2i(-1, -1), Vector2i(-1, 0),
		Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3)
	]
	for pixel: Vector2i in pixel_rows:
		draw_rect(Rect2(Vector2(pixel.x * 4 - 2, pixel.y * 4 - 2), Vector2(8, 8)), Color(0.12, 0.045, 0.035, 0.95))
	for pixel: Vector2i in pixel_rows:
		draw_rect(Rect2(Vector2(pixel.x * 4, pixel.y * 4), Vector2(4, 4)), Color(1.0, 0.61, 0.32))
	draw_rect(Rect2(Vector2(-1, -1), Vector2(4, 4)), Color(1.0, 0.88, 0.65))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var distance_text: String = "%dm" % roundi(world_distance / 32.0)
	draw_string(ThemeDB.fallback_font, marker_position + Vector2(16, 5), distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 0.78, 0.54))
