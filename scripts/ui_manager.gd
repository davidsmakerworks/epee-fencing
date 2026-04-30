extends Control

# UI Manager - handles all HUD elements, scores, messages, and match state display

@onready var p1_score: Label = $HUD/HBox/P1Score
@onready var p2_score: Label = $HUD/HBox/P2Score
@onready var state_label: Label = $HUD/HBox/StateLabel
@onready var message_label: Label = $MessageLabel
@onready var victory_panel: Control = $VictoryPanel
@onready var victory_text: Label = $VictoryPanel/VictoryText
@onready var controls_panel: Control = $ControlsPanel
@onready var restart_btn: Button = $RestartButton

var msg_timer: float = 0.0

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

	match GameManager.current_state:
		GameManager.GameState.FOUGHT:
			state_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		GameManager.GameState.POINT:
			state_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		GameManager.GameState.ENDED:
			state_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		_:
			state_label.add_theme_color_override("font_color", Color.WHITE)

func _show_msg(text: String, duration: float = 1.5) -> void:
	message_label.text = text
	msg_timer = duration

func _on_point_scored(scorer: String, is_double: bool) -> void:
	if is_double:
		_show_msg("DOUBLE TOUCH!", 2.0)
	elif scorer == "player1":
		_show_msg("Touch! You score!", 1.8)
	else:
		_show_msg("Touch! Opponent scores!", 1.8)

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
