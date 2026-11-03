extends Control
var variant := "office"
## Original vector scenery, scaled to the available room area.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 470))
	if variant == "reception":
		_draw_reception()
		return
	draw_rect(Rect2(0, 0, 1280, 470), Color("202d38"))
	draw_rect(Rect2(0, 340, 1280, 130), Color("28353b"))
	for x in range(0, 1280, 80):
		draw_line(Vector2(x, 340), Vector2(x - 100, 470), Color("35434a"), 2)
	draw_style_box(_panel(Color("111f31"), Color("637783")), Rect2(100, 38, 310, 220))
	draw_circle(Vector2(340, 87), 24, Color("c9d6cf"))
	for x in range(115, 390, 42):
		draw_rect(Rect2(x, 160 + x % 37, 32, 90), Color("26394b"))
	draw_line(Vector2(255, 40), Vector2(255, 255), Color("637783"), 7)
	draw_line(Vector2(102, 145), Vector2(408, 145), Color("637783"), 7)
	draw_style_box(_panel(Color("35454c"), Color("65746f")), Rect2(970, 70, 230, 290))
	for y in [95, 180, 265]:
		for x in range(990, 1170, 30):
			draw_rect(Rect2(x, y, 22, 60), Color("8b8973") if x % 60 == 0 else Color("526b70"))
		draw_line(Vector2(980, y + 66), Vector2(1190, y + 66), Color("a39378"), 5)
	draw_style_box(_panel(Color("293b43"), Color("b4a17c")), Rect2(520, 30, 210, 105))
	draw_circle(Vector2(625, 82), 30, Color("596e71"))
	draw_rect(Rect2(360, 345, 35, 110), Color("4b3e36"))
	draw_rect(Rect2(860, 345, 35, 110), Color("4b3e36"))
	draw_style_box(_panel(Color("82705a"), Color("ad9876")), Rect2(320, 260, 620, 90))
	draw_line(Vector2(840, 265), Vector2(825, 174), Color("b5ac8b"), 7)
	draw_colored_polygon(PackedVector2Array([Vector2(780, 189), Vector2(868, 189), Vector2(842, 151), Vector2(806, 151)]), Color("dac38d"))
	draw_rect(Rect2(420, 275, 56, 35), Color("16232a"))
	draw_line(Vector2(445, 277), Vector2(435, 295), Color("b4d9dc"), 2)
	draw_line(Vector2(435, 295), Vector2(459, 307), Color("b4d9dc"), 2)
	draw_circle(Vector2(600, 292), 22, Color("d4c3a3"))
	draw_circle(Vector2(600, 292), 15, Color("48362c"))
	draw_arc(Vector2(625, 292), 11, -1.5, 1.5, 16, Color("d4c3a3"), 5)
	draw_rect(Rect2(700, 275, 75, 43), Color("dfd3b3"))
	for y in [286, 297, 308]:
		draw_line(Vector2(712, y), Vector2(760, y), Color("827660"), 2)

func _panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	return style

func _draw_reception() -> void:
	draw_rect(Rect2(0, 0, 1280, 470), Color("27383e"))
	draw_rect(Rect2(0, 340, 1280, 130), Color("1d2e34"))
	for x in range(0, 1280, 100):
		draw_line(Vector2(x, 340), Vector2(x - 100, 470), Color("405157"), 2)
	draw_style_box(_panel(Color("443e39"), Color("8f8872")), Rect2(880, 55, 225, 300))
	draw_circle(Vector2(915, 210), 7, Color("d9c88f"))
	draw_circle(Vector2(640, 85), 47, Color("dad0b0"))
	draw_line(Vector2(640, 85), Vector2(640, 50), Color("293a40"), 4)
	draw_line(Vector2(640, 85), Vector2(668, 85), Color("293a40"), 4)
	draw_style_box(_panel(Color("74644e"), Color("baa27b")), Rect2(320, 290, 470, 120))
	draw_rect(Rect2(610, 230, 100, 65), Color("18272e"))
	draw_rect(Rect2(645, 295, 30, 10), Color("8e9c9c"))
	draw_circle(Vector2(175, 243), 30, Color("c9aa8c"))
	draw_style_box(_panel(Color("53777b"), Color("73999a")), Rect2(130, 275, 90, 100))
	draw_rect(Rect2(138, 375, 25, 70), Color("182a36"))
	draw_rect(Rect2(187, 375, 25, 70), Color("182a36"))
