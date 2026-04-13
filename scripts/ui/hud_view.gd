# HUDView — Status bar and turn control interface
#
# Why it exists:
#   The player needs to know at all times what is expected of them, and have a
#   button to end their turn. HUDView centralizes that communication: it is the
#   only zone for status text and the only global action control.
#
# What it does:
#   - Shows a dynamic status message (TurnLabel) that guides the player.
#   - Shows a scrolling log of the last 3 played actions (LogLabel).
#   - Exposes the "End turn" button and emits end_turn_requested when pressed.
#   - Hides the button during the bot's turn (refresh handles this).
#   - disable_actions() locks the button when the game ends.
#
# Design:
#   Dark panel background distinguishes the HUD from the green game area.
#   The log is maintained as a capped list of 3 strings, joined with newlines.

class_name HUDView
extends PanelContainer

signal end_turn_requested()

@onready var turn_label: Label  = $VBox/ControlRow/TurnLabel
@onready var end_turn_btn: Button = $VBox/ControlRow/EndTurnBtn
@onready var log_label: Label   = $VBox/LogLabel

var _log_lines: Array[String] = []

func _ready() -> void:
	end_turn_btn.pressed.connect(func(): end_turn_requested.emit())
	# LogLabel is hidden until there are entries, to keep the HUD compact
	log_label.visible = false
	# Dark background with a thin green top border to separate from game area
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1A2530")
	style.set_border_width_all(0)
	style.border_width_top = 2
	style.border_color = Color("#44BB88")
	style.set_content_margin_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	add_theme_stylebox_override("panel", style)

# Updates the main status text.
func set_status(text: String) -> void:
	turn_label.text = text

# Appends a line to the action log, keeping at most 3 entries.
func log_action(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 3:
		_log_lines.pop_front()
	log_label.text = "\n".join(_log_lines)
	log_label.visible = true

# Disables controls at the end of the game (victory).
func disable_actions() -> void:
	end_turn_btn.disabled = true

# Syncs the HUD with the current turn: hides the button when the bot plays.
func refresh(gm: GameManager) -> void:
	var p := gm.current_player()
	end_turn_btn.visible = p.is_human
	end_turn_btn.disabled = false
