class_name WeaponDB

const _GRADE := { "S": 0.012, "A": 0.010, "B": 0.008, "C": 0.006, "D": 0.004, "E": 0.002 }

# constant_movesets  — always available, never consume a slot
# moveset_slots      — number of extra slots (grows with weapon level)
# xp_thresholds      — cumulative XP to reach levels 2, 3, 4, 5
# XP per step = step.time / 10

const WEAPONS := {
	"unarmed": {
		"name":              "Fist",
		"description":       "Raw output — no tools, no excuses.",
		"stat_req":          {},
		"scaling":           {"END": "D", "VIG": "E"},
		"constant_movesets": ["starter_chain", "no_backspace"],
		"moveset_slots":     1,
		"xp_thresholds":    [100, 300, 700, 1500],
		"defense_movesets":  {"block": "unarmed_block", "parry": "unarmed_parry"},
	},
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Returns all moveset dicts available for this weapon, including equipped extras.
# extra_ids: list of moveset ids currently slotted by the player for this weapon.
static func get_moveset(weapon: Dictionary, extra_ids: Array = []) -> Array:
	var ids: Array = weapon.get("constant_movesets", []).duplicate()
	for eid in extra_ids:
		ids.append(eid)
	return MovesetDB.get_moveset(ids)

# Damage for a single step, scaled by the moveset's stat.
static func calc_step_damage(step: Dictionary, moveset: Dictionary, weapon: Dictionary, stats: Dictionary) -> int:
	var base: int     = step.get("base_damage", 0)
	var stat_key: String = moveset.get("scaling_stat", "END")
	var grade: String = weapon.get("scaling", {}).get(stat_key, "E")
	var stat_val: int = stats.get(stat_key, 10)
	return int(base * (1.0 + stat_val * _GRADE.get(grade, 0.002)))

static func meets_requirements(weapon: Dictionary, stats: Dictionary) -> bool:
	for stat in weapon.get("stat_req", {}):
		if stats.get(stat, 0) < weapon["stat_req"][stat]:
			return false
	return true

# Current number of extra slots (base + bonus from weapon level).
static func effective_slots(weapon: Dictionary, weapon_level: int) -> int:
	return weapon.get("moveset_slots", 0) + maxi(0, weapon_level - 1)

# XP threshold to reach the next level (0 if already at max).
static func xp_for_next_level(weapon: Dictionary, current_level: int) -> float:
	var thresholds: Array = weapon.get("xp_thresholds", [])
	var idx := current_level - 1   # level 1 → idx 0 → threshold to reach level 2
	if idx < 0 or idx >= thresholds.size():
		return 0.0
	return float(thresholds[idx])

static func max_level(weapon: Dictionary) -> int:
	return weapon.get("xp_thresholds", []).size() + 1
