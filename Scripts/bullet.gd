extends Area2D

const SPEED = 800
var damage = 8

func _physics_process(delta: float) -> void:
	position += transform.x * SPEED * delta


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
