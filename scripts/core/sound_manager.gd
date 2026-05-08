extends Node

# All sounds are generated procedurally at startup — no external files needed.
# To swap in real audio (e.g. Kenney assets), replace the _streams[Sound.X]
# assignment in _generate_sounds() with:
#   _streams[Sound.HIT] = load("res://assets/sounds/combat/hit.ogg")

enum Sound {
	HIT,
	BLOCK,
	ROLL,
	PARRY,
	STAGGER,
	VICTORY,
	DEFEAT,
	BUTTON_CLICK,
	LEVEL_UP,
	SITE_OF_GRACE,
	RUNE_GAIN,
	LOOT_DROP,
}

const SAMPLE_RATE := 22050
const POOL_SIZE   := 8

var _streams: Dictionary = {}     # Sound → AudioStreamWAV
var _pool:    Array      = []     # AudioStreamPlayer pool

func _ready() -> void:
	_generate_sounds()
	_init_pool()

# ── Public ────────────────────────────────────────────────────────────────────

func play(sound: Sound, volume_db: float = 0.0) -> void:
	var stream = _streams.get(sound)
	if stream == null:
		return
	var player: AudioStreamPlayer = _next_player()
	player.stream    = stream
	player.volume_db = volume_db
	player.play()

# ── Pool ──────────────────────────────────────────────────────────────────────

func _init_pool() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func _next_player() -> AudioStreamPlayer:
	for p in _pool:
		if not (p as AudioStreamPlayer).playing:
			return p
	return _pool[0]  # steal the oldest if all busy

# ── Sound catalogue ───────────────────────────────────────────────────────────

func _generate_sounds() -> void:
	_streams[Sound.HIT]           = _tone(240.0,  0.10, 0.70)
	_streams[Sound.BLOCK]         = _tone(100.0,  0.18, 0.60)
	_streams[Sound.ROLL]          = _sweep(700.0, 200.0, 0.13, 0.45)
	_streams[Sound.PARRY]         = _tone(1200.0, 0.07, 0.65)
	_streams[Sound.STAGGER]       = _tone(130.0,  0.28, 0.60)
	_streams[Sound.VICTORY]       = _arpeggio([523, 659, 784, 1047],       0.13, 0.50)
	_streams[Sound.DEFEAT]        = _arpeggio([400, 320, 240, 160],        0.18, 0.45)
	_streams[Sound.BUTTON_CLICK]  = _tone(900.0,  0.035, 0.30)
	_streams[Sound.LEVEL_UP]      = _arpeggio([523, 659, 784, 988, 1047],  0.09, 0.50)
	_streams[Sound.SITE_OF_GRACE] = _tone(528.0,  0.80, 0.40)
	_streams[Sound.RUNE_GAIN]     = _arpeggio([880, 1109, 1318],           0.07, 0.40)
	_streams[Sound.LOOT_DROP]     = _arpeggio([660, 831, 1047],            0.11, 0.45)

# ── Synthesis helpers ─────────────────────────────────────────────────────────

func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format   = AudioStreamWAV.FORMAT_16_BITS
	s.stereo   = false
	s.mix_rate = SAMPLE_RATE
	s.data     = data
	return s

func _tone(freq: float, duration: float, vol: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t   := float(i) / float(n)
		var env := pow(1.0 - t, 0.4)
		var s   := int(sin(TAU * freq * float(i) / SAMPLE_RATE) * env * vol * 32767.0)
		data.encode_s16(i * 2, clampi(s, -32768, 32767))
	return _make_wav(data)

func _sweep(freq_a: float, freq_b: float, duration: float, vol: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t  := float(i) / float(n)
		phase  += TAU * lerpf(freq_a, freq_b, t) / SAMPLE_RATE
		var s  := int(sin(phase) * (1.0 - t) * vol * 32767.0)
		data.encode_s16(i * 2, clampi(s, -32768, 32767))
	return _make_wav(data)

func _arpeggio(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var note_n := int(SAMPLE_RATE * note_dur)
	var total  := note_n * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	for fi in range(freqs.size()):
		var freq: float = float(freqs[fi])
		for i in range(note_n):
			var t  := float(i) / float(note_n)
			var env := pow(1.0 - t, 0.5)
			var s  := int(sin(TAU * freq * float(i) / SAMPLE_RATE) * env * vol * 32767.0)
			data.encode_s16((fi * note_n + i) * 2, clampi(s, -32768, 32767))
	return _make_wav(data)
