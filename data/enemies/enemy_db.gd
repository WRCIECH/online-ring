class_name EnemyDB

# "drops" entries: first_kill_chance = probability on first defeat,
#                  repeat_chance     = probability on subsequent defeats.
# Weapons already owned are skipped silently.

const ENEMIES := {
	"procrastination_mob": {
		"name": "Procrastination Mob",
		"description": "A common distraction. Weak alone, draining in groups.",
		"max_hp": 80,
		"initiative": 6,
		"max_poise": 20,
		"rune_reward": 50,
		"is_boss": false,
		"drops": [],
		"status_multipliers": { "bleed": 1.5, "frost": 1.2 },
		"moveset": ["mindless_scroll", "shiny_object"],
	},
	"hater": {
		"name": "The Hater",
		"description": "A manifestation of public online criticism.",
		"max_hp": 180,
		"initiative": 8,
		"max_poise": 40,
		"rune_reward": 150,
		"is_boss": true,
		"drops": [
			# Dagger: reward for learning to fight back fast and sharp
			{"id": "dagger", "first_kill_chance": 1.0, "repeat_chance": 0.0},
		],
		"status_multipliers": { "madness": 1.4, "bleed": 0.8 },
		"moveset": ["public_criticism", "mockery", "credibility_slash"],
	},
	"blank_page_omen": {
		"name": "Blank Page Omen",
		"description": "The paralysis of the first sentence. It feeds on the gap between intent and action.",
		"max_hp": 220,
		"initiative": 4,
		"max_poise": 50,
		"rune_reward": 200,
		"is_boss": true,
		"drops": [
			# Greatsword: reward for pushing through the hardest creative block
			{"id": "greatsword", "first_kill_chance": 1.0, "repeat_chance": 0.0},
		],
		"status_multipliers": { "scarlet_rot": 1.3, "frost": 1.2 },
		"moveset": ["infinite_loop", "standard_terror", "scope_creep"],
	},
	"perfectionism_knight": {
		"name": "Perfectionism Knight",
		"description": "A Remembrance Boss. An endless demand for revision. It will never let you publish.",
		"max_hp": 400,
		"initiative": 10,
		"max_poise": 80,
		"rune_reward": 500,
		"is_boss": true,
		"is_remembrance": true,
		"unlocks_area": "second_area",
		"drops": [],  # area unlock is the reward; Remembrance weapon added in future phase
		"status_multipliers": { "madness": 0.5, "bleed": 0.7, "frost": 0.8, "scarlet_rot": 0.9 },
		"moveset": ["revision_spiral", "not_good_enough", "one_more_source"],
	},
}

static func get_moveset(enemy: Dictionary) -> Array:
	return EnemyMovesetDB.get_moveset(enemy.get("moveset", []))
