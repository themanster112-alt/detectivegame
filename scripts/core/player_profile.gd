extends RefCounted
const VERSION := 1
const ROLES := ["lead_detective", "assistant_detective"]
# Future cooperative metadata only; not an authorization policy for the current game.
const ROLE_DEFINITIONS := {
	"lead_detective": {"label": "المحقق الرئيسي", "description": "يحقق ويجمع الأدلة ويستجوب، ويعتمد الاتهام النهائي مستقبلًا.", "investigate": true, "collect_evidence": true, "interrogate": true, "final_accusation": true},
	"assistant_detective": {"label": "المحقق المساعد", "description": "يحقق ويجمع الأدلة ويستجوب، ويشارك مواد الاتهام مستقبلًا.", "investigate": true, "collect_evidence": true, "interrogate": true, "final_accusation": false}
}
var path := "user://player_progress.json"
var persistence_enabled := true
var write_allowed := true
var error := ""
var data: Dictionary = {"version": VERSION, "player_id": "", "player_name": "", "role": "lead_detective", "intro_seen": false, "intro_page": 0, "last_case": "res://data/cases/last_call.json", "volume": 1.0}
static func clean_name(value: String) -> String:
	var cleaned := ""
	for character in value.strip_edges():
		var code := character.unicode_at(0)
		if code >= 32 and code != 127 and code not in [0x061C, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069] and character not in ["{", "}"]:
			cleaned += character
	return cleaned.strip_edges().left(28)
static func format_text(value: String, player_name: String) -> String:
	return value.replace("{player_name}", player_name if not player_name.is_empty() else "المحقق")
func load_progress() -> bool:
	if not persistence_enabled or not FileAccess.file_exists(path):
		return true
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return _invalid()
	var value: Variant = json.data
	if not value is Dictionary or value.get("version") != VERSION or not value.get("player_name") is String or not value.get("intro_seen") is bool or not value.get("intro_page") is float and not value.get("intro_page") is int:
		return _invalid()
	if clean_name(value.player_name) != value.player_name or value.get("role") != "lead_detective" or not value.get("player_id") is String or not value.get("last_case") is String:
		return _invalid()
	if not value.get("volume") is float and not value.get("volume") is int:
		return _invalid()
	if not is_finite(float(value.volume)) or value.volume < 0 or value.volume > 1 or value.intro_page < 0 or value.intro_page > 3:
		return _invalid()
	data = value.duplicate(true)
	return true
func _invalid() -> bool:
	error = "تعذّر قراءة تقدم اللاعب؛ لم يُستبدل الملف الموجود."
	write_allowed = false
	return false
func save() -> bool:
	if not write_allowed:
		return false
	if not persistence_enabled:
		return true
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		error = "تعذّر إنشاء مجلد تقدم اللاعب."
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "تعذّر حفظ تقدم اللاعب."
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(path + ".tmp", path)
	error = "" if result == OK else "تعذّر حفظ تقدم اللاعب."
	return result == OK
func new_player(value: String) -> bool:
	var name := clean_name(value)
	if name.is_empty():
		error = "أدخل اسمًا قبل بدء اللعبة."
		return false
	data.player_name = name
	data.player_id = Crypto.new().generate_random_bytes(16).hex_encode()
	data.role = "lead_detective"
	data.intro_seen = false
	data.intro_page = 0
	data.last_case = "res://data/cases/last_call.json"
	return save()
