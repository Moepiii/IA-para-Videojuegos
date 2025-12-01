class_name CobardeNPC
extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var speed: float = 140.0
@export var acceleration: float = 10.0
@export var rotation_speed: float = 10.0 
@export var spin_speed: float = 4.0 
@export var sprite_faces_up: bool = true
@export var arrival_threshold: float = 5.0 
@export var min_node_distance: int = 2     

# --- REFERENCIAS ---
@export var player: CharacterBody2D
@export var region_graph: RegionGraph
@export var assigned_room_node_path: NodePath

var assigned_room: Habitacion
var room_graph_manual: Node2D 

# --- VARIABLES ---
var ruta_manual: PackedVector2Array = []
var indice_ruta: int = 0
var timer_recalculo: Timer 
var habitacion_actual_npc: Node = null

# Lista de tareas para cuando revisa la sala
var nodos_por_visitar: Array = [] 

enum State { SPINNING, PANIC, FLEE, RELAXING }
var current_state = State.SPINNING

# --- [NUEVO] PERFIL TÁCTICO: EL MIEDOSO ---
# Define qué le gusta y qué odia
var mis_pesos = {
	"w_cobertura": -0.8, # Le encanta la cobertura (reduce costo, lo atrae)
	"w_luz": 4.0,        # Odia la luz (aumenta costo, la evita)
	"w_alto": 0.0,       # Le da igual la altura
	"w_peligro": 20.0    # TERROR absoluto al jugador (evita acercarse a él a toda costa)
}

func _ready():
	timer_recalculo = Timer.new()
	timer_recalculo.wait_time = 0.5
	timer_recalculo.one_shot = false 
	timer_recalculo.timeout.connect(_on_recalculate_timer)
	add_child(timer_recalculo)
	
	await get_tree().process_frame
	
	if get_node_or_null(assigned_room_node_path) is Habitacion:
		assigned_room = get_node(assigned_room_node_path)
		_actualizar_grafo(assigned_room)
	
	set_state(State.SPINNING)

func _actualizar_grafo(sala_nueva: Node):
	habitacion_actual_npc = sala_nueva
	if sala_nueva.has_node("Waypoints"):
		room_graph_manual = sala_nueva.get_node("Waypoints")

func set_state(new_state):
	current_state = new_state
	
	match new_state:
		State.SPINNING:
			timer_recalculo.stop()
			ruta_manual.clear()
			velocity = Vector2.ZERO
			
		State.PANIC:
			timer_recalculo.stop()
			velocity = Vector2.ZERO
			# Mirar al jugador antes de correr
			await get_tree().create_timer(1.0).timeout
			if current_state == State.PANIC:
				set_state(State.FLEE)
			
		State.FLEE:
			timer_recalculo.start()
			_buscar_refugio_lejos()
			
		State.RELAXING:
			timer_recalculo.stop()
			# PREPARAR LA RONDA DE INSPECCIÓN TÁCTICA
			if room_graph_manual and "astar" in room_graph_manual:
				nodos_por_visitar = room_graph_manual.astar.get_point_ids()
				nodos_por_visitar.shuffle()
				_ir_al_siguiente_nodo_inspeccion()
			else:
				set_state(State.SPINNING)

func _physics_process(delta):
	if not player or not region_graph: return

	# 1. Detección
	var my_room = region_graph.get_region_node_from_body(self)
	var player_room = region_graph.get_region_node_from_body(player)
	
	if my_room != habitacion_actual_npc:
		_actualizar_grafo(my_room)

	# 2. Cambio de Comportamiento
	if player_room == habitacion_actual_npc:
		if current_state == State.SPINNING or current_state == State.RELAXING:
			set_state(State.PANIC)
	else:
		if current_state == State.FLEE or current_state == State.PANIC:
			set_state(State.RELAXING)

	# 3. Ejecución
	match current_state:
		State.FLEE:
			_mover_por_ruta_huida(delta)
		State.RELAXING:
			_mover_por_ruta_inspeccion(delta)
		State.SPINNING:
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
			rotation += spin_speed * delta
			move_and_slide()
		State.PANIC:
			velocity = Vector2.ZERO
			_rotar_hacia_objetivo(player.global_position, delta)
			move_and_slide()

# --- LÓGICA DE MOVIMIENTO HUIDA ---
func _mover_por_ruta_huida(delta):
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return

	var objetivo = ruta_manual[indice_ruta]
	if global_position.distance_to(objetivo) < arrival_threshold:
		indice_ruta += 1
		if indice_ruta >= ruta_manual.size():
			velocity = Vector2.ZERO
			ruta_manual.clear() 
		return

	var dir = (objetivo - global_position).normalized()
	velocity = velocity.lerp(dir * speed, acceleration * delta)
	move_and_slide()
	_rotar_hacia_movimiento(delta)

# --- LÓGICA DE MOVIMIENTO INSPECCIÓN (RELAXING) ---
func _mover_por_ruta_inspeccion(delta):
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		_ir_al_siguiente_nodo_inspeccion()
		return

	var objetivo = ruta_manual[indice_ruta]
	
	if global_position.distance_to(objetivo) < arrival_threshold:
		indice_ruta += 1
		return

	var dir = (objetivo - global_position).normalized()
	velocity = velocity.lerp(dir * (speed * 0.8), acceleration * delta)
	move_and_slide()
	_rotar_hacia_movimiento(delta)

func _ir_al_siguiente_nodo_inspeccion():
	if nodos_por_visitar.is_empty():
		set_state(State.SPINNING)
		return
	
	if not room_graph_manual: return
	
	var siguiente_id = nodos_por_visitar.pop_front()
	var destino = room_graph_manual.astar.get_point_position(siguiente_id)
	
	# [CAMBIO TÁCTICO] Usar ruta inteligente para ir al siguiente punto
	if room_graph_manual.has_method("obtener_ruta_tactica"):
		ruta_manual = room_graph_manual.obtener_ruta_tactica(
			global_position, 
			destino, 
			mis_pesos, 
			player.global_position
		)
	else:
		# Fallback al pathfinding normal
		var mi_id = room_graph_manual.astar.get_closest_point(global_position)
		ruta_manual = room_graph_manual.astar.get_point_path(mi_id, siguiente_id)
		
	indice_ruta = 0

# --- CEREBRO: BUSCAR REFUGIO (AHORA TÁCTICO) ---
func _buscar_refugio_lejos():
	if not room_graph_manual or not "astar" in room_graph_manual: return
	
	var astar = room_graph_manual.astar
	var id_npc = astar.get_closest_point(global_position)
	var id_player = astar.get_closest_point(player.global_position)
	
	# 1. ¿Qué tan lejos estoy? (Usamos distancia física simple para esto)
	var ruta_actual = astar.get_point_path(id_player, id_npc)
	var distancia_en_nodos = ruta_actual.size()
	
	if not ruta_manual.is_empty():
		if distancia_en_nodos > 2: return 
			
	if ruta_manual.is_empty() and distancia_en_nodos > min_node_distance + 1:
		return

	# 2. Seleccionar el mejor destino
	var mejor_punto = -1
	var max_distancia_nodos = -1
	
	# Aquí seguimos buscando el punto "más lejano" en distancia bruta,
	# pero LLEGAREMOS a él usando el camino táctico.
	for punto_id in astar.get_point_ids():
		var ruta_posible = astar.get_point_path(id_player, punto_id)
		var dist = ruta_posible.size()
		if dist > max_distancia_nodos:
			max_distancia_nodos = dist
			mejor_punto = punto_id
	
	# 3. Calcular la ruta TÁCTICA hacia ese refugio
	if mejor_punto != -1 and mejor_punto != id_npc:
		var destino_pos = astar.get_point_position(mejor_punto)
		
		# [CAMBIO TÁCTICO] Calculamos ruta evitando luz y peligro
		if room_graph_manual.has_method("obtener_ruta_tactica"):
			ruta_manual = room_graph_manual.obtener_ruta_tactica(
				global_position, 
				destino_pos, 
				mis_pesos, 
				player.global_position
			)
		else:
			ruta_manual = astar.get_point_path(id_npc, mejor_punto)
			
		indice_ruta = 0

func _on_recalculate_timer():
	if current_state == State.FLEE:
		_buscar_refugio_lejos()

# --- ROTACIONES ---
func _rotar_hacia_movimiento(delta):
	if velocity.length() > 5.0:
		var angle = velocity.angle() 
		if sprite_faces_up: angle += PI/2 
		rotation = lerp_angle(rotation, angle, rotation_speed * delta)

func _rotar_hacia_objetivo(target_pos: Vector2, delta):
	var direction = (target_pos - global_position).normalized()
	var angle = direction.angle()
	if sprite_faces_up: angle += PI/2
	rotation = lerp_angle(rotation, angle, rotation_speed * 2 * delta)
