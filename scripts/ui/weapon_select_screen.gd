extends Control

var _selected_weapons: Array[String] = []
var _weapon_cards: Dictionary = {}   # weapon_id → PanelContainer
var _begin_btn: Button
var _info_lbl: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "SELECT WEAPONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = 40
	title.offset_bottom = 80
	add_child(title)

	var sub := Label.new()
	sub.text = "Choose up to 2 weapons for this run"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top    = 82
	sub.offset_bottom = 110
	add_child(sub)

	# Weapon card grid
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 20)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.offset_top    = 120
	grid.offset_bottom = -120
	grid.offset_left   = 80
	grid.offset_right  = -80
	add_child(grid)

	for weapon_id in GameManager.owned_weapons:
		var card := _build_weapon_card(weapon_id)
		_weapon_cards[weapon_id] = card
		grid.add_child(card)

	# Bottom bar
	_info_lbl = Label.new()
	_info_lbl.text = ""
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lbl.add_theme_font_size_override("font_size", 12)
	_info_lbl.add_theme_color_override("font_color", Color(0.75, 0.35, 0.25))
	_info_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_info_lbl.offset_top    = -110
	_info_lbl.offset_bottom = -78
	add_child(_info_lbl)

	_begin_btn = Button.new()
	_begin_btn.text = "Begin Run"
	_begin_btn.custom_minimum_size = Vector2(220, 48)
	_begin_btn.disabled = true
	_begin_btn.pressed.connect(_on_begin)
	_begin_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_begin_btn.offset_top    = -68
	_begin_btn.offset_bottom = -20
	_begin_btn.offset_left   = 490
	_begin_btn.offset_right  = -490
	add_child(_begin_btn)

func _build_weapon_card(weapon_id: String) -> PanelContainer:
	var wdata: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
	var wlevel: int  = GameManager.get_weapon_level(weapon_id)
	var wxp:    float = GameManager.get_weapon_xp(weapon_id)
	var thres:  float = WeaponDB.xp_for_next_level(wdata, wlevel)

	# PanelContainer sizes ALL children to fill itself, so the transparent
	# Button overlay (added last) sits on top and catches every click.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_card(card, false)

	# Content layer
	var m := _margin(card, 14)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	m.add_child(vbox)

	# Weapon picture — set_weapon() must come after add_child so _ready() has run
	var visual := WeaponDisplay.new()
	visual.custom_minimum_size = Vector2(0, 130)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(visual)
	visual.set_weapon(weapon_id)

	vbox.add_child(HSeparator.new())

	# Name
	var name_lbl := Label.new()
	name_lbl.text = wdata.get("name", weapon_id)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Level
	var lvl_lbl := Label.new()
	lvl_lbl.text = "Level %d" % wlevel
	lvl_lbl.add_theme_font_size_override("font_size", 12)
	lvl_lbl.add_theme_color_override("font_color", Color(0.65, 0.58, 0.30))
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lvl_lbl)

	# XP bar
	if thres > 0.0:
		var xp_bar := ProgressBar.new()
		xp_bar.max_value       = thres
		xp_bar.value           = wxp
		xp_bar.show_percentage = false
		xp_bar.custom_minimum_size = Vector2(0, 8)
		xp_bar.mouse_filter    = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.55, 0.42, 0.12)
		fill.set_corner_radius_all(4)
		var bg_sbox := StyleBoxFlat.new()
		bg_sbox.bg_color = Color(0.12, 0.10, 0.08)
		bg_sbox.set_corner_radius_all(4)
		bg_sbox.set_border_width_all(1)
		bg_sbox.border_color = Color(0.30, 0.24, 0.10)
		xp_bar.add_theme_stylebox_override("fill",       fill)
		xp_bar.add_theme_stylebox_override("background", bg_sbox)
		vbox.add_child(xp_bar)

		var xp_lbl := Label.new()
		xp_lbl.text = "%.0f / %.0f XP" % [wxp, thres]
		xp_lbl.add_theme_font_size_override("font_size", 10)
		xp_lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.35))
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(xp_lbl)
	else:
		var max_lbl := Label.new()
		max_lbl.text = "MAX LEVEL"
		max_lbl.add_theme_font_size_override("font_size", 10)
		max_lbl.add_theme_color_override("font_color", Color(0.70, 0.60, 0.20))
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(max_lbl)

	vbox.add_child(HSeparator.new())

	# Movesets preview
	var moves_hdr := Label.new()
	moves_hdr.text = "Movesets"
	moves_hdr.add_theme_font_size_override("font_size", 11)
	moves_hdr.add_theme_color_override("font_color", Color(0.50, 0.48, 0.55))
	moves_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(moves_hdr)

	var extra_ids := GameManager.get_weapon_extra_movesets(weapon_id)
	for moveset in WeaponDB.get_moveset(wdata, extra_ids):
		var ml := Label.new()
		ml.text = "• " + moveset.get("name", "")
		ml.add_theme_font_size_override("font_size", 11)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(ml)

	# Desc
	var desc := Label.new()
	desc.text = wdata.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.50, 0.48, 0.55))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	# Transparent Button overlay — catches clicks anywhere on the card,
	# regardless of which child the cursor is over.
	var overlay := Button.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.flat = true
	overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		overlay.add_theme_stylebox_override(s, empty)
	overlay.pressed.connect(func(): _toggle_weapon(weapon_id))
	card.add_child(overlay)

	return card

func _toggle_weapon(weapon_id: String) -> void:
	if _selected_weapons.has(weapon_id):
		_selected_weapons.erase(weapon_id)
	elif _selected_weapons.size() < 2:
		_selected_weapons.append(weapon_id)
	else:
		_info_lbl.text = "You can only bring 2 weapons per run."
		return
	_info_lbl.text = ""
	_refresh_card_styles()
	_begin_btn.disabled = _selected_weapons.is_empty()

func _refresh_card_styles() -> void:
	for wid in _weapon_cards:
		_style_card(_weapon_cards[wid], _selected_weapons.has(wid))

func _style_card(card: PanelContainer, selected: bool) -> void:
	var sbox := StyleBoxFlat.new()
	sbox.set_corner_radius_all(6)
	if selected:
		sbox.bg_color     = Color(0.12, 0.10, 0.18)
		sbox.set_border_width_all(2)
		sbox.border_color = Color(0.68, 0.56, 0.22)
	else:
		sbox.bg_color     = Color(0.09, 0.08, 0.12)
		sbox.set_border_width_all(1)
		sbox.border_color = Color(0.22, 0.20, 0.28)
	card.add_theme_stylebox_override("panel", sbox)

func _on_begin() -> void:
	GameManager.start_run(_selected_weapons)
	get_tree().change_scene_to_file("res://scenes/map/run_map.tscn")

func _margin(parent: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	parent.add_child(m)
	return m
