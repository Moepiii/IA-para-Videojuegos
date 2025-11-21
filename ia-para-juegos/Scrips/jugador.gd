extends CharacterBody2D

# Variables de Movimiento Manual 
@export var speed = 800
@export var acceleration = 1800
@export var rotation_speed = 5.0 

var target_direction = Vector2.ZERO

func _physics_process(delta):
	# 1. Llama a la función que procesa el input del jugador
	manual_control_process(delta)
	# 2. Aplica el movimiento y la colisión
	move_and_slide()


# Control Manual del Jugador

func manual_control_process(delta):
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.y += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		target_direction = input_dir
	else:
		target_direction = Vector2.ZERO

	# --- 3. Aplicar Rotación y Velocidad ---
	if target_direction != Vector2.ZERO:
		var target_angle = (target_direction * -1).angle() - deg_to_rad(90)
		rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)
		velocity = velocity.move_toward(target_direction * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
