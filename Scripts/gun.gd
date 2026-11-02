extends Area2D

const BULLET_SCENE: PackedScene = preload("res://Scenes/bullet.tscn")
const FIRE_INTERVAL: float = 0.16
const MAX_ACTIVE_BULLETS: int = 80

var cooldown: float = 0.0

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or bool(player.get("is_dead")) or not Input.is_action_pressed("shoot"):
		return
	if cooldown > 0.0 or get_tree().get_nodes_in_group("bullet").size() >= MAX_ACTIVE_BULLETS:
		return
	var bullet: Area2D = BULLET_SCENE.instantiate()
	bullet.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = $BulletSpawnPos.global_position
	bullet.call("set_direction", get_global_mouse_position() - bullet.global_position)
	cooldown = FIRE_INTERVAL
