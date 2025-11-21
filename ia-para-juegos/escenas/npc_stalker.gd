class_name StalkerNPC
extends CharacterBody2D

# --- MÁQUINA DE ESTADOS ---
enum State {
	PATROL,     # Patrullando nodos al azar
	CHASE,      # Persecución (Híbrida: Táctica o Directa)
	SEARCH,     # Buscando en la última posición conocida
	IDLE        # Descansando
}
var current_state: State = State.IDLE

# --- CONFIGURACIÓN ---
@export var speed: float = 135.0
@export var acceleration: float = 10.0
@export var rotation_speed: float = 8.0
@export var sprite_faces_up: bool = true
@export var vision_range: float = 100.0
@export var arrival_threshold: float = 15.0

# --- REFERENCIAS ---
@export var player: CharacterBody2D
@export var region_graph: RegionGraph
@export var assigned_room_node_path: NodePath

var assigned_room: Habitacion
var room_graph_manual: Node2D 

# --- VARIABLES INTERNAS ---
var ruta_manual: PackedVector2Array = []
var indice_ruta: int = 0
var idle_timer: Timer
var last_known_player_pos: Vector2 = Vector2.ZERO

var habitacion_actual_npc: Node = null
var cooldown_teletransporte: bool = false 

# Variable Táctica: ¿Ya fui al centro de esta sala?
var is_at_tactical_post: bool = false

func _ready():
	idle_timer = Timer.new()
	idle_timer.wait_time = 3.0
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	add_child(idle_timer)
	
	await get_tree().process_frame
	
	if get_node_or_null(assigned_room_node_path) is Habitacion:
		assigned_room = get_node(assigned_room_node_path)
		_actualizar_grafo_navegacion(assigned_room)
	
	set_state(State.PATROL)

# --- 🌀 AL CRUZAR PORTAL ---
func recibir_teletransporte():
	print("👻 Stalker en nueva sala. Buscando centro...")
	velocity = Vector2.ZERO
	ruta_manual.clear()
	cooldown_teletransporte = true
	
	# [CRUCIAL] Reseteamos la táctica para obligarlo a ir al centro
	is_at_tactical_post = false 
	
	if region_graph:
		var nueva_sala = region_graph.get_region_node_from_body(self)
		if nueva_sala: 
			_actualizar_grafo_navegacion(nueva_sala)
			
			if can_see_player():
				set_state(State.CHASE)
			else:
				set_state(State.SEARCH)

	await get_tree().create_timer(0.2).timeout
	cooldown_teletransporte = false

func _actualizar_grafo_navegacion(sala_nueva: Node):
	if sala_nueva == habitacion_actual_npc: return 
	habitacion_actual_npc = sala_nueva
	
	if sala_nueva.has_node("Waypoints"):
		room_graph_manual = sala_nueva.get_node("Waypoints")

# --- CONTROL DE ESTADOS ---
func set_state(new_state: State):
	current_state = new_state
	
	match new_state:
		State.IDLE:
			idle_timer.start()
			velocity = Vector2.ZERO
			
		State.PATROL:
			idle_timer.stop()
			var destino = _get_random_waypoint()
			_calcular_ruta_hacia(destino)
			
		State.CHASE:
			idle_timer.stop()
			
		State.SEARCH:
			idle_timer.stop()
			_calcular_ruta_hacia(last_known_player_pos)

func _physics_process(delta):
	if cooldown_teletransporte: return
	if not player or not region_graph: return

	# 1. Actualizar ubicación
	var nueva_sala = region_graph.get_region_node_from_body(self)
	if nueva_sala and nueva_sala != habitacion_actual_npc:
		_actualizar_grafo_navegacion(nueva_sala)

	# 2. Detección
	var veo_jugador = can_see_player()
	
	if veo_jugador:
		last_known_player_pos = player.global_position
		if current_state != State.CHASE:
			set_state(State.CHASE)
	
	# 3. Ejecución de Movimiento
	match current_state:
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
			move_and_slide()
			
		State.PATROL:
			_mover_por_ruta(delta)
			
		State.SEARCH:
			_mover_por_ruta(delta)
			
		State.CHASE:
			_mover_persecucion_hibrida(delta)
			
	_rotar_hacia_movimiento(delta)


# --- LÓGICA DE DECISIÓN ---
func _mover_persecucion_hibrida(delta):
	var player_room = region_graph.get_region_node_from_body(player)
	
	# PROTECCIÓN: Si no sé dónde estoy, busco al jugador directo
	if not habitacion_actual_npc:
		_comportamiento_directo(delta)
		return

	# REGLA 1: Si no he ido al centro, VOY AL CENTRO (Ignoro jugador)
	if not is_at_tactical_post:
		_comportamiento_tactico_nodos(delta)
		return

	# REGLA 2: Si ya fui al centro, decido según dónde esté el jugador
	if player_room == habitacion_actual_npc:
		_comportamiento_tactico_nodos(delta) # Atacar usando nodos
	else:
		_comportamiento_directo(delta) # Perseguir a otra sala


# --- COMPORTAMIENTO A: INTELIGENTE / TÁCTICO ---
func _comportamiento_tactico_nodos(delta):
	var objetivo_final = Vector2.ZERO
	
	# 1. Obtener posición del Marker2D (Centro Táctico)
	var centro_sala = Vector2.ZERO
	if habitacion_actual_npc.has_node("Marker2D"):
		centro_sala = habitacion_actual_npc.get_node("Marker2D").global_position
	else:
		# Si la sala no tiene Marker, usamos su posición global como fallback
		centro_sala = habitacion_actual_npc.global_position 
	
	# --- FASE 1: IR AL CENTRO ---
	if not is_at_tactical_post:
		objetivo_final = centro_sala
		
		# Chequear si llegamos
		if global_position.distance_to(centro_sala) < 30.0:
			is_at_tactical_post = true
			print("👻 Stalker: Centro asegurado. ¡Ahora voy por ti!")
			# Pequeño hack: Retornamos para que en el siguiente frame recalcule hacia el jugador
			return 
	
	# --- FASE 2: IR A POR EL JUGADOR ---
	else:
		objetivo_final = player.global_position

	# --- CÁLCULO DE RUTA ---
	
	# Si no hay grafo de nodos, vamos directo al objetivo (sea centro o jugador)
	if not room_graph_manual or not "astar" in room_graph_manual:
		_mover_directo_a_punto(objetivo_final, delta)
		return

	var id_npc = room_graph_manual.astar.get_closest_point(global_position)
	var id_target = room_graph_manual.astar.get_closest_point(objetivo_final)
	
	# [ATAQUE FINAL] Si ya estoy atacando y no hay nodos en medio...
	if is_at_tactical_post and id_npc == id_target:
		_mover_directo_a_punto(player.global_position, delta)
		return

	# Navegación normal por nodos
	var siguiente_punto = objetivo_final
	if id_npc != -1 and id_target != -1:
		var r = room_graph_manual.astar.get_point_path(id_npc, id_target)
		if r.size() > 1: siguiente_punto = r[1]
		elif r.size() == 1: siguiente_punto = r[0]
	
	_mover_directo_a_punto(siguiente_punto, delta)


# --- COMPORTAMIENTO B: DIRECTO ---
func _comportamiento_directo(delta):
	_mover_directo_a_punto(player.global_position, delta)

func _mover_directo_a_punto(destino: Vector2, delta):
	var dir = (destino - global_position).normalized()
	velocity = velocity.lerp(dir * speed, acceleration * delta)
	move_and_slide()


# --- LÓGICA: PATRULLA Y BÚSQUEDA ---
func _mover_por_ruta(delta):
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		
		if velocity.length() < 5.0:
			if current_state == State.PATROL: set_state(State.IDLE)
			elif current_state == State.SEARCH: set_state(State.PATROL)
		return

	var objetivo = ruta_manual[indice_ruta]
	if global_position.distance_to(objetivo) < arrival_threshold:
		indice_ruta += 1
		return

	var dir = (objetivo - global_position).normalized()
	velocity = velocity.lerp(dir * speed, acceleration * delta)
	move_and_slide()


# --- AUXILIARES ---

func can_see_player() -> bool:
	return global_position.distance_to(player.global_position) < vision_range

func _on_idle_timer_timeout():
	if current_state == State.IDLE:
		set_state(State.PATROL)

func _calcular_ruta_hacia(destino: Vector2):
	if room_graph_manual and "astar" in room_graph_manual:
		var id_ini = room_graph_manual.astar.get_closest_point(global_position)
		var id_fin = room_graph_manual.astar.get_closest_point(destino)
		if id_ini != -1 and id_fin != -1:
			ruta_manual = room_graph_manual.astar.get_point_path(id_ini, id_fin)
			indice_ruta = 0
		else:
			ruta_manual = []

func _get_random_waypoint() -> Vector2:
	if room_graph_manual and "astar" in room_graph_manual:
		var ids = room_graph_manual.astar.get_point_ids()
		if ids.size() > 0:
			return room_graph_manual.astar.get_point_position(ids[randi() % ids.size()])
	return global_position

func _rotar_hacia_movimiento(delta):
	if velocity.length() > 5.0:
		var angle = velocity.angle() 
		if sprite_faces_up: angle += PI/2 
		rotation = lerp_angle(rotation, angle, rotation_speed * delta)
