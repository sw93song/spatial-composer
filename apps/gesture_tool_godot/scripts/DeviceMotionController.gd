extends RefCounted
class_name DeviceMotionController

var _enabled := false
var _velocity := Vector3.ZERO


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_velocity = Vector3.ZERO


func is_enabled() -> bool:
	return _enabled


func advance(delta: float, current_position: Vector3) -> Vector3:
	if not _enabled:
		return current_position

	var accel := Input.get_accelerometer()
	var gyro := Input.get_gyroscope()
	if accel.length() < 0.01 and gyro.length() < 0.01:
		return current_position

	var planar_motion := Vector3(
		accel.x + gyro.y * 0.25,
		0.0,
		-accel.y + gyro.x * 0.25
	)
	var response := clamp(delta * 6.0, 0.0, 1.0)
	_velocity = _velocity.lerp(planar_motion * 1.6, response)
	return current_position + _velocity * delta
