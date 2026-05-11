extends Control

# Shown after the player defeats the final boss.
# Grants one stat point (VIG / END / MIND) and displays any moveset reward.

var _stat_chosen:    String = ""
var _confirm_btn:    Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _get_moveset_reward() -> String:
	return GameManager.pending_run_reward

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var m := _margin(panel, 28)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	m.add_child(vbox)

	# Header
	var title := Label.new()
	title.text = "RUN COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	vbox.add_child(title)

	# Elapsed time
	var secs := int(GameManager.run_elapsed_seconds())
	var h := secs / 3600
	var mi := (secs % 3600) / 60
	var s  := secs % 60
	var time_lbl := Label.new()
	time_lbl.text = "Time: %02d:%02d:%02d" % [h, mi, s]
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_size_override("font_size", 13)
	time_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	vbox.add_child(time_lbl)

	vbox.add_child(HSeparator.new())

	# Moveset reward
	var reward_id := _get_moveset_reward()
	if not reward_id.is_empty():
		var reward_hdr := Label.new()
		reward_hdr.text = "REWARD"
		reward_hdr.add_theme_font_size_override("font_size", 13)
		reward_hdr.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
		vbox.add_child(reward_hdr)

		var ms := MovesetDB.MOVES.get(reward_id, {})
		var reward_lbl := Label.new()
		reward_lbl.text = "New moveset unlocked: %s" % ms.get("name", reward_id)
		reward_lbl.add_theme_font_size_override("font_size", 15)
		reward_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55))
		vbox.add_child(reward_lbl)

		if not GameManager.owned_movesets.has(reward_id):
			GameManager.owned_movesets.append(reward_id)

		vbox.add_child(HSeparator.new())

	# Stat level-up (one point)
	var up_hdr := Label.new()
	up_hdr.text = "LEVEL UP — choose one stat"
	up_hdr.add_theme_font_size_override("font_size", 13)
	up_hdr.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	vbox.add_child(up_hdr)

	var stat_row := HBoxContainer.new()
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 16)
	vbox.add_child(stat_row)

	for entry: Array in [
		["VIG", "Vitality — increases HP"],
		["END", "Endurance — increases Stamina"],
		["MIND", "Mind — increases FP"],
	]:
		var stat: String = entry[0]
		var desc: String = entry[1]
		var btn := Button.new()
		btn.text = "%s\n%d → %d\n%s" % [stat, GameManager.stats[stat], GameManager.stats[stat] + 1, desc]
		btn.custom_minimum_size = Vector2(150, 70)
		btn.toggle_mode = true
		btn.pressed.connect(func():
			_stat_chosen = stat
			# Deselect siblings
			for child in stat_row.get_children():
				if child != btn and child is Button:
					child.button_pressed = false
			_confirm_btn.disabled = false
		)
		stat_row.add_child(btn)

	vbox.add_child(HSeparator.new())

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm & Start New Run"
	_confirm_btn.custom_minimum_size = Vector2(280, 48)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	var btn_center := CenterContainer.new()
	btn_center.add_child(_confirm_btn)
	vbox.add_child(btn_center)

func _on_confirm() -> void:
	if not _stat_chosen.is_empty():
		GameManager.level_up_stat(_stat_chosen)
	GameManager.pending_run_reward = ""
	GameManager.end_run_victory()
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")

func _margin(parent: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	parent.add_child(m)
	return m
