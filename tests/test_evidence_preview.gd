extends "res://tests/test_last_call_complete.gd"
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	game.begin_investigation()
	for location in ["adam_office", "reception"]:
		game.travel_to(location)
		await settle()
		var targets: Array = game.room._hotspots.get_children()
		for target in targets:
			check(not target.has_meta("person_id"), "Scene contains no character approach points")
			check(not str(target.get_meta("inspection_id", "")).begins_with("area_"), "Each target directly addresses one clue")
			for other in targets:
				if target != other: check(not target.get_global_rect().intersects(other.get_global_rect()), "Independent evidence touch targets do not overlap")
	game.travel_to("adam_office")
	await settle()
	await touch(game.room._hotspots.find_child("Evidence_call_log", false, false))
	check(game.session.collected_ids().is_empty(), "Opening preview does not collect evidence")
	var art: TextureRect = game.modal_body.find_child("KnownEvidenceArtwork", true, false)
	check(art != null and art.texture == game.room.visual_catalog.evidence_texture("call_log"), "Actual PNG appears on click BEFORE collection")
	check(game._window_title.text == game.session.evidence_data("call_log").name, "Preview displays the evidence name immediately")
	check(action("أضف إلى دفتر الأدلة") != null, "Collection remains an explicit choice")
	await capture("before-collect-fixed")
	game.show_notebook()
	check(game._card_grid.get_child_count() == 0, "Preview alone does not leak evidence into notebook")
	game.show_evidence("call_log")
	await settle()
	await touch(action("أضف إلى دفتر الأدلة"))
	check(game.session.has_evidence("call_log"), "Collect still records progress normally")
	await touch(action("دفتر الأدلة"))
	check(game._card_grid.get_child_count() == 1, "Collected evidence appears in notebook")
	await touch(card("e:call_log"))
	check(game.modal_body.find_child("EvidenceArtwork", true, false) != null, "Notebook detail displays same linked image")
	game.close_modal()
	game.travel_to("reception")
	await settle()
	await touch(game.room._hotspots.find_child("Evidence_call_recording", false, false))
	art = game.modal_body.find_child("KnownEvidenceArtwork", true, false)
	check(art != null and art.texture == game.room.visual_catalog.evidence_texture("call_recording"), "New call-recording PNG displays immediately")
	check(not game.session.has_evidence("call_recording"), "Preview does not change investigation logic")
	await capture("reception-before-collect-fixed")
	game.close_modal()
	game.show_evidence("locker_access")
	art = game.modal_body.find_child("KnownEvidenceArtwork", true, false)
	check(art != null and art.texture == game.room.visual_catalog.evidence_texture("locker_access"), "Cabinet log uses exact assigned image without CCTV fallback")
	game.close_modal()
	complete(game.session)
	var reached := 0
	for location in ["adam_office", "reception"]:
		game.travel_to(location)
		await settle()
		var ids: Array = game.room._hotspots.get_children().map(func(target): return str(target.get_meta("inspection_id", "")))
		for id in ids:
			var target: Button = game.room._hotspots.find_child("Evidence_" + id, false, false)
			for other in game.room._hotspots.get_children():
				if other != target: check(not target.get_global_rect().intersects(other.get_global_rect()), "Unlocked evidence targets remain separate")
			await touch(target)
			check(game._window_title.text == game.session.evidence_data(id).name, "One touch directly opens the matching clue")
			var preview = game.modal_body.find_child("KnownEvidenceArtwork", true, false)
			check((preview != null) == (game.room.visual_catalog.evidence_texture(id) != null), "Matching image displays or genuine missing asset is reported")
			reached += 1
			game.close_modal()
			await settle()
	check(reached == 15, "All fifteen clues have their own reachable inspection point")
	game.queue_free()
	await process_frame
	print("EVIDENCE PREVIEW: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func complete(s) -> void:
	for iteration in range(6):
		for clue in s._case.evidence:
			if s.meets(clue.get("requires", {})):
				s.travel_to(clue.location_id)
				s.collect_evidence(clue.id)
		for task in s.available_analyses():
			s.request_analysis(task.id)
		for person in s._case.people:
			s.select_person(person.id)
			for statement in s.person_statements(person.id):
				s.hear_statement(statement.id)
			for question in s.questions_for(person.id):
				if question.available:
					s.ask_question(question.id)
			for conflict in s._case.contradictions:
				if conflict.person_id == person.id:
					s.confront(conflict.question_id, conflict.evidence_id)
