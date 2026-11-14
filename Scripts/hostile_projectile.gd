extends Area2D

const LIFETIME: float = 6.0
var speed: float = 260.0
var damage: int = 1
var direction: Vector2 = Vector2.RIGHT
var time_left: float = LIFETIME

func configure(aim: Vector2, velocity: float, hit_damage: int = 1) -> void:
	direction = aim.normalized()
	speed = velocity
	damage = hit_damage
	rotation = direction.angle()

var pulse_time: float = 0.0

func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(pulse_time * 18.0)
	draw_circle(Vector2.ZERO, 11.0 + pulse * 2.0, Color(1.0, 0.25, 0.12, 0.22))
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.45, 0.2, 0.45))
	draw_circle(Vector2(-6.0, 0.0), 3.5, Color(1.0, 0.3, 0.15, 0.3))

func _physics_process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()
	global_position += direction * speed * delta
	time_left -= delta
	if time_left <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.call("receive_damage", damage)
		queue_free()
