extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES LINEALES (Dynamic Velocity Match)
# ----------------------------------------------------------------------

@export_group("Lineal Match")
@export var max_acceleration: float = 500.0   # Máxima aceleración lineal
@export var max_speed: float = 1200.0          # Límite de velocidad
@export var linear_time_to_target: float = 0.1 # Tiempo para alcanzar la velocidad objetivo

# ----------------------------------------------------------------------
# PROPIEDADES ANGULARES (Dynamic Align)
# ----------------------------------------------------------------------
@export_group("Angular Align")
@export var max_angular_acceleration: float = 635.0
@export var max_rotation: float = 3.0
@export var align_target_radius: float = 0.005 # Radio de detención total
@export var align_slow_radius: float = 0.5     # Radio para comenzar a desacelerar
@export var align_time_to_target: float = 0.1  # Tiempo para alcanzar la rotación objetivo

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var jugador: CharacterBody2D = null
var current_rotation_speed: float = 0.0
enum State { STOPPED, MATCHING }
var current_state = State.STOPPED

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		jugador = players[0]
	print("Dynamic Match + Align: STOPPED. Presiona 0 para activar.")

func _input(event):
	# TECLA 0
	if event is InputEventKey and event.keycode == KEY_0 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.MATCHING
			print("Dynamic Match + Align activado.")
		else:
			current_state = State.STOPPED
			print("Dynamic Match + Align desactivado.")

# ----------------------------------------------------------------------
# ALGORITMO DYNAMIC VELOCITY MATCH (Lineal)
# ----------------------------------------------------------------------

func get_velocity_match_steering(target_velocity: Vector2) -> Vector2:
	
	# Aceleración necesaria = (Velocidad Objetivo - Velocidad Actual) / Tiempo
	var linear_acceleration = target_velocity - velocity
	linear_acceleration /= linear_time_to_target 
	
	# Limitar la Aceleración
	if linear_acceleration.length() > max_acceleration:
		linear_acceleration = linear_acceleration.normalized() * max_acceleration

	return linear_acceleration

# ----------------------------------------------------------------------
# LÓGICA ANGULAR: DYNAMIC ALIGN
# ----------------------------------------------------------------------

func map_to_range(angle: float) -> float:
	return fposmod(angle + PI, 2 * PI) - PI

func get_align_steering(target_orientation: float) -> float:
	
	# 1. Diferencia angular y magnitud
	var rotation_difference = map_to_range(target_orientation - rotation)
	var rotation_size = abs(rotation_difference)
	
	# 2. Chequear detención total
	if rotation_size < align_target_radius:
		# Frenar suavemente si ya estamos alineados
		return -current_rotation_speed / align_time_to_target
		
	# 3. Calcular la Velocidad de Rotación Objetivo (targetRotation)
	var target_rotation: float
	
	if rotation_size > align_slow_radius:
		target_rotation = max_rotation
	else:
		# Desaceleración suave y proporcional
		target_rotation = max_rotation * rotation_size / align_slow_radius

	# 4. Aplicar la dirección (sentido)
	target_rotation *= rotation_difference / rotation_size
	
	# 5. Calcular la Aceleración Angular
	var angular_acceleration = target_rotation - current_rotation_speed
	angular_acceleration /= align_time_to_target
	
	# 6. Limitar la Aceleración Angular
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
	var angular_acceleration = 0.0

	if current_state == State.MATCHING:
		# LINEAL: Igualar la velocidad del objetivo (jugador)
		linear_acceleration = get_velocity_match_steering(jugador.velocity)
		
		# ANGULAR: Alinear la rotación con la rotación del objetivo (jugador)
		angular_acceleration = get_align_steering(jugador.rotation)
		
	else:
		# STOPPED: Frenar suavemente la rotación y el movimiento
		linear_acceleration = velocity.normalized() * -max_acceleration
		angular_acceleration = -current_rotation_speed / align_time_to_target
		
	# --- INTEGRACIÓN DE MOVIMIENTO ---

	# 1. Integración de Velocidad Lineal
	linear_acceleration = linear_acceleration.limit_length(max_acceleration)
	velocity += linear_acceleration * delta
	velocity = velocity.limit_length(max_speed)
	
	# 2. Integración de Rotación Angular
	current_rotation_speed += angular_acceleration * delta
	current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	move_and_slide()
	rotation += current_rotation_speed * delta
