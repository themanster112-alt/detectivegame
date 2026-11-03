extends "res://tests/test_last_call_outcomes.gd"
const Catalog = preload("res://assets/ui/last_call_visual_catalog.tres")
const EXPECTED := {"door_events":"evidence_1_lock_log.png","desk_inventory":"evidence_2_empty_statue_spot.png","call_log":"evidence_2_phone.png","finance_memo":"evidence_3_financial_file.png","call_recording":"evidence_5_call_recording.png","audio_archive":"evidence_6_voice_archive.png","security_log":"evidence_7_bag_inspection.png","locker_find":"evidence_1_statue.png","statue_photo":"evidence_5_office_photo.png","locker_access":"evidence_10_cabinet_log.png","bag_fibers":"evidence_6_fibers.png","server_logs":"evidence_12_server_camera_logs.png","mazen_threats":"evidence_7_threat_note.png","layla_file":"evidence_14_brother_complaint.png","fraud_ledger":"evidence_15_transfer_ledger.png"}
func screenshot(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/confirmed-art-" + name + ".png")
func pictures() -> Array:
	return game.modal_body.find_children("*", "TextureRect", true, false).filter(func(node): return node.texture != null)
func run() -> void:
	var found := 0
	var missing := []
	for id in EXPECTED:
		var path: String = "res://assets/evidence/" + EXPECTED[id]
		check(Catalog.evidence_files.get(id) == path, "Exact user-approved image path for " + id)
		if FileAccess.file_exists(path):
			check(Catalog.evidence_texture(id) != null, "Existing mapped PNG loads: " + path)
			found += 1
		else:
			check(Catalog.evidence_texture(id) == null, "Missing file never substitutes another evidence image")
			missing.append(EXPECTED[id])
	check(Catalog.inspection_fallbacks.is_empty(), "Old cross-evidence fallbacks removed")
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await process_frame
	game.begin_investigation()
	game.show_evidence("call_log")
	check(pictures().size() == 1 and not game.session.has_evidence("call_log"), "Assigned image previews before collection")
	game.show_notebook()
	check(game._card_grid.get_child_count() == 0, "Preview does not silently add evidence to notebook")
	complete(game.session)
	check(game.session.collected_ids().size() == 15, "All evidence remains discoverable despite missing images")
	for id in EXPECTED:
		var clue: Dictionary = game.session.evidence_data(id)
		game.travel_to(clue.location_id)
		game.show_evidence(id)
		await process_frame
		await process_frame
		var exists := FileAccess.file_exists("res://assets/evidence/" + EXPECTED[id])
		check(pictures().size() == (1 if exists else 0), "Inspection shows exact assigned picture or explicit missing state: " + id)
		if exists: check(pictures()[0].texture == Catalog.evidence_texture(id), "Correct evidence texture actually displayed: " + id)
		else: check(labels().contains("غير متوفرة"), "Missing image is explained while clue remains playable")
		if id in ["server_logs","locker_access","fraud_ledger","door_events","desk_inventory","call_recording","audio_archive"]: await screenshot(id)
		game._show_notebook_entry("e:" + id)
		check(pictures().size() == (1 if exists else 0), "Notebook details obey confirmed mapping: " + id)
	game.queue_free()
	await process_frame
	print("MAPPING FILES: ", found, " found; missing: ", missing)
	print("CONFIRMED EVIDENCE MAPPING: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
