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
	queue_free()

func _draw() -> void:
	var pulse: float = 0.15 + 0.08 * sin(animation_time * 4.0)
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color(0.12, 0.95, 0.68, pulse))
	draw_rect(Rect2(Vector2(-12, -12), Vector2(24, 24)), Color(0.04, 0.2, 0.2))
	draw_rect(Rect2(Vector2(-8, -8), Vector2(16, 16)), Color(0.78, 0.98, 0.84))
	draw_rect(Rect2(Vector2(-4, -12), Vector2(8, 24)), Color(0.15, 0.82, 0.53))
	draw_rect(Rect2(Vector2(-12, -4), Vector2(24, 8)), Color(0.15, 0.82, 0.53))
