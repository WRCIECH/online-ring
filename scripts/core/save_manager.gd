extends Node

const SAVE_PATH := "user://save_data.json"
const CONFIG_PATH := "user://player.cfg"
const API_BASE_URL := "http://localhost:8000"  # Replace with Railway URL in production

var player_id: String = ""
var _pending_sync: bool = false

var _http: HTTPRequest

signal save_completed
signal load_completed
signal sync_succeeded
signal sync_failed

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
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
	data["saved_at"] = Time.get_unix_time_from_system()
	_save_local(data)
	_sync_to_server(data)
	save_completed.emit()

func load_game() -> void:
	var data := _load_local()
	if data.is_empty():
		load_completed.emit()
		return
	GameManager.load_save_data(data)
	load_completed.emit()

# ── Local persistence ─────────────────────────────────────────────────────────

func _save_local(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _load_local() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

# ── Remote sync ───────────────────────────────────────────────────────────────

func _sync_to_server(data: Dictionary) -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_pending_sync = true  # retry on next save
		return
	var body := JSON.stringify(data)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(API_BASE_URL + "/save", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("SaveManager: HTTP request failed to start (offline?)")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		sync_succeeded.emit()
	else:
		push_warning("SaveManager: sync failed — result=%d code=%d (offline mode active)" % [result, response_code])
		sync_failed.emit()
