extends RefCounted
class_name LiveSyncClient

var _host := "127.0.0.1"
var _port := 49090


func configure(host: String, port: int) -> void:
	_host = host
	_port = port


func send_project_json(json_text: String) -> Dictionary:
	var peer := StreamPeerTCP.new()
	var error := peer.connect_to_host(_host, _port)
	if error != OK:
		return {
			"ok": false,
			"message": "connect failed: %s" % error
		}

	var waited_ms := 0
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and waited_ms < 3000:
		peer.poll()
		OS.delay_msec(50)
		waited_ms += 50

	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		peer.disconnect_from_host()
		return {
			"ok": false,
			"message": "did not connect to %s:%d" % [_host, _port]
		}

	var payload := json_text.to_utf8_buffer()
	var framed := ("%d\n" % payload.size()).to_utf8_buffer()
	framed.append_array(payload)
	var packet_error := peer.put_data(framed)
	if packet_error != OK:
		peer.disconnect_from_host()
		return {
			"ok": false,
			"message": "send failed: %s" % packet_error
		}

	var response := ""
	waited_ms = 0
	while waited_ms < 5000:
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0:
			var data_result := peer.get_data(available)
			if data_result[0] == OK:
				response += data_result[1].get_string_from_utf8()
				if response.contains("\n"):
					break
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED and response.is_empty():
			break
		OS.delay_msec(50)
		waited_ms += 50

	peer.disconnect_from_host()
	var line := response.split("\n", false)[0] if not response.is_empty() else ""
	if line.begins_with("OK "):
		return {
			"ok": true,
			"message": line.substr(3)
		}

	if line.begins_with("ERR "):
		return {
			"ok": false,
			"message": line.substr(4)
		}

	return {
		"ok": false,
		"message": "no acknowledgement from renderer"
	}
