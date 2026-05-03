# LadderView — Visual representation of a ladder slot
#
# Why it exists:
#   LadderManager keeps ladders as Arrays of Cards (pure logic). LadderView
#   presents that data as an actual CardView (the top card) so the player can
#   see at a glance what is on each ladder. It is also the interaction point:
#   clicking anywhere in the slot emits ladder_clicked.
#
# What it does:
#   - Instantiates a real CardView showing the top card of the ladder, or
#     leaves the slot empty if no card has been played yet.
#   - Shows a small "Needs: X" label below the card slot.
#   - Emits ladder_clicked with its index when the user clicks anywhere in the slot.
#   - Highlights (green tint) the slot via set_valid_target(true) when the
#     currently selected card can be played here.
#
# Design:
#   No panel background — the CardView is the only visual element. This avoids
#   a "card inside a white box" appearance. The VBoxContainer root has
#   mouse_filter = STOP so clicks anywhere in the slot (even on empty space)
#   are captured and forwarded as ladder_clicked. The CardView inside has
#   mouse_filter = IGNORE so it does not intercept those clicks.

class_name LadderView
extends VBoxContainer

signal ladder_clicked(ladder_index: int)

var ladder_data: Array = []
var ladder_index: int = -1

@onready var card_area: Control  = $CardArea
@onready var next_label: Label   = $NextNeeded

const CardScene := preload("res://escenas/ui/card/card.tscn")
const COLOR_MUTED := Color("#AAAAAA")
const CARD_W := 180
const CARD_H := 260

var _bg_style: StyleBoxFlat

func _ready() -> void:
	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = Color("#0A1E1E")
	_bg_style.set_border_width_all(1)
	_bg_style.border_color = Color("#2A6060")
	_bg_style.set_corner_radius_all(6)
	resized.connect(queue_redraw)
	next_label.add_theme_color_override("font_color", COLOR_MUTED)
	gui_input.connect(_on_gui_input)
	refresh()

func _draw() -> void:
	draw_style_box(_bg_style, Rect2(Vector2.ZERO, size))

# Highlights the slot with a green tint when the selected card can be played here.
func set_valid_target(valid: bool) -> void:
	modulate = Color(0.80, 1.0, 0.85, 1.0) if valid else Color(1, 1, 1, 1)

# Rebuilds the CardView from the current ladder_data.
func refresh() -> void:
	if not is_inside_tree():
		return
	# Clear the previous card and any shadow nodes
	for child in card_area.get_children():
		child.queue_free()

	if ladder_data.is_empty():
		next_label.text = "Needs: A"
	else:
		var top: Card = ladder_data.back()

		# Stacking shadow effect: 1 shadow for 2 cards, 2 shadows for 3+
		var shadow_levels := clampi(ladder_data.size() - 1, 0, 2)
		for i in range(shadow_levels, 0, -1):
			var shadow := Panel.new()
			var ss := StyleBoxFlat.new()
			ss.bg_color = Color("#0D1E1E")
			ss.set_border_width_all(1)
			ss.border_color = Color("#1E4040")
			ss.set_corner_radius_all(6)
			shadow.add_theme_stylebox_override("panel", ss)
			shadow.custom_minimum_size = Vector2(CARD_W, CARD_H)
			shadow.size = Vector2(CARD_W, CARD_H)
			shadow.position = Vector2(i * 5, i * 5)
			card_area.add_child(shadow)

		var cv: CardView = CardScene.instantiate()
		cv.card_data = top
		# MOUSE_FILTER_IGNORE: clicks pass through to the LadderView root
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_area.add_child(cv)
		# Fill the card_area so the card is properly anchored
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var next_val := top.value + 1
		if next_val > Card.MAX_VALUE:
			next_label.text = "Complete ✓"
		else:
			next_label.text = "Needs: " + Card.value_to_string(next_val)

# Emits ladder_clicked when the player clicks anywhere in the slot.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	   and event.button_index == MOUSE_BUTTON_LEFT:
		ladder_clicked.emit(ladder_index)
