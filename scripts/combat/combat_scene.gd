class_name CombatScene
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const STAGGER_PAUSE := 1.5
const NOTES_PATH    := "user://notes.txt"
const STA_ROLL      := 15
const STA_BLOCK     := 20
const STA_PARRY     := 25

const ER_HP  := Color(0.73, 0.06, 0.06)
const ER_FP  := Color(0.12, 0.27, 0.70)
const ER_STA := Color(0.28, 0.62, 0.18)

const RING_CENTER  := Vector2(600, 490)
const ENEMY_CENTER := Vector2(600, 450)   # enemy display centred here; visual = screen centre
const RING_RADIUS  := 200.0
const RING_BTN_W   := 158.0
const RING_BTN_H   := 54.0

enum Phase { INIT, PLAYER_ATTACK, STEP_TIMER, ENEMY_ATTACK, ENEMY_STAGGERED, VICTORY, DEFEAT }

# ── Combat state ──────────────────────────────────────────────────────────────
var _phase: Phase = Phase.INIT
var _player_first: bool = true

var _enemy: Dictionary       = {}
var _enemy_hp: int           = 0
var _enemy_max_hp: int       = 0
var _enemy_poise: int        = 0
var _enemy_max_poise: int    = 0
var _current_enemy_move: Dictionary = {}

var _player_hp:      int = 0
var _player_stamina: int = 0
var _player_fp:      int = 0

var _enemy_status_buildup: Dictionary = {}
var _rot_turns_remaining:  int  = 0
var _enemy_skip_turn:      bool = false

# ── Chain / combo state ───────────────────────────────────────────────────────
var _chain_moveset_id: String = ""   # moveset id currently being chained ("" = none)
var _chain_step_idx:   int    = 0    # index of the NEXT step to use in the chain

# ── Step-timer attack state ───────────────────────────────────────────────────
var _active_weapon_idx:   int        = 0
var _pending_step:        Dictionary = {}
var _pending_moveset:     Dictionary = {}
var _pending_weapon_id:   String     = ""
var _step_timer:          float      = 0.0
var _step_total:          float      = 1.0
var _step_started:        bool       = false

# ── Defense task state ────────────────────────────────────────────────────────
var _timer_is_defense:        bool   = false
var _pending_defense_action:  String = ""   # "roll" | "block" | "parry"
var _defense_parry_step:      int    = 0    # 0 = enemy task, 1 = weapon task

# ── Estus (healing flasks) ────────────────────────────────────────────────────
var _player_estus:    int   = 0
var _estus_displays:  Array = []   # EstusDisplay refs (bottom slot only)
var _estus_popup:     CanvasLayer
var _estus_popup_lbl: Label

# ── UI refs ───────────────────────────────────────────────────────────────────
var _enemy_name_lbl:  Label
var _enemy_hp_bar:    ProgressBar
var _enemy_visual:    EnemyDisplay
var _enemy_move_lbl:  Label
var _log:             RichTextLabel
var _phase_lbl:       Label
var _ring_container:   Control
var _buttons_container: Control
var _player_hp_bar:   ProgressBar
var _player_sta_bar:  ProgressBar
var _player_fp_bar:   ProgressBar
var _weapon_display:   WeaponDisplay
var _status_bars_box:  HBoxContainer

# Step panel refs
var _step_panel:     PanelContainer
var _step_list:      VBoxContainer
var _weapon_tabs:    HBoxContainer

# Step timer overlay refs
var _timer_layer:      CanvasLayer
var _timer_header_lbl: Label
var _timer_step_lbl:   Label
var _timer_notes_edit: TextEdit   # writing area embedded in timer
var _timer_time_lbl:   Label
var _timer_bar:        ProgressBar
var _timer_hint_lbl:   Label
var _timer_start_btn:    Button
var _timer_done_btn:     Button
var _timer_back_btn:     Button
var _timer_confirm_box:  HBoxContainer
var _timer_yes_btn:      Button
var _timer_no_btn:       Button

# Notepad
var _notepad: NotepadOverlay

# Equipment overlay refs
var _equip_overlay:     CanvasLayer
var _equip_left_col:    VBoxContainer
var _equip_right_col:   VBoxContainer
var _equip_picker_box:  VBoxContainer
var _equip_active_wid:  String = ""
var _equip_picker_slot: int    = -1

# Victory / corpse overlay refs
var _victory_layer:       CanvasLayer
var _victory_enemy_vis:   EnemyDisplay
var _victory_enemy_lbl:   Label
var _victory_blood:       BloodSplatter
var _victory_hint_lbl:    Label
var _victory_corpse_btn:  Button
var _victory_reward_vbox: VBoxContainer
var _pending_drops:       Array = []
var _victory_is_boss:     bool  = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_init_combat()

func _process(delta: float) -> void:
	if _phase == Phase.STEP_TIMER and _step_started:
		_step_timer -= delta
		_timer_time_lbl.text = _fmt_time(ceili(_step_timer))
		_timer_bar.value = 1.0 - (_step_timer / _step_total)
		if _step_timer <= 0.0:
			_on_timer_expired()
	if _victory_layer != null and _victory_layer.visible and _victory_hint_lbl.visible:
		_victory_hint_lbl.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003)

# ── Combat initialisation ─────────────────────────────────────────────────────

func _init_combat() -> void:
	var enemy_id: String = GameManager.pending_encounter.get("enemy_id", "procrastination_mob")
	_enemy         = EnemyDB.ENEMIES.get(enemy_id, EnemyDB.ENEMIES["procrastination_mob"]).duplicate(true)
	var mult: float = GameManager.pending_encounter.get("difficulty_mult", 1.0)
	_enemy_max_hp  = int(_enemy.max_hp * mult)
	_enemy_hp      = _enemy_max_hp
	_enemy_poise   = _enemy.max_poise
	_enemy_max_poise = _enemy.max_poise

	_player_hp      = GameManager.current_hp
	_player_fp      = GameManager.current_fp
	_player_stamina = GameManager.max_stamina
	_player_estus   = GameManager.run_estus_count

	_player_first = true  # player always acts first in new system (no DEX check needed for MVP)
	_enemy_status_buildup = {}
	_rot_turns_remaining  = 0
	_enemy_skip_turn      = false
	_active_weapon_idx    = 0
	_chain_moveset_id     = ""
	_chain_step_idx       = 0
	_step_started         = false
	_timer_is_defense     = false
	_pending_defense_action = ""
	_defense_parry_step   = 0

	_enemy_name_lbl.text = _enemy.name
	_enemy_visual.set_enemy(enemy_id)
	_enemy_visual.set_interactive(false)
	_update_enemy_bars()
	_update_player_bars()
	_update_weapon_display()
	_update_estus_display()

	_log_add("You face [b]%s[/b]." % _enemy.name, Color(0.9, 0.75, 0.2))
	_log_add(_enemy.description, Color(0.65, 0.65, 0.65))

	_enter_phase(Phase.PLAYER_ATTACK)

# ── State machine ─────────────────────────────────────────────────────────────

func _enter_phase(new_phase: Phase) -> void:
	_phase = new_phase
	_enemy_visual.set_interactive(false)
	match new_phase:
		Phase.PLAYER_ATTACK:
			_show_player_options()

		Phase.ENEMY_ATTACK:
			_step_panel.visible = false
			# Scarlet Rot DOT
			if _rot_turns_remaining > 0:
				var rot_dmg: int = int(_enemy_max_hp * 0.06)
				_enemy_hp = maxi(0, _enemy_hp - rot_dmg)
				_rot_turns_remaining -= 1
				_update_enemy_bars()
				_log_add("Scarlet Rot corrodes — %d damage (%d turns left)." % [rot_dmg, _rot_turns_remaining],
					StatusEffects.COLORS["scarlet_rot"])
				if _enemy_hp <= 0:
					_enter_phase(Phase.VICTORY)
					return
			# Frost skip
			if _enemy_skip_turn:
				_enemy_skip_turn = false
				_log_add("Enemy is frozen by Frost — they cannot act this turn!", StatusEffects.COLORS["frost"])
				await get_tree().create_timer(1.2).timeout
				_enter_phase(Phase.PLAYER_ATTACK)
				return
			_choose_enemy_move()
			_show_defense_panel()

		Phase.ENEMY_STAGGERED:
			_handle_stagger()

		Phase.VICTORY:
			_handle_victory()

		Phase.DEFEAT:
			_handle_defeat()

# ── Player attack phase — step panel ─────────────────────────────────────────

func _show_player_options() -> void:
	_clear_options()
	_enemy_move_lbl.text = ""
	_step_panel.visible  = true
	_show_step_buttons()

func _show_step_buttons() -> void:
	for child in _step_list.get_children():
		child.queue_free()
	for child in _weapon_tabs.get_children():
		child.queue_free()

	var equipped: Array = GameManager.equipped_run_weapons
	if equipped.is_empty():
		var lbl := Label.new()
		lbl.text = "No weapons equipped!"
		lbl.add_theme_font_size_override("font_size", 12)
		_step_list.add_child(lbl)
		return

	# Weapon tabs (only if 2 weapons)
	if equipped.size() > 1:
		for i in range(equipped.size()):
			var wid_tab: String = equipped[i]
			var wdata_tab: Dictionary = WeaponDB.WEAPONS.get(wid_tab, {})
			var tab := Button.new()
			tab.text = wdata_tab.get("name", wid_tab)
			tab.toggle_mode = true
			tab.button_pressed = (i == _active_weapon_idx)
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_i := i
			tab.pressed.connect(func():
				_active_weapon_idx = captured_i
				_show_step_buttons()
			)
			_weapon_tabs.add_child(tab)

	var weapon_id: String = equipped[_active_weapon_idx]
	var weapon: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
	var extra_ids: Array   = GameManager.get_weapon_extra_movesets(weapon_id)

	for moveset in WeaponDB.get_moveset(weapon, extra_ids):
		# Moveset header
		var hdr := Label.new()
		hdr.text = moveset.get("name", "")
		hdr.add_theme_font_size_override("font_size", 13)
		hdr.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
		_step_list.add_child(hdr)

		var sta_cost: int      = moveset.get("stamina_cost", 5)
		var moveset_id: String = moveset.get("id", "")
		var steps: Array       = moveset.get("steps", [])

		# Show only the currently relevant step for this moveset
		var show_idx: int = _chain_step_idx \
			if (_chain_moveset_id == moveset_id and _chain_moveset_id != "") \
			else 0
		var step: Dictionary = steps[show_idx]
		var dmg: int = WeaponDB.calc_step_damage(step, moveset, weapon, GameManager.stats)
		var t: int   = step.get("time", 0)
		var can_use: bool = _player_stamina >= sta_cost
		var btn := Button.new()
		var step_prefix: String = "[%d/%d] " % [show_idx + 1, steps.size()] if steps.size() > 1 else ""
		btn.text = "%s%s\n%s  ·  %d dmg" % [step_prefix, step.get("name", ""), _fmt_time(t), dmg]
		btn.disabled = not can_use
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 54)
		btn.add_theme_font_size_override("font_size", 14)
		var captured_step: Dictionary    = step
		var captured_moveset: Dictionary = moveset
		var captured_wid     := weapon_id
		btn.pressed.connect(func():
			_on_step_clicked(captured_step, captured_moveset, captured_wid)
		)
		_step_list.add_child(btn)

	_step_list.add_child(HSeparator.new())
	var end_btn := Button.new()
	end_btn.text = "End Turn"
	end_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	end_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_btn.custom_minimum_size = Vector2(0, 46)
	end_btn.add_theme_font_size_override("font_size", 14)
	end_btn.add_theme_color_override("font_color", Color(0.70, 0.55, 0.30))
	end_btn.pressed.connect(_end_player_turn)
	_step_list.add_child(end_btn)

# ── Step timer ────────────────────────────────────────────────────────────────

func _on_step_clicked(step: Dictionary, moveset: Dictionary, weapon_id: String) -> void:
	_pending_step      = step
	_pending_moveset   = moveset
	_pending_weapon_id = weapon_id
	_step_total        = maxf(float(step.get("time", 1)), 1.0)
	_step_timer        = _step_total
	_step_started      = false

	_timer_header_lbl.text       = "TASK PREVIEW"
	_timer_header_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	_timer_step_lbl.text         = step.get("name", "")
	_timer_time_lbl.text         = _fmt_time(ceili(_step_timer))
	_timer_bar.max_value         = 1.0
	_timer_bar.value             = 0.0
	_timer_bar.visible           = false
	_timer_hint_lbl.visible      = false
	_timer_start_btn.visible     = true
	_timer_done_btn.visible      = false
	_timer_back_btn.text         = "Back"
	_timer_back_btn.visible      = true
	_timer_confirm_box.visible   = false

	_load_notes_to_timer()
	_timer_layer.show()
	_step_panel.visible = false
	_phase = Phase.STEP_TIMER

func _start_step() -> void:
	_step_started = true
	if _timer_is_defense:
		_timer_header_lbl.text = "DEFEND — COMPLETE IN TIME"
		_timer_header_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.20))
		_timer_back_btn.text = "Give up  (take full damage)"
	else:
		_timer_header_lbl.text = "TASK IN PROGRESS"
		_timer_header_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
		_timer_back_btn.text = "Back  (costs stamina)"
	_timer_bar.visible         = true
	_timer_hint_lbl.visible    = true
	_timer_start_btn.visible   = false
	_timer_done_btn.visible    = true
	_timer_back_btn.visible    = true
	_timer_confirm_box.visible = false
	_timer_notes_edit.grab_focus()

func _cancel_step() -> void:
	_save_notes_from_timer()
	var was_started := _step_started
	_step_started = false

	if _timer_is_defense:
		_timer_is_defense = false
		_timer_layer.hide()
		if was_started:
			# Gave up mid-task — take full damage
			var dmg: int = _current_enemy_move.get("damage", 0)
			_player_hp = maxi(_player_hp - dmg, 0)
			_update_player_bars()
			SoundManager.play(SoundManager.Sound.HIT)
			_log_add("You gave up defending — full damage taken!", Color(0.9, 0.25, 0.2))
			_player_stamina = GameManager.max_stamina
			_update_player_bars()
			if _player_hp <= 0:
				_enter_phase(Phase.DEFEAT)
				return
			_enter_phase(Phase.PLAYER_ATTACK)
		else:
			# Cancelled from preview — re-show defense panel
			_enter_phase(Phase.ENEMY_ATTACK)
		return

	# Attack cancel
	if was_started:
		var sta_cost: int = _pending_moveset.get("stamina_cost", 5)
		_player_stamina = maxi(_player_stamina - sta_cost, 0)
		_update_player_bars()
		_log_add("Abandoned task — stamina drained.", Color(0.80, 0.40, 0.20))
	_timer_layer.hide()
	_phase              = Phase.PLAYER_ATTACK
	_step_panel.visible = true
	_show_step_buttons()

func _load_notes_to_timer() -> void:
	if FileAccess.file_exists(NOTES_PATH):
		var f := FileAccess.open(NOTES_PATH, FileAccess.READ)
		if f:
			_timer_notes_edit.text = f.get_as_text()
			f.close()
	var line_count := _timer_notes_edit.get_line_count()
	_timer_notes_edit.set_caret_line(line_count - 1)
	_timer_notes_edit.scroll_vertical = line_count

func _save_notes_from_timer() -> void:
	var f := FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(_timer_notes_edit.text)
		f.close()

func _on_timer_expired() -> void:
	_step_started = false
	SoundManager.play(SoundManager.Sound.TIMER_DONE)
	_timer_header_lbl.text = "TIME'S UP!"
	_timer_header_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	_timer_hint_lbl.text    = "Did you complete the task?"
	_timer_hint_lbl.visible = true
	_timer_done_btn.visible    = false
	_timer_back_btn.visible    = false
	_timer_confirm_box.visible = true

func _on_timer_failed() -> void:
	if _timer_is_defense:
		_defense_timer_expired()
	else:
		_save_notes_from_timer()
		var sta_cost: int = _pending_moveset.get("stamina_cost", 5)
		_player_stamina = maxi(_player_stamina - sta_cost, 0)
		_update_player_bars()
		_log_add("Task failed — stamina drained.", Color(0.80, 0.40, 0.20))
		_timer_layer.hide()
		_phase = Phase.PLAYER_ATTACK
		_step_panel.visible = true
		_show_step_buttons()

func _execute_step() -> void:
	_save_notes_from_timer()
	if _timer_is_defense:
		_resolve_defense()
		return

	_step_started = false
	_timer_layer.hide()

	var step      := _pending_step
	var moveset   := _pending_moveset
	var weapon_id := _pending_weapon_id
	var weapon: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})

	var sta: int = moveset.get("stamina_cost", 5)
	_player_stamina = maxi(_player_stamina - sta, 0)
	_update_player_bars()

	var dmg: int  = WeaponDB.calc_step_damage(step, moveset, weapon, GameManager.stats)
	var pdmg: int = step.get("poise_damage", 5)

	_enemy_hp    -= dmg
	_enemy_poise -= pdmg
	_update_enemy_bars()

	SoundManager.play(SoundManager.Sound.HIT)
	_log_add("You complete [b]%s[/b] — %d damage!" % [step.get("name", ""), dmg], Color.WHITE)

	# Weapon XP gain
	var xp_gain: float = step.get("time", 0) / 10.0
	var levelled_up := GameManager.add_weapon_xp(weapon_id, xp_gain)
	if levelled_up:
		var new_lvl: int = GameManager.get_weapon_level(weapon_id)
		_log_add("%s reached level %d — new moveset slot!" % [weapon.get("name", weapon_id), new_lvl],
			Color(0.80, 0.65, 0.25))

	# Advance or reset chain
	var used_moveset_id: String = _pending_moveset.get("id", "")
	var all_steps: Array        = _pending_moveset.get("steps", [])
	var used_idx: int = _chain_step_idx \
		if (_chain_moveset_id == used_moveset_id and _chain_moveset_id != "") \
		else 0
	var next_chain_idx := used_idx + 1
	if next_chain_idx >= all_steps.size():
		_chain_moveset_id = ""
		_chain_step_idx   = 0
	else:
		_chain_moveset_id = used_moveset_id
		_chain_step_idx   = next_chain_idx

	if _enemy_hp <= 0:
		_enter_phase(Phase.VICTORY)
		return
	if _enemy_poise <= 0:
		_enemy_poise = 0
		_enter_phase(Phase.ENEMY_STAGGERED)
		return

	# Auto-end turn if no move is affordable
	if not _any_move_affordable():
		_log_add("Stamina exhausted — enemy seizes the moment.", Color(0.75, 0.55, 0.20))
		_enter_phase(Phase.ENEMY_ATTACK)
		return

	# Enemy interrupt — only when NOT mid-chain
	if _chain_moveset_id == "":
		var chance: float = float(_enemy.get("initiative", 5)) / 20.0
		if randf() < chance:
			_log_add("The %s interrupts!" % _enemy.name, Color(0.90, 0.35, 0.20))
			_enter_phase(Phase.ENEMY_ATTACK)
			return

	_enter_phase(Phase.PLAYER_ATTACK)

func _any_move_affordable() -> bool:
	var equipped: Array = GameManager.equipped_run_weapons
	for wid in equipped:
		var wdata: Dictionary = WeaponDB.WEAPONS.get(wid, {})
		var extra_ids: Array  = GameManager.get_weapon_extra_movesets(wid)
		for moveset in WeaponDB.get_moveset(wdata, extra_ids):
			if _player_stamina >= moveset.get("stamina_cost", 5):
				return true
	return false

func _end_player_turn() -> void:
	_enter_phase(Phase.ENEMY_ATTACK)

# ── Enemy attack phase ────────────────────────────────────────────────────────

func _choose_enemy_move() -> void:
	var moveset: Array = EnemyDB.get_moveset(_enemy)
	_current_enemy_move = moveset[randi() % moveset.size()]
	_enemy_move_lbl.text = _current_enemy_move.name + "\n" + _current_enemy_move.description
	_log_add("The %s uses [b]%s[/b]!" % [_enemy.name, _current_enemy_move.name], Color(0.9, 0.35, 0.25))

func _show_defense_panel() -> void:
	for child in _step_list.get_children():
		child.queue_free()
	for child in _weapon_tabs.get_children():
		child.queue_free()
	_clear_options()
	_step_panel.visible = true

	var move        := _current_enemy_move
	var sta         := _player_stamina
	var guard_break := sta == 0

	# Incoming attack header
	var hdr := Label.new()
	hdr.text = "DEFEND AGAINST"
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	_step_list.add_child(hdr)

	var atk_lbl := Label.new()
	atk_lbl.text = move.get("name", "")
	atk_lbl.add_theme_font_size_override("font_size", 18)
	atk_lbl.add_theme_color_override("font_color", Color(0.90, 0.35, 0.25))
	_step_list.add_child(atk_lbl)

	_step_list.add_child(HSeparator.new())

	if guard_break:
		_log_add("GUARD BREAK — no stamina! Only Take Hit or Flee.", Color(0.9, 0.5, 0.1))

	# Roll
	var dodge: Dictionary = move.get("dodge_task", {})
	_step_list.add_child(_defense_btn(
		"Roll  ·  %d STA" % STA_ROLL,
		"%s  ·  %ds" % [dodge.get("name", "???"), dodge.get("time", 20)],
		guard_break or sta < STA_ROLL or dodge.is_empty(),
		func(): _on_defense_chosen("roll")
	))

	# Block — weapon's block step
	var block_step := _get_weapon_defense_step("block")
	_step_list.add_child(_defense_btn(
		"Block  ·  %d STA  →  %d dmg" % [STA_BLOCK, move.get("block_damage", 0)],
		"%s  ·  %ds" % [block_step.get("name", "???"), block_step.get("time", 25)],
		guard_break or sta < STA_BLOCK or block_step.is_empty(),
		func(): _on_defense_chosen("block")
	))

	# Parry — 2-step: enemy parry_task → weapon parry step
	var parry_task: Dictionary = move.get("parry_task", {})
	var parry_step := _get_weapon_defense_step("parry")
	var parry_line2: String
	if not parry_task.is_empty() and not parry_step.is_empty():
		parry_line2 = "1: %s (%ds) → 2: %s (%ds)" % [
			parry_task.get("name", ""), parry_task.get("time", 15),
			parry_step.get("name", ""), parry_step.get("time", 20)]
	else:
		parry_line2 = "???"
	_step_list.add_child(_defense_btn(
		"Parry  ·  %d STA  →  0 dmg" % STA_PARRY,
		parry_line2,
		guard_break or sta < STA_PARRY or parry_task.is_empty() or parry_step.is_empty(),
		func(): _on_defense_chosen("parry")
	))

	_step_list.add_child(HSeparator.new())

	# Take Hit — instant, no task
	_step_list.add_child(_defense_btn(
		"Take Hit  →  %d dmg" % move.get("damage", 0),
		"No task required",
		false,
		func(): _apply_defense_instant("take")
	))

	# Flee — instant (not vs boss)
	if not _enemy.get("is_boss", false):
		_step_list.add_child(_defense_btn(
			"Flee",
			"Ends the run",
			false,
			func(): _apply_defense_instant("flee")
		))

func _defense_btn(title: String, subtitle: String, disabled: bool, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = "%s\n%s" % [title, subtitle]
	btn.disabled = disabled
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 54)
	btn.add_theme_font_size_override("font_size", 14)
	if not disabled:
		btn.pressed.connect(callback)
	return btn

func _get_weapon_defense_step(type: String) -> Dictionary:
	var wid: String = GameManager.equipped_run_weapons[0] \
		if not GameManager.equipped_run_weapons.is_empty() else ""
	var wdata: Dictionary = WeaponDB.WEAPONS.get(wid, {})
	var moveset_id: String = wdata.get("defense_movesets", {}).get(type, "")
	var moveset: Dictionary = MovesetDB.MOVES.get(moveset_id, {})
	var steps: Array = moveset.get("steps", [])
	return steps[0] if not steps.is_empty() else {}

func _on_defense_chosen(action: String) -> void:
	_pending_defense_action = action
	_defense_parry_step     = 0
	_timer_is_defense       = true
	_step_panel.visible     = false

	var task: Dictionary = _get_defense_task(action, 0)
	_show_defense_timer(task, action)

func _get_defense_task(action: String, step: int) -> Dictionary:
	var move := _current_enemy_move
	match action:
		"roll":  return move.get("dodge_task", {})
		"block": return _get_weapon_defense_step("block")
		"parry":
			if step == 0: return move.get("parry_task", {})
			else:         return _get_weapon_defense_step("parry")
	return {}

func _show_defense_timer(task: Dictionary, action: String) -> void:
	_step_total  = maxf(float(task.get("time", 20)), 1.0)
	_step_timer  = _step_total
	_step_started = false

	var step_label: String
	if action == "parry" and _defense_parry_step == 1:
		step_label = "PARRY — STEP 2 / 2"
	else:
		step_label = "DEFEND — %s" % action.to_upper()

	_timer_header_lbl.text = step_label
	_timer_header_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.20))
	_timer_step_lbl.text   = task.get("name", "")
	_timer_time_lbl.text   = _fmt_time(ceili(_step_timer))
	_timer_bar.max_value   = 1.0
	_timer_bar.value       = 0.0
	_timer_bar.visible     = false
	_timer_hint_lbl.visible    = false
	_timer_start_btn.visible   = true
	_timer_done_btn.visible    = false
	_timer_back_btn.text       = "Give up  (take full damage)"
	_timer_back_btn.visible    = true
	_timer_confirm_box.visible = false

	_load_notes_to_timer()
	_timer_layer.show()
	_phase = Phase.STEP_TIMER

func _defense_timer_expired() -> void:
	_save_notes_from_timer()
	_step_started     = false
	_timer_is_defense = false
	_timer_layer.hide()
	var is_parry_step2 := (_pending_defense_action == "parry" and _defense_parry_step == 1)
	if is_parry_step2:
		# Step 1 succeeded but step 2 missed — falls back to block
		_player_stamina = maxi(_player_stamina - (STA_PARRY - STA_PARRY / 2), 0)
		var dmg: int = _current_enemy_move.get("block_damage", 0)
		_player_hp = maxi(_player_hp - dmg, 0)
		_update_player_bars()
		SoundManager.play(SoundManager.Sound.BLOCK)
		_log_add("Parry step 2 missed — took %d damage (partial block)." % dmg, Color(0.85, 0.65, 0.25))
	else:
		var dmg: int = _current_enemy_move.get("damage", 0)
		_player_hp = maxi(_player_hp - dmg, 0)
		_update_player_bars()
		SoundManager.play(SoundManager.Sound.HIT)
		_log_add("Defense task missed — %d damage taken!" % dmg, Color(0.9, 0.25, 0.2))
	_player_stamina = GameManager.max_stamina
	_update_player_bars()
	if _player_hp <= 0:
		_enter_phase(Phase.DEFEAT)
	else:
		_enter_phase(Phase.PLAYER_ATTACK)

func _resolve_defense() -> void:
	_step_started     = false
	_timer_is_defense = false
	_timer_layer.hide()
	var action := _pending_defense_action
	var move   := _current_enemy_move

	match action:
		"roll":
			_player_stamina -= STA_ROLL
			SoundManager.play(SoundManager.Sound.ROLL)
			_log_add("You roll away — no damage taken.", Color(0.5, 0.85, 0.5))
		"block":
			_player_stamina -= STA_BLOCK
			var dmg: int = move.get("block_damage", 0)
			_player_hp -= dmg
			SoundManager.play(SoundManager.Sound.BLOCK)
			_log_add("You block! Took %d damage." % dmg, Color(0.85, 0.65, 0.25))
		"parry":
			if _defense_parry_step == 0:
				# Step 1 done — start weapon parry step immediately
				_defense_parry_step  = 1
				_timer_is_defense    = true
				_player_stamina -= STA_PARRY / 2
				_player_stamina  = maxi(_player_stamina, 0)
				_update_player_bars()
				_log_add("Parry step 1 done! Now the counter-move...", Color(0.75, 0.90, 0.45))
				var task := _get_defense_task("parry", 1)
				_show_defense_timer(task, "parry")
				return   # don't advance phase yet
			else:
				# Both steps done — perfect parry
				_player_stamina -= STA_PARRY - STA_PARRY / 2
				_enemy_poise    -= move.get("poise_damage", 5)
				SoundManager.play(SoundManager.Sound.PARRY)
				_log_add("Perfect parry! No damage — enemy poise broken.", Color(0.4, 0.95, 0.4))
				_update_enemy_bars()
				if _enemy_poise <= 0:
					_enemy_poise = 0
					_player_stamina = maxi(_player_stamina, 0)
					_enter_phase(Phase.ENEMY_STAGGERED)
					return

	_player_stamina = GameManager.max_stamina
	_player_hp      = maxi(_player_hp, 0)
	_update_player_bars()
	if _player_hp <= 0:
		_enter_phase(Phase.DEFEAT)
	else:
		_enter_phase(Phase.PLAYER_ATTACK)

func _apply_defense_instant(action: String) -> void:
	var move := _current_enemy_move
	match action:
		"take":
			SoundManager.play(SoundManager.Sound.HIT)
			var dmg: int = move.get("damage", 0)
			_player_hp -= dmg
			_log_add("You take the full hit — %d damage!" % dmg, Color(0.9, 0.25, 0.2))
		"flee":
			_log_add("You retreat from the fight. The run is over.", Color(0.65, 0.65, 0.65))
			GameManager.end_run_failure()
			SaveManager.save_game()
			await get_tree().create_timer(1.0).timeout
			get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")
			return
	_player_stamina = GameManager.max_stamina
	_player_hp      = maxi(_player_hp, 0)
	_update_player_bars()
	if _player_hp <= 0:
		_enter_phase(Phase.DEFEAT)
	else:
		_enter_phase(Phase.PLAYER_ATTACK)

# ── Special phases ────────────────────────────────────────────────────────────

func _trigger_status(effect: String) -> void:
	_enemy_status_buildup[effect] = 0.0
	var color: Color = StatusEffects.COLORS.get(effect, Color.WHITE)
	match effect:
		"bleed":
			var dmg: int = int(_enemy_max_hp * 0.20)
			_enemy_hp -= dmg
			_log_add("BLEED erupts! %d damage!" % dmg, color)
			SoundManager.play(SoundManager.Sound.HIT)
		"madness":
			var e_dmg: int = int(_enemy_max_hp * 0.15)
			var p_dmg: int = int(GameManager.max_hp * 0.08)
			_enemy_hp -= e_dmg
			_player_hp -= p_dmg
			_update_player_bars()
			_log_add("MADNESS erupts! %d to enemy, %d to you." % [e_dmg, p_dmg], color)
			SoundManager.play(SoundManager.Sound.HIT)
		"frost":
			var dmg: int = int(_enemy_max_hp * 0.18)
			_enemy_hp -= dmg
			_enemy_skip_turn = true
			_log_add("FROST shatters! %d damage — enemy loses next turn." % dmg, color)
		"scarlet_rot":
			_rot_turns_remaining = 3
			_log_add("SCARLET ROT spreads! 6% HP for 3 turns.", color)
	_update_enemy_bars()
	_update_status_bars()
	if _enemy_hp <= 0:
		_enter_phase(Phase.VICTORY)

func _update_status_bars() -> void:
	for child in _status_bars_box.get_children():
		child.free()
	for effect in _enemy_status_buildup:
		var buildup: float = _enemy_status_buildup.get(effect, 0.0)
		if buildup <= 0.0:
			continue
		var color: Color     = StatusEffects.COLORS.get(effect, Color.WHITE)
		var label: String    = StatusEffects.LABELS.get(effect, effect)
		var threshold: float = StatusEffects.THRESHOLDS.get(effect, 100.0)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		_status_bars_box.add_child(col)
		var lbl := Label.new()
		lbl.text = label
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", color)
		col.add_child(lbl)
		var bar := ProgressBar.new()
		bar.max_value = threshold
		bar.value     = buildup
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(68, 8)
		col.add_child(bar)
	if _rot_turns_remaining > 0:
		var rot_lbl := Label.new()
		rot_lbl.text = "Rot: %d turns" % _rot_turns_remaining
		rot_lbl.add_theme_font_size_override("font_size", 10)
		rot_lbl.add_theme_color_override("font_color", StatusEffects.COLORS["scarlet_rot"])
		_status_bars_box.add_child(rot_lbl)

func _handle_stagger() -> void:
	_enemy_poise = _enemy_max_poise
	_update_enemy_bars()
	_clear_options()
	_phase_lbl.text = "STAGGERED!"
	SoundManager.play(SoundManager.Sound.STAGGER)
	_log_add("The enemy is staggered! You can attack freely.", Color(1.0, 0.9, 0.2))
	await get_tree().create_timer(STAGGER_PAUSE).timeout
	_enter_phase(Phase.PLAYER_ATTACK)

func _handle_victory() -> void:
	_step_panel.visible = false
	_clear_options()
	_phase_lbl.text = "VICTORY"
	SoundManager.play(SoundManager.Sound.VICTORY)

	var enemy_id: String = GameManager.pending_encounter.get("enemy_id", "")
	_log_add("Victory! %s defeated." % _enemy.name, Color(1.0, 0.85, 0.2))

	var drops := _resolve_drops(enemy_id)
	for drop in drops:
		var dtype: String = drop.get("type", "")
		var did:   String = drop.get("id", "")
		if did.is_empty():
			continue
		if dtype == "weapon" and not GameManager.owned_weapons.has(did):
			GameManager.owned_weapons.append(did)
		elif dtype == "moveset" and not GameManager.owned_movesets.has(did):
			GameManager.owned_movesets.append(did)

	_sync_player_stats()
	var is_boss := GameManager.is_on_boss()
	if not is_boss:
		GameManager.advance_run()   # advance index BEFORE saving
	SaveManager.save_game()

	_show_victory_screen(drops, is_boss)

func _resolve_drops(enemy_id: String) -> Array:
	var drops: Array = []
	var enemy: Dictionary = EnemyDB.ENEMIES.get(enemy_id, {})

	# Weapon drops from enemy db (first-kill chance)
	var is_first := not GameManager.run_defeated_enemies.has(enemy_id)
	for drop in enemy.get("drops", []):
		var chance: float = drop.get("first_kill_chance", 0.0) if is_first \
							else drop.get("repeat_chance", 0.0)
		if chance > 0.0 and randf() <= chance:
			drops.append({"type": "weapon", "id": drop.get("id", "")})

	# Moveset drops for non-boss enemies (50% chance)
	if not GameManager.is_on_boss() and randf() < 0.5:
		var pool: Array = ["immediate_strike", "single_thought", "explain_simply",
						   "concrete_hit", "question_jab", "momentum_combo", "recovery_roll"]
		pool.shuffle()
		for mid in pool:
			if not GameManager.owned_movesets.has(mid):
				drops.append({"type": "moveset", "id": mid})
				break

	return drops

func _handle_defeat() -> void:
	_step_panel.visible = false
	_clear_options()
	_phase_lbl.text = "DEFEAT"
	SoundManager.play(SoundManager.Sound.DEFEAT)
	_log_add("You have fallen. The run is over.", Color(0.8, 0.1, 0.1))
	_sync_player_stats()
	GameManager.end_run_failure()
	SaveManager.save_game()
	_btn("Back to Weapons", _go_to_weapon_select, false)

func _sync_player_stats() -> void:
	GameManager.current_hp      = _player_hp
	GameManager.current_fp      = _player_fp
	GameManager.current_stamina = _player_stamina
	GameManager.run_estus_count = _player_estus

# ── Navigation ────────────────────────────────────────────────────────────────

func _go_to_run_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/run_map.tscn")

func _go_to_run_complete() -> void:
	# Pick a rare moveset reward not yet owned
	var rare_pool: Array = ["raw_take", "endurance_strike", "fast_publish"]
	rare_pool.shuffle()
	var reward_id: String = ""
	for mid in rare_pool:
		if not GameManager.owned_movesets.has(mid):
			reward_id = mid
			break
	GameManager.pending_run_reward = reward_id if not reward_id.is_empty() else ""
	get_tree().change_scene_to_file("res://scenes/ui/run_complete.tscn")

func _go_to_weapon_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")

# ── Victory / corpse screen ───────────────────────────────────────────────────

func _show_victory_screen(drops: Array, is_boss: bool) -> void:
	_pending_drops   = drops
	_victory_is_boss = is_boss

	_victory_enemy_lbl.text = _enemy.name
	_victory_enemy_vis.set_enemy(GameManager.pending_encounter.get("enemy_id", ""))
	_victory_blood.reset()

	_victory_corpse_btn.disabled = false
	_victory_hint_lbl.visible    = true
	_victory_reward_vbox.visible = false
	for child in _victory_reward_vbox.get_children():
		child.free()

	_victory_layer.show()

func _on_corpse_clicked() -> void:
	_victory_corpse_btn.disabled = true
	_victory_hint_lbl.visible    = false
	SoundManager.play(SoundManager.Sound.LOOT_DROP)

	var has_drops := false
	for drop in _pending_drops:
		var dtype: String = drop.get("type", "")
		var did:   String = drop.get("id", "")
		if did.is_empty():
			continue
		has_drops = true
		var name_str: String
		var col: Color
		if dtype == "weapon":
			name_str = "⚔  New weapon: %s" % WeaponDB.WEAPONS.get(did, {}).get("name", did)
			col = Color(0.45, 0.88, 0.98)
		else:
			name_str = "✦  New moveset: %s" % MovesetDB.MOVES.get(did, {}).get("name", did)
			col = Color(0.75, 0.92, 0.55)
		var lbl := Label.new()
		lbl.text = name_str
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", col)
		_victory_reward_vbox.add_child(lbl)

	if not has_drops:
		var no_lbl := Label.new()
		no_lbl.text = "Nothing dropped."
		no_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_lbl.add_theme_font_size_override("font_size", 13)
		no_lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.40))
		_victory_reward_vbox.add_child(no_lbl)

	var nav_btn := Button.new()
	nav_btn.add_theme_font_size_override("font_size", 14)
	nav_btn.custom_minimum_size = Vector2(220, 46)
	if _victory_is_boss:
		nav_btn.text = "Complete Run"
		nav_btn.pressed.connect(_go_to_run_complete)
	else:
		nav_btn.text = "Continue →"
		nav_btn.pressed.connect(_go_to_run_map)
	var nav_center := CenterContainer.new()
	nav_center.add_child(nav_btn)
	_victory_reward_vbox.add_child(nav_center)

	_victory_reward_vbox.visible = true

# ── UI helpers ────────────────────────────────────────────────────────────────

func _update_weapon_display() -> void:
	var equipped: Array = GameManager.equipped_run_weapons
	if equipped.is_empty():
		return
	var wid: String = equipped[_active_weapon_idx]
	_weapon_display.set_weapon(wid)

func _update_enemy_bars() -> void:
	_enemy_hp_bar.max_value = _enemy_max_hp
	_enemy_hp_bar.value     = _enemy_hp

func _update_player_bars() -> void:
	_player_hp_bar.max_value  = GameManager.max_hp
	_player_hp_bar.value      = _player_hp
	_player_fp_bar.max_value  = GameManager.max_fp
	_player_fp_bar.value      = _player_fp
	_player_sta_bar.max_value = GameManager.max_stamina
	_player_sta_bar.value     = _player_stamina

func _log_add(text: String, color: Color = Color.WHITE) -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	_log.scroll_to_line(_log.get_line_count())

func _clear_options() -> void:
	for child in _buttons_container.get_children():
		child.queue_free()

func _btn(label: String, callback: Callable, disabled: bool = false) -> void:
	_clear_options()
	var b := Button.new()
	b.text = label
	b.disabled = disabled
	b.custom_minimum_size = Vector2(220, 54)
	b.position = RING_CENTER - Vector2(110, 27)
	b.pressed.connect(callback)
	_buttons_container.add_child(b)

func _populate_ring(items: Array) -> void:
	_clear_options()
	var n := items.size()
	if n == 0:
		return
	for i in range(n):
		var angle := (float(i) / n) * TAU - PI / 2.0
		var center := RING_CENTER + Vector2(cos(angle), sin(angle)) * RING_RADIUS
		var b := Button.new()
		b.text           = items[i].label
		b.disabled       = items[i].get("disabled", false)
		b.custom_minimum_size = Vector2(RING_BTN_W, RING_BTN_H)
		b.position       = center - Vector2(RING_BTN_W, RING_BTN_H) / 2.0
		b.pressed.connect(items[i].callback)
		_buttons_container.add_child(b)

func _fmt_time(secs: int) -> String:
	if secs <= 0:
		return "0 s"
	if secs < 60:
		return "%d s" % secs
	return "%d:%02d" % [secs / 60, secs % 60]

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_player_stats()
	_build_ring()
	_build_equipment_slots()
	_build_log()
	_build_step_panel()
	_build_step_timer_overlay()
	_notepad = NotepadOverlay.new()
	add_child(_notepad)
	_build_equip_overlay()
	_build_estus_popup()
	_build_victory_overlay()

# ── Player stats — upper left ─────────────────────────────────────────────────

func _build_player_stats() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_right  = 260
	panel.offset_bottom = 86
	panel.offset_left   = 12
	panel.offset_top    = 12
	add_child(panel)

	var m := _margin_container(panel, 8)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	m.add_child(vbox)

	_player_hp_bar  = _thick_bar(ER_HP)
	_player_fp_bar  = _thick_bar(ER_FP)
	_player_sta_bar = _thick_bar(ER_STA)
	vbox.add_child(_player_hp_bar)
	vbox.add_child(_player_fp_bar)
	vbox.add_child(_player_sta_bar)

func _thick_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(230, 20)
	_apply_bar_color(bar, color)
	return bar

# ── Ring menu — centre ────────────────────────────────────────────────────────

func _build_ring() -> void:
	_ring_container = Control.new()
	_ring_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring_container)

	_buttons_container = Control.new()
	_buttons_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buttons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_container.add_child(_buttons_container)

	_phase_lbl = Label.new()
	_phase_lbl.visible = false
	_ring_container.add_child(_phase_lbl)

	# Visual: 130 × 150 px centred on RING_CENTER
	# Name → HP bar → visual → status → move desc

	_enemy_name_lbl = Label.new()
	_enemy_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_name_lbl.add_theme_font_size_override("font_size", 16)
	_enemy_name_lbl.custom_minimum_size = Vector2(220, 0)
	_enemy_name_lbl.position = Vector2(ENEMY_CENTER.x - 110, ENEMY_CENTER.y - 125)
	_ring_container.add_child(_enemy_name_lbl)

	_enemy_hp_bar = _progress_bar(ER_HP)
	_enemy_hp_bar.custom_minimum_size = Vector2(200, 16)
	_enemy_hp_bar.position = Vector2(ENEMY_CENTER.x - 100, ENEMY_CENTER.y - 99)
	_ring_container.add_child(_enemy_hp_bar)

	_enemy_visual = EnemyDisplay.new()
	_enemy_visual.custom_minimum_size = Vector2(130, 150)
	_enemy_visual.position = Vector2(ENEMY_CENTER.x - 65, ENEMY_CENTER.y - 75)
	_ring_container.add_child(_enemy_visual)

	_status_bars_box = HBoxContainer.new()
	_status_bars_box.add_theme_constant_override("separation", 10)
	_status_bars_box.position = Vector2(ENEMY_CENTER.x - 100, ENEMY_CENTER.y + 87)
	_ring_container.add_child(_status_bars_box)

	_enemy_move_lbl = Label.new()
	_enemy_move_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_move_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_enemy_move_lbl.add_theme_font_size_override("font_size", 12)
	_enemy_move_lbl.add_theme_color_override("font_color", Color(0.90, 0.45, 0.30))
	_enemy_move_lbl.custom_minimum_size = Vector2(280, 0)
	_enemy_move_lbl.position = Vector2(ENEMY_CENTER.x - 140, ENEMY_CENTER.y + 103)
	_ring_container.add_child(_enemy_move_lbl)

# ── Step panel — left side (player attack UI) ─────────────────────────────────

func _build_step_panel() -> void:
	_step_panel = PanelContainer.new()
	_step_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_step_panel.offset_left   = 12
	_step_panel.offset_right  = 320
	_step_panel.offset_top    = 96
	_step_panel.offset_bottom = 500
	_step_panel.visible = false
	add_child(_step_panel)

	var m := _margin_container(_step_panel, 6)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)

	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 4)
	outer.add_child(icon_row)

	var equip_btn := Button.new()
	equip_btn.text = "⚙"
	equip_btn.tooltip_text = "Equipment"
	equip_btn.custom_minimum_size = Vector2(36, 32)
	equip_btn.add_theme_font_size_override("font_size", 18)
	equip_btn.pressed.connect(_show_equip_overlay)
	icon_row.add_child(equip_btn)

	var notes_btn := Button.new()
	notes_btn.text = "✏"
	notes_btn.tooltip_text = "Notepad"
	notes_btn.custom_minimum_size = Vector2(36, 32)
	notes_btn.add_theme_font_size_override("font_size", 18)
	notes_btn.pressed.connect(func(): _notepad.show_notepad())
	icon_row.add_child(notes_btn)

	_weapon_tabs = HBoxContainer.new()
	_weapon_tabs.add_theme_constant_override("separation", 4)
	outer.add_child(_weapon_tabs)

	_step_list = VBoxContainer.new()
	_step_list.add_theme_constant_override("separation", 3)
	_step_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_step_list)

# ── Step timer overlay ────────────────────────────────────────────────────────

func _build_step_timer_overlay() -> void:
	_timer_layer = CanvasLayer.new()
	_timer_layer.layer = 5
	_timer_layer.hide()
	add_child(_timer_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var m := _margin_container(panel, 28)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	m.add_child(vbox)

	_timer_header_lbl = Label.new()
	_timer_header_lbl.text = "TASK PREVIEW"
	_timer_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_header_lbl.add_theme_font_size_override("font_size", 13)
	_timer_header_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	vbox.add_child(_timer_header_lbl)

	vbox.add_child(HSeparator.new())

	_timer_step_lbl = Label.new()
	_timer_step_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_timer_step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_step_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_timer_step_lbl)

	# Writing area — the player's notepad, embedded directly in the timer
	_timer_notes_edit = TextEdit.new()
	_timer_notes_edit.custom_minimum_size = Vector2(0, 190)
	_timer_notes_edit.wrap_mode           = TextEdit.LINE_WRAPPING_BOUNDARY
	_timer_notes_edit.add_theme_font_size_override("font_size", 14)
	_timer_notes_edit.placeholder_text    = "Write your response here…"
	vbox.add_child(_timer_notes_edit)

	_timer_time_lbl = Label.new()
	_timer_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_time_lbl.add_theme_font_size_override("font_size", 52)
	_timer_time_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	vbox.add_child(_timer_time_lbl)

	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 10)
	_timer_bar.visible = false
	_apply_bar_color(_timer_bar, Color(0.90, 0.75, 0.20))
	vbox.add_child(_timer_bar)

	_timer_hint_lbl = Label.new()
	_timer_hint_lbl.text = "Write in the box above — click Done when finished."
	_timer_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_hint_lbl.add_theme_font_size_override("font_size", 11)
	_timer_hint_lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	_timer_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_timer_hint_lbl.visible = false
	vbox.add_child(_timer_hint_lbl)

	vbox.add_child(HSeparator.new())

	# Primary action buttons — large, centred
	var action_center := CenterContainer.new()
	vbox.add_child(action_center)

	_timer_start_btn = Button.new()
	_timer_start_btn.text = "Start Task"
	_timer_start_btn.custom_minimum_size = Vector2(240, 56)
	_timer_start_btn.add_theme_font_size_override("font_size", 16)
	_timer_start_btn.pressed.connect(_start_step)
	action_center.add_child(_timer_start_btn)

	_timer_done_btn = Button.new()
	_timer_done_btn.text = "Done!"
	_timer_done_btn.custom_minimum_size = Vector2(240, 56)
	_timer_done_btn.add_theme_font_size_override("font_size", 16)
	_timer_done_btn.visible = false
	_timer_done_btn.pressed.connect(_execute_step)
	action_center.add_child(_timer_done_btn)

	# Back — small, de-emphasised, below the primary button
	var back_center := CenterContainer.new()
	vbox.add_child(back_center)

	_timer_back_btn = Button.new()
	_timer_back_btn.text = "Back"
	_timer_back_btn.flat = true
	_timer_back_btn.add_theme_font_size_override("font_size", 11)
	_timer_back_btn.custom_minimum_size = Vector2(120, 28)
	_timer_back_btn.pressed.connect(_cancel_step)
	back_center.add_child(_timer_back_btn)

	# Confirm box — shown only when timer hits 0
	var confirm_center := CenterContainer.new()
	vbox.add_child(confirm_center)

	_timer_confirm_box = HBoxContainer.new()
	_timer_confirm_box.add_theme_constant_override("separation", 20)
	_timer_confirm_box.visible = false
	confirm_center.add_child(_timer_confirm_box)

	_timer_yes_btn = Button.new()
	_timer_yes_btn.text = "Yes, I did it!"
	_timer_yes_btn.custom_minimum_size = Vector2(180, 56)
	_timer_yes_btn.add_theme_font_size_override("font_size", 16)
	_timer_yes_btn.add_theme_color_override("font_color", Color(0.40, 0.90, 0.40))
	_timer_yes_btn.pressed.connect(_execute_step)
	_timer_confirm_box.add_child(_timer_yes_btn)

	_timer_no_btn = Button.new()
	_timer_no_btn.text = "No, I failed"
	_timer_no_btn.custom_minimum_size = Vector2(180, 56)
	_timer_no_btn.add_theme_font_size_override("font_size", 16)
	_timer_no_btn.add_theme_color_override("font_color", Color(0.90, 0.35, 0.25))
	_timer_no_btn.pressed.connect(_on_timer_failed)
	_timer_confirm_box.add_child(_timer_no_btn)

# ── Equipment overlay ─────────────────────────────────────────────────────────

func _build_equip_overlay() -> void:
	_equip_overlay = CanvasLayer.new()
	_equip_overlay.layer = 9
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

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body)

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

	var display := WeaponDisplay.new()
	display.custom_minimum_size = Vector2(140, 165)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(display)
	display.set_weapon(weapon_id)

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
		xp_bar.max_value = thres; xp_bar.value = wxp
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

	if not constants.is_empty():
		var chdr := Label.new()
		chdr.text = "CONSTANT"
		chdr.add_theme_font_size_override("font_size", 10)
		chdr.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
		info.add_child(chdr)
		for mid in constants:
			var mname: String = MovesetDB.MOVES.get(mid, {}).get("name", mid)
			info.add_child(_equip_pill(mname, "constant"))

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
			rm.text = "✕"; rm.custom_minimum_size = Vector2(24, 24)
			rm.add_theme_font_size_override("font_size", 10)
			var cw := weapon_id; var ci := slot_idx
			rm.pressed.connect(func(): _remove_slot(cw, ci))
			row.add_child(rm)
			info.add_child(row)
		else:
			var ep := _equip_pill("+ assign", "empty")
			var cw := weapon_id; var ci := slot_idx
			ep.pressed.connect(func(): _on_slot_empty_pressed(cw, ci))
			info.add_child(ep)

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
	var wdata: Dictionary = WeaponDB.WEAPONS.get(_equip_active_wid, {})
	var constants: Array  = wdata.get("constant_movesets", [])
	var slotted: Array    = GameManager.get_weapon_extra_movesets(_equip_active_wid)

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

# ── Victory overlay ───────────────────────────────────────────────────────────

func _build_victory_overlay() -> void:
	_victory_layer = CanvasLayer.new()
	_victory_layer.layer = 7
	_victory_layer.hide()
	add_child(_victory_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var m := _margin_container(panel, 24)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	# Header + enemy name
	var hdr := Label.new()
	hdr.text = "ENEMY FALLEN"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	vbox.add_child(hdr)

	_victory_enemy_lbl = Label.new()
	_victory_enemy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_enemy_lbl.add_theme_font_size_override("font_size", 22)
	_victory_enemy_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	vbox.add_child(_victory_enemy_lbl)

	vbox.add_child(HSeparator.new())

	# Corpse area — blood behind, enemy visual on top, transparent click button over all
	var corpse_ctrl := Control.new()
	corpse_ctrl.custom_minimum_size = Vector2(320, 240)
	corpse_ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(corpse_ctrl)

	_victory_blood = BloodSplatter.new()
	_victory_blood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpse_ctrl.add_child(_victory_blood)

	_victory_enemy_vis = EnemyDisplay.new()
	_victory_enemy_vis.custom_minimum_size = Vector2(160, 190)
	_victory_enemy_vis.position = Vector2(80, 8)
	_victory_enemy_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory_enemy_vis.modulate = Color(0.50, 0.46, 0.52)   # desaturated / dead look
	corpse_ctrl.add_child(_victory_enemy_vis)

	_victory_corpse_btn = Button.new()
	_victory_corpse_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_corpse_btn.flat = true
	_victory_corpse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		_victory_corpse_btn.add_theme_stylebox_override(s, empty)
	_victory_corpse_btn.pressed.connect(_on_corpse_clicked)
	corpse_ctrl.add_child(_victory_corpse_btn)

	# Pulsing hint
	_victory_hint_lbl = Label.new()
	_victory_hint_lbl.text = "◆  Click the fallen enemy to claim spoils  ◆"
	_victory_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_hint_lbl.add_theme_font_size_override("font_size", 12)
	_victory_hint_lbl.add_theme_color_override("font_color", Color(0.80, 0.68, 0.28))
	vbox.add_child(_victory_hint_lbl)

	vbox.add_child(HSeparator.new())

	# Reward list — populated and revealed on corpse click
	_victory_reward_vbox = VBoxContainer.new()
	_victory_reward_vbox.add_theme_constant_override("separation", 10)
	_victory_reward_vbox.visible = false
	vbox.add_child(_victory_reward_vbox)

# ── Estus (healing flasks) ────────────────────────────────────────────────────

func _wire_estus_slot(slot: Panel) -> void:
	var display := EstusDisplay.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(display)
	_estus_displays.append(display)

	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, empty)
	btn.pressed.connect(_show_estus_popup)
	slot.add_child(btn)

func _update_estus_display() -> void:
	if _estus_displays.is_empty():
		return
	var d: EstusDisplay = _estus_displays[0]
	if _player_estus > 0:
		d.set_count(_player_estus)
		d.visible = true
	else:
		d.visible = false

func _build_estus_popup() -> void:
	_estus_popup = CanvasLayer.new()
	_estus_popup.layer = 6
	_estus_popup.hide()
	add_child(_estus_popup)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_estus_popup.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)

	var m := _margin_container(panel, 24)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	var title := Label.new()
	title.text = "Drink Estus?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	vbox.add_child(title)

	_estus_popup_lbl = Label.new()
	_estus_popup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estus_popup_lbl.add_theme_font_size_override("font_size", 13)
	_estus_popup_lbl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55))
	vbox.add_child(_estus_popup_lbl)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var drink_btn := Button.new()
	drink_btn.text = "Drink"
	drink_btn.custom_minimum_size = Vector2(120, 40)
	drink_btn.pressed.connect(_confirm_estus)
	btn_row.add_child(drink_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	cancel_btn.flat = true
	cancel_btn.pressed.connect(func(): _estus_popup.hide())
	btn_row.add_child(cancel_btn)

func _show_estus_popup() -> void:
	if _phase != Phase.PLAYER_ATTACK or _player_estus <= 0:
		return
	var heal_amt: int = int(GameManager.max_hp * 0.40)
	_estus_popup_lbl.text = "%d remaining  ·  restores ~%d HP" % [_player_estus, heal_amt]
	_estus_popup.show()

func _confirm_estus() -> void:
	_estus_popup.hide()
	_use_estus()

func _use_estus() -> void:
	if _player_estus <= 0:
		return
	var heal_amt: int = int(GameManager.max_hp * 0.40)
	_player_hp    = mini(_player_hp + heal_amt, GameManager.max_hp)
	_player_estus -= 1
	GameManager.run_estus_count = _player_estus
	SaveManager.save_game()
	_update_player_bars()
	_update_estus_display()
	SoundManager.play(SoundManager.Sound.SITE_OF_GRACE)
	_log_add("You drink an estus — +%d HP." % heal_amt, Color(0.45, 0.88, 0.45))

# ── Equipment slots — bottom left ─────────────────────────────────────────────

func _build_equipment_slots() -> void:
	const SZ  := 76.0
	const GAP := 10.0
	const PAD :=  8.0
	var STEP  := SZ + GAP

	var content_sz := 3.0 * SZ + 2.0 * GAP
	var label_h    := 17.0
	var panel_w    := int(2.0 * PAD + content_sz)
	var panel_h    := int(2.0 * PAD + content_sz + label_h)

	var outer := PanelContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	outer.offset_left   = 10
	outer.offset_right  = 10 + panel_w
	outer.offset_bottom = -10
	outer.offset_top    = -10 - panel_h
	add_child(outer)

	var m := _margin_container(outer, int(PAD))
	var root := Control.new()
	root.custom_minimum_size = Vector2(content_sz, content_sz + label_h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(root)

	_equipment_slot(root, Vector2(STEP, 0),            SZ, false)
	_equipment_slot(root, Vector2(0,    STEP),         SZ, false)
	var wslot := _equipment_slot(root, Vector2(2.0 * STEP, STEP), SZ, true)
	var es3   := _equipment_slot(root, Vector2(STEP, 2.0 * STEP), SZ, false)
	_wire_estus_slot(es3)

	_weapon_display = WeaponDisplay.new()
	_weapon_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wslot.add_child(_weapon_display)


func _equipment_slot(parent: Control, pos: Vector2, sz: float, active: bool) -> Panel:
	var slot := Panel.new()
	slot.position = pos
	slot.size     = Vector2(sz, sz)
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.06, 0.05, 0.09)
	sbox.set_corner_radius_all(3)
	if active:
		sbox.set_border_width_all(2)
		sbox.border_color = Color(0.68, 0.56, 0.22)
	else:
		sbox.set_border_width_all(1)
		sbox.border_color = Color(0.22, 0.20, 0.26)
	slot.add_theme_stylebox_override("panel", sbox)
	parent.add_child(slot)
	return slot

# ── Battle log — right strip ──────────────────────────────────────────────────

func _build_log() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -345
	panel.offset_right  = -10
	panel.offset_top    = 10
	panel.offset_bottom = -10
	add_child(panel)

	var m := _margin_container(panel, 8)
	_log = RichTextLabel.new()
	_log.bbcode_enabled   = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("font_size", 11)
	m.add_child(_log)

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
	_apply_bar_color(bar, color)
	return bar

func _apply_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.09, 0.13)
	bg.set_corner_radius_all(5)
	bg.set_border_width_all(1)
	bg.border_color = color.darkened(0.35)
	bar.add_theme_stylebox_override("background", bg)
