extends CanvasLayer

# Notifies `Main` node that the button has been pressed
signal start_game

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
	$ScoreLabel.text = str(score)

func _on_start_button_pressed():
	$StartButton.hide()
	start_game.emit()

func _on_message_timer_timeout():
	$Message.hide()
