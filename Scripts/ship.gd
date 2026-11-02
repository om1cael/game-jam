extends Node2D

var animation_time: float = 0.0

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func _draw() -> void:
	var engine_glow: float = 0.55 + 0.2 * sin(animation_time * 4.0)
	draw_circle(Vector2(0, 4), 38.0, Color(0.16, 0.055, 0.045, 0.32))
	draw_rect(Rect2(-36, -12, 12, 36), Color(0.24, 0.09, 0.075))
	draw_rect(Rect2(24, -12, 12, 36), Color(0.24, 0.09, 0.075))
	draw_rect(Rect2(-32, -8, 8, 28), Color(0.72, 0.28, 0.16))
	draw_rect(Rect2(24, -8, 8, 28), Color(0.72, 0.28, 0.16))
	draw_rect(Rect2(-28, -4, 8, 20), Color(0.94, 0.57, 0.32))
	draw_rect(Rect2(20, -4, 8, 20), Color(0.94, 0.57, 0.32))
	draw_rect(Rect2(-16, 24, 32, 12), Color(0.3, 0.105, 0.075))
	draw_rect(Rect2(-12, 24, 24, 8), Color(0.77, 0.3, 0.15))
	draw_rect(Rect2(-8, 32, 16, 12), Color(1.0, 0.42, 0.16, engine_glow))
	draw_rect(Rect2(-4, 36, 8, 8), Color(1.0, 0.8, 0.47, engine_glow))
	draw_rect(Rect2(-20, -16, 40, 40), Color(0.26, 0.09, 0.07))
	draw_rect(Rect2(-16, -24, 32, 44), Color(0.78, 0.31, 0.17))
	draw_rect(Rect2(-12, -32, 24, 40), Color(0.91, 0.54, 0.31))
	draw_rect(Rect2(-8, -40, 16, 12), Color(0.97, 0.75, 0.49))
	draw_rect(Rect2(-8, -24, 16, 16), Color(0.19, 0.23, 0.25))
	draw_rect(Rect2(-4, -20, 8, 8), Color(0.55, 0.83, 0.84))
	draw_rect(Rect2(-12, 0, 24, 8), Color(0.99, 0.78, 0.54))
	draw_rect(Rect2(-8, 8, 16, 8), Color(0.67, 0.22, 0.13))
	draw_rect(Rect2(-4, 12, 8, 4), Color(0.3, 0.105, 0.075))
