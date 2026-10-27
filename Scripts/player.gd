extends CharacterBody2D

var lifes = 3
const SPEED = 150.0

func _process(delta: float) -> void:
	var global_mouse_pos = get_global_mouse_position()
	
	if $GunPivot.global_position.distance_to(global_mouse_pos) > 50:
		$GunPivot.look_at(get_global_mouse_position())
	
	var gun_pivot_rotation = abs($GunPivot.global_rotation_degrees)
	
	$AnimatedSprite2D.flip_h = gun_pivot_rotation > 90
	$GunPivot/Gun/Sprite2D.flip_v = gun_pivot_rotation > 90

func _physics_process(delta: float) -> void:
	if lifes <= 0: return
	var direction := Input.get_vector("left", "right", "up", "down")
	
	if direction:
		$AnimatedSprite2D.play("walking")
		velocity = direction * SPEED
	else:
		$AnimatedSprite2D.play("default")
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)

	move_and_slide()

func receive_damage(damage: int) -> void:
	lifes -= damage
	$LifeIndicator.value = lifes
	
	if lifes <= 0:
		$AnimatedSprite2D.visible = false
		
		$CollisionShape2D.set_deferred("disabled", true)
		$HitReceiver/CollisionShape2D.set_deferred("disabled", true)
		$GunPivot.visible = false
		$LifeIndicator.visible = false
		
		$DeathParticle.emitting = true

func _on_hit_receiver_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		receive_damage(1)
