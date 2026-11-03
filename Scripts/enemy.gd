extends CharacterBody2D

signal defeated(enemy: Node2D, variant: String, points: int)

const BASE_HEALTH: float = 36.0
const BASE_SPEED: float = 78.0
const BASE_DAMAGE: float = 1.0
const ATTACK_RANGE: float = 64.0
const ATTACK_WINDUP: float = 0.44
enum State { IDLE, CHASE, ATTACK, DAMAGED, DEAD }
const VARIANTS: Dictionary = {
	"NORMAL": {"health": 1.0, "damage": 1.0, "speed": 1.0, "points": 100, "color": Color(0.91, 1.0, 0.85)},
	"ARMORED": {"health": 2.0, "damage": 0.8, "speed": 0.75, "points": 200, "color": Color(0.35, 0.78, 1.0)},
	"AGGRESSIVE": {"health": 0.65, "damage": 2.0, "speed": 1.0, "points": 200, "color": Color(1.0, 0.7, 0.22)},
	"FAST": {"health": 0.8, "damage": 0.9, "speed": 1.5, "points": 150, "color": Color(0.78, 1.0, 0.28)},
	"MUTATED": {"health": 1.3, "damage": 1.5, "speed": 1.1, "points": 300, "color": Color(0.82, 0.45, 1.0)},
	"ELITE": {"health": 2.5, "damage": 1.5, "speed": 1.15, "points": 500, "color": Color(0.22, 1.0, 0.82)}
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
var player: Node2D
var variant_color: Color = Color.WHITE

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	$AnimatedSprite2D.play("default")

func configure_variant(new_variant: String, round_number: int) -> void:
	variant = new_variant if VARIANTS.has(new_variant) else "NORMAL"
	var stats: Dictionary = VARIANTS[variant]
	max_life = BASE_HEALTH * float(stats["health"]) * (1.0 + float(round_number - 1) * 0.12)
	life = max_life
	speed = BASE_SPEED * float(stats["speed"]) * (1.0 + float(round_number - 1) * 0.04)
	contact_damage = BASE_DAMAGE * float(stats["damage"])
	points = int(stats["points"])
	variant_color = stats["color"]
	$AnimatedSprite2D.modulate = variant_color
	$LifeIndicator.max_value = max_life
	$LifeIndicator.value = life
	attack_cooldown = 0.75
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	damaged_timer = maxf(0.0, damaged_timer - delta)
	if not is_instance_valid(player) or bool(player.get("is_dead")):
		state = State.IDLE
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction: Vector2 = global_position.direction_to(player.global_position)
	var distance: float = global_position.distance_to(player.global_position)
	if distance > ATTACK_RANGE:
		attack_windup = 0.0
		if damaged_timer <= 0.0:
			state = State.CHASE
		velocity = direction * speed
	else:
		if damaged_timer <= 0.0:
			state = State.ATTACK
		velocity = Vector2.ZERO
		if attack_windup > 0.0:
			attack_windup = maxf(0.0, attack_windup - delta)
			if attack_windup <= 0.0:
				if distance <= ATTACK_RANGE + 8.0:
					player.call("receive_damage", contact_damage)
				attack_cooldown = 1.18
		elif attack_cooldown <= 0.0:
			attack_windup = ATTACK_WINDUP
	$AnimatedSprite2D.flip_h = direction.x < 0.0
	if attack_windup > 0.0:
		var warning_pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.035)
		$AnimatedSprite2D.modulate = variant_color.lerp(Color(1.0, 0.16, 0.12), warning_pulse)
	else:
		$AnimatedSprite2D.modulate = variant_color
	move_and_slide()
	queue_redraw()

func receive_damage(damage: int) -> void:
	if dead or damage <= 0:
		return
	life = maxf(0.0, life - damage)
	state = State.DAMAGED
	damaged_timer = 0.12
	$LifeIndicator.value = life
	if $AnimationPlayer.has_animation("damage"):
		$AnimationPlayer.play("damage")
	if life <= 0.0:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	defeated.emit(self, variant, points)
	$AnimatedSprite2D.visible = false
	$LifeIndicator.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	$BulletArea/CollisionShape2D.set_deferred("disabled", true)
	$DeathParticle.emitting = true

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
