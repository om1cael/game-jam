extends CharacterBody2D

signal defeated(enemy: Node2D, variant: String, points: int)

const BASE_HEALTH: float = 46.0
const BASE_SPEED: float = 88.0
const BASE_DAMAGE: float = 1.0
const ATTACK_RANGE: float = 64.0
const ATTACK_WINDUP: float = 0.44
const PROJECTILE_SCENE: PackedScene = preload("res://Scenes/hostile_projectile.tscn")
const VARIANT_SHEETS: Dictionary = {
	"NORMAL": preload("res://Sprites/Enemy/Variants/normal_walk.png"),
	"ARMORED": preload("res://Sprites/Enemy/Variants/armored_walk.png"),
	"AGGRESSIVE": preload("res://Sprites/Enemy/Variants/aggressive_walk.png"),
	"FAST": preload("res://Sprites/Enemy/Variants/fast_walk.png"),
	"MUTATED": preload("res://Sprites/Enemy/Variants/mutated_walk.png"),
	"ELITE": preload("res://Sprites/Enemy/Variants/elite_walk.png"),
	"SPITTER": preload("res://Sprites/Enemy/Variants/spitter_walk.png"),
	"BURROWER": preload("res://Sprites/Enemy/Variants/burrower_walk.png")
}
enum State { IDLE, CHASE, ATTACK, DAMAGED, DEAD }
const VARIANTS: Dictionary = {
	"NORMAL": {"health": 1.0, "damage": 1.0, "speed": 1.0, "points": 100, "color": Color(0.91, 1.0, 0.85)},
	"ARMORED": {"health": 2.0, "damage": 0.8, "speed": 0.75, "points": 200, "color": Color(0.35, 0.78, 1.0)},
	"AGGRESSIVE": {"health": 0.65, "damage": 2.0, "speed": 1.0, "points": 200, "color": Color(1.0, 0.7, 0.22)},
	"FAST": {"health": 0.8, "damage": 0.9, "speed": 1.5, "points": 150, "color": Color(0.78, 1.0, 0.28)},
	"MUTATED": {"health": 1.3, "damage": 1.5, "speed": 1.1, "points": 300, "color": Color(0.82, 0.45, 1.0)},
	"ELITE": {"health": 2.5, "damage": 1.5, "speed": 1.15, "points": 500, "color": Color(0.22, 1.0, 0.82)},
	"SPITTER": {"health": 0.9, "damage": 1.2, "speed": 0.82, "points": 250, "color": Color(0.68, 0.95, 0.52)},
	"BURROWER": {"health": 1.55, "damage": 1.8, "speed": 0.9, "points": 350, "color": Color(1.0, 0.62, 0.3)}
}

var variant: String = "NORMAL"
var life: float = BASE_HEALTH
var max_life: float = BASE_HEALTH
var speed: float = BASE_SPEED
var contact_damage: float = BASE_DAMAGE
var points: int = 100
var dead: bool = false
var attack_cooldown: float = 0.0
var attack_windup: float = 0.0
var state: int = State.IDLE
var damaged_timer: float = 0.0
var emp_stun_timer: float = 0.0
var lunge_timer: float = 0.0
var lunge_direction: Vector2 = Vector2.RIGHT
var ranged_cooldown: float = 0.0
var movement_clock: float = 0.0
var player: Node2D
var variant_color: Color = Color.WHITE

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	_configure_variant_sprite()
	$AnimatedSprite2D.play("default")

func configure_variant(new_variant: String, round_number: int) -> void:
	variant = new_variant if VARIANTS.has(new_variant) else "NORMAL"
	var stats: Dictionary = VARIANTS[variant]
	var difficulty: Dictionary = GameState.get_difficulty_config()
	max_life = BASE_HEALTH * float(stats["health"])
	max_life *= (1.0 + float(round_number - 1) * 0.16)
	max_life *= float(difficulty["enemy_health"])
	life = max_life
	speed = BASE_SPEED * float(stats["speed"])
	speed *= (1.0 + float(round_number - 1) * 0.06)
	speed *= float(difficulty["enemy_speed"])
	contact_damage = BASE_DAMAGE * float(stats["damage"])
	contact_damage *= (1.0 + float(round_number - 1) * 0.08)
	points = int(stats["points"])
	variant_color = stats["color"]
	_configure_variant_sprite()
	$AnimatedSprite2D.modulate = Color.WHITE
	$LifeIndicator.max_value = max_life
	$LifeIndicator.value = life
	attack_cooldown = 0.75
	ranged_cooldown = randf_range(1.0, 1.8)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	damaged_timer = maxf(0.0, damaged_timer - delta)
	emp_stun_timer = maxf(0.0, emp_stun_timer - delta)
	ranged_cooldown = maxf(0.0, ranged_cooldown - delta)
	movement_clock += delta
	_animate_body()
	if emp_stun_timer > 0.0:
		state = State.DAMAGED
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	if not is_instance_valid(player) or bool(player.get("is_dead")):
		state = State.IDLE
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction: Vector2 = global_position.direction_to(player.global_position)
	var distance: float = global_position.distance_to(player.global_position)
	if lunge_timer > 0.0:
		lunge_timer = maxf(0.0, lunge_timer - delta)
		velocity = lunge_direction * speed * 3.2
		move_and_slide()
		if lunge_timer <= 0.0:
			velocity = Vector2.ZERO
			if global_position.distance_to(player.global_position) <= ATTACK_RANGE + 10.0:
				player.call("receive_damage", contact_damage)
			attack_cooldown = 1.1
		queue_redraw()
		return
	if variant == "ELITE":
		if distance > 270.0:
			velocity = direction * speed
		elif distance < 155.0:
			velocity = -direction * speed * 0.8
		else:
			velocity = direction.orthogonal() * sin(movement_clock * 2.2) * speed * 0.65
		if ranged_cooldown <= 0.0:
			_fire_projectile_pattern(3, 0.18, 330.0, 1)
			ranged_cooldown = 2.15
		$AnimatedSprite2D.flip_h = direction.x < 0.0
		move_and_slide()
		queue_redraw()
		return
	if variant == "BURROWER" and distance > ATTACK_RANGE and distance <= 215.0:
		if attack_windup <= 0.0 and ranged_cooldown <= 0.0:
			attack_windup = 0.34
		if attack_windup > 0.0:
			attack_windup = maxf(0.0, attack_windup - delta)
			velocity = Vector2.ZERO
			if attack_windup <= 0.0:
				lunge_direction = direction
				lunge_timer = 0.28
				ranged_cooldown = 2.1
			$AnimatedSprite2D.flip_h = direction.x < 0.0
			$AnimatedSprite2D.modulate = variant_color.lerp(Color(1.0, 0.16, 0.12), 0.75)
			move_and_slide()
			queue_redraw()
			return
	if variant == "SPITTER":
		if distance > 310.0:
			velocity = direction * speed
		elif distance < 205.0:
			velocity = -direction * speed * 0.78
		else:
			velocity = direction.orthogonal() * sin(movement_clock * 1.8) * speed * 0.72
		if ranged_cooldown <= 0.0:
			_fire_projectile_pattern(3, 0.16, 300.0, 1)
			ranged_cooldown = 2.35
		$AnimatedSprite2D.flip_h = direction.x < 0.0
		move_and_slide()
		queue_redraw()
		return
	if distance > ATTACK_RANGE:
		attack_windup = 0.0
		if damaged_timer <= 0.0:
			state = State.CHASE
		velocity = direction * speed
		if variant == "FAST":
			var strafe: Vector2 = direction.orthogonal() * sin(movement_clock * 4.0) * 0.34
			velocity = (direction + strafe).normalized() * speed
	else:
		if damaged_timer <= 0.0:
			state = State.ATTACK
		velocity = Vector2.ZERO
		if attack_windup > 0.0:
			attack_windup = maxf(0.0, attack_windup - delta)
			if attack_windup <= 0.0:
				if variant == "AGGRESSIVE":
					lunge_direction = direction
					lunge_timer = 0.22
				elif distance <= ATTACK_RANGE + 8.0:
					player.call("receive_damage", contact_damage)
				attack_cooldown = 0.92
		elif attack_cooldown <= 0.0:
			attack_windup = ATTACK_WINDUP * (0.72 if variant == "AGGRESSIVE" else 1.0)
	if variant == "MUTATED" and ranged_cooldown <= 0.0 and distance <= 390.0:
		_fire_projectile_pattern(1, 0.0, 230.0, 1)
		ranged_cooldown = 2.8
	$AnimatedSprite2D.flip_h = direction.x < 0.0
	if attack_windup > 0.0:
		var warning_pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.035)
		$AnimatedSprite2D.modulate = variant_color.lerp(Color(1.0, 0.16, 0.12), warning_pulse)
	else:
		$AnimatedSprite2D.modulate = Color.WHITE
	move_and_slide()
	queue_redraw()

func receive_damage(damage: int) -> void:
	if dead or damage <= 0:
		return
	var applied_damage: int = maxi(1, ceili(float(damage) * 0.55)) if variant == "ARMORED" else damage
	life = maxf(0.0, life - applied_damage)
	state = State.DAMAGED
	damaged_timer = 0.12
	$LifeIndicator.value = life
	if $AnimationPlayer.has_animation("damage"):
		$AnimationPlayer.play("damage")
	if life <= 0.0:
		_die()

func _configure_variant_sprite() -> void:
	var sprite_sheet: Texture2D = VARIANT_SHEETS[variant] as Texture2D
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("default")
	frames.add_animation("walking")
	frames.set_animation_speed("walking", 9.0)
	frames.set_animation_loop("walking", true)
	frames.add_animation("attack")
	frames.set_animation_speed("attack", 5.0)
	frames.set_animation_loop("attack", true)
	for frame_index: int in 4:
		var frame: AtlasTexture = _enemy_frame(sprite_sheet, frame_index)
		if frame_index == 1:
			frames.add_frame("default", frame)
		frames.add_frame("walking", frame)
		if frame_index < 2:
			frames.add_frame("attack", frame)
	$AnimatedSprite2D.sprite_frames = frames
	$AnimatedSprite2D.play("default")

func _enemy_frame(sprite_sheet: Texture2D, frame_index: int) -> AtlasTexture:
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = sprite_sheet
	frame.region = Rect2(frame_index * 128, 0, 128, 120)
	return frame

func _animate_body() -> void:
	var attack_pull: float = clampf(attack_windup / ATTACK_WINDUP, 0.0, 1.0)
	var breathe: float = sin(movement_clock * 7.0)
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.position.y = -1.0 + breathe * 1.2
	sprite.scale = Vector2(
		0.38 * (1.0 + attack_pull * 0.13),
		0.38 * (1.0 - attack_pull * 0.1)
	)
	sprite.rotation = -signf(velocity.x) * minf(absf(velocity.x) / 500.0, 0.08)
	var animation_name: String = "default"
	if attack_windup > 0.0 or lunge_timer > 0.0:
		animation_name = "attack"
	elif velocity.length_squared() > 25.0:
		animation_name = "walking"
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)

func apply_emp(damage: int, stun_duration: float) -> void:
	receive_damage(damage)
	if not dead:
		emp_stun_timer = maxf(emp_stun_timer, stun_duration)
		attack_windup = 0.0
		lunge_timer = 0.0

func _fire_projectile_pattern(
	count: int,
	spread: float,
	projectile_speed: float,
	damage: int
) -> void:
	if not is_instance_valid(player):
		return
	var aim: Vector2 = global_position.direction_to(player.global_position)
	for index: int in count:
		var offset: float = float(index) - float(count - 1) / 2.0
		var projectile: Area2D = PROJECTILE_SCENE.instantiate() as Area2D
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = global_position
		projectile.call("configure", aim.rotated(offset * spread), projectile_speed, damage)
	AudioManager.play_sfx("boss_shot" if variant == "ELITE" else "enemy_shot")

func _die() -> void:
	if dead:
		return
	dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	defeated.emit(self, variant, points)
	$LifeIndicator.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	$BulletArea/CollisionShape2D.set_deferred("disabled", true)
	AudioManager.play_sfx("enemy_down")
	$DeathParticle.emitting = true
	var death_tween: Tween = create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property($AnimatedSprite2D, "scale", $AnimatedSprite2D.scale * 1.35, 0.16)
	death_tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 0.16)
	death_tween.chain().tween_callback(func() -> void:
		$AnimatedSprite2D.visible = false
	)

func _on_death_particle_finished() -> void:
	queue_free()

func _on_bullet_area_area_entered(area: Area2D) -> void:
	if not dead and area.is_in_group("bullet"):
		receive_damage(int(area.get("damage")))
		area.queue_free()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var label_size: Vector2 = font.get_string_size(variant, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10)
	draw_string(font, Vector2(-label_size.x * 0.5, -24.0), variant, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, variant_color.lightened(0.25))
	if attack_windup > 0.0:
		var pulse: float = 28.0 + 4.0 * sin(Time.get_ticks_msec() * 0.035)
		draw_arc(Vector2.ZERO, pulse, 0.0, TAU, 24, Color(1.0, 0.2, 0.13, 0.9), 2.0, true)
