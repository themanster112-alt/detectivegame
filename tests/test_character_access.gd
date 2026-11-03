extends "res://tests/test_last_call_complete.gd"
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	game.begin_investigation()
	var seen := []
	for location in ["adam_office", "reception", "adam_office"]:
		game.travel_to(location)
		await settle()
		check(game.room._portrait == null or not game.room._portrait.is_visible_in_tree(), "Cropped dialogue portrait never floats over exploration scene")
		check(game.room._hotspots.get_children().all(func(target): return not target.has_meta("person_id")), "Crime scenes contain only evidence interactions")
		await capture("approach-" + location)
	game.show_people()
	await settle()
	check(game._card_grid.get_child_count() == 4, "All four people have image cards")
	for control in game._card_grid.get_children():
		check(control.text.is_empty() and control.find_child("PersonArtwork", true, false) != null, "People view is image-first rather than text buttons")
		var art: TextureRect = control.find_child("PersonArtwork", true, false)
		check(art.texture != null and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Card portrait loads without distortion or cropping")
		for child in control.find_children("*", "Control", true, false):
			check(control.get_global_rect().grow(1).encloses(child.get_global_rect()), "Card content stays within its clickable image card: %s %s in %s" % [child.name, child.get_global_rect(), control.get_global_rect()])
	await capture("people-portraits")
	for id in ["nadine", "layla", "samer", "mazen"]:
		game.show_people()
		await settle()
		await touch(card(id))
		check(game.session.active_person == id, "Each photo card opens the right person")
		game.close_modal()
	game.queue_free()
	await process_frame
	print("CHARACTER ACCESS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
