class_name LadderView
extends PanelContainer

signal ladder_clicked(ladder_index: int)

var ladder_data: Array = []
var ladder_index: int = -1

@onready var top_card_label: Label = $VBoxContainer/TopCard
@onready var next_label: Label = $VBoxContainer/NextNeeded

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	if ladder_data.is_empty():
		top_card_label.text = "—"
		next_label.text = "Necesita: A"
	else:
		var top: Card = ladder_data.back()
		top_card_label.text = top.label()
		var next_val := top.value + 1
		if next_val > 13:
			next_label.text = "Completa ✓"
		else:
			var next_display := str(next_val)
			match next_val:
				1:  next_display = "A"
				11: next_display = "J"
				12: next_display = "Q"
				13: next_display = "K"
			next_label.text = "Necesita: " + next_display

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	   and event.button_index == MOUSE_BUTTON_LEFT:
		ladder_clicked.emit(ladder_index)
