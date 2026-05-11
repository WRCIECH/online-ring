class_name CombatScene
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const STAGGER_PAUSE := 1.5
const STA_ROLL      := 15
const STA_BLOCK     := 20
const STA_PARRY     := 25

const ER_HP  := Color(0.73, 0.06, 0.06)
const ER_FP  := Color(0.12, 0.27, 0.70)
const ER_STA := Color(0.28, 0.62, 0.18)

const RING_CENTER := Vector2(600, 490)
const RING_RADIUS := 200.0
const RING_BTN_W  := 158.0
const RING_BTN_H  := 54.0

enum Phase { INIT, PLAYER_ATTACK, STEP_TIMER, ENEMY_ATTACK, ENEMY_STAGGERED, VICTORY, DEFEAT }

# ── Combat state ──────────────────────────────────────────────────────────────
var _phase: Phase = Phase.INIT
var _new_round:   bool = true
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

# ── Step-timer attack state ───────────────────────────────────────────────────
var _active_weapon_idx:   int        = 0
var _pending_step:        Dictionary = {}
var _pending_moveset:     Dictionary = {}
var _pending_weapon_id:   String     = ""
var _step_timer:          float      = 0.0
var _step_total:          float      = 1.0

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
var _weapon_name_lbl:  Label
var _status_bars_box:  HBoxContainer

# Step panel refs
var _step_panel:     PanelContainer
var _step_list:      VBoxContainer
var _weapon_tabs:    HBoxContainer

# Step timer overlay refs
var _timer_layer:    CanvasLayer
var _timer_step_lbl: Label
var _timer_time_lbl: Label
var _timer_bar:      ProgressBar

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_init_combat()

func _process(delta: float) -> void:
	if _phase == Phase.STEP_TIMER:
		_step_timer -= delta
		_timer_time_lbl.text = _fmt_time(ceili(_step_timer))
		_timer_bar.value = 1.0 - (_step_timer / _step_total)
		if _step_timer <= 0.0:
			_execute_step()

# ── Combat initialisation ─────────────────────────────────────────────────────

func _init_combat() -> void:
	var enemy_id: String = GameManager.pending_encounter.get("enemy_id", "procrastination_mob")
	_enemy         = EnemyDB.ENEMIES.get(enemy_id, EnemyDB.ENEMIES["procrastination_mob"]).duplicate(true)
	_enemy_hp      = _enemy.max_hp
	_enemy_max_hp  = _enemy.max_hp
	_enemy_poise   = _enemy.max_poise
	_enemy_max_poise = _enemy.max_poise

	_player_hp      = GameManager.current_hp
	_player_fp      = GameManager.current_fp
	_player_stamina = GameManager.max_stamina

	_player_first = true  # player always acts first in new system (no DEX check needed for MVP)
	_new_round    = true
	_enemy_status_buildup = {}
	_rot_turns_remaining  = 0
	_enemy_skip_turn      = false
	_active_weapon_idx    = 0

	_enemy_name_lbl.text = _enemy.name
	_enemy_visual.set_enemy(enemy_id)
	_enemy_visual.set_interactive(false)
	_update_enemy_bars()
	_update_player_bars()
	_update_weapon_display()

	_log_add("You face [b]%s[/b]." % _enemy.name, Color(0.9, 0.75, 0.2))
	_log_add(_enemy.description, Color(0.65, 0.65, 0.65))

	_enter_phase(Phase.PLAYER_ATTACK)

# ── State machine ─────────────────────────────────────────────────────────────

func _enter_phase(new_phase: Phase) -> void:
	_phase = new_phase
	_enemy_visual.set_interactive(false)
	match new_phase:
		Phase.PLAYER_ATTACK:
			if _new_round:
				_player_stamina = GameManager.max_stamina
				_new_round = false
				_update_player_bars()
			_show_player_options()

		Phase.ENEMY_ATTACK:
			_new_round = true
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
			_show_defense_options()

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
		hdr.add_theme_font_size_override("font_size", 10)
		hdr.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
		_step_list.add_child(hdr)

		var sta_cost: int = moveset.get("stamina_cost", 5)

		for step in moveset.get("steps", []):
			var dmg: int  = WeaponDB.calc_step_damage(step, moveset, weapon, GameManager.stats)
			var t: int    = step.get("time", 0)
			var can_use   := _player_stamina >= sta_cost
			var btn := Button.new()
			btn.text = "%s\n%s  ·  %d dmg" % [step.get("name", ""), _fmt_time(t), dmg]
			btn.disabled = not can_use
			btn.custom_minimum_size = Vector2(0, 46)
			btn.add_theme_font_size_override("font_size", 10)
			var captured_step    := step
			var captured_moveset := moveset
			var captured_wid     := weapon_id
			btn.pressed.connect(func():
				_on_step_clicked(captured_step, captured_moveset, captured_wid)
			)
			_step_list.add_child(btn)

# ── Step timer ────────────────────────────────────────────────────────────────

func _on_step_clicked(step: Dictionary, moveset: Dictionary, weapon_id: String) -> void:
	_pending_step      = step
	_pending_moveset   = moveset
	_pending_weapon_id = weapon_id
	_step_total        = maxf(float(step.get("time", 1)), 1.0)
	_step_timer        = _step_total

	_timer_step_lbl.text = step.get("name", "")
	_timer_time_lbl.text = _fmt_time(ceili(_step_timer))
	_timer_bar.max_value = 1.0
	_timer_bar.value     = 0.0
	_timer_layer.show()
	_step_panel.visible = false

	_phase = Phase.STEP_TIMER

func _cancel_step() -> void:
	_timer_layer.hide()
	_phase = Phase.PLAYER_ATTACK
	_step_panel.visible = true
	_show_step_buttons()

func _execute_step() -> void:
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

	if _enemy_hp <= 0:
		_enter_phase(Phase.VICTORY)
		return
	if _enemy_poise <= 0:
		_enemy_poise = 0
		_enter_phase(Phase.ENEMY_STAGGERED)
		return

	_enter_phase(Phase.ENEMY_ATTACK)

# ── Enemy attack phase ────────────────────────────────────────────────────────

func _choose_enemy_move() -> void:
	var moveset: Array = EnemyDB.get_moveset(_enemy)
	_current_enemy_move = moveset[randi() % moveset.size()]
	_enemy_move_lbl.text = _current_enemy_move.name + "\n" + _current_enemy_move.description
	_log_add("The %s uses [b]%s[/b]!" % [_enemy.name, _current_enemy_move.name], Color(0.9, 0.35, 0.25))

func _show_defense_options() -> void:
	var sta         := _player_stamina
	var guard_break := sta == 0
	var items: Array = [
		{"label": "Roll",     "callback": _on_defense.bind("roll"),  "disabled": guard_break or sta < STA_ROLL},
		{"label": "Block",    "callback": _on_defense.bind("block"), "disabled": guard_break or sta < STA_BLOCK},
		{"label": "Parry",    "callback": _on_defense.bind("parry"), "disabled": guard_break or sta < STA_PARRY},
		{"label": "Take Hit", "callback": _on_defense.bind("take"),  "disabled": false},
	]
	if not _enemy.get("is_boss", false):
		items.append({"label": "Flee", "callback": _on_defense.bind("flee"), "disabled": false})
	if guard_break:
		_log_add("GUARD BREAK — no stamina! Only Take or Flee.", Color(0.9, 0.5, 0.1))
	_populate_ring(items)

func _on_defense(action: String) -> void:
	_apply_defense(action)

func _apply_defense(action: String) -> void:
	_clear_options()
	var move := _current_enemy_move
	match action:
		"roll":
			SoundManager.play(SoundManager.Sound.ROLL)
			_player_stamina -= STA_ROLL
			_log_add("You roll away. No damage taken.", Color(0.5, 0.85, 0.5))
		"block":
			SoundManager.play(SoundManager.Sound.BLOCK)
			_player_stamina -= STA_BLOCK
			var dmg: int = move.get("block_damage", 0)
			_player_hp -= dmg
			_log_add("You block! Took %d damage." % dmg, Color(0.85, 0.65, 0.25))
		"parry":
			SoundManager.play(SoundManager.Sound.PARRY)
			_player_stamina -= STA_PARRY
			_log_add("Parried! No damage taken.", Color(0.4, 0.95, 0.4))
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

	_player_stamina = maxi(_player_stamina, 0)
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
		child.queue_free()
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
			_log_add("New weapon: %s" % WeaponDB.WEAPONS.get(did, {}).get("name", did),
				Color(0.4, 0.85, 0.95))
		elif dtype == "moveset" and not GameManager.owned_movesets.has(did):
			GameManager.owned_movesets.append(did)
			_log_add("New moveset: %s" % MovesetDB.MOVES.get(did, {}).get("name", did),
				Color(0.45, 0.85, 0.55))

	_sync_player_stats()
	SaveManager.save_game()

	if GameManager.is_on_boss():
		_btn("Complete Run", _go_to_run_complete, false)
	else:
		GameManager.advance_run()
		_btn("Continue Run", _go_to_run_map, false)

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

# ── UI helpers ────────────────────────────────────────────────────────────────

func _update_weapon_display() -> void:
	var equipped: Array = GameManager.equipped_run_weapons
	if equipped.is_empty():
		return
	var wid: String = equipped[_active_weapon_idx]
	var wdata: Dictionary = WeaponDB.WEAPONS.get(wid, {})
	_weapon_name_lbl.text = wdata.get("name", wid)
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
	_enemy_name_lbl.position = Vector2(RING_CENTER.x - 110, RING_CENTER.y - 125)
	_ring_container.add_child(_enemy_name_lbl)

	_enemy_hp_bar = _progress_bar(ER_HP)
	_enemy_hp_bar.custom_minimum_size = Vector2(200, 16)
	_enemy_hp_bar.position = Vector2(RING_CENTER.x - 100, RING_CENTER.y - 99)
	_ring_container.add_child(_enemy_hp_bar)

	_enemy_visual = EnemyDisplay.new()
	_enemy_visual.custom_minimum_size = Vector2(130, 150)
	_enemy_visual.position = Vector2(RING_CENTER.x - 65, RING_CENTER.y - 75)
	_ring_container.add_child(_enemy_visual)

	_status_bars_box = HBoxContainer.new()
	_status_bars_box.add_theme_constant_override("separation", 10)
	_status_bars_box.position = Vector2(RING_CENTER.x - 100, RING_CENTER.y + 87)
	_ring_container.add_child(_status_bars_box)

	_enemy_move_lbl = Label.new()
	_enemy_move_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_move_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_enemy_move_lbl.add_theme_font_size_override("font_size", 12)
	_enemy_move_lbl.add_theme_color_override("font_color", Color(0.90, 0.45, 0.30))
	_enemy_move_lbl.custom_minimum_size = Vector2(280, 0)
	_enemy_move_lbl.position = Vector2(RING_CENTER.x - 140, RING_CENTER.y + 103)
	_ring_container.add_child(_enemy_move_lbl)

# ── Step panel — left side (player attack UI) ─────────────────────────────────

func _build_step_panel() -> void:
	_step_panel = PanelContainer.new()
	_step_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_step_panel.offset_left   = 12
	_step_panel.offset_right  = 272
	_step_panel.offset_top    = 96
	_step_panel.offset_bottom = 500
	_step_panel.visible = false
	add_child(_step_panel)

	var m := _margin_container(_step_panel, 6)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)

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
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var m := _margin_container(panel, 28)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	m.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "TASK IN PROGRESS"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	vbox.add_child(hdr)

	vbox.add_child(HSeparator.new())

	_timer_step_lbl = Label.new()
	_timer_step_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_timer_step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_step_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_timer_step_lbl)

	_timer_time_lbl = Label.new()
	_timer_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_time_lbl.add_theme_font_size_override("font_size", 52)
	_timer_time_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	vbox.add_child(_timer_time_lbl)

	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 10)
	_apply_bar_color(_timer_bar, Color(0.90, 0.75, 0.20))
	vbox.add_child(_timer_bar)

	var hint := Label.new()
	hint.text = "Complete the task above — the timer tracks your effort."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel step"
	cancel_btn.pressed.connect(_cancel_step)
	var cbtn_center := CenterContainer.new()
	cbtn_center.add_child(cancel_btn)
	vbox.add_child(cbtn_center)

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

	_equipment_slot(root, Vector2(STEP, 0),              SZ, false)
	_equipment_slot(root, Vector2(0,    STEP),           SZ, false)
	var wslot := _equipment_slot(root, Vector2(2.0 * STEP, STEP), SZ, true)
	_equipment_slot(root, Vector2(STEP, 2.0 * STEP),    SZ, false)

	_weapon_display = WeaponDisplay.new()
	_weapon_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wslot.add_child(_weapon_display)

	_weapon_name_lbl = Label.new()
	_weapon_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_name_lbl.add_theme_font_size_override("font_size", 10)
	_weapon_name_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
	_weapon_name_lbl.position = Vector2(0, content_sz + 3.0)
	_weapon_name_lbl.size     = Vector2(content_sz, 14)
	root.add_child(_weapon_name_lbl)

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
