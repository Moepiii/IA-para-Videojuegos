extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES DINÁMICAS (Angular)
# ----------------------------------------------------------------------

@export var max_angular_acceleration: float = 3.0 # Máxima aceleración angular 
@export var max_rotation: float = 1.5             # Máxima velocidad de rotación 
@export var target_radius: float = 0.005          # Radio de detención total (targetRadius)
@export var slow_radius: float = 0.5              # Radio para comenzar a desacelerar (slowRadius)
@export var time_to_target: float = 0.1           # Tiempo para alcanzar la velocidad objetivo (timeToTarget)

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var jugador: CharacterBody2D = null 
var current_rotation_speed: float = 0.0 
enum State { STOPPED, ALIGNING } 
var current_state = State.STOPPED

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		jugador = players[0]
	print("Dynamic Align: STOPPED. Presiona 9 para activar.")

func _input(event):
	# tecla 9
	if event is InputEventKey and event.keycode == KEY_9 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.ALIGNING
			print("Dynamic Align activado.")
		else:
			current_state = State.STOPPED
			print("Dynamic Align desactivado.")

# ----------------------------------------------------------------------
# FUNCIÓN AUXILIAR (mapToRange)
# ----------------------------------------------------------------------

# Transforma el ángulo al rango [-PI, PI] para encontrar el camino más corto.
func map_to_range(angle: float) -> float:
	# En Godot, fposmod es la función equivalente a % para flotantes
	return fposmod(angle + PI, 2 * PI) - PI

# ----------------------------------------------------------------------
# ALGORITMO DYNAMIC ALIGN
# ----------------------------------------------------------------------

func get_align_steering(target_orientation: float) -> float:
	
	# 1. Obtener la diferencia angular "ingenua"
	# target.orientation - character.orientation
	var rotation_difference = target_orientation - rotation
	
	# 2. Mapear al rango [-PI, PI]
	rotation_difference = map_to_range(rotation_difference)
	var rotation_size = abs(rotation_difference) # Magnitud

	# 3. Chequear detención total (targetRadius)
	if rotation_size < target_radius: 
		# Aplicamos aceleración opuesta a la rotación actual para frenar
		return -current_rotation_speed / time_to_target 
		
	# 4. Calcular la Velocidad de Rotación Objetivo (targetRotation)
	var target_rotation: float
	
	if rotation_size > slow_radius:
		target_rotation = max_rotation
	else:
		# Desaceleración suave y proporcional (como en Arrive)
		target_rotation = max_rotation * rotation_size / slow_radius

	# 5. Aplicar la dirección (sentido horario o antihorario)
	# targetRotation *= rotation / rotationSize
	target_rotation *= rotation_difference / rotation_size
	
	# 6. Calcular la Aceleración Angular (SteeringOutput.angular)
	# result.angular = targetRotation - character.rotation (velocidad angular actual)
	var angular_acceleration = target_rotation - current_rotation_speed
	angular_acceleration /= time_to_target
	
	# 7. Limitar la Aceleración Angular
	if abs(angular_acceleration) > max_angular_acceleration:
		angular_acceleration = sign(angular_acceleration) * max_angular_acceleration

	return angular_acceleration

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL (INTEGRACIÓN DINÁMICA)
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	if not is_instance_valid(jugador): return

	var angular_acceleration = 0.0

	if current_state == State.ALIGNING:
		# Nota: Si el jugador es un CharacterBody2D, target.orientation es su 'rotation'
		angular_acceleration = get_align_steering(jugador.rotation)
		
		# Movemos la velocidad lineal a cero para que solo rote
		velocity = velocity.move_toward(Vector2.ZERO, 100 * delta)
	else:
		# Frenar la rotación y el movimiento
		angular_acceleration = -current_rotation_speed / time_to_target
		velocity = velocity.move_toward(Vector2.ZERO, 100 * delta)

	# 1. Integración de Rotación Angular
	current_rotation_speed += angular_acceleration * delta
	current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	move_and_slide()
	rotation += current_rotation_speed * delta
