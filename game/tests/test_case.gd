class_name TestCase
extends RefCounted
## Base class for tests. Define methods named test_* (they may await).
## `tree` is the running SceneTree, for tests that need nodes or frames.

var tree: SceneTree
var failures: Array[String] = []
var checks := 0


func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures.append(what)
	return ok


func check_eq(actual, expected, what: String) -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [what, expected, actual])


func check_near(actual: float, expected: float, tolerance: float, what: String) -> bool:
	return check(absf(actual - expected) <= tolerance, "%s (expected %s ± %s, got %s)" % [what, expected, tolerance, actual])
