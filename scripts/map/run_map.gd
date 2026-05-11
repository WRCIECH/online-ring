extends Control

# ── Spiral geometry ────────────────────────────────────────────────────────────
const CX     := 600.0          # spiral centre x
const CY     := 390.0          # spiral centre y
const R0     := 45.0           # radius of first node from centre
const DR     := 16.0           # radius increase per step
const DTHETA := 1.082          # ~62° per step in radians
const NODE_R := 14.0           # default node circle radius
const BOSS_R := 20.0           # boss node radius

# ── Enemy name map ─────────────────────────────────────────────────────────────
const ENEMY_ICON := {
	"procrastination_mob": "●",
	"hater":               "▲",
	"blank_page_omen":     "◆",
	"perfectionism_knight":"★",
}

# ── State ─────────────────────────────────────────────────────────────────────
var _positions:    PackedVector2Array
var _timer_lbl:    Label
var _info_name:    Label
var _info_enemy:   Label
var _info_desc:    Label
var _info_mult:    Label
var _enter_btn:    Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_compute_positions()
	_build_ui()
	_build_node_buttons()
	_select_current()

# ── Position maths ─────────────────────────────────────────────────────────────

func _compute_positions() -> void:
	var theta := -PI * 0.5
	var n: int = GameManager.run_location_sequence.size()
	for i in range(n):
		var r := R0 + i * DR
		_positions.append(Vector2(CX + r * cos(theta), CY + r * sin(theta)))
		theta += DTHETA

# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var cur := GameManager.run_current_index
	var n   := _positions.size()

	# ── Connector lines ────────────────────────────────────────────────────────
	for i in range(1, n):
		var beaten := i <= cur
		var col := Color(0.42, 0.38, 0.55, 0.9) if beaten \
				   else Color(0.22, 0.20, 0.30, 0.6)
		draw_line(_positions[i - 1], _positions[i], col, 2.0)

	# ── Node circles ──────────────────────────────────────────────────────────
	for i in range(n):
		var pos  := _positions[i]
		var loc: Dictionary = GameManager.run_location_sequence[i]
		var is_boss  := (i == n - 1)
		var beaten   := (i < cur)
		var active   := (i == cur)
		var radius   := BOSS_R if is_boss else NODE_R
		if active: radius += 3.0

		# Outer glow for active / boss
		if active:
			draw_circle(pos, radius + 5.0, Color(0.90, 0.75, 0.20, 0.18))
		if is_boss and active:
			draw_circle(pos, radius + 9.0, Color(0.90, 0.30, 0.10, 0.12))

		# Background circle
		var bg: Color
		if beaten:
			bg = Color(0.20, 0.32, 0.20)
		elif active:
			bg = Color(0.22, 0.18, 0.08)
		elif is_boss:
			bg = Color(0.28, 0.08, 0.06)
		else:
			bg = Color(0.12, 0.10, 0.18)
		draw_circle(pos, radius, bg)

		# Border
		var border: Color
		if beaten:
			border = Color(0.35, 0.62, 0.35)
		elif active:
			border = Color(0.90, 0.75, 0.20)
		elif is_boss:
			border = Color(0.75, 0.28, 0.12)
		else:
			border = Color(0.35, 0.30, 0.45)
		draw_arc(pos, radius, 0.0, TAU, 32, border, 2.0)

		# Number label
		var num_col: Color
		if beaten:      num_col = Color(0.40, 0.70, 0.40)
		elif active:    num_col = Color(0.95, 0.85, 0.30)
		elif is_boss:   num_col = Color(0.90, 0.50, 0.30)
		else:           num_col = Color(0.55, 0.50, 0.65)

		var num_str := "★" if is_boss else str(i + 1)
		draw_string(ThemeDB.fallback_font,
			pos + Vector2(-6 if i < 9 else -9, 5),
			num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, num_col)

# ── Node buttons (invisible, one per location) ─────────────────────────────────

func _build_node_buttons() -> void:
	var n := _positions.size()
	for i in range(n):
		var pos := _positions[i]
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(40, 40)
		btn.position = pos - Vector2(20, 20)
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(s, empty)
		var captured := i
		btn.pressed.connect(func(): _on_node_pressed(captured))
		add_child(btn)

# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Top bar
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 48
	add_child(top)

	var top_m := _margin(top, 8)
	var top_row := HBoxContainer.new()
	top_m.add_child(top_row)

	var title := Label.new()
	title.text = "GREAT RUN"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)

	_timer_lbl = Label.new()
	_timer_lbl.add_theme_font_size_override("font_size", 14)
	_timer_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_timer_lbl)

	# Legend row (top-right corner)
	var legend := PanelContainer.new()
	legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	legend.offset_left   = -210
	legend.offset_right  = -10
	legend.offset_top    = 56
	legend.offset_bottom = 130
	add_child(legend)

	var leg_m := _margin(legend, 8)
	var leg_v := VBoxContainer.new()
	leg_v.add_theme_constant_override("separation", 3)
	leg_m.add_child(leg_v)

	for entry: Array in [
		[Color(0.35, 0.62, 0.35), "Defeated"],
		[Color(0.90, 0.75, 0.20), "Current"],
		[Color(0.55, 0.50, 0.65), "Upcoming"],
		[Color(0.75, 0.28, 0.12), "★ Boss"],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		leg_v.add_child(row)
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 12)
		dot.add_theme_color_override("font_color", entry[0])
		row.add_child(dot)
		var lbl := Label.new()
		lbl.text = entry[1]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
		row.add_child(lbl)

	# Info panel — bottom
	var info := PanelContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_top    = -148
	info.offset_bottom = 0
	info.offset_left   = 0
	info.offset_right  = 0
	add_child(info)

	var info_m := _margin(info, 10)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 20)
	info_m.add_child(info_row)

	var info_text := VBoxContainer.new()
	info_text.add_theme_constant_override("separation", 4)
	info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(info_text)

	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 18)
	_info_name.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	info_text.add_child(_info_name)

	_info_enemy = Label.new()
	_info_enemy.add_theme_font_size_override("font_size", 13)
	_info_enemy.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	info_text.add_child(_info_enemy)

	_info_mult = Label.new()
	_info_mult.add_theme_font_size_override("font_size", 11)
	_info_mult.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	info_text.add_child(_info_mult)

	_info_desc = Label.new()
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_desc.add_theme_font_size_override("font_size", 12)
	_info_desc.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
	info_text.add_child(_info_desc)

	_enter_btn = Button.new()
	_enter_btn.text = "Enter\nLocation"
	_enter_btn.custom_minimum_size = Vector2(120, 80)
	_enter_btn.disabled = true
	_enter_btn.pressed.connect(_on_enter)
	info_row.add_child(_enter_btn)

# ── Interaction ────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if GameManager.run_active:
		var secs := int(GameManager.run_elapsed_seconds())
		_timer_lbl.text = "Elapsed  %02d:%02d:%02d" % [secs / 3600, (secs % 3600) / 60, secs % 60]

func _on_node_pressed(idx: int) -> void:
	_show_info(idx)

func _select_current() -> void:
	_show_info(GameManager.run_current_index)

func _show_info(idx: int) -> void:
	if idx < 0 or idx >= GameManager.run_location_sequence.size():
		return
	var loc: Dictionary = GameManager.run_location_sequence[idx]
	var enemy: Dictionary = EnemyDB.ENEMIES.get(loc.get("enemy_id", ""), {})
	var cur := GameManager.run_current_index
	var beaten := idx < cur

	_info_name.text  = loc.get("name", "")
	_info_enemy.text = enemy.get("name", "")
	var mult: float  = loc.get("mult", 1.0)
	var hp: int      = int(enemy.get("max_hp", 0) * mult)
	_info_mult.text  = "HP: %d   (×%.2f difficulty)" % [hp, mult] if not beaten \
					   else "Defeated"
	_info_desc.text  = enemy.get("description", "")

	_enter_btn.disabled = beaten or idx != cur
	queue_redraw()

func _on_enter() -> void:
	var loc := GameManager.current_location_data()
	if loc.is_empty():
		return
	GameManager.pending_encounter = {
		"enemy_id":        loc.get("enemy_id", "procrastination_mob"),
		"difficulty_mult": loc.get("mult", 1.0),
	}
	get_tree().change_scene_to_file("res://scenes/combat/combat.tscn")

func _margin(parent: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	parent.add_child(m)
	return m
