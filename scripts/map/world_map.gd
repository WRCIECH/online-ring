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
var _info_enter:    Button

var _level_up_screen: LevelUpScreen
var _equip_screen:    EquipScreen

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if GameManager.current_location.is_empty():
		GameManager.current_location  = "blank_canvas"
		GameManager.last_site_of_grace = "blank_canvas"

	_build_ui_layer()
	_build_locations()
	_build_level_up_screen()
	_refresh_ui()

	get_viewport().size_changed.connect(queue_redraw)
	GameManager.stats_changed.connect(_refresh_ui)
	GameManager.runes_changed.connect(func(_r: int): _refresh_ui())
	GameManager.hp_changed.connect(func(_h: int, _m: int): _refresh_ui())
	GameManager.location_changed.connect(func(_l: String): _refresh_all_nodes())

# ── Drawing (background + connection lines) ───────────────────────────────────

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), GameConstants.COLOR_MAP_BG)

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
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)

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

	# Info panel (right side, hidden until a node is clicked)
	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_info_panel.offset_left   = -310
	_info_panel.offset_top    = -170
	_info_panel.offset_bottom =  170
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

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ivbox.add_child(spacer)

	_info_enter = Button.new()
	_info_enter.pressed.connect(_on_enter_pressed)
	ivbox.add_child(_info_enter)

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

# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_node_clicked(id: String) -> void:
	var data: Dictionary = MAP_DATA[id]
	if not GameManager.unlocked_areas.has(data.area):
		return

	_selected_id = id
	_info_name.text = data.name
	_info_desc.text = data.description
	_info_enter.text = "Rest at Site of Grace" if data.is_site_of_grace else "Enter Location"
	_info_panel.visible = true

func _on_enter_pressed() -> void:
	if _selected_id.is_empty():
		return
	var data: Dictionary = MAP_DATA[_selected_id]
	GameManager.current_location = _selected_id

	if data.is_site_of_grace:
		GameManager.last_site_of_grace = _selected_id
		_info_panel.visible = false
		_level_up_screen.show_screen()
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
