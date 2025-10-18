extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES DINÁMICAS
# ----------------------------------------------------------------------

@export var max_acceleration: float = 200.0   
@export var max_speed: float = 200.0          
@export var max_prediction: float = 1.0 

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
enum State { STOPPED, FLEEING } 
var current_state = State.STOPPED 

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		jugador = players[0]
	print("Dynamic Flee: STOPPED. Presiona 6 para activar.")

func _input(event):
	if event is InputEventKey and event.keycode == KEY_6 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.FLEEING
			print("Dynamic Flee activado.")
		else:
			current_state = State.STOPPED
			print("Dynamic Flee desactivado.")

# ----------------------------------------------------------------------
# LÓGICA LINEAL: DYNAMIC FLEE
# ----------------------------------------------------------------------

func get_flee_steering(target_position: Vector2) -> Vector2:
	# 1. Dirección OPUESTA al objetivo 
	var direction = global_position - target_position
	
	if direction.length_squared() == 0.0:
		return Vector2.ZERO
		
	# 2. Aceleración máxima en la dirección de fuga
	return direction.normalized() * max_acceleration
	
# ----------------------------------------------------------------------
# LÓGICA ANGULAR: LOOK WHERE YOU'RE GOING 
# ----------------------------------------------------------------------

func map_to_range(angle: float) -> float:
	return fposmod(angle + PI, 2 * PI) - PI

func get_look_where_youre_going_steering() -> float:
	var current_velocity = velocity
	if current_velocity.length_squared() == 0.0: return 0.0

	var target_orientation_raw = current_velocity.angle()
	var target_orientation_compensated = target_orientation_raw + PI/2 
	
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
# PROCESAMIENTO PRINCIPAL (INTEGRACIÓN DINÁMICA)
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	if not is_instance_valid(jugador): 
		velocity = Vector2.ZERO
		return

	var linear_acceleration = Vector2.ZERO

	if current_state == State.FLEEING:
		linear_acceleration = get_flee_steering(jugador.global_position)
	else:
		# Frenar al detenerse
		linear_acceleration = velocity.normalized() * -max_acceleration

	# 1. Limitación e Integración de Velocidad Lineal
	if linear_acceleration.length_squared() > max_acceleration * max_acceleration:
		linear_acceleration = linear_acceleration.normalized() * max_acceleration
	
	velocity += linear_acceleration * delta
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	# 2. Integración de Rotación (LWGYG)
	var angular_acceleration = get_look_where_youre_going_steering()
	current_rotation_speed += angular_acceleration * delta
	current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	move_and_slide()
	rotation += current_rotation_speed * delta
