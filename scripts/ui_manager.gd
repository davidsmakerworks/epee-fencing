extends Control

# UI Manager - handles all HUD elements, scores, messages, and match state display

@onready var p1_score: Label = $HUD/HBox/P1Score
@onready var p2_score: Label = $HUD/HBox/P2Score
@onready var state_label: Label = $HUD/HBox/StateLabel
@onready var clock_label: Label = $HUD/HBox/ClockLabel
@onready var message_label: Label = $MessageLabel
@onready var victory_panel: Control = $VictoryPanel
@onready var victory_text: Label = $VictoryPanel/VictoryText
@onready var controls_panel: Control = $ControlsPanel
@onready var restart_btn: Button = $RestartButton
@onready var easy_btn: Button = $ControlsPanel/VBox/DiffButtons/EasyBtn
@onready var medium_btn: Button = $ControlsPanel/VBox/DiffButtons/MediumBtn
@onready var hard_btn: Button = $ControlsPanel/VBox/DiffButtons/HardBtn

const DIFF_EASY: float = 0.4
const DIFF_MEDIUM: float = 0.65
const DIFF_HARD: float = 0.85

var msg_timer: float = 0.0
var selected_difficulty: float = DIFF_MEDIUM

func _ready() -> void:
	_init_ui()

func _init_ui() -> void:
	p1_score.text = "0"
	p2_score.text = "0"
	state_label.text = "EPÉE"
	message_label.text = ""
	victory_panel.visible = false
	controls_panel.visible = true
	restart_btn.visible = false

	GameManager.connect("point_scored", _on_point_scored)
	GameManager.connect("match_ended", _on_match_ended)
	GameManager.connect("bout_reset", _on_bout_reset)

	easy_btn.pressed.connect(_on_easy_pressed)
	medium_btn.pressed.connect(_on_medium_pressed)
	hard_btn.pressed.connect(_on_hard_pressed)

	_highlight_difficulty(selected_difficulty)

func _highlight_difficulty(diff: float) -> void:
	easy_btn.modulate = Color(1, 1, 1) if diff == DIFF_EASY else Color(0.6, 0.6, 0.6)
	medium_btn.modulate = Color(1, 1, 1) if diff == DIFF_MEDIUM else Color(0.6, 0.6, 0.6)
	hard_btn.modulate = Color(1, 1, 1) if diff == DIFF_HARD else Color(0.6, 0.6, 0.6)

func _on_easy_pressed() -> void:
	selected_difficulty = DIFF_EASY
	_highlight_difficulty(DIFF_EASY)

func _on_medium_pressed() -> void:
	selected_difficulty = DIFF_MEDIUM
	_highlight_difficulty(DIFF_MEDIUM)

func _on_hard_pressed() -> void:
	selected_difficulty = DIFF_HARD
	_highlight_difficulty(DIFF_HARD)

func _process(delta: float) -> void:
	_update_hud(delta)

func _update_hud(delta: float) -> void:
	if msg_timer > 0:
		msg_timer -= delta
		if msg_timer <= 0:
			message_label.text = ""

	p1_score.text = str(GameManager.player1_score)
	p2_score.text = str(GameManager.player2_score)

	var state_name = GameManager.get_state_name()
	state_label.text = state_name

	if GameManager.is_period_running or GameManager.current_state == GameManager.GameState.PRIORITY:
		clock_label.text = GameManager.get_time_string()

	match GameManager.current_state:
		GameManager.GameState.FOUGHT:
			state_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		GameManager.GameState.POINT:
			state_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		GameManager.GameState.ENDED:
			state_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		GameManager.GameState.PERIOD_BREAK:
			state_label.add_theme_color_override("font_color", Color(0.5, 0.5, 1.0))
			clock_label.text = ""
		GameManager.GameState.PRIORITY:
			state_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
		_:
			state_label.add_theme_color_override("font_color", Color.WHITE)

func _show_msg(text: String, duration: float = 1.5) -> void:
	message_label.text = text
	msg_timer = duration

func _on_point_scored(scorer: String, is_double: bool) -> void:
	if is_double:
		_show_msg("DOUBLE TOUCH!", 2.0)
	elif scorer == "player1":
		_show_msg("Touch! " + GameManager.last_hit_zone + " hit!", 1.8)
	elif scorer == "player2":
		_show_msg("Touch! Opponent " + GameManager.last_hit_zone + "!", 1.8)
	elif scorer == "side_p1" or scorer == "side_p2":
		_show_msg("OUT OF BOUNDS!", 1.8)
	elif scorer == "corps_p1" or scorer == "corps_p2":
		_show_msg("CORPS A CORPS - HALT!", 1.8)
	elif scorer == "passivity":
		_show_msg("PASSIVITY - HALT!", 1.8)

func _on_match_ended() -> void:
	victory_panel.visible = true
	restart_btn.visible = true
	controls_panel.visible = false

	var winner = GameManager.get_winner()
	if winner == "player1":
		victory_text.text = "YOU WIN!\n%s - %s" % [str(GameManager.player1_score), str(GameManager.player2_score)]
	elif winner == "player2":
		victory_text.text = "OPPONENT WINS!\n%s - %s" % [str(GameManager.player1_score), str(GameManager.player2_score)]
	else:
		victory_text.text = "DRAW!\n%s - %s" % [str(GameManager.player1_score), str(GameManager.player2_score)]

func _on_bout_reset() -> void:
	pass

func _on_restart_button_pressed() -> void:
	GameManager.reset_match()
	victory_panel.visible = false
	restart_btn.visible = false
	controls_panel.visible = true
	state_label.text = "EPÉE"
	message_label.text = "Press ENTER or SPACE to start"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if GameManager.current_state == GameManager.GameState.IDLE:
			GameManager.start_match()
			controls_panel.visible = false
		elif GameManager.current_state == GameManager.GameState.ENDED:
			_on_restart_button_pressed()