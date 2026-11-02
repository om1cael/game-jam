extends CharacterBody2D

signal died

const SPEED: float = 190.0
const MAX_LIFE: float = 3.0
const INVULNERABILITY_TIME: float = 0.9
const ROLL_SPEED: float = 570.0
const ROLL_DURATION: float = 0.24
const ROLL_COOLDOWN: float = 1.0
const ROLL_SQUASH_TIME: float = 0.08
const ROLL_STRETCH_TIME: float = 0.12

var lifes: float = MAX_LIFE
var invulnerability_timer: float = 0.0
var is_dead: bool = false
var roll_timer: float = 0.0
var roll_cooldown: float = 0.0
var roll_direction: Vector2 = Vector2.RIGHT
var base_sprite_scale: Vector2 = Vector2.ONE

@onready var gun_pivot: Node2D = $GunPivot
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var life_indicator: ProgressBar = $LifeIndicator

func _ready() -> void:
	life_indicator.max_value = MAX_LIFE
	life_indicator.value = lifes
	base_sprite_scale = animated_sprite.scale

func _process(_delta: float) -> void:
	if is_dead:
		return
	gun_pivot.look_at(get_global_mouse_position())
	var facing_left: bool = absf(gun_pivot.global_rotation_degrees) > 90.0
	animated_sprite.flip_h = facing_left
	$GunPivot/Gun/Sprite2D.flip_v = facing_left

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	animated_sprite.modulate = Color(1.0, 0.7, 0.38) if roll_timer > 0.0 else (Color(1.0, 0.48, 0.48, 1.0) if invulnerability_timer > 0.0 else Color.WHITE)
	var direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	if Input.is_action_just_pressed("dodge") and roll_cooldown <= 0.0:
		_start_roll(direction)
	if roll_timer > 0.0:
		roll_timer = maxf(0.0, roll_timer - delta)
		velocity = roll_direction * ROLL_SPEED
		var roll_elapsed: float = ROLL_DURATION - roll_timer
		if roll_elapsed < ROLL_SQUASH_TIME:
			animated_sprite.scale = base_sprite_scale * Vector2(1.28, 0.68)
		elif roll_elapsed < ROLL_SQUASH_TIME + ROLL_STRETCH_TIME:
			animated_sprite.scale = base_sprite_scale * Vector2(0.84, 1.16)
		else:
			animated_sprite.scale = base_sprite_scale * Vector2(1.08, 0.94)
		if roll_timer <= 0.0:
			animated_sprite.scale = base_sprite_scale
	else:
		velocity = direction.normalized() * SPEED
		animated_sprite.scale = base_sprite_scale
	if direction.is_zero_approx():
		if roll_timer <= 0.0:
			animated_sprite.play("default")
	else:
		animated_sprite.play("walking")
	move_and_slide()

func _start_roll(movement_direction: Vector2) -> void:
	if movement_direction.is_zero_approx():
		roll_direction = Vector2.RIGHT.rotated(gun_pivot.global_rotation)
	else:
		roll_direction = movement_direction.normalized()
	roll_timer = ROLL_DURATION
	roll_cooldown = ROLL_COOLDOWN
	invulnerability_timer = maxf(invulnerability_timer, ROLL_DURATION)
	animated_sprite.scale = base_sprite_scale

func receive_damage(damage: float) -> void:
	if is_dead or invulnerability_timer > 0.0 or damage <= 0.0:
		return
	lifes = maxf(0.0, lifes - damage)
	life_indicator.value = lifes
	invulnerability_timer = INVULNERABILITY_TIME
	if lifes <= 0.0:
		is_dead = true
		velocity = Vector2.ZERO
		animated_sprite.visible = false
		gun_pivot.visible = false
		life_indicator.visible = false
		$CollisionShape2D.set_deferred("disabled", true)
		$HitReceiver/CollisionShape2D.set_deferred("disabled", true)
		$DeathParticle.emitting = true
		died.emit()

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	lifes = minf(MAX_LIFE, lifes + amount)
	life_indicator.value = lifes

func _on_hit_receiver_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		receive_damage(1)

func _on_hit_receiver_area_entered(area: Area2D) -> void:
	if area.is_in_group("hostile_projectile"):
		receive_damage(float(area.get("damage")))
		area.queue_free()
