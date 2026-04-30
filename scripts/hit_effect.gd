extends Node2D

# Hit effect - visual feedback when a touch lands
# Creates spark particles and flash effect at the point of contact

var sparks: Array[Dictionary] = []
var is_active: bool = false
var effect_timer: float = 0.0

func _process(delta: float) -> void:
	if not is_active:
		return

	effect_timer -= delta
	_update_sparks(delta)

	if effect_timer <= 0:
		is_active = false
		sparks.clear()
		queue_redraw()

func _draw() -> void:
	for spark in sparks:
		var alpha = spark["life"] / spark["max_life"]
		var base_color = spark["color"]
		var color = Color(base_color.r, base_color.g, base_color.b, alpha)
		var size = spark["size"] * alpha
		draw_circle(spark["position"], size, color)

func spawn_hit_effect(hit_position: Vector2, is_double: bool = false) -> void:
	is_active = true
	effect_timer = 0.5
	sparks.clear()

	var count = 12 if is_double else 8
	for i in range(count):
		var angle = randf() * TAU
		var speed = randf_range(40.0, 120.0)
		var color = Color(1.0, randf_range(0.6, 1.0), randf_range(0.1, 0.4))
		if is_double:
			color = Color(1.0, 1.0, randf_range(0.3, 0.6))

		sparks.append({
			"position": hit_position,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"color": color,
			"size": randf_range(2.0, 5.0),
			"life": randf_range(0.2, 0.5),
			"max_life": 0.5,
			"gravity": 80.0
		})

	queue_redraw()

func spawn_parry_spark(block_position: Vector2) -> void:
	is_active = true
	effect_timer = 0.3
	sparks.clear()

	for i in range(6):
		var angle = randf() * PI
		var speed = randf_range(30.0, 80.0)
		sparks.append({
			"position": block_position,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"color": Color(0.4, 0.8, 1.0),
			"size": randf_range(1.5, 3.5),
			"life": randf_range(0.15, 0.3),
			"max_life": 0.3,
			"gravity": 40.0
		})

	queue_redraw()

func _update_sparks(delta: float) -> void:
	var i = 0
	while i < sparks.size():
		var spark = sparks[i]
		spark["life"] -= delta
		var vel = spark["velocity"]
		vel.y += spark["gravity"] * delta
		spark["velocity"] = vel
		spark["position"] = spark["position"] + spark["velocity"] * delta

		if spark["life"] <= 0:
			sparks.remove_at(i)
		else:
			i += 1

	queue_redraw()
