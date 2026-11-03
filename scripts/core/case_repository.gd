extends RefCounted
const Loader = preload("res://scripts/core/case_loader.gd")
static func list_cases(directory: String = "res://data/cases") -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return cases
	var ids := {}
	for file in dir.get_files():
		if file.get_extension().to_lower() != "json":
			continue
		var path := directory.path_join(file)
		var loaded := Loader.load_case(path)
		if loaded.errors.is_empty() and not ids.has(loaded.data.id):
			ids[loaded.data.id] = true
			cases.append({"id": loaded.data.id, "title": loaded.data.title, "crime_label": loaded.data.case_file.crime_label, "path": path})
	cases.sort_custom(func(first, second): return first.id < second.id)
	return cases
