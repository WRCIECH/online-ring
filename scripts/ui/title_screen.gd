extends Control

var SAVE_PATH:   String = "user://save_data_dev.json"        if OS.has_feature("editor") else "user://save_data.json"
var BACKUP_PATH: String = "user://save_data_backup_dev.json" if OS.has_feature("editor") else "user://save_data_backup.json"

var _confirm_row: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.custom_minimum_size = Vector2(560, 0)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "ONLINE RING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "A Content Creator's RPG"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.48, 0.48))
	vbox.add_child(subtitle)

	_gap(vbox, 44)

	# Premise
	var premise := Label.new()
	premise.text = "Fight the manifestations of procrastination, perfectionism, and burnout.\n\nEvery attack requires a real creative act."
	premise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	premise.autowrap_mode = TextServer.AUTOWRAP_WORD
	premise.add_theme_font_size_override("font_size", 14)
	premise.add_theme_color_override("font_color", Color(0.68, 0.65, 0.58))
	vbox.add_child(premise)

	_gap(vbox, 52)

	# Buttons
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 12)
	btn_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(btn_col)

	var has_save := FileAccess.file_exists(SAVE_PATH)

	if has_save:
		var cont := _make_btn("Continue", _on_continue)
		btn_col.add_child(cont)

	var new_game := _make_btn("New Game" if has_save else "Begin", _on_new_game)
	btn_col.add_child(new_game)

	# Confirm erase row — hidden until New Game is clicked with an existing save
	_confirm_row = VBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 8)
	_confirm_row.visible = false
	btn_col.add_child(_confirm_row)

	var warn := Label.new()
	warn.text = "Erase all progress and start fresh?"
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 13)
	warn.add_theme_color_override("font_color", Color(0.85, 0.35, 0.25))
	_confirm_row.add_child(warn)

	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 12)
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_row.add_child(confirm_row)

	var yes := _make_btn("Yes, erase", _on_erase_confirmed)
	yes.custom_minimum_size = Vector2(120, 40)
	confirm_row.add_child(yes)

	var no := _make_btn("Cancel", func(): _confirm_row.visible = false)
	no.custom_minimum_size = Vector2(120, 40)
	confirm_row.add_child(no)

	# Version label — bottom left
	var ver := Label.new()
	ver.text = "v0.1 — Early Build"
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_top    = -30
	ver.offset_right  = 200
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(0.30, 0.30, 0.30))
	add_child(ver)  # direct child so anchoring works independently

func _make_btn(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(260, 50)
	b.pressed.connect(callback)
	return b

func _gap(parent: VBoxContainer, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = height
	parent.add_child(s)

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_continue() -> void:
	SaveManager.load_game()
	var dest := "res://scenes/map/run_map.tscn" if GameManager.run_active \
				else "res://scenes/ui/weapon_select.tscn"
	get_tree().change_scene_to_file(dest)

func _on_new_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_confirm_row.visible = true
	else:
		_go_fresh()

func _on_erase_confirmed() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove(SAVE_PATH.get_file())
		dir.remove(BACKUP_PATH.get_file())
	_go_fresh()

func _go_fresh() -> void:
	GameManager.reset()
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")

# ── Keyboard ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _confirm_row.visible:
		_confirm_row.visible = false
		get_viewport().set_input_as_handled()
