class_name CombatScene
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const STAGGER_PAUSE    := 1.5
const STA_ROLL         := 15
const STA_BLOCK        := 20
const STA_PARRY        := 25

# Elden Ring stat-bar colours (approximated from screenshots)
const ER_HP  := Color(0.73, 0.06, 0.06)   # deep crimson
const ER_FP  := Color(0.12, 0.27, 0.70)   # royal blue
const ER_STA := Color(0.28, 0.62, 0.18)   # medium green

# Ring-menu geometry (screen-space, 1200×800 reference)
const RING_CENTER := Vector2(600, 490)
const RING_RADIUS := 200.0
const RING_BTN_W  := 158.0
const RING_BTN_H  := 54.0

enum Phase { INIT, PLAYER_ATTACK, TASK_CONFIRM, ENEMY_ATTACK, ENEMY_STAGGERED, VICTORY, DEFEAT }

# ── Combat state ──────────────────────────────────────────────────────────────
var _phase: Phase = Phase.INIT
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

# ── Status effects state ──────────────────────────────────────────────────────
var _enemy_status_buildup: Dictionary = {}  # effect_name -> float buildup
var _rot_turns_remaining: int = 0
var _enemy_skip_turn: bool = false
var _faith_crack: bool = false  # true if incantation used without faith confirmation

# ── UI refs ───────────────────────────────────────────────────────────────────
var _enemy_name_lbl:  Label
var _enemy_hp_bar:    ProgressBar
var _enemy_visual:    EnemyDisplay
var _enemy_move_lbl:  Label
var _log:             RichTextLabel
var _phase_lbl:       Label
var _ring_container:   Control      # holds permanent enemy info + _buttons_container
var _buttons_container: Control     # holds only the transient ring buttons
var _player_hp_bar:   ProgressBar
var _player_sta_bar:  ProgressBar
var _player_fp_bar:   ProgressBar

var _weapon_display:   WeaponDisplay
var _weapon_name_lbl:  Label

var _task_layer:       CanvasLayer
var _task_move_lbl:    Label
var _task_desc_lbl:    Label
var _task_check:       CheckBox
var _task_confirm_btn: Button
var _faith_check_row:  Control   # shown only for incantation moves
var _faith_check:      CheckBox
var _status_bars_box:  HBoxContainer

var _action_popup:    PanelContainer
var _popup_body_lbl:  Label
var _r1_popup_text:   String = ""
var _r2_popup_text:   String = ""
var _legend_atk_grp:  VBoxContainer
var _legend_def_grp:  VBoxContainer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_init_combat()

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
	_enemy_status_buildup = {}
	_rot_turns_remaining  = 0
	_enemy_skip_turn      = false

	_enemy_name_lbl.text = _enemy.name
	_enemy_visual.set_enemy(enemy_id)
	_update_enemy_bars()
	_update_player_bars()

	# Weapon display
	var wid: String = GameManager.equipped_weapon
	var wdata: Dictionary = WeaponDB.WEAPONS.get(wid, WeaponDB.WEAPONS["writers_quill"])
	_weapon_name_lbl.text = wdata.get("name", wid)
	_weapon_display.set_weapon(wid)

	# Build per-move popup texts for the legend rows
	var moveset := WeaponDB.get_moveset(wdata)
	_r1_popup_text = ""
	_r2_popup_text = ""
	if moveset.size() >= 1:
		var m0: Dictionary = moveset[0]
		var c0 := "%d STA" % m0.get("stamina_cost", 0) if m0.get("stamina_cost", 0) > 0 \
				  else "%d FP" % m0.get("fp_cost", 0)
		_r1_popup_text = "LMB  hold 2 s\n%s\n\n%s\n\nCost: %s" % \
				[m0.get("name", ""), m0.get("real_task", ""), c0]
	if moveset.size() >= 2:
		var m1: Dictionary = moveset[1]
		var c1 := "%d STA" % m1.get("stamina_cost", 0) if m1.get("stamina_cost", 0) > 0 \
				  else "%d FP" % m1.get("fp_cost", 0)
		_r2_popup_text = "RMB  hold 2 s\n%s\n\n%s\n\nCost: %s" % \
				[m1.get("name", ""), m1.get("real_task", ""), c1]

	# Recover runes if this is the death location
	var runes_here: int = GameManager.runes_at_death
	if GameManager.recover_runes_at(GameManager.current_location):
		_log_add("You recovered %d runes." % runes_here, Color(1.0, 0.85, 0.2))

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
	_enemy_visual.set_interactive(false)
	_update_legend_visibility()
	match new_phase:
		Phase.PLAYER_ATTACK:
			if _new_round:
				_player_stamina = GameManager.max_stamina
				_new_round = false
				_update_player_bars()
			_show_player_options()

		Phase.ENEMY_ATTACK:
			_new_round = true
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
			# Normal flow
			_choose_enemy_move()
			_show_defense_options()

		Phase.ENEMY_STAGGERED:
			_handle_stagger()

		Phase.VICTORY:
			_handle_victory()

		Phase.DEFEAT:
			_handle_defeat()

# ── Player attack phase ───────────────────────────────────────────────────────

func _show_player_options() -> void:
	_clear_options()
	_enemy_move_lbl.text = ""
	_enemy_visual.set_interactive(true)

func _on_attack_btn(move: Dictionary, weapon: Dictionary) -> void:
	_pending_move   = move
	_pending_weapon = weapon
	_task_move_lbl.text = move.name
	_task_desc_lbl.text = move.real_task
	_task_check.button_pressed = false
	_task_confirm_btn.disabled = true
	_faith_check_row.visible = move.get("is_incantation", false)
	_faith_check.button_pressed = false
	_task_layer.show()
	_phase = Phase.TASK_CONFIRM   # pause timer

func _on_end_turn() -> void:
	_log_add("You hold back, saving stamina.", Color(0.6, 0.6, 0.6))
	_enter_phase(Phase.ENEMY_ATTACK)

func _on_r1_triggered() -> void:
	var weapon: Dictionary = WeaponDB.WEAPONS.get(GameManager.equipped_weapon, WeaponDB.WEAPONS["writers_quill"])
	var moveset := WeaponDB.get_moveset(weapon)
	if moveset.is_empty():
		_enemy_visual.set_interactive(true)
		return
	_try_use_move(moveset[0], weapon)

func _on_r2_triggered() -> void:
	var weapon: Dictionary = WeaponDB.WEAPONS.get(GameManager.equipped_weapon, WeaponDB.WEAPONS["writers_quill"])
	var moveset := WeaponDB.get_moveset(weapon)
	if moveset.size() < 2:
		_log_add("No R2 move for this weapon.", Color(0.6, 0.6, 0.6))
		_enemy_visual.set_interactive(true)
		return
	_try_use_move(moveset[1], weapon)

func _try_use_move(move: Dictionary, weapon: Dictionary) -> void:
	var sta: int = move.get("stamina_cost", 0)
	var fp:  int = move.get("fp_cost", 0)
	if _player_stamina < sta or _player_fp < fp:
		_log_add("Not enough stamina/FP for %s." % move.name, Color(0.9, 0.5, 0.1))
		_enemy_visual.set_interactive(true)
		return
	_on_attack_btn(move, weapon)

func _on_task_check_toggled(checked: bool) -> void:
	_task_confirm_btn.disabled = not checked

func _on_task_confirmed() -> void:
	_task_layer.hide()
	if _pending_move.get("is_incantation", false):
		if _faith_check.button_pressed:
			GameManager.faith_integrity = mini(100, GameManager.faith_integrity + 5)
			_faith_crack = false
		else:
			GameManager.faith_integrity = maxi(0, GameManager.faith_integrity - 10)
			_faith_crack = true
	else:
		_faith_crack = false
	_execute_attack()

func _on_task_back() -> void:
	_task_layer.hide()
	_phase = Phase.PLAYER_ATTACK
	_update_legend_visibility()
	_enemy_visual.set_interactive(true)

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

	# Faith integrity penalty for incantations used without genuine belief
	if _faith_crack:
		var faith_mult: float = maxf(0.3, GameManager.faith_integrity / 100.0)
		dmg = int(dmg * faith_mult)
		_log_add("Faith wavers — incantation at %d%% power." % GameManager.faith_integrity,
			Color(0.65, 0.40, 0.85))
		_faith_crack = false

	_enemy_hp    -= dmg
	_enemy_poise -= pdmg
	_update_enemy_bars()

	SoundManager.play(SoundManager.Sound.HIT)
	_log_add("You use [b]%s[/b] — %d damage!" % [move.name, dmg], Color.WHITE)

	# Status buildup
	var buildup_map: Dictionary = move.get("status_buildup", {})
	for effect in buildup_map:
		var amount: float = float(buildup_map[effect])
		var mult: float = _enemy.get("status_multipliers", {}).get(effect, 1.0)
		_enemy_status_buildup[effect] = _enemy_status_buildup.get(effect, 0.0) + amount * mult
		if _enemy_status_buildup[effect] >= StatusEffects.THRESHOLDS.get(effect, 100.0):
			_trigger_status(effect)
	_update_status_bars()

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
	for m in WeaponDB.get_moveset(weapon_data):
		if _player_stamina >= m.get("stamina_cost", 0) and _player_fp >= m.get("fp_cost", 0):
			can_chain = true
			break

	if can_chain:
		_enter_phase(Phase.PLAYER_ATTACK)   # _new_round=false, no stamina restore
	else:
		_enter_phase(Phase.ENEMY_ATTACK)

# ── Enemy attack phase ────────────────────────────────────────────────────────

func _choose_enemy_move() -> void:
	var moveset: Array = EnemyDB.get_moveset(_enemy)
	_current_enemy_move = moveset[randi() % moveset.size()]
	_enemy_move_lbl.text = _current_enemy_move.name + "\n" + _current_enemy_move.description
	_log_add("The %s uses [b]%s[/b]!" % [_enemy.name, _current_enemy_move.name], Color(0.9, 0.35, 0.25))

func _show_defense_options() -> void:
	_phase_lbl.text = "ENEMY ATTACKS"
	var sta         := _player_stamina
	var guard_break := sta == 0

	var items: Array = [
		{"label": "Roll",  "callback": _on_defense.bind("roll"),  "disabled": guard_break or sta < STA_ROLL},
		{"label": "Block", "callback": _on_defense.bind("block"), "disabled": guard_break or sta < STA_BLOCK},
		{"label": "Parry", "callback": _on_defense.bind("parry"), "disabled": guard_break or sta < STA_PARRY},
		{"label": "Take Hit", "callback": _on_defense.bind("take"), "disabled": false},
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

func _trigger_status(effect: String) -> void:
	_enemy_status_buildup[effect] = 0.0
	var color: Color = StatusEffects.COLORS.get(effect, Color.WHITE)
	match effect:
		"bleed":
			var dmg: int = int(_enemy_max_hp * 0.20)
			_enemy_hp -= dmg
			_log_add("BLEED erupts! Viral spike — %d damage!" % dmg, color)
			SoundManager.play(SoundManager.Sound.HIT)
		"madness":
			var e_dmg: int = int(_enemy_max_hp * 0.15)
			var p_dmg: int = int(GameManager.max_hp * 0.08)
			_enemy_hp -= e_dmg
			_player_hp -= p_dmg
			_update_player_bars()
			_log_add("MADNESS erupts! %d to enemy — and %d reputation damage to you." % [e_dmg, p_dmg], color)
			SoundManager.play(SoundManager.Sound.HIT)
		"frost":
			var dmg: int = int(_enemy_max_hp * 0.18)
			_enemy_hp -= dmg
			_enemy_skip_turn = true
			_log_add("FROST shatters! %d damage — enemy loses their next turn." % dmg, color)
		"scarlet_rot":
			_rot_turns_remaining = 3
			_log_add("SCARLET ROT spreads! Enemy takes 6%% HP for 3 turns.", color)
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
		var color: Color  = StatusEffects.COLORS.get(effect, Color.WHITE)
		var label: String = StatusEffects.LABELS.get(effect, effect)
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
	# Show Scarlet Rot active turns if running
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
	_clear_options()
	_phase_lbl.text = "VICTORY"
	SoundManager.play(SoundManager.Sound.VICTORY)

	var enemy_id: String = GameManager.pending_encounter.get("enemy_id", "")
	var is_first_kill: bool = not GameManager.defeated_enemies.has(enemy_id)

	var runes: int = _enemy.get("rune_reward", 0)
	GameManager.add_runes(runes)
	SoundManager.play(SoundManager.Sound.RUNE_GAIN)
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
				SoundManager.play(SoundManager.Sound.LOOT_DROP)
	return gained

func _handle_defeat() -> void:
	_clear_options()
	_phase_lbl.text = "YOU DIED"
	SoundManager.play(SoundManager.Sound.DEFEAT)
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

# Single button (used for end-state labels like "Return to Map")
func _btn(label: String, callback: Callable, disabled: bool = false) -> void:
	_clear_options()
	var b := Button.new()
	b.text = label
	b.disabled = disabled
	b.custom_minimum_size = Vector2(200, 54)
	b.position = RING_CENTER - Vector2(100, 27)
	b.pressed.connect(callback)
	_buttons_container.add_child(b)

# Ring-menu: items = [{label, callback, disabled?}, ...]
func _populate_ring(items: Array) -> void:
	_clear_options()
	var n := items.size()
	if n == 0:
		return
	for i in range(n):
		var angle := (float(i) / n) * TAU - PI / 2.0   # first item at top
		var center := RING_CENTER + Vector2(cos(angle), sin(angle)) * RING_RADIUS
		var b := Button.new()
		b.text           = items[i].label
		b.disabled       = items[i].get("disabled", false)
		b.custom_minimum_size = Vector2(RING_BTN_W, RING_BTN_H)
		b.position       = center - Vector2(RING_BTN_W, RING_BTN_H) / 2.0
		b.pressed.connect(items[i].callback)
		_buttons_container.add_child(b)

func _update_legend_visibility() -> void:
	var player_turn := _phase in [Phase.PLAYER_ATTACK, Phase.TASK_CONFIRM, Phase.ENEMY_STAGGERED]
	var enemy_turn  := _phase == Phase.ENEMY_ATTACK
	_legend_atk_grp.visible = player_turn
	_legend_def_grp.visible = enemy_turn
	if not player_turn and not enemy_turn:
		_action_popup.visible = false  # clear any open tooltip

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_player_stats()
	_build_ring()            # enemy info lives inside the ring
	_build_equipment_slots() # bottom-left
	_build_log()             # right side
	_build_task_popup()
	_build_action_legend()   # last — popup draws on top of everything

# ── Player stats — upper left (colour-coded strips only, no text) ─────────────

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

# ── Ring menu — centre (enemy info lives here too) ────────────────────────────

func _build_ring() -> void:
	_ring_container = Control.new()
	_ring_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring_container)

	# Dedicated sub-container for transient ring buttons (cleared each turn)
	_buttons_container = Control.new()
	_buttons_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buttons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_container.add_child(_buttons_container)

	# _phase_lbl kept as invisible node — code still writes to it harmlessly
	_phase_lbl = Label.new()
	_phase_lbl.visible = false
	_ring_container.add_child(_phase_lbl)

	# Stack order: name → hp bar → visual → status → move desc
	# Total stack height ≈ 166 px; centred on RING_CENTER.y

	# Visual is centred on RING_CENTER; name + HP bar float above it.
	# Visual: 130 × 150 px → top at RING_CENTER.y - 75
	# HP bar: 16 px + 8 px gap → top at RING_CENTER.y - 99
	# Name:   22 px + 4 px gap → top at RING_CENTER.y - 125

	# ── Enemy name ────────────────────────────────────────────────────────────
	_enemy_name_lbl = Label.new()
	_enemy_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_name_lbl.add_theme_font_size_override("font_size", 16)
	_enemy_name_lbl.custom_minimum_size = Vector2(220, 0)
	_enemy_name_lbl.position = Vector2(RING_CENTER.x - 110, RING_CENTER.y - 125)
	_ring_container.add_child(_enemy_name_lbl)

	# ── Enemy HP bar ──────────────────────────────────────────────────────────
	_enemy_hp_bar = _progress_bar(ER_HP)
	_enemy_hp_bar.custom_minimum_size = Vector2(200, 16)
	_enemy_hp_bar.position = Vector2(RING_CENTER.x - 100, RING_CENTER.y - 99)
	_ring_container.add_child(_enemy_hp_bar)

	# ── Enemy visual — centred on RING_CENTER ────────────────────────────────
	_enemy_visual = EnemyDisplay.new()
	_enemy_visual.custom_minimum_size = Vector2(130, 150)
	_enemy_visual.position = Vector2(RING_CENTER.x - 65, RING_CENTER.y - 75)
	_enemy_visual.r1_triggered.connect(_on_r1_triggered)
	_enemy_visual.r2_triggered.connect(_on_r2_triggered)
	_ring_container.add_child(_enemy_visual)

	# ── Status buildup bars ───────────────────────────────────────────────────
	_status_bars_box = HBoxContainer.new()
	_status_bars_box.add_theme_constant_override("separation", 10)
	_status_bars_box.position = Vector2(RING_CENTER.x - 100, RING_CENTER.y + 87)
	_ring_container.add_child(_status_bars_box)

	# ── Enemy current-move description ────────────────────────────────────────
	_enemy_move_lbl = Label.new()
	_enemy_move_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_move_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_enemy_move_lbl.add_theme_font_size_override("font_size", 12)
	_enemy_move_lbl.add_theme_color_override("font_color", Color(0.90, 0.45, 0.30))
	_enemy_move_lbl.custom_minimum_size = Vector2(280, 0)
	_enemy_move_lbl.position = Vector2(RING_CENTER.x - 140, RING_CENTER.y + 103)
	_ring_container.add_child(_enemy_move_lbl)

# ── Action legend — left side between stat bars and equipment ─────────────────

func _build_action_legend() -> void:
	# ── Shared popup — content + position change per hovered row ─────────────
	# Added before legend so legend draws on top; popup itself is above ring
	# because it's the last child added to the root (after _build_task_popup).
	_action_popup = PanelContainer.new()
	_action_popup.offset_left   = 282
	_action_popup.offset_right  = 632   # 350 px wide
	_action_popup.offset_top    = 96    # overwritten on each hover
	_action_popup.offset_bottom = 276   # 180 px tall — fits attack text
	_action_popup.visible       = false
	_action_popup.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_action_popup)

	var pm := _margin_container(_action_popup, 10)
	_popup_body_lbl = Label.new()
	_popup_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_popup_body_lbl.add_theme_font_size_override("font_size", 11)
	pm.add_child(_popup_body_lbl)

	# ── Compact legend panel ──────────────────────────────────────────────────
	var outer := PanelContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	outer.offset_left   = 12
	outer.offset_right  = 272
	outer.offset_top    = 96
	outer.offset_bottom = 270
	add_child(outer)

	var m := _margin_container(outer, 8)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	m.add_child(vbox)

	var header := Label.new()
	header.text = "ACTIONS"
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.48, 0.45, 0.40))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	# ── Attack group (visible only on player's turn) ──────────────────────────
	_legend_atk_grp = VBoxContainer.new()
	_legend_atk_grp.add_theme_constant_override("separation", 2)
	_legend_atk_grp.visible = false
	vbox.add_child(_legend_atk_grp)

	_legend_row(_legend_atk_grp, "LMB — R1  (hold 2 s)", "_r1_")
	_legend_row(_legend_atk_grp, "RMB — R2  (hold 2 s)", "_r2_")

	# ── Defense group (visible only on enemy's turn) ───────────────────────────
	_legend_def_grp = VBoxContainer.new()
	_legend_def_grp.add_theme_constant_override("separation", 2)
	_legend_def_grp.visible = false
	vbox.add_child(_legend_def_grp)

	# Separator is inside the def group — hidden along with it
	_legend_def_grp.add_child(HSeparator.new())

	_legend_row(_legend_def_grp, "Roll",
		"Roll\n0 damage.   Costs %d STA." % STA_ROLL)
	_legend_row(_legend_def_grp, "Block",
		"Block\nPartial damage.   Costs %d STA." % STA_BLOCK)
	_legend_row(_legend_def_grp, "Parry",
		"Parry\n0 damage.   Costs %d STA.\nCounter window: react just before the hit." % STA_PARRY)
	_legend_row(_legend_def_grp, "Take Hit",
		"Take Hit\nFull damage, no stamina cost.")
	_legend_row(_legend_def_grp, "Flee",
		"Flee\nRetreat from combat — no runes gained.\nNot available against bosses.")

func _legend_row(parent: VBoxContainer, display: String, tip: String) -> void:
	var lbl := Label.new()
	lbl.text = display
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.mouse_entered.connect(func():
		if tip == "_r1_":
			_popup_body_lbl.text = _r1_popup_text
		elif tip == "_r2_":
			_popup_body_lbl.text = _r2_popup_text
		else:
			_popup_body_lbl.text = tip
		var ry := lbl.get_global_rect().position.y
		var ph := 180.0
		ry = minf(ry, 790.0 - ph)
		_action_popup.offset_top    = ry
		_action_popup.offset_bottom = ry + ph
		_action_popup.visible = true
	)
	lbl.mouse_exited.connect(func(): _action_popup.visible = false)
	parent.add_child(lbl)

# ── Battle log — bottom left ──────────────────────────────────────────────────

# ── Weapon panel — bottom left ────────────────────────────────────────────────

func _build_equipment_slots() -> void:
	# Four slots in an Elden Ring-style cross (3×3 grid, centre empty):
	#        [▲ Spell ]
	#  [◄ Left ]   [Weapon ►]
	#        [▼ Estus ]
	const SZ  := 76.0   # slot side length (px) — ~50% more area than before
	const GAP := 10.0   # gap between slots
	const PAD :=  8.0   # panel inner padding
	var STEP  := SZ + GAP   # = 86

	# Grid content: 3*SZ + 2*GAP = 248 wide/tall
	var content_sz := 3.0 * SZ + 2.0 * GAP          # = 248
	var label_h    := 17.0
	var panel_w    := int(2.0 * PAD + content_sz)    # = 264
	var panel_h    := int(2.0 * PAD + content_sz + label_h)  # = 281

	var outer := PanelContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	outer.offset_left   = 10
	outer.offset_right  = 10 + panel_w    # = 274
	outer.offset_bottom = -10
	outer.offset_top    = -10 - panel_h   # = -291
	add_child(outer)

	var m := _margin_container(outer, int(PAD))

	var root := Control.new()
	root.custom_minimum_size = Vector2(content_sz, content_sz + label_h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(root)

	# Spell slot (top centre) — empty
	_equipment_slot(root, Vector2(STEP, 0),              SZ, false)
	# Left-hand slot — empty
	_equipment_slot(root, Vector2(0,    STEP),           SZ, false)
	# Weapon slot (right centre) — active, contains WeaponDisplay
	var wslot := _equipment_slot(root, Vector2(2.0 * STEP, STEP), SZ, true)
	# Consumable / Estus slot (bottom centre) — empty
	_equipment_slot(root, Vector2(STEP, 2.0 * STEP),    SZ, false)

	# Weapon art inside the right slot
	_weapon_display = WeaponDisplay.new()
	_weapon_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wslot.add_child(_weapon_display)

	# Weapon name label below the cross
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
		sbox.border_color = Color(0.68, 0.56, 0.22)   # gold
	else:
		sbox.set_border_width_all(1)
		sbox.border_color = Color(0.22, 0.20, 0.26)   # dim
	slot.add_theme_stylebox_override("panel", sbox)
	parent.add_child(slot)
	return slot

# ── Battle log — right strip ──────────────────────────────────────────────────

func _build_log() -> void:
	var panel := PanelContainer.new()
	# Anchor to right edge, full height
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

	var context := Label.new()
	context.text = "Complete the real-world task below before your attack lands.\nHonour system — the game's power scales with your actual creative output."
	context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context.autowrap_mode = TextServer.AUTOWRAP_WORD
	context.add_theme_font_size_override("font_size", 11)
	context.add_theme_color_override("font_color", Color(0.48, 0.48, 0.48))
	vbox.add_child(context)

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

	# Faith check — only shown for FAI incantations
	_faith_check_row = VBoxContainer.new()
	_faith_check_row.add_theme_constant_override("separation", 6)
	_faith_check_row.visible = false
	vbox.add_child(_faith_check_row)

	var faith_sep := HSeparator.new()
	_faith_check_row.add_child(faith_sep)

	var faith_lbl := Label.new()
	faith_lbl.text = "Faith integrity check:"
	faith_lbl.add_theme_font_size_override("font_size", 12)
	faith_lbl.add_theme_color_override("font_color", Color(0.65, 0.50, 0.85))
	_faith_check_row.add_child(faith_lbl)

	_faith_check = CheckBox.new()
	_faith_check.text = "This genuinely reflects what I believe — not just what's safe or trending."
	_faith_check_row.add_child(_faith_check)

	var faith_hint := Label.new()
	faith_hint.text = "Unchecked: reduced damage + -10 faith integrity. Checked: +5 faith integrity."
	faith_hint.add_theme_font_size_override("font_size", 11)
	faith_hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	_faith_check_row.add_child(faith_hint)

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
