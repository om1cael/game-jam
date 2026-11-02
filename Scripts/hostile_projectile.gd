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

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	time_left -= delta
	if time_left <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.call("receive_damage", damage)
		queue_free()
