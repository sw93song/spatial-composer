extends Node3D
class_name WorldView

signal entity_selected(entity_index: int)
signal ground_clicked(position: Vector3)
signal ground_dragged(position: Vector3)
signal drag_state_changed(active: bool)

var _camera: Camera3D
var _world_nodes: Node3D
var _entity_snapshots: Array = []
var _dragging := false


func _ready() -> void:
	_build_static_scene()
	set_process_unhandled_input(true)


func display_project(model: ProjectModel, time_sec: float, selected_entity_index: int, raw_trail := PackedVector3Array()) -> void:
	if _world_nodes == null:
		return

	_entity_snapshots.clear()
	for child in _world_nodes.get_children():
		child.free()

	_spawn_entity(
		0,
		model.listener,
		TrajectoryTrack.evaluate(model.listener.get("track", {}), time_sec),
		Color(0.92, 0.92, 0.96),
		selected_entity_index == 0,
		true
	)

	for source_index in range(model.sources.size()):
		var color := Color.from_hsv(float(source_index % 8) / 8.0, 0.75, 0.95)
		_spawn_entity(
			source_index + 1,
			model.sources[source_index],
			TrajectoryTrack.evaluate(model.sources[source_index].get("track", {}), time_sec),
			color,
			selected_entity_index == source_index + 1,
			false
		)

	if raw_trail.size() >= 2:
		var trail_mesh := MeshInstance3D.new()
		trail_mesh.mesh = _build_polyline_mesh(raw_trail, Color(0.95, 0.95, 0.95))
		_world_nodes.add_child(trail_mesh)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var picked_entity := _pick_entity(event.position)
			if picked_entity >= 0:
				entity_selected.emit(picked_entity)
				_dragging = true
				drag_state_changed.emit(true)
			else:
				var ground_hit = _project_mouse_to_ground(event.position)
				if ground_hit != null:
					ground_clicked.emit(ground_hit)
		elif _dragging:
			_dragging = false
			drag_state_changed.emit(false)

	if event is InputEventMouseMotion and _dragging:
		var drag_hit = _project_mouse_to_ground(event.position)
		if drag_hit != null:
			ground_dragged.emit(drag_hit)


func _build_static_scene() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(7.0, 6.0, 7.0)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	add_child(_camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	add_child(light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(16.0, 16.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.12, 0.15, 0.18)
	floor_material.roughness = 1.0
	floor.material_override = floor_material
	add_child(floor)

	var grid := MeshInstance3D.new()
	grid.mesh = _build_grid_mesh(16, 1.0)
	add_child(grid)

	_world_nodes = Node3D.new()
	add_child(_world_nodes)


func _spawn_entity(entity_index: int, entity: Dictionary, pose: Dictionary, color: Color, selected: bool, is_listener: bool) -> void:
	var path_mesh_instance := MeshInstance3D.new()
	path_mesh_instance.mesh = _build_path_mesh(entity.get("track", {}), color, selected)
	_world_nodes.add_child(path_mesh_instance)

	var marker := MeshInstance3D.new()
	if is_listener:
		var sphere := SphereMesh.new()
		sphere.radius = 0.2
		marker.mesh = sphere
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 0.35
		marker.mesh = box

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = selected
	material.emission = color
	material.emission_energy_multiplier = 0.6 if selected else 0.0
	marker.material_override = material
	marker.position = pose.get("position", Vector3.ZERO)
	marker.rotation_degrees = pose.get("rotation_euler_deg", Vector3.ZERO)
	if selected:
		marker.scale = Vector3.ONE * 1.2
	_world_nodes.add_child(marker)

	_entity_snapshots.append({
		"entity_index": entity_index,
		"position": marker.position,
		"radius": 0.45 if selected else 0.35
	})


func _build_path_mesh(track: Dictionary, color: Color, selected: bool) -> ImmediateMesh:
	return _build_polyline_mesh(
		TrajectoryTrack.sample_positions(track, 72),
		color.lightened(0.2 if selected else 0.0)
	)


func _build_polyline_mesh(points: PackedVector3Array, color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	if points.size() < 2:
		return mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color

	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for point in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh


func _build_grid_mesh(size: int, spacing: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.24, 0.28, 0.32)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in range(-size, size + 1):
		mesh.surface_add_vertex(Vector3(i * spacing, 0.01, -size * spacing))
		mesh.surface_add_vertex(Vector3(i * spacing, 0.01, size * spacing))
		mesh.surface_add_vertex(Vector3(-size * spacing, 0.01, i * spacing))
		mesh.surface_add_vertex(Vector3(size * spacing, 0.01, i * spacing))
	mesh.surface_end()
	return mesh


func _pick_entity(screen_position: Vector2) -> int:
	if _camera == null:
		return -1

	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position).normalized()
	var best_entity_index := -1
	var best_distance_along_ray := INF

	for snapshot in _entity_snapshots:
		var point = snapshot.get("position", Vector3.ZERO)
		var along_ray := maxf((point - ray_origin).dot(ray_direction), 0.0)
		var closest_point := ray_origin + ray_direction * along_ray
		var distance_to_ray := point.distance_to(closest_point)
		if distance_to_ray <= float(snapshot.get("radius", 0.35)) and along_ray < best_distance_along_ray:
			best_distance_along_ray = along_ray
			best_entity_index = int(snapshot.get("entity_index", -1))

	return best_entity_index


func _project_mouse_to_ground(screen_position: Vector2) -> Variant:
	if _camera == null:
		return null

	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position).normalized()
	var ground := Plane(Vector3.UP, 0.0)
	return ground.intersects_ray(ray_origin, ray_direction)
