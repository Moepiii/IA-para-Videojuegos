extends CharacterBody2D

@export var move_speed: float = 150.0
@export var chase_speed_multiplier: float = 1.8 

# 🛑 DEBES ARRASTRAR EL NODO 'GrafoRegiones' AQUÍ EN EL INSPECTOR
@export var grafo_regiones: Node2D 

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var timer_descanso: Timer = $TimerDescanso # Debe llamarse 'TimerDescanso'

# Máquina de Estados
enum Estado { PATRULLA, DESCANSO } 
var estado_actual = Estado.PATRULLA

var ruta_posiciones_alto_nivel = [] 
var punto_destino_actual: Vector2 = Vector2.ZERO
var ultimo_punto_patrulla: Vector2 = Vector2.ZERO 

func _ready():
	await get_tree().physics_frame
	
	if timer_descanso != null:
		timer_descanso.timeout.connect(_on_timer_descanso_timeout)
	
	# 🛑 CORRECCIÓN: Usa la señal 'path_changed' de Godot 4.
	nav_agent.path_changed.connect(queue_redraw) 

	_elegir_siguiente_destino_patrulla()

func _physics_process(_delta): # Se corrige la advertencia 'UNUSED_PARAMETER'
	# Si no se puede alcanzar el target, se queda quieto
	if not nav_agent.is_target_reachable(): 
		velocity = Vector2.ZERO

	match estado_actual:
		Estado.PATRULLA:
			_logica_estado_patrulla(_delta)
		Estado.DESCANSO:
			_logica_estado_descanso(_delta)
	
	move_and_slide() 

# --- Lógica de Estados ---

func _logica_estado_patrulla(_delta):
	# 1. Comprueba si ha llegado al Waypoint actual
	if global_position.distance_to(punto_destino_actual) < 10: 
		if not ruta_posiciones_alto_nivel.is_empty():
			_avanzar_al_siguiente_punto_alto_nivel()
		else:
			ultimo_punto_patrulla = punto_destino_actual
			_entrar_estado_descanso()
		return
	
	# 2. Muévete hacia el siguiente punto de bajo nivel
	var direccion = global_position.direction_to(nav_agent.get_next_path_position())
	velocity = direccion * move_speed

func _logica_estado_descanso(_delta):
	velocity = Vector2.ZERO

# --- Transiciones y Señales ---

func _entrar_estado_patrulla():
	estado_actual = Estado.PATRULLA
	_elegir_siguiente_destino_patrulla()
	
func _entrar_estado_descanso():
	estado_actual = Estado.DESCANSO
	if timer_descanso != null:
		timer_descanso.start()

func _on_timer_descanso_timeout():
	_entrar_estado_patrulla()

# --- Funciones de Pathfinding Jerárquico ---

func _elegir_siguiente_destino_patrulla():
	if grafo_regiones == null: return
	
	var target_pos_patrulla = grafo_regiones.get_random_waypoint_position()
	
	var intentos = 0
	var max_intentos = 10 
	while target_pos_patrulla.is_equal_approx(global_position) and intentos < max_intentos:
		target_pos_patrulla = grafo_regiones.get_random_waypoint_position()
		intentos += 1

	iniciar_navegacion_a(target_pos_patrulla)
	ultimo_punto_patrulla = target_pos_patrulla

func iniciar_navegacion_a(posicion_destino: Vector2):
	if grafo_regiones == null: return
	
	ruta_posiciones_alto_nivel = grafo_regiones.encontrar_ruta_alto_nivel(global_position, posicion_destino)
	
	if ruta_posiciones_alto_nivel.is_empty():
		return
	
	_avanzar_al_siguiente_punto_alto_nivel()

func _avanzar_al_siguiente_punto_alto_nivel():
	if ruta_posiciones_alto_nivel.is_empty():
		return 
		
	punto_destino_actual = ruta_posiciones_alto_nivel.pop_front()
	nav_agent.target_position = punto_destino_actual


func _draw():
	# 🛑 CORRECCIÓN: Usa get_current_navigation_path() para la línea AMARILLA (Bajo Nivel)
	var path = nav_agent.get_current_navigation_path()
	if path.size() > 1:
		for i in range(path.size() - 1):
			draw_line(path[i] - global_position, path[i+1] - global_position, Color.YELLOW, 3.0) 

	# 🛑 Dibujo de la ruta azul (Alto Nivel) ELIMINADO para evitar el conflicto visual.
