extends MarginContainer
## Insets are logical viewport units; desktop preview keeps a 20px design margin.
func _ready() -> void:
	resized.connect(_apply_safe_area)
	_apply_safe_area()

func _apply_safe_area() -> void:
	var insets := Vector4(20, 20, 20, 20)
	if OS.has_feature("mobile"):
		var screen := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and safe.has_area():
			var scale_factor := get_viewport_rect().size / screen
			insets.x = maxf(20, safe.position.x * scale_factor.x)
			insets.y = maxf(20, safe.position.y * scale_factor.y)
			insets.z = maxf(20, (screen.x - safe.end.x) * scale_factor.x)
			insets.w = maxf(20, (screen.y - safe.end.y) * scale_factor.y)
	for i in range(4):
		add_theme_constant_override("margin_" + ["left", "top", "right", "bottom"][i], ceili(insets[i]))
