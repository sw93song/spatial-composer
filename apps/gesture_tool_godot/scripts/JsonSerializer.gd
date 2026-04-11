extends RefCounted
class_name JsonSerializer


static func project_to_json_string(model: ProjectModel) -> String:
	return JSON.stringify(model.to_dict(), "\t")


static func save_project(path: String, model: ProjectModel) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % path)
		return
	file.store_string(project_to_json_string(model))


static func load_project(path: String, model: ProjectModel) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Project file not found: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for reading: %s" % path)
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Project JSON root must be an object")
		return false

	model.load_from_dict(parsed)
	return true
