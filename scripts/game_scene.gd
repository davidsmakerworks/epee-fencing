extends Node2D

# Main game scene - manages the fencing match

@onready var player1: CharacterBody2D = $Fencers/Player1
@onready var player2: CharacterBody2D = $Fencers/Player2
@onready var ai_controller: Node = $Fencers/Player2/AIController
@onready var hit_effects: Node2D = $HitEffects

const PISTE_LEFT: float = 120.0
const PISTE_RIGHT: float = 1160.0
const PISTE_CENTER: float = 640.0
const PISTE_Y: float = 480.0
const START_DISTANCE: float = 200.0
const LOCKOUT_DURATION: float = 0.08  # Slightly more forgiving than real 40ms
const CORPS_DISTANCE: float = 28.0

var lockout_timer: float = 0.0
var pending_p1_hit: bool = false
var pending_p2_hit: bool = false
var pending_p1_line: String = "Mid"
var pending_p2_line: String = "Mid"

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

func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.FOUGHT:
		_check_hits(delta)
		if lockout_timer <= 0.0:
			_check_rear_line()
			_check_corps_a_corps()
		_constrain_to_piste()

func _check_hits(delta: float) -> void:
	if not player1 or not player2:
		return

	# If lockout is active, tick it down and check for second hit
	if lockout_timer > 0.0:
		lockout_timer -= delta
		if lockout_timer <= 0.0:
			_resolve_pending_hits()
		else:
			_check_second_hit()
		return

	var p1 = player1
	var p2 = player2

	# Detect potential hits first without applying take_hit,
	# so that simultaneous hits on the same frame are both registered.
	var p1_would_hit = false
	var p2_would_hit = false

	if p1.attack_hitbox_active and not p1.hit_registered:
		var atk = p1.get_attack_rect()
		var def_box = p2.get_hitbox_rect()
		if atk.intersects(def_box):
			if not p2.in_parry_window or p1.is_beat_attack:
				p1_would_hit = true

	if p2.attack_hitbox_active and not p2.hit_registered:
		var atk = p2.get_attack_rect()
		var def_box = p1.get_hitbox_rect()
		if atk.intersects(def_box):
			if not p1.in_parry_window or p2.is_beat_attack:
				p2_would_hit = true

	# Apply hits
	var p1_hit_now = false
	var p2_hit_now = false

	if p1_would_hit:
		p2.take_hit()
		p1.hit_registered = true
		p1_hit_now = true
		pending_p1_line = p1.get_attack_line_name()
		_spawn_hit_effect(p2.position + Vector2(-10 * p2.facing, -30), false)

	if p2_would_hit:
		p1.take_hit()
		p2.hit_registered = true
		p2_hit_now = true
		pending_p2_line = p2.get_attack_line_name()
		_spawn_hit_effect(p1.position + Vector2(-10 * p1.facing, -30), false)

	if p1_hit_now or p2_hit_now:
		pending_p1_hit = p1_hit_now
		pending_p2_hit = p2_hit_now
		lockout_timer = LOCKOUT_DURATION

func _check_second_hit() -> void:
	if not player1 or not player2:
		return
	var p1 = player1
	var p2 = player2

	var p1_would_hit = false
	var p2_would_hit = false

	if not pending_p1_hit and p1.attack_hitbox_active and not p1.hit_registered:
		var atk = p1.get_attack_rect()
		var def_box = p2.get_hitbox_rect()
		if atk.intersects(def_box):
			if not p2.in_parry_window or p1.is_beat_attack:
				p1_would_hit = true

	if not pending_p2_hit and p2.attack_hitbox_active and not p2.hit_registered:
		var atk = p2.get_attack_rect()
		var def_box = p1.get_hitbox_rect()
		if atk.intersects(def_box):
			if not p1.in_parry_window or p2.is_beat_attack:
				p2_would_hit = true

	if p1_would_hit:
		p2.take_hit()
		p1.hit_registered = true
		pending_p1_hit = true
		pending_p1_line = p1.get_attack_line_name()
		_spawn_hit_effect(p2.position + Vector2(-10 * p2.facing, -30), false)

	if p2_would_hit:
		p1.take_hit()
		p2.hit_registered = true
		pending_p2_hit = true
		pending_p2_line = p2.get_attack_line_name()
		_spawn_hit_effect(p1.position + Vector2(-10 * p1.facing, -30), false)

func _resolve_pending_hits() -> void:
	if pending_p1_hit and pending_p2_hit:
		GameManager.record_double_point(pending_p1_line, pending_p2_line)
		_spawn_hit_effect(Vector2((player1.position.x + player2.position.x) * 0.5, PISTE_Y - 30), true)
	elif pending_p1_hit:
		GameManager.record_point("player1", pending_p1_line)
	elif pending_p2_hit:
		GameManager.record_point("player2", pending_p2_line)

	pending_p1_hit = false
	pending_p2_hit = false

func _check_rear_line() -> void:
	if not player1 or not player2:
		return

	# Player1 stepping off left (their rear)
	if player1.position.x <= PISTE_LEFT:
		GameManager.record_point("player2", "Rear Line")
		_spawn_hit_effect(Vector2(PISTE_LEFT, PISTE_Y - 30), false)

	# Player2 stepping off right (their rear)
	if player2.position.x >= PISTE_RIGHT:
		GameManager.record_point("player1", "Rear Line")
		_spawn_hit_effect(Vector2(PISTE_RIGHT, PISTE_Y - 30), false)

func _check_corps_a_corps() -> void:
	if not player1 or not player2:
		return
	var dist = abs(player1.position.x - player2.position.x)
	if dist < CORPS_DISTANCE:
		GameManager.halt_bout("Corps-a-corps")

func _spawn_hit_effect(position: Vector2, is_double: bool) -> void:
	var effect = hit_effects
	if effect:
		if effect.has_method("spawn_hit_effect"):
			effect.spawn_hit_effect(position, is_double)

func _constrain_to_piste() -> void:
	# Allow fencers to move past center (corps-a-corps halts them),
	# but keep them from running too far off-screen.
	player1.position.x = clamp(player1.position.x, PISTE_LEFT - 120, 1320)
	player2.position.x = clamp(player2.position.x, -40, PISTE_RIGHT + 120)

func _on_bout_reset() -> void:
	player1.position = Vector2(PISTE_CENTER - START_DISTANCE, PISTE_Y)
	player2.position = Vector2(PISTE_CENTER + START_DISTANCE, PISTE_Y)
	player1.reset_for_bout()
	player2.reset_for_bout()

	if ai_controller:
		ai_controller.reset()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_end"):
		get_tree().quit()
