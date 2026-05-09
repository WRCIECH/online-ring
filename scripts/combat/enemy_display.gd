class_name EnemyDisplay
extends Control

# Sprite fallback: drop {enemy_id}.png into res://assets/sprites/enemies/
# and it will be used automatically (Kenney RPG Asset Pack works well).

var enemy_id: String = ""

var _sprite: TextureRect

func _ready() -> void:
	_sprite = TextureRect.new()
	_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite.expand_mode  = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.visible = false
	add_child(_sprite)

func set_enemy(id: String) -> void:
	enemy_id = id
	var path := "res://assets/sprites/enemies/%s.png" % id
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.visible = true
	else:
		_sprite.visible = false
	queue_redraw()

# ── Procedural drawing ────────────────────────────────────────────────────────

func _draw() -> void:
	if _sprite and _sprite.visible:
		return
	var cx := size.x * 0.5
	var H  := size.y
	match enemy_id:
		"procrastination_mob":  _proc_mob(cx, H)
		"hater":                _hater(cx, H)
		"blank_page_omen":      _blank_page(cx, H)
		"perfectionism_knight": _knight(cx, H)
		_:                      _generic(cx, H)

# ── Procrastination Mob ───────────────────────────────────────────────────────
# Amorphous blob — big distracted eyes, slumped posture, scattered energy
func _proc_mob(cx: float, H: float) -> void:
	var body  := Color(0.20, 0.28, 0.52)
	var shine := Color(0.30, 0.40, 0.70)
	var white := Color(0.90, 0.90, 0.85)
	var pupil := Color(0.10, 0.10, 0.20)
	var yell  := Color(0.85, 0.78, 0.20)

	# Main blob body
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,      H*0.14),
		Vector2(cx+28,   H*0.24),
		Vector2(cx+36,   H*0.50),
		Vector2(cx+30,   H*0.72),
		Vector2(cx+14,   H*0.84),
		Vector2(cx,      H*0.86),
		Vector2(cx-14,   H*0.84),
		Vector2(cx-30,   H*0.72),
		Vector2(cx-36,   H*0.50),
		Vector2(cx-28,   H*0.24),
	]), body)

	# Sheen highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-10,  H*0.16),
		Vector2(cx+8,   H*0.20),
		Vector2(cx+14,  H*0.34),
		Vector2(cx+4,   H*0.40),
		Vector2(cx-12,  H*0.36),
		Vector2(cx-16,  H*0.24),
	]), shine)

	# Large distracted eyes (looking sideways)
	draw_circle(Vector2(cx-13, H*0.44), 9, white)
	draw_circle(Vector2(cx+13, H*0.44), 9, white)
	draw_circle(Vector2(cx-11, H*0.44), 4, pupil)   # pupils looking left
	draw_circle(Vector2(cx+16, H*0.44), 4, pupil)   # pupils looking right

	# Floating distraction sparks
	var spark_pts := [
		Vector2(cx+38, H*0.30), Vector2(cx-38, H*0.35),
		Vector2(cx+34, H*0.60),
	]
	for sp in spark_pts:
		draw_line(sp, sp + Vector2(5, -5),  yell, 1.5)
		draw_line(sp, sp + Vector2(-4, -6), yell, 1.5)
		draw_line(sp, sp + Vector2(0,  7),  yell, 1.5)

# ── The Hater ─────────────────────────────────────────────────────────────────
# Hooded, angular figure — pointing finger, glowing rage eyes
func _hater(cx: float, H: float) -> void:
	var robe   := Color(0.48, 0.08, 0.08)
	var shadow := Color(0.28, 0.04, 0.04)
	var rage   := Color(0.95, 0.22, 0.10)
	var bone   := Color(0.70, 0.62, 0.52)

	# Robe body (wide, imposing)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-20, H*0.40),
		Vector2(cx+20, H*0.40),
		Vector2(cx+30, H*0.94),
		Vector2(cx-30, H*0.94),
	]), robe)

	# Inner robe shadow
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-6,  H*0.40),
		Vector2(cx+6,  H*0.40),
		Vector2(cx+10, H*0.94),
		Vector2(cx-10, H*0.94),
	]), shadow)

	# Hood (pointed, angular)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,    H*0.04),    # peak
		Vector2(cx+22, H*0.24),   # right shoulder
		Vector2(cx+20, H*0.42),   # right base
		Vector2(cx-20, H*0.42),   # left base
		Vector2(cx-22, H*0.24),   # left shoulder
	]), robe)

	# Face shadow inside hood
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,    H*0.14),
		Vector2(cx+12, H*0.24),
		Vector2(cx+10, H*0.38),
		Vector2(cx,    H*0.39),
		Vector2(cx-10, H*0.38),
		Vector2(cx-12, H*0.24),
	]), shadow)

	# Glowing rage eyes
	draw_circle(Vector2(cx-7,  H*0.28), 5, rage)
	draw_circle(Vector2(cx+7,  H*0.28), 5, rage)
	draw_circle(Vector2(cx-7,  H*0.28), 2, Color(1, 0.8, 0.6))
	draw_circle(Vector2(cx+7,  H*0.28), 2, Color(1, 0.8, 0.6))

	# Pointing arm (right side, extended)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx+20, H*0.48),
		Vector2(cx+20, H*0.58),
		Vector2(cx+46, H*0.54),
		Vector2(cx+46, H*0.50),
	]), bone)
	# Pointing finger
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx+46, H*0.52),
		Vector2(cx+50, H*0.50),
		Vector2(cx+46, H*0.48),
	]), bone)

# ── Blank Page Omen ───────────────────────────────────────────────────────────
# Spectral entity — hollow void eyes, wispy tendrils, drifting presence
func _blank_page(cx: float, H: float) -> void:
	var mist  := Color(0.72, 0.72, 0.78)
	var glow  := Color(0.88, 0.88, 0.95)
	var void_ := Color(0.06, 0.05, 0.10)

	# Main spectral body (tall, wispy)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,    H*0.06),
		Vector2(cx+18, H*0.18),
		Vector2(cx+22, H*0.44),
		Vector2(cx+18, H*0.60),
		Vector2(cx+26, H*0.74),
		Vector2(cx+12, H*0.68),
		Vector2(cx,    H*0.72),
		Vector2(cx-12, H*0.68),
		Vector2(cx-26, H*0.74),
		Vector2(cx-18, H*0.60),
		Vector2(cx-22, H*0.44),
		Vector2(cx-18, H*0.18),
	]), mist)

	# Glow aura (outline effect — lighter inner shape)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,    H*0.10),
		Vector2(cx+12, H*0.20),
		Vector2(cx+14, H*0.44),
		Vector2(cx+10, H*0.58),
		Vector2(cx,    H*0.62),
		Vector2(cx-10, H*0.58),
		Vector2(cx-14, H*0.44),
		Vector2(cx-12, H*0.20),
	]), glow)

	# Hollow void eyes (large, terrifying)
	draw_circle(Vector2(cx-10, H*0.30), 9, void_)
	draw_circle(Vector2(cx+10, H*0.30), 9, void_)
	draw_circle(Vector2(cx-10, H*0.30), 4, mist)
	draw_circle(Vector2(cx+10, H*0.30), 4, mist)

	# Tendrils at bottom
	var tendril_bases := [
		Vector2(cx-18, H*0.68), Vector2(cx, H*0.72), Vector2(cx+18, H*0.68)
	]
	for i in range(3):
		var b: Vector2 = tendril_bases[i]
		var end := b + Vector2((i-1)*8, H*0.18)
		draw_line(b, end, mist, 3.0)
		draw_line(end, end + Vector2(-4, H*0.06), mist, 1.5)
		draw_line(end, end + Vector2(4, H*0.05),  mist, 1.5)

	# Floating page fragment hint
	draw_line(Vector2(cx+24, H*0.22), Vector2(cx+36, H*0.22), glow, 1.0)
	draw_line(Vector2(cx+24, H*0.26), Vector2(cx+34, H*0.26), glow, 1.0)
	draw_line(Vector2(cx+24, H*0.30), Vector2(cx+32, H*0.30), glow, 1.0)

# ── Perfectionism Knight ──────────────────────────────────────────────────────
# Full plate armour — imposing helmet, broad pauldrons, raised fist
func _knight(cx: float, H: float) -> void:
	var iron   := Color(0.28, 0.26, 0.35)
	var steel  := Color(0.42, 0.40, 0.52)
	var accent := Color(0.60, 0.20, 0.80)
	var visor  := Color(0.06, 0.04, 0.12)

	# Left pauldron (wide shoulder plate)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-40, H*0.32),
		Vector2(cx-18, H*0.28),
		Vector2(cx-18, H*0.46),
		Vector2(cx-36, H*0.50),
		Vector2(cx-42, H*0.44),
	]), steel)
	draw_line(Vector2(cx-40, H*0.32), Vector2(cx-18, H*0.28), accent, 1.5)

	# Right pauldron
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx+40, H*0.32),
		Vector2(cx+18, H*0.28),
		Vector2(cx+18, H*0.46),
		Vector2(cx+36, H*0.50),
		Vector2(cx+42, H*0.44),
	]), steel)
	draw_line(Vector2(cx+40, H*0.32), Vector2(cx+18, H*0.28), accent, 1.5)

	# Helmet (dome)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx,    H*0.06),
		Vector2(cx+16, H*0.14),
		Vector2(cx+18, H*0.28),
		Vector2(cx-18, H*0.28),
		Vector2(cx-16, H*0.14),
	]), iron)
	# Helmet highlight
	draw_line(Vector2(cx-10, H*0.08), Vector2(cx-16, H*0.22), steel, 1.5)

	# Visor slit
	draw_line(Vector2(cx-14, H*0.22), Vector2(cx+14, H*0.22), visor, 4.0)
	draw_line(Vector2(cx-12, H*0.26), Vector2(cx+12, H*0.26), visor, 2.0)

	# Gorget (neck guard)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-12, H*0.28),
		Vector2(cx+12, H*0.28),
		Vector2(cx+14, H*0.36),
		Vector2(cx-14, H*0.36),
	]), steel)

	# Chest plate
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-18, H*0.36),
		Vector2(cx+18, H*0.36),
		Vector2(cx+22, H*0.62),
		Vector2(cx-22, H*0.62),
	]), iron)
	draw_line(Vector2(cx, H*0.36), Vector2(cx, H*0.62), steel, 1.0)
	draw_line(Vector2(cx-18, H*0.46), Vector2(cx+18, H*0.46), steel, 1.0)
	draw_line(Vector2(cx-20, H*0.54), Vector2(cx+20, H*0.54), steel, 1.0)

	# Tassets (hip armour)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-22, H*0.62),
		Vector2(cx+22, H*0.62),
		Vector2(cx+26, H*0.78),
		Vector2(cx-26, H*0.78),
	]), steel)

	# Greaves (legs, simplified)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-18, H*0.78),
		Vector2(cx-6,  H*0.78),
		Vector2(cx-6,  H*0.96),
		Vector2(cx-18, H*0.96),
	]), iron)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx+6,  H*0.78),
		Vector2(cx+18, H*0.78),
		Vector2(cx+18, H*0.96),
		Vector2(cx+6,  H*0.96),
	]), iron)

	# Raised gauntlet fist (right)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx+22, H*0.38),
		Vector2(cx+36, H*0.34),
		Vector2(cx+40, H*0.44),
		Vector2(cx+26, H*0.50),
	]), steel)
	draw_line(Vector2(cx+22, H*0.38), Vector2(cx+40, H*0.44), accent, 1.5)

	# Accent trim
	draw_arc(Vector2(cx, H*0.10), H*0.08, PI*0.6, PI*2.4, 20, accent, 1.5)

# ── Generic fallback ──────────────────────────────────────────────────────────
func _generic(cx: float, H: float) -> void:
	var col := Color(0.45, 0.40, 0.50)
	# Simple humanoid silhouette
	draw_circle(Vector2(cx, H*0.16), H*0.10, col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-16, H*0.28),
		Vector2(cx+16, H*0.28),
		Vector2(cx+20, H*0.68),
		Vector2(cx-20, H*0.68),
	]), col)
	draw_line(Vector2(cx-28, H*0.32), Vector2(cx-16, H*0.28), col, 5.0)
	draw_line(Vector2(cx+28, H*0.32), Vector2(cx+16, H*0.28), col, 5.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-14, H*0.68),
		Vector2(cx-4,  H*0.68),
		Vector2(cx-4,  H*0.92),
		Vector2(cx-14, H*0.92),
	]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx+4,  H*0.68),
		Vector2(cx+14, H*0.68),
		Vector2(cx+14, H*0.92),
		Vector2(cx+4,  H*0.92),
	]), col)
