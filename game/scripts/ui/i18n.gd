class_name I18n
extends RefCounted
## Loads game/i18n/strings.csv (key,en,it) into TranslationServer at runtime, so no project setting is
## needed. The CSV is imported with the "keep" importer, so the same file ships in exported builds.

const PATH := "res://i18n/strings.csv"
const LOCALES: Array[String] = ["en", "it"]

static var _loaded := false


static func load_strings() -> void:
	if _loaded:
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("I18n: cannot open %s" % PATH)
		return
	var header := f.get_csv_line()
	var translations: Array[Translation] = []
	var columns: Array[int] = []
	for i in range(1, header.size()):
		var tr_obj := Translation.new()
		tr_obj.locale = header[i].strip_edges()
		translations.append(tr_obj)
		columns.append(i)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "" or row[0].begins_with("#"):
			continue
		for j in translations.size():
			var col := columns[j]
			if col < row.size() and row[col] != "":
				translations[j].add_message(row[0], row[col].replace("\\n", "\n"))
	for t in translations:
		TranslationServer.add_translation(t)
	_loaded = true


## The phone's language if we support it, else English.
static func system_locale() -> String:
	var lang := OS.get_locale_language()
	return lang if lang in LOCALES else "en"


static func set_locale(locale: String) -> void:
	load_strings()
	TranslationServer.set_locale(locale if locale in LOCALES else "en")


static func locale() -> String:
	var l := TranslationServer.get_locale().substr(0, 2)
	return l if l in LOCALES else "en"
