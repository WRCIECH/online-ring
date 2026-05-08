class_name EnemyDB

const ENEMIES := {
	"procrastination_mob": {
		"name": "Procrastination Mob",
		"description": "A common distraction. Weak alone, draining in groups.",
		"max_hp": 80,
		"initiative": 6,
		"max_poise": 20,
		"rune_reward": 50,
		"is_boss": false,
		"moveset": [
			{
				"id": "mindless_scroll",
				"name": "Mindless Scrolling",
				"description": "Just 5 more minutes of social media.",
				"damage": 12, "block_damage": 5, "poise_damage": 8,
			},
			{
				"id": "shiny_object",
				"name": "Shiny Object",
				"description": "A new tool that absolutely needs researching right now.",
				"damage": 18, "block_damage": 8, "poise_damage": 5,
			},
		],
	},
	"hater": {
		"name": "The Hater",
		"description": "A manifestation of public online criticism.",
		"max_hp": 180,
		"initiative": 8,
		"max_poise": 40,
		"rune_reward": 150,
		"is_boss": true,
		"moveset": [
			{
				"id": "public_criticism",
				"name": "Public Criticism",
				"description": "Attacks your approach publicly, hoping others pile on.",
				"damage": 28, "block_damage": 12, "poise_damage": 15,
			},
			{
				"id": "mockery",
				"name": "Mockery",
				"description": "Ridicules your content to undermine your confidence.",
				"damage": 18, "block_damage": 7, "poise_damage": 8,
			},
			{
				"id": "credibility_slash",
				"name": "Credibility Slash",
				"description": "Who are you to talk about this?",
				"damage": 35, "block_damage": 18, "poise_damage": 20,
			},
		],
	},
	"blank_page_omen": {
		"name": "Blank Page Omen",
		"description": "The paralysis of the first sentence. It feeds on the gap between intent and action.",
		"max_hp": 220,
		"initiative": 4,
		"max_poise": 50,
		"rune_reward": 200,
		"is_boss": true,
		"moveset": [
			{
				"id": "infinite_loop",
				"name": "Infinite Loop",
				"description": "Check notes, reread outline, check notes again. Nothing gets written.",
				"damage": 22, "block_damage": 10, "poise_damage": 12,
			},
			{
				"id": "standard_terror",
				"name": "Standard Terror",
				"description": "It's not good enough. You delete the paragraph. Again.",
				"damage": 30, "block_damage": 14, "poise_damage": 18,
			},
			{
				"id": "scope_creep",
				"name": "Scope Creep",
				"description": "You need to research more before you can even start.",
				"damage": 15, "block_damage": 6, "poise_damage": 6,
			},
		],
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
		"moveset": [
			{
				"id": "revision_spiral",
				"name": "Revision Spiral",
				"description": "Forces you back to revise the opening. Again.",
				"damage": 35, "block_damage": 16, "poise_damage": 20,
			},
			{
				"id": "not_good_enough",
				"name": "Not Good Enough",
				"description": "Compares your work to the best in the field.",
				"damage": 45, "block_damage": 22, "poise_damage": 30,
			},
			{
				"id": "one_more_source",
				"name": "One More Source",
				"description": "You just need to read one more thing before it's done.",
				"damage": 25, "block_damage": 10, "poise_damage": 15,
			},
		],
	},
}
