class_name WeaponDisplay
extends Control

# Sprite fallback: drop a PNG named {weapon_id}.png into
# res://assets/sprites/weapons/ and it will be shown automatically.
# Kenney "Pixel Shmup" or "Weapon Pack" (CC0) work perfectly.

var weapon_id: String = ""

var _sprite: TextureRect

func _ready() -> void:
	_sprite = TextureRect.new()
	_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.visible = false
	add_child(_sprite)

func set_weapon(id: String) -> void:
	weapon_id = id
	var path := "res://assets/sprites/weapons/%s.png" % id
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.visible = true
	else:
		_sprite.visible = false
	queue_redraw()

# ── Procedural drawing ────────────────────────────────────────────────────────

func _draw() -> void:
	if _sprite and _sprite.visible:
		return   # sprite takes over

	# Compress horizontally so portrait weapons don't look wide in a square slot.
	# draw_set_transform scale keeps the centre x fixed while squeezing the arms.
	var sx := 0.72
	var ox := size.x * 0.5 * (1.0 - sx)
	draw_set_transform(Vector2(ox, 0.0), 0.0, Vector2(sx, 1.0))

	var cx := size.x * 0.5
	var H  := size.y

	match weapon_id:
		"unarmed":         _fist(cx, H)
		"writers_quill":   _quill(cx, H)
		"dagger":          _dagger(cx, H)
		"greatsword":      _greatsword(cx, H)
		"viral_hook":      _hook(cx, H)
		"sacred_seal":     _seal(cx, H)
		_:                 _generic(cx, H)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── Unarmed / Fist ───────────────────────────────────────────────────────────
func _fist(cx: float, H: float) -> void:
	var skin  := Color(0.82, 0.68, 0.50)
	var dark  := Color(0.52, 0.38, 0.24)
	var knuck := Color(0.92, 0.78, 0.60)
	var gold  := Color(0.90, 0.75, 0.20)

	# Back fist (left, slightly behind)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 28, H*0.32),
		Vector2(cx - 4,  H*0.32),
		Vector2(cx - 2,  H*0.48),
		Vector2(cx - 4,  H*0.62),
		Vector2(cx - 26, H*0.62),
		Vector2(cx - 30, H*0.48),
	]), dark)
	draw_line(Vector2(cx - 28, H*0.39), Vector2(cx - 4, H*0.39), Color(0.38, 0.25, 0.14), 1.5)

	# Front fist (right, main)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 2,  H*0.26),
		Vector2(cx + 30, H*0.26),
		Vector2(cx + 34, H*0.44),
		Vector2(cx + 30, H*0.60),
		Vector2(cx + 2,  H*0.60),
		Vector2(cx - 2,  H*0.44),
	]), skin)
	# Knuckle highlights
	draw_line(Vector2(cx + 2, H*0.33), Vector2(cx + 30, H*0.33), knuck, 2.0)
	for i in range(4):
		var kx := cx + 4.0 + i * 7.0
		draw_circle(Vector2(kx, H*0.28), 2.5, knuck)
	# Thumb
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 2,  H*0.44),
		Vector2(cx - 14, H*0.36),
		Vector2(cx - 12, H*0.56),
		Vector2(cx,      H*0.60),
	]), skin)

	# Impact lines radiating from the right
	var impact_pts: Array = [
		[Vector2(cx + 38, H*0.18), Vector2(cx + 52, H*0.12)],
		[Vector2(cx + 40, H*0.30), Vector2(cx + 56, H*0.28)],
		[Vector2(cx + 40, H*0.44), Vector2(cx + 56, H*0.46)],
		[Vector2(cx + 36, H*0.56), Vector2(cx + 50, H*0.62)],
	]
	for pts in impact_pts:
		draw_line(pts[0], pts[1], gold, 2.0)

# ── Writers Quill ─────────────────────────────────────────────────────────────
func _quill(cx: float, H: float) -> void:
	var cream   := Color(0.92, 0.88, 0.76)
	var quill_d := Color(0.70, 0.65, 0.50)
	var nib_c   := Color(0.25, 0.20, 0.15)

	# Feather body
	var pts := PackedVector2Array([
		Vector2(cx,       H * 0.06),
		Vector2(cx + 22,  H * 0.20),
		Vector2(cx + 28,  H * 0.45),
		Vector2(cx + 16,  H * 0.60),
		Vector2(cx,       H * 0.64),
		Vector2(cx - 16,  H * 0.60),
		Vector2(cx - 28,  H * 0.45),
		Vector2(cx - 22,  H * 0.20),
	])
	draw_colored_polygon(pts, cream)

	# Feather detail lines
	for i in range(4):
		var t := 0.20 + i * 0.10
		draw_line(Vector2(cx, H * t), Vector2(cx + 26, H * (t - 0.06)), quill_d, 1.0)
		draw_line(Vector2(cx, H * t), Vector2(cx - 26, H * (t - 0.06)), quill_d, 1.0)

	# Central spine
	draw_line(Vector2(cx, H * 0.05), Vector2(cx, H * 0.72), nib_c, 1.5)

	# Nib
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 5, H * 0.64),
		Vector2(cx,     H * 0.80),
		Vector2(cx + 5, H * 0.64),
	]), nib_c)

# ── Dagger ────────────────────────────────────────────────────────────────────
func _dagger(cx: float, H: float) -> void:
	var silver := Color(0.82, 0.82, 0.90)
	var gold   := Color(0.82, 0.68, 0.22)
	var brown  := Color(0.38, 0.24, 0.14)

	# Blade
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,      H * 0.08),
		Vector2(cx - 7,  H * 0.30),
		Vector2(cx - 10, H * 0.48),
		Vector2(cx + 10, H * 0.48),
		Vector2(cx + 7,  H * 0.30),
	]), silver)
	# Fuller (fuller groove line down blade centre)
	draw_line(Vector2(cx, H * 0.12), Vector2(cx, H * 0.44), Color(0.65, 0.65, 0.75), 1.0)

	# Crossguard
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 20, H * 0.48),
		Vector2(cx - 20, H * 0.54),
		Vector2(cx + 20, H * 0.54),
		Vector2(cx + 20, H * 0.48),
	]), gold)

	# Handle
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 5,  H * 0.54),
		Vector2(cx - 5,  H * 0.76),
		Vector2(cx + 5,  H * 0.76),
		Vector2(cx + 5,  H * 0.54),
	]), brown)
	# Wrap lines
	for i in range(3):
		var y := H * (0.58 + i * 0.055)
		draw_line(Vector2(cx - 5, y), Vector2(cx + 5, y), gold, 1.0)

	# Pommel
	draw_circle(Vector2(cx, H * 0.82), 7, gold)

# ── Greatsword ────────────────────────────────────────────────────────────────
func _greatsword(cx: float, H: float) -> void:
	var steel  := Color(0.72, 0.74, 0.86)
	var gold   := Color(0.82, 0.68, 0.22)
	var dark   := Color(0.22, 0.16, 0.12)
	var edge   := Color(0.92, 0.92, 0.96)

	# Blade (long, tapered)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,      H * 0.04),
		Vector2(cx - 9,  H * 0.28),
		Vector2(cx - 14, H * 0.52),
		Vector2(cx + 14, H * 0.52),
		Vector2(cx + 9,  H * 0.28),
	]), steel)
	# Edge highlights
	draw_line(Vector2(cx, H * 0.05), Vector2(cx - 13, H * 0.51), edge, 1.0)
	draw_line(Vector2(cx, H * 0.05), Vector2(cx + 13, H * 0.51), edge, 1.0)
	# Fuller
	draw_line(Vector2(cx, H * 0.08), Vector2(cx, H * 0.48), Color(0.60, 0.62, 0.75), 1.5)

	# Crossguard
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 32, H * 0.52),
		Vector2(cx - 32, H * 0.57),
		Vector2(cx + 32, H * 0.57),
		Vector2(cx + 32, H * 0.52),
	]), gold)
	# Guard detail
	draw_circle(Vector2(cx, H * 0.545), 5, dark)

	# Handle
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 7,  H * 0.57),
		Vector2(cx - 7,  H * 0.76),
		Vector2(cx + 7,  H * 0.76),
		Vector2(cx + 7,  H * 0.57),
	]), dark)
	for i in range(3):
		var y := H * (0.60 + i * 0.055)
		draw_line(Vector2(cx - 7, y), Vector2(cx + 7, y), gold, 1.2)

	# Pommel
	draw_circle(Vector2(cx, H * 0.82), 10, gold)
	draw_circle(Vector2(cx, H * 0.82), 5, dark)

# ── Viral Hook (ARC) ──────────────────────────────────────────────────────────
func _hook(cx: float, H: float) -> void:
	var purple := Color(0.65, 0.18, 0.80)
	var bright := Color(0.82, 0.35, 0.95)
	var dark   := Color(0.22, 0.10, 0.28)

	# Hook arc (the blade)
	draw_arc(Vector2(cx + 16, H * 0.38), H * 0.26,
		PI * 0.55, PI * 1.90, 40, purple, 6.0)

	# Inner highlight arc
	draw_arc(Vector2(cx + 16, H * 0.38), H * 0.21,
		PI * 0.60, PI * 1.80, 32, bright, 1.5)

	# Hook inner tip
	draw_line(
		Vector2(cx - 10, H * 0.18),
		Vector2(cx - 22, H * 0.30),
		bright, 3.0)

	# Handle grip
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 10, H * 0.62),
		Vector2(cx + 10, H * 0.82),
		Vector2(cx + 22, H * 0.82),
		Vector2(cx + 22, H * 0.62),
	]), dark)
	for i in range(4):
		var y := H * (0.64 + i * 0.048)
		draw_line(Vector2(cx + 10, y), Vector2(cx + 22, y), purple, 1.0)

	# Pommel
	draw_circle(Vector2(cx + 16, H * 0.86), 7, purple)

# ── Sacred Seal (FAI) ─────────────────────────────────────────────────────────
func _seal(cx: float, H: float) -> void:
	var gold  := Color(0.90, 0.75, 0.20)
	var dark  := Color(0.12, 0.09, 0.06)
	var shine := Color(1.00, 0.92, 0.55)

	# Outer ring
	draw_arc(Vector2(cx, H * 0.38), H * 0.26, 0, TAU, 48, gold, 4.0)
	# Inner ring
	draw_arc(Vector2(cx, H * 0.38), H * 0.17, 0, TAU, 32, gold, 2.0)
	# Centre dot
	draw_circle(Vector2(cx, H * 0.38), 5, gold)

	# Rune cross
	draw_line(Vector2(cx - H*0.26, H*0.38), Vector2(cx + H*0.26, H*0.38), gold, 1.5)
	draw_line(Vector2(cx, H*0.12),           Vector2(cx, H*0.64),           gold, 1.5)

	# Diagonal accents
	var r := H * 0.20
	for i in range(4):
		var a := PI / 4.0 + i * PI / 2.0
		var inner := Vector2(cos(a) * H*0.17, sin(a) * H*0.17)
		var outer := Vector2(cos(a) * H*0.26, sin(a) * H*0.26)
		draw_line(Vector2(cx, H*0.38) + inner, Vector2(cx, H*0.38) + outer, shine, 1.0)

	# Handle
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 6,  H * 0.64),
		Vector2(cx - 6,  H * 0.84),
		Vector2(cx + 6,  H * 0.84),
		Vector2(cx + 6,  H * 0.64),
	]), gold)
	draw_line(Vector2(cx - 6, H*0.70), Vector2(cx + 6, H*0.70), shine, 1.0)
	draw_line(Vector2(cx - 6, H*0.77), Vector2(cx + 6, H*0.77), shine, 1.0)

	# Pommel
	draw_circle(Vector2(cx, H * 0.88), 8, gold)
	draw_circle(Vector2(cx, H * 0.88), 4, shine)

# ── Generic fallback ──────────────────────────────────────────────────────────
func _generic(cx: float, H: float) -> void:
	var col := Color(0.60, 0.60, 0.65)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,      H * 0.06),
		Vector2(cx - 8,  H * 0.35),
		Vector2(cx - 10, H * 0.52),
		Vector2(cx + 10, H * 0.52),
		Vector2(cx + 8,  H * 0.35),
	]), col)
	draw_line(Vector2(cx - 22, H*0.52), Vector2(cx + 22, H*0.52), col, 5.0)
	draw_rect(Rect2(cx - 5, H*0.52, 10, H*0.30), col.darkened(0.3))
	draw_circle(Vector2(cx, H*0.86), 8, col)
