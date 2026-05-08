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
	"viral_hook": {
		"name": "Viral Hook",
		"description": "The Discovery Engine's weapon. Builds emotional resonance slowly, then erupts. Controversy risks your own reputation.",
		"stat_req": { "ARC": 12 },
		"scaling": { "ARC": "A", "DEX": "D" },
		"moveset": [
			{
				"id": "emotional_story",
				"name": "R1 — Emotional Story",
				"real_task": "Write 3 emotionally resonant sentences about a real personal experience related to your topic.",
				"stamina_cost": 14, "fp_cost": 0,
				"base_damage": 14, "poise_damage": 7,
				"scaling_stat": "ARC",
				"status_buildup": { "bleed": 28 },
			},
			{
				"id": "niche_discovery",
				"name": "R2 — Niche Discovery",
				"real_task": "Find and share one piece of genuinely obscure knowledge your audience almost certainly doesn't know.",
				"stamina_cost": 22, "fp_cost": 0,
				"base_damage": 22, "poise_damage": 10,
				"scaling_stat": "ARC",
				"status_buildup": { "bleed": 42, "frost": 20 },
			},
			{
				"id": "aow_controversy",
				"name": "AoW — Controversy Drop",
				"real_task": "Write one genuinely controversial take you actually believe and are prepared to defend publicly.",
				"stamina_cost": 0, "fp_cost": 18,
				"base_damage": 30, "poise_damage": 18,
				"scaling_stat": "ARC",
				"status_buildup": { "madness": 60 },
				"self_risk": true,
			},
		],
	},
	"sacred_seal": {
		"name": "Sacred Seal",
		"description": "Catalyst for community and ideology. Incantation power scales with faith integrity — weakens when you stop believing what you preach.",
		"stat_req": { "FAI": 12 },
		"scaling": { "FAI": "A", "INT": "D" },
		"moveset": [
			{
				"id": "community_post",
				"name": "R1 — Community Post",
				"real_task": "Publish an unfinished thought or open question and genuinely invite your audience's perspective.",
				"stamina_cost": 12, "fp_cost": 0,
				"base_damage": 14, "poise_damage": 6,
				"scaling_stat": "FAI",
				"is_incantation": false,
			},
			{
				"id": "deep_response",
				"name": "R2 — Deep Response",
				"real_task": "Write a genuinely thoughtful reply to 3 comments or messages from your community today.",
				"stamina_cost": 22, "fp_cost": 0,
				"base_damage": 30, "poise_damage": 15,
				"scaling_stat": "FAI",
				"is_incantation": false,
			},
			{
				"id": "aow_manifesto",
				"name": "AoW — Manifesto",
				"real_task": "Write your core creative manifesto in 200+ words: what you believe, why it matters, who it's for.",
				"stamina_cost": 0, "fp_cost": 30,
				"base_damage": 85, "poise_damage": 42,
				"scaling_stat": "FAI",
				"is_incantation": true,
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
