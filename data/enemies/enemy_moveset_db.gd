class_name EnemyMovesetDB

# All enemy moves keyed by unique ID.
# Enemies reference these by ID; see EnemyDB.get_moveset().
const MOVES: Dictionary = {
	# ── Procrastination Mob ───────────────────────────────────────────────────
	"mindless_scroll": {
		"id": "mindless_scroll",
		"name": "Mindless Scrolling",
		"description": "Just 5 more minutes of social media.",
		"damage": 12, "block_damage": 5, "poise_damage": 8,
	},
	"shiny_object": {
		"id": "shiny_object",
		"name": "Shiny Object",
		"description": "A new tool that absolutely needs researching right now.",
		"damage": 18, "block_damage": 8, "poise_damage": 5,
	},

	# ── The Hater ─────────────────────────────────────────────────────────────
	"public_criticism": {
		"id": "public_criticism",
		"name": "Public Criticism",
		"description": "Attacks your approach publicly, hoping others pile on.",
		"damage": 28, "block_damage": 12, "poise_damage": 15,
	},
	"mockery": {
		"id": "mockery",
		"name": "Mockery",
		"description": "Ridicules your content to undermine your confidence.",
		"damage": 18, "block_damage": 7, "poise_damage": 8,
	},
	"credibility_slash": {
		"id": "credibility_slash",
		"name": "Credibility Slash",
		"description": "Who are you to talk about this?",
		"damage": 35, "block_damage": 18, "poise_damage": 20,
	},

	# ── Blank Page Omen ───────────────────────────────────────────────────────
	"infinite_loop": {
		"id": "infinite_loop",
		"name": "Infinite Loop",
		"description": "Check notes, reread outline, check notes again. Nothing gets written.",
		"damage": 22, "block_damage": 10, "poise_damage": 12,
	},
	"standard_terror": {
		"id": "standard_terror",
		"name": "Standard Terror",
		"description": "It's not good enough. You delete the paragraph. Again.",
		"damage": 30, "block_damage": 14, "poise_damage": 18,
	},
	"scope_creep": {
		"id": "scope_creep",
		"name": "Scope Creep",
		"description": "You need to research more before you can even start.",
		"damage": 15, "block_damage": 6, "poise_damage": 6,
	},

	# ── Perfectionism Knight ──────────────────────────────────────────────────
	"revision_spiral": {
		"id": "revision_spiral",
		"name": "Revision Spiral",
		"description": "Forces you back to revise the opening. Again.",
		"damage": 35, "block_damage": 16, "poise_damage": 20,
	},
	"not_good_enough": {
		"id": "not_good_enough",
		"name": "Not Good Enough",
		"description": "Compares your work to the best in the field.",
		"damage": 45, "block_damage": 22, "poise_damage": 30,
	},
	"one_more_source": {
		"id": "one_more_source",
		"name": "One More Source",
		"description": "You just need to read one more thing before it's done.",
		"damage": 25, "block_damage": 10, "poise_damage": 15,
	},
}

static func get_moveset(ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		if MOVES.has(id):
			result.append(MOVES[id])
	return result
