extends Node

const SETTINGS_PATH := "user://settings.cfg"

var always_on_top:  bool  = false
var fullscreen:     bool  = false
var master_volume:  float = 1.0

signal settings_changed

func _ready() -> void:
	_load()
	_apply_all()

# ── Public setters (apply + persist immediately) ──────────────────────────────

func set_always_on_top(value: bool) -> void:
	always_on_top = value
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, value)
	_save()
	settings_changed.emit()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	if value:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save()
	settings_changed.emit()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	var db: float = linear_to_db(master_volume) if master_volume > 0.0 else -80.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	_save()
	settings_changed.emit()

# ── Internal ──────────────────────────────────────────────────────────────────

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	always_on_top = cfg.get_value("display", "always_on_top", false)
	fullscreen    = cfg.get_value("display", "fullscreen",    false)
	master_volume = cfg.get_value("audio",   "master_volume", 1.0)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "always_on_top", always_on_top)
	cfg.set_value("display", "fullscreen",    fullscreen)
	cfg.set_value("audio",   "master_volume", master_volume)
	cfg.save(SETTINGS_PATH)

func _apply_all() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, always_on_top)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var db: float = linear_to_db(master_volume) if master_volume > 0.0 else -80.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
