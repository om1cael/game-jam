extends Node

const MENU_MUSIC: String = "res://sounds/intro.mp3"
const GAME_MUSIC: String = "res://sounds/in_game.mp3"

var music_player: AudioStreamPlayer
var active_track: String = ""
var music_tween: Tween
var effect_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	apply_settings()
	play_menu_music()

func play_menu_music() -> void:
	_play_track(MENU_MUSIC)

func play_game_music() -> void:
	_play_track(GAME_MUSIC)

func play_effect(path: String) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_error("Efeito sonoro não encontrado ou inválido: %s" % path)
		return
	var available_player: AudioStreamPlayer
	for player: AudioStreamPlayer in effect_players:
		if not player.playing:
			available_player = player
			break
	if available_player == null:
		if effect_players.size() >= 12:
			push_warning("Limite de reprodução simultânea de efeitos sonoros atingido.")
			return
		available_player = AudioStreamPlayer.new()
		available_player.bus = "SFX"
		add_child(available_player)
		effect_players.append(available_player)
	available_player.stream = stream
	available_player.play()

func _play_track(path: String) -> void:
	if active_track == path and music_player.playing:
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_error("Faixa de áudio não encontrada ou inválida: %s" % path)
		return
	if stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream
		mp3_stream.loop = true
	if music_tween and music_tween.is_running():
		music_tween.kill()
	active_track = path
	if music_player.playing:
		music_tween = create_tween()
		music_tween.tween_property(music_player, "volume_db", -60.0, 0.25)
		music_tween.tween_callback(func() -> void:
			music_player.stream = stream
			music_player.play()
			music_player.volume_db = -30.0
			var fade_in: Tween = create_tween()
			fade_in.tween_property(music_player, "volume_db", 0.0, 0.4)
		)
	else:
		music_player.stream = stream
		music_player.volume_db = -30.0
		music_player.play()
		music_tween = create_tween()
		music_tween.tween_property(music_player, "volume_db", 0.0, 0.4)

func apply_settings() -> void:
	if music_player == null:
		return
	var master_bus: int = AudioServer.get_bus_index("Master")
	var music_bus: int = AudioServer.get_bus_index("Music")
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	var master_volume: float = float(GameState.settings["master_volume"])
	var music_volume: float = float(GameState.settings["music_volume"])
	var sfx_volume: float = float(GameState.settings["sfx_volume"])
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.001)))
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(music_volume, 0.001)))
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(sfx_volume, 0.001)))
	var window_mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(GameState.settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)
	var resolution: Vector2i = GameState.settings["resolution"]
	if not bool(GameState.settings["fullscreen"]):
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		if resolution.x <= screen_size.x and resolution.y <= screen_size.y:
			DisplayServer.window_set_size(resolution)
		else:
			push_warning("A resolução salva excede a tela; a resolução atual foi mantida.")
		music_player.volume_db = 0.0

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
