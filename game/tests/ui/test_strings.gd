extends TestCase
## Every string key used by the UI exists in English and Italian, and no Italian cell is a copy of the
## English one where a translation is expected.

const KEEP_SAME := ["lang_name_en", "lang_name_it", "date_fmt",
	"ms_signed", "lat_count", "boards_online", "unlock_remix", "section_intro"]


func _table() -> Dictionary:
	var f := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	var out := {}
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			out[row[0]] = [row[1], row[2]]
	return out


func test_every_key_has_both_languages() -> void:
	var t := _table()
	check(t.size() > 200, "the string table loads")
	for k in t:
		check(t[k][0].strip_edges() != "", "%s has English" % k)
		check(t[k][1].strip_edges() != "", "%s has Italian" % k)
		if not k in KEEP_SAME and t[k][0].length() > 6:
			check(t[k][0] != t[k][1], "%s is translated, not copied" % k)
		check(t[k][0].count("%") == t[k][1].count("%"), "%s: same placeholders in both" % k)


func test_every_used_key_exists() -> void:
	var t := _table()
	var re := RegEx.create_from_string("tr_?\\(\"([a-z0-9_]+)\"\\)")
	for path in _scripts("res://scripts/ui"):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			check(t.has(m.get_string(1)), "%s uses missing key %s" % [path.get_file(), m.get_string(1)])
	# Keys built from parts.
	for topic in ["steps", "lanes", "bells", "holds", "still", "stomps", "full"]:
		for pat in ["tut_%s_title", "tut_%s", "tut_%s_short", "tut_fail_%s"]:
			check(t.has(pat % topic), "tutorial key %s" % (pat % topic))
	for n in range(1, 8):
		check(t.has("stop_date_%d" % n) and t.has("stop_fact_%d" % n), "stop %d has its card text" % n)
	for i in 5:
		check(t.has("grade_%d" % i), "grade %d" % i)
	for d in ["easy", "medium", "hard", "expert"]:
		check(t.has("diff_" + d), "difficulty %s" % d)


func test_stop_cards_are_two_sentences() -> void:
	var t := _table()
	for n in range(1, 8):
		for i in 2:
			var s: String = t.get("stop_fact_%d" % n, ["", ""])[i]
			var sentences := s.count(". ") + (1 if s.ends_with(".") else 0)
			check_eq(sentences, 2, "stop %d card (%s) has two sentences" % [n, ["en", "it"][i]])


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
