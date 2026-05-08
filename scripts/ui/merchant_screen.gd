class_name MerchantScreen
extends CanvasLayer

const STOCK_SIZE           := 3      # items shown per day
const PRICE_PER_REQ_POINT  := 55     # runes per stat-requirement point
const MIN_PRICE            := 400    # floor price for any weapon

var _daily_stock: Array = []         # [{weapon_id, price}, ...]

var _runes_lbl: Label
var _stock_box: VBoxContainer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	_build_ui()
	hide()

func show_screen() -> void:
	_generate_daily_stock()
	_refresh_runes()
	_refresh_stock()
	show()

# ── Stock generation (deterministic, seeded by calendar date) ─────────────────

func _generate_daily_stock() -> void:
	var date := Time.get_date_dict_from_system()
	var day_seed: int = date.get("year", 2026) * 10000 \
		+ date.get("month", 1) * 100 \
		+ date.get("day",   1)

	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed

	# All sellable weapons (starter weapon is always free, skip it)
	var candidates: Array = []
	for wid in WeaponDB.WEAPONS:
		if wid != "writers_quill":
			candidates.append(wid)

	# Deterministic Fisher-Yates shuffle using seeded RNG
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	_daily_stock.clear()
	for i in range(mini(STOCK_SIZE, candidates.size())):
		var wid: String = candidates[i]
		_daily_stock.append({
			"weapon_id": wid,
			"price":     _calc_price(WeaponDB.WEAPONS[wid]),
		})

func _calc_price(weapon: Dictionary) -> int:
	var req_sum := 0
	for stat in weapon.get("stat_req", {}):
		req_sum += int(weapon["stat_req"][stat])
	return maxi(MIN_PRICE, req_sum * PRICE_PER_REQ_POINT)

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
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)

	var outer := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	outer.add_child(root)

	# ── Header row ────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "WANDERING MERCHANT"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(hide)
	header.add_child(close_btn)

	# ── Runes + refresh info ──────────────────────────────────────────────────
	var info_row := HBoxContainer.new()
	root.add_child(info_row)

	_runes_lbl = Label.new()
	_runes_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runes_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	info_row.add_child(_runes_lbl)

	var refresh_lbl := Label.new()
	refresh_lbl.text = "Stock refreshes at midnight"
	refresh_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	refresh_lbl.add_theme_font_size_override("font_size", 11)
	refresh_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	info_row.add_child(refresh_lbl)

	root.add_child(HSeparator.new())

	# ── Stock list ────────────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 300
	root.add_child(scroll)

	_stock_box = VBoxContainer.new()
	_stock_box.add_theme_constant_override("separation", 10)
	_stock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stock_box)

# ── Stock display ─────────────────────────────────────────────────────────────

func _refresh_runes() -> void:
	_runes_lbl.text = "Runes: %d" % GameManager.runes

func _refresh_stock() -> void:
	for child in _stock_box.get_children():
		child.queue_free()
	for entry in _daily_stock:
		_build_row(entry.weapon_id, entry.price)

func _build_row(weapon_id: String, price: int) -> void:
	var weapon: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
	if weapon.is_empty():
		return

	var already_owned: bool = GameManager.weapons.has(weapon_id)
	var meets_req: bool     = WeaponDB.meets_requirements(weapon, GameManager.stats)
	var can_afford: bool    = GameManager.runes >= price

	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_box.add_child(row)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	row.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	m.add_child(hbox)

	# Left: weapon info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = weapon.get("name", weapon_id)
	name_lbl.add_theme_font_size_override("font_size", 15)
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = weapon.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62))
	info.add_child(desc_lbl)

	var req: Dictionary = weapon.get("stat_req", {})
	if not req.is_empty():
		var parts: PackedStringArray = []
		for stat in req:
			parts.append("%s %d" % [stat, req[stat]])
		var req_lbl := Label.new()
		req_lbl.text = "Requires: " + "  |  ".join(parts)
		req_lbl.add_theme_font_size_override("font_size", 11)
		req_lbl.add_theme_color_override("font_color",
			Color(0.35, 0.85, 0.35) if meets_req else Color(0.85, 0.35, 0.35))
		info.add_child(req_lbl)

	# Scaling
	var scaling: Dictionary = weapon.get("scaling", {})
	if not scaling.is_empty():
		var sparts: PackedStringArray = []
		for stat in scaling:
			sparts.append("%s: %s" % [stat, scaling[stat]])
		var scale_lbl := Label.new()
		scale_lbl.text = "Scaling: " + "  ".join(sparts)
		scale_lbl.add_theme_font_size_override("font_size", 11)
		scale_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		info.add_child(scale_lbl)

	# Right: price + buy
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(155, 0)
	right.add_theme_constant_override("separation", 6)
	hbox.add_child(right)

	var price_lbl := Label.new()
	price_lbl.text = "%d runes" % price
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 14)
	price_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
	right.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if already_owned:
		buy_btn.text = "Already Owned"
		buy_btn.disabled = true
	elif not meets_req:
		buy_btn.text = "Requirements\nNot Met"
		buy_btn.disabled = true
	elif not can_afford:
		buy_btn.text = "Not Enough\nRunes"
		buy_btn.disabled = true
	else:
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_buy.bind(weapon_id, price))
	right.add_child(buy_btn)

# ── Purchase ──────────────────────────────────────────────────────────────────

func _on_buy(weapon_id: String, price: int) -> void:
	if not GameManager.spend_runes(price):
		return
	if not GameManager.weapons.has(weapon_id):
		GameManager.weapons.append(weapon_id)
	SoundManager.play(SoundManager.Sound.LOOT_DROP)
	SaveManager.save_game()
	_refresh_runes()
	_refresh_stock()

# ── Keyboard ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
