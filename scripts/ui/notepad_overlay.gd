class_name NotepadOverlay
extends CanvasLayer

const SAVE_DELAY := 1.5

const TABS: Array = ["Draft", "Ideas", "Outline", "Research"]
const TAB_PATHS: Dictionary = {
	"Draft":    "user://notes.txt",
	"Ideas":    "user://notes_ideas.txt",
	"Outline":  "user://notes_outline.txt",
	"Research": "user://notes_research.txt",
}
const TAB_HINTS: Dictionary = {
	"Draft":    "Write your piece here…",
	"Ideas":    "Dump raw ideas — no filter…",
	"Outline":  "Structure, sections, beats…",
	"Research": "Facts, references, quotes…",
}

var _text_edit:   TextEdit
var _save_timer:  float  = 0.0
var _active_tab:  String = "Draft"
var _tab_btns:    Dictionary = {}

func _ready() -> void:
	layer = 15
	hide()
	_build_ui()
	_load_tab(_active_tab)

func _process(delta: float) -> void:
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save()

func show_notepad() -> void:
	if _save_timer > 0.0:
		_save()
	_load_tab(_active_tab)
	show()
	_text_edit.grab_focus()

func _exit_tree() -> void:
	if _save_timer > 0.0:
		_save()

# ── Tab management ────────────────────────────────────────────────────────────

func _switch_tab(tab: String) -> void:
	if _save_timer > 0.0:
		_save()
	_active_tab = tab
	_load_tab(tab)
	_update_tab_buttons()
	_text_edit.placeholder_text = TAB_HINTS.get(tab, "Write here…")
	_text_edit.grab_focus()

func _load_tab(tab: String) -> void:
	var path: String = TAB_PATHS.get(tab, "user://notes.txt")
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			_text_edit.text = f.get_as_text()
			f.close()
	else:
		_text_edit.text = ""

func _update_tab_buttons() -> void:
	for tab in _tab_btns:
		var btn: Button = _tab_btns[tab]
		btn.button_pressed = (tab == _active_tab)

# ── Persistence ───────────────────────────────────────────────────────────────

func _save() -> void:
	_save_timer = 0.0
	var path: String = TAB_PATHS.get(_active_tab, "user://notes.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(_text_edit.text)
		f.close()

func _on_text_changed() -> void:
	_save_timer = SAVE_DELAY

func _on_copy_all() -> void:
	DisplayServer.clipboard_set(_text_edit.text)

func _on_close() -> void:
	_save()
	hide()

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.80)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 620)
	center.add_child(panel)

	var outer := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	outer.add_child(root)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "✏  NOTEPAD"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.80, 0.75, 0.55))
	root.add_child(title)

	# ── Tab bar ───────────────────────────────────────────────────────────────
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	root.add_child(tab_bar)

	for tab in TABS:
		var btn := Button.new()
		btn.text = tab
		btn.toggle_mode = true
		btn.button_pressed = (tab == _active_tab)
		btn.custom_minimum_size = Vector2(90, 30)
		btn.add_theme_font_size_override("font_size", 13)
		var captured: String = tab
		btn.pressed.connect(func(): _switch_tab(captured))
		tab_bar.add_child(btn)
		_tab_btns[tab] = btn

	root.add_child(HSeparator.new())

	# ── Text editor ───────────────────────────────────────────────────────────
	_text_edit = TextEdit.new()
	_text_edit.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_edit.placeholder_text      = TAB_HINTS.get(_active_tab, "Write here…")
	_text_edit.wrap_mode             = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_edit.add_theme_font_size_override("font_size", 14)
	_text_edit.text_changed.connect(_on_text_changed)
	root.add_child(_text_edit)

	root.add_child(HSeparator.new())

	# ── Bottom bar ────────────────────────────────────────────────────────────
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var copy_btn := Button.new()
	copy_btn.text = "Copy Tab"
	copy_btn.custom_minimum_size = Vector2(100, 30)
	copy_btn.pressed.connect(_on_copy_all)
	bottom.add_child(copy_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.pressed.connect(_on_close)
	bottom.add_child(close_btn)
