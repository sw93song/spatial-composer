extends RefCounted
class_name GestureRecorder

const SAMPLE_INTERVAL_SEC := 1.0 / 60.0
const MIN_POINT_DISTANCE := 0.08
const MAX_POINT_TIME_GAP := 0.30

var _recording := false
var _target_entity_index := -1
var _start_time_sec := 0.0
var _elapsed_sec := 0.0
var _sample_accumulator_sec := 0.0
var _samples: Array = []


func reset() -> void:
	_recording = false
	_target_entity_index = -1
	_start_time_sec = 0.0
	_elapsed_sec = 0.0
	_sample_accumulator_sec = 0.0
	_samples.clear()


func start(entity_index: int, start_time_sec: float, initial_pose: Dictionary) -> void:
	reset()
	_recording = true
	_target_entity_index = entity_index
	_start_time_sec = start_time_sec
	_samples.append(
		TrajectoryTrack.make_key(
			start_time_sec,
			initial_pose.get("position", Vector3.ZERO),
			initial_pose.get("rotation_euler_deg", Vector3.ZERO)
		)
	)


func update(delta: float, position: Vector3, rotation_deg: Vector3) -> void:
	if not _recording:
		return

	_elapsed_sec += delta
	_sample_accumulator_sec += delta
	if _sample_accumulator_sec < SAMPLE_INTERVAL_SEC:
		return

	_sample_accumulator_sec = 0.0
	_append_sample(_start_time_sec + _elapsed_sec, position, rotation_deg)


func finish(final_position: Vector3, final_rotation_deg: Vector3) -> Dictionary:
	if _recording:
		_append_sample(_start_time_sec + _elapsed_sec, final_position, final_rotation_deg)

	var simplified := _simplify_samples(_samples)
	var track := {
		"space": "world",
		"interpolation": "linear",
		"keys": simplified
	}
	reset()
	return track


func is_recording_active() -> bool:
	return _recording


func get_sample_count() -> int:
	return _samples.size()


func get_trail_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for sample in _samples:
		points.push_back(TrajectoryTrack.array_to_vec3(sample.get("position", [0.0, 0.0, 0.0])))
	return points


func _append_sample(time_sec: float, position: Vector3, rotation_deg: Vector3) -> void:
	if not _samples.is_empty():
		var last_sample: Dictionary = _samples[_samples.size() - 1]
		var last_position := TrajectoryTrack.array_to_vec3(last_sample.get("position", [0.0, 0.0, 0.0]))
		if last_position.distance_to(position) < 0.001 and is_equal_approx(float(last_sample.get("t", 0.0)), time_sec):
			return

	_samples.append(TrajectoryTrack.make_key(time_sec, position, rotation_deg))


func _simplify_samples(samples: Array) -> Array:
	if samples.size() <= 2:
		return samples.duplicate(true)

	var kept: Array = [samples[0].duplicate(true)]
	var last_kept_index := 0

	for index in range(1, samples.size() - 1):
		var candidate: Dictionary = samples[index]
		var candidate_position := TrajectoryTrack.array_to_vec3(candidate.get("position", [0.0, 0.0, 0.0]))
		var last_kept: Dictionary = samples[last_kept_index]
		var last_kept_position := TrajectoryTrack.array_to_vec3(last_kept.get("position", [0.0, 0.0, 0.0]))
		var candidate_time := float(candidate.get("t", 0.0))
		var last_kept_time := float(last_kept.get("t", 0.0))

		if candidate_position.distance_to(last_kept_position) >= MIN_POINT_DISTANCE or candidate_time - last_kept_time >= MAX_POINT_TIME_GAP:
			kept.append(candidate.duplicate(true))
			last_kept_index = index

	kept.append(samples[samples.size() - 1].duplicate(true))
	return kept
