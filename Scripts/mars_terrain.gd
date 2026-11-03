extends Node2D

var chunks: Dictionary = {}

func generate_chunk(chunk: Vector2i, origin: Vector2, chunk_size: float) -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = int(chunk.x * 83492791) ^ int(chunk.y * 2971215073) ^ 6173
	var features: Dictionary = {
		"patches": [],
		"craters": [],
		"rocks": [],
		"cracks": []
	}
	for index: int in 5:
		var center: Vector2 = origin + Vector2(random.randf_range(0.0, chunk_size), random.randf_range(0.0, chunk_size))
		var radius: float = random.randf_range(54.0, 148.0)
		var points: PackedVector2Array = _rough_ellipse(center, radius, random.randi_range(8, 13), random.randf_range(0.55, 0.9), random)
		var color_index: int = random.randi_range(0, 3)
		var patch_colors: Array[Color] = [
			Color(0.34, 0.105, 0.09, 0.24),
			Color(0.74, 0.22, 0.12, 0.18),
			Color(0.91, 0.37, 0.17, 0.13),
			Color(0.22, 0.075, 0.07, 0.2)
		]
		features["patches"].append({"points": points, "color": patch_colors[color_index]})
	for index: int in 3:
		var center: Vector2 = origin + Vector2(random.randf_range(28.0, chunk_size - 28.0), random.randf_range(28.0, chunk_size - 28.0))
		features["craters"].append({
			"center": center,
			"radius": random.randf_range(12.0, 31.0),
			"flatten": random.randf_range(0.68, 0.92),
			"rotation": random.randf_range(0.0, TAU)
		})
	for index: int in 7:
		var center: Vector2 = origin + Vector2(random.randf_range(14.0, chunk_size - 14.0), random.randf_range(14.0, chunk_size - 14.0))
		var rock_size: float = random.randf_range(4.0, 13.0)
		var points: PackedVector2Array = _rough_ellipse(center, rock_size, random.randi_range(4, 7), random.randf_range(0.55, 1.0), random)
		var rock_colors: Array[Color] = [
			Color(0.29, 0.12, 0.11),
			Color(0.55, 0.23, 0.16),
			Color(0.8, 0.36, 0.2)
		]
		features["rocks"].append({
			"points": points,
			"color": rock_colors[random.randi_range(0, rock_colors.size() - 1)]
		})
	for index: int in 4:
		var start: Vector2 = origin + Vector2(random.randf_range(20.0, chunk_size - 20.0), random.randf_range(20.0, chunk_size - 20.0))
		var crack: PackedVector2Array = PackedVector2Array([start])
		var point: Vector2 = start
		var direction: float = random.randf_range(0.0, TAU)
		for segment: int in random.randi_range(2, 4):
			direction += random.randf_range(-0.65, 0.65)
			point += Vector2.RIGHT.rotated(direction) * random.randf_range(7.0, 18.0)
			crack.append(point)
		features["cracks"].append(crack)
	chunks[chunk] = features
	queue_redraw()

func erase_chunk(chunk: Vector2i) -> void:
	chunks.erase(chunk)
	queue_redraw()

func _rough_ellipse(center: Vector2, radius: float, point_count: int, flatten: float, random: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var rotation: float = random.randf_range(0.0, TAU)
	for index: int in point_count:
		var angle: float = TAU * float(index) / float(point_count)
		var varied_radius: float = radius * random.randf_range(0.78, 1.18)
		var point: Vector2 = Vector2(cos(angle) * varied_radius, sin(angle) * varied_radius * flatten)
		points.append(center + Vector2(point.x * cos(rotation) - point.y * sin(rotation), point.x * sin(rotation) + point.y * cos(rotation)))
	return points

func _draw() -> void:
	for features_variant: Variant in chunks.values():
		var features: Dictionary = features_variant
		for patch: Dictionary in features["patches"]:
			draw_colored_polygon(patch["points"], patch["color"])
		for crack: PackedVector2Array in features["cracks"]:
			draw_polyline(crack, Color(0.2, 0.065, 0.06, 0.48), 2.0, false)
			draw_polyline(crack, Color(0.92, 0.36, 0.18, 0.27), 1.0, false)
		for crater: Dictionary in features["craters"]:
			var center: Vector2 = crater["center"]
			var radius: float = crater["radius"]
			var flatten: float = crater["flatten"]
			draw_set_transform(center, float(crater["rotation"]), Vector2(1.0, flatten))
			draw_circle(Vector2.ZERO, radius, Color(0.19, 0.065, 0.06, 0.5))
			draw_circle(Vector2.ZERO, radius * 0.72, Color(0.43, 0.13, 0.095, 0.8))
			draw_arc(Vector2.ZERO, radius * 0.84, PI * 0.08, PI * 0.92, 20, Color(1.0, 0.46, 0.24, 0.42), 2.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for rock: Dictionary in features["rocks"]:
			draw_colored_polygon(rock["points"], rock["color"])
			var rock_points: PackedVector2Array = rock["points"]
			if rock_points.size() >= 3:
				draw_line(rock_points[0], rock_points[1], Color(1.0, 0.53, 0.3, 0.42), 1.0)
