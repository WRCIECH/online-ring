extends Node

var SAVE_PATH:   String = "user://save_data_dev.json"        if OS.has_feature("editor") else "user://save_data.json"
var BACKUP_PATH: String = "user://save_data_backup_dev.json" if OS.has_feature("editor") else "user://save_data_backup.json"
const CONFIG_PATH := "user://player.cfg"

# Set to true once Railway is deployed and API_BASE_URL is updated.
const SYNC_ENABLED := false
const API_BASE_URL := "http://localhost:8000"

var player_id: String = ""

var _http_save: HTTPRequest   # POST /save
var _http_load: HTTPRequest   # GET  /save/{id}

signal save_completed
signal load_completed
signal sync_succeeded
signal sync_failed

func _ready() -> void:
	_http_save = HTTPRequest.new()
	add_child(_http_save)
	_http_save.request_completed.connect(_on_save_response)

	_http_load = HTTPRequest.new()
	add_child(_http_load)
	_http_load.request_completed.connect(_on_load_response)

	_ensure_player_id()

func _ensure_player_id() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		player_id = cfg.get_value("player", "id", "")
	if player_id.is_empty():
		player_id = "player_%d_%d" % [randi(), int(Time.get_unix_time_from_system())]
		cfg.set_value("player", "id", player_id)
		cfg.save(CONFIG_PATH)

# ── Public API ────────────────────────────────────────────────────────────────

func save_game() -> void:
	var data := GameManager.get_save_data()
	data["player_id"] = player_id
	data["saved_at"]  = Time.get_unix_time_from_system()
	_save_local(data)
	if SYNC_ENABLED:
		_push_to_server(data)
	save_completed.emit()

func load_game() -> void:
	var local: Dictionary = _load_local()
	if not local.is_empty():
		GameManager.load_save_data(local)
	load_completed.emit()
	if SYNC_ENABLED:
		_fetch_from_server()

# ── Local persistence ─────────────────────────────────────────────────────────

func _save_local(data: Dictionary) -> void:
	# Rotate current save to backup before overwriting
	if FileAccess.file_exists(SAVE_PATH):
		var old := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if old:
			var content := old.get_as_text()
			old.close()
			var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if bak:
				bak.store_string(content)
				bak.close()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _load_local() -> Dictionary:
	var result := _try_load(SAVE_PATH)
	if not result.is_empty():
		return result
	# Primary corrupt or missing — try backup
	var backup := _try_load(BACKUP_PATH)
	if not backup.is_empty():
		push_warning("SaveManager: primary save corrupt, loaded from backup")
	return backup

func _try_load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

# ── Remote save ───────────────────────────────────────────────────────────────

func _push_to_server(data: Dictionary) -> void:
	if _http_save.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return  # previous request still in flight; local save already done
	var body    := JSON.stringify(data)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err     := _http_save.request(API_BASE_URL + "/save", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("SaveManager: push failed to start (offline?)")

func _on_save_response(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		sync_succeeded.emit()
	else:
		push_warning("SaveManager: push failed — result=%d code=%d" % [result, response_code])
		sync_failed.emit()

# ── Remote load (background, applies only if server data is newer) ────────────

func _fetch_from_server() -> void:
	if player_id.is_empty():
		return
	if _http_load.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var err := _http_load.request(API_BASE_URL + "/save/" + player_id)
	if err != OK:
		push_warning("SaveManager: fetch failed to start (offline?)")

func _on_load_response(result: int, response_code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return  # offline or no server save — stay with local data

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return

	var server: Dictionary = parsed
	var local:  Dictionary = _load_local()

	var server_time: float = server.get("saved_at", 0.0)
	var local_time:  float = local.get("saved_at",  0.0)

	if server_time > local_time:
		GameManager.load_save_data(server)
		_save_local(server)  # cache so next cold start uses it immediately
		push_warning("SaveManager: applied newer save from server (%.0f > %.0f)" % [server_time, local_time])
