extends Node

const MENU_MUSIC: String = "res://sounds/intro.mp3"
const GAME_MUSIC: String = "res://sounds/in_game.mp3"
const SYNTH_SAMPLE_RATE: int = 22050
const DEATH_MUSIC_DURATION: float = 7.2

var music_player: AudioStreamPlayer
var active_track: String = ""
var music_tween: Tween
var effect_players: Array[AudioStreamPlayer] = []
var generated_effects: Dictionary = {}

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)
	generated_effects = {
		"shot": _make_synth_sound(0.11, 1050.0, 260.0, 0.24, 0.08),
		"enemy_shot": _make_synth_sound(0.18, 660.0, 190.0, 0.16, 0.12),
		"enemy_down": _make_synth_sound(0.16, 360.0, 95.0, 0.18, 0.16),
		"damage": _make_synth_sound(0.22, 210.0, 72.0, 0.26, 0.24),
		"emp": _make_synth_sound(0.48, 180.0, 980.0, 0.2, 0.18),
		"shield": _make_synth_sound(0.3, 420.0, 1180.0, 0.17, 0.04),
		"overdrive": _make_synth_sound(0.4, 280.0, 1240.0, 0.22, 0.05),
		"death": _make_synth_sound(1.15, 520.0, 62.0, 0.95, 0.32),
		"boss_shot": _make_synth_sound(0.2, 540.0, 150.0, 0.2, 0.14),
		"pickup": _make_synth_sound(0.24, 520.0, 1040.0, 0.17, 0.0)
	}
	apply_settings()
	play_menu_music()

func play_menu_music() -> void:
	_play_track(MENU_MUSIC)

func play_game_music() -> void:
	_play_track(GAME_MUSIC)

func play_death_music() -> void:
	if active_track == "generated://death" and music_player.playing:
		return
	_play_generated_music(_make_death_theme(), "generated://death")

func play_sfx(effect_name: String) -> void:
	if not generated_effects.has(effect_name):
		push_warning("Efeito sonoro procedural desconhecido: %s" % effect_name)
		return
	_play_stream_on_sfx_bus(generated_effects[effect_name] as AudioStream)

func play_effect(path: String) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_error("Efeito sonoro não encontrado ou inválido: %s" % path)
		return
	_play_stream_on_sfx_bus(stream)

func _play_stream_on_sfx_bus(stream: AudioStream) -> void:
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
	_play_music_stream(stream, path)

func _play_generated_music(stream: AudioStream, track_id: String) -> void:
	_play_music_stream(stream, track_id)

func _play_music_stream(stream: AudioStream, track_id: String) -> void:
	if music_tween and music_tween.is_running():
		music_tween.kill()
	active_track = track_id
	if music_player.playing:
		music_tween = create_tween()
		music_tween.tween_property(music_player, "volume_db", -60.0, 0.25)
		music_tween.tween_callback(func() -> void:
			music_player.stream = stream
			music_player.play()
			music_player.volume_db = -30.0
			music_tween = create_tween()
			music_tween.tween_property(music_player, "volume_db", 0.0, 0.4)
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

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func _make_synth_sound(
	duration: float,
	start_frequency: float,
	end_frequency: float,
	amplitude: float,
	noise_amount: float
) -> AudioStreamWAV:
	var sample_count: int = maxi(1, roundi(duration * SYNTH_SAMPLE_RATE))
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(sample_count * 2)
	for sample_index: int in sample_count:
		var progress: float = float(sample_index) / float(sample_count)
		var sweep: float = start_frequency * progress
		sweep += (end_frequency - start_frequency) * progress * progress * 0.5
		var phase: float = TAU * sweep * duration
		var tone: float = sin(phase) * 0.72 + sin(phase * 2.0) * 0.18
		var noise: float = fposmod(sin(float(sample_index) * 12.9898) * 43758.5453, 2.0) - 1.0
		var envelope: float = minf(1.0, progress * 45.0) * pow(1.0 - progress, 1.5)
		var mixed_signal: float = tone * (1.0 - noise_amount) + noise * noise_amount
		var value: float = clampf(mixed_signal * envelope * amplitude, -1.0, 1.0)
		samples.encode_s16(sample_index * 2, roundi(value * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SYNTH_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = samples
	return stream

func _make_death_theme() -> AudioStreamWAV:
	var notes: Array[float] = [392.0, 349.23, 311.13, 261.63, 233.08, 207.65, 196.0, 155.56, 130.81]
	var note_duration: float = 0.8
	var sample_count: int = roundi(DEATH_MUSIC_DURATION * SYNTH_SAMPLE_RATE)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(sample_count * 2)
	for sample_index: int in sample_count:
		var elapsed: float = float(sample_index) / float(SYNTH_SAMPLE_RATE)
		var note_index: int = mini(floori(elapsed / note_duration), notes.size() - 1)
		var note_progress: float = fposmod(elapsed, note_duration)
		var frequency: float = notes[note_index]
		var attack: float = minf(1.0, note_progress * 12.0)
		var release: float = 1.0 - 0.5 * note_progress / note_duration
		var envelope: float = attack * release
		var fade_out: float = 1.0 - 0.55 * elapsed / DEATH_MUSIC_DURATION
		var melody: float = sin(TAU * frequency * elapsed) * 0.62
		var harmony: float = sin(TAU * frequency * 0.5 * elapsed) * 0.28
		var overtone: float = sin(TAU * frequency * 1.5 * elapsed) * 0.1
		var value: float = clampf((melody + harmony + overtone) * envelope * fade_out * 0.24, -1.0, 1.0)
		samples.encode_s16(sample_index * 2, roundi(value * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SYNTH_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = samples
	return stream

func _on_music_finished() -> void:
	active_track = ""
