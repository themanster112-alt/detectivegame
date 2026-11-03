extends SceneTree
var game: Control
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
func touch(control: Control) -> void:
	if control == null:
		check(false, "Touch target exists")
		return
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await settle()
func action(prefix: String) -> Button:
	for child in game._modal_actions.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
	return null
func labels(root_node: Node) -> Array:
	return root_node.find_children("*", "Label", true, false).map(func(label): return label.text)
func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/crime-scene-" + name + ".png")
func footer_fits() -> void:
	var viewport := Rect2(Vector2.ZERO, root.size)
	check(game.footer_buttons.size() == 4, "Bottom navigation retains all four actions")
	for button in game.footer_buttons:
		check(button.is_visible_in_tree(), "Every navigation button remains visible")
		check(viewport.encloses(button.get_global_rect()), "Navigation button fits landscape viewport")
		check(button.size.y >= 64 and button.size.x >= 64, "Navigation supports touch")
	for first in range(game.footer_buttons.size()):
		for second in range(first + 1, game.footer_buttons.size()):
			check(not game.footer_buttons[first].get_global_rect().intersects(game.footer_buttons[second].get_global_rect()), "Navigation actions do not overlap")
	for hotspot in game.room._hotspots.get_children():
		for button in game.footer_buttons:
			check(not button.get_global_rect().intersects(hotspot.get_global_rect()), "World interaction does not overlap footer")

func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	game.case_path = "res://data/cases/midnight_training.json"
	root.add_child(game)
	await settle()
	game.begin_investigation()
	await settle()
	var room: Control = game.room
	check(game.session.collected_ids().is_empty(), "No evidence discovered before interaction")
	game.show_notebook()
	check(game._card_grid.get_child_count() == 0, "Notebook does not expose undiscovered evidence")
	game.close_modal()
	check(room._evidence.get_child_count() == 0, "No staged evidence pictures or temporary art captions in scene")
	var rendered_text: Array = labels(room)
	for clue in game.case_data.evidence:
		check(not rendered_text.any(func(text): return text.contains(clue.name)), "Scene labels do not expose evidence names")
		var target: Button = room.find_child("Evidence_" + clue.id, true, false)
		check(target != null and target.text.is_empty() and target.tooltip_text.is_empty(), "Hotspots have no evidence-name label or tooltip")
		check(target.get_theme_stylebox("normal") is StyleBoxEmpty, "Idle hotspot has no visible button plate")
	check(not rendered_text.any(func(text): return text.contains("صورة دليل مؤقتة")), "Temporary evidence image labels removed")
	footer_fits()
	await capture("clean")
	var coffee: Dictionary = room.inspection_data("coffee")
	var phone: Dictionary = room.inspection_data("phone")
	check(coffee.art_match and not phone.art_match, "Existing cup is distinguished from a temporary search region")
	var image_rect: Rect2 = room._background_image_rect()
	var expected: Vector2 = image_rect.position + coffee.rect.get_center() * image_rect.size + room._stage.global_position
	check(room.find_child("Evidence_coffee", true, false).get_global_rect().get_center().distance_to(expected) < 2, "Cup region aligns with background rather than obsolete case coordinates")
	await touch(room.find_child("Evidence_phone", true, false))
	check(game.overlay.visible and game._window_title.text == "هاتف مكسور", "Real touch opens compact inspection")
	check(game.modal_panel.size.x <= 720 and game.modal_panel.size.y <= 600, "Inspection window remains small at 1280x720")
	var inspection_labels := labels(game.modal_body)
	check(not inspection_labels.any(func(text): return text == "هاتف مكسور"), "Undiscovered evidence name not shown before collection")
	check(inspection_labels.any(func(text): return text.contains("قطعة الدليل غير ظاهرة")), "Approximate search position is disclosed honestly")
	check(action("أضف إلى دفتر الأدلة") != null, "Collectible evidence offers explicit collection")
	check(not game.session.has_evidence("phone"), "Inspection alone does not silently collect")
	await capture("inspection")
	await touch(action("أضف إلى دفتر الأدلة"))
	check(game.session.has_evidence("phone"), "Touching collect records existing engine evidence")
	check(game._window_title.text == "هاتف مكسور", "Evidence name is available after collection")
	game.close_modal()
	await touch(room.find_child("Evidence_coffee", true, false))
	check(not labels(game.modal_body).any(func(text): return text.contains("قطعة الدليل غير ظاهرة")), "Actual background object does not receive a false mismatch disclaimer")
	game.close_modal()
	game.show_notebook()
	check(game._card_grid.get_child_count() == 1 and not game.session.has_evidence("coffee"), "Only collected evidence appears in notebook")
	game.close_modal()
	for button in game.footer_buttons:
		await touch(button)
		check(game.overlay.visible, "Every footer action responds to real touch")
		game.close_modal()
	await touch(room.find_child("Evidence_letter", true, false))
	check(game._accusation_shortcut.visible and not game.conclusion_button.disabled, "Accusation remains available during inspection")
	await touch(game._accusation_shortcut)
	check(game._window_title.text == "توجيه اتهام" and game.session.accusations().is_empty(), "Accusation navigation does not automatically charge anyone")
	game.close_modal()
	var data: Dictionary = game._world_data()
	data["presentation"] = {"hotspots": [
		{"id": "custom_phone", "evidence_id": "phone", "location_id": "office", "rect": [0.12, 0.35, 0.1, 0.1], "label": "تفتيش ركن المكتب", "art_match": false},
		{"id": "detail", "location_id": "office", "rect": [0.74, 0.35, 0.08, 0.1], "label": "فحص الجدار", "description": "عنصر اختبار للفحص فقط.", "art_match": true},
		{"id": "invalid", "location_id": "office", "rect": [0.95, 0.95, 0.5, 0.5], "label": "invalid"}
	]}
	var original_state: Dictionary = game.session.export_state()
	room.display_location(game.session.location_data(), data, game.collected)
	check(room.inspection_data("phone").rect == Rect2(0.12, 0.35, 0.1, 0.1), "Case JSON presentation.hotspots overrides art catalog coordinates")
	check(room.find_child("Inspection_invalid", true, false) == null, "Malformed or out-of-bounds regions rejected")
	await settle()
	await touch(room.find_child("Inspection_detail", true, false))
	check(labels(game.modal_body).has("عنصر اختبار للفحص فقط.") and action("أضف") == null, "Noncollectible scenery provides description without collection")
	check(game.session.export_state() == original_state, "Decorative inspection does not change investigation state")
	game.close_modal()
	data = game._world_data()
	data.evidence[1]["hotspot"] = {"rect": [0.4, 0.4, 0.1, 0.1], "collectible": false}
	room.display_location(game.session.location_data(), data, game.collected)
	game.show_evidence("coffee")
	check(action("أضف") == null, "Per-item noncollectible setting is respected")
	game.collect_evidence("coffee")
	check(not game.session.has_evidence("coffee"), "UI collection path respects inspect-only items")
	game.close_modal()
	game.show_locations()
	await settle()
	var reception: Button
	for target in game._card_grid.get_children():
		if target.get_meta("item_id") == "reception":
			reception = target
	await touch(reception)
	check(game.session.current_location == "reception" and not game.overlay.visible, "Location navigation opens existing background")
	await settle()
	footer_fits()
	game.travel_to("office")
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 800)]:
		root.size = dimensions
		await settle()
		footer_fits()
		var bounds := Rect2(Vector2.ZERO, root.size)
		for target in room._hotspots.get_children():
			check(bounds.encloses(target.get_global_rect()), "Scene hotspots stay within viewport after resize")
	root.size = Vector2i(1280, 720)
	await settle()
	await capture("footer")
	game.queue_free()
	await process_frame
	print("CRIME SCENE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
