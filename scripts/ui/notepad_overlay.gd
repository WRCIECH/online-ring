class_name NotepadOverlay
extends CanvasLayer

const NOTES_PATH  := "user://notes.txt"
const SAVE_DELAY  := 1.5   # seconds after last keystroke before auto-saving

var _text_edit:   TextEdit
var _save_timer:  float = 0.0

func _ready() -> void:
	layer = 15
	hide()
	_build_ui()
	if FileAccess.file_exists(NOTES_PATH):
		var f := FileAccess.open(NOTES_PATH, FileAccess.READ)
		if f:
			_text_edit.text = f.get_as_text()
			f.close()

func _process(delta: float) -> void:
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save()

func show_notepad() -> void:
	show()
	_text_edit.grab_focus()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.80)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 580)
	center.add_child(panel)

	var outer := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	outer.add_child(root)

	# ── Top bar ───────────────────────────────────────────────────────────────
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)

	var title := Label.new()
	title.text = "✏  NOTEPAD"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.80, 0.75, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var copy_btn := Button.new()
	copy_btn.text = "Copy All"
	copy_btn.custom_minimum_size = Vector2(100, 30)
	copy_btn.pressed.connect(_on_copy_all)
	top.add_child(copy_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.pressed.connect(_on_close)
	top.add_child(close_btn)

	root.add_child(HSeparator.new())

	# ── Text editor ───────────────────────────────────────────────────────────
	_text_edit = TextEdit.new()
	_text_edit.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_edit.placeholder_text      = "Write your ideas here…"
	_text_edit.wrap_mode             = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_edit.add_theme_font_size_override("font_size", 14)
	_text_edit.text_changed.connect(_on_text_changed)
	root.add_child(_text_edit)

func _on_text_changed() -> void:
	_save_timer = SAVE_DELAY

func _on_copy_all() -> void:
	DisplayServer.clipboard_set(_text_edit.text)

func _on_close() -> void:
	_save()
	hide()

func _save() -> void:
	_save_timer = 0.0
	var f := FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(_text_edit.text)
		f.close()
