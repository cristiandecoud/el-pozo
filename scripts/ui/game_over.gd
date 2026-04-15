class_name GameOver
extends CanvasLayer

@onready var result_label: Label    = $Root/Panel/VBox/ResultLabel
@onready var winner_name: Label     = $Root/Panel/VBox/WinnerName
@onready var turns_label: Label     = $Root/Panel/VBox/TurnsLabel
@onready var cards_label: Label     = $Root/Panel/VBox/CardsLabel
@onready var play_again_btn: Button = $Root/Panel/VBox/PlayAgainBtn
@onready var main_menu_btn: Button  = $Root/Panel/VBox/MainMenuBtn

func setup(winner: Player, _human_name: String, turns: int, cards: int) -> void:
	if winner.is_human:
		result_label.text = "¡Ganaste!"
		result_label.add_theme_color_override("font_color", Color("#F5C518"))
	else:
		result_label.text = "¡Perdiste!"
		result_label.add_theme_color_override("font_color", Color("#CC2222"))
	winner_name.text = winner.name
	turns_label.text = "Turnos jugados: " + str(turns)
	cards_label.text = "Cartas jugadas: " + str(cards)

	play_again_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://escenas/game/game.tscn"))
	main_menu_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://escenas/ui/main_menu/main_menu.tscn"))
