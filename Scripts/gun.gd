extends Area2D

const bullet = preload("res://Scenes/bullet.tscn")

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	var shoot = Input.is_action_just_pressed("shoot")
	var can_shoot = get_tree().get_first_node_in_group("player").lifes > 0
	
	if shoot and can_shoot:
		var instance = bullet.instantiate()
		instance.global_position = $BulletSpawnPos.global_position
		instance.global_rotation = $BulletSpawnPos.global_rotation
		
		get_tree().current_scene.add_child(instance)
