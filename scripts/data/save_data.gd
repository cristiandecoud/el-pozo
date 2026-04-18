extends Node

const SAVE_PATH := "user://save_data.json"

var settings: Dictionary = {
	"font_size": 14,
	"animation_speed": 1.0,
	"card_theme": "classic",
	"well_size": 2,
	"bot_turn_delay": 0.5,
}
var players: Dictionary = {}  # name → stats dict

# Transient data for the current game session — never written to disk.
var session: Dictionary = {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_data()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		if parsed.has("settings"):
			settings.merge(parsed["settings"], true)
		if parsed.has("players"):
			players = parsed["players"]

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"settings": settings,
		"players": players
	}, "\t"))
	file.close()

# ── Settings ──────────────────────────────────────────────────────────────────

func get_setting(key: String, default_val: Variant = null) -> Variant:
	return settings.get(key, default_val)

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_data()

# ── Sesión ────────────────────────────────────────────────────────────────────

# Called from GameSetup before launching the game scene. Registers the player,
# persists the last-used name, and stores transient session data (not saved).
func start_session(player_name: String, player_color: Color, bot_count: int) -> void:
	ensure_player(player_name)
	settings["last_player_name"] = player_name
	save_data()
	session["player_name"]  = player_name
	session["player_color"] = player_color.to_html()
	session["bot_count"]    = bot_count

func get_session_color() -> Color:
	return Color(session.get("player_color", "#F5C518"))

# ── Estadísticas de jugador ───────────────────────────────────────────────────

func ensure_player(name: String) -> void:
	if not players.has(name):
		players[name] = {
			"games_played": 0,
			"wins": 0,
			"losses": 0,
			"cards_played": 0,
			"fastest_win_turns": 0
		}
		save_data()

# Records a full game result in a single disk write.
func record_game_result(name: String, won: bool, turns: int, cards: int) -> void:
	ensure_player(name)
	players[name]["games_played"] += 1
	players[name]["cards_played"] += cards
	if won:
		players[name]["wins"] += 1
		var fastest: int = players[name]["fastest_win_turns"] as int
		if fastest == 0 or turns < fastest:
			players[name]["fastest_win_turns"] = turns
	else:
		players[name]["losses"] += 1
	save_data()

func get_player_stats(name: String) -> Dictionary:
	ensure_player(name)
	return players[name]

func all_player_names() -> Array:
	return players.keys()
