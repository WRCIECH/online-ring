class_name EstusDisplay
extends Control

var count: int = 0

func set_count(n: int) -> void:
	count = n
	queue_redraw()

func _draw() -> void:
	if count <= 0:
		return

	var w  := size.x
	var h  := size.y
	var cx := w * 0.5

	var body  := Color(0.72, 0.42, 0.05)
	var neck  := Color(0.58, 0.33, 0.04)
	var shine := Color(0.90, 0.70, 0.20, 0.50)

	# Body
	var bt := h * 0.28
	var bh := h * 0.50
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w*0.28, bt),
		Vector2(cx + w*0.28, bt),
		Vector2(cx + w*0.33, bt + bh*0.3),
		Vector2(cx + w*0.36, bt + bh*0.7),
		Vector2(cx + w*0.28, bt + bh),
		Vector2(cx,           bt + bh + h*0.03),
		Vector2(cx - w*0.28, bt + bh),
		Vector2(cx - w*0.36, bt + bh*0.7),
		Vector2(cx - w*0.33, bt + bh*0.3),
	]), body)

	# Neck
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w*0.12, h*0.08),
		Vector2(cx + w*0.12, h*0.08),
		Vector2(cx + w*0.15, bt),
		Vector2(cx - w*0.15, bt),
	]), neck)

	# Cork
	draw_rect(Rect2(cx - w*0.16, h*0.02, w*0.32, h*0.08), Color(0.45, 0.30, 0.12))

	# Shine
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w*0.20, bt + h*0.03),
		Vector2(cx - w*0.08, bt + h*0.03),
		Vector2(cx - w*0.06, bt + h*0.16),
		Vector2(cx - w*0.18, bt + h*0.16),
	]), shine)

	# Liquid surface line
	draw_line(
		Vector2(cx - w*0.24, bt + bh*0.22),
		Vector2(cx + w*0.24, bt + bh*0.22),
		Color(1.0, 0.82, 0.28, 0.55), 1.5)

	# Count number below flask
	var font      := ThemeDB.fallback_font
	var font_size := 16
	var count_str := "×%d" % count
	var text_w    := font.get_string_size(count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font,
		Vector2(cx - text_w * 0.5, h * 0.95),
		count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(1.0, 0.90, 0.40, 0.95))
