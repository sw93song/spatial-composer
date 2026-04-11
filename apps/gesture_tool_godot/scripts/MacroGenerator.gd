extends RefCounted
class_name MacroGenerator


static func bake_orbit(center: Vector3, radius: float, duration_sec: float, turns: float = 1.0, start_time: float = 0.0, key_count: int = 16) -> Dictionary:
	var track := {
		"space": "world",
		"interpolation": "linear",
		"keys": []
	}

	var resolved_key_count := max(key_count, 4)
	for index in range(resolved_key_count + 1):
		var alpha := float(index) / float(resolved_key_count)
		var angle := TAU * turns * alpha
		var position := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var rotation_deg := Vector3(0.0, rad_to_deg(angle) + 90.0, 0.0)
		track["keys"].append(
			TrajectoryTrack.make_key(
				start_time + alpha * duration_sec,
				position,
				rotation_deg
			)
		)

	return track
