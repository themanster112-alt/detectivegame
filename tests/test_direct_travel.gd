extends "res://tests/test_last_call_complete.gd"
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	game.begin_investigation()
	await settle()
	for button in game.find_children("*", "Button", true, false):
		check(not (button.text == "المواقع" and button.is_visible_in_tree()), "No intermediate locations button")
	for id in ["reception", "adam_office", "reception"]:
		for target in game.travel_buttons.values():
			check(target.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(target.get_global_rect()), "Location name is directly visible inside viewport")
		await touch(game.travel_buttons[id])
		check(game.session.current_location == id and not game.overlay.visible, "Click on location name travels directly without opening a window")
		check(game.travel_buttons[id].disabled, "Current location is clearly selected")
	await capture("direct-location-names")
	game.queue_free()
	await process_frame
	print("DIRECT TRAVEL: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
