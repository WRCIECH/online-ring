class_name LevelUpScreen
extends CanvasLayer

const STAT_NAMES := {
	"VIG": "Vigor",
	"STR": "Strength",
	"DEX": "Dexterity",
	"INT": "Intelligence",
	"FAI": "Faith",
	"ARC": "Arcane",
}

# Pending stat increases before confirmation
var _pending: Dictionary = {}

# UI references
var _level_label:  Label
var _runes_label:  Label
var _cost_label:   Label
var _stat_rows:    Dictionary = {}  # stat -> {value, bonus, plus, minus}
var _hp_preview:   Label
var _fp_preview:   Label
var _sta_preview:  Label
var _confirm_btn:  Button

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	_build_ui()
	hide()

func show_screen() -> void:
	_pending.clear()
	for stat in STAT_NAMES:
		_pending[stat] = 0
	_refresh()
	show()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SITE OF GRACE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Level + runes row
	var info_row := HBoxContainer.new()
	vbox.add_child(info_row)

	_level_label = Label.new()
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_level_label)

	_runes_label = Label.new()
	_runes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_row.add_child(_runes_label)

	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	vbox.add_child(_cost_label)

	vbox.add_child(HSeparator.new())

	# Column header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var h_stat := Label.new()
	h_stat.text = "STAT"
	h_stat.custom_minimum_size = Vector2(170, 0)
	h_stat.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(h_stat)

	var h_base := Label.new()
	h_base.text = "BASE"
	h_base.custom_minimum_size = Vector2(50, 0)
	h_base.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_base.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(h_base)

	var h_pending := Label.new()
	h_pending.text = "PENDING"
	h_pending.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_pending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_pending.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(h_pending)

	var h_spacer := Control.new()
	h_spacer.custom_minimum_size = Vector2(84, 0)
	header.add_child(h_spacer)

	# Stat rows
	for stat in ["VIG", "STR", "DEX", "INT", "FAI", "ARC"]:
		_build_stat_row(vbox, stat)

	vbox.add_child(HSeparator.new())

	# Derived stats preview
	var derived_row := HBoxContainer.new()
	derived_row.add_theme_constant_override("separation", 0)
	vbox.add_child(derived_row)

	_hp_preview = Label.new()
	_hp_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derived_row.add_child(_hp_preview)

	_fp_preview = Label.new()
	_fp_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fp_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	derived_row.add_child(_fp_preview)

	_sta_preview = Label.new()
	_sta_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sta_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derived_row.add_child(_sta_preview)

	vbox.add_child(HSeparator.new())

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm Level Up"
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(_confirm_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(hide)
	btn_row.add_child(close_btn)

func _build_stat_row(parent: VBoxContainer, stat: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [stat, STAT_NAMES[stat]]
	name_lbl.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.custom_minimum_size = Vector2(50, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	row.add_child(bonus_lbl)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(38, 0)
	minus_btn.pressed.connect(_on_stat_minus.bind(stat))
	row.add_child(minus_btn)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(38, 0)
	plus_btn.pressed.connect(_on_stat_plus.bind(stat))
	row.add_child(plus_btn)

	_stat_rows[stat] = {
		"value": value_lbl,
		"bonus": bonus_lbl,
		"plus":  plus_btn,
		"minus": minus_btn,
	}

# ── Stat pending logic ────────────────────────────────────────────────────────

func _on_stat_plus(stat: String) -> void:
	var next_n := _get_pending_total() + 1
	if _total_rune_cost_for_n_levels(next_n) > GameManager.runes:
		return
	_pending[stat] += 1
	_refresh()

func _on_stat_minus(stat: String) -> void:
	if _pending[stat] <= 0:
		return
	_pending[stat] -= 1
	_refresh()

func _on_confirm_pressed() -> void:
	var total := _get_pending_total()
	if total == 0:
		return
	# Apply each pending level-up in order (cost is recalculated each time by GameManager)
	for stat in ["VIG", "STR", "DEX", "INT", "FAI", "ARC"]:
		for _i in range(_pending[stat]):
			GameManager.level_up(stat)
	_pending.clear()
	for stat in STAT_NAMES:
		_pending[stat] = 0
	SaveManager.save_game()
	_refresh()

# ── Refresh / preview ─────────────────────────────────────────────────────────

func _refresh() -> void:
	var pending_total := _get_pending_total()
	var rune_cost    := _total_rune_cost_for_n_levels(pending_total)
	var runes_after  := GameManager.runes - rune_cost
	var level_after  := GameManager.level + pending_total

	_level_label.text = "Level: %d" % GameManager.level
	_runes_label.text  = "Runes: %s" % _fmt_runes(GameManager.runes)

	if pending_total > 0:
		var next_cost := _rune_cost_at_level(level_after)
		_cost_label.text = "After confirm → Level %d | %s runes left | next: %s" % [
			level_after, _fmt_runes(runes_after), _fmt_runes(next_cost)
		]
	else:
		_cost_label.text = "Next level costs %s runes" % _fmt_runes(_rune_cost_at_level(GameManager.level))

	for stat in _stat_rows:
		var row: Dictionary = _stat_rows[stat]
		row["value"].text  = str(GameManager.stats[stat])
		var p: int = _pending[stat]
		row["bonus"].text  = ("+%d" % p) if p > 0 else ""
		row["minus"].disabled = (p <= 0)

	# Simulate derived stats with pending applied
	var sim := GameManager.stats.duplicate()
	for stat in _pending:
		sim[stat] += _pending[stat]

	_hp_preview.text  = "HP: %d"  % _sim_hp(sim["VIG"])
	_fp_preview.text  = "FP: %d"  % (80 + sim["INT"] * 6 + sim["FAI"] * 5)
	_sta_preview.text = "STA: %d" % (80 + sim["STR"] * 3 + sim["DEX"] * 4)

	_confirm_btn.disabled = (pending_total == 0 or runes_after < 0)

# ── Helper maths ──────────────────────────────────────────────────────────────

func _get_pending_total() -> int:
	var n := 0
	for stat in _pending:
		n += _pending[stat]
	return n

func _total_rune_cost_for_n_levels(n: int) -> int:
	var total := 0
	for i in range(n):
		total += _rune_cost_at_level(GameManager.level + i)
	return total

func _rune_cost_at_level(lvl: int) -> int:
	return max(int(0.02 * pow(lvl, 3) + 3.06 * pow(lvl, 2) + 105.6 * lvl - 895), 100)

func _sim_hp(vig: int) -> int:
	if vig <= 25:
		return 300 + vig * 12
	elif vig <= 40:
		return 600 + (vig - 25) * 18
	else:
		return 870 + (vig - 40) * 8

func _fmt_runes(n: int) -> String:
	# Format with thousands separator
	return "%d" % n
