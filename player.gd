extends Area2D

signal hit
@export var speed = 400 # How fast the player will move (pixels/sec).
var screen_size # Size of the game window.

enum State { IDLE, WALK, TO_SIT, TO_WALK }
var state := State.IDLE

func start(pos):
	position = pos
	show()
	_set_state(State.IDLE)

func _ready():
	screen_size = get_viewport_rect().size
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	_apply_collision(State.IDLE)
	hide()

func _process(delta):
	var velocity = Vector2.ZERO # The player's movement vector.
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
		velocity = velocity.normalized() * speed
		if state == State.IDLE or state == State.TO_SIT:
			_set_state(State.TO_WALK)
		position += velocity * delta
		position = position.clamp(Vector2.ZERO, screen_size)
		if velocity.x != 0:
			$AnimatedSprite2D.flip_v = false
			$AnimatedSprite2D.flip_h = velocity.x > 0
	else:
		if state == State.WALK or state == State.TO_WALK:
			_set_state(State.TO_SIT)

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	var sprite := $AnimatedSprite2D
	match state:
		State.IDLE:
			sprite.play("idle")
		State.WALK:
			sprite.play("walk")
		State.TO_SIT:
			sprite.play("walk_to_sit")
		State.TO_WALK:
			# Same frames as walk→sit, played backwards.
			sprite.play("walk_to_sit", -1.0, true)
	_apply_collision(state)

func _apply_collision(for_state: State) -> void:
	var sitting := for_state == State.IDLE or for_state == State.TO_SIT
	$SitCollision.disabled = not sitting
	$WalkCollision.disabled = sitting

func _on_animation_finished() -> void:
	if state == State.TO_SIT:
		_set_state(State.IDLE)
	elif state == State.TO_WALK:
		_set_state(State.WALK)


func _on_body_entered(_body):
	hide() # Player disappears after being hit.
	hit.emit()
	# Must be deferred as we can't change physics properties on a physics callback.
	$WalkCollision.set_deferred("disabled", true)
	$SitCollision.set_deferred("disabled", true)
