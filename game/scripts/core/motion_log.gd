class_name MotionLog
extends RefCounted
## Records what the motion sensors, the screen and the detector did during play, so a session on a
## real phone can be saved (user://motion_*.csv), sent to the developers and replayed through
## BellDetector or Calibrator in a test. Set InputRouter.motion_log to start recording.
##
## CSV rows: kind,t,ax,ay,az,gx,gy,gz with kind r (reading: linear m/s², rotation °/s),
## t (touch) or b (bell rang). Times are song time in seconds.

const MAX_ROWS := 60 * 60 * 10   ## ten minutes of 60 fps readings

var rows: Array[PackedFloat64Array] = []
var kinds := PackedByteArray()   # "r", "t" or "b" as bytes


func add_reading(t: float, acc: Vector3, gyro_dps: Vector3) -> void:
	_add("r", PackedFloat64Array([t, acc.x, acc.y, acc.z, gyro_dps.x, gyro_dps.y, gyro_dps.z]))


func add_touch(t: float) -> void:
	_add("t", PackedFloat64Array([t, 0, 0, 0, 0, 0, 0]))


func add_ring(t: float) -> void:
	_add("b", PackedFloat64Array([t, 0, 0, 0, 0, 0, 0]))


func size() -> int:
	return rows.size()


func save(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_line("kind,t,ax,ay,az,gx,gy,gz")
	for i in rows.size():
		var r := rows[i]
		f.store_line("%s,%.5f,%.4f,%.4f,%.4f,%.3f,%.3f,%.3f" % [char(kinds[i]), r[0], r[1], r[2], r[3], r[4], r[5], r[6]])
	f.close()
	return OK


static func load_file(path: String) -> MotionLog:
	var ml := MotionLog.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ml
	f.get_line()
	while not f.eof_reached():
		var parts := f.get_line().split(",")
		if parts.size() != 8 or not parts[0] in ["r", "t", "b"]:
			continue
		var r := PackedFloat64Array()
		for k in range(1, 8):
			r.append(parts[k].to_float())
		ml._add(parts[0], r)
	return ml


## Plays the recorded readings and touches through a detector; returns the times it rang.
func replay(detector: BellDetector) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in rows.size():
		var r := rows[i]
		match char(kinds[i]):
			"t":
				detector.note_touch(r[0])
			"r":
				if detector.feed(r[0], Vector3(r[1], r[2], r[3]), Vector3(r[4], r[5], r[6])):
					out.append(detector.last_t)
	return out


## The bell times the phone rang while recording.
func rings() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in rows.size():
		if char(kinds[i]) == "b":
			out.append(rows[i][0])
	return out


func _add(kind: String, row: PackedFloat64Array) -> void:
	if rows.size() >= MAX_ROWS:
		return
	rows.append(row)
	kinds.append(kind.unicode_at(0))
