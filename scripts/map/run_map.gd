extends Control

# ── Spiral geometry ────────────────────────────────────────────────────────────
const CX     := 600.0
const CY     := 390.0
const R0     := 45.0
const DR     := 16.0
const DTHETA := 1.082
const NODE_R := 14.0

# ── State ─────────────────────────────────────────────────────────────────────
var _positions:     PackedVector2Array
var _bg_particles:  Array   # precomputed [[Vector2, radius, alpha], ...]
var _timer_lbl:     Label

# Hover tooltip
var _hover_panel:   PanelContainer
var _hover_lbl:     Label

# Click popup
var _location_popup: CanvasLayer
var _popup_name:     Label
var _popup_enemy:    Label
var _popup_mult:     Label
var _popup_desc:     Label
var _popup_enter:    Button

var _notepad:           NotepadOverlay
var _equip_overlay:     CanvasLayer
var _equip_left_col:    VBoxContainer
var _equip_right_col:   VBoxContainer
var _equip_picker_box:  VBoxContainer
var _equip_active_wid:  String = ""
var _equip_picker_slot: int    = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_compute_positions()
	_compute_bg_particles()
	_build_ui()
	_build_hover_tooltip()
	_build_location_popup()
	_notepad = NotepadOverlay.new()
	add_child(_notepad)
	_build_equip_overlay()
	_build_node_buttons()
	if GameManager.is_run_expired():
		_handle_run_expired()

# ── Position maths ─────────────────────────────────────────────────────────────

func _compute_positions() -> void:
	var theta := -PI * 0.5
	var n: int = GameManager.run_location_sequence.size()
	for i in range(n):
		var r := R0 + i * DR
		_positions.append(Vector2(CX + r * cos(theta), CY + r * sin(theta)))
		theta += DTHETA

func _compute_bg_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4831
	for i in range(100):
		_bg_particles.append([
			Vector2(rng.randf_range(0, 1200), rng.randf_range(0, 800)),
			rng.randf_range(0.5, 2.2),
			rng.randf_range(0.05, 0.20),
		])

# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw_background() -> void:
	# Central glow — layers of soft light around the spiral centre
	draw_circle(Vector2(CX, CY), 400.0, Color(0.14, 0.10, 0.22, 0.28))
	draw_circle(Vector2(CX, CY), 240.0, Color(0.16, 0.12, 0.26, 0.16))
	draw_circle(Vector2(CX, CY), 110.0, Color(0.18, 0.14, 0.28, 0.09))

	# Atmospheric fog patches in the corners / edges
	draw_circle(Vector2( 110,  130), 210.0, Color(0.10, 0.08, 0.18, 0.22))
	draw_circle(Vector2(1090,  160), 190.0, Color(0.08, 0.09, 0.20, 0.18))
	draw_circle(Vector2(  90,  670), 230.0, Color(0.12, 0.08, 0.16, 0.20))
	draw_circle(Vector2(1100,  680), 200.0, Color(0.10, 0.11, 0.18, 0.17))
	draw_circle(Vector2( 580,  740), 170.0, Color(0.08, 0.08, 0.16, 0.14))

	# Dust particles — tiny scattered dots for texture
	for p in _bg_particles:
		draw_circle(p[0], p[1], Color(0.55, 0.50, 0.72, p[2]))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.08))
	_draw_background()

	var cur := GameManager.run_current_index
	var n   := _positions.size()

	for i in range(1, n):
		var beaten := i <= cur
		var col := Color(0.42, 0.38, 0.55, 0.9) if beaten \
				   else Color(0.22, 0.20, 0.30, 0.6)
		draw_line(_positions[i - 1], _positions[i], col, 2.0)

	for i in range(n):
		var pos    := _positions[i]
		var beaten := (i < cur)
		var active := (i == cur)
		var radius := NODE_R
		if active: radius += 3.0

		if active:
			draw_circle(pos, radius + 5.0, Color(0.90, 0.75, 0.20, 0.18))

		var bg: Color
		if beaten:    bg = Color(0.20, 0.32, 0.20)
		elif active:  bg = Color(0.22, 0.18, 0.08)
		else:         bg = Color(0.12, 0.10, 0.18)
		draw_circle(pos, radius, bg)

		var border: Color
		if beaten:    border = Color(0.35, 0.62, 0.35)
		elif active:  border = Color(0.90, 0.75, 0.20)
		else:         border = Color(0.35, 0.30, 0.45)
		draw_arc(pos, radius, 0.0, TAU, 32, border, 2.0)

		var num_col: Color
		if beaten:    num_col = Color(0.40, 0.70, 0.40)
		elif active:  num_col = Color(0.95, 0.85, 0.30)
		else:         num_col = Color(0.55, 0.50, 0.65)

		var num_str := str(i + 1) if (beaten or active) else "?"
		draw_string(ThemeDB.fallback_font,
			pos + Vector2(-5, 5),
			num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, num_col)

# ── Node buttons ───────────────────────────────────────────────────────────────

func _build_node_buttons() -> void:
	var n   := _positions.size()
	var cur := GameManager.run_current_index
	for i in range(n):
		var pos    := _positions[i]
		var future := i > cur
		var btn    := Button.new()
		btn.flat   = true
		btn.custom_minimum_size = Vector2(40, 40)
		btn.position = pos - Vector2(20, 20)
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(s, empty)
		if future:
			btn.disabled = true
			btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		else:
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var captured := i
			btn.pressed.connect(func(): _on_node_pressed(captured))
			btn.mouse_entered.connect(func(): _show_hover(captured))
			btn.mouse_exited.connect(_hide_hover)
		add_child(btn)

# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Top bar
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 48
	add_child(top)

	var top_m   := _margin(top, 8)
	var top_row := HBoxContainer.new()
	top_m.add_child(top_row)

	var title := Label.new()
	title.text = "GREAT RUN  #%d" % GameManager.run_count
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)

	var equip_btn := Button.new()
	equip_btn.text = "⚙"
	equip_btn.tooltip_text = "Equipment"
	equip_btn.custom_minimum_size = Vector2(36, 32)
	equip_btn.add_theme_font_size_override("font_size", 18)
	equip_btn.pressed.connect(_show_equip_overlay)
	top_row.add_child(equip_btn)

	var notes_btn := Button.new()
	notes_btn.text = "✏"
	notes_btn.tooltip_text = "Notepad"
	notes_btn.custom_minimum_size = Vector2(36, 32)
	notes_btn.add_theme_font_size_override("font_size", 18)
	notes_btn.pressed.connect(func(): _notepad.show_notepad())
	top_row.add_child(notes_btn)

	_timer_lbl = Label.new()
	_timer_lbl.add_theme_font_size_override("font_size", 14)
	_timer_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_timer_lbl)


# ── Equipment overlay ──────────────────────────────────────────────────────────

func _build_equip_overlay() -> void:
	_equip_overlay = CanvasLayer.new()
	_equip_overlay.layer = 10
	_equip_overlay.hide()
	add_child(_equip_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_equip_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 580)
	center.add_child(panel)

	var outer := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(outer)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	outer.add_child(root_vbox)

	var title := Label.new()
	title.text = "EQUIPMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	root_vbox.add_child(HSeparator.new())

	# Two-column body
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body)

	# Left: weapon cards + picker
	var left_wrap := VBoxContainer.new()
	left_wrap.custom_minimum_size = Vector2(400, 0)
	left_wrap.add_theme_constant_override("separation", 12)
	body.add_child(left_wrap)

	_equip_left_col = VBoxContainer.new()
	_equip_left_col.add_theme_constant_override("separation", 16)
	left_wrap.add_child(_equip_left_col)

	_equip_picker_box = VBoxContainer.new()
	_equip_picker_box.add_theme_constant_override("separation", 6)
	_equip_picker_box.visible = false
	left_wrap.add_child(_equip_picker_box)

	body.add_child(VSeparator.new())

	# Right: moveset detail list
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)

	_equip_right_col = VBoxContainer.new()
	_equip_right_col.add_theme_constant_override("separation", 6)
	_equip_right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_equip_right_col)

	root_vbox.add_child(HSeparator.new())

	var close_row := CenterContainer.new()
	root_vbox.add_child(close_row)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(140, 36)
	close_btn.pressed.connect(func(): _equip_overlay.hide())
	close_row.add_child(close_btn)

func _show_equip_overlay() -> void:
	for c in _equip_left_col.get_children():   c.queue_free()
	for c in _equip_right_col.get_children():  c.queue_free()
	for c in _equip_picker_box.get_children(): c.queue_free()
	_equip_picker_box.visible = false
	_equip_picker_slot = -1

	for weapon_id in GameManager.equipped_run_weapons:
		_equip_left_col.add_child(_build_weapon_card(weapon_id))

	_refresh_moveset_list()
	_equip_overlay.show()

func _build_weapon_card(weapon_id: String) -> Control:
	var wdata: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
	var wlvl: int         = GameManager.get_weapon_level(weapon_id)
	var wxp: float        = GameManager.get_weapon_xp(weapon_id)
	var thres: float      = WeaponDB.xp_for_next_level(wdata, wlvl)
	var total_slots: int  = WeaponDB.effective_slots(wdata, wlvl)
	var max_slots: int    = WeaponDB.effective_slots(wdata, WeaponDB.max_level(wdata))
	var extra_ids: Array  = GameManager.get_weapon_extra_movesets(weapon_id)
	var constants: Array  = wdata.get("constant_movesets", [])
	var base_slots: int   = wdata.get("moveset_slots", 0)

	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 14)

	# Weapon art
	var display := WeaponDisplay.new()
	display.custom_minimum_size = Vector2(140, 165)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(display)
	display.set_weapon(weapon_id)

	# Info column
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = wdata.get("name", weapon_id)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	info.add_child(name_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Lv. %d   %s" % [wlvl, ("%.0f / %.0f XP" % [wxp, thres]) if thres > 0 else "MAX"]
	lvl_lbl.add_theme_font_size_override("font_size", 11)
	lvl_lbl.add_theme_color_override("font_color", Color(0.65, 0.58, 0.30))
	info.add_child(lvl_lbl)

	if thres > 0:
		var xp_bar := ProgressBar.new()
		xp_bar.max_value = thres
		xp_bar.value = wxp
		xp_bar.show_percentage = false
		xp_bar.custom_minimum_size = Vector2(0, 8)
		var fill_sb := StyleBoxFlat.new()
		fill_sb.bg_color = Color(0.55, 0.42, 0.12)
		fill_sb.set_corner_radius_all(4)
		var bg_sb := StyleBoxFlat.new()
		bg_sb.bg_color = Color(0.12, 0.10, 0.08)
		bg_sb.set_corner_radius_all(4)
		xp_bar.add_theme_stylebox_override("fill", fill_sb)
		xp_bar.add_theme_stylebox_override("background", bg_sb)
		info.add_child(xp_bar)

	info.add_child(HSeparator.new())

	# Constant moveset pills
	if not constants.is_empty():
		var chdr := Label.new()
		chdr.text = "CONSTANT"
		chdr.add_theme_font_size_override("font_size", 10)
		chdr.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
		info.add_child(chdr)
		for mid in constants:
			var mname: String = MovesetDB.MOVES.get(mid, {}).get("name", mid)
			info.add_child(_equip_pill(mname, "constant"))

	# Extra slot pills
	var shdr := Label.new()
	shdr.text = "SLOTS"
	shdr.add_theme_font_size_override("font_size", 10)
	shdr.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
	info.add_child(shdr)

	for slot_idx in range(max_slots):
		if slot_idx >= total_slots:
			var needed_lvl: int = slot_idx - base_slots + 2
			info.add_child(_equip_pill("Lv. %d" % needed_lvl, "locked"))
		elif slot_idx < extra_ids.size():
			var mid: String = extra_ids[slot_idx]
			var mname: String = MovesetDB.MOVES.get(mid, {}).get("name", mid)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.add_child(_equip_pill(mname, "filled"))
			var rm := Button.new()
			rm.text = "✕"
			rm.custom_minimum_size = Vector2(24, 24)
			rm.add_theme_font_size_override("font_size", 10)
			var cw := weapon_id; var ci := slot_idx
			rm.pressed.connect(func(): _remove_slot(cw, ci))
			row.add_child(rm)
			info.add_child(row)
		else:
			var empty_pill := _equip_pill("+ assign", "empty")
			var cw := weapon_id; var ci := slot_idx
			empty_pill.pressed.connect(func(): _on_slot_empty_pressed(cw, ci))
			info.add_child(empty_pill)

	return card

func _equip_pill(label: String, state: String) -> Button:
	var pill := Button.new()
	pill.text = label
	pill.custom_minimum_size = Vector2(0, 26)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_theme_font_size_override("font_size", 11)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(13)
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 4;  sb.content_margin_bottom = 4
	match state:
		"constant":
			sb.bg_color = Color(0.22, 0.18, 0.08); sb.set_border_width_all(1)
			sb.border_color = Color(0.68, 0.56, 0.22); pill.disabled = true
		"filled":
			sb.bg_color = Color(0.14, 0.22, 0.14); sb.set_border_width_all(1)
			sb.border_color = Color(0.35, 0.62, 0.35); pill.disabled = true
		"empty":
			sb.bg_color = Color(0.10, 0.10, 0.16); sb.set_border_width_all(1)
			sb.border_color = Color(0.55, 0.48, 0.20)
		"locked":
			sb.bg_color = Color(0.08, 0.08, 0.10); sb.set_border_width_all(1)
			sb.border_color = Color(0.30, 0.30, 0.32); pill.disabled = true
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		pill.add_theme_stylebox_override(s, sb)
	return pill

func _on_slot_empty_pressed(weapon_id: String, slot_idx: int) -> void:
	_equip_active_wid  = weapon_id
	_equip_picker_slot = slot_idx
	_refresh_picker()
	_equip_picker_box.visible = true

func _refresh_picker() -> void:
	for c in _equip_picker_box.get_children(): c.queue_free()

	var wdata: Dictionary  = WeaponDB.WEAPONS.get(_equip_active_wid, {})
	var constants: Array   = wdata.get("constant_movesets", [])
	var slotted: Array     = GameManager.get_weapon_extra_movesets(_equip_active_wid)

	var hdr := Label.new()
	hdr.text = "Pick for slot %d:" % (_equip_picker_slot + 1)
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", Color(0.80, 0.68, 0.28))
	_equip_picker_box.add_child(hdr)

	var any := false
	for mid in GameManager.owned_movesets:
		var moveset: Dictionary = MovesetDB.MOVES.get(mid, {})
		if moveset.is_empty() or constants.has(mid) or slotted.has(mid):
			continue
		if moveset.get("types", []).has("defense"):
			continue
		any = true
		var btn := Button.new()
		btn.text = moveset.get("name", mid)
		btn.add_theme_font_size_override("font_size", 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cm := mid
		btn.pressed.connect(func(): _assign_moveset(cm))
		_equip_picker_box.add_child(btn)

	if not any:
		var empty_lbl := Label.new()
		empty_lbl.text = "No available movesets."
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.40))
		_equip_picker_box.add_child(empty_lbl)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.add_theme_font_size_override("font_size", 11)
	cancel.pressed.connect(func(): _equip_picker_box.visible = false; _equip_picker_slot = -1)
	_equip_picker_box.add_child(cancel)

func _assign_moveset(moveset_id: String) -> void:
	var slots: Array = GameManager.get_weapon_extra_movesets(_equip_active_wid).duplicate()
	while slots.size() <= _equip_picker_slot:
		slots.append("")
	slots[_equip_picker_slot] = moveset_id
	slots = slots.filter(func(s): return s != "")
	GameManager.set_weapon_extra_movesets(_equip_active_wid, slots)
	SaveManager.save_game()
	_show_equip_overlay()

func _remove_slot(weapon_id: String, slot_idx: int) -> void:
	var slots: Array = GameManager.get_weapon_extra_movesets(weapon_id).duplicate()
	if slot_idx < slots.size():
		slots.remove_at(slot_idx)
	GameManager.set_weapon_extra_movesets(weapon_id, slots)
	SaveManager.save_game()
	_show_equip_overlay()

func _refresh_moveset_list() -> void:
	var hdr := Label.new()
	hdr.text = "MOVESETS"
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	_equip_right_col.add_child(hdr)
	_equip_right_col.add_child(HSeparator.new())

	var all_equipped_ids: Array = []

	for weapon_id in GameManager.equipped_run_weapons:
		var wdata: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
		var extra_ids: Array  = GameManager.get_weapon_extra_movesets(weapon_id)
		var const_ids: Array  = wdata.get("constant_movesets", [])
		all_equipped_ids.append_array(const_ids)
		all_equipped_ids.append_array(extra_ids)

		var whdr := Label.new()
		whdr.text = wdata.get("name", weapon_id).to_upper()
		whdr.add_theme_font_size_override("font_size", 11)
		whdr.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
		_equip_right_col.add_child(whdr)

		for moveset in WeaponDB.get_moveset(wdata, extra_ids):
			_equip_moveset_entry(moveset, true)

		_equip_right_col.add_child(HSeparator.new())

	# Free (owned but not equipped anywhere)
	var free_list: Array = []
	for mid in GameManager.owned_movesets:
		if all_equipped_ids.has(mid):
			continue
		var moveset: Dictionary = MovesetDB.MOVES.get(mid, {})
		if not moveset.is_empty() and not moveset.get("types", []).has("defense"):
			free_list.append(moveset)

	if not free_list.is_empty():
		var fhdr := Label.new()
		fhdr.text = "FREE MOVESETS"
		fhdr.add_theme_font_size_override("font_size", 11)
		fhdr.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
		_equip_right_col.add_child(fhdr)
		for moveset in free_list:
			_equip_moveset_entry(moveset, false)

func _equip_moveset_entry(moveset: Dictionary, equipped: bool) -> void:
	var steps: Array    = moveset.get("steps", [])
	var name_col: Color = Color(0.80, 0.68, 0.28) if equipped else Color(0.58, 0.56, 0.52)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_equip_right_col.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = moveset.get("name", "").to_upper()
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", name_col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var sta_lbl := Label.new()
	sta_lbl.text = "%d STA" % moveset.get("stamina_cost", 0)
	sta_lbl.add_theme_font_size_override("font_size", 11)
	sta_lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	row.add_child(sta_lbl)

	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		var prefix: String   = "[%d/%d] " % [i + 1, steps.size()] if steps.size() > 1 else ""
		var slbl := Label.new()
		slbl.text = "  %s%s  ·  %s  ·  %d dmg" % [
			prefix, step.get("name", ""),
			_fmt_time(step.get("time", 0)), step.get("base_damage", 0)]
		slbl.add_theme_font_size_override("font_size", 11)
		slbl.add_theme_color_override("font_color", Color(0.48, 0.46, 0.52))
		slbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_equip_right_col.add_child(slbl)

# ── Interaction ────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if GameManager.run_active:
		var remaining := GameManager.run_remaining_seconds()
		_timer_lbl.text = _fmt_remaining(remaining)
		_timer_lbl.add_theme_color_override("font_color", _remaining_color(remaining))
		if remaining <= 0.0:
			_handle_run_expired()

func _on_node_pressed(idx: int) -> void:
	_show_location_popup(idx)

# ── Hover tooltip ──────────────────────────────────────────────────────────────

func _build_hover_tooltip() -> void:
	_hover_panel = PanelContainer.new()
	_hover_panel.visible = false
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_panel)

	var m := _margin(_hover_panel, 8)
	_hover_lbl = Label.new()
	_hover_lbl.add_theme_font_size_override("font_size", 12)
	_hover_lbl.add_theme_color_override("font_color", Color(0.80, 0.75, 0.55))
	m.add_child(_hover_lbl)

func _show_hover(idx: int) -> void:
	var loc: Dictionary = GameManager.run_location_sequence[idx]
	var cur    := GameManager.run_current_index
	var beaten := idx < cur
	var status := "▶ Current" if not beaten else "✓ Defeated"
	_hover_lbl.text = "%s\n%s" % [loc.get("name", ""), status]
	var node_pos := _positions[idx]
	_hover_panel.position = Vector2(
		clampf(node_pos.x + 16, 4, 1200 - 220),
		clampf(node_pos.y - 56, 4, 800  -  60))
	_hover_panel.visible = true

func _hide_hover() -> void:
	_hover_panel.visible = false

# ── Location popup ─────────────────────────────────────────────────────────────

func _build_location_popup() -> void:
	_location_popup = CanvasLayer.new()
	_location_popup.layer = 5
	_location_popup.hide()
	add_child(_location_popup)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.80)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_location_popup.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var outer := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	outer.add_child(vbox)

	_popup_name = Label.new()
	_popup_name.add_theme_font_size_override("font_size", 22)
	_popup_name.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	_popup_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_popup_name)

	vbox.add_child(HSeparator.new())

	_popup_enemy = Label.new()
	_popup_enemy.add_theme_font_size_override("font_size", 15)
	_popup_enemy.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	_popup_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_popup_enemy)

	_popup_mult = Label.new()
	_popup_mult.add_theme_font_size_override("font_size", 12)
	_popup_mult.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	_popup_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_popup_mult)

	_popup_desc = Label.new()
	_popup_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_popup_desc.add_theme_font_size_override("font_size", 12)
	_popup_desc.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
	_popup_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_popup_desc)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_popup_enter = Button.new()
	_popup_enter.text = "Enter Location"
	_popup_enter.custom_minimum_size = Vector2(160, 44)
	_popup_enter.pressed.connect(_on_enter)
	btn_row.add_child(_popup_enter)

	var close_btn := Button.new()
	close_btn.text = "Back to Map"
	close_btn.custom_minimum_size = Vector2(140, 44)
	close_btn.pressed.connect(func(): _location_popup.hide())
	btn_row.add_child(close_btn)

func _show_location_popup(idx: int) -> void:
	var loc: Dictionary   = GameManager.run_location_sequence[idx]
	var enemy: Dictionary = EnemyDB.ENEMIES.get(loc.get("enemy_id", ""), {})
	var cur    := GameManager.run_current_index
	var beaten := idx < cur

	_popup_name.text  = loc.get("name", "")
	_popup_enemy.text = enemy.get("name", "")
	var mult: float   = loc.get("mult", 1.0)
	var hp: int       = int(enemy.get("max_hp", 0) * mult)
	_popup_mult.text  = "Defeated" if beaten \
						else "HP: %d   (×%.2f difficulty)" % [hp, mult]
	_popup_desc.text  = enemy.get("description", "")
	_popup_enter.visible = (idx == cur)
	_location_popup.show()

func _on_enter() -> void:
	var loc := GameManager.current_location_data()
	if loc.is_empty():
		return
	GameManager.pending_encounter = {
		"enemy_id":        loc.get("enemy_id", "procrastination_mob"),
		"difficulty_mult": loc.get("mult", 1.0),
	}
	get_tree().change_scene_to_file("res://scenes/combat/combat.tscn")

# ── Helpers ────────────────────────────────────────────────────────────────────

func _fmt_remaining(secs: float) -> String:
	var s := int(secs)
	var h := s / 3600
	var m := (s % 3600) / 60
	var ss := s % 60
	if h > 0:
		return "%d:%02d:%02d left" % [h, m, ss]
	return "%02d:%02d left" % [m, ss]

func _remaining_color(secs: float) -> Color:
	if secs < 3600.0:
		return Color(0.90, 0.25, 0.20)   # red — under 1 hour
	if secs < 14400.0:
		return Color(0.90, 0.55, 0.15)   # orange — under 4 hours
	return Color(0.55, 0.52, 0.44)       # default muted

func _handle_run_expired() -> void:
	GameManager.end_run_failure()
	SaveManager.save_game()
	_timer_lbl.text = "RUN EXPIRED"
	_timer_lbl.add_theme_color_override("font_color", Color(0.90, 0.25, 0.20))
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")

func _fmt_time(secs: int) -> String:
	if secs <= 0:   return "0 s"
	if secs < 60:   return "%d s" % secs
	return "%d:%02d" % [secs / 60, secs % 60]

func _margin(parent: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	parent.add_child(m)
	return m
