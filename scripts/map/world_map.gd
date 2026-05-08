class_name WorldMap
extends Node2D

# ── Location data ─────────────────────────────────────────────────────────────
# All Vector2 positions are in viewport pixels (1200×800 reference).
# "connections" lists are one-directional — drawing deduplicates them.

const MAP_DATA := {
	"blank_canvas": {
		"name":            "The Blank Canvas",
		"description":     "Your starting Site of Grace. An empty page, full of potential. Rest here to level up and set your respawn point.",
		"position":        Vector2(160, 420),
		"is_site_of_grace": true,
		"connections":     ["open_feed"],
		"area":            "starting_area",
		"enemy_id":        "",
		"is_boss":         false,
		"is_remembrance":  false,
	},
	"merchants_post": {
		"name":            "Merchant's Post",
		"description":     "A wandering merchant camps here daily. Stock changes at midnight. Good place to spend runes on weapons you haven't found yet.",
		"position":        Vector2(265, 510),
		"is_site_of_grace": false,
		"connections":     ["blank_canvas", "open_feed"],
		"area":            "starting_area",
		"enemy_id":        "",
		"is_boss":         false,
		"is_remembrance":  false,
		"is_merchant":     true,
	},
	"open_feed": {
		"name":            "The Open Feed",
		"description":     "Endless distractions roam freely here. Procrastination Mobs patrol every path. Easy to enter — hard to leave.",
		"position":        Vector2(370, 360),
		"is_site_of_grace": false,
		"connections":     ["blank_canvas", "haters_den", "draft_dungeon"],
		"area":            "starting_area",
		"enemy_id":        "procrastination_mob",
		"is_boss":         false,
		"is_remembrance":  false,
	},
	"haters_den": {
		"name":            "Hater's Den",
		"description":     "Where public criticism nests. A Hater roams within. Defeating it rewards the Bold Rebuttal weapon.",
		"position":        Vector2(470, 560),
		"is_site_of_grace": false,
		"connections":     ["open_feed"],
		"area":            "starting_area",
		"enemy_id":        "hater",
		"is_boss":         true,
		"is_remembrance":  false,
	},
	"draft_dungeon": {
		"name":            "The Draft Dungeon",
		"description":     "A maze of unfinished drafts and abandoned ideas. The Blank Page Omen guards the exit.",
		"position":        Vector2(570, 230),
		"is_site_of_grace": false,
		"connections":     ["open_feed", "grace_of_focus"],
		"area":            "starting_area",
		"enemy_id":        "blank_page_omen",
		"is_boss":         true,
		"is_remembrance":  false,
	},
	"grace_of_focus": {
		"name":            "Grace of Focus",
		"description":     "A rare Site of Grace. Rest here before confronting the Perfectionism Knight in the Tower.",
		"position":        Vector2(770, 210),
		"is_site_of_grace": true,
		"connections":     ["draft_dungeon", "perfectionism_tower"],
		"area":            "starting_area",
		"enemy_id":        "",
		"is_boss":         false,
		"is_remembrance":  false,
	},
	"perfectionism_tower": {
		"name":            "Tower of Perfectionism",
		"description":     "The Perfectionism Knight stands between you and the Momentum Plateau. A Remembrance Boss — defeating it unlocks new territory.",
		"position":        Vector2(950, 195),
		"is_site_of_grace": false,
		"connections":     ["grace_of_focus"],
		"area":            "starting_area",
		"enemy_id":        "perfectionism_knight",
		"is_boss":         true,
		"is_remembrance":  true,
	},
	"momentum_plateau": {
		"name":            "Momentum Plateau",
		"description":     "A vast new territory, earned by overcoming Perfectionism. New enemies, new weapons, new creative challenges.",
		"position":        Vector2(1060, 380),
		"is_site_of_grace": false,
		"connections":     ["perfectionism_tower"],
		"area":            "second_area",
		"enemy_id":        "",
		"is_boss":         false,
		"is_remembrance":  false,
	},
}

# ── References ────────────────────────────────────────────────────────────────

var _map_nodes:   Dictionary = {}  # id -> MapNode
var _selected_id: String = ""

var _level_label: Label
var _runes_label: Label
var _hp_label:    Label

var _info_panel:    PanelContainer
var _info_name:     Label
var _info_desc:     Label
var _info_moveset:  Label
var _info_enter:    Button

var _level_up_screen:  LevelUpScreen
var _equip_screen:     EquipScreen
var _settings_screen:  SettingsScreen
var _merchant_screen:  MerchantScreen
var _ui_layer:         CanvasLayer
var _camera:           Camera2D
var _terrain_texture:  ImageTexture

# ── Pan / zoom state ──────────────────────────────────────────────────────────
var _panning:          bool    = false
var _pan_start_mouse:  Vector2 = Vector2.ZERO
var _pan_start_camera: Vector2 = Vector2.ZERO

const ZOOM_MIN  := 0.35
const ZOOM_MAX  := 2.50
const ZOOM_STEP := 0.04

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if GameManager.current_location.is_empty():
		GameManager.current_location  = "blank_canvas"
		GameManager.last_site_of_grace = "blank_canvas"
	# Starting location is always discovered
	if not GameManager.discovered_locations.has(GameManager.current_location):
		GameManager.discovered_locations.append(GameManager.current_location)

	_camera = Camera2D.new()
	_camera.position = Vector2(500, 380)  # centre view on starting area
	add_child(_camera)

	_generate_terrain()
	_build_ui_layer()
	_build_locations()
	_build_level_up_screen()
	_build_settings_screen()
	_build_merchant_screen()
	_refresh_ui()

	get_viewport().size_changed.connect(queue_redraw)
	GameManager.stats_changed.connect(_refresh_ui)
	GameManager.runes_changed.connect(func(_r: int):
		_refresh_ui()
		_refresh_all_nodes()
	)
	GameManager.hp_changed.connect(func(_h: int, _m: int): _refresh_ui())
	GameManager.location_changed.connect(func(_l: String): _refresh_all_nodes())
	GameManager.player_died.connect(_refresh_all_nodes)

# ── Drawing (background + connection lines) ───────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
				if event.pressed:
					_pan_start_mouse  = event.position
					_pan_start_camera = _camera.position
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_camera.zoom.x + ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_camera.zoom.x - ZOOM_STEP)
	elif event is InputEventMouseMotion and _panning:
		# Divide by zoom so pan speed matches world units at any zoom level
		_camera.position = _pan_start_camera + (event.position - _pan_start_mouse) / _camera.zoom.x
		queue_redraw()

func _set_zoom(z: float) -> void:
	_camera.zoom = Vector2.ONE * clampf(z, ZOOM_MIN, ZOOM_MAX)

# ── Terrain generation ────────────────────────────────────────────────────────

func _generate_terrain() -> void:
	if GameManager.map_seed == 0:
		GameManager.map_seed = randi()
		SaveManager.save_game()

	const GEN_W := 400
	const GEN_H := 300

	# Noise layer 1: elevation (large landmass shapes)
	var elev := FastNoiseLite.new()
	elev.seed              = GameManager.map_seed
	elev.frequency         = 0.0025
	elev.fractal_octaves   = 6
	elev.fractal_lacunarity = 2.0
	elev.fractal_gain      = 0.5

	# Noise layer 2: moisture (forest vs plains variation)
	var moist := FastNoiseLite.new()
	moist.seed             = GameManager.map_seed + 1337
	moist.frequency        = 0.008
	moist.fractal_octaves  = 3

	var img := Image.create(GEN_W, GEN_H, false, Image.FORMAT_RGB8)

	for py in range(GEN_H):
		for px in range(GEN_W):
			# Map pixel to world coordinates covered by the terrain rect
			var wx := -200.0 + (float(px) / GEN_W) * 1600.0
			var wy := -200.0 + (float(py) / GEN_H) * 1200.0

			var e: float = elev.get_noise_2d(wx, wy)
			var m: float = moist.get_noise_2d(wx, wy)

			# Vignette: fade to dark void near texture edges
			var cx := float(px) / GEN_W * 2.0 - 1.0   # -1 to 1
			var cy := float(py) / GEN_H * 2.0 - 1.0
			var dist := sqrt(cx * cx + cy * cy)
			var vig := 1.0 - smoothstep(0.55, 1.05, dist)

			var col := _terrain_color(e, m)
			img.set_pixel(px, py, Color(col.r * vig, col.g * vig, col.b * vig))

	_terrain_texture = ImageTexture.create_from_image(img)
	texture_filter   = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()

func _terrain_color(e: float, m: float) -> Color:
	var d := m * 0.04   # subtle intra-biome detail variation

	if e < -0.30:
		return Color(0.04 + d, 0.09,       0.26 + d)   # deep ocean
	elif e < -0.05:
		return Color(0.07 + d, 0.15,       0.38 + d)   # ocean
	elif e < 0.03:
		return Color(0.30 + d, 0.26,       0.17)        # coast / sand
	elif e < 0.25:
		if m > 0.15:
			return Color(0.07,       0.17 + d, 0.08)    # forest
		else:
			return Color(0.14 + d,   0.26,     0.13)    # plains
	elif e < 0.52:
		return Color(0.23 + d,   0.19,     0.13 + d)    # hills
	elif e < 0.78:
		return Color(0.29 + d,   0.26,     0.22 + d)    # mountains
	else:
		return Color(0.44,       0.42 + d, 0.42)        # snow peaks

func _draw() -> void:
	# 1. Dark void — covers any camera position
	draw_rect(Rect2(Vector2(-10000, -10000), Vector2(22000, 22000)), Color(0.04, 0.03, 0.05))

	# 2. Terrain texture (world rect: -200,-200 to 1400,1000)
	if _terrain_texture:
		draw_texture_rect(_terrain_texture, Rect2(Vector2(-200, -200), Vector2(1600, 1200)), false)

	var drawn: Dictionary = {}
	for id in MAP_DATA:
		var data: Dictionary = MAP_DATA[id]
		var from_pos: Vector2 = data.position
		var from_unlocked := GameManager.unlocked_areas.has(data.area)

		for conn_id in data.connections:
			if not MAP_DATA.has(conn_id):
				continue
			var key: String = str(id) + "|" + str(conn_id) if id < conn_id else str(conn_id) + "|" + str(id)
			if drawn.has(key):
				continue
			drawn[key] = true

			var to_pos: Vector2    = MAP_DATA[conn_id].position
			var to_unlocked := GameManager.unlocked_areas.has(MAP_DATA[conn_id].area)
			var col: Color = GameConstants.COLOR_CONNECTION if (from_unlocked and to_unlocked) else GameConstants.COLOR_CONNECTION_LOCKED
			draw_line(from_pos, to_pos, col, 2.0, true)

# ── UI layer (top bar + info panel) ──────────────────────────────────────────

func _build_ui_layer() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 5
	add_child(_ui_layer)
	var ui: CanvasLayer = _ui_layer

	# Top bar
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 46
	ui.add_child(top)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	top.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	margin.add_child(hbox)

	_level_label = Label.new()
	hbox.add_child(_level_label)

	_runes_label = Label.new()
	hbox.add_child(_runes_label)

	_hp_label = Label.new()
	hbox.add_child(_hp_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.pressed.connect(func(): _settings_screen.show_screen())
	hbox.add_child(settings_btn)

	# Info panel (right side, hidden until a node is clicked)
	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_info_panel.offset_left   = -310
	_info_panel.offset_top    = -215
	_info_panel.offset_bottom =  215
	_info_panel.visible = false
	ui.add_child(_info_panel)

	var im := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		im.add_theme_constant_override("margin_" + side, 16)
	_info_panel.add_child(im)

	var ivbox := VBoxContainer.new()
	ivbox.add_theme_constant_override("separation", 10)
	im.add_child(ivbox)

	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 17)
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	ivbox.add_child(_info_name)

	ivbox.add_child(HSeparator.new())

	_info_desc = Label.new()
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_desc.custom_minimum_size = Vector2(260, 0)
	ivbox.add_child(_info_desc)

	_info_moveset = Label.new()
	_info_moveset.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_moveset.add_theme_font_size_override("font_size", 12)
	_info_moveset.add_theme_color_override("font_color", Color(0.60, 0.58, 0.52))
	_info_moveset.visible = false
	ivbox.add_child(_info_moveset)

	var info_spacer := Control.new()
	info_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ivbox.add_child(info_spacer)

	_info_enter = Button.new()
	_info_enter.pressed.connect(_on_enter_pressed)
	ivbox.add_child(_info_enter)

	_build_legend(ui)

func _build_legend(ui: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_top    = -215
	panel.offset_right  = 218
	panel.offset_bottom = -10
	ui.add_child(panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	m.add_child(vbox)

	var title := Label.new()
	title.text = "LEGEND"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(title)

	_legend_entry(vbox, "●  Site of Grace",      GameConstants.COLOR_SITE_OF_GRACE)
	_legend_entry(vbox, "●  Merchant",           GameConstants.COLOR_MERCHANT)
	_legend_entry(vbox, "●  Enemy area",          GameConstants.COLOR_ENEMY_AREA)
	_legend_entry(vbox, "●  Remembrance Boss",    GameConstants.COLOR_REMEMBRANCE)
	_legend_entry(vbox, "●  Locked area",         GameConstants.COLOR_LOCKED_NODE)
	_legend_entry(vbox, "◉  Current location",    GameConstants.COLOR_CURRENT_LOCATION)
	_legend_entry(vbox, "◎  Lost runes here",     Color(1.0, 0.78, 0.10))
	_legend_entry(vbox, "⊗  Defeated",            Color(0.42, 0.42, 0.42))

func _legend_entry(parent: VBoxContainer, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)

# ── Map nodes ─────────────────────────────────────────────────────────────────

func _build_locations() -> void:
	for id in MAP_DATA:
		var data: Dictionary = MAP_DATA[id]
		var node := MapNode.new()
		node.location_id   = id
		node.location_data = data
		node.position      = data.position
		node.name          = "Loc_" + id
		add_child(node)
		_map_nodes[id] = node
		node.clicked.connect(_on_node_clicked.bind(id))

# ── Level-up screen ───────────────────────────────────────────────────────────

func _build_level_up_screen() -> void:
	_equip_screen = EquipScreen.new()
	add_child(_equip_screen)

	_level_up_screen = LevelUpScreen.new()
	_level_up_screen.equip_screen = _equip_screen
	add_child(_level_up_screen)

func _build_settings_screen() -> void:
	_settings_screen = SettingsScreen.new()
	add_child(_settings_screen)

func _build_merchant_screen() -> void:
	_merchant_screen = MerchantScreen.new()
	add_child(_merchant_screen)

# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_node_clicked(id: String) -> void:
	var data: Dictionary = MAP_DATA[id]

	if not GameManager.unlocked_areas.has(data.area):
		# Show locked feedback instead of silently ignoring the click
		_selected_id = ""
		_info_name.text = data.name
		var blocker := _area_blocker_name(data.area)
		_info_desc.text = "Locked." if blocker.is_empty() \
			else "Locked — defeat %s to unlock this area." % blocker
		_info_moveset.visible = false
		_info_enter.text = "Locked"
		_info_enter.disabled = true
		_info_panel.visible = true
		return

	# Adjacency / discovery gate
	if not _is_accessible(id):
		_selected_id = ""
		_info_name.text = data.name
		_info_desc.text = "Not reachable yet — travel to an adjacent location first."
		_info_moveset.visible = false
		_info_enter.text = "Not Reachable"
		_info_enter.disabled = true
		_info_panel.visible = true
		return

	_selected_id = id
	_info_name.text = data.name
	_info_desc.text = data.description
	_info_enter.disabled = false

	# Show enemy moveset if this location has an enemy (GDD: known upfront)
	var enemy_id: String = data.get("enemy_id", "")
	if not enemy_id.is_empty() and EnemyDB.ENEMIES.has(enemy_id):
		var enemy: Dictionary = EnemyDB.ENEMIES[enemy_id]
		var lines := PackedStringArray(["", "Attacks:"])
		for move in enemy.get("moveset", []):
			lines.append(" • %s — %s" % [move.get("name", ""), move.get("description", "")])
		_info_moveset.text = "\n".join(lines)
		_info_moveset.visible = true
	else:
		_info_moveset.visible = false

	if data.is_site_of_grace:
		_info_enter.text = "Rest at Site of Grace"
	elif data.get("is_merchant", false):
		_info_enter.text = "Browse Wares"
	else:
		_info_enter.text = "Enter Location"
	_info_panel.visible = true

func _is_accessible(id: String) -> bool:
	if GameManager.discovered_locations.has(id):
		return true
	var current := GameManager.current_location
	if current.is_empty():
		return true
	# Adjacent if listed in current location's connections
	if MAP_DATA.get(current, {}).get("connections", []).has(id):
		return true
	# Adjacent if current location is listed in the target's connections
	if MAP_DATA.get(id, {}).get("connections", []).has(current):
		return true
	return false

func _area_blocker_name(area: String) -> String:
	for loc_id in MAP_DATA:
		var loc: Dictionary = MAP_DATA[loc_id]
		if loc.get("is_remembrance", false) and loc.get("unlocks_area", "") == area:
			return loc.name
	return ""

func _on_enter_pressed() -> void:
	if _selected_id.is_empty():
		return
	var data: Dictionary = MAP_DATA[_selected_id]
	GameManager.current_location = _selected_id
	if not GameManager.discovered_locations.has(_selected_id):
		GameManager.discovered_locations.append(_selected_id)
		_refresh_all_nodes()

	if data.is_site_of_grace:
		GameManager.last_site_of_grace = _selected_id
		_info_panel.visible = false
		SoundManager.play(SoundManager.Sound.SITE_OF_GRACE)
		_level_up_screen.show_screen()
	elif data.get("is_merchant", false):
		_info_panel.visible = false
		SoundManager.play(SoundManager.Sound.BUTTON_CLICK)
		_merchant_screen.show_screen()
	else:
		var enemy_id: String = data.get("enemy_id", "")
		if enemy_id.is_empty():
			return
		GameManager.pending_encounter = {
			"enemy_id":   enemy_id,
			"location_id": _selected_id,
		}
		_info_panel.visible = false
		get_tree().change_scene_to_file("res://scenes/combat/combat.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not (event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _info_panel.visible:
		var mouse := get_viewport().get_mouse_position()
		if not _info_panel.get_global_rect().has_point(mouse):
			_info_panel.visible = false

# ── UI refresh ────────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	_level_label.text = "LVL %d"      % GameManager.level
	_runes_label.text = "Runes: %d"   % GameManager.runes
	_hp_label.text    = "HP %d / %d"  % [GameManager.current_hp, GameManager.max_hp]
	queue_redraw()

func _refresh_all_nodes() -> void:
	for node in _map_nodes.values():
		node.refresh_state()
	queue_redraw()
