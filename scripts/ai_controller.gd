extends Node

# AI opponent for epee fencing

@export var difficulty: float = 0.65

var player_fencer: Node = null
var own_fencer: Node = null

enum AIState {
	IDLE,
	EN_GARDE,
	ADVANCE,
	RETREAT,
	WAIT,
	ATTACK,
	LUNGE,
	PARRY,
	FEINT
}

var ai_state: AIState = AIState.IDLE
var state_timer: float = 0.0
var next_decision: float = 0.0
var reaction_time: float = 0.0
var is_reacting: bool = false
var pending_action: AIState = AIState.IDLE
var aggression_level: float = 0.5
var preferred_distance: float = 130.0

func _ready() -> void:
	_calibrate_difficulty()

func _calibrate_difficulty() -> void:
	reaction_time = lerp(0.3, 0.08, difficulty)
	aggression_level = lerp(0.45, 0.9, difficulty)
	preferred_distance = lerp(140.0, 95.0, difficulty)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.FOUGHT:
		return
	if not own_fencer:
		return

	state_timer -= delta
	next_decision -= delta

	# React to player attack
	if is_reacting:
		reaction_time -= delta
		if reaction_time <= 0:
			is_reacting = false
			_execute_pending()

	if _is_player_attacking() and not is_reacting and randf() < difficulty * 0.5:
		var dist = _get_distance()
		if dist < 150:
			_queue_reaction(AIState.PARRY)
			return

	# Execute current state every frame
	_execute_state(delta)

	# Make new decisions when fencer is ready
	if next_decision <= 0 and own_fencer.can_act:
		_make_decision()
		next_decision = randf_range(0.1, 0.3)

func _get_distance() -> float:
	if not player_fencer or not own_fencer:
		return 200.0
	return abs(player_fencer.position.x - own_fencer.position.x)

func _execute_state(delta: float) -> void:
	match ai_state:
		AIState.IDLE:
			if state_timer <= 0:
				ai_state = AIState.EN_GARDE
				_own_enter_engarde()

		AIState.EN_GARDE:
			pass  # decisions handled in _make_decision

		AIState.ADVANCE:
			if own_fencer.can_act:
				_own_advance()
			if state_timer <= 0:
				var dist = _get_distance()
				if dist <= preferred_distance:
					ai_state = AIState.EN_GARDE
				else:
					state_timer = 0.1

		AIState.RETREAT:
			if own_fencer.can_act:
				_own_retreat()
			if state_timer <= 0:
				var dist = _get_distance()
				if dist >= preferred_distance:
					ai_state = AIState.EN_GARDE
				else:
					state_timer = 0.1

		AIState.WAIT:
			if state_timer <= 0:
				ai_state = AIState.EN_GARDE

		AIState.ATTACK:
			if state_timer <= 0:
				ai_state = AIState.WAIT
				state_timer = randf_range(0.3, 0.6)

		AIState.LUNGE:
			if state_timer <= 0:
				ai_state = AIState.WAIT
				state_timer = randf_range(0.4, 0.8)

		AIState.PARRY:
			if state_timer <= 0:
				if randf() < 0.4 * difficulty:
					ai_state = AIState.ATTACK
					state_timer = 0.15
					_own_start_attack()
				else:
					ai_state = AIState.EN_GARDE
					_own_enter_engarde()

		AIState.FEINT:
			if state_timer <= 0:
				if randf() < aggression_level:
					ai_state = AIState.LUNGE
					state_timer = 0.5
					_own_start_lunge()
				else:
					ai_state = AIState.EN_GARDE
					_own_enter_engarde()

func _make_decision() -> void:
	if not own_fencer or not own_fencer.can_act:
		return

	var dist = _get_distance()

	match ai_state:
		AIState.EN_GARDE:
			if dist > preferred_distance + 30:
				ai_state = AIState.ADVANCE
				state_timer = 0.3
				_own_advance()
			elif dist < preferred_distance - 20:
				if randf() < aggression_level * 0.7:
					_do_attack()
				elif randf() < 0.3:
					ai_state = AIState.RETREAT
					state_timer = 0.3
					_own_retreat()
				else:
					ai_state = AIState.WAIT
					state_timer = randf_range(0.1, 0.3)
			else:
				if randf() < aggression_level * 0.55:
					_do_attack()
				else:
					ai_state = AIState.WAIT
					state_timer = randf_range(0.08, 0.25)

		AIState.WAIT:
			if state_timer <= 0:
				ai_state = AIState.EN_GARDE

func _do_attack() -> void:
	var r = randf()
	if r < 0.15:
		ai_state = AIState.FEINT
		state_timer = 0.25
		_own_start_attack()
	elif r < 0.55:
		ai_state = AIState.LUNGE
		state_timer = 0.6
		_own_start_lunge()
	else:
		ai_state = AIState.ATTACK
		state_timer = 0.3
		_own_start_attack()

func _is_player_attacking() -> bool:
	if not player_fencer:
		return false
	return player_fencer.is_in_attack_state()

func _queue_reaction(action: AIState) -> void:
	if is_reacting:
		return
	is_reacting = true
	reaction_time = self.reaction_time
	pending_action = action

func _execute_pending() -> void:
	match pending_action:
		AIState.PARRY:
			ai_state = AIState.PARRY
			state_timer = 0.35
			_own_start_parry()
		AIState.ATTACK:
			ai_state = AIState.ATTACK
			state_timer = 0.25
			_own_start_attack()

# Delegate to own fencer
func _own_enter_engarde() -> void:
	if own_fencer:
		own_fencer.enter_en_garde()

func _own_advance() -> void:
	if own_fencer:
		own_fencer._start_advance()

func _own_retreat() -> void:
	if own_fencer:
		own_fencer._start_retreat()

func _own_start_attack() -> void:
	if own_fencer:
		own_fencer._start_attack()

func _own_start_lunge() -> void:
	if own_fencer:
		own_fencer._start_lunge()

func _own_start_parry() -> void:
	if own_fencer:
		own_fencer._start_parry()

func reset() -> void:
	ai_state = AIState.IDLE
	state_timer = 0.2
	next_decision = 0.1
	is_reacting = false
