extends Node

# Game Manager - Central state management for the fencing match
# Epee rules: whole body is target, no right-of-way, simultaneous hits allowed
# Period system: 3 periods of 3 minutes, first to 15 wins

signal match_started
signal match_paused
signal match_ended
signal point_scored(scorer: String, is_double: bool)
signal bout_reset
signal penalty_issued(reason: String)
signal period_ended(period: int)
signal period_started(period: int)

enum GameState {
	IDLE,
	READY,
	EN_GARDE,
	FOUGHT,
	POINT,
	PERIOD_BREAK,
	PRIORITY,
	ENDED
}

var current_state: GameState = GameState.IDLE
var player1_score: int = 0
var player2_score: int = 0
var max_score: int = 15
var current_bout: int = 1
var max_bouts: int = 1
var halt_timer: float = 0.0
var is_double_touch: bool = false
var last_hit_zone: String = ""

var player1_ready: bool = false
var player2_ready: bool = false

# Period system
var current_period: int = 1
var max_periods: int = 3
var period_time: float = 180.0
var period_timer: float = 0.0
var is_period_running: bool = false

# Priority (sudden death)
var has_priority: String = ""

const HALT_DURATION: float = 1.5
const READY_DURATION: float = 1.0
const EN_GARDE_DURATION: float = 0.8
const PERIOD_BREAK_DURATION: float = 60.0
const PRIORITY_DURATION: float = 60.0

func _ready() -> void:
	reset_match()

func _process(delta: float) -> void:
	match current_state:
		GameState.POINT:
			halt_timer -= delta
			if halt_timer <= 0:
				if check_match_over():
					if player1_score == player2_score and current_period >= max_periods:
						start_priority()
					else:
						end_match()
				else:
					start_ready_phase()
		GameState.READY:
			halt_timer -= delta
			if halt_timer <= 0:
				start_engarde_phase()
		GameState.EN_GARDE:
			halt_timer -= delta
			if halt_timer <= 0:
				start_bout()
		GameState.FOUGHT:
			if is_period_running:
				period_timer -= delta
				if period_timer <= 0:
					end_period()
		GameState.PERIOD_BREAK:
			halt_timer -= delta
			if halt_timer <= 0:
				start_ready_phase()
		GameState.PRIORITY:
			if is_period_running:
				period_timer -= delta
				if period_timer <= 0:
					if player1_score != player2_score:
						end_match()
					else:
						# Flip priority
						has_priority = "player2" if has_priority == "player1" else "player1"
						period_timer = PRIORITY_DURATION
						emit_signal("penalty_issued", "PRIORITY")

func reset_match() -> void:
	player1_score = 0
	player2_score = 0
	current_bout = 1
	current_period = 1
	current_state = GameState.IDLE
	period_timer = period_time
	is_period_running = false
	has_priority = ""
	emit_signal("bout_reset")

func start_match() -> void:
	current_state = GameState.READY
	current_period = 1
	period_timer = period_time
	is_period_running = false
	has_priority = ""
	start_ready_phase()
	emit_signal("match_started")

func start_ready_phase() -> void:
	current_state = GameState.READY
	halt_timer = READY_DURATION
	player1_ready = false
	player2_ready = false

func start_engarde_phase() -> void:
	current_state = GameState.EN_GARDE
	halt_timer = EN_GARDE_DURATION

func start_bout() -> void:
	current_state = GameState.FOUGHT
	is_period_running = true
	emit_signal("bout_reset")
	emit_signal("period_started", current_period)

func end_period() -> void:
	is_period_running = false
	emit_signal("period_ended", current_period)
	if current_period < max_periods:
		current_period += 1
		current_state = GameState.PERIOD_BREAK
		halt_timer = PERIOD_BREAK_DURATION
		period_timer = period_time
		emit_signal("penalty_issued", "PERIOD_BREAK")
	elif player1_score == player2_score:
		start_priority()
	else:
		end_match()

func start_priority() -> void:
	current_state = GameState.PRIORITY
	is_period_running = true
	period_timer = PRIORITY_DURATION
	has_priority = "player1"  # Random would be better, simplified for now

func record_point(scorer: String) -> void:
	if current_state != GameState.FOUGHT:
		return

	match scorer:
		"player1":
			player1_score += 1
		"player2":
			player2_score += 1
		"side_p1", "side_p2", "corps_p1", "corps_p2":
			pass
		_:
			return

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

func record_passivity_halt() -> void:
	if current_state != GameState.FOUGHT:
		return
	is_double_touch = false
	current_state = GameState.POINT
	halt_timer = HALT_DURATION
	emit_signal("point_scored", "passivity", is_double_touch)

func check_match_over() -> bool:
	if player1_score >= max_score or player2_score >= max_score:
		return true
	return false

func end_match() -> void:
	current_state = GameState.ENDED
	is_period_running = false
	emit_signal("match_ended")

func get_winner() -> String:
	if player1_score > player2_score:
		return "player1"
	elif player2_score > player1_score:
		return "player2"
	return "draw"

func get_time_string() -> String:
	var mins = int(period_timer) / 60
	var secs = int(period_timer) % 60
	return "%d:%02d" % [mins, secs]

func get_state_name() -> String:
	match current_state:
		GameState.IDLE: return "IDLE"
		GameState.READY: return "READY"
		GameState.EN_GARDE: return "EN GARDE"
		GameState.FOUGHT: return "ALLEZ!"
		GameState.POINT: return "HALT!"
		GameState.PERIOD_BREAK: return "PERIOD %d" % current_period
		GameState.PRIORITY: return "PRIORITY"
		GameState.ENDED: return "MATCH OVER"
	return "UNKNOWN"