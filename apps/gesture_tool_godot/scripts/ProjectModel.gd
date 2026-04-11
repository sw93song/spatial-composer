extends RefCounted
class_name ProjectModel

var format_version: int = 1
var project := {}
var listener := {}
var sources: Array = []
var groups: Array = []


func _init() -> void:
	reset_default()


func reset_default() -> void:
	format_version = 1
	project = {
		"title": "untitled",
		"sample_rate": 48000,
		"duration_sec": 8.0,
		"tempo_bpm": 120.0
	}
	listener = {
		"id": "listener_main",
		"track": TrajectoryTrack.make_default_track()
	}
	sources = []
	groups = []


func load_from_dict(data: Dictionary) -> void:
	format_version = int(data.get("format_version", 1))
	project = {
		"title": str(data.get("project", {}).get("title", "untitled")),
		"sample_rate": int(data.get("project", {}).get("sample_rate", 48000)),
		"duration_sec": float(data.get("project", {}).get("duration_sec", 8.0)),
		"tempo_bpm": float(data.get("project", {}).get("tempo_bpm", 120.0))
	}
	listener = _normalize_listener(data.get("listener", {}))
	sources = []
	for source_value in data.get("sources", []):
		if source_value is Dictionary:
			sources.append(_normalize_source(source_value))
	groups = data.get("groups", []).duplicate(true)


func to_dict() -> Dictionary:
	return {
		"format_version": format_version,
		"project": project.duplicate(true),
		"listener": listener.duplicate(true),
		"sources": sources.duplicate(true),
		"groups": groups.duplicate(true)
	}


func add_source() -> int:
	var source_index := sources.size() + 1
	var source := {
		"id": _make_unique_source_id("src_%02d" % source_index),
		"audio_asset": "assets/demo.wav",
		"gain_db": 0.0,
		"track": TrajectoryTrack.make_default_track()
	}
	var first_key = source["track"]["keys"][0]
	first_key["position"] = [2.0 + float(sources.size()), 0.0, 0.0]
	source["track"]["keys"][0] = first_key
	sources.append(source)
	return sources.size()


func remove_source(source_index: int) -> void:
	if source_index < 0 or source_index >= sources.size():
		return
	sources.remove_at(source_index)


func get_entity_count() -> int:
	return 1 + sources.size()


func get_entity_label(entity_index: int) -> String:
	if entity_index == 0:
		return "listener: %s" % listener.get("id", "listener_main")
	var source_index := entity_index - 1
	if source_index >= 0 and source_index < sources.size():
		return "source: %s" % sources[source_index].get("id", "src")
	return "unknown"


func get_entity(entity_index: int) -> Dictionary:
	if entity_index == 0:
		return listener
	var source_index := entity_index - 1
	if source_index >= 0 and source_index < sources.size():
		return sources[source_index]
	return {}


func set_entity(entity_index: int, entity: Dictionary) -> void:
	if entity_index == 0:
		listener = entity
		return
	var source_index := entity_index - 1
	if source_index >= 0 and source_index < sources.size():
		sources[source_index] = entity


func get_entity_track(entity_index: int) -> Dictionary:
	return get_entity(entity_index).get("track", TrajectoryTrack.make_default_track())


func get_entity_pose(entity_index: int, time_sec: float) -> Dictionary:
	return TrajectoryTrack.evaluate(get_entity_track(entity_index), time_sec)


func set_project_title(title: String) -> void:
	project["title"] = title


func set_duration(duration_sec: float) -> void:
	project["duration_sec"] = max(duration_sec, 0.1)


func _normalize_listener(data: Dictionary) -> Dictionary:
	return {
		"id": str(data.get("id", "listener_main")),
		"track": TrajectoryTrack.normalize_track(data.get("track", TrajectoryTrack.make_default_track()))
	}


func _normalize_source(data: Dictionary) -> Dictionary:
	return {
		"id": str(data.get("id", _make_unique_source_id("src"))),
		"audio_asset": str(data.get("audio_asset", "assets/demo.wav")),
		"gain_db": float(data.get("gain_db", 0.0)),
		"track": TrajectoryTrack.normalize_track(data.get("track", TrajectoryTrack.make_default_track()))
	}


func _make_unique_source_id(base_id: String) -> String:
	var candidate := base_id
	var suffix := 1
	while _id_exists(candidate):
		candidate = "%s_%d" % [base_id, suffix]
		suffix += 1
	return candidate


func _id_exists(candidate: String) -> bool:
	if listener.get("id", "") == candidate:
		return true
	for source in sources:
		if source.get("id", "") == candidate:
			return true
	return false
