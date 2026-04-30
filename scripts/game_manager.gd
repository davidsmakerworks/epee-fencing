extends Node

# Game Manager - Central state management for the fencing match
# Epee rules: whole body is target, no right-of-way, simultaneous hits allowed

signal match_started
signal match_paused
signal match_ended
signal point_scored(scorer: String, is_double: bool)
signal bout_reset

enum GameState {
	IDLE,
	READY,
	EN_GARDE,
	FOUGHT,
	POINT,
	HALF_TIME,
	ENDED
}

var current_state: GameState = GameState.IDLE
var player1_score: int = 0
var player2_score: int = 0
var max_score: int = 5
var current_bout: int = 1
var max_bouts: int = 1
var halt_timer: float = 0.0
var is_double_touch: bool = false

var player1_ready: bool = false
var player2_ready: bool = false

const HALT_DURATION: float = 1.5
const READY_DURATION: float = 1.0

func _ready() -> void:
	reset_match()

func _process(delta: float) -> void:
	match current_state:
		GameState.POINT:
			halt_timer -= delta
			if halt_timer <= 0:
				if check_match_over():
					end_match()
				else:
					start_ready_phase()
		GameState.READY:
			halt_timer -= delta
			if halt_timer <= 0:
				start_bout()

func reset_match() -> void:
	player1_score = 0
	player2_score = 0
	current_bout = 1
	current_state = GameState.IDLE
	emit_signal("bout_reset")

func start_match() -> void:
	current_state = GameState.READY
	start_ready_phase()
	emit_signal("match_started")

func start_ready_phase() -> void:
	current_state = GameState.READY
	halt_timer = READY_DURATION
	player1_ready = false
	player2_ready = false

func start_bout() -> void:
	current_state = GameState.FOUGHT
	emit_signal("bout_reset")

func record_point(scorer: String) -> void:
	if current_state != GameState.FOUGHT:
		return

	if scorer == "player1":
		player1_score += 1
	elif scorer == "player2":
		player2_score += 1

	is_double_touch = false
	current_state = GameState.POINT
	halt_timer = HALT_DURATION
	emit_signal("point_scored", scorer, is_double_touch)

func record_double_point() -> void:
	if current_state != GameState.FOUGHT:
		return

	player1_score += 1
	player2_score += 1
	is_double_touch = true
	current_state = GameState.POINT
	halt_timer = HALT_DURATION
	emit_signal("point_scored", "both", is_double_touch)

func check_match_over() -> bool:
	return player1_score >= max_score or player2_score >= max_score

func end_match() -> void:
	current_state = GameState.ENDED
	emit_signal("match_ended")

func get_winner() -> String:
	if player1_score > player2_score:
		return "player1"
	elif player2_score > player1_score:
		return "player2"
	return "draw"

func get_state_name() -> String:
	match current_state:
		GameState.IDLE: return "IDLE"
		GameState.READY: return "READY"
		GameState.EN_GARDE: return "EN GARDE"
		GameState.FOUGHT: return "ALLEZ!"
		GameState.POINT: return "HALT!"
		GameState.HALF_TIME: return "HALF TIME"
		GameState.ENDED: return "MATCH OVER"
	return "UNKNOWN"
