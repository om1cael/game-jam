extends Area2D

const SPEED: float = 800.0
const MAX_LIFETIME: float = 1.8

var damage: int = 12
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = MAX_LIFETIME

func set_direction(value: Vector2) -> void:
	direction = value.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
