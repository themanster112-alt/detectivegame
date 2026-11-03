extends SceneTree
const Loader = preload("res://scripts/core/case_loader.gd")
const Session = preload("res://scripts/core/investigation_session.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var data: Dictionary = Loader.load_case("res://tests/fixtures/engine_contract.json").data
	data.reports[1]["request_required"] = true
	data.reports[1]["analysis_label"] = "اختبار طلب تحليل"
	var s := Session.new()
	check(s.load_data(data), "Optional request flag validates")
	check(s.request_analysis("updated").status == "locked", "No requests before investigation")
	s.begin_investigation()
	check(s.request_analysis("updated").status == "locked", "Missing inputs reject request")
	check(s.available_analyses().is_empty(), "Unavailable tasks do not reveal inputs or results")
	s.collect_evidence("sample")
	check(s.available_reports().size() == 1, "Collecting input does not auto publish request-only result")
	var tasks := s.available_analyses()
	check(tasks.size() == 1 and tasks[0].id == "updated", "Eligible request offered")
	check(not tasks[0].has("summary") and not tasks[0].has("findings") and not tasks[0].has("cause_of_death"), "Pending tasks contain no hidden result text")
	check(s.case_snapshot().reports.size() == 1 and not s.known_nodes().any(func(node): return node.ref == "r:updated"), "Unrequested result absent from snapshot and board")
	var before: Dictionary = s.export_state()
	check(s.request_analysis("unknown").status == "invalid", "Unknown task rejected")
	check(s.request_analysis("initial").status == "invalid", "Ordinary reports cannot be requested as tasks")
	check(s.export_state() == before, "Invalid requests leave state unchanged")
	var result := s.request_analysis("updated")
	check(result.status == "completed" and result.report.id == "updated", "Request returns result synchronously without timer")
	check(s.available_reports().size() == 2 and s.available_analyses().is_empty(), "Completed report is published and task disappears")
	check(s.known_nodes().any(func(node): return node.ref == "r:updated"), "Requested result becomes linkable board material")
	var state := s.export_state()
	check(s.request_analysis("updated").status == "duplicate" and s.export_state() == state, "Repeat request cannot duplicate progress")
	var restored := Session.new()
	restored.load_data(data)
	check(restored.restore_state(state) and restored.export_state() == state, "Requested analyses round-trip with saved progress")
	var bad := state.duplicate(true)
	bad.requested_analyses = []
	check(not restored.restore_state(bad), "Unrequested result cannot be injected by save")
	bad = state.duplicate(true)
	bad.requested_analyses = ["initial"]
	check(not restored.restore_state(bad), "Save cannot designate ordinary report as analysis")
	var legacy_data: Dictionary = Loader.load_case("res://tests/fixtures/engine_contract.json").data
	var legacy := Session.new()
	legacy.load_data(legacy_data)
	legacy.begin_investigation()
	legacy.collect_evidence("sample")
	check(legacy.available_reports().size() == 2, "Cases without request flag retain automatic reports")
	var legacy_state := legacy.export_state()
	legacy_state.erase("requested_analyses")
	var old_restore := Session.new()
	old_restore.load_data(legacy_data)
	check(old_restore.restore_state(legacy_state), "Existing save layout remains compatible for previous cases")
	data.reports[1].request_required = "yes"
	check(not Loader.validate(data).is_empty(), "Malformed request flag rejected")
	data.reports[1].request_required = true
	data.reports[0]["request_required"] = true
	check(not Loader.validate(data).is_empty(), "A requested analysis cannot replace mandatory initial report")
	s.reset()
	check(s.available_reports().size() == 1 and s.export_state().requested_analyses.is_empty(), "Reset clears requested results")
	print("ANALYSIS REQUESTS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
