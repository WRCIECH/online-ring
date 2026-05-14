extends Node

# ── Stats ─────────────────────────────────────────────────────────────────────
# VIG → HP   |   END → Stamina   |   MIND → FP
var stats: Dictionary = { "VIG": 10, "END": 10, "MIND": 10 }
var level: int = 1

# ── Derived stats ─────────────────────────────────────────────────────────────
var max_hp:      int = 300
var current_hp:  int = 300
var max_stamina: int = 130
var current_stamina: int = 130
var max_fp:      int = 140
var current_fp:  int = 140

# ── Run state (reset each run) ────────────────────────────────────────────────
const RUN_DURATION: float = 172800.0   # 48 hours = 2 days

const RUN_ESTUS_MAX: int = 3

var run_active:            bool  = false
var run_location_sequence: Array = []   # Array of {enemy_id, name, mult}, boss last
var run_current_index:     int   = 0
var run_start_time:        float = 0.0
var run_duration_seconds:  float = RUN_DURATION
var run_estus_count:       int   = RUN_ESTUS_MAX
var run_defeated_enemies:  Array[String] = []

# ── Location pool (25 named encounters, shuffled within tiers each run) ───────
const LOCATION_POOL: Array = [
	# Tier 1 — easy  (indices 0–7)
	{"enemy_id": "procrastination_mob", "name": "The Endless Feed",          "mult": 1.00},
	{"enemy_id": "procrastination_mob", "name": "Notification Storm",        "mult": 1.10},
	{"enemy_id": "hater",               "name": "The First Critic",          "mult": 0.65},
	{"enemy_id": "procrastination_mob", "name": "The Research Hole",         "mult": 1.20},
	{"enemy_id": "blank_page_omen",     "name": "The Blank Draft",           "mult": 0.65},
	{"enemy_id": "hater",               "name": "The Comment Section",       "mult": 0.80},
	{"enemy_id": "burnout_shade",       "name": "The Empty Session",         "mult": 1.05},
	{"enemy_id": "burnout_shade",       "name": "The Can't-Start Day",       "mult": 1.15},
	# Tier 2 — medium  (indices 8–15)
	{"enemy_id": "procrastination_mob", "name": "The Planning Loop",         "mult": 1.40},
	{"enemy_id": "blank_page_omen",     "name": "The First Sentence",        "mult": 0.88},
	{"enemy_id": "hater",               "name": "The Algorithm Skeptic",     "mult": 1.00},
	{"enemy_id": "blank_page_omen",     "name": "The Revision Spiral",       "mult": 1.05},
	{"enemy_id": "procrastination_mob", "name": "The Tomorrow Promise",      "mult": 1.60},
	{"enemy_id": "hater",               "name": "The Credibility Challenge", "mult": 1.15},
	{"enemy_id": "comparison_engine",   "name": "The Feed Trap",             "mult": 0.90},
	{"enemy_id": "fear_phantom",        "name": "The Draft You Never Post",  "mult": 0.95},
	# Tier 3 — hard  (indices 16–20)
	{"enemy_id": "hater",               "name": "The Imposter Voice",        "mult": 1.30},
	{"enemy_id": "blank_page_omen",     "name": "The Deleted Draft",         "mult": 1.38},
	{"enemy_id": "hater",               "name": "The Comparison Trap",       "mult": 1.45},
	{"enemy_id": "blank_page_omen",     "name": "The Perfectionism Plateau", "mult": 1.55},
	{"enemy_id": "comparison_engine",   "name": "The Viral Spiral",          "mult": 1.35},
	# Boss — always last, never shuffled  (index 21)
	{"enemy_id": "perfectionism_knight","name": "The Perfectionism Tower",   "mult": 1.00},
]

# ── Weapon progression (persists across runs) ─────────────────────────────────
var owned_weapons:       Array[String]  = ["unarmed"]
var owned_movesets:      Array[String]  = []
var equipped_run_weapons: Array[String] = []        # up to 2, chosen at run start
var weapon_xp:           Dictionary    = {}         # weapon_id → float
var weapon_level:        Dictionary    = {}         # weapon_id → int
var weapon_extra_movesets: Dictionary  = {}         # weapon_id → Array[String]

# ── Run counter (lifetime, persists across runs) ──────────────────────────────
var run_count: int = 0

# ── Combat handoff ────────────────────────────────────────────────────────────
var pending_encounter:   Dictionary = {}
var pending_run_reward:  String     = ""   # moveset id set by combat on boss victory

# ── Signals ───────────────────────────────────────────────────────────────────
signal stats_changed
signal hp_changed(new_hp: int, max_hp: int)
signal fp_changed(new_fp: int, max_fp: int)
signal stamina_changed(new_stamina: int, max_stamina: int)

func _ready() -> void:
	recalculate_derived_stats()

# ── Derived stat computation ──────────────────────────────────────────────────
func recalculate_derived_stats() -> void:
	var vig:  int = stats["VIG"]
	var end_:  int = stats["END"]
	var mind: int = stats["MIND"]

	# HP: same diminishing-returns curve as before, keyed on VIG
	if vig <= 25:
		max_hp = 300 + vig * 12
	elif vig <= 40:
		max_hp = 600 + (vig - 25) * 18
	else:
		max_hp = 870 + (vig - 40) * 8

	max_stamina = 80 + end_ * 5
	max_fp      = 80 + mind * 6

	current_hp      = mini(current_hp,      max_hp)
	current_stamina = mini(current_stamina,  max_stamina)
	current_fp      = mini(current_fp,       max_fp)

# ── Run management ────────────────────────────────────────────────────────────
func start_run(weapons: Array) -> void:
	equipped_run_weapons = weapons.duplicate()
	run_active           = true
	run_current_index    = 0
	run_count           += 1
	run_start_time       = Time.get_unix_time_from_system()
	run_duration_seconds = RUN_DURATION
	run_estus_count      = RUN_ESTUS_MAX
	run_defeated_enemies = []
	current_hp           = max_hp
	current_stamina      = max_stamina
	current_fp           = max_fp

	# Shuffle within each difficulty tier; boss is always last
	var tier1 := LOCATION_POOL.slice(0,  8).duplicate()
	var tier2 := LOCATION_POOL.slice(8,  16).duplicate()
	var tier3 := LOCATION_POOL.slice(16, 21).duplicate()
	tier1.shuffle()
	tier2.shuffle()
	tier3.shuffle()
	run_location_sequence = tier1 + tier2 + tier3 + [LOCATION_POOL[21]]

func advance_run() -> void:
	run_current_index += 1

func current_location_data() -> Dictionary:
	if run_current_index < run_location_sequence.size():
		return run_location_sequence[run_current_index]
	return {}

func current_enemy_id() -> String:
	return current_location_data().get("enemy_id", "")

func is_on_boss() -> bool:
	return run_current_index == run_location_sequence.size() - 1

func end_run_failure() -> void:
	run_active = false

func end_run_victory() -> void:
	run_active = false

func run_elapsed_seconds() -> float:
	if not run_active:
		return 0.0
	return Time.get_unix_time_from_system() - run_start_time

func run_remaining_seconds() -> float:
	return maxf(0.0, run_duration_seconds - run_elapsed_seconds())

func is_run_expired() -> bool:
	return run_active and run_remaining_seconds() <= 0.0

# ── Weapon XP & levelling ─────────────────────────────────────────────────────
func add_weapon_xp(weapon_id: String, amount: float) -> bool:
	if not weapon_xp.has(weapon_id):
		weapon_xp[weapon_id] = 0.0
	weapon_xp[weapon_id] += amount
	return _check_weapon_level_up(weapon_id)

func _check_weapon_level_up(weapon_id: String) -> bool:
	var wdata: Dictionary = WeaponDB.WEAPONS.get(weapon_id, {})
	if wdata.is_empty():
		return false
	var cur_level: int = weapon_level.get(weapon_id, 1)
	var threshold: float = WeaponDB.xp_for_next_level(wdata, cur_level)
	if threshold <= 0.0:
		return false   # already max level
	if weapon_xp.get(weapon_id, 0.0) >= threshold:
		weapon_level[weapon_id] = cur_level + 1
		return true
	return false

func get_weapon_level(weapon_id: String) -> int:
	return weapon_level.get(weapon_id, 1)

func get_weapon_xp(weapon_id: String) -> float:
	return weapon_xp.get(weapon_id, 0.0)

func get_weapon_extra_movesets(weapon_id: String) -> Array:
	return weapon_extra_movesets.get(weapon_id, [])

func set_weapon_extra_movesets(weapon_id: String, ids: Array) -> void:
	weapon_extra_movesets[weapon_id] = ids.duplicate()

# ── HP / Stamina / FP helpers ─────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)

func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)

func spend_stamina(amount: int) -> bool:
	if current_stamina < amount:
		return false
	current_stamina -= amount
	stamina_changed.emit(current_stamina, max_stamina)
	return true

func restore_stamina(amount: int) -> void:
	current_stamina = mini(max_stamina, current_stamina + amount)
	stamina_changed.emit(current_stamina, max_stamina)

func spend_fp(amount: int) -> bool:
	if current_fp < amount:
		return false
	current_fp -= amount
	fp_changed.emit(current_fp, max_fp)
	return true

# ── Post-run levelling (one point per stat, one per completed run) ────────────
func level_up_stat(stat: String) -> bool:
	if not stats.has(stat):
		return false
	stats[stat] += 1
	level += 1
	recalculate_derived_stats()
	stats_changed.emit()
	return true

# ── Save / Load ───────────────────────────────────────────────────────────────
func get_save_data() -> Dictionary:
	return {
		"stats":                  stats.duplicate(),
		"level":                  level,
		"owned_weapons":          owned_weapons.duplicate(),
		"owned_movesets":         owned_movesets.duplicate(),
		"equipped_run_weapons":   equipped_run_weapons.duplicate(),
		"weapon_xp":              weapon_xp.duplicate(),
		"weapon_level":           weapon_level.duplicate(),
		"weapon_extra_movesets":  weapon_extra_movesets.duplicate(),
		"current_hp":             current_hp,
		"current_stamina":        current_stamina,
		"current_fp":             current_fp,
		"run_count":              run_count,
		"run_duration_seconds":   run_duration_seconds,
		"run_estus_count":        run_estus_count,
		"run_active":             run_active,
		"run_location_sequence":  run_location_sequence.duplicate(),
		"run_current_index":      run_current_index,
		"run_start_time":         run_start_time,
		"run_defeated_enemies":   run_defeated_enemies.duplicate(),
	}

func load_save_data(data: Dictionary) -> void:
	stats  = data.get("stats", {"VIG": 10, "END": 10, "MIND": 10})
	level  = data.get("level", 1)
	owned_weapons.assign(data.get("owned_weapons", ["unarmed"]))
	owned_movesets.assign(data.get("owned_movesets", []))
	equipped_run_weapons.assign(data.get("equipped_run_weapons", []))
	weapon_xp              = data.get("weapon_xp", {})
	weapon_level           = data.get("weapon_level", {})
	weapon_extra_movesets  = data.get("weapon_extra_movesets", {})
	run_count              = data.get("run_count", 0)
	run_duration_seconds   = data.get("run_duration_seconds", RUN_DURATION)
	run_estus_count        = data.get("run_estus_count", RUN_ESTUS_MAX)
	run_active             = data.get("run_active", false)
	run_location_sequence.assign(data.get("run_location_sequence", []))
	run_current_index      = data.get("run_current_index", 0)
	run_start_time         = data.get("run_start_time", 0.0)
	run_defeated_enemies.assign(data.get("run_defeated_enemies", []))
	recalculate_derived_stats()
	current_hp      = data.get("current_hp",      max_hp)
	current_stamina = data.get("current_stamina",  max_stamina)
	current_fp      = data.get("current_fp",       max_fp)
	stats_changed.emit()

# ── Hard reset ────────────────────────────────────────────────────────────────
func reset() -> void:
	stats                  = {"VIG": 10, "END": 10, "MIND": 10}
	level                  = 1
	owned_weapons          = ["unarmed"]
	owned_movesets         = []
	equipped_run_weapons   = []
	weapon_xp              = {}
	weapon_level           = {}
	weapon_extra_movesets  = {}
	run_count              = 0
	run_duration_seconds   = RUN_DURATION
	run_estus_count        = RUN_ESTUS_MAX
	run_active             = false
	run_location_sequence  = []
	run_current_index      = 0
	run_start_time         = 0.0
	run_defeated_enemies   = []
	pending_encounter      = {}
	recalculate_derived_stats()
	current_hp      = max_hp
	current_stamina = max_stamina
	current_fp      = max_fp
	stats_changed.emit()
