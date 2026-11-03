extends RefCounted
## Atomic replacement, no backup archives. Callers keep current state if a read fails.
const SAVE_VERSION := 1

static func load_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "missing", "data": {}}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"status": "invalid", "data": {}}
	var data: Variant = json.data
	if not data is Dictionary or data.get("save_version") != SAVE_VERSION or not data.get("campaign") is Dictionary or not data.get("cases") is Dictionary:
		return {"status": "invalid", "data": {}}
	return {"status": "loaded", "data": data}

static func save(path: String, campaign: Dictionary, cases: Dictionary) -> Error:
	var directory := path.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"save_version": SAVE_VERSION, "campaign": campaign, "cases": cases}, "	"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(temporary, path)
