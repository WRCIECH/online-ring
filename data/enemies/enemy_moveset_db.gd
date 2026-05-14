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
		"dodge_task": {"name": "Write the next word of your piece without looking away", "time": 20},
		"parry_task": {"name": "Write one sentence about your current topic", "time": 15},
	},
	"shiny_object": {
		"id": "shiny_object",
		"name": "Shiny Object",
		"description": "A new tool that absolutely needs researching right now.",
		"damage": 18, "block_damage": 8, "poise_damage": 5,
		"dodge_task": {"name": "Close all distractions — write one word of your piece", "time": 20},
		"parry_task": {"name": "Write one concrete fact you already know about your topic", "time": 15},
	},

	# ── The Hater ─────────────────────────────────────────────────────────────
	"public_criticism": {
		"id": "public_criticism",
		"name": "Public Criticism",
		"description": "Attacks your approach publicly, hoping others pile on.",
		"damage": 28, "block_damage": 12, "poise_damage": 15,
		"dodge_task": {"name": "Write one thing you know to be true about your work", "time": 20},
		"parry_task": {"name": "Write one sentence that defends your perspective", "time": 15},
	},
	"mockery": {
		"id": "mockery",
		"name": "Mockery",
		"description": "Ridicules your content to undermine your confidence.",
		"damage": 18, "block_damage": 7, "poise_damage": 8,
		"dodge_task": {"name": "Write the next sentence of your piece", "time": 20},
		"parry_task": {"name": "Write one line you are genuinely proud of from your work", "time": 15},
	},
	"credibility_slash": {
		"id": "credibility_slash",
		"name": "Credibility Slash",
		"description": "Who are you to talk about this?",
		"damage": 35, "block_damage": 18, "poise_damage": 20,
		"dodge_task": {"name": "Write one credential or experience that qualifies you", "time": 20},
		"parry_task": {"name": "Write one specific example that supports your point", "time": 15},
	},

	# ── Blank Page Omen ───────────────────────────────────────────────────────
	"infinite_loop": {
		"id": "infinite_loop",
		"name": "Infinite Loop",
		"description": "Check notes, reread outline, check notes again. Nothing gets written.",
		"damage": 22, "block_damage": 10, "poise_damage": 12,
		"dodge_task": {"name": "Pick one thing to write and write its first word now", "time": 20},
		"parry_task": {"name": "Write one sentence that moves your piece forward", "time": 15},
	},
	"standard_terror": {
		"id": "standard_terror",
		"name": "Standard Terror",
		"description": "It's not good enough. You delete the paragraph. Again.",
		"damage": 30, "block_damage": 14, "poise_damage": 18,
		"dodge_task": {"name": "Write one small achievable step you can do right now", "time": 20},
		"parry_task": {"name": "Write the next sentence — no editing allowed", "time": 15},
	},
	"scope_creep": {
		"id": "scope_creep",
		"name": "Scope Creep",
		"description": "You need to research more before you can even start.",
		"damage": 15, "block_damage": 6, "poise_damage": 6,
		"dodge_task": {"name": "Write only about your core topic — one sentence", "time": 20},
		"parry_task": {"name": "Write your piece's single main point in one sentence", "time": 15},
	},

	# ── Perfectionism Knight ──────────────────────────────────────────────────
	"revision_spiral": {
		"id": "revision_spiral",
		"name": "Revision Spiral",
		"description": "Forces you back to revise the opening. Again.",
		"damage": 35, "block_damage": 16, "poise_damage": 20,
		"dodge_task": {"name": "Write something new — do not look at old text", "time": 20},
		"parry_task": {"name": "Write one original idea that is not a revision", "time": 15},
	},
	"not_good_enough": {
		"id": "not_good_enough",
		"name": "Not Good Enough",
		"description": "Compares your work to the best in the field.",
		"damage": 45, "block_damage": 22, "poise_damage": 30,
		"dodge_task": {"name": "Write the next sentence regardless of quality", "time": 20},
		"parry_task": {"name": "Write one thing about your work that is already good enough", "time": 15},
	},
	"one_more_source": {
		"id": "one_more_source",
		"name": "One More Source",
		"description": "You just need to read one more thing before it's done.",
		"damage": 25, "block_damage": 10, "poise_damage": 15,
		"dodge_task": {"name": "Write from what you already know — one sentence", "time": 20},
		"parry_task": {"name": "Write your own take without referencing anything", "time": 15},
	},

	# ── Burnout Shade ─────────────────────────────────────────────────────────
	"hollow_stare": {
		"id": "hollow_stare",
		"name": "Hollow Stare",
		"description": "Stares through you, draining your will to continue.",
		"damage": 16, "block_damage": 7, "poise_damage": 9,
		"dodge_task": {"name": "Write one sentence about why your topic matters to you", "time": 20},
		"parry_task": {"name": "Write your project's next concrete sentence", "time": 15},
	},
	"drag_down": {
		"id": "drag_down",
		"name": "Drag Down",
		"description": "Heavy mental fog pulls your creativity underwater.",
		"damage": 24, "block_damage": 10, "poise_damage": 13,
		"dodge_task": {"name": "Write three words that describe what you enjoy about writing", "time": 20},
		"parry_task": {"name": "Write the simplest possible version of your next idea", "time": 15},
	},

	# ── Comparison Engine ─────────────────────────────────────────────────────
	"viral_post": {
		"id": "viral_post",
		"name": "Viral Post",
		"description": "Shows you someone else's viral content to make you question yourself.",
		"damage": 22, "block_damage": 9, "poise_damage": 11,
		"dodge_task": {"name": "Write one thing that makes your perspective unique", "time": 20},
		"parry_task": {"name": "Write one sentence only you could have written", "time": 15},
	},
	"follower_count": {
		"id": "follower_count",
		"name": "Follower Count",
		"description": "Reduces your creative worth to a number you can never beat.",
		"damage": 28, "block_damage": 12, "poise_damage": 15,
		"dodge_task": {"name": "Write who you are writing for — name one specific person", "time": 20},
		"parry_task": {"name": "Write one reader your work could genuinely help", "time": 15},
	},
	"trending_now": {
		"id": "trending_now",
		"name": "Trending Now",
		"description": "Drowns your voice in the noise of what's popular this week.",
		"damage": 36, "block_damage": 17, "poise_damage": 21,
		"dodge_task": {"name": "Write one evergreen idea that will matter in five years", "time": 20},
		"parry_task": {"name": "Write one truth your audience needs to hear right now", "time": 15},
	},

	# ── Fear Phantom ──────────────────────────────────────────────────────────
	"what_if_they_laugh": {
		"id": "what_if_they_laugh",
		"name": "What If They Laugh",
		"description": "Conjures an imaginary audience mocking your unfinished work.",
		"damage": 20, "block_damage": 8, "poise_damage": 10,
		"dodge_task": {"name": "Write one sentence as if no one will ever read it", "time": 20},
		"parry_task": {"name": "Write the bravest sentence you can right now", "time": 15},
	},
	"stay_hidden": {
		"id": "stay_hidden",
		"name": "Stay Hidden",
		"description": "Whispers that you are safer staying unpublished.",
		"damage": 16, "block_damage": 6, "poise_damage": 8,
		"dodge_task": {"name": "Write one reason someone needs to read your work", "time": 20},
		"parry_task": {"name": "Write your work's first sentence as if it is already published", "time": 15},
	},
	"visibility_terror": {
		"id": "visibility_terror",
		"name": "Visibility Terror",
		"description": "Full existential panic at the thought of being truly seen.",
		"damage": 32, "block_damage": 15, "poise_damage": 18,
		"dodge_task": {"name": "Write what you want readers to feel after reading your piece", "time": 20},
		"parry_task": {"name": "Write your work's core message in one direct sentence", "time": 15},
	},
}

static func get_moveset(ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		if MOVES.has(id):
			result.append(MOVES[id])
	return result
