extends Node

const FONT := preload("res://fonts/Chewy-Regular.ttf")

func floating_text(world_position: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.z_index = 100
	label.position = world_position
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", world_position + Vector2(0, -70), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.tween_callback(label.queue_free)

func play_oneshot(stream: AudioStream, world_position: Vector2 = Vector2.ZERO) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.position = world_position
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
