class_name EquipScreen
extends CanvasLayer

var _selected_id: String = ""

var _list_box:      VBoxContainer
var _detail_name:   Label
var _detail_desc:   Label
var _detail_req:    Label
var _detail_scale:  Label
var _detail_moves:  VBoxContainer
var _equip_btn:     Button

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 11
	_build_ui()
	hide()

func show_screen() -> void:
	_selected_id = ""
	_refresh_list()
	_clear_detail()
	show()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 560)
	center.add_child(panel)

	var outer_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer_margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(outer_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	outer_margin.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "EQUIPMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	root_vbox.add_child(HSeparator.new())

	# Two-column body
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(columns)

	_build_list_column(columns)
	_build_detail_column(columns)

	root_vbox.add_child(HSeparator.new())

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(hide)
	root_vbox.add_child(close_btn)

func _build_list_column(parent: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(280, 0)
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)

	var hdr := Label.new()
	hdr.text = "OWNED WEAPONS"
	hdr.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	hdr.add_theme_font_size_override("font_size", 12)
	col.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

func _build_detail_column(parent: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 18)
	col.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_desc.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	col.add_child(_detail_desc)

	col.add_child(HSeparator.new())

	_detail_req = Label.new()
	_detail_req.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_req.add_theme_font_size_override("font_size", 12)
	col.add_child(_detail_req)

	_detail_scale = Label.new()
	_detail_scale.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_detail_scale.add_theme_font_size_override("font_size", 12)
	col.add_child(_detail_scale)

	col.add_child(HSeparator.new())

	var moves_hdr := Label.new()
	moves_hdr.text = "MOVESET"
	moves_hdr.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	moves_hdr.add_theme_font_size_override("font_size", 12)
	col.add_child(moves_hdr)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	_detail_moves = VBoxContainer.new()
	_detail_moves.add_theme_constant_override("separation", 4)
	_detail_moves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_moves)

	_equip_btn = Button.new()
	_equip_btn.text = "Equip"
	_equip_btn.pressed.connect(_on_equip_pressed)
	col.add_child(_equip_btn)

# ── List ──────────────────────────────────────────────────────────────────────

func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()

	for weapon_id in GameManager.weapons:
		var weapon: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
		if weapon.is_empty():
			continue

		var is_equipped: bool = GameManager.equipped_weapon == weapon_id
		var meets_req: bool   = WeaponDB.meets_requirements(weapon, GameManager.stats)

		var btn := Button.new()
		btn.text = weapon.get("name", weapon_id)
		if is_equipped:
			btn.text += "  [E]"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_weapon_selected.bind(weapon_id))

		if not meets_req and not is_equipped:
			btn.add_theme_color_override("font_color", Color(0.6, 0.35, 0.35))

		_list_box.add_child(btn)

# ── Detail ────────────────────────────────────────────────────────────────────

func _clear_detail() -> void:
	_detail_name.text  = "Select a weapon"
	_detail_desc.text  = ""
	_detail_req.text   = ""
	_detail_scale.text = ""
	for child in _detail_moves.get_children():
		child.queue_free()
	_equip_btn.text     = "Equip"
	_equip_btn.disabled = true

func _on_weapon_selected(weapon_id: String) -> void:
	_selected_id = weapon_id
	var weapon: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
	if weapon.is_empty():
		return

	var meets_req: bool  = WeaponDB.meets_requirements(weapon, GameManager.stats)
	var is_equipped: bool = GameManager.equipped_weapon == weapon_id

	_detail_name.text = weapon.get("name", weapon_id)
	_detail_desc.text = weapon.get("description", "")

	# Requirements
	var req: Dictionary = weapon.get("stat_req", {})
	if req.is_empty():
		_detail_req.text = "No stat requirements"
		_detail_req.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	else:
		var lines: PackedStringArray = []
		for stat in req:
			var needed: int = req[stat]
			var have: int   = GameManager.stats.get(stat, 0)
			lines.append("%s %d  (you have %d)  %s" % [stat, needed, have, "✓" if have >= needed else "✗"])
		_detail_req.text = "\n".join(lines)
		_detail_req.add_theme_color_override("font_color",
			Color(0.35, 0.85, 0.35) if meets_req else Color(0.85, 0.35, 0.35))

	# Scaling
	var scaling: Dictionary = weapon.get("scaling", {})
	var parts: PackedStringArray = []
	for stat in scaling:
		parts.append("%s: %s" % [stat, scaling[stat]])
	_detail_scale.text = "Scaling — " + "  ".join(parts)

	# Moveset
	for child in _detail_moves.get_children():
		child.queue_free()

	for move in weapon.get("moveset", []):
		var dmg: int = WeaponDB.calc_damage(move, weapon, GameManager.stats)
		var sta: int = move.get("stamina_cost", 0)
		var fp: int  = move.get("fp_cost", 0)

		var cost_str: String = "%d STA" % sta
		if fp > 0:
			cost_str += "  %d FP" % fp

		var move_lbl := Label.new()
		move_lbl.text = "%s   %d dmg | %s" % [move.get("name", ""), dmg, cost_str]
		move_lbl.add_theme_font_size_override("font_size", 13)
		_detail_moves.add_child(move_lbl)

		var task_lbl := Label.new()
		task_lbl.text = move.get("real_task", "")
		task_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		task_lbl.add_theme_color_override("font_color", Color(0.82, 0.72, 0.38))
		task_lbl.add_theme_font_size_override("font_size", 11)
		_detail_moves.add_child(task_lbl)

		_detail_moves.add_child(HSeparator.new())

	# Equip button
	if is_equipped:
		_equip_btn.text     = "Currently Equipped"
		_equip_btn.disabled = true
	elif not meets_req:
		_equip_btn.text     = "Requirements Not Met"
		_equip_btn.disabled = true
	else:
		_equip_btn.text     = "Equip"
		_equip_btn.disabled = false

func _on_equip_pressed() -> void:
	if _selected_id.is_empty():
		return
	GameManager.equipped_weapon = _selected_id
	SaveManager.save_game()
	_refresh_list()
	_on_weapon_selected(_selected_id)
