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

var timer_label: Label
var format_label: Label
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

	# Create timer label (top center, below state)
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.anchor_left = 0.5
	timer_label.anchor_top = 0.12
	timer_label.anchor_right = 0.5
	timer_label.anchor_bottom = 0.12
	timer_label.offset_left = -40
	timer_label.offset_top = -12
	timer_label.offset_right = 40
	timer_label.offset_bottom = 12
	timer_label.grow_horizontal = 2
	timer_label.horizontal_alignment = 1
	timer_label.add_theme_font_size_override("font_size", 18)
	add_child(timer_label)

	# Create format label (top left)
	format_label = Label.new()
	format_label.name = "FormatLabel"
	format_label.anchor_left = 0.02
	format_label.anchor_top = 0.02
	format_label.anchor_right = 0.02
	format_label.anchor_bottom = 0.02
	format_label.offset_right = 120
	format_label.offset_bottom = 20
	format_label.horizontal_alignment = 0
	format_label.add_theme_font_size_override("font_size", 16)
	add_child(format_label)

	GameManager.connect("point_scored", _on_point_scored)
	GameManager.connect("bout_halted", _on_bout_halted)
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
		GameManager.GameState.HALF_TIME:
			state_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		_:
			state_label.add_theme_color_override("font_color", Color.WHITE)

	# Update timer display
	if GameManager.current_state == GameManager.GameState.FOUGHT:
		timer_label.text = GameManager.get_timer_string()
		timer_label.visible = true
	else:
		timer_label.visible = false

	# Update format display
	var format_text = GameManager.get_format_name()
	if GameManager.match_format == GameManager.MatchFormat.DE:
		format_text += "  |  P%d" % GameManager.current_period
	format_label.text = format_text

func _show_msg(text: String, duration: float = 1.5) -> void:
	message_label.text = text
	msg_timer = duration

func _on_point_scored(scorer: String, is_double: bool, line: String, p2_line: String) -> void:
	if is_double:
		var line_text = ""
		if line != "" or p2_line != "":
			line_text = " (%s / %s)" % [line, p2_line]
		_show_msg("DOUBLE TOUCH!" + line_text, 2.0)
	elif scorer == "player1":
		var line_text = ""
		if line != "":
			line_text = " " + line
		_show_msg("Touch" + line_text + "! You score!", 1.8)
	else:
		var line_text = ""
		if line != "":
			line_text = " " + line
		_show_msg("Touch" + line_text + "! Opponent scores!", 1.8)

func _on_bout_halted(reason: String) -> void:
	if reason != "":
		_show_msg(reason.to_upper() + "!", 2.0)
	else:
		_show_msg("HALT!", 2.0)

func _on_match_ended() -> void:
	victory_panel.visible = true
	restart_btn.visible = true
	controls_panel.visible = false

	var winner = GameManager.get_winner()
	var format_str = GameManager.get_format_name()
	if winner == "player1":
		victory_text.text = "YOU WIN!\n%s - %s\n(%s)" % [str(GameManager.player1_score), str(GameManager.player2_score), format_str]
	elif winner == "player2":
		victory_text.text = "OPPONENT WINS!\n%s - %s\n(%s)" % [str(GameManager.player1_score), str(GameManager.player2_score), format_str]
	else:
		victory_text.text = "DRAW!\n%s - %s\n(%s)" % [str(GameManager.player1_score), str(GameManager.player2_score), format_str]

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

	if event.is_action_pressed("toggle_format"):
		if GameManager.current_state == GameManager.GameState.IDLE:
			GameManager.toggle_format()
			# Update controls text to reflect new format
			var controls_text = controls_panel.get_node_or_null("VBox/ControlsText")
			if controls_text:
				var touches = 5 if GameManager.match_format == GameManager.MatchFormat.POOL else 15
				var lines = controls_text.text.split("\n")
				for i in range(lines.size()):
					if lines[i].begins_with("First to"):
						lines[i] = "First to %d touches wins! (3:00)" % touches
				controls_text.text = "\n".join(lines)
