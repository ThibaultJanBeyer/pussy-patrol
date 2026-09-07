extends CanvasLayer

# Notifies `Main` node that the button has been pressed
signal start_game

const FILLED_COLOR := Color(0.85, 0.1, 0.1, 1) # red, a life you still have
const EMPTY_COLOR := Color(0.6, 0.6, 0.6, 1) # grey, a life spent

func _ready():
	$StatsDisplay.hide()

func show_message(text):
	$Message.text = text
	$Message.show()
	$MessageTimer.start()

func show_game_over():
	$Message.text = "Game Over"
	$Message.show()
	# Let the player skip the auto-restart countdown by starting manually.
	$StartButton.show()

func show_countdown(seconds_left: int) -> void:
	$Message.text = "Game Over\nNext round in %d..." % seconds_left
	$Message.show()

func reset() -> void:
	$Message.hide()
	$StartButton.hide()

func update_score(score):
	$StatsDisplay/ScoreDisplay/ScoreLabel.text = str(score)

func update_lives(lives: int, _max_lives: int) -> void:
	var bars := $StatsDisplay/LivesDisplay/Bars.get_children()
	for i in bars.size():
		bars[i].color = FILLED_COLOR if i < lives else EMPTY_COLOR

func _on_start_button_pressed():
	$StatsDisplay.show()
	$StartButton.hide()
	start_game.emit()

func _on_message_timer_timeout():
	$Message.hide()
