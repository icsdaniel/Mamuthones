extends TestCase
## Settings the game cannot work without on a phone.


func test_motion_sensors_enabled() -> void:
	# Godot 4.4+ leaves the phone's sensors off unless enabled here; without them the bell tilt
	# would never ring on Android.
	for k in ["enable_accelerometer", "enable_gravity", "enable_gyroscope"]:
		check(bool(ProjectSettings.get_setting("input_devices/sensors/" + k, false)), k + " is on")
