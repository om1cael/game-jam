extends Node

const SAVE_PATH: String = "user://fallen_astro_save.json"
const PART_NAMES: Array[String] = [
	"REATOR",
	"BATERIA",
	"RÁDIO DE TELECOMUNICAÇÕES",
	"ESCOTILHA"
]
const DIFFICULTY_CONFIG: Dictionary = {
	"easy": {
		"label": "FÁCIL",
		"player_lives": 4.0,
		"incoming_damage": 0.6,
		"enemy_health": 0.85,
		"enemy_speed": 0.9,
		"spawn_pressure": 0.8,
		"score_multiplier": 0.75
	},
	"medium": {
		"label": "MÉDIO",
		"player_lives": 3.0,
		"incoming_damage": 1.0,
		"enemy_health": 1.0,
		"enemy_speed": 1.0,
		"spawn_pressure": 1.0,
		"score_multiplier": 1.0
	},
	"hard": {
		"label": "DIFÍCIL",
		"player_lives": 3.0,
		"incoming_damage": 1.35,
		"enemy_health": 1.18,
		"enemy_speed": 1.08,
		"spawn_pressure": 1.2,
		"score_multiplier": 1.5
	},
	"hardcore": {
		"label": "HARDCORE",
		"player_lives": 2.0,
		"incoming_damage": 1.75,
		"enemy_health": 1.4,
		"enemy_speed": 1.2,
		"spawn_pressure": 1.45,
		"score_multiplier": 2.25
	}
}
const WEAPON_UPGRADE_IDS: Array[String] = [
	"rapid_fire",
	"heavy_rounds",
	"long_barrel",
	"extended_magazine"
]

var score: int = 0
var high_score: int = 0
var current_round: int = 1
var ship_parts: Array[String] = []
var campaign_active: bool = false
var difficulty: String = "medium"
var weapon_upgrades: Dictionary = {
	"rapid_fire": 0,
	"heavy_rounds": 0,
	"long_barrel": 0,
	"extended_magazine": 0
}
var last_weapon_upgrade: String = ""
var settings: Dictionary = {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"resolution": Vector2i(1280, 720)
}

func _ready() -> void:
	load_data()

func start_new_campaign() -> void:
	score = 0
	current_round = 1
	ship_parts.clear()
	weapon_upgrades = {
		"rapid_fire": 0,
		"heavy_rounds": 0,
		"long_barrel": 0,
		"extended_magazine": 0
	}
	last_weapon_upgrade = ""
	campaign_active = true
	save_data()

func set_difficulty(value: String) -> void:
	if not DIFFICULTY_CONFIG.has(value):
		push_warning("Dificuldade inválida; mantendo MÉDIO.")
		difficulty = "medium"
	else:
		difficulty = value
	save_data()

func get_difficulty_config() -> Dictionary:
	return DIFFICULTY_CONFIG.get(difficulty, DIFFICULTY_CONFIG["medium"]).duplicate()

func apply_weapon_upgrade(upgrade_id: String) -> bool:
	if not WEAPON_UPGRADE_IDS.has(upgrade_id):
		push_warning("Melhoria de arma inválida: %s" % upgrade_id)
		return false
	weapon_upgrades[upgrade_id] = int(weapon_upgrades.get(upgrade_id, 0)) + 1
	last_weapon_upgrade = upgrade_id
	save_data()
	return true

func weapon_upgrade_level(upgrade_id: String) -> int:
	if not WEAPON_UPGRADE_IDS.has(upgrade_id):
		return 0
	return maxi(0, int(weapon_upgrades.get(upgrade_id, 0)))

func load_campaign() -> bool:
	if not campaign_active:
		return false
	return true

func add_score(amount: int) -> void:
	if amount <= 0:
		return
	var score_multiplier: float = float(get_difficulty_config()["score_multiplier"])
	score += roundi(float(amount) * score_multiplier)
	high_score = maxi(high_score, score)

func claim_component(round_number: int) -> String:
	if round_number < 1 or round_number > PART_NAMES.size():
		return ""
	var part: String = PART_NAMES[round_number - 1]
	if not ship_parts.has(part):
		ship_parts.append(part)
	save_data()
	return part

func save_data() -> void:
	high_score = maxi(high_score, score)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível salvar FALLEN ASTRO: %s" % error_string(FileAccess.get_open_error()))
		return
	var saved_settings: Dictionary = settings.duplicate(true)
	var saved_resolution: Vector2i = settings["resolution"]
	saved_settings["resolution"] = [saved_resolution.x, saved_resolution.y]
	var payload: Dictionary = {
		"version": 3,
		"score": score,
		"high_score": high_score,
		"current_round": clampi(current_round, 1, 5),
		"ship_parts": ship_parts,
		"campaign_active": campaign_active,
		"difficulty": difficulty,
		"weapon_upgrades": weapon_upgrades,
		"last_weapon_upgrade": last_weapon_upgrade,
		"settings": saved_settings
	}
	file.store_string(JSON.stringify(payload))
	file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Não foi possível ler o arquivo de progresso de FALLEN ASTRO.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Arquivo de progresso inválido; os valores padrão serão usados.")
		return
	var data: Dictionary = parsed
	var saved_difficulty: String = str(data.get("difficulty", "medium"))
	difficulty = saved_difficulty if DIFFICULTY_CONFIG.has(saved_difficulty) else "medium"
	_load_weapon_upgrades(data.get("weapon_upgrades", {}), str(data.get("last_weapon_upgrade", "")))
	high_score = maxi(0, int(data.get("high_score", 0)))
	if data.has("settings") and typeof(data["settings"]) == TYPE_DICTIONARY:
		_load_settings(data["settings"])
	var saved_parts: Variant = data.get("ship_parts", [])
	if typeof(saved_parts) == TYPE_ARRAY:
		for part: Variant in saved_parts:
			if typeof(part) == TYPE_STRING and PART_NAMES.has(part) and not ship_parts.has(part):
				ship_parts.append(part)
	campaign_active = bool(data.get("campaign_active", false))
	if campaign_active:
		current_round = clampi(int(data.get("current_round", 1)), 1, 5)
		score = maxi(0, int(data.get("score", 0)))
		high_score = maxi(high_score, score)
		current_round = mini(current_round, ship_parts.size() + 1)

func _load_weapon_upgrades(saved: Variant, saved_last_upgrade: String) -> void:
	weapon_upgrades = {
		"rapid_fire": 0,
		"heavy_rounds": 0,
		"long_barrel": 0,
		"extended_magazine": 0
	}
	if typeof(saved) == TYPE_DICTIONARY:
		for upgrade_id: String in WEAPON_UPGRADE_IDS:
			var level: Variant = saved.get(upgrade_id, 0)
			if typeof(level) == TYPE_INT or typeof(level) == TYPE_FLOAT:
				weapon_upgrades[upgrade_id] = maxi(0, int(level))
	last_weapon_upgrade = saved_last_upgrade if WEAPON_UPGRADE_IDS.has(saved_last_upgrade) else ""

func _load_settings(saved: Dictionary) -> void:
	for key: String in ["master_volume", "music_volume", "sfx_volume"]:
		if saved.has(key) and (typeof(saved[key]) == TYPE_FLOAT or typeof(saved[key]) == TYPE_INT):
			settings[key] = clampf(float(saved[key]), 0.0, 1.0)
	if saved.has("fullscreen"):
		settings["fullscreen"] = bool(saved["fullscreen"])
	var resolution: Variant = saved.get("resolution", Vector2i(1280, 720))
	if typeof(resolution) == TYPE_ARRAY and resolution.size() == 2:
		settings["resolution"] = Vector2i(int(resolution[0]), int(resolution[1]))
	elif typeof(resolution) == TYPE_VECTOR2I:
		settings["resolution"] = resolution

func save_settings() -> void:
	save_data()
