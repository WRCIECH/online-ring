class_name WeaponDB

const _GRADE := { "S": 0.012, "A": 0.010, "B": 0.008, "C": 0.006, "D": 0.004, "E": 0.002 }

const WEAPONS := {
	"writers_quill": {
		"name": "Writer's Quill",
		"description": "The starting weapon. Reliable, if unspectacular.",
		"stat_req": {},
		"scaling": { "STR": "D", "DEX": "D" },
		"moveset": ["quick_note", "focused_write"],
	},
	"greatsword": {
		"name": "Greatsword",
		"description": "The Methodical Builder. Slow but devastating.",
		"stat_req": { "STR": 20 },
		"scaling": { "STR": "A", "DEX": "D" },
		"moveset": ["mindmap", "argument_section", "aow_sword_of_night"],
	},
	"dagger": {
		"name": "Dagger",
		"description": "The Opportunist. Fast and punishing in quick succession.",
		"stat_req": { "DEX": 12 },
		"scaling": { "DEX": "A", "STR": "E" },
		"moveset": ["hook_sentence", "voice_memo"],
	},
	"viral_hook": {
		"name": "Viral Hook",
		"description": "The Discovery Engine's weapon. Builds emotional resonance slowly, then erupts. Controversy risks your own reputation.",
		"stat_req": { "ARC": 12 },
		"scaling": { "ARC": "A", "DEX": "D" },
		"moveset": ["emotional_story", "niche_discovery", "aow_controversy"],
	},
	"sacred_seal": {
		"name": "Sacred Seal",
		"description": "Catalyst for community and ideology. Incantation power scales with faith integrity — weakens when you stop believing what you preach.",
		"stat_req": { "FAI": 12 },
		"scaling": { "FAI": "A", "INT": "D" },
		"moveset": ["community_post", "deep_response", "aow_manifesto"],
	},
}

static func get_moveset(weapon: Dictionary) -> Array:
	return MovesetDB.get_moveset(weapon.get("moveset", []))

static func calc_damage(move: Dictionary, weapon: Dictionary, stats: Dictionary) -> int:
	var base: int = move.get("base_damage", 0)
	var stat_key: String = move.get("scaling_stat", "STR")
	var grade: String = weapon.get("scaling", {}).get(stat_key, "E")
	var stat_val: int = stats.get(stat_key, 10)
	return int(base * (1.0 + stat_val * _GRADE.get(grade, 0.002)))

static func meets_requirements(weapon: Dictionary, stats: Dictionary) -> bool:
	for stat in weapon.get("stat_req", {}):
		if stats.get(stat, 0) < weapon["stat_req"][stat]:
			return false
	return true
