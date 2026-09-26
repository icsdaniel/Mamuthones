class_name SaveData
extends RefCounted
## The player's calibration and best scores, kept on the phone.

const PATH := "user://save.cfg"

var _cfg := ConfigFile.new()
var _path := PATH


func _init(path := PATH) -> void:
	_path = path
	_cfg.load(_path)  # a missing file just means a fresh start


func calibration() -> Dictionary:
	return _cfg.get_value("motion", "calibration", {})


func set_calibration(cal: Dictionary) -> void:
	_cfg.set_value("motion", "calibration", cal)
	_cfg.save(_path)


func best(song_id: String) -> int:
	return _cfg.get_value("best", song_id, 0)


## Saves the score if it beats the best. Returns the previous best.
func submit(song_id: String, score: int) -> int:
	var prev := best(song_id)
	if score > prev:
		_cfg.set_value("best", song_id, score)
		_cfg.save(_path)
	return prev
