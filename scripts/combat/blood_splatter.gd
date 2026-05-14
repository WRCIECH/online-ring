class_name BloodSplatter
extends Control

var _age: float = 0.0
const ANIM_DUR := 1.0

func reset() -> void:
	_age = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if _age < ANIM_DUR:
		_age = minf(_age + delta, ANIM_DUR)
		queue_redraw()

func _draw() -> void:
	var t := _age / ANIM_DUR
	if t <= 0.0:
		return
	var cx := size.x * 0.5
	var cy := size.y * 0.76

	var blood := Color(0.40, 0.01, 0.01)
	var dark  := Color(0.18, 0.005, 0.005)

	# Expanding main pool
	var r := 78.0 * t
	draw_circle(Vector2(cx, cy), r,        Color(blood.r, blood.g, blood.b, 0.82 * t))
	draw_circle(Vector2(cx, cy), r * 0.55, Color(dark.r,  dark.g,  dark.b, 0.92 * t))

	# Scatter drops — each pops at a different threshold  [x, y, radius, t0]
	var drops: Array = [
		[cx - 52, cy - 20, 8.0, 0.15],
		[cx + 50, cy - 16, 6.0, 0.25],
		[cx - 30, cy + 42, 7.0, 0.10],
		[cx + 66, cy + 14, 5.0, 0.38],
		[cx - 68, cy +  8, 6.0, 0.30],
		[cx +  6, cy + 56, 5.0, 0.20],
		[cx - 18, cy - 44, 4.0, 0.42],
	]
	for d in drops:
		var t0: float = d[3]
		if t > t0:
			var dt := minf((t - t0) / 0.28, 1.0)
			draw_circle(Vector2(d[0], d[1]), d[2] * dt,
				Color(blood.r, blood.g, blood.b, 0.68 * dt))
