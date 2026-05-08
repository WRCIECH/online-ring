class_name MapNode
extends Node2D

const RADIUS: float = GameConstants.MAP_NODE_RADIUS
const LABEL_WIDTH := 130.0

var location_id: String = ""
var location_data: Dictionary = {}

signal clicked

var _hovered: bool = false

# ── State ─────────────────────────────────────────────────────────────────────

func refresh_state() -> void:
	queue_redraw()

func _is_accessible() -> bool:
	if GameManager.discovered_locations.has(location_id):
		return true
	var current := GameManager.current_location
	if current.is_empty():
		return true
	if WorldMap.MAP_DATA.get(current, {}).get("connections", []).has(location_id):
		return true
	if location_data.get("connections", []).has(current):
		return true
	return false

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var is_unlocked: bool = GameManager.unlocked_areas.has(location_data.get("area", ""))
	var is_current: bool  = GameManager.current_location == location_id
	var is_grace: bool    = location_data.get("is_site_of_grace", false)
	var is_boss: bool     = location_data.get("is_remembrance",   false)
	var is_merchant: bool = location_data.get("is_merchant",      false)

	var enemy_id: String  = location_data.get("enemy_id", "")
	var is_defeated: bool = not enemy_id.is_empty() and GameManager.defeated_enemies.has(enemy_id)
	var has_lost_runes: bool = (location_id == GameManager.death_location
								and GameManager.runes_at_death > 0)

	# ── Base colour ───────────────────────────────────────────────────────────
	var base_color: Color
	if not is_unlocked:
		base_color = GameConstants.COLOR_LOCKED_NODE
	elif is_grace:
		base_color = GameConstants.COLOR_SITE_OF_GRACE
	elif is_merchant:
		base_color = GameConstants.COLOR_MERCHANT
	elif is_boss:
		base_color = GameConstants.COLOR_REMEMBRANCE
	else:
		base_color = GameConstants.COLOR_ENEMY_AREA

	if is_defeated and not is_grace:
		base_color = base_color.darkened(0.35)

	var accessible: bool = true
	if is_unlocked:
		accessible = _is_accessible()
		if not accessible:
			base_color = base_color.darkened(0.50)
			base_color.a = 0.40

	if _hovered and is_unlocked and accessible:
		base_color = base_color.lightened(GameConstants.COLOR_HOVER_AMOUNT)

	# ── Rings (outermost first) ───────────────────────────────────────────────

	# Amber ring = lost runes here
	if has_lost_runes:
		draw_circle(Vector2.ZERO, RADIUS + 13.0, Color(1.0, 0.78, 0.10))
		draw_circle(Vector2.ZERO, RADIUS + 9.5,  GameConstants.COLOR_MAP_BG)

	# Gold ring = current location
	if is_current:
		draw_circle(Vector2.ZERO, RADIUS + 6.5, GameConstants.COLOR_CURRENT_LOCATION)

	# ── Main circle ───────────────────────────────────────────────────────────
	var draw_color: Color = base_color
	if is_defeated and not is_grace:
		draw_color.a = 0.60
	draw_circle(Vector2.ZERO, RADIUS, draw_color)

	# ── Inner indicator ───────────────────────────────────────────────────────
	if is_defeated and not is_grace:
		# X = cleared
		var r: float = RADIUS * 0.38
		draw_line(Vector2(-r, -r), Vector2(r,  r), Color(1, 1, 1, 0.45), 2.0)
		draw_line(Vector2( r, -r), Vector2(-r, r), Color(1, 1, 1, 0.45), 2.0)
	elif is_merchant:
		# Gold coin dot
		draw_circle(Vector2.ZERO, RADIUS * 0.38, Color(0.95, 0.82, 0.22))
	else:
		draw_circle(Vector2.ZERO, RADIUS * 0.35, Color(1, 1, 1, 0.22))

	# ── Labels ────────────────────────────────────────────────────────────────
	var font: Font = ThemeDB.fallback_font
	if font:
		var label: String = location_data.get("name", "")
		draw_string(
			font,
			Vector2(-LABEL_WIDTH * 0.5, RADIUS + 16.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			LABEL_WIDTH,
			11,
			Color(0.88, 0.82, 0.65)
		)
		if has_lost_runes:
			draw_string(
				font,
				Vector2(-LABEL_WIDTH * 0.5, RADIUS + 28.0),
				"%d runes" % GameManager.runes_at_death,
				HORIZONTAL_ALIGNMENT_CENTER,
				LABEL_WIDTH,
				10,
				Color(1.0, 0.78, 0.10)
			)

# ── Input ─────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	# get_global_mouse_position() returns world coordinates (Camera2D-aware)
	var mouse_world := get_global_mouse_position()
	var was_hovered := _hovered
	_hovered = global_position.distance_to(mouse_world) <= RADIUS
	if _hovered != was_hovered:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var mouse_world := get_global_mouse_position()
	if global_position.distance_to(mouse_world) <= RADIUS:
		clicked.emit()
		get_viewport().set_input_as_handled()
