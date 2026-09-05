extends Area2D

signal hit
@export var speed = 400 # How fast the player will move (pixels/sec).
var screen_size # Size of the game window.

enum State { IDLE, WALK, TO_SIT, TO_WALK, HIT }
var state := State.IDLE
# If the player releases move mid stand-up, finish standing first then sit.
var sit_after_stand := false

# Touch/drag-to-follow: while held, overrides keyboard movement and steers
# toward the pointer instead. Mouse works the same way so this is testable
# on desktop; a real touch also emits emulated mouse events, which is fine
# since both paths land on the same drag_target.
var drag_active := false
var drag_target := Vector2.ZERO

func start(pos):
	position = pos
	show()
	set_process(true)
	sit_after_stand = false
	_set_state(State.IDLE)

func _ready():
	screen_size = get_viewport_rect().size
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	hide()
	await get_tree().physics_frame
	_apply_collision(State.IDLE)

func _input(event: InputEvent) -> void:
	# Not _unhandled_input: Godot's GUI layer absorbs mouse/touch events
	# before they get there whenever the scene has any Control node (here,
	# the HUD's Start button and labels), even far from those controls.
	if event is InputEventScreenTouch:
		drag_active = event.pressed
		if event.pressed:
			drag_target = event.position
	elif event is InputEventScreenDrag:
		drag_active = true
		drag_target = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drag_active = event.pressed
		if event.pressed:
			drag_target = event.position
	elif event is InputEventMouseMotion and drag_active:
		drag_target = event.position

func _process(delta):
	if state == State.HIT:
		return

	var velocity = Vector2.ZERO # The player's movement vector.
	if drag_active:
		var to_target = drag_target - position
		# Close enough: stop steering instead of jittering back and forth
		# across the target every frame.
		if to_target.length() > 2.0:
			velocity = to_target.normalized()
	else:
		if Input.is_action_pressed("move_right"):
			velocity.x += 1
		if Input.is_action_pressed("move_left"):
			velocity.x -= 1
		if Input.is_action_pressed("move_down"):
			velocity.y += 1
		if Input.is_action_pressed("move_up"):
			velocity.y -= 1

	var wants_to_move := velocity.length() > 0

	if wants_to_move:
		sit_after_stand = false
		velocity = velocity.normalized() * speed
		if state == State.IDLE or state == State.TO_SIT:
			_set_state(State.TO_WALK)
		position += velocity * delta
		position = position.clamp(Vector2.ZERO, screen_size)
		if velocity.x != 0:
			$AnimatedSprite2D.flip_v = false
			$AnimatedSprite2D.flip_h = velocity.x > 0
	else:
		if state == State.WALK:
			_set_state(State.TO_SIT)
		elif state == State.TO_WALK:
			# Brief tap: finish stand-up visually, then sit — movement already happened.
			sit_after_stand = true

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	var prev := state
	state = new_state
	var sprite := $AnimatedSprite2D
	match state:
		State.IDLE:
			sprite.play("idle")
		State.WALK:
			sprite.play("walk")
		State.TO_SIT:
			if prev == State.TO_WALK and sprite.animation == &"walk_to_sit":
				# Reverse from the current stand-up frame instead of snapping.
				var frame: int = sprite.frame
				var progress: float = sprite.frame_progress
				sprite.play("walk_to_sit")
				sprite.set_frame_and_progress(frame, progress)
			else:
				sprite.play("walk_to_sit")
		State.TO_WALK:
			if prev == State.TO_SIT and sprite.animation == &"walk_to_sit":
				var frame: int = sprite.frame
				var progress: float = sprite.frame_progress
				sprite.play("walk_to_sit", -1.0, false)
				sprite.set_frame_and_progress(frame, progress)
			else:
				# Same frames as walk→sit, played backwards.
				sprite.play("walk_to_sit", -1.0, true)
		State.HIT:
			sit_after_stand = false
			sprite.play("water")
	_apply_collision(state)

func _apply_collision(for_state: State) -> void:
	if for_state == State.HIT:
		$SitCollision.set_deferred("disabled", true)
		$WalkCollision.set_deferred("disabled", true)
		return
	var sitting := for_state == State.IDLE or for_state == State.TO_SIT
	$SitCollision.set_deferred("disabled", not sitting)
	$WalkCollision.set_deferred("disabled", sitting)

func _on_animation_finished() -> void:
	if state == State.TO_SIT:
		_set_state(State.IDLE)
	elif state == State.TO_WALK:
		if sit_after_stand:
			sit_after_stand = false
			_set_state(State.TO_SIT)
		else:
			_set_state(State.WALK)

func _on_body_entered(body):
	if state == State.HIT:
		return
	if body.has_method("explode"):
		body.explode()
	set_process(false)
	_set_state(State.HIT)
	hit.emit()
