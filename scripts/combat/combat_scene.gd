class_name CombatScene
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const DECISION_TIME    := 30.0
const STAGGER_PAUSE    := 1.5
const STA_ROLL         := 15
const STA_BLOCK        := 20
const STA_PARRY        := 25

enum Phase { INIT, PLAYER_ATTACK, TASK_CONFIRM, ENEMY_ATTACK, ENEMY_STAGGERED, VICTORY, DEFEAT }

# ── Combat state ──────────────────────────────────────────────────────────────
var _phase: Phase = Phase.INIT
var _timer: float  = 0.0
var _new_round: bool = true          # true = restore stamina at next player turn
var _player_first: bool = true

var _enemy: Dictionary      = {}
var _enemy_hp: int          = 0
var _enemy_max_hp: int      = 0
var _enemy_poise: int       = 0
var _enemy_max_poise: int   = 0
var _current_enemy_move: Dictionary = {}

var _player_hp: int         = 0
var _player_stamina: int    = 0
var _player_fp: int         = 0

var _pending_move: Dictionary   = {}
var _pending_weapon: Dictionary = {}

# ── UI refs ───────────────────────────────────────────────────────────────────
var _enemy_name_lbl:  Label
var _enemy_hp_bar:    ProgressBar
var _enemy_poise_bar: ProgressBar
var _enemy_move_lbl:  Label
var _log:             RichTextLabel
var _phase_lbl:       Label
var _timer_bar:       ProgressBar
var _options_box:     HFlowContainer
var _player_hp_bar:   ProgressBar
var _player_sta_bar:  ProgressBar
var _player_fp_bar:   ProgressBar
var _player_hp_lbl:   Label
var _player_sta_lbl:  Label
var _player_fp_lbl:   Label

var _task_layer:       CanvasLayer
var _task_move_lbl:    Label
var _task_desc_lbl:    Label
var _task_check:       CheckBox
var _task_confirm_btn: Button

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_init_combat()

func _process(delta: float) -> void:
	if _phase in [Phase.PLAYER_ATTACK, Phase.ENEMY_ATTACK]:
		_timer = maxf(0.0, _timer - delta)
		_timer_bar.value = _timer
		if _timer == 0.0:
			_on_timer_expired()

# ── Combat initialisation ─────────────────────────────────────────────────────

func _init_combat() -> void:
	var encounter: Dictionary = GameManager.pending_encounter
	var enemy_id: String = encounter.get("enemy_id", "procrastination_mob")
	_enemy         = EnemyDB.ENEMIES.get(enemy_id, EnemyDB.ENEMIES["procrastination_mob"]).duplicate(true)
	_enemy_hp      = _enemy.max_hp
	_enemy_max_hp  = _enemy.max_hp
	_enemy_poise   = _enemy.max_poise
	_enemy_max_poise = _enemy.max_poise

	_player_hp      = GameManager.current_hp
	_player_fp      = GameManager.current_fp
	_player_stamina = GameManager.max_stamina

	_player_first = GameManager.stats["DEX"] >= _enemy.initiative
	_new_round    = true

	_enemy_name_lbl.text = _enemy.name
	_update_enemy_bars()
	_update_player_bars()
	_log_add("You face [b]%s[/b]." % _enemy.name, Color(0.9, 0.75, 0.2))
	_log_add(_enemy.description, Color(0.65, 0.65, 0.65))

	if _player_first:
		_log_add("You act first (higher DEX).", Color(0.55, 0.85, 0.55))
		_enter_phase(Phase.PLAYER_ATTACK)
	else:
		_log_add("Enemy acts first.", Color(0.85, 0.45, 0.35))
		_enter_phase(Phase.ENEMY_ATTACK)

# ── State machine ─────────────────────────────────────────────────────────────

func _enter_phase(new_phase: Phase) -> void:
	_phase = new_phase
	match new_phase:
		Phase.PLAYER_ATTACK:
			if _new_round:
				_player_stamina = GameManager.max_stamina
				_new_round = false
				_update_player_bars()
			_timer = DECISION_TIME
			_timer_bar.show()
			_show_player_options()

		Phase.ENEMY_ATTACK:
			_new_round = true
			_choose_enemy_move()
			_timer = DECISION_TIME
			_timer_bar.show()
			_show_defense_options()

		Phase.ENEMY_STAGGERED:
			_handle_stagger()

		Phase.VICTORY:
			_handle_victory()

		Phase.DEFEAT:
			_handle_defeat()

func _on_timer_expired() -> void:
	match _phase:
		Phase.PLAYER_ATTACK:
			_log_add("No action chosen — turn skipped.", Color(0.6, 0.6, 0.6))
			_enter_phase(Phase.ENEMY_ATTACK)
		Phase.ENEMY_ATTACK:
			_log_add("No response — you take the hit.", Color(0.85, 0.35, 0.25))
			_apply_defense("take")

# ── Player attack phase ───────────────────────────────────────────────────────

func _show_player_options() -> void:
	_clear_options()
	_phase_lbl.text = "YOUR TURN"
	_enemy_move_lbl.text = ""

	var weapon_id: String = GameManager.equipped_weapon
	var weapon: Dictionary = WeaponDB.WEAPONS.get(weapon_id, WeaponDB.WEAPONS["writers_quill"])

	for move in weapon.moveset:
		var dmg    := WeaponDB.calc_damage(move, weapon, GameManager.stats)
		var sta    : int = move.get("stamina_cost", 0)
		var fp     : int = move.get("fp_cost", 0)
		var can_use := _player_stamina >= sta and _player_fp >= fp

		var cost_str := ""
		if sta > 0: cost_str += " %dSTA" % sta
		if fp  > 0: cost_str += " %dFP"  % fp

		_btn("%s\n%ddmg |%s" % [move.name, dmg, cost_str],
			_on_attack_btn.bind(move, weapon), not can_use)

	_btn("End Turn\n(save stamina)", _on_end_turn, false)

func _on_attack_btn(move: Dictionary, weapon: Dictionary) -> void:
	_pending_move   = move
	_pending_weapon = weapon
	_task_move_lbl.text = move.name
	_task_desc_lbl.text = move.real_task
	_task_check.button_pressed = false
	_task_confirm_btn.disabled = true
	_task_layer.show()
	_phase = Phase.TASK_CONFIRM   # pause timer

func _on_end_turn() -> void:
	_log_add("You hold back, saving stamina.", Color(0.6, 0.6, 0.6))
	_enter_phase(Phase.ENEMY_ATTACK)

func _on_task_check_toggled(checked: bool) -> void:
	_task_confirm_btn.disabled = not checked

func _on_task_confirmed() -> void:
	_task_layer.hide()
	_execute_attack()

func _on_task_back() -> void:
	_task_layer.hide()
	_phase = Phase.PLAYER_ATTACK   # resume timer

func _execute_attack() -> void:
	var move   := _pending_move
	var weapon := _pending_weapon
	var sta    : int = move.get("stamina_cost", 0)
	var fp     : int = move.get("fp_cost", 0)

	_player_stamina -= sta
	_player_fp      -= fp
	_update_player_bars()

	var dmg   := WeaponDB.calc_damage(move, weapon, GameManager.stats)
	var pdmg  : int = move.get("poise_damage", 10)
	_enemy_hp    -= dmg
	_enemy_poise -= pdmg
	_update_enemy_bars()

	_log_add("You use [b]%s[/b] — %d damage!" % [move.name, dmg], Color.WHITE)

	if _enemy_hp <= 0:
		_enter_phase(Phase.VICTORY)
		return

	if _enemy_poise <= 0:
		_enemy_poise = 0
		_enter_phase(Phase.ENEMY_STAGGERED)
		return

	# Can the player afford another attack?
	var weapon_data: Dictionary = WeaponDB.WEAPONS.get(GameManager.equipped_weapon, WeaponDB.WEAPONS["writers_quill"])
	var can_chain := false
	for m in weapon_data.moveset:
		if _player_stamina >= m.get("stamina_cost", 0) and _player_fp >= m.get("fp_cost", 0):
			can_chain = true
			break

	if can_chain:
		_enter_phase(Phase.PLAYER_ATTACK)   # _new_round=false, no stamina restore
	else:
		_enter_phase(Phase.ENEMY_ATTACK)

# ── Enemy attack phase ────────────────────────────────────────────────────────

func _choose_enemy_move() -> void:
	var moveset: Array = _enemy.moveset
	_current_enemy_move = moveset[randi() % moveset.size()]
	_enemy_move_lbl.text = _current_enemy_move.name + "\n" + _current_enemy_move.description
	_log_add("The %s uses [b]%s[/b]!" % [_enemy.name, _current_enemy_move.name], Color(0.9, 0.35, 0.25))

func _show_defense_options() -> void:
	_clear_options()
	_phase_lbl.text = "ENEMY ATTACKS — Choose your response"
	var sta      := _player_stamina
	var guard_break := sta == 0

	_btn("Roll\n0 dmg | %dSTA" % STA_ROLL,  _on_defense.bind("roll"),  guard_break or sta < STA_ROLL)
	_btn("Block\n%ddmg | %dSTA" % [_current_enemy_move.get("block_damage", 0), STA_BLOCK],
		_on_defense.bind("block"), guard_break or sta < STA_BLOCK)
	_btn("Parry\n0 dmg | %dSTA" % STA_PARRY, _on_defense.bind("parry"), guard_break or sta < STA_PARRY)
	_btn("Take\n%ddmg | 0STA" % _current_enemy_move.get("damage", 0), _on_defense.bind("take"), false)

	if not _enemy.get("is_boss", false):
		_btn("Flee\n(no runes)", _on_defense.bind("flee"), false)

	if guard_break:
		_log_add("GUARD BREAK — no stamina left! You can only Take or Flee.", Color(0.9, 0.5, 0.1))

func _on_defense(action: String) -> void:
	_timer_bar.hide()
	_apply_defense(action)

func _apply_defense(action: String) -> void:
	_clear_options()
	var move := _current_enemy_move

	match action:
		"roll":
			_player_stamina -= STA_ROLL
			_log_add("You roll away. No damage taken.", Color(0.5, 0.85, 0.5))
		"block":
			_player_stamina -= STA_BLOCK
			var dmg: int = move.get("block_damage", 0)
			_player_hp -= dmg
			_log_add("You block! Took %d damage." % dmg, Color(0.85, 0.65, 0.25))
		"parry":
			_player_stamina -= STA_PARRY
			_log_add("Parried! No damage taken.", Color(0.4, 0.95, 0.4))
		"take":
			var dmg: int = move.get("damage", 0)
			_player_hp -= dmg
			_log_add("You take the full hit — %d damage!" % dmg, Color(0.9, 0.25, 0.2))
		"flee":
			_log_add("You retreat from the fight.", Color(0.65, 0.65, 0.65))
			await get_tree().create_timer(1.0).timeout
			get_tree().change_scene_to_file("res://scenes/map/world_map.tscn")
			return

	_player_stamina = maxi(_player_stamina, 0)
	_player_hp      = maxi(_player_hp, 0)
	_update_player_bars()

	if _player_hp <= 0:
		_enter_phase(Phase.DEFEAT)
	else:
		_enter_phase(Phase.PLAYER_ATTACK)

# ── Special phases ────────────────────────────────────────────────────────────

func _handle_stagger() -> void:
	_enemy_poise = _enemy_max_poise
	_update_enemy_bars()
	_clear_options()
	_phase_lbl.text = "STAGGERED!"
	_log_add("The enemy is staggered! You can attack freely.", Color(1.0, 0.9, 0.2))
	await get_tree().create_timer(STAGGER_PAUSE).timeout
	_enter_phase(Phase.PLAYER_ATTACK)

func _handle_victory() -> void:
	_timer_bar.hide()
	_clear_options()
	_phase_lbl.text = "VICTORY"

	var enemy_id: String = GameManager.pending_encounter.get("enemy_id", "")
	var is_first_kill: bool = not GameManager.defeated_enemies.has(enemy_id)

	var runes: int = _enemy.get("rune_reward", 0)
	GameManager.add_runes(runes)
	_log_add("Victory! +%d runes." % runes, Color(1.0, 0.85, 0.2))

	if is_first_kill and not enemy_id.is_empty():
		GameManager.defeated_enemies.append(enemy_id)

	if _enemy.get("is_remembrance", false):
		var area: String = _enemy.get("unlocks_area", "")
		if not area.is_empty() and not GameManager.unlocked_areas.has(area):
			GameManager.unlocked_areas.append(area)
			_log_add("New area unlocked!", Color(0.9, 0.75, 0.2))

	var drops := _resolve_drops(is_first_kill)
	if drops.is_empty():
		_log_add("No items dropped.", Color(0.5, 0.5, 0.5))
	else:
		for weapon_id in drops:
			var w: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
			_log_add("Weapon obtained: %s" % w.get("name", weapon_id), Color(0.4, 0.85, 0.95))

	_sync_player_stats()
	SaveManager.save_game()
	_btn("Return to Map", _go_to_map, false)

func _resolve_drops(is_first_kill: bool) -> Array:
	var gained: Array = []
	for drop in _enemy.get("drops", []):
		var chance: float = drop.get("first_kill_chance", 0.0) if is_first_kill \
							else drop.get("repeat_chance", 0.0)
		if chance > 0.0 and randf() <= chance:
			var weapon_id: String = drop.get("id", "")
			if not weapon_id.is_empty() and not GameManager.weapons.has(weapon_id):
				GameManager.weapons.append(weapon_id)
				gained.append(weapon_id)
	return gained

func _handle_defeat() -> void:
	_timer_bar.hide()
	_clear_options()
	_phase_lbl.text = "YOU DIED"
	GameManager.runes_at_death   = GameManager.runes
	GameManager.death_location   = GameManager.current_location
	GameManager.runes            = 0
	GameManager.current_hp       = GameManager.max_hp
	GameManager.current_location = GameManager.last_site_of_grace
	_sync_player_stats()
	SaveManager.save_game()
	_log_add("You died. Runes lost. Respawning at last Site of Grace.", Color(0.8, 0.1, 0.1))
	_btn("Return to Map", _go_to_map, false)

func _sync_player_stats() -> void:
	GameManager.current_hp      = _player_hp
	GameManager.current_fp      = _player_fp
	GameManager.current_stamina = _player_stamina

func _go_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/world_map.tscn")

# ── UI helpers ────────────────────────────────────────────────────────────────

func _update_enemy_bars() -> void:
	_enemy_hp_bar.max_value    = _enemy_max_hp
	_enemy_hp_bar.value        = _enemy_hp
	_enemy_poise_bar.max_value = _enemy_max_poise
	_enemy_poise_bar.value     = _enemy_poise

func _update_player_bars() -> void:
	_player_hp_bar.max_value  = GameManager.max_hp
	_player_hp_bar.value      = _player_hp
	_player_sta_bar.max_value = GameManager.max_stamina
	_player_sta_bar.value     = _player_stamina
	_player_fp_bar.max_value  = GameManager.max_fp
	_player_fp_bar.value      = _player_fp
	_player_hp_lbl.text  = "HP %d/%d"  % [_player_hp,      GameManager.max_hp]
	_player_sta_lbl.text = "STA %d/%d" % [_player_stamina,  GameManager.max_stamina]
	_player_fp_lbl.text  = "FP %d/%d"  % [_player_fp,       GameManager.max_fp]

func _log_add(text: String, color: Color = Color.WHITE) -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	_log.scroll_to_line(_log.get_line_count())

func _clear_options() -> void:
	for child in _options_box.get_children():
		child.queue_free()

func _btn(label: String, callback: Callable, disabled: bool = false) -> void:
	var b := Button.new()
	b.text = label
	b.disabled = disabled
	b.custom_minimum_size = Vector2(170, 56)
	b.pressed.connect(callback)
	_options_box.add_child(b)

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_build_enemy_section(root)
	_build_log_section(root)
	_build_options_section(root)
	_build_player_section(root)
	_build_task_popup()

func _build_enemy_section(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 3.0
	root.add_child(panel)

	var m := _margin_container(panel, 14)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	m.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	_enemy_name_lbl = Label.new()
	_enemy_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_name_lbl.add_theme_font_size_override("font_size", 20)
	header.add_child(_enemy_name_lbl)

	var hp_lbl_header := Label.new()
	hp_lbl_header.text = "HP"
	hp_lbl_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(hp_lbl_header)

	_enemy_hp_bar = _progress_bar(Color(0.75, 0.15, 0.1))
	_enemy_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_enemy_hp_bar)

	var poise_row := HBoxContainer.new()
	poise_row.add_theme_constant_override("separation", 8)
	vbox.add_child(poise_row)

	var poise_lbl := Label.new()
	poise_lbl.text = "POISE"
	poise_lbl.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8))
	poise_row.add_child(poise_lbl)

	_enemy_poise_bar = _progress_bar(Color(0.3, 0.5, 0.75))
	_enemy_poise_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poise_row.add_child(_enemy_poise_bar)

	_enemy_move_lbl = Label.new()
	_enemy_move_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_enemy_move_lbl.add_theme_color_override("font_color", Color(0.9, 0.45, 0.3))
	vbox.add_child(_enemy_move_lbl)

func _build_log_section(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.0
	root.add_child(panel)

	var m := _margin_container(panel, 10)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(_log)

func _build_options_section(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 3.0
	root.add_child(panel)

	var m := _margin_container(panel, 12)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	m.add_child(vbox)

	_phase_lbl = Label.new()
	_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_phase_lbl)

	_timer_bar = ProgressBar.new()
	_timer_bar.max_value = DECISION_TIME
	_timer_bar.value = DECISION_TIME
	_timer_bar.show_percentage = false
	vbox.add_child(_timer_bar)

	_options_box = HFlowContainer.new()
	_options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("h_separation", 10)
	_options_box.add_theme_constant_override("v_separation", 8)
	vbox.add_child(_options_box)

func _build_player_section(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 68
	root.add_child(panel)

	var m := _margin_container(panel, 8)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	m.add_child(hbox)

	var hp_col := _stat_column("HP", Color(0.75, 0.15, 0.1))
	_player_hp_bar  = hp_col[0]
	_player_hp_lbl  = hp_col[1]
	hbox.add_child(hp_col[2])

	var sta_col := _stat_column("STA", Color(0.85, 0.65, 0.1))
	_player_sta_bar = sta_col[0]
	_player_sta_lbl = sta_col[1]
	hbox.add_child(sta_col[2])

	var fp_col := _stat_column("FP", Color(0.2, 0.4, 0.85))
	_player_fp_bar  = fp_col[0]
	_player_fp_lbl  = fp_col[1]
	hbox.add_child(fp_col[2])

func _build_task_popup() -> void:
	_task_layer = CanvasLayer.new()
	_task_layer.layer = 10
	add_child(_task_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_task_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var m := _margin_container(panel, 26)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	var title := Label.new()
	title.text = "BEFORE YOU ATTACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_task_move_lbl = Label.new()
	_task_move_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_task_move_lbl)

	var task_header := Label.new()
	task_header.text = "Your real-world task:"
	task_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(task_header)

	_task_desc_lbl = Label.new()
	_task_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_task_desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.42))
	vbox.add_child(_task_desc_lbl)

	vbox.add_child(HSeparator.new())

	_task_check = CheckBox.new()
	_task_check.text = "I completed this task"
	_task_check.toggled.connect(_on_task_check_toggled)
	vbox.add_child(_task_check)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_task_confirm_btn = Button.new()
	_task_confirm_btn.text = "Confirm & Attack"
	_task_confirm_btn.disabled = true
	_task_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_confirm_btn.pressed.connect(_on_task_confirmed)
	btn_row.add_child(_task_confirm_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_task_back)
	btn_row.add_child(back_btn)

	_task_layer.hide()

# ── UI factory helpers ────────────────────────────────────────────────────────

func _margin_container(parent: Control, margin: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	parent.add_child(m)
	return m

func _progress_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 14
	bar.add_theme_color_override("fill_color_modulate", color)
	return bar

# Returns [ProgressBar, Label, container_node]
func _stat_column(label_text: String, color: Color) -> Array:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)

	var lbl := Label.new()
	lbl.text = label_text + " 0/0"
	lbl.add_theme_font_size_override("font_size", 11)
	col.add_child(lbl)

	var bar := _progress_bar(color)
	col.add_child(bar)

	return [bar, lbl, col]
