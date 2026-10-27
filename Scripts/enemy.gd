extends CharacterBody2D

const SPEED = 100
var life = 100

@onready var player = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	$AnimatedSprite2D.play("default")

func _physics_process(delta: float) -> void:
	var direction = global_position.direction_to(player.global_position)
	
	if global_position.distance_to(player.global_position) > 40:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	
	$AnimatedSprite2D.flip_h = direction.x < 0
	move_and_slide()

func receive_damage(damage: int) -> void:
	life -= damage
	$LifeIndicator.value = life
	$AnimationPlayer.play("damage")
	
	if life <= 0:
		$AnimatedSprite2D.visible = false
		$LifeIndicator.visible = false
		
		$CollisionShape2D.set_deferred("disabled", true)
		$BulletArea/CollisionShape2D.set_deferred("disabled", true)
		
		$DeathParticle.emitting = true

func _on_death_particle_finished() -> void:
	queue_free()

func _on_bullet_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet"):
		var damage = area.damage
		
		receive_damage(damage)
		area.queue_free()
