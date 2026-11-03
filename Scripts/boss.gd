extends CharacterBody2D

signal health_changed(current_health: float, maximum_health: float)
signal defeated(boss_name: String, points: int)

const PROJECTILE_SCENE: PackedScene = preload("res://Scenes/hostile_projectile.tscn")
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
var dash_direction: Vector2 = Vector2.RIGHT
var defeated_state: bool = false
var boss_color: Color = BOSS_COLORS[0]

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	scale = Vector2.ZERO
	var intro: Tween = create_tween()
	intro.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	queue_redraw()

func configure(new_round: int) -> void:
	round_number = clampi(new_round, 1, 5)
	boss_name = BOSS_NAMES[round_number - 1]
	boss_color = BOSS_COLORS[round_number - 1]
	var health_by_round: Array[float] = [900.0, 1200.0, 1550.0, 1950.0, 2400.0]
	maximum_health = health_by_round[round_number - 1]
	health = maximum_health
	$Hitbox/CollisionShape2D.shape.radius = 44.0 + float(round_number) * 2.0
	health_changed.emit(health, maximum_health)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if defeated_state:
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	vulnerability_timer = maxf(0.0, vulnerability_timer - delta)
	if round_number == 5 and phase == 1 and health <= maximum_health * 0.5:
		phase = 2
		attack_cooldown = 0.35
		queue_redraw()
	if not is_instance_valid(player) or bool(player.get("is_dead")):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if warning_timer > 0.0:
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
		var distance: float = global_position.distance_to(player.global_position)
		velocity = Vector2.ZERO if distance < 58.0 else global_position.direction_to(player.global_position) * _move_speed()
		if attack_cooldown <= 0.0:
			_begin_attack()
	move_and_slide()
	if global_position.distance_to(player.global_position) < 64.0 and contact_cooldown <= 0.0:
		player.call("receive_damage", 1 + int(round_number >= 4))
		contact_cooldown = 1.0
	queue_redraw()

func _begin_attack() -> void:
	attack_index += 1
	warning_timer = 0.72 if round_number < 5 or phase == 1 else 0.48
	attack_cooldown = warning_timer

func _resolve_attack() -> void:
	if round_number == 1:
		if attack_index % 2 == 1:
			_start_dash()
		else:
			_fire_aimed(1)
	elif round_number == 2:
		if attack_index % 2 == 1:
			_start_dash()
		else:
			_fire_aimed(3, 0.22)
	elif round_number == 3:
		if attack_index % 2 == 1:
			_fire_radial(8, 280.0)
		else:
			_start_dash()
	elif round_number == 4:
		if attack_index % 2 == 1:
			_fire_aimed(3, 0.16, 320.0)
		else:
			_fire_radial(6, 235.0)
	else:
		if phase == 1 and attack_index % 2 == 1:
			_start_dash()
		elif attack_index % 2 == 0:
			_fire_radial(10 if phase == 2 else 7, 330.0)
		else:
			_fire_aimed(5 if phase == 2 else 3, 0.3, 350.0)
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

func _fire_radial(count: int, projectile_speed: float) -> void:
	for index: int in count:
		var angle: float = TAU * float(index) / float(count) + float(attack_index % 2) * 0.15
		_spawn_projectile(Vector2.RIGHT.rotated(angle), projectile_speed)

func _spawn_projectile(direction: Vector2, projectile_speed: float) -> void:
	var projectile: Area2D = PROJECTILE_SCENE.instantiate()
	projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.call("configure", direction, projectile_speed, 1)

func _move_speed() -> float:
	var speeds: Array[float] = [74.0, 120.0, 58.0, 92.0, 104.0]
	return speeds[round_number - 1] * (1.25 if phase == 2 else 1.0)

func _dash_speed() -> float:
	var speeds: Array[float] = [380.0, 470.0, 310.0, 395.0, 440.0]
	return speeds[round_number - 1] * (1.2 if phase == 2 else 1.0)

func _attack_interval() -> float:
	var intervals: Array[float] = [2.25, 1.7, 2.35, 1.7, 1.5]
	return intervals[round_number - 1] * (0.72 if phase == 2 else 1.0)

func receive_damage(damage: int) -> void:
	if defeated_state or damage <= 0:
		return
	if round_number == 1 and vulnerability_timer > 0.0:
		damage *= 2
	health = maxf(0.0, health - float(damage))
	health_changed.emit(health, maximum_health)
	if health <= 0.0:
		defeated_state = true
		velocity = Vector2.ZERO
		$Hitbox/CollisionShape2D.set_deferred("disabled", true)
		defeated.emit(boss_name, 1000)
		var death_tween: Tween = create_tween()
		death_tween.tween_property(self, "scale", Vector2.ZERO, 0.45)
		death_tween.tween_callback(queue_free)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not defeated_state and area.is_in_group("bullet"):
		receive_damage(int(area.get("damage")))
		area.queue_free()

func _draw() -> void:
	var radius: float = 42.0 + float(round_number) * 2.0
	draw_circle(Vector2.ZERO, radius, Color(boss_color.r, boss_color.g, boss_color.b, 0.24))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, boss_color, 5.0, true)
	draw_arc(Vector2.ZERO, radius * 0.68, 0.0, TAU, 40, Color(0.8, 0.96, 1.0, 0.9), 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -radius * 0.56),
		Vector2(radius * 0.34, 0),
		Vector2(0, radius * 0.56),
		Vector2(-radius * 0.34, 0)
	]), boss_color)
	if warning_timer > 0.0:
		draw_arc(Vector2.ZERO, radius + 16.0 + sin(Time.get_ticks_msec() * 0.012) * 4.0, 0.0, TAU, 48, Color(1.0, 0.2, 0.16, 0.9), 4.0, true)
	elif vulnerability_timer > 0.0:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 48, Color(1.0, 0.58, 0.3, 0.95), 4.0, true)
