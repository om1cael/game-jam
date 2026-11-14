extends Node2D

const SHIP_TEXTURE: Texture2D = preload("res://Sprites/ship.png")

var animation_time: float = 0.0

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func _draw() -> void:
	var flicker: float = 0.55 + 0.2 * sin(animation_time * 9.0) + 0.1 * sin(animation_time * 23.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, 8), 46.0, Color(0.1, 0.03, 0.03, 0.28))
	var base_position: Vector2 = Vector2(-SHIP_TEXTURE.get_width() * 0.5, -SHIP_TEXTURE.get_height() * 0.5 - 2.0)
	draw_texture(SHIP_TEXTURE, base_position)
	# chama do motor
	var flame_top: float = base_position.y + SHIP_TEXTURE.get_height() - 2.0
	draw_rect(Rect2(-9.0, flame_top, 18.0, 14.0 * flicker + 6.0), Color(1.0, 0.42, 0.16, 0.55))
	draw_rect(Rect2(-5.0, flame_top, 10.0, 12.0 * flicker + 4.0), Color(1.0, 0.82, 0.5, 0.85))
	# luz de navegação piscando
	var blink: float = 1.0 if fmod(animation_time, 1.2) < 0.25 else 0.25
	draw_rect(Rect2(-26.0, 22.0, 4.0, 4.0), Color(1.0, 0.25, 0.2, blink))
	draw_rect(Rect2(22.0, 22.0, 4.0, 4.0), Color(0.3, 1.0, 0.5, blink))
