extends RefCounted
class_name TrajectoryTrack

static func make_default_track() -> Dictionary:
	return {
		"space": "world",
		"interpolation": "linear",
		"keys": [
			make_key(0.0, Vector3.ZERO, Vector3.ZERO)
		]
	}


static func make_key(time_sec: float, position: Vector3, rotation_deg: Vector3) -> Dictionary:
	return {
		"t": time_sec,
		"position": vec3_to_array(position),
		"rotation_euler_deg": vec3_to_array(rotation_deg),
		"ease_in": "auto",
		"ease_out": "auto"
	}


static func normalize_track(track: Dictionary) -> Dictionary:
	var normalized := {
		"space": str(track.get("space", "world")),
		"interpolation": str(track.get("interpolation", "linear")),
		"keys": []
	}

	var input_keys: Array = track.get("keys", [])
	for key_value in input_keys:
		if key_value is Dictionary:
			var key: Dictionary = key_value
			normalized["keys"].append({
				"t": float(key.get("t", 0.0)),
				"position": vec3_to_array(array_to_vec3(key.get("position", [0.0, 0.0, 0.0]))),
				"rotation_euler_deg": vec3_to_array(array_to_vec3(key.get("rotation_euler_deg", [0.0, 0.0, 0.0]))),
				"ease_in": str(key.get("ease_in", "auto")),
				"ease_out": str(key.get("ease_out", "auto"))
			})

	if normalized["keys"].is_empty():
		normalized["keys"].append(make_key(0.0, Vector3.ZERO, Vector3.ZERO))

	sort_keys(normalized)
	return normalized


static func add_or_replace_key(track: Dictionary, key: Dictionary) -> int:
	var keys: Array = track.get("keys", [])
	var target_time := float(key.get("t", 0.0))

	for index in range(keys.size()):
		if is_equal_approx(float(keys[index].get("t", -9999.0)), target_time):
			keys[index] = key
			track["keys"] = keys
			sort_keys(track)
			return find_key_index_at_time(track, target_time)

	keys.append(key)
	track["keys"] = keys
	sort_keys(track)
	return find_key_index_at_time(track, target_time)


static func remove_key(track: Dictionary, index: int) -> void:
	var keys: Array = track.get("keys", [])
	if index < 0 or index >= keys.size():
		return
	keys.remove_at(index)
	if keys.is_empty():
		keys.append(make_key(0.0, Vector3.ZERO, Vector3.ZERO))
	track["keys"] = keys
	sort_keys(track)


static func update_key(track: Dictionary, index: int, key: Dictionary) -> void:
	var keys: Array = track.get("keys", [])
	if index < 0 or index >= keys.size():
		return
	keys[index] = key
	track["keys"] = keys
	sort_keys(track)


static func get_key(track: Dictionary, index: int) -> Dictionary:
	var keys: Array = track.get("keys", [])
	if index < 0 or index >= keys.size():
		return make_key(0.0, Vector3.ZERO, Vector3.ZERO)
	return keys[index]


static func find_key_index_at_time(track: Dictionary, time_sec: float) -> int:
	var keys: Array = track.get("keys", [])
	for index in range(keys.size()):
		if is_equal_approx(float(keys[index].get("t", 0.0)), time_sec):
			return index
	return -1


static func sort_keys(track: Dictionary) -> void:
	var keys: Array = track.get("keys", [])
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("t", 0.0)) < float(b.get("t", 0.0))
	)
	track["keys"] = keys


static func evaluate(track: Dictionary, time_sec: float) -> Dictionary:
	var keys: Array = track.get("keys", [])
	if keys.is_empty():
		return {
			"position": Vector3.ZERO,
			"rotation_euler_deg": Vector3.ZERO
		}

	var first_key: Dictionary = keys[0]
	if time_sec <= float(first_key.get("t", 0.0)):
		return {
			"position": array_to_vec3(first_key.get("position", [0.0, 0.0, 0.0])),
			"rotation_euler_deg": array_to_vec3(first_key.get("rotation_euler_deg", [0.0, 0.0, 0.0]))
		}

	var last_key: Dictionary = keys[keys.size() - 1]
	if time_sec >= float(last_key.get("t", 0.0)):
		return {
			"position": array_to_vec3(last_key.get("position", [0.0, 0.0, 0.0])),
			"rotation_euler_deg": array_to_vec3(last_key.get("rotation_euler_deg", [0.0, 0.0, 0.0]))
		}

	for index in range(1, keys.size()):
		var a: Dictionary = keys[index - 1]
		var b: Dictionary = keys[index]
		var a_time := float(a.get("t", 0.0))
		var b_time := float(b.get("t", 0.0))
		if time_sec <= b_time:
			var span := max(b_time - a_time, 0.0001)
			var alpha := clamp((time_sec - a_time) / span, 0.0, 1.0)
			return {
				"position": array_to_vec3(a.get("position", [0.0, 0.0, 0.0])).lerp(
					array_to_vec3(b.get("position", [0.0, 0.0, 0.0])),
					alpha
				),
				"rotation_euler_deg": array_to_vec3(a.get("rotation_euler_deg", [0.0, 0.0, 0.0])).lerp(
					array_to_vec3(b.get("rotation_euler_deg", [0.0, 0.0, 0.0])),
					alpha
				)
			}

	return {
		"position": Vector3.ZERO,
		"rotation_euler_deg": Vector3.ZERO
	}


static func sample_positions(track: Dictionary, sample_count: int = 64) -> PackedVector3Array:
	var points := PackedVector3Array()
	var keys: Array = track.get("keys", [])
	if keys.is_empty():
		return points

	if keys.size() == 1:
		points.push_back(array_to_vec3(keys[0].get("position", [0.0, 0.0, 0.0])))
		return points

	var start_time := float(keys[0].get("t", 0.0))
	var end_time := float(keys[keys.size() - 1].get("t", 0.0))
	var resolved_samples := max(sample_count, keys.size())

	for index in range(resolved_samples + 1):
		var alpha := float(index) / float(resolved_samples)
		var time_sec := lerp(start_time, end_time, alpha)
		var pose: Dictionary = evaluate(track, time_sec)
		points.push_back(pose.get("position", Vector3.ZERO))

	return points


static func vec3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func array_to_vec3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
