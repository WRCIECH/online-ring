class_name WeaponDB

const _GRADE := { "S": 0.012, "A": 0.010, "B": 0.008, "C": 0.006, "D": 0.004, "E": 0.002 }

const WEAPONS := {
	"writers_quill": {
		"name": "Writer's Quill",
		"description": "The starting weapon. Reliable, if unspectacular.",
		"stat_req": {},
		"scaling": { "STR": "D", "DEX": "D" },
		"moveset": [
			{
				"id": "quick_note",
				"name": "R1 — Quick Note",
				"real_task": "Write 3 bullet points about your current topic or project.",
				"stamina_cost": 15, "fp_cost": 0,
				"base_damage": 18, "poise_damage": 8,
				"scaling_stat": "DEX",
			},
			{
				"id": "focused_write",
				"name": "R2 — Focused Write",
				"real_task": "Write for 20 minutes without switching tabs or checking your phone.",
				"stamina_cost": 30, "fp_cost": 0,
				"base_damage": 35, "poise_damage": 16,
				"scaling_stat": "STR",
			},
		],
	},
	"greatsword": {
		"name": "Greatsword",
		"description": "The Methodical Builder. Slow but devastating.",
		"stat_req": { "STR": 20 },
		"scaling": { "STR": "A", "DEX": "D" },
		"moveset": [
			{
				"id": "mindmap",
				"name": "R1 — Mindmap",
				"real_task": "Create a mindmap of your topic in 10 minutes.",
				"stamina_cost": 18, "fp_cost": 0,
				"base_damage": 30, "poise_damage": 14,
				"scaling_stat": "STR",
			},
			{
				"id": "argument_section",
				"name": "R2 — Argument",
				"real_task": "Write one argumentative section of 300+ words without pausing.",
				"stamina_cost": 40, "fp_cost": 0,
				"base_damage": 55, "poise_damage": 25,
				"scaling_stat": "STR",
			},
			{
				"id": "aow_sword_of_night",
				"name": "AoW — Sword of Night",
				"real_task": "Write the core thesis of your topic from scratch in 15 minutes.",
				"stamina_cost": 0, "fp_cost": 20,
				"base_damage": 70, "poise_damage": 35,
				"scaling_stat": "STR",
			},
		],
	},
	"dagger": {
		"name": "Dagger",
		"description": "The Opportunist. Fast and punishing in quick succession.",
		"stat_req": { "DEX": 12 },
		"scaling": { "DEX": "A", "STR": "E" },
		"moveset": [
			{
				"id": "hook_sentence",
				"name": "R1 — Hook",
				"real_task": "Write 3 different opening sentences for your piece.",
				"stamina_cost": 12, "fp_cost": 0,
				"base_damage": 22, "poise_damage": 10,
				"scaling_stat": "DEX",
			},
			{
				"id": "voice_memo",
				"name": "R2 — Voice Memo",
				"real_task": "Record a 2-minute voice memo talking through your main argument.",
				"stamina_cost": 22, "fp_cost": 0,
				"base_damage": 38, "poise_damage": 16,
				"scaling_stat": "DEX",
			},
		],
	},
}

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
