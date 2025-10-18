extends CharacterBody2D

# ====================================================================
# CLASES DE DATOS SEGÚN TU ESPECIFICACIÓN
# ====================================================================

# 1. Clase Static: Posición y orientación del personaje
class Static:
	var position: Vector2 = Vector2.ZERO
	var orientation: float = 0.0

# 2. Clase KinematicSteeringOutput: Resultado de los algoritmos cinemáticos
class KinematicSteeringOutput:
	var velocity: Vector2 = Vector2.ZERO # Velocidad deseada
	var rotation: float = 0.0           # Velocidad angular deseada

# ====================================================================
# PROPIEDADES Y ESTADO DEL OVNI
# ====================================================================

@export var max_speed: float = 200.0 
@export var radius: float = 10.0      
@export var time_to_target: float = 0.5 

# Referencia al nodo jugador. Como tu jugador es el único CharacterBody2D
# que no es el OVNI, lo buscaremos por su nombre en la escena (puede que se llame
# "CharacterBody2D" o algo más como "Jugador").
# Basado en tu imagen, intentaremos encontrar el nodo por su nombre.
const JUGADOR_NOMBRE: String = "CharacterBody2D" 

var ovni_static: Static = Static.new()
var target_static: Static = Static.new()
var jugador_node: Node2D = null

# ====================================================================
# FUNCIÓN DE ORIENTACIÓN
# ====================================================================

func new_orientation(current: float, velocity: Vector2) -> float:
	# newOrientation(current: float, velocity: Vector) -> float
	if velocity.length_squared() > 0:
		# En Godot, angle() es equivalente a atan2(y, x).
		return velocity.angle()
	return current

# ====================================================================
# ALGORITMO: KINEMATIC ARRIVE
# ====================================================================

func kinematic_arrive(ovni: Static, target: Static) -> KinematicSteeringOutput:
	# Implementación de la clase KinematicArrive.
	var result: KinematicSteeringOutput = KinematicSteeringOutput.new()

	# Get the direction to the target.
	var direction: Vector2 = target.position - ovni.position
	var distance: float = direction.length()

	# Check if we’re within radius (Rango Interior).
	if distance < radius:
		return result # Retorna velocidad cero por defecto.

	# We need to move to our target, we’d like to get there in timeToTarget seconds.
	var speed: float = distance / time_to_target
	
	# If this is too fast, clip it to the max speed (Rango Exterior).
	var target_speed: float = min(speed, max_speed)
	
	# Calcular velocidad vectorial final.
	result.velocity = direction.normalized() * target_speed

	# Face in the direction we want to move.
	# Modifica la orientación de los datos Static del personaje.
	ovni_static.orientation = new_orientation(ovni.orientation, result.velocity)
	
	result.rotation = 0
	return result

# ====================================================================
# BUCLE PRINCIPAL DE JUEGO
# ====================================================================

func _ready():
	# Buscamos el nodo jugador por el nombre que tiene en el árbol de escena.
	# Asumimos que el jugador está en el mismo nivel que el OVNI (hijo de "Mundo").
	if get_parent() and get_parent().has_node(JUGADOR_NOMBRE):
		jugador_node = get_parent().get_node(JUGADOR_NOMBRE)
	
	if !jugador_node:
		print("ERROR: No se encontró el nodo jugador: " + JUGADOR_NOMBRE + ". Verifica que el nombre del nodo es correcto.")
		set_physics_process(false)
		return
		
	# Inicializar datos estáticos del OVNI
	ovni_static.position = global_position
	ovni_static.orientation = rotation
	velocity = Vector2.ZERO

func _physics_process(delta):
	if !jugador_node:
		return

	# 1. ACTUALIZAR LOS DATOS DE ENTRADA (Static)
	target_static.position = jugador_node.global_position
	ovni_static.position = global_position
	ovni_static.orientation = rotation

	# 2. EJECUTAR EL ALGORITMO CINEMÁTICO
	var steering: KinematicSteeringOutput = kinematic_arrive(ovni_static, target_static)

	# 3. APLICAR EL MOVIMIENTO
	if steering:
		# Actualización cinemática simple: P_nueva = P_vieja + V_deseada * tiempo
		global_position += steering.velocity * delta
		
		# Sincronizar orientación y velocidad del nodo con el resultado del algoritmo.
		rotation = ovni_static.orientation
		velocity = steering.velocity
		
		# move_and_slide() aplica la velocidad final y resuelve colisiones.
		move_and_slide()
	else:
		# Si steering es null (detenido por el radio), forzamos la detención.
		velocity = Vector2.ZERO
		move_and_slide()
