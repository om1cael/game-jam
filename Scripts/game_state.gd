extends Node

const SAVE_PATH: String = "user://fallen_astro_save.json"
const PART_NAMES: Array[String] = [
	"REATOR",
	"BATERIA",
	"RÁDIO DE TELECOMUNICAÇÕES",
	"ESCOTILHA"
]

var score: int = 0
var high_score: int = 0
var current_round: int = 1
var ship_parts: Array[String] = []
var campaign_active: bool = false
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
	campaign_active = true
	save_data()

func load_campaign() -> bool:
	if not campaign_active:
		return false
	return true

func add_score(amount: int) -> void:
	if amount <= 0:
		return
	score += amount
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
		"version": 1,
		"score": score,
		"high_score": high_score,
		"current_round": clampi(current_round, 1, 5),
		"ship_parts": ship_parts,
		"campaign_active": campaign_active,
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
