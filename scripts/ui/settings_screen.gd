class_name SettingsScreen
extends CanvasLayer

var _always_on_top_check: CheckBox
var _fullscreen_check:    CheckBox
var _volume_slider:       HSlider
var _volume_pct:          Label
var _reset_confirm_row:   Control

func _ready() -> void:
	layer = 10
	_build_ui()
	hide()

func show_screen() -> void:
	_sync_controls()
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
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	m.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# ── Display ───────────────────────────────────────────────────────────────
	_section_header(vbox, "DISPLAY")

	_always_on_top_check = CheckBox.new()
	_always_on_top_check.text = "Always on Top"
	_always_on_top_check.toggled.connect(func(v: bool): SettingsManager.set_always_on_top(v))
	vbox.add_child(_always_on_top_check)

	var aot_hint := Label.new()
	aot_hint.text = "Keep game window above other apps — useful when writing alongside the game."
	aot_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	aot_hint.add_theme_font_size_override("font_size", 11)
	aot_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(aot_hint)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.toggled.connect(func(v: bool): SettingsManager.set_fullscreen(v))
	vbox.add_child(_fullscreen_check)

	vbox.add_child(HSeparator.new())

	# ── Audio ─────────────────────────────────────────────────────────────────
	_section_header(vbox, "AUDIO")

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 14)
	vbox.add_child(vol_row)

	var vol_lbl := Label.new()
	vol_lbl.text = "Master Volume"
	vol_lbl.custom_minimum_size = Vector2(130, 0)
	vol_row.add_child(vol_lbl)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step      = 0.05
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(_volume_slider)

	_volume_pct = Label.new()
	_volume_pct.custom_minimum_size = Vector2(46, 0)
	_volume_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vol_row.add_child(_volume_pct)

	vbox.add_child(HSeparator.new())

	# ── Reset ─────────────────────────────────────────────────────────────────
	_section_header(vbox, "DANGER ZONE")

	var reset_btn := Button.new()
	reset_btn.text = "Reset All Progress"
	reset_btn.add_theme_color_override("font_color", Color(0.85, 0.35, 0.25))
	reset_btn.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_btn)

	_reset_confirm_row = VBoxContainer.new()
	_reset_confirm_row.add_theme_constant_override("separation", 6)
	_reset_confirm_row.visible = false
	vbox.add_child(_reset_confirm_row)

	var warn := Label.new()
	warn.text = "Erase all progress and return to the title screen?"
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD
	warn.add_theme_font_size_override("font_size", 12)
	warn.add_theme_color_override("font_color", Color(0.85, 0.35, 0.25))
	_reset_confirm_row.add_child(warn)

	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 10)
	_reset_confirm_row.add_child(confirm_row)

	var yes_btn := Button.new()
	yes_btn.text = "Yes, erase"
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_btn.pressed.connect(_on_reset_confirmed)
	confirm_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_btn.pressed.connect(func(): _reset_confirm_row.visible = false)
	confirm_row.add_child(no_btn)

	vbox.add_child(HSeparator.new())

	# Close
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(hide)
	vbox.add_child(close_btn)

func _section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	parent.add_child(lbl)

# ── Sync ──────────────────────────────────────────────────────────────────────

func _sync_controls() -> void:
	_always_on_top_check.set_pressed_no_signal(SettingsManager.always_on_top)
	_fullscreen_check.set_pressed_no_signal(SettingsManager.fullscreen)
	_volume_slider.set_value_no_signal(SettingsManager.master_volume)
	_volume_pct.text = "%d%%" % int(SettingsManager.master_volume * 100)

func _on_volume_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)
	_volume_pct.text = "%d%%" % int(value * 100)

# ── Keyboard ──────────────────────────────────────────────────────────────────

func _on_reset_pressed() -> void:
	_reset_confirm_row.visible = true

func _on_reset_confirmed() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove("save_data.json")
		dir.remove("save_data_backup.json")
	GameManager.reset()
	hide()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_reset_confirm_row.visible = false  # also dismiss confirm row if open
		hide()
		get_viewport().set_input_as_handled()
