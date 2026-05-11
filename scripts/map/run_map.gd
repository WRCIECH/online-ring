extends Control

const ENEMY_NAMES := {
	"procrastination_mob": "Procrastination Mob",
	"hater":               "The Hater",
	"blank_page_omen":     "Blank Page Omen",
	"perfectionism_knight":"Perfectionism Knight",
}

var _timer_lbl:   Label
var _location_list: VBoxContainer
var _enter_btn:   Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Top bar: run timer ─────────────────────────────────────────────────────
	var top_bar := PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 48
	add_child(top_bar)

	var top_m := _margin(top_bar, 8)
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

	# ── Centre: location list ──────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top    = 56
	scroll.offset_bottom = -80
	scroll.offset_left   = 300
	scroll.offset_right  = -300
	add_child(scroll)

	_location_list = VBoxContainer.new()
	_location_list.add_theme_constant_override("separation", 12)
	_location_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_location_list)

	# ── Bottom bar: enter button ───────────────────────────────────────────────
	var bot := PanelContainer.new()
	bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -70
	add_child(bot)

	var bot_m := _margin(bot, 10)
	var bot_row := HBoxContainer.new()
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_m.add_child(bot_row)

	_enter_btn = Button.new()
	_enter_btn.text = "Enter Location"
	_enter_btn.custom_minimum_size = Vector2(220, 44)
	_enter_btn.pressed.connect(_on_enter)
	bot_row.add_child(_enter_btn)

func _process(_delta: float) -> void:
	if GameManager.run_active:
		var secs := int(GameManager.run_elapsed_seconds())
		var h := secs / 3600
		var m := (secs % 3600) / 60
		var s := secs % 60
		_timer_lbl.text = "Elapsed  %02d:%02d:%02d" % [h, m, s]

func _refresh() -> void:
	for child in _location_list.get_children():
		child.queue_free()

	var seq: Array = GameManager.run_location_sequence
	var cur: int   = GameManager.run_current_index

	for i in range(seq.size()):
		var enemy_id: String = seq[i]
		var beaten: bool     = i < cur
		var active: bool     = i == cur
		var is_boss: bool    = i == seq.size() - 1

		var row := PanelContainer.new()
		var sbox := StyleBoxFlat.new()
		if active:
			sbox.bg_color = Color(0.14, 0.12, 0.20)
			sbox.set_border_width_all(2)
			sbox.border_color = Color(0.65, 0.52, 0.20)
		elif beaten:
			sbox.bg_color = Color(0.07, 0.07, 0.09)
			sbox.set_border_width_all(1)
			sbox.border_color = Color(0.18, 0.18, 0.22)
		else:
			sbox.bg_color = Color(0.09, 0.08, 0.12)
			sbox.set_border_width_all(1)
			sbox.border_color = Color(0.22, 0.20, 0.28)
		sbox.set_corner_radius_all(4)
		row.add_theme_stylebox_override("panel", sbox)

		var row_m := _margin(row, 10)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row_m.add_child(hbox)

		# Status dot
		var dot := Label.new()
		dot.add_theme_font_size_override("font_size", 18)
		if beaten:
			dot.text = "✓"
			dot.add_theme_color_override("font_color", Color(0.35, 0.62, 0.35))
		elif active:
			dot.text = "▶"
			dot.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
		else:
			dot.text = "○"
			dot.add_theme_color_override("font_color", Color(0.40, 0.38, 0.45))
		hbox.add_child(dot)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = ("⚔  BOSS  —  " if is_boss else "") + ENEMY_NAMES.get(enemy_id, enemy_id)
		name_lbl.add_theme_font_size_override("font_size", 15)
		if beaten:
			name_lbl.add_theme_color_override("font_color", Color(0.38, 0.36, 0.42))
		elif is_boss:
			name_lbl.add_theme_color_override("font_color", Color(0.90, 0.40, 0.25))
		info.add_child(name_lbl)

		if not beaten:
			var enemy: Dictionary = EnemyDB.ENEMIES.get(enemy_id, {})
			var desc := Label.new()
			desc.text = enemy.get("description", "")
			desc.add_theme_font_size_override("font_size", 11)
			desc.add_theme_color_override("font_color", Color(0.50, 0.48, 0.55))
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD
			info.add_child(desc)

		_location_list.add_child(row)

	_enter_btn.disabled = GameManager.run_current_index >= GameManager.run_location_sequence.size()

func _on_enter() -> void:
	var enemy_id := GameManager.current_enemy_id()
	if enemy_id.is_empty():
		return
	GameManager.pending_encounter = {"enemy_id": enemy_id}
	get_tree().change_scene_to_file("res://scenes/combat/combat.tscn")

func _margin(parent: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	parent.add_child(m)
	return m
