extends TestCase
## Juice (2026-10-31): combo milestones and breaks, the stamp's weight, the stings load, the HUD's
## sparks, and the faster standard note speed.

const PlayScreenScript := preload("res://scripts/ui/screens/play_screen.gd")
const ResultsScript := preload("res://scripts/ui/screens/results_screen.gd")


func test_milestone_tiers() -> void:
	check_eq(PlayScreenScript.milestone_tier(23, 24), 0, "24 is no milestone")
	check_eq(PlayScreenScript.milestone_tier(24, 25), 1, "25 -> tier 1")
	check_eq(PlayScreenScript.milestone_tier(49, 50), 2, "50 -> tier 2")
	check_eq(PlayScreenScript.milestone_tier(99, 100), 3, "100 -> tier 3")
	check_eq(PlayScreenScript.milestone_tier(150, 151), 0, "151 is none")
	check_eq(PlayScreenScript.milestone_tier(199, 200), 3, "200 -> tier 3")
	check_eq(PlayScreenScript.milestone_tier(300, 301), 0, "301 is none")
	check_eq(PlayScreenScript.milestone_tier(30, 0), 0, "a break is no milestone")


func test_stamp_tiers() -> void:
	check_eq(ResultsScript.stamp_tier(0), 1, "F stamps light")
	check_eq(ResultsScript.stamp_tier(Session.RANK_B), 2, "B rings")
	check_eq(ResultsScript.stamp_tier(Session.RANK_S), 3, "S rings out")
	check_eq(ResultsScript.stamp_tier(Session.RANK_SPLUS), 3, "S+ rings out")


func test_every_juice_sting_loads() -> void:
	var s := tree.root.get_node_or_null("Sound")
	if not check(s != null, "Sound autoload"):
		return
	for n in s.JUICE_NAMES:
		check(s._juice.get(n) != null, "juice/%s.wav loads" % n)
		s.juice(n)
	s.stop_all()


func test_standard_speed_is_faster() -> void:
	check_eq(Profile.DEFAULT_SETTINGS["note_speed"], 1.6, "standard note speed 1.6x")


func test_sparks_fly_and_die() -> void:
	var sp := Sparks.new()
	tree.root.add_child(sp)
	sp.burst(Vector2(50, 50), 10)
	sp.ring(Vector2(50, 50), 8)
	check(sp.alive() > 0, "sparks alive after a burst")
	await tree.create_timer(1.6).timeout
	check_eq(sp.alive(), 0, "every spark dies within its life")
	sp.queue_free()
