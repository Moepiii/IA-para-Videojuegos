extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES EXPORTADAS (Cinematic Flee)
# ----------------------------------------------------------------------

@export var max_speed: float = 200.0          # Velocidad lineal máxima para huir
@export var flee_slow_radius: float = 300.0   # Radio de seguridad: al alcanzar esta distancia, frenará.
@export var target_radius: float = 5.0        # Radio de detención es pequeño, solo para frenar al llegar a flee_slow_radius)

# Parámetros para la función update (time/delta)
@export var time_to_target: float = 0.1 

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var jugador: CharacterBody2D = null 
enum State { STOPPED, FLEEING } 
var current_state = State.STOPPED # Comienza detenido

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		jugador = players[0]
		print(" Jugador encontrado: ", jugador.name)
	else:
		print(" ERROR: Jugador no encontrado.")
		
	print("Cinematic Flee: STOPPED. Presiona 3 para alternar el estado.")

func _input(event):
	#  tecla 3 
	if event is InputEventKey and event.keycode == KEY_3 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.FLEEING
			print("Cinematic Flee activado: FLEEING")
		else:
			current_state = State.STOPPED
			print("Cinematic Flee desactivado: STOPPED")

# ----------------------------------------------------------------------
# LÓGICA CINEMÁTICA AUXILIAR
# ----------------------------------------------------------------------

# Función newOrientation: Establece la orientación para mirar en la dirección de la velocidad.
func new_orientation(current_orientation: float, new_velocity: Vector2) -> float:
	if new_velocity.length_squared() > 0:
		var target_angle = new_velocity.angle()
		# +PI/2
		return target_angle + PI/2
	else:
		return current_orientation

# ----------------------------------------------------------------------
# ALGORITMO CINEMATIC FLEE
# ----------------------------------------------------------------------

# Simula la función getSteering() de Flee, que es un Seek inverso.
func get_cinematic_flee_output(target_position: Vector2):
	var result_velocity = Vector2.ZERO
	
	# 1. Obtener la dirección y distancia al objetivo (Jugador).
	var direction = global_position - target_position # Dirección para afuera
	var distance = direction.length()
	
	# 2. Comprobación de seguridad: Detenerse si ya está suficientemente lejos.
	if distance > flee_slow_radius:
		# Si está lo suficientemente lejos, simula el frenado suave
		var target_speed = max_speed * (flee_slow_radius + target_radius - distance) / target_radius
		
		# parado total si la velocidad calculada es menor a 0.
		if target_speed <= 0:
			velocity = Vector2.ZERO
			return
		
		# Establecer la velocidad de frenado
		result_velocity = direction.normalized() * target_speed
	
	else:
		# 3. Fuga si está dentro del radio de seguridad, huir a máxima velocidad.
		if direction.length_squared() > 0:
			result_velocity = direction.normalized() * max_speed
		
	# 4. Face in the direction we want to move (Away from the target).
	rotation = new_orientation(rotation, result_velocity)
	
	# 5. Asignar la velocidad final.
	velocity = result_velocity

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	if not is_instance_valid(jugador): 
		velocity = Vector2.ZERO
		return

	if current_state == State.FLEEING:
		# Calcular el resultado cinemático
		get_cinematic_flee_output(jugador.global_position)
		
	else:
		#  Frenar suavemente hasta detenerse 
		var deceleration_rate = max_speed / time_to_target 
		velocity = velocity.move_toward(Vector2.ZERO, deceleration_rate * delta)
		
	# Aplicar el movimiento cinemático
	move_and_slide()
