extends Node2D

# Blade trail effect - shows motion trail during attacks and lunges

@export var trail_color: Color = Color(0.7, 0.8, 1.0, 0.6)

var target_fencer: CharacterBody2D
var trail_points: Array[Vector2] = []
var max_trail_length: int = 12
var trail_alpha: float = 0.0
var target_alpha: float = 0.0
var sample_timer: float = 0.0

func _ready() -> void:
	target_fencer = get_parent()

func _process(delta: float) -> void:
	if not target_fencer:
		return

	sample_timer -= delta
	trail_alpha = lerp(trail_alpha, target_alpha, delta * 10.0)

	var is_moving = target_fencer.is_in_attack_state()
	if is_moving:
		target_alpha = 0.5
		if sample_timer <= 0:
			_sample_blade_tip()
			sample_timer = 0.02
	else:
		target_alpha = 0.0
		if trail_alpha < 0.01:
			trail_points.clear()

	sample_timer = max(sample_timer, 0.0)

	queue_redraw()

func _sample_blade_tip() -> void:
	var blade_tip = _calculate_blade_tip()
	trail_points.append(blade_tip)

	if trail_points.size() > max_trail_length:
		trail_points.remove_at(0)

func _calculate_blade_tip() -> Vector2:
	if target_fencer and target_fencer.has_method("_get_blade_tip"):
		return target_fencer._get_blade_tip()
	var fencer_pos = target_fencer.position
	var extend = target_fencer.arm_extend
	var blade_len = 90.0
	var facing = target_fencer.facing
	var blade_ang = target_fencer.blade_angle
	var arm_offset = 26 + extend * 30.0
	var tip_x = fencer_pos.x + (12 + arm_offset + blade_len) * facing
	var tip_y = fencer_pos.y + 30 + blade_ang * 0.5
	return Vector2(tip_x, tip_y)

func _draw() -> void:
	if trail_points.size() < 2:
		return

	for i in range(1, trail_points.size()):
		var alpha = (float(i) / float(trail_points.size())) * trail_alpha
		var width = (float(i) / float(trail_points.size())) * 3.0
		var color = Color(trail_color.r, trail_color.g, trail_color.b, alpha)

		draw_line(trail_points[i - 1], trail_points[i], color, width)
