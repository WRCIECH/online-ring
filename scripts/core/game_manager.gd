extends Node

# ── Stats ──────────────────────────────────────────────────────────────────
var stats: Dictionary = {
	"VIG": 10,
	"STR": 10,
	"DEX": 10,
	"INT": 10,
	"FAI": 10,
	"ARC": 10,
}

var level: int = 1
var runes: int = 0
var runes_at_death: int = 0
var death_location: String = ""

# ── Derived stats ───────────────────────────────────────────────────────────
var max_hp: int = 300
var current_hp: int = 300
var max_fp: int = 100
var current_fp: int = 100
var max_stamina: int = 100
var current_stamina: int = 100

# ── World state ─────────────────────────────────────────────────────────────
var current_location: String = ""
var last_site_of_grace: String = ""
var discovered_locations: Array[String] = []
var defeated_enemies: Array[String] = []
var unlocked_areas: Array[String] = ["starting_area"]

# ── Equipment ───────────────────────────────────────────────────────────────
var equipped_weapon: String = "writers_quill"
var equipped_seal: String = ""
var equipped_armor: String = ""
var equipped_talismans: Array[String] = ["", ""]

# ── Inventory ───────────────────────────────────────────────────────────────
var weapons: Array[String] = ["writers_quill"]
var items: Array[Dictionary] = []

# ── Combat ───────────────────────────────────────────────────────────────────
var pending_encounter: Dictionary = {}

# ── FAI / faith system ────────────────────────────────────────────────────────
# 0–100. Drops when player uses incantations without genuine belief.
# Recovers when player confirms faith honestly. Affects FAI incantation damage.
var faith_integrity: int = 100

# ── Signals ─────────────────────────────────────────────────────────────────
signal stats_changed
signal hp_changed(new_hp: int, max_hp: int)
signal fp_changed(new_fp: int, max_fp: int)
signal stamina_changed(new_stamina: int, max_stamina: int)
signal runes_changed(new_runes: int)
signal location_changed(new_location: String)
signal player_died

func _ready() -> void:
	recalculate_derived_stats()

# ── Derived stat computation ─────────────────────────────────────────────────
func recalculate_derived_stats() -> void:
	var vig: int     = stats["VIG"]
	var str_val: int = stats["STR"]
	var dex: int     = stats["DEX"]
	var int_val: int = stats["INT"]
	var fai: int     = stats["FAI"]

	# HP scales steeply with VIG (diminishing returns above 40)
	if vig <= 25:
		max_hp = 300 + vig * 12
	elif vig <= 40:
		max_hp = 600 + (vig - 25) * 18
	else:
		max_hp = 870 + (vig - 40) * 8

	max_fp = 80 + int_val * 6 + fai * 5
	max_stamina = 80 + str_val * 3 + dex * 4

	current_hp = min(current_hp, max_hp)
	current_fp = min(current_fp, max_fp)
	current_stamina = min(current_stamina, max_stamina)

# ── Rune economy ─────────────────────────────────────────────────────────────
func add_runes(amount: int) -> void:
	runes += amount
	runes_changed.emit(runes)

func spend_runes(amount: int) -> bool:
	if runes < amount:
		return false
	runes -= amount
	runes_changed.emit(runes)
	return true

func rune_cost_for_next_level() -> int:
	# Approximates Elden Ring's level cost curve
	var cost := int(0.02 * pow(level, 3) + 3.06 * pow(level, 2) + 105.6 * level - 895)
	return max(cost, 100)

# ── Combat actions ───────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		_on_player_death()

func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)

func spend_fp(amount: int) -> bool:
	if current_fp < amount:
		return false
	current_fp -= amount
	fp_changed.emit(current_fp, max_fp)
	return true

func spend_stamina(amount: int) -> bool:
	if current_stamina < amount:
		return false
	current_stamina -= amount
	stamina_changed.emit(current_stamina, max_stamina)
	return true

func restore_stamina(amount: int) -> void:
	current_stamina = min(max_stamina, current_stamina + amount)
	stamina_changed.emit(current_stamina, max_stamina)

# ── Death ────────────────────────────────────────────────────────────────────
func _on_player_death() -> void:
	runes_at_death = runes
	death_location = current_location
	runes = 0
	runes_changed.emit(runes)
	current_hp = max_hp
	current_location = last_site_of_grace
	location_changed.emit(current_location)
	player_died.emit()

func recover_runes_at(location: String) -> bool:
	if location != death_location or runes_at_death == 0:
		return false
	add_runes(runes_at_death)
	runes_at_death = 0
	death_location = ""
	return true

# ── Leveling ─────────────────────────────────────────────────────────────────
func level_up(stat: String) -> bool:
	if not stats.has(stat):
		return false
	var cost := rune_cost_for_next_level()
	if not spend_runes(cost):
		return false
	stats[stat] += 1
	level += 1
	recalculate_derived_stats()
	stats_changed.emit()
	return true

# ── Save / Load ──────────────────────────────────────────────────────────────
func get_save_data() -> Dictionary:
	return {
		"stats": stats.duplicate(),
		"level": level,
		"runes": runes,
		"runes_at_death": runes_at_death,
		"death_location": death_location,
		"current_hp": current_hp,
		"current_fp": current_fp,
		"current_stamina": current_stamina,
		"current_location": current_location,
		"last_site_of_grace": last_site_of_grace,
		"discovered_locations": discovered_locations.duplicate(),
		"defeated_enemies": defeated_enemies.duplicate(),
		"unlocked_areas": unlocked_areas.duplicate(),
		"equipped_weapon": equipped_weapon,
		"equipped_seal": equipped_seal,
		"equipped_armor": equipped_armor,
		"equipped_talismans": equipped_talismans.duplicate(),
		"weapons": weapons.duplicate(),
		"items": items.duplicate(),
		"faith_integrity": faith_integrity,
	}

func load_save_data(data: Dictionary) -> void:
	stats = data.get("stats", stats)
	level = data.get("level", 1)
	runes = data.get("runes", 0)
	runes_at_death = data.get("runes_at_death", 0)
	death_location = data.get("death_location", "")
	current_location = data.get("current_location", "")
	last_site_of_grace = data.get("last_site_of_grace", "")
	discovered_locations = data.get("discovered_locations", [])
	defeated_enemies = data.get("defeated_enemies", [])
	unlocked_areas = data.get("unlocked_areas", ["starting_area"])
	equipped_weapon = data.get("equipped_weapon", "")
	equipped_seal = data.get("equipped_seal", "")
	equipped_armor = data.get("equipped_armor", "")
	equipped_talismans = data.get("equipped_talismans", ["", ""])
	weapons = data.get("weapons", [])
	items = data.get("items", [])
	faith_integrity = data.get("faith_integrity", 100)
	recalculate_derived_stats()
	current_hp = data.get("current_hp", max_hp)
	current_fp = data.get("current_fp", max_fp)
	current_stamina = data.get("current_stamina", max_stamina)
	stats_changed.emit()
