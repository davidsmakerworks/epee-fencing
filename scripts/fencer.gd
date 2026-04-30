extends CharacterBody2D

# Procedural fencer character - draws itself without external sprites
# Full epee fencing mechanics: advance, retreat, lunge, attack, parry

signal hit_dealt
signal hit_taken

enum FencerState {
	IDLE,
	EN_GARDE,
	ADVANCE,
	RETREAT,
	ATTACK,
	LUNGE,
	PARRY,
	RECOVER,
	HIT
}

# Movement
@export var move_speed: float = 100.0
@export var advance_speed: float = 90.0
@export var retreat_speed: float = 130.0
@export var lunge_speed: float = 350.0
@export var recovery_time: float = 0.35

# Combat
@export var attack_duration: float = 0.2
@export var attack_range: float = 140.0
@export var parry_duration: float = 0.3
@export var parry_window: float = 0.12

# Identity
@export var fencer_name: String = "Fencer"
@export var is_player: bool = true
@export var facing: int = 1
@export var team_color: Color = Color(0.2, 0.5, 0.9)

# State
var state: FencerState = FencerState.IDLE
var state_timer: float = 0.0
var is_attacking: bool = false
var is_parrying: bool = false
var in_parry_window: bool = false
var can_act: bool = true
var is_prepared: bool = false
var lunge_progress: float = 0.0
var hit_registered: bool = false
var flash_timer: float = 0.0
var blade_angle: float = 0.0
var target_blade_angle: float = 0.0
var body_sway: float = 0.0
var arm_extend: float = 0.0
var target_arm_extend: float = 0.0
var attack_hitbox_active: bool = false

# Dimensions
const FENCER_HEIGHT: float = 100.0
const BODY_WIDTH: float = 24.0
const BLADE_LENGTH: float = 90.0

# Hitbox
var _hitbox_rect: Rect2 = Rect2()
var _attack_rect: Rect2 = Rect2()

func _ready() -> void:
	_update_hitboxes()

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.FOUGHT:
		return

	state_timer -= delta
	flash_timer -= delta
	body_sway = sin(Time.get_ticks_msec() * 0.003) * 2.0
	arm_extend = lerp(arm_extend, target_arm_extend, delta * 15.0)
	blade_angle = lerp(blade_angle, target_blade_angle, delta * 12.0)

	match state:
		FencerState.IDLE:
			_idle_update(delta)
		FencerState.EN_GARDE:
			_engarde_update(delta)
		FencerState.ADVANCE:
			_advance_update(delta)
		FencerState.RETREAT:
			_retreat_update(delta)
		FencerState.ATTACK:
			_attack_update(delta)
		FencerState.LUNGE:
			_lunge_update(delta)
		FencerState.PARRY:
			_parry_update(delta)
		FencerState.RECOVER:
			_recover_update(delta)
		FencerState.HIT:
			_hit_update(delta)

	_update_hitboxes()

func _draw() -> void:
	var base_y = 0.0
	var sway_x = body_sway * 0.5
	var f = float(facing)

	# Colors
	var white = Color(0.92, 0.92, 0.95)
	var lamé = Color(0.82, 0.75, 0.15)
	var boot = Color(0.18, 0.18, 0.22)
	var mask = Color(0.7, 0.72, 0.75)
	var skin = Color(0.82, 0.62, 0.52)
	var glove = Color(0.88, 0.88, 0.9)
	var accent = team_color

	# Flash effect when hit
	var modulate = 1.0
	if flash_timer > 0:
		modulate = 1.0 + sin(flash_timer * 40) * 0.5

	# === BOOTS ===
	var boot_h = 18.0
	var boot_w = 10.0
	draw_rect(Rect2(-8 + sway_x * 0.3, base_y + FENCER_HEIGHT - boot_h - 5, boot_w, boot_h), boot * modulate)
	draw_rect(Rect2(4 + sway_x * 0.3, base_y + FENCER_HEIGHT - boot_h - 5, boot_w, boot_h), boot * modulate)

	# === LEGS (breeches) ===
	var leg_h = 16.0
	draw_rect(Rect2(-10 + sway_x * 0.4, base_y + FENCER_HEIGHT - boot_h - leg_h - 5, 12, leg_h), white * modulate)
	draw_rect(Rect2(2 + sway_x * 0.4, base_y + FENCER_HEIGHT - boot_h - leg_h - 5, 12, leg_h), white * modulate)

	# === TORSO (lamé jacket) ===
	var torso_h = 34.0
	var torso_y = base_y + FENCER_HEIGHT - boot_h - leg_h - torso_h - 5
	draw_rect(Rect2(-BODY_WIDTH * 0.5 + sway_x, torso_y, BODY_WIDTH, torso_h), white * modulate)
	draw_rect(Rect2(-BODY_WIDTH * 0.35 + sway_x, torso_y + 2, BODY_WIDTH * 0.7, torso_h - 4), lamé * modulate)
	draw_rect(Rect2(-2 + sway_x, torso_y, 4, torso_h), accent * modulate)

	# === BACK ARM (guard position) ===
	var back_arm_y = torso_y + 6
	var back_arm_start_x = (-BODY_WIDTH * 0.5 - 12) * f + sway_x
	var back_arm_end_x = (-BODY_WIDTH * 0.5) * f + sway_x
	draw_rect(Rect2(min(back_arm_start_x, back_arm_end_x), back_arm_y, abs(back_arm_end_x - back_arm_start_x), 5), white * modulate)
	var hand_start_x = (-BODY_WIDTH * 0.5 - 16) * f + sway_x
	var hand_end_x = (-BODY_WIDTH * 0.5 - 10) * f + sway_x
	draw_rect(Rect2(min(hand_start_x, hand_end_x), back_arm_y - 2, abs(hand_end_x - hand_start_x), 9), glove * modulate)

	# === FRONT ARM (weapon arm) ===
	var blade_y_offset = -8.0 if is_player else 8.0
	var front_arm_base_y = torso_y + 6 + blade_y_offset
	var extend_px = arm_extend * 30.0
	var shoulder_x = BODY_WIDTH * 0.3 * f + sway_x
	var upper_end_x = shoulder_x + (8 + extend_px * 0.3) * f
	draw_rect(Rect2(min(shoulder_x, upper_end_x), front_arm_base_y, abs(upper_end_x - shoulder_x), 5), white * modulate)
	var forearm_end_x = upper_end_x + (10 + extend_px * 0.7) * f
	draw_rect(Rect2(min(upper_end_x, forearm_end_x), front_arm_base_y - 1, abs(forearm_end_x - upper_end_x), 5), white * modulate)
	var glove_x = forearm_end_x
	draw_rect(Rect2(min(glove_x, glove_x + 8 * f), front_arm_base_y - 3, 8, 9), glove * modulate)

	# === EPEE BLADE ===
	var blade_base_x = glove_x + 8 * f
	var blade_base_y = front_arm_base_y
	var blade_end_x = blade_base_x + BLADE_LENGTH * f
	var blade_end_y = blade_base_y + blade_angle * 0.5

	# Blade (steel) — tinted by team color for visibility
	var blade_color = Color(0.75, 0.78, 0.85) + (accent * 0.15)
	blade_color = Color(blade_color.r * modulate, blade_color.g * modulate, blade_color.b * modulate)
	draw_line(Vector2(blade_base_x, blade_base_y), Vector2(blade_end_x, blade_end_y), blade_color, 2.5)
	# Blade highlight
	draw_line(Vector2(blade_base_x, blade_base_y - 0.5), Vector2(blade_end_x, blade_end_y - 0.5), Color(0.9, 0.92, 0.95) * modulate, 1.0)

	# Bell guard
	draw_circle(Vector2(blade_base_x, blade_base_y), 5, Color(0.55, 0.58, 0.62) * modulate)

	# === HEAD / MASK ===
	var head_y = torso_y - 18.0
	var head_x = sway_x

	draw_rect(Rect2(-10 + head_x, head_y - 14, 20, 22), mask * modulate)
	for mx in range(-8, 9, 3):
		draw_line(Vector2(mx + head_x, head_y - 12), Vector2(mx + head_x, head_y + 6), Color(0.35, 0.35, 0.4) * modulate, 0.5)
	for my in range(-12, 7, 3):
		draw_line(Vector2(-8 + head_x, my + head_y), Vector2(8 + head_x, my + head_y), Color(0.35, 0.35, 0.4) * modulate, 0.5)

	draw_rect(Rect2(-5 + head_x, head_y - 8, 10, 10), skin * modulate)
	draw_rect(Rect2(-4 * f + head_x, head_y - 5, 3, 2), Color(0.15, 0.15, 0.2) * modulate)
	draw_rect(Rect2(2 * f + head_x, head_y - 5, 3, 2), Color(0.15, 0.15, 0.2) * modulate)
	draw_rect(Rect2(-11 + head_x, head_y - 14, 22, 3), accent * modulate)

	# === STATE INDICATORS ===
	if state == FencerState.PARRY and in_parry_window:
		draw_arc(Vector2((blade_base_x + blade_end_x) * 0.5, blade_base_y - 20), 25, 0, TAU, 12, Color(0.3, 1.0, 0.3, 0.4), 2.0, true)

	if state == FencerState.HIT:
		draw_rect(Rect2(-BODY_WIDTH * 0.6 + sway_x, torso_y - 20, BODY_WIDTH * 1.2, torso_h + 25), Color(1, 0.3, 0.3, 0.3))

# State updates
func _idle_update(delta: float) -> void:
	target_blade_angle = 10.0 if is_player else 5.0
	target_arm_extend = 0.0
	velocity.x = 0

	if is_player:
		if Input.is_action_just_pressed("fencer1_prepare"):
			enter_en_garde()
		elif Input.is_action_pressed("fencer1_move_forward"):
			enter_en_garde()
		elif Input.is_action_pressed("fencer1_move_backward"):
			enter_en_garde()

func _engarde_update(delta: float) -> void:
	target_blade_angle = -30.0 if is_player else 5.0
	target_arm_extend = 0.5
	velocity.x = 0

	if is_player:
		if Input.is_action_just_pressed("fencer1_attack"):
			_start_attack()
		elif Input.is_action_just_pressed("fencer1_lunge"):
			_start_lunge()
		elif Input.is_action_just_pressed("fencer1_parry"):
			_start_parry()
		elif Input.is_action_pressed("fencer1_move_forward"):
			_start_advance()
		elif Input.is_action_pressed("fencer1_move_backward"):
			_start_retreat()

func _advance_update(delta: float) -> void:
	velocity.x = advance_speed * facing
	target_blade_angle = -20.0
	target_arm_extend = 0.4
	move_and_slide()

	if state_timer <= 0:
		if is_player and Input.is_action_pressed("fencer1_move_forward"):
			state_timer = 0.1
		else:
			state = FencerState.EN_GARDE
			state_timer = 0.15

func _retreat_update(delta: float) -> void:
	velocity.x = -retreat_speed * facing
	target_blade_angle = -35.0
	target_arm_extend = 0.3
	move_and_slide()

	if state_timer <= 0:
		if is_player and Input.is_action_pressed("fencer1_move_backward"):
			state_timer = 0.1
		else:
			state = FencerState.EN_GARDE
			state_timer = 0.15

func _attack_update(delta: float) -> void:
	if state_timer > attack_duration * 0.4:
		velocity.x = move_speed * 0.4 * facing
		target_blade_angle = -5.0
		target_arm_extend = 1.0
		attack_hitbox_active = false
	else:
		velocity.x = move_speed * 0.15 * facing
		target_blade_angle = 5.0
		target_arm_extend = 1.0
		attack_hitbox_active = true

	move_and_slide()

	if state_timer <= 0:
		state = FencerState.RECOVER
		state_timer = recovery_time
		attack_hitbox_active = false

func _lunge_update(delta: float) -> void:
	lunge_progress += delta * 3.5

	if lunge_progress < 0.3:
		velocity.x = lunge_speed * facing
	elif lunge_progress < 0.7:
		velocity.x = lunge_speed * 0.6 * facing
		attack_hitbox_active = true
	else:
		velocity.x = lunge_speed * 0.15 * facing
		if lunge_progress >= 0.8:
			attack_hitbox_active = false

	target_blade_angle = lerp(-20.0, 5.0, lunge_progress)
	target_arm_extend = lerp(0.5, 1.0, lunge_progress)
	move_and_slide()

	if lunge_progress >= 1.0:
		state = FencerState.RECOVER
		state_timer = recovery_time * 1.5
		lunge_progress = 0.0
		attack_hitbox_active = false

func _parry_update(delta: float) -> void:
	velocity.x = 0
	target_arm_extend = 0.6

	if state_timer > parry_duration - parry_window:
		in_parry_window = true
		target_blade_angle = 50.0
	else:
		in_parry_window = false
		target_blade_angle = -25.0

	if state_timer <= 0:
		state = FencerState.EN_GARDE
		is_parrying = false
		in_parry_window = false
		can_act = true

func _recover_update(delta: float) -> void:
	velocity.x = 0
	target_blade_angle = -25.0
	target_arm_extend = 0.5
	attack_hitbox_active = false

	if state_timer <= 0:
		state = FencerState.EN_GARDE
		can_act = true

func _hit_update(delta: float) -> void:
	velocity.x = -60.0 * facing
	target_blade_angle = 30.0
	target_arm_extend = 0.2
	move_and_slide()

	if state_timer <= 0:
		state = FencerState.EN_GARDE
		hit_registered = false
		can_act = true

# Actions
func enter_en_garde() -> void:
	state = FencerState.EN_GARDE
	is_prepared = true
	state_timer = 0.1

func _start_advance() -> void:
	if state != FencerState.EN_GARDE and state != FencerState.ADVANCE and state != FencerState.IDLE:
		return
	if state == FencerState.IDLE:
		is_prepared = true
	state = FencerState.ADVANCE
	state_timer = 0.2

func _start_retreat() -> void:
	if state != FencerState.EN_GARDE and state != FencerState.RETREAT and state != FencerState.IDLE:
		return
	if state == FencerState.IDLE:
		is_prepared = true
	state = FencerState.RETREAT
	state_timer = 0.2

func _start_attack() -> void:
	if not can_act:
		return
	state = FencerState.ATTACK
	state_timer = attack_duration
	is_attacking = true
	hit_registered = false
	can_act = false

func _start_lunge() -> void:
	if not can_act:
		return
	state = FencerState.LUNGE
	lunge_progress = 0.0
	is_attacking = true
	hit_registered = false
	can_act = false

func _start_parry() -> void:
	if not can_act:
		return
	state = FencerState.PARRY
	state_timer = parry_duration
	is_parrying = true
	in_parry_window = false
	can_act = false

func take_hit() -> void:
	if in_parry_window:
		return
	if state == FencerState.HIT or hit_registered:
		return

	hit_registered = true
	state = FencerState.HIT
	state_timer = 0.4
	flash_timer = 0.25
	emit_signal("hit_taken")

func _update_hitboxes() -> void:
	var extend_offset = arm_extend * 30.0
	var blade_reach = 12 + 18 + extend_offset + BLADE_LENGTH
	var attack_w = blade_reach

	if facing > 0:
		_attack_rect = Rect2(
			position.x + BODY_WIDTH * 0.5,
			position.y + FENCER_HEIGHT * 0.1,
			attack_w,
			35.0
		)
	else:
		_attack_rect = Rect2(
			position.x - BODY_WIDTH * 0.5 - attack_w,
			position.y + FENCER_HEIGHT * 0.1,
			attack_w,
			35.0
		)

	_hitbox_rect = Rect2(
		position.x - BODY_WIDTH * 0.5,
		position.y - 14,
		BODY_WIDTH,
		FENCER_HEIGHT + 20
	)

func get_attack_rect() -> Rect2:
	return _attack_rect

func get_hitbox_rect() -> Rect2:
	return _hitbox_rect

func is_in_attack_state() -> bool:
	return state == FencerState.ATTACK or state == FencerState.LUNGE

func reset_for_bout() -> void:
	state = FencerState.EN_GARDE
	is_prepared = true
	is_attacking = false
	is_parrying = false
	can_act = true
	hit_registered = false
	arm_extend = 0.0
	target_arm_extend = 0.5
	blade_angle = 0.0
	target_blade_angle = -30.0 if is_player else 5.0
	attack_hitbox_active = false
	velocity = Vector2.ZERO
