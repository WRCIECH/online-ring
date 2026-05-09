class_name MovesetDB

# All individual moves keyed by their unique ID.
# Weapons reference these by ID; see WeaponDB.get_moveset().
const MOVES: Dictionary = {
	# ── Writer's Quill ────────────────────────────────────────────────────────
	"quick_note": {
		"id": "quick_note",
		"name": "R1 — Quick Note",
		"real_task": "Write 3 bullet points about your current topic or project.",
		"stamina_cost": 15, "fp_cost": 0,
		"base_damage": 18, "poise_damage": 8,
		"scaling_stat": "DEX",
	},
	"focused_write": {
		"id": "focused_write",
		"name": "R2 — Focused Write",
		"real_task": "Write for 20 minutes without switching tabs or checking your phone.",
		"stamina_cost": 30, "fp_cost": 0,
		"base_damage": 35, "poise_damage": 16,
		"scaling_stat": "STR",
	},

	# ── Greatsword ────────────────────────────────────────────────────────────
	"mindmap": {
		"id": "mindmap",
		"name": "R1 — Mindmap",
		"real_task": "Create a mindmap of your topic in 10 minutes.",
		"stamina_cost": 18, "fp_cost": 0,
		"base_damage": 30, "poise_damage": 14,
		"scaling_stat": "STR",
	},
	"argument_section": {
		"id": "argument_section",
		"name": "R2 — Argument",
		"real_task": "Write one argumentative section of 300+ words without pausing.",
		"stamina_cost": 40, "fp_cost": 0,
		"base_damage": 55, "poise_damage": 25,
		"scaling_stat": "STR",
	},
	"aow_sword_of_night": {
		"id": "aow_sword_of_night",
		"name": "AoW — Sword of Night",
		"real_task": "Write the core thesis of your topic from scratch in 15 minutes.",
		"stamina_cost": 0, "fp_cost": 20,
		"base_damage": 70, "poise_damage": 35,
		"scaling_stat": "STR",
	},

	# ── Dagger ────────────────────────────────────────────────────────────────
	"hook_sentence": {
		"id": "hook_sentence",
		"name": "R1 — Hook",
		"real_task": "Write 3 different opening sentences for your piece.",
		"stamina_cost": 12, "fp_cost": 0,
		"base_damage": 22, "poise_damage": 10,
		"scaling_stat": "DEX",
	},
	"voice_memo": {
		"id": "voice_memo",
		"name": "R2 — Voice Memo",
		"real_task": "Record a 2-minute voice memo talking through your main argument.",
		"stamina_cost": 22, "fp_cost": 0,
		"base_damage": 38, "poise_damage": 16,
		"scaling_stat": "DEX",
	},

	# ── Viral Hook ────────────────────────────────────────────────────────────
	"emotional_story": {
		"id": "emotional_story",
		"name": "R1 — Emotional Story",
		"real_task": "Write 3 emotionally resonant sentences about a real personal experience related to your topic.",
		"stamina_cost": 14, "fp_cost": 0,
		"base_damage": 14, "poise_damage": 7,
		"scaling_stat": "ARC",
		"status_buildup": { "bleed": 28 },
	},
	"niche_discovery": {
		"id": "niche_discovery",
		"name": "R2 — Niche Discovery",
		"real_task": "Find and share one piece of genuinely obscure knowledge your audience almost certainly doesn't know.",
		"stamina_cost": 22, "fp_cost": 0,
		"base_damage": 22, "poise_damage": 10,
		"scaling_stat": "ARC",
		"status_buildup": { "bleed": 42, "frost": 20 },
	},
	"aow_controversy": {
		"id": "aow_controversy",
		"name": "AoW — Controversy Drop",
		"real_task": "Write one genuinely controversial take you actually believe and are prepared to defend publicly.",
		"stamina_cost": 0, "fp_cost": 18,
		"base_damage": 30, "poise_damage": 18,
		"scaling_stat": "ARC",
		"status_buildup": { "madness": 60 },
		"self_risk": true,
	},

	# ── Sacred Seal ───────────────────────────────────────────────────────────
	"community_post": {
		"id": "community_post",
		"name": "R1 — Community Post",
		"real_task": "Publish an unfinished thought or open question and genuinely invite your audience's perspective.",
		"stamina_cost": 12, "fp_cost": 0,
		"base_damage": 14, "poise_damage": 6,
		"scaling_stat": "FAI",
		"is_incantation": false,
	},
	"deep_response": {
		"id": "deep_response",
		"name": "R2 — Deep Response",
		"real_task": "Write a genuinely thoughtful reply to 3 comments or messages from your community today.",
		"stamina_cost": 22, "fp_cost": 0,
		"base_damage": 30, "poise_damage": 15,
		"scaling_stat": "FAI",
		"is_incantation": false,
	},
	"aow_manifesto": {
		"id": "aow_manifesto",
		"name": "AoW — Manifesto",
		"real_task": "Write your core creative manifesto in 200+ words: what you believe, why it matters, who it's for.",
		"stamina_cost": 0, "fp_cost": 30,
		"base_damage": 85, "poise_damage": 42,
		"scaling_stat": "FAI",
		"is_incantation": true,
	},
}

static func get_moveset(ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		if MOVES.has(id):
			result.append(MOVES[id])
	return result
