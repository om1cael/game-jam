extends CharacterBody2D

signal died

const SPEED: float = 190.0
const BASE_MAX_LIFE: float = 3.0
const INVULNERABILITY_TIME: float = 0.9
const ROLL_SPEED: float = 570.0
const ROLL_DURATION: float = 0.24
const ROLL_COOLDOWN: float = 1.0
const ROLL_SQUASH_TIME: float = 0.08
const ROLL_STRETCH_TIME: float = 0.12
const EMP_RADIUS: float = 190.0
const EMP_DAMAGE: int = 34
const EMP_BOSS_DAMAGE: int = 100
const EMP_STUN_DURATION: float = 1.35
const EMP_BOSS_STUN_DURATION: float = 0.85
const EMP_COOLDOWN: float = 9.0
const EMP_VISUAL_DURATION: float = 0.45
const OVERDRIVE_DURATION: float = 3.2
const OVERDRIVE_COOLDOWN: float = 11.0
const OVERDRIVE_SPEED_MULTIPLIER: float = 1.3
const DIRECTION_NAMES: Array[String] = [
	"right",
	"down_right",
	"down",
	"down_left",
	"left",
	"up_left",
	"up",
	"up_right"
]
const PLAYER_DIRECTION_SHEETS: Dictionary = {
	"down": preload("res://Sprites/Player/directions/down_walk.png"),
	"down_left": preload("res://Sprites/Player/directions/down_left_walk.png"),
	"left": preload("res://Sprites/Player/directions/left_walk.png"),
	"up_left": preload("res://Sprites/Player/directions/up_left_walk.png"),
	"up": preload("res://Sprites/Player/directions/up_walk.png"),
	"up_right": preload("res://Sprites/Player/directions/up_right_walk.png"),
	"right": preload("res://Sprites/Player/directions/right_walk.png"),
	"down_right": preload("res://Sprites/Player/directions/down_right_walk.png")
}

var lifes: float = BASE_MAX_LIFE
var max_life: float = BASE_MAX_LIFE
var invulnerability_timer: float = 0.0
var is_dead: bool = false
var roll_timer: float = 0.0
var roll_cooldown: float = 0.0
var roll_direction: Vector2 = Vector2.RIGHT
var base_sprite_scale: Vector2 = Vector2.ONE
var emp_cooldown: float = 0.0
var emp_visual_timer: float = 0.0
var overdrive_timer: float = 0.0
var overdrive_cooldown: float = 0.0
var facing_direction: String = "down"

@onready var gun_pivot: Node2D = $GunPivot
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var life_indicator: ProgressBar = $LifeIndicator
@onready var gun_sprite: Sprite2D = $GunPivot/Gun/Sprite2D

func _ready() -> void:
	_configure_directional_animations()
	var difficulty: Dictionary = GameState.get_difficulty_config()
	max_life = float(difficulty["player_lives"])
	lifes = max_life
	life_indicator.max_value = max_life
	life_indicator.value = lifes
	base_sprite_scale = animated_sprite.scale
	refresh_weapon_appearance()

func refresh_weapon_appearance() -> void:
	var color_by_upgrade: Dictionary = {
		"rapid_fire": Color(1.0, 0.56, 0.2),
		"heavy_rounds": Color(1.0, 0.28, 0.22),
		"long_barrel": Color(0.25, 0.86, 1.0),
		"extended_magazine": Color(0.55, 1.0, 0.3)
	}
	var selected_upgrade: String = GameState.last_weapon_upgrade
	if color_by_upgrade.has(selected_upgrade):
		var level: int = GameState.weapon_upgrade_level(selected_upgrade)
		gun_sprite.modulate = Color.WHITE.lerp(
			color_by_upgrade[selected_upgrade],
			minf(0.78, 0.42 + float(maxi(0, level - 1)) * 0.08)
		)
	else:
		gun_sprite.modulate = Color.WHITE

func _process(_delta: float) -> void:
	if is_dead:
		return
	gun_pivot.look_at(get_global_mouse_position())
	var aim_direction: Vector2 = global_position.direction_to(get_global_mouse_position())
	if not aim_direction.is_zero_approx():
		var direction_index: int = roundi(aim_direction.angle() / (PI / 4.0))
		if direction_index < 0:
			direction_index += DIRECTION_NAMES.size()
		facing_direction = DIRECTION_NAMES[direction_index]
	var facing_left: bool = aim_direction.x < 0.0
	$GunPivot/Gun/Sprite2D.flip_v = facing_left

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	emp_cooldown = maxf(0.0, emp_cooldown - delta)
	emp_visual_timer = maxf(0.0, emp_visual_timer - delta)
	overdrive_timer = maxf(0.0, overdrive_timer - delta)
	overdrive_cooldown = maxf(0.0, overdrive_cooldown - delta)
	if emp_visual_timer > 0.0 or overdrive_timer > 0.0:
		queue_redraw()
	if roll_timer > 0.0:
		animated_sprite.modulate = Color(1.0, 0.7, 0.38)
	elif overdrive_timer > 0.0:
		animated_sprite.modulate = Color(1.0, 0.84, 0.35)
	elif invulnerability_timer > 0.0:
		animated_sprite.modulate = Color(1.0, 0.48, 0.48, 1.0)
	else:
		animated_sprite.modulate = Color.WHITE
	var direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	if Input.is_action_just_pressed("emp_pulse") and emp_cooldown <= 0.0:
		_activate_emp()
	if Input.is_action_just_pressed("overdrive") and overdrive_cooldown <= 0.0:
		_activate_overdrive()
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
		var speed_multiplier: float = OVERDRIVE_SPEED_MULTIPLIER if overdrive_timer > 0.0 else 1.0
		velocity = direction.normalized() * SPEED * speed_multiplier
		animated_sprite.scale = base_sprite_scale
	_play_facing_animation(direction.is_zero_approx() and roll_timer <= 0.0)
	move_and_slide()

func _configure_directional_animations() -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	var default_frame: AtlasTexture = _direction_frame("down", 1)
	frames.add_animation("default")
	frames.add_frame("default", default_frame)
	for direction: String in DIRECTION_NAMES:
		var idle_animation: String = "idle_" + direction
		frames.add_animation(idle_animation)
		frames.add_frame(idle_animation, _direction_frame(direction, 1))
		var walk_animation: String = "walk_" + direction
		frames.add_animation(walk_animation)
		frames.set_animation_speed(walk_animation, 10.0)
		frames.set_animation_loop(walk_animation, true)
		for frame_index: int in 4:
			frames.add_frame(walk_animation, _direction_frame(direction, frame_index))
	animated_sprite.sprite_frames = frames
	animated_sprite.play("idle_down")

func _direction_frame(direction: String, frame_index: int) -> AtlasTexture:
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = PLAYER_DIRECTION_SHEETS[direction] as Texture2D
	frame.region = Rect2(frame_index * 128, 0, 128, 120)
	return frame

func _play_facing_animation(idle: bool) -> void:
	var animation_name: String = ("idle_" if idle else "walk_") + facing_direction
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _start_roll(movement_direction: Vector2) -> void:
	if movement_direction.is_zero_approx():
		roll_direction = Vector2.RIGHT.rotated(gun_pivot.global_rotation)
	else:
		roll_direction = movement_direction.normalized()
	roll_timer = ROLL_DURATION
	roll_cooldown = ROLL_COOLDOWN
	invulnerability_timer = maxf(invulnerability_timer, ROLL_DURATION)
	animated_sprite.scale = base_sprite_scale

func _activate_emp() -> void:
	emp_cooldown = EMP_COOLDOWN
	emp_visual_timer = EMP_VISUAL_DURATION
	AudioManager.play_sfx("emp")
	for hostile_node: Node in get_tree().get_nodes_in_group("enemy"):
		var hostile: Node2D = hostile_node as Node2D
		if hostile == null or global_position.distance_to(hostile.global_position) > EMP_RADIUS:
			continue
		var damage: int = EMP_BOSS_DAMAGE if hostile.is_in_group("boss") else EMP_DAMAGE
		var stun_duration: float = EMP_STUN_DURATION
		if hostile.is_in_group("boss"):
			stun_duration = EMP_BOSS_STUN_DURATION
		if hostile.has_method("apply_emp"):
			hostile.call("apply_emp", damage, stun_duration)
	for projectile_node: Node in get_tree().get_nodes_in_group("hostile_projectile"):
		var projectile: Node2D = projectile_node as Node2D
		if projectile != null and global_position.distance_to(projectile.global_position) <= EMP_RADIUS:
			projectile.queue_free()
	queue_redraw()

func _activate_overdrive() -> void:
	overdrive_timer = OVERDRIVE_DURATION
	overdrive_cooldown = OVERDRIVE_COOLDOWN
	AudioManager.play_sfx("overdrive")
	queue_redraw()

func receive_damage(damage: float) -> void:
	if is_dead or invulnerability_timer > 0.0 or damage <= 0.0:
		return
	var difficulty: Dictionary = GameState.get_difficulty_config()
	damage *= float(difficulty["incoming_damage"])
	lifes = maxf(0.0, lifes - damage)
	life_indicator.value = lifes
	invulnerability_timer = INVULNERABILITY_TIME
	if lifes <= 0.0:
		is_dead = true
		AudioManager.play_sfx("death")
		velocity = Vector2.ZERO
		animated_sprite.visible = false
		gun_pivot.visible = false
		life_indicator.visible = false
		$CollisionShape2D.set_deferred("disabled", true)
		$HitReceiver/CollisionShape2D.set_deferred("disabled", true)
		$DeathParticle.emitting = true
		died.emit()
	else:
		AudioManager.play_sfx("damage")

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	lifes = minf(max_life, lifes + amount)
	life_indicator.value = lifes

func _on_hit_receiver_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		receive_damage(1)

func _on_hit_receiver_area_entered(area: Area2D) -> void:
	if area.is_in_group("hostile_projectile"):
		receive_damage(float(area.get("damage")))
		area.queue_free()

func _draw() -> void:
	if overdrive_timer > 0.0:
		var pulse: float = 0.72 + 0.08 * sin(Time.get_ticks_msec() * 0.012)
		draw_arc(Vector2.ZERO, 43.0, 0.0, TAU, 40, Color(1.0, 0.72, 0.24, pulse), 3.0, true)
	if emp_visual_timer > 0.0:
		var progress: float = 1.0 - emp_visual_timer / EMP_VISUAL_DURATION
		var radius: float = lerpf(18.0, EMP_RADIUS, progress)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.38, 0.88, 1.0, 1.0 - progress), 3.0, true)
