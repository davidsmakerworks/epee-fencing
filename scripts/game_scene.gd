extends Node2D

# Main game scene - manages the fencing match

@onready var player1: CharacterBody2D = $Fencers/Player1
@onready var player2: CharacterBody2D = $Fencers/Player2
@onready var ai_controller: Node = $Fencers/Player2/AIController
@onready var hit_effects: Node2D = $HitEffects
@onready var ui: Control = $UI

const PISTE_LEFT: float = 120.0
const PISTE_RIGHT: float = 1160.0
const PISTE_CENTER: float = 640.0
const PISTE_Y: float = 480.0
const START_DISTANCE: float = 200.0
const CORPS_WARNING_MAX: int = 2
const PISTE_MARGIN: float = 30.0

var last_p1_hit: bool = false
var last_p2_hit: bool = false

# Lockout window for simultaneous hits (epee ~40-50ms)
const LOCKOUT_WINDOW: float = 0.045
var _lockout_timer: float = 0.0
var _pending_p1_hit: bool = false
var _pending_p2_hit: bool = false
var _in_lockout: bool = false
var _p1_corps_warnings: int = 0
var _p2_corps_warnings: int = 0
var _p1_side_warnings: int = 0
var _p2_side_warnings: int = 0

# Passivity timer
const PASSIVITY_TIME: float = 60.0
var _passivity_timer: float = 0.0

func _ready() -> void:
	_setup_fencers()
	_connect_signals()
	queue_redraw()

func _draw() -> void:
	_draw_piste()

func _draw_piste() -> void:
	# Background wall
	draw_rect(Rect2(0, 0, 1280, PISTE_Y + 80), Color(0.12, 0.12, 0.18))

	# Wall decorative elements
	for x in range(200, 1080, 200):
		draw_rect(Rect2(x, PISTE_Y + 40, 2, PISTE_Y + 30), Color(0.18, 0.18, 0.25))

	# Wall accent
	draw_rect(Rect2(0, PISTE_Y + 75, 1280, 5), Color(0.25, 0.25, 0.35))

	# Main piste floor
	draw_rect(Rect2(PISTE_LEFT, PISTE_Y + 95, PISTE_RIGHT - PISTE_LEFT, 14), Color(0.65, 0.55, 0.35))

	# Piste surface with texture lines
	for x in range(int(PISTE_LEFT), int(PISTE_RIGHT), 40):
		draw_line(Vector2(x, PISTE_Y + 95), Vector2(x, PISTE_Y + 109), Color(0.55, 0.45, 0.28, 0.5), 1.0)

	# Center line
	draw_line(Vector2(PISTE_CENTER, PISTE_Y + 88), Vector2(PISTE_CENTER, PISTE_Y + 112), Color(0.2, 0.2, 0.25), 2.0)

	# Warning lines (neutral zone markers)
	draw_line(Vector2(PISTE_CENTER - 100, PISTE_Y + 90), Vector2(PISTE_CENTER - 100, PISTE_Y + 110), Color(0.7, 0.2, 0.2), 2.0)
	draw_line(Vector2(PISTE_CENTER + 100, PISTE_Y + 90), Vector2(PISTE_CENTER + 100, PISTE_Y + 110), Color(0.7, 0.2, 0.2), 2.0)

	# End lines
	draw_line(Vector2(PISTE_LEFT, PISTE_Y + 88), Vector2(PISTE_LEFT, PISTE_Y + 112), Color(0.2, 0.2, 0.25), 3.0)
	draw_line(Vector2(PISTE_RIGHT, PISTE_Y + 88), Vector2(PISTE_RIGHT, PISTE_Y + 112), Color(0.2, 0.2, 0.25), 3.0)

	# Floor below piste
	draw_rect(Rect2(0, PISTE_Y + 109, 1280, 200), Color(0.08, 0.08, 0.12))

	# Spotlight effect
	draw_rect(Rect2(PISTE_CENTER - 250, 80, 500, PISTE_Y), Color(1, 1, 1, 0.02))

func _setup_fencers() -> void:
	player1.position = Vector2(PISTE_CENTER - START_DISTANCE, PISTE_Y)
	player2.position = Vector2(PISTE_CENTER + START_DISTANCE, PISTE_Y)

	if ai_controller:
		ai_controller.player_fencer = player1
		ai_controller.own_fencer = player2

func _connect_signals() -> void:
	GameManager.connect("bout_reset", _on_bout_reset)
	GameManager.connect("match_started", _on_match_started)
	player1.connect("parry_blocked", _on_parry_blocked)
	player2.connect("parry_blocked", _on_parry_blocked)

func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.FOUGHT:
		if _in_lockout:
			_lockout_timer -= delta
			if _lockout_timer <= 0:
				_resolve_lockout()
		if not _in_lockout:
			_check_hits()
			_check_corps()
			_passivity_timer -= delta
			if _passivity_timer <= 0:
				GameManager.record_passivity_halt()
				_passivity_timer = PASSIVITY_TIME
		_constrain_to_piste()

func _resolve_lockout() -> void:
	_in_lockout = false
	if _pending_p1_hit and _pending_p2_hit:
		GameManager.record_double_point()
		_spawn_hit_effect(Vector2((player1.position.x + player2.position.x) * 0.5, PISTE_Y - 30), true)
	elif _pending_p1_hit:
		GameManager.record_point("player1")
	elif _pending_p2_hit:
		GameManager.record_point("player2")
	_pending_p1_hit = false
	_pending_p2_hit = false

func _check_hits() -> void:
	if not player1 or not player2:
		return

	var p1 = player1
	var p2 = player2

	var p1_hits = false
	var p2_hits = false

	# Check if Player1's attack hits Player2
	if p1.attack_hitbox_active and not p1.hit_registered:
		var atk = p1.get_attack_rect()
		var def_box = p2.get_hitbox_rect()
		if atk.intersects(def_box):
			p2.take_hit()
			p1.hit_registered = true
			if not p2.in_parry_window:
				p1_hits = true
				_passivity_timer = PASSIVITY_TIME
				GameManager.last_hit_zone = p2.get_hit_zone_name(p2.get_hit_zone(atk))
				_spawn_hit_effect(p2.position + Vector2(-10 * p2.facing, -30), false)

	# Check if Player2's attack hits Player1
	if p2.attack_hitbox_active and not p2.hit_registered:
		var atk = p2.get_attack_rect()
		var def_box = p1.get_hitbox_rect()
		if atk.intersects(def_box):
			p1.take_hit()
			p2.hit_registered = true
			if not p1.in_parry_window:
				p2_hits = true
				_passivity_timer = PASSIVITY_TIME
				GameManager.last_hit_zone = p1.get_hit_zone_name(p1.get_hit_zone(atk))
				_spawn_hit_effect(p1.position + Vector2(-10 * p1.facing, -30), false)

	# Epee: simultaneous hits both score (with lockout window)
	if p1_hits and p2_hits:
		GameManager.record_double_point()
		_spawn_hit_effect(Vector2((p1.position.x + p2.position.x) * 0.5, PISTE_Y - 30), true)
		_in_lockout = false
		_pending_p1_hit = false
		_pending_p2_hit = false
	elif p1_hits and not p2_hits:
		if _in_lockout:
			_pending_p1_hit = true
		else:
			_in_lockout = true
			_lockout_timer = LOCKOUT_WINDOW
			_pending_p1_hit = true
			_pending_p2_hit = false
	elif p2_hits and not p1_hits:
		if _in_lockout:
			_pending_p2_hit = true
		else:
			_in_lockout = true
			_lockout_timer = LOCKOUT_WINDOW
			_pending_p1_hit = false
			_pending_p2_hit = true

func _spawn_hit_effect(position: Vector2, is_double: bool) -> void:
	var effect = hit_effects
	if effect:
		if effect.has_method("spawn_hit_effect"):
			effect.spawn_hit_effect(position, is_double)

func _constrain_to_piste() -> void:
	# Check rear boundary (end of piste): point to opponent
	if player1.position.x < PISTE_LEFT + PISTE_MARGIN:
		_p1_side_warnings += 1
		if _p1_side_warnings >= 3:
			GameManager.record_point("player2")
			_p1_side_warnings = 0
		else:
			GameManager.record_point("side_p1")
	elif player1.position.x > PISTE_RIGHT - PISTE_MARGIN:
		_p1_side_warnings += 1
		if _p1_side_warnings >= 3:
			GameManager.record_point("player2")
			_p1_side_warnings = 0
		else:
			GameManager.record_point("side_p1")
	if player2.position.x < PISTE_LEFT + PISTE_MARGIN:
		_p2_side_warnings += 1
		if _p2_side_warnings >= 3:
			GameManager.record_point("player1")
			_p2_side_warnings = 0
		else:
			GameManager.record_point("side_p2")
	elif player2.position.x > PISTE_RIGHT - PISTE_MARGIN:
		_p2_side_warnings += 1
		if _p2_side_warnings >= 3:
			GameManager.record_point("player1")
			_p2_side_warnings = 0
		else:
			GameManager.record_point("side_p2")

func _check_corps() -> void:
	if not player1 or not player2:
		return
	var r1 = player1.get_hitbox_rect()
	var r2 = player2.get_hitbox_rect()
	if r1.intersects(r2):
		# Corps-a-corps: halt and reset
		var p1_advancing = abs(player1.velocity.x) > abs(player2.velocity.x)
		if p1_advancing:
			_p1_corps_warnings += 1
			if _p1_corps_warnings >= CORPS_WARNING_MAX:
				GameManager.record_point("player2")
				_p1_corps_warnings = 0
			else:
				GameManager.record_point("corps_p1")
		else:
			_p2_corps_warnings += 1
			if _p2_corps_warnings >= CORPS_WARNING_MAX:
				GameManager.record_point("player1")
				_p2_corps_warnings = 0
			else:
				GameManager.record_point("corps_p2")

func _on_parry_blocked(pos: Vector2) -> void:
	if hit_effects and hit_effects.has_method("spawn_parry_spark"):
		hit_effects.spawn_parry_spark(pos)

func _on_match_started() -> void:
	if ai_controller and ui:
		ai_controller.difficulty = ui.selected_difficulty
		ai_controller._calibrate_difficulty()

func _on_bout_reset() -> void:
	player1.position = Vector2(PISTE_CENTER - START_DISTANCE, PISTE_Y)
	player2.position = Vector2(PISTE_CENTER + START_DISTANCE, PISTE_Y)
	player1.reset_for_bout()
	player2.reset_for_bout()
	_in_lockout = false
	_pending_p1_hit = false
	_pending_p2_hit = false
	_p1_corps_warnings = 0
	_p2_corps_warnings = 0
	_p1_side_warnings = 0
	_p2_side_warnings = 0
	_passivity_timer = PASSIVITY_TIME

	if ai_controller:
		ai_controller.reset()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_end"):
		get_tree().quit()
