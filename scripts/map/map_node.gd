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

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var is_unlocked := GameManager.unlocked_areas.has(location_data.get("area", ""))
	var is_current  := GameManager.current_location == location_id
	var is_grace: bool = location_data.get("is_site_of_grace", false)
	var is_boss: bool  = location_data.get("is_remembrance", false)

	var base_color: Color
	if not is_unlocked:
		base_color = GameConstants.COLOR_LOCKED_NODE
	elif is_grace:
		base_color = GameConstants.COLOR_SITE_OF_GRACE
	elif is_boss:
		base_color = GameConstants.COLOR_REMEMBRANCE
	else:
		base_color = GameConstants.COLOR_ENEMY_AREA

	if _hovered and is_unlocked:
		base_color = base_color.lightened(GameConstants.COLOR_HOVER_AMOUNT)

	# Outer pulse ring for current location
	if is_current:
		draw_circle(Vector2.ZERO, RADIUS + 7.0, GameConstants.COLOR_CURRENT_LOCATION)

	draw_circle(Vector2.ZERO, RADIUS, base_color)

	# Inner dot
	draw_circle(Vector2.ZERO, RADIUS * 0.35, Color(1, 1, 1, 0.25))

	# Location name below node
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

# ── Input ─────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var mouse_pos  := get_viewport().get_mouse_position()
	var was_hovered := _hovered
	_hovered = global_position.distance_to(mouse_pos) <= RADIUS
	if _hovered != was_hovered:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	if global_position.distance_to(mouse_pos) <= RADIUS:
		clicked.emit()
		get_viewport().set_input_as_handled()
