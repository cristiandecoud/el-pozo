class_name HUDView
extends HBoxContainer

signal end_turn_requested()

@onready var turn_label: Label = $TurnLabel
@onready var end_turn_btn: Button = $EndTurnBtn

func _ready() -> void:
	end_turn_btn.pressed.connect(func(): end_turn_requested.emit())

func set_status(text: String) -> void:
	turn_label.text = text

func log_action(_text: String) -> void:
	pass  # sin log en MVP

func disable_actions() -> void:
	end_turn_btn.disabled = true

func refresh(gm: GameManager) -> void:
	var p := gm.current_player()
	end_turn_btn.visible = p.is_human
	end_turn_btn.disabled = false
