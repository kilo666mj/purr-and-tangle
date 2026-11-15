extends RefCounted
## Presets change pacing and starting target count, never matching/rotation rules.

enum { RELAXED, NORMAL, SPICY }
const NAMES := ["Relaxed", "Normal", "Spicy"]
const STARTING_YARN := [4, 8, 12]
const FALL_SECONDS := [1.05, 0.85, 0.65]
const MIN_FALL_SECONDS := 0.18
const SPEED_STEP_SECONDS := 20.0
const SPEED_STEP_FACTOR := 0.85
const DESCRIPTIONS := ["4 tangles · a little breathing room", "8 tangles · a steady pace", "12 tangles · quick paws"]


static func valid(value: int) -> int:
	return value if value in [RELAXED, NORMAL, SPICY] else NORMAL


static func fall_interval(preset: int, level: int, play_time: float = 0.0) -> float:
	var base := maxf(MIN_FALL_SECONDS, FALL_SECONDS[valid(preset)] - (level - 1) * 0.045)
	var steps := floori(maxf(0.0, play_time) / SPEED_STEP_SECONDS)
	return maxf(MIN_FALL_SECONDS, base * pow(SPEED_STEP_FACTOR, steps))


static func targets(preset: int, level: int) -> int:
	return mini(STARTING_YARN[valid(preset)] + (level - 1) * 2, 52)
