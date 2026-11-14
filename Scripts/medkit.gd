extends Area2D

const HEAL_AMOUNT: float = 1.0
const LIFETIME: float = 24.0

var lifetime: float = LIFETIME
var animation_time: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	lifetime -= delta
	animation_time += delta
	position.y = base_y + sin(animation_time * 3.0) * 3.0
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or bool(body.get("is_dead")):
		return
	body.call("heal", HEAL_AMOUNT)
	AudioManager.play_sfx("pickup")
	queue_free()

const MEDKIT_TEXTURE: Texture2D = preload("res://Sprites/medkit.png")

func _draw() -> void:
	var pulse: float = 0.16 + 0.1 * sin(animation_time * 4.0)
	var fading: float = 1.0
	if lifetime < 4.0:
		fading = 0.45 + 0.55 * absf(sin(animation_time * 10.0))
	draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.95, 0.55, pulse * fading))
	draw_circle(Vector2.ZERO, 15.0, Color(0.2, 0.95, 0.55, pulse * 1.4 * fading))
	draw_texture(MEDKIT_TEXTURE, -MEDKIT_TEXTURE.get_size() * 0.5, Color(1, 1, 1, fading))
