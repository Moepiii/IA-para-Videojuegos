extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES EXPORTADAS
# ----------------------------------------------------------------------

@export var max_acceleration: float = 300.0
@export var max_speed: float = 200.0
@export var max_prediction: float = 10.0     

# Parámetros de LOOK WHERE YOU'RE GOING
@export var max_angular_acceleration: float = 5.0
@export var max_rotation: float = 3.0             
@export var target_radius: float = 0.005          
@export var slow_radius: float = 0.5              
@export var time_to_target: float = 0.1           

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var jugador: CharacterBody2D = null 
var current_rotation_speed: float = 0.0 
enum State { STOPPED, PURSUE } 
var current_state = State.STOPPED #  Comienza detenido

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		jugador = players[0]
	print("Perseguidor: STOPPED. Presiona W para alternar el estado.")

func _input(event):
	# Alternar el estado con la tecla W
	if event is InputEventKey and event.keycode == KEY_W and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.PURSUE
			print("Perseguidor activado: PURSUE")
		else:
			current_state = State.STOPPED
			print("Perseguidor desactivado: STOPPED")

# ----------------------------------------------------------------------
# LÓGICA LINEAL Y ANGULAR
# ----------------------------------------------------------------------

func get_seek_steering(target_position: Vector2) -> Vector2:
	var acceleration = target_position - global_position
	return acceleration.normalized() * max_acceleration
	
func map_to_range(angle: float) -> float:
	return fposmod(angle + PI, 2 * PI) - PI

func get_predicted_target_position() -> Vector2:
	if not is_instance_valid(jugador): return global_position
	
	var direction = jugador.global_position - global_position
	var distance = direction.length()
	var speed = velocity.length()
	
	var prediction: float
	if speed <= 0.1 or speed <= distance / max_prediction:
		prediction = max_prediction
	else:
		prediction = distance / speed
		
	return jugador.global_position + jugador.velocity * prediction

func get_look_where_youre_going_steering() -> float:
	var current_velocity = velocity
	if current_velocity.length_squared() == 0.0: return 0.0

	var target_orientation_raw = current_velocity.angle()
	var target_orientation_compensated = target_orientation_raw + PI/2 # COMPENSACIÓN
	
	var rotation_difference = map_to_range(target_orientation_compensated - rotation)
	
	if abs(rotation_difference) < target_radius: 
		current_rotation_speed = 0.0 
		return 0.0

	var target_rotation: float
	if abs(rotation_difference) > slow_radius:
		target_rotation = max_rotation 
	else:
		target_rotation = max_rotation * abs(rotation_difference) / slow_radius

	target_rotation *= rotation_difference / abs(rotation_difference)
	
	var angular_acceleration = target_rotation - current_rotation_speed
	angular_acceleration /= time_to_target
	
	if abs(angular_acceleration) > max_angular_acceleration:
		angular_acceleration = sign(angular_acceleration) * max_angular_acceleration

	return angular_acceleration

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	if not is_instance_valid(jugador): 
		velocity = Vector2.ZERO
		return

	var linear_acceleration = Vector2.ZERO

	if current_state == State.PURSUE:
		# PURSUE ACTIVO: Perseguir con Seek
		var predicted_target_position = get_predicted_target_position()
		linear_acceleration = get_seek_steering(predicted_target_position)
	else:
		# STOPPED: Frenar hasta detenerse
		velocity = velocity.move_toward(Vector2.ZERO, max_acceleration * delta)

	# Límite e integración de velocidad lineal
	if linear_acceleration.length_squared() > 0.0:
		if linear_acceleration.length() > max_acceleration:
			linear_acceleration = linear_acceleration.normalized() * max_acceleration
		
		velocity += linear_acceleration * delta
		
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed
	
	# Rotación (Look Where You're Going)
	var angular_acceleration = get_look_where_youre_going_steering()
	current_rotation_speed += angular_acceleration * delta
	current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	move_and_slide()
	rotation += current_rotation_speed * delta
