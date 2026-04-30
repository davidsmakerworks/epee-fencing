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

var last_p1_hit: bool = false
var last_p2_hit: bool = false

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
		_check_hits()
		_constrain_to_piste()

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
			if not p2.in_parry_window:
				p1.hit_registered = true
				p1_hits = true
				_spawn_hit_effect(p2.position + Vector2(-10 * p2.facing, -30), false)

	# Check if Player2's attack hits Player1
	if p2.attack_hitbox_active and not p2.hit_registered:
		var atk = p2.get_attack_rect()
		var def_box = p1.get_hitbox_rect()
		if atk.intersects(def_box):
			p1.take_hit()
			if not p1.in_parry_window:
				p2.hit_registered = true
				p2_hits = true
				_spawn_hit_effect(p1.position + Vector2(-10 * p1.facing, -30), false)

	# Epee: simultaneous hits both score
	if p1_hits and p2_hits:
		GameManager.record_double_point()
		_spawn_hit_effect(Vector2((p1.position.x + p2.position.x) * 0.5, PISTE_Y - 30), true)
	elif p1_hits:
		GameManager.record_point("player1")
	elif p2_hits:
		GameManager.record_point("player2")

func _spawn_hit_effect(position: Vector2, is_double: bool) -> void:
	var effect = hit_effects
	if effect:
		if effect.has_method("spawn_hit_effect"):
			effect.spawn_hit_effect(position, is_double)

func _constrain_to_piste() -> void:
	player1.position.x = clamp(player1.position.x, PISTE_LEFT + 30, PISTE_CENTER)
	player2.position.x = clamp(player2.position.x, PISTE_CENTER, PISTE_RIGHT - 30)

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
