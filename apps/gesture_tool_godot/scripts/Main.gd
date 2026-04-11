extends Control

var _project_model := ProjectModel.new()
var _gesture_recorder := GestureRecorder.new()
var _motion_controller := DeviceMotionController.new()
var _live_sync_client := LiveSyncClient.new()

var _selected_entity_index := 0
var _selected_key_index := 0
var _current_time_sec := 0.0
var _is_playing := false
var _updating_ui := false
var _scene_drag_active := false
var _scene_drag_position := Vector3.ZERO

var _world_view
var _viewport

var _title_edit
var _duration_spin
var _entity_list
var _key_list
var _time_spin
var _key_time_spin
var _position_spins: Array = []
var _rotation_spins: Array = []
var _orbit_center_spins: Array = []
var _audio_asset_edit
var _orbit_radius_spin
var _orbit_duration_spin
var _orbit_turns_spin
var _record_button
var _sensor_checkbox
var _live_sync_checkbox
var _live_sync_host_edit
var _live_sync_port_spin
var _live_sync_hint_label
var _status_label
var _help_label
var _import_dialog
var _export_dialog
var _audio_dialog
var _audio_dialog_mode = ""


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	_build_ui()
	_refresh_all()
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta):
	if _gesture_recorder.is_recording_active():
		_process_recording(delta)
		return

	if not _is_playing:
		return

	var duration_sec := float(_project_model.project.get("duration_sec", 8.0))
	_current_time_sec += delta
	if _current_time_sec > duration_sec:
		_current_time_sec = 0.0
	_sync_time_controls()
	_refresh_world_and_pose()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if _import_dialog.visible or _export_dialog.visible:
			return

		match event.keycode:
			KEY_SPACE:
				_toggle_play()
				get_viewport().set_input_as_handled()
			KEY_K:
				_on_add_key_pressed()
				get_viewport().set_input_as_handled()
			KEY_R:
				_toggle_recording()
				get_viewport().set_input_as_handled()
			KEY_M:
				_on_bake_orbit_pressed()
				get_viewport().set_input_as_handled()


func _build_ui():
	var root := HSplitContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.split_offset = 380
	add_child(root)

	var sidebar := ScrollContainer.new()
	sidebar.custom_minimum_size = Vector2(380.0, 0.0)
	root.add_child(sidebar)

	var sidebar_body := VBoxContainer.new()
	sidebar_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(sidebar_body)

	sidebar_body.add_child(_make_section_label("Project"))
	_title_edit = LineEdit.new()
	_title_edit.placeholder_text = "Project Title"
	_title_edit.text_changed.connect(_on_title_changed)
	sidebar_body.add_child(_title_edit)

	_duration_spin = _make_spin_box(0.1, 600.0, 0.1)
	_duration_spin.value_changed.connect(_on_duration_changed)
	sidebar_body.add_child(_labeled_row("Duration (sec)", _duration_spin))

	var project_buttons := HBoxContainer.new()
	var new_project_button := Button.new()
	new_project_button.text = "New"
	new_project_button.pressed.connect(_on_new_project_pressed)
	project_buttons.add_child(new_project_button)
	var import_button := Button.new()
	import_button.text = "Import JSON"
	import_button.pressed.connect(_on_import_pressed)
	project_buttons.add_child(import_button)
	var export_button := Button.new()
	export_button.text = "Export JSON"
	export_button.pressed.connect(_on_export_pressed)
	project_buttons.add_child(export_button)
	sidebar_body.add_child(project_buttons)

	sidebar_body.add_child(_make_section_label("Entities"))
	var entity_buttons := HBoxContainer.new()
	var add_source_button := Button.new()
	add_source_button.text = "Add Audio Source..."
	add_source_button.pressed.connect(_on_add_audio_source_pressed)
	entity_buttons.add_child(add_source_button)
	var assign_audio_button := Button.new()
	assign_audio_button.text = "Set Selected Audio..."
	assign_audio_button.pressed.connect(_on_assign_audio_pressed)
	entity_buttons.add_child(assign_audio_button)
	var delete_entity_button := Button.new()
	delete_entity_button.text = "Delete Source"
	delete_entity_button.pressed.connect(_on_delete_source_pressed)
	entity_buttons.add_child(delete_entity_button)
	sidebar_body.add_child(entity_buttons)

	_entity_list = ItemList.new()
	_entity_list.custom_minimum_size = Vector2(0.0, 120.0)
	_entity_list.item_selected.connect(_on_entity_selected)
	sidebar_body.add_child(_entity_list)

	sidebar_body.add_child(_make_section_label("Transport"))
	_time_spin = _make_spin_box(0.0, 600.0, 0.01)
	_time_spin.value_changed.connect(_on_time_changed)
	sidebar_body.add_child(_labeled_row("Playhead", _time_spin))

	var transport_buttons := HBoxContainer.new()
	var play_button := Button.new()
	play_button.text = "Play / Stop"
	play_button.pressed.connect(_on_play_toggle_pressed)
	transport_buttons.add_child(play_button)
	var add_key_button := Button.new()
	add_key_button.text = "Add Key"
	add_key_button.pressed.connect(_on_add_key_pressed)
	transport_buttons.add_child(add_key_button)
	var delete_key_button := Button.new()
	delete_key_button.text = "Delete Key"
	delete_key_button.pressed.connect(_on_delete_key_pressed)
	transport_buttons.add_child(delete_key_button)
	_record_button = Button.new()
	_record_button.pressed.connect(_on_record_toggle_pressed)
	transport_buttons.add_child(_record_button)
	sidebar_body.add_child(transport_buttons)

	sidebar_body.add_child(_make_section_label("Keys"))
	_key_list = ItemList.new()
	_key_list.custom_minimum_size = Vector2(0.0, 150.0)
	_key_list.item_selected.connect(_on_key_selected)
	sidebar_body.add_child(_key_list)

	sidebar_body.add_child(_make_section_label("Inspector"))
	_audio_asset_edit = LineEdit.new()
	_audio_asset_edit.placeholder_text = "Select a WAV file for the selected source"
	sidebar_body.add_child(_labeled_row("Audio File", _audio_asset_edit))
	var audio_buttons := HBoxContainer.new()
	var browse_audio_button := Button.new()
	browse_audio_button.text = "Browse Audio..."
	browse_audio_button.pressed.connect(_on_assign_audio_pressed)
	audio_buttons.add_child(browse_audio_button)
	var apply_audio_button := Button.new()
	apply_audio_button.text = "Apply Audio Path"
	apply_audio_button.pressed.connect(_on_apply_audio_path_pressed)
	audio_buttons.add_child(apply_audio_button)
	sidebar_body.add_child(audio_buttons)
	_key_time_spin = _make_spin_box(0.0, 600.0, 0.01)
	sidebar_body.add_child(_labeled_row("Key Time", _key_time_spin))

	_position_spins = _make_vec3_editors(sidebar_body, "Position")
	_rotation_spins = _make_vec3_editors(sidebar_body, "Rotation")

	var apply_button := Button.new()
	apply_button.text = "Apply Key / Pose"
	apply_button.pressed.connect(_on_apply_key_pressed)
	sidebar_body.add_child(apply_button)

	sidebar_body.add_child(_make_section_label("Orbit Macro"))
	_orbit_center_spins = _make_vec3_editors(sidebar_body, "Orbit Center")
	_orbit_radius_spin = _make_spin_box(0.1, 100.0, 0.1)
	_orbit_radius_spin.value = 2.0
	sidebar_body.add_child(_labeled_row("Radius", _orbit_radius_spin))
	_orbit_duration_spin = _make_spin_box(0.1, 600.0, 0.1)
	sidebar_body.add_child(_labeled_row("Macro Duration", _orbit_duration_spin))
	_orbit_turns_spin = _make_spin_box(0.25, 32.0, 0.25)
	_orbit_turns_spin.value = 1.0
	sidebar_body.add_child(_labeled_row("Turns", _orbit_turns_spin))

	var orbit_button := Button.new()
	orbit_button.text = "Bake Orbit To Selected"
	orbit_button.pressed.connect(_on_bake_orbit_pressed)
	sidebar_body.add_child(orbit_button)

	sidebar_body.add_child(_make_section_label("Input"))
	_sensor_checkbox = CheckBox.new()
	_sensor_checkbox.text = "Use Device Sensors When Available"
	_sensor_checkbox.toggled.connect(_on_sensor_toggled)
	sidebar_body.add_child(_sensor_checkbox)

	sidebar_body.add_child(_make_section_label("Live Sync"))
	_live_sync_checkbox = CheckBox.new()
	_live_sync_checkbox.text = "Enable TCP Snapshot Sync"
	_live_sync_checkbox.toggled.connect(_on_live_sync_toggled)
	sidebar_body.add_child(_live_sync_checkbox)
	_live_sync_host_edit = LineEdit.new()
	_live_sync_host_edit.text = "127.0.0.1"
	_live_sync_host_edit.text_changed.connect(_on_live_sync_endpoint_changed)
	sidebar_body.add_child(_labeled_row("Host", _live_sync_host_edit))
	_live_sync_port_spin = _make_spin_box(1.0, 65535.0, 1.0)
	_live_sync_port_spin.value = 49090
	_live_sync_port_spin.value_changed.connect(_on_live_sync_endpoint_changed)
	sidebar_body.add_child(_labeled_row("Port", _live_sync_port_spin))
	var live_sync_send_button := Button.new()
	live_sync_send_button.text = "Send Snapshot"
	live_sync_send_button.pressed.connect(_on_send_snapshot_pressed)
	sidebar_body.add_child(live_sync_send_button)
	_live_sync_hint_label = Label.new()
	_live_sync_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live_sync_hint_label.text = "Renderer command: spatial_preview_cli tcp-render <output.wav> 49090. If Godot runs on Windows and the renderer runs inside WSL2, use the WSL IP instead of 127.0.0.1."
	sidebar_body.add_child(_live_sync_hint_label)

	sidebar_body.add_child(_make_section_label("Status"))
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar_body.add_child(_status_label)

	_help_label = Label.new()
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.text = "Shortcuts: Space play, K add key, R record, M orbit. In the 3D view, left click selects and drag moves on the ground plane."
	sidebar_body.add_child(_help_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(viewport_container)

	_viewport = SubViewport.new()
	_viewport.handle_input_locally = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	viewport_container.add_child(_viewport)

	_world_view = WorldView.new()
	_world_view.entity_selected.connect(_on_world_entity_selected)
	_world_view.ground_clicked.connect(_on_world_ground_clicked)
	_world_view.ground_dragged.connect(_on_world_ground_dragged)
	_world_view.drag_state_changed.connect(_on_world_drag_state_changed)
	_viewport.add_child(_world_view)

	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.filters = PackedStringArray(["*.json ; Project JSON"])
	_import_dialog.file_selected.connect(_on_import_file_selected)
	add_child(_import_dialog)

	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.filters = PackedStringArray(["*.json ; Project JSON"])
	_export_dialog.file_selected.connect(_on_export_file_selected)
	add_child(_export_dialog)

	_audio_dialog = FileDialog.new()
	_audio_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_audio_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_audio_dialog.filters = PackedStringArray([
		"*.wav ; WAV Audio",
		"*.wave ; WAVE Audio"
	])
	_audio_dialog.file_selected.connect(_on_audio_file_selected)
	add_child(_audio_dialog)

	call_deferred("_on_resized")
	_update_record_button()


func _make_section_label(text_value):
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 18)
	return label


func _make_spin_box(min_value, max_value, step):
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.allow_greater = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _labeled_row(label_text, field):
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(label)
	row.add_child(field)
	return row


func _make_vec3_editors(parent, title):
	var editors: Array = []
	parent.add_child(_make_section_label(title))
	for axis in ["X", "Y", "Z"]:
		var spin = _make_spin_box(-100.0, 100.0, 0.1)
		parent.add_child(_labeled_row(axis, spin))
		editors.append(spin)
	return editors


func _refresh_all():
	_refresh_project_fields()
	_refresh_entity_list()
	_refresh_audio_fields()
	_refresh_key_list()
	_refresh_pose_fields()
	_refresh_world_and_pose()


func _refresh_project_fields():
	_updating_ui = true
	_title_edit.text = str(_project_model.project.get("title", "untitled"))
	_duration_spin.value = float(_project_model.project.get("duration_sec", 8.0))
	_orbit_duration_spin.value = float(_project_model.project.get("duration_sec", 8.0))
	_updating_ui = false


func _refresh_entity_list():
	_entity_list.clear()
	for entity_index in range(_project_model.get_entity_count()):
		_entity_list.add_item(_project_model.get_entity_label(entity_index))
	_entity_list.select(clamp(_selected_entity_index, 0, max(_project_model.get_entity_count() - 1, 0)))


func _refresh_key_list():
	_key_list.clear()
	var track = _project_model.get_entity_track(_selected_entity_index)
	var keys = track.get("keys", [])
	for index in range(keys.size()):
		var key = keys[index]
		var position := TrajectoryTrack.array_to_vec3(key.get("position", [0.0, 0.0, 0.0]))
		_key_list.add_item(
			"t=%.2f  pos=(%.2f, %.2f, %.2f)" % [
				float(key.get("t", 0.0)),
				position.x,
				position.y,
				position.z
			]
		)

	_selected_key_index = clamp(_selected_key_index, 0, max(keys.size() - 1, 0))
	if not keys.is_empty():
		_key_list.select(_selected_key_index)


func _refresh_audio_fields():
	if _audio_asset_edit == null:
		return

	if _selected_entity_index == 0:
		_audio_asset_edit.text = ""
		_audio_asset_edit.editable = false
		_audio_asset_edit.placeholder_text = "Listener has no audio asset"
		return

	var entity = _project_model.get_entity(_selected_entity_index)
	_audio_asset_edit.text = str(entity.get("audio_asset", ""))
	_audio_asset_edit.editable = true
	_audio_asset_edit.placeholder_text = "Select a WAV file for the selected source"


func _refresh_pose_fields():
	_updating_ui = true
	var track = _project_model.get_entity_track(_selected_entity_index)
	var keys = track.get("keys", [])
	var display_pose

	if _selected_key_index >= 0 and _selected_key_index < keys.size():
		var key = keys[_selected_key_index]
		_key_time_spin.value = float(key.get("t", _current_time_sec))
		display_pose = {
			"position": TrajectoryTrack.array_to_vec3(key.get("position", [0.0, 0.0, 0.0])),
			"rotation_euler_deg": TrajectoryTrack.array_to_vec3(key.get("rotation_euler_deg", [0.0, 0.0, 0.0]))
		}
	else:
		_key_time_spin.value = _current_time_sec
		display_pose = _project_model.get_entity_pose(_selected_entity_index, _current_time_sec)

	var position = display_pose.get("position", Vector3.ZERO)
	var rotation_deg = display_pose.get("rotation_euler_deg", Vector3.ZERO)
	for axis in range(3):
		_position_spins[axis].value = position[axis]
		_rotation_spins[axis].value = rotation_deg[axis]
		_orbit_center_spins[axis].value = position[axis]

	_updating_ui = false


func _refresh_world_and_pose():
	_sync_time_controls()
	_world_view.display_project(
		_project_model,
		_current_time_sec,
		_selected_entity_index,
		_gesture_recorder.get_trail_points()
	)
	_update_status_text()


func _sync_time_controls():
	_updating_ui = true
	_time_spin.value = _current_time_sec
	_updating_ui = false


func _build_key_from_inspector():
	return TrajectoryTrack.make_key(
		_key_time_spin.value,
		_read_position_from_inspector(),
		_read_rotation_from_inspector()
	)


func _read_position_from_inspector():
	return Vector3(
		_position_spins[0].value,
		_position_spins[1].value,
		_position_spins[2].value
	)


func _read_rotation_from_inspector():
	return Vector3(
		_rotation_spins[0].value,
		_rotation_spins[1].value,
		_rotation_spins[2].value
	)


func _set_selected_entity_pose(time_sec, position, rotation_deg):
	var entity := _project_model.get_entity(_selected_entity_index)
	var track = entity.get("track", TrajectoryTrack.make_default_track())
	_selected_key_index = TrajectoryTrack.add_or_replace_key(
		track,
		TrajectoryTrack.make_key(time_sec, position, rotation_deg)
	)
	entity["track"] = track
	_project_model.set_entity(_selected_entity_index, entity)


func _get_live_selected_pose():
	var pose := _project_model.get_entity_pose(_selected_entity_index, _current_time_sec)
	if _scene_drag_active:
		pose["position"] = _scene_drag_position
	return pose


func _process_recording(delta):
	_is_playing = false
	_current_time_sec += delta
	if _current_time_sec > float(_project_model.project.get("duration_sec", 8.0)):
		_project_model.set_duration(_current_time_sec)
		_refresh_project_fields()

	var pose = _get_live_selected_pose()
	if _motion_controller.is_enabled():
		_scene_drag_active = true
		_scene_drag_position = _motion_controller.advance(delta, pose.get("position", Vector3.ZERO))
		pose["position"] = _scene_drag_position
	var rotation_deg = _read_rotation_from_inspector()
	pose["rotation_euler_deg"] = rotation_deg
	_set_selected_entity_pose(_current_time_sec, pose.get("position", Vector3.ZERO), rotation_deg)
	_gesture_recorder.update(delta, pose.get("position", Vector3.ZERO), rotation_deg)
	_refresh_key_list()
	_refresh_pose_fields()
	_refresh_world_and_pose()


func _toggle_play():
	if _gesture_recorder.is_recording_active():
		return
	_is_playing = not _is_playing
	_update_status_text()


func _toggle_recording():
	if _gesture_recorder.is_recording_active():
		var final_pose = _get_live_selected_pose()
		var final_rotation = _read_rotation_from_inspector()
		var entity := _project_model.get_entity(_selected_entity_index)
		entity["track"] = _gesture_recorder.finish(
			final_pose.get("position", Vector3.ZERO),
			final_rotation
		)
		_project_model.set_entity(_selected_entity_index, entity)
		_selected_key_index = 0
		_scene_drag_active = false
	else:
		_is_playing = false
		var initial_pose := _project_model.get_entity_pose(_selected_entity_index, _current_time_sec)
		initial_pose["rotation_euler_deg"] = _read_rotation_from_inspector()
		_scene_drag_position = initial_pose.get("position", Vector3.ZERO)
		_gesture_recorder.start(_selected_entity_index, _current_time_sec, initial_pose)

	_update_record_button()
	_refresh_all()
	_maybe_send_live_snapshot()


func _update_record_button():
	if _record_button == null:
		return
	if _gesture_recorder.is_recording_active():
		_record_button.text = "Stop Rec"
	else:
		_record_button.text = "Record"


func _update_status_text():
	var mode = "idle"
	if _gesture_recorder.is_recording_active():
		mode = "recording"
	elif _is_playing:
		mode = "playing"
	if _status_label == null:
		return
	_status_label.text = "Selected: %s | time %.2f s | mode: %s | drag samples: %d" % [
		_project_model.get_entity_label(_selected_entity_index),
		_current_time_sec,
		mode,
		_gesture_recorder.get_sample_count()
	]


func _on_resized():
	if _viewport != null:
		_viewport.size = Vector2i(max(size.x - 380.0, 320.0), max(size.y, 240.0))


func _on_new_project_pressed():
	_project_model.reset_default()
	_gesture_recorder.reset()
	_selected_entity_index = 0
	_selected_key_index = 0
	_current_time_sec = 0.0
	_is_playing = false
	_scene_drag_active = false
	_update_record_button()
	_refresh_all()
	_maybe_send_live_snapshot()


func _on_title_changed(new_text):
	if _updating_ui:
		return
	_project_model.set_project_title(new_text)
	_refresh_world_and_pose()


func _on_duration_changed(value):
	if _updating_ui:
		return
	_project_model.set_duration(value)
	_current_time_sec = clamp(_current_time_sec, 0.0, float(_project_model.project.get("duration_sec", value)))
	_refresh_all()


func _on_add_source_pressed():
	_selected_entity_index = _project_model.add_source()
	_selected_key_index = 0
	_refresh_all()
	_maybe_send_live_snapshot()


func _on_add_audio_source_pressed():
	_audio_dialog_mode = "add"
	_audio_dialog.popup_centered_ratio()


func _on_assign_audio_pressed():
	if _selected_entity_index == 0:
		_set_status_message("Select a source first. The listener does not have an audio file.")
		return
	_audio_dialog_mode = "assign"
	_audio_dialog.popup_centered_ratio()


func _on_delete_source_pressed():
	if _selected_entity_index == 0:
		return
	_project_model.remove_source(_selected_entity_index - 1)
	_selected_entity_index = clamp(_selected_entity_index - 1, 0, max(_project_model.get_entity_count() - 1, 0))
	_selected_key_index = 0
	_refresh_all()
	_maybe_send_live_snapshot()


func _on_entity_selected(index):
	_selected_entity_index = index
	_selected_key_index = 0
	_refresh_key_list()
	_refresh_pose_fields()
	_refresh_world_and_pose()


func _on_time_changed(value):
	if _updating_ui or _gesture_recorder.is_recording_active():
		return
	_current_time_sec = value
	_refresh_pose_fields()
	_refresh_world_and_pose()


func _on_play_toggle_pressed():
	_toggle_play()


func _on_record_toggle_pressed():
	_toggle_recording()


func _on_add_key_pressed():
	_set_selected_entity_pose(
		_current_time_sec,
		_read_position_from_inspector(),
		_read_rotation_from_inspector()
	)
	_refresh_all()
	_maybe_send_live_snapshot()


func _on_delete_key_pressed():
	var entity := _project_model.get_entity(_selected_entity_index)
	var track = entity.get("track", TrajectoryTrack.make_default_track())
	TrajectoryTrack.remove_key(track, _selected_key_index)
	entity["track"] = track
	_project_model.set_entity(_selected_entity_index, entity)
	_selected_key_index = clamp(_selected_key_index, 0, max(track.get("keys", []).size() - 1, 0))
	_refresh_all()
	_maybe_send_live_snapshot()


func _on_key_selected(index):
	_selected_key_index = index
	var track = _project_model.get_entity_track(_selected_entity_index)
	var keys = track.get("keys", [])
	if index >= 0 and index < keys.size():
		_current_time_sec = float(keys[index].get("t", _current_time_sec))
	_refresh_pose_fields()
	_refresh_world_and_pose()


func _on_apply_key_pressed():
	var entity := _project_model.get_entity(_selected_entity_index)
	var track = entity.get("track", TrajectoryTrack.make_default_track())
	var key = _build_key_from_inspector()
	if _selected_key_index >= 0 and _selected_key_index < track.get("keys", []).size():
		TrajectoryTrack.update_key(track, _selected_key_index, key)
	else:
		_selected_key_index = TrajectoryTrack.add_or_replace_key(track, key)
	entity["track"] = track
	_project_model.set_entity(_selected_entity_index, entity)
	_current_time_sec = key.get("t", _current_time_sec)
	_refresh_all()
	_maybe_send_live_snapshot()


func _on_bake_orbit_pressed():
	var entity := _project_model.get_entity(_selected_entity_index)
	var center := Vector3(
		_orbit_center_spins[0].value,
		_orbit_center_spins[1].value,
		_orbit_center_spins[2].value
	)
	entity["track"] = MacroGenerator.bake_orbit(
		center,
		_orbit_radius_spin.value,
		_orbit_duration_spin.value,
		_orbit_turns_spin.value,
		0.0
	)
	_project_model.set_entity(_selected_entity_index, entity)
	_selected_key_index = 0
	_current_time_sec = 0.0
	_refresh_all()
	_maybe_send_live_snapshot()


func _on_world_entity_selected(index):
	_selected_entity_index = index
	_selected_key_index = 0
	_refresh_all()


func _on_world_ground_clicked(position):
	_scene_drag_position = position
	_set_selected_entity_pose(_current_time_sec, position, _read_rotation_from_inspector())
	_refresh_all()
	_maybe_send_live_snapshot()


func _on_world_ground_dragged(position):
	_scene_drag_active = true
	_scene_drag_position = position
	_set_selected_entity_pose(_current_time_sec, position, _read_rotation_from_inspector())
	_refresh_key_list()
	_refresh_pose_fields()
	_refresh_world_and_pose()
	_maybe_send_live_snapshot()


func _on_world_drag_state_changed(active):
	_scene_drag_active = active


func _on_sensor_toggled(enabled):
	_motion_controller.set_enabled(enabled)


func _on_live_sync_toggled(_enabled):
	_configure_live_sync()


func _on_live_sync_endpoint_changed(_value):
	_configure_live_sync()


func _on_send_snapshot_pressed():
	_send_live_snapshot()


func _on_import_pressed():
	_import_dialog.popup_centered_ratio()


func _on_export_pressed():
	_export_dialog.current_file = "%s.json" % _project_model.project.get("title", "project")
	_export_dialog.popup_centered_ratio()


func _on_import_file_selected(path):
	if JsonSerializer.load_project(path, _project_model):
		_gesture_recorder.reset()
		_selected_entity_index = 0
		_selected_key_index = 0
		_current_time_sec = 0.0
		_is_playing = false
		_scene_drag_active = false
		_update_record_button()
		_refresh_all()
		_maybe_send_live_snapshot()


func _on_export_file_selected(path):
	JsonSerializer.save_project(path, _project_model)
	_set_status_message("Exported %s" % path)


func _on_audio_file_selected(path):
	var resolved_path = _normalize_audio_asset_path(path)
	if _audio_dialog_mode == "add":
		_selected_entity_index = _project_model.add_source(resolved_path)
		_selected_key_index = 0
		_refresh_all()
		_set_status_message("Added source with audio: %s" % resolved_path)
		_maybe_send_live_snapshot()
		return

	if _audio_dialog_mode == "assign":
		_set_selected_source_audio_asset(resolved_path)


func _on_apply_audio_path_pressed():
	if _selected_entity_index == 0:
		_set_status_message("Select a source first. The listener does not have an audio file.")
		return
	var path = _normalize_audio_asset_path(_audio_asset_edit.text.strip_edges())
	if path.is_empty():
		_set_status_message("Enter or choose a WAV file path.")
		return
	_set_selected_source_audio_asset(path)


func _configure_live_sync():
	_live_sync_client.configure(_live_sync_host_edit.text, int(_live_sync_port_spin.value))


func _set_selected_source_audio_asset(path):
	if _selected_entity_index == 0:
		_set_status_message("Select a source first. The listener does not have an audio file.")
		return
	var entity := _project_model.get_entity(_selected_entity_index)
	entity["audio_asset"] = path
	_project_model.set_entity(_selected_entity_index, entity)
	_refresh_audio_fields()
	_set_status_message("Audio file set: %s" % path)
	_maybe_send_live_snapshot()


func _normalize_audio_asset_path(path):
	var normalized = path.replace("\\", "/")
	if normalized.is_empty():
		return normalized

	var project_root = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var repo_root = project_root.get_base_dir().get_base_dir().replace("\\", "/")
	if normalized.begins_with(repo_root + "/"):
		return normalized.trim_prefix(repo_root + "/")
	return normalized


func _maybe_send_live_snapshot():
	if _live_sync_checkbox != null and _live_sync_checkbox.button_pressed:
		_send_live_snapshot()


func _send_live_snapshot():
	_configure_live_sync()
	var result := _live_sync_client.send_project_json(JsonSerializer.project_to_json_string(_project_model))
	if result.get("ok", false):
		_set_status_message("Live sync OK: %s (%s:%d)" % [
			result.get("message", "rendered"),
			_live_sync_host_edit.text,
			int(_live_sync_port_spin.value)
		])
	else:
		_set_status_message("Live sync failed: %s" % result.get("message", "unknown error"))


func _set_status_message(message):
	if _status_label != null:
		_status_label.text = message
