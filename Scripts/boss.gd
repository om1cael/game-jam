extends CharacterBody2D

signal health_changed(current_health: float, maximum_health: float)
signal defeated(boss_name: String, points: int)

const PROJECTILE_SCENE: PackedScene = preload("res://Scenes/hostile_projectile.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Scenes/enemy.tscn")
const BOSS_SHEETS: Array[Texture2D] = [
	preload("res://Sprites/Boss/guardian_walk.png"),
	preload("res://Sprites/Boss/predator_walk.png"),
	preload("res://Sprites/Boss/colossus_walk.png"),
	preload("res://Sprites/Boss/commander_walk.png"),
	preload("res://Sprites/Boss/entity_walk.png")
]
const SHOCKWAVE_DURATION: float = 0.82
const SHOCKWAVE_MAX_RADIUS: float = 420.0
const BOSS_NAMES: Array[String] = [
	"GUARDIÃO",
	"PREDADOR",
	"COLOSSO",
	"COMANDANTE",
	"ENTIDADE FINAL"
]
const BOSS_COLORS: Array[Color] = [
	Color(0.25, 0.9, 0.8),
	Color(1.0, 0.28, 0.2),
	Color(0.84, 0.57, 0.22),
	Color(0.7, 0.38, 1.0),
	Color(0.4, 0.65, 1.0)
]

var round_number: int = 1
var boss_name: String = BOSS_NAMES[0]
var maximum_health: float = 420.0
var health: float = maximum_health
var phase: int = 1
var player: Node2D
var attack_index: int = 0
var attack_cooldown: float = 1.6
var warning_timer: float = 0.0
var contact_cooldown: float = 0.0
var dash_timer: float = 0.0
var vulnerability_timer: float = 0.0
var emp_stun_timer: float = 0.0
var shockwave_timer: float = 0.0
var shockwave_previous_radius: float = 56.0
var shockwave_hit: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var defeated_state: bool = false
var boss_color: Color = BOSS_COLORS[0]
var summoned_minions: Array[Node2D] = []
var motion_clock: float = 0.0
var attack_pose_timer: float = 0.0
var current_sprite_animation: StringName = &""
@onready var body_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	_configure_body_sprite()
	scale = Vector2.ZERO
	var intro: Tween = create_tween()
	intro.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	queue_redraw()

func configure(new_round: int) -> void:
	round_number = clampi(new_round, 1, 5)
	boss_name = BOSS_NAMES[round_number - 1]
	boss_color = BOSS_COLORS[round_number - 1]
	_configure_body_sprite()
	var health_by_round: Array[float] = [1250.0, 1700.0, 2300.0, 3000.0, 3900.0]
	var difficulty: Dictionary = GameState.get_difficulty_config()
	maximum_health = health_by_round[round_number - 1] * float(difficulty["enemy_health"])
	health = maximum_health
	$Hitbox/CollisionShape2D.shape.radius = 44.0 + float(round_number) * 2.0
	health_changed.emit(health, maximum_health)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if defeated_state:
		return
	motion_clock += delta
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	vulnerability_timer = maxf(0.0, vulnerability_timer - delta)
	emp_stun_timer = maxf(0.0, emp_stun_timer - delta)
	attack_pose_timer = maxf(0.0, attack_pose_timer - delta)
	if round_number == 5 and phase == 1 and health <= maximum_health * 0.5:
		phase = 2
		attack_cooldown = 0.35
		queue_redraw()
	if not is_instance_valid(player) or bool(player.get("is_dead")):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_update_shockwave(delta)
	if emp_stun_timer > 0.0:
		velocity = Vector2.ZERO
	elif warning_timer > 0.0:
		warning_timer = maxf(0.0, warning_timer - delta)
		velocity = Vector2.ZERO
		if warning_timer == 0.0:
			_resolve_attack()
			attack_cooldown = _attack_interval()
	elif dash_timer > 0.0:
		dash_timer -= delta
		if dash_timer <= 0.0:
			dash_timer = 0.0
			velocity = Vector2.ZERO
			vulnerability_timer = 0.8
		else:
			velocity = dash_direction * _dash_speed()
	else:
		attack_cooldown -= delta
		var to_player: Vector2 = global_position.direction_to(player.global_position)
		var distance: float = global_position.distance_to(player.global_position)
		var orbit_direction: float = -1.0 if (attack_index + round_number) % 2 == 0 else 1.0
		var tangent: Vector2 = to_player.rotated(PI * 0.5 * orbit_direction)
		if distance > 270.0:
			velocity = to_player * _move_speed()
		elif distance > 105.0:
			velocity = (to_player * 0.52 + tangent * 0.86).normalized() * _move_speed()
		else:
			velocity = (-to_player * 0.85 + tangent * 0.55).normalized() * _move_speed() * 0.78
		if attack_cooldown <= 0.0:
			_begin_attack()
	move_and_slide()
	var dash_lean: float = (
		clampf(velocity.x / maxf(_dash_speed(), 1.0), -1.0, 1.0) * 0.16
		if dash_timer > 0.0
		else 0.0
	)
	var warning_lean: float = sin(motion_clock * 18.0) * 0.035 if warning_timer > 0.0 else 0.0
	var breathing: float = 1.0 + sin(motion_clock * 2.6) * 0.035
	body_sprite.position.y = sin(motion_clock * 3.0 + float(round_number)) * 2.6
	body_sprite.rotation = dash_lean + warning_lean
	body_sprite.scale = Vector2(breathing, 1.0 / breathing)
	_update_body_animation()
	if global_position.distance_to(player.global_position) < 64.0 and contact_cooldown <= 0.0:
		if emp_stun_timer <= 0.0:
			player.call("receive_damage", 1 + int(round_number >= 4))
		contact_cooldown = 1.0
	queue_redraw()

func _begin_attack() -> void:
	attack_index += 1
	var warning_by_boss: Array[float] = [0.82, 0.62, 0.95, 0.72, 0.62]
	var phase_multiplier: float = 0.82 if round_number == 5 and phase == 2 else 1.0
	warning_timer = warning_by_boss[round_number - 1] * phase_multiplier
	attack_cooldown = warning_timer

func _resolve_attack() -> void:
	attack_pose_timer = 0.34
	if round_number == 1:
		if attack_index % 2 == 1:
			_start_dash()
		else:
			_fire_aimed(1)
	elif round_number == 2:
		if attack_index % 2 == 1:
			_start_dash()
		else:
			_fire_aimed(5, 0.16, 370.0)
	elif round_number == 3:
		if attack_index % 2 == 1:
			_start_shockwave()
		else:
			_fire_radial(10, 300.0)
	elif round_number == 4:
		if attack_index % 2 == 1:
			_summon_guards()
		else:
			_fire_aimed(5, 0.2, 350.0)
	else:
		if phase == 1 and attack_index % 2 == 1:
			_start_dash()
		else:
			if phase == 2:
				_fire_radial(13, 350.0)
				_fire_radial(13, 350.0, PI / 13.0)
			elif attack_index % 2 == 0:
				_fire_radial(8, 310.0)
			else:
				_fire_aimed(4, 0.24, 365.0)
	attack_cooldown = _attack_interval()

func _start_dash() -> void:
	if is_instance_valid(player):
		dash_direction = global_position.direction_to(player.global_position)
		dash_timer = 0.42 if round_number != 3 else 0.55

func _fire_aimed(count: int, spread: float = 0.0, projectile_speed: float = 270.0) -> void:
	if not is_instance_valid(player):
		return
	var aim: Vector2 = global_position.direction_to(player.global_position)
	for index: int in count:
		var offset: float = float(index) - float(count - 1) / 2.0
		_spawn_projectile(aim.rotated(offset * spread), projectile_speed)
	AudioManager.play_sfx("boss_shot")

func _fire_radial(count: int, projectile_speed: float, phase_offset: float = 0.0) -> void:
	for index: int in count:
		var alternating_offset: float = float(attack_index % 2) * 0.15
		var angle: float = TAU * float(index) / float(count)
		angle += alternating_offset + phase_offset
		_spawn_projectile(Vector2.RIGHT.rotated(angle), projectile_speed)
	AudioManager.play_sfx("boss_shot")

func _spawn_projectile(direction: Vector2, projectile_speed: float) -> void:
	var projectile: Area2D = PROJECTILE_SCENE.instantiate()
	projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.call("configure", direction, projectile_speed, 1)

func _start_shockwave() -> void:
	shockwave_timer = SHOCKWAVE_DURATION
	shockwave_previous_radius = 56.0
	shockwave_hit = false

func _update_shockwave(delta: float) -> void:
	if shockwave_timer <= 0.0 or not is_instance_valid(player):
		return
	shockwave_timer = maxf(0.0, shockwave_timer - delta)
	var progress: float = 1.0 - shockwave_timer / SHOCKWAVE_DURATION
	var radius: float = lerpf(56.0, SHOCKWAVE_MAX_RADIUS, progress)
	var player_distance: float = global_position.distance_to(player.global_position)
	var crossed_wave: bool = (
		player_distance + 18.0 >= shockwave_previous_radius
		and player_distance - 18.0 <= radius
	)
	if not shockwave_hit and crossed_wave:
		player.call("receive_damage", 1 + int(round_number >= 4))
		shockwave_hit = true
	shockwave_previous_radius = radius

func _summon_guards() -> void:
	var living_minions: Array[Node2D] = []
	for minion: Node2D in summoned_minions:
		if is_instance_valid(minion):
			living_minions.append(minion)
	summoned_minions = living_minions
	var slots: int = 2 - summoned_minions.size()
	for index: int in slots:
		var minion: CharacterBody2D = ENEMY_SCENE.instantiate() as CharacterBody2D
		minion.process_mode = Node.PROCESS_MODE_PAUSABLE
		minion.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(index) / 2.0) * 84.0
		minion.call("configure_variant", "FAST" if index == 0 else "ARMORED", round_number)
		var game: Node = get_tree().current_scene
		if game.has_method("_on_enemy_defeated"):
			minion.connect("defeated", Callable(game, "_on_enemy_defeated"))
			game.set("active_enemies", int(game.get("active_enemies")) + 1)
		get_tree().current_scene.add_child(minion)
		summoned_minions.append(minion)
	AudioManager.play_sfx("shield")

func _move_speed() -> float:
	var speeds: Array[float] = [82.0, 132.0, 64.0, 98.0, 116.0]
	return speeds[round_number - 1] * (1.32 if phase == 2 else 1.0)

func _dash_speed() -> float:
	var speeds: Array[float] = [420.0, 520.0, 350.0, 430.0, 485.0]
	return speeds[round_number - 1] * (1.28 if phase == 2 else 1.0)

func _attack_interval() -> float:
	var intervals: Array[float] = [1.8, 1.3, 1.85, 1.4, 1.22]
	return intervals[round_number - 1] * (0.68 if phase == 2 else 1.0)

func receive_damage(damage: int) -> void:
	if defeated_state or damage <= 0:
		return
	self_modulate = Color(1.0, 0.72, 0.65)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(self, "self_modulate", Color.WHITE, 0.14)
	if round_number == 1 and vulnerability_timer <= 0.0:
		damage = maxi(1, roundi(float(damage) * 0.35))
	elif round_number == 1 and vulnerability_timer > 0.0:
		damage *= 2
	health = maxf(0.0, health - float(damage))
	health_changed.emit(health, maximum_health)
	if health <= 0.0:
		defeated_state = true
		velocity = Vector2.ZERO
		$Hitbox/CollisionShape2D.set_deferred("disabled", true)
		for minion: Node2D in summoned_minions:
			if is_instance_valid(minion):
				minion.queue_free()
		defeated.emit(boss_name, 1000)
		var death_tween: Tween = create_tween()
		death_tween.tween_property(self, "scale", Vector2.ZERO, 0.45)
		death_tween.tween_callback(queue_free)

func apply_emp(damage: int, stun_duration: float) -> void:
	receive_damage(damage)
	if defeated_state:
		return
	warning_timer = 0.0
	dash_timer = 0.0
	shockwave_timer = 0.0
	emp_stun_timer = maxf(emp_stun_timer, stun_duration)
	attack_cooldown = maxf(attack_cooldown, stun_duration + 0.4)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not defeated_state and area.is_in_group("bullet"):
		receive_damage(int(area.get("damage")))
		area.queue_free()

func _draw() -> void:
	var radius: float = 42.0 + float(round_number) * 2.0
	var pulse: float = 0.18 + 0.06 * (0.5 + 0.5 * sin(motion_clock * 3.2))
	draw_circle(
		Vector2.ZERO,
		radius + 3.0 * sin(motion_clock * 2.1),
		Color(boss_color.r, boss_color.g, boss_color.b, pulse)
	)
	if warning_timer > 0.0:
		draw_arc(
			Vector2.ZERO,
			radius + 16.0 + sin(Time.get_ticks_msec() * 0.012) * 4.0,
			0.0,
			TAU,
			48,
			Color(1.0, 0.2, 0.16, 0.9),
			4.0,
			true
		)
		if _is_aimed_attack() and is_instance_valid(player):
			var aim: Vector2 = global_position.direction_to(player.global_position)
			var warning_distance: float = minf(global_position.distance_to(player.global_position), 280.0)
			draw_line(Vector2.ZERO, aim * warning_distance, Color(1.0, 0.28, 0.2, 0.34), 3.0, true)
			draw_arc(aim * warning_distance, 12.0, 0.0, TAU, 20, Color(1.0, 0.43, 0.28, 0.7), 2.0, true)
	elif vulnerability_timer > 0.0:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 48, Color(1.0, 0.58, 0.3, 0.95), 4.0, true)
	elif round_number == 1:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 48, Color(0.35, 0.88, 1.0, 0.88), 4.0, true)
	if shockwave_timer > 0.0:
		draw_arc(
			Vector2.ZERO,
			shockwave_previous_radius,
			0.0,
			TAU,
			48,
			Color(1.0, 0.55, 0.2, 0.95),
			5.0,
			true
		)
	if attack_pose_timer > 0.0:
		var impact_progress: float = 1.0 - attack_pose_timer / 0.34
		var impact_radius: float = radius + 12.0 + impact_progress * 42.0
		draw_arc(
			Vector2.ZERO,
			impact_radius,
			0.0,
			TAU,
			40,
			Color(boss_color.r, boss_color.g, boss_color.b, 0.72 * (1.0 - impact_progress)),
			3.0,
			true
		)

func _configure_body_sprite() -> void:
	var sprite_node: AnimatedSprite2D = get_node("AnimatedSprite2D") as AnimatedSprite2D
	var sprite_frames: SpriteFrames = SpriteFrames.new()
	var animation_rows: Dictionary = {
		"idle": 1,
		"move": 0,
		"windup": 2,
		"attack": 3
	}
	for animation_name: String in animation_rows:
		sprite_frames.add_animation(animation_name)
		var animation_speed: float = 5.0
		if animation_name == "attack":
			animation_speed = 12.0
		elif animation_name != "idle":
			animation_speed = 9.0
		sprite_frames.set_animation_speed(animation_name, animation_speed)
		sprite_frames.set_animation_loop(animation_name, animation_name != "attack")
	var sprite_sheet: Texture2D = BOSS_SHEETS[round_number - 1]
	for animation_name: String in animation_rows:
		var row: int = int(animation_rows[animation_name])
		for frame_index: int in 4:
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = sprite_sheet
			frame.region = Rect2(frame_index * 128, row * 120, 128, 120)
			sprite_frames.add_frame(animation_name, frame)
	sprite_node.sprite_frames = sprite_frames
	sprite_node.play(&"idle")
	current_sprite_animation = &"idle"

func _update_body_animation() -> void:
	if warning_timer > 0.0:
		_play_body_animation(&"windup")
	elif dash_timer > 0.0 or attack_pose_timer > 0.0 or shockwave_timer > 0.0:
		_play_body_animation(&"attack")
	elif velocity.length_squared() > 400.0:
		_play_body_animation(&"move")
	else:
		_play_body_animation(&"idle")

func _play_body_animation(animation_name: StringName) -> void:
	if current_sprite_animation == animation_name:
		return
	current_sprite_animation = animation_name
	body_sprite.play(animation_name)

func _is_aimed_attack() -> bool:
	if round_number == 1 or round_number == 2:
		return attack_index % 2 == 0
	if round_number == 4:
		return attack_index % 2 == 0
	return round_number == 5 and phase == 1 and attack_index % 2 == 0
