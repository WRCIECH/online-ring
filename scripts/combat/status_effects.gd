class_name StatusEffects

# Buildup required to trigger each effect (same threshold for all enemies;
# adjust per-enemy via status_multipliers in EnemyDB to make some resistant).
const THRESHOLDS: Dictionary = {
	"bleed":       100.0,
	"madness":     100.0,
	"frost":       100.0,
	"scarlet_rot": 100.0,
}

const COLORS: Dictionary = {
	"bleed":       Color(0.85, 0.05, 0.15),
	"madness":     Color(0.65, 0.10, 0.90),
	"frost":       Color(0.35, 0.80, 1.00),
	"scarlet_rot": Color(0.85, 0.30, 0.05),
}

const LABELS: Dictionary = {
	"bleed":       "Bleed",
	"madness":     "Madness",
	"frost":       "Frost",
	"scarlet_rot": "Scarlet Rot",
}

# What triggers when each effect procs (descriptive — logic is in CombatScene)
const DESCRIPTIONS: Dictionary = {
	"bleed":       "Viral spike: 20% enemy max HP burst damage.",
	"madness":     "Reputation eruption: 15% enemy HP + 8% player HP (reputational blowback).",
	"frost":       "Shatters: 18% enemy HP burst + enemy loses next turn.",
	"scarlet_rot": "Corrodes: 6% enemy HP per turn for 3 turns.",
}
