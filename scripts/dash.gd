extends RefCounted
## Kitchen dash rules: cross the lanes of robot vacuums and rolling yarn; three bumps end the run.

const WIDTH := 11
const HEIGHT := 9
const BUMPS := 3
const REST_ROW := 4  # A safe rug halfway across.

var cat := Vector2i.ZERO
var lanes := {}  # row -> {dir, interval, clock, cells}
var score := 0
var crossings := 0
var bumps := 0
var moving := false
var over := false
var won := false  # Endless: kept so every side game reports the same outcome fields.
var paused := false
var rng := RandomNumberGenerator.new()


func start(seed_value: int) -> void:
	rng.seed = seed_value
	score = 0
	crossings = 0
	bumps = 0
	moving = false
	over = false
	paused = false
	lay_out()


func lay_out() -> void:
	cat = Vector2i(WIDTH / 2, HEIGHT - 1)
	lanes.clear()
	for row in range(1, HEIGHT - 1):
		if row == REST_ROW:
			continue
		# Evenly spaced, so every lane always has a gap to slip through.
		var count := rng.randi_range(2, 3)
		var offset := rng.randi_range(0, WIDTH - 1)
		var cells: Array[int] = []
		for i in range(count):
			cells.append((offset + i * (WIDTH / count)) % WIDTH)
		var pace := rng.randf_range(0.3, 0.55) * maxf(0.45, 1.0 - 0.07 * crossings)
		lanes[row] = {"dir": 1 if row % 2 == 0 else -1, "interval": pace, "clock": 0.0, "cells": cells}


func turn(direction: Vector2i) -> void:
	if over:
		return
	moving = true
	cat = (cat + direction).clamp(Vector2i.ZERO, Vector2i(WIDTH - 1, HEIGHT - 1))
	if cat.y == 0:
		crossings += 1
		score += 50
		lay_out()
	check_bump()


func tick(delta: float) -> void:
	if paused or over:
		return
	for row in lanes:
		var lane: Dictionary = lanes[row]
		lane.clock += delta
		while lane.clock >= lane.interval:
			lane.clock -= lane.interval
			for i in range(lane.cells.size()):
				lane.cells[i] = posmod(lane.cells[i] + lane.dir, WIDTH)
	check_bump()


func check_bump() -> void:
	if lanes.has(cat.y) and lanes[cat.y].cells.has(cat.x):
		bumps += 1
		over = bumps >= BUMPS
		cat = Vector2i(WIDTH / 2, HEIGHT - 1)
