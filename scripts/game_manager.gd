extends Node

# Game Manager - Central state management for the fencing match
# Epee rules: whole body is target, no right-of-way, simultaneous hits allowed

signal match_started
signal match_paused
signal match_ended
signal point_scored(scorer: String, is_double: bool, line: String, p2_line: String)
signal bout_halted(reason: String)
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

enum MatchFormat {
	POOL,
	DE
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

var match_format: MatchFormat = MatchFormat.POOL
var current_period: int = 1
var period_time: float = 180.0
const PERIOD_DURATION: float = 180.0
const POOL_MAX_SCORE: int = 5
const DE_MAX_SCORE: int = 15

const HALT_DURATION: float = 1.5
const READY_DURATION: float = 1.0
const HALF_TIME_DURATION: float = 3.0

func _ready() -> void:
	reset_match()

func _process(delta: float) -> void:
	match current_state:
		GameState.FOUGHT:
			period_time -= delta
			if period_time <= 0:
				_end_period()
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
		GameState.HALF_TIME:
			halt_timer -= delta
			if halt_timer <= 0:
				current_period += 1
				period_time = PERIOD_DURATION
				start_ready_phase()

func reset_match() -> void:
	player1_score = 0
	player2_score = 0
	current_bout = 1
	current_period = 1
	period_time = PERIOD_DURATION
	max_score = POOL_MAX_SCORE if match_format == MatchFormat.POOL else DE_MAX_SCORE
	current_state = GameState.IDLE
	emit_signal("bout_reset")

func start_match() -> void:
	current_state = GameState.READY
	max_score = POOL_MAX_SCORE if match_format == MatchFormat.POOL else DE_MAX_SCORE
	current_period = 1
	period_time = PERIOD_DURATION
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

func record_point(scorer: String, line: String = "") -> void:
	if current_state != GameState.FOUGHT:
		return

	if scorer == "player1":
		player1_score += 1
	elif scorer == "player2":
		player2_score += 1

	is_double_touch = false
	current_state = GameState.POINT
	halt_timer = HALT_DURATION
	emit_signal("point_scored", scorer, is_double_touch, line, "")

func record_double_point(p1_line: String = "", p2_line: String = "") -> void:
	if current_state != GameState.FOUGHT:
		return

	player1_score += 1
	player2_score += 1
	is_double_touch = true
	current_state = GameState.POINT
	halt_timer = HALT_DURATION
	emit_signal("point_scored", "both", is_double_touch, p1_line, p2_line)

func halt_bout(reason: String = "") -> void:
	if current_state != GameState.FOUGHT:
		return
	current_state = GameState.POINT
	halt_timer = HALT_DURATION
	emit_signal("bout_halted", reason)

func _end_period() -> void:
	if match_format == MatchFormat.POOL:
		end_match()
	else:
		# DE format
		if current_period >= 3:
			end_match()
		else:
			current_state = GameState.HALF_TIME
			halt_timer = HALF_TIME_DURATION
			emit_signal("bout_halted", "End of Period %d" % current_period)

func check_match_over() -> bool:
	return player1_score >= max_score or player2_score >= max_score

func end_match() -> void:
	current_state = GameState.ENDED
	emit_signal("match_ended")

func toggle_format() -> void:
	if current_state != GameState.IDLE:
		return
	if match_format == MatchFormat.POOL:
		match_format = MatchFormat.DE
		max_score = DE_MAX_SCORE
	else:
		match_format = MatchFormat.POOL
		max_score = POOL_MAX_SCORE

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

func get_format_name() -> String:
	match match_format:
		MatchFormat.POOL: return "POOL"
		MatchFormat.DE: return "DE"
	return "POOL"

func get_timer_string() -> String:
	var minutes = int(period_time) / 60
	var seconds = int(period_time) % 60
	return "%d:%02d" % [minutes, seconds]
