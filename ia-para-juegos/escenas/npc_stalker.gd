class_name StalkerNPC
extends CharacterBody2D

# --- CONFIGURACIÓN DE MOVIMIENTO ---
@export var speed_patrol: float = 80.0
@export var speed_chase: float = 70.0
@export var acceleration: float = 25.0
@export var rotation_speed: float = 12.0
@export var arrival_threshold: float = 5.0 
@export var sprite_faces_up: bool = true
@export var assigned_room_node_path: NodePath 

# --- CONFIGURACIÓN ATAQUE Y RESPAWN ---
@export var damage: int = 1
@export var efecto_muerte_scene: PackedScene
@export var tiempo_respawn: float = 2.0      

# --- REFERENCIAS ---
@export var player: CharacterBody2D
@export var region_graph: RegionGraph

var assigned_room: Habitacion
var room_graph_manual: Node2D 
var habitacion_actual_npc: Node = null

# --- VARIABLES INTERNAS ---
var ruta_manual: PackedVector2Array = []
var indice_ruta: int = 0
var idle_timer: Timer
var ultimo_id_jugador: int = -1 
var posicion_inicial: Vector2 

var esta_renaciendo: bool = false 

enum State { IDLE, STALKING }
var current_state = State.IDLE

# --- PERFIL TÁCTICO ---
var mis_pesos = {
	"w_cobertura": 100.8, #el persigue como explota no le interesa
	"w_luz": 104.0,        #va por la luz
	"w_alto": -100.0,       #no le gusta mucho pero si toco toco  
}
func _ready():
	modulate.a = 0.7 
	posicion_inicial = global_position 
	
	idle_timer = Timer.new()
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	add_child(idle_timer)
	
	await get_tree().process_frame
	if assigned_room_node_path:
		var sala = get_node(assigned_room_node_path)
		if sala:
			assigned_room = sala
			_actualizar_grafo(sala)
	
	set_state(State.IDLE)

func _physics_process(delta):
	if esta_renaciendo: return 
	if not player or not region_graph: return

	# 1. ACTUALIZAR SALA
	var nueva_sala = region_graph.get_region_node_from_body(self)
	if nueva_sala and nueva_sala != habitacion_actual_npc:
		_actualizar_grafo(nueva_sala)

	var player_room = region_graph.get_region_node_from_body(player)

	# 2. ESTADOS
	if player_room == habitacion_actual_npc:
		if current_state != State.STALKING: set_state(State.STALKING)
	else:
		if current_state != State.IDLE: set_state(State.IDLE)

	# 3. EJECUCIÓN
	match current_state:
		State.IDLE:
			_mover_por_ruta(delta, speed_patrol)
		State.STALKING:
			_comportamiento_stalker(delta)

# --- LÓGICA DE ACECHO ---
func _comportamiento_stalker(delta):
	# A. RECALCULO
	var hay_que_recalcular = false
	if room_graph_manual and "astar" in room_graph_manual:
		var id_actual_player = room_graph_manual.astar.get_closest_point(player.global_position)
		if id_actual_player != ultimo_id_jugador:
			ultimo_id_jugador = id_actual_player
			hay_que_recalcular = true
		elif ruta_manual.is_empty():
			hay_que_recalcular = true
	
	if hay_que_recalcular:
		_calcular_ruta_a_un_nodo_distancia()

	# B. MOVIMIENTO
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		_mover_directo_a_punto(player.global_position, delta)
		return

	var objetivo = ruta_manual[indice_ruta]
	if global_position.distance_to(objetivo) < arrival_threshold:
		indice_ruta += 1
		return

	_mover_hacia(objetivo, speed_chase, delta)

# --- FÍSICAS Y COLISIONES ---
func _mover_directo_a_punto(destino: Vector2, delta):
	var dir = (destino - global_position).normalized()
	velocity = velocity.lerp(dir * speed_chase, acceleration * delta)
	move_and_slide()
	_verificar_colision_fisica()
	_rotar_visual(velocity, delta)

func _mover_hacia(destino: Vector2, velocidad: float, delta: float):
	var dir = (destino - global_position).normalized()
	velocity = velocity.lerp(dir * velocidad, acceleration * delta)
	move_and_slide()
	_verificar_colision_fisica()
	_rotar_visual(velocity, delta)

func _verificar_colision_fisica():
	for i in get_slide_collision_count():
		var colision = get_slide_collision(i)
		if colision.get_collider() == player:
			_atacar_y_renacer() 
			break

# --- [MODIFICADO] LÓGICA DE RESPAWN ALEATORIO CON EFECTO ---
func _atacar_y_renacer():
	if esta_renaciendo: return
	
	print("🩸 Stalker atacó y se desvanece...")
	esta_renaciendo = true
	
	# 1. DESAPARECER (Silenciosamente)
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	ruta_manual.clear()
	
	# 2. ESPERAR TIEMPO DE MUERTE
	await get_tree().create_timer(tiempo_respawn).timeout
	
	# 3. ELEGIR NUEVA POSICIÓN
	var nueva_pos = _obtener_posicion_random_en_sala()
	global_position = nueva_pos
	
	# 4. EFECTO DE REAPARICIÓN (Fuegos Artificiales AQUÍ)
	print("🎆 ¡Apareciendo en nueva posición!")
	if efecto_muerte_scene:
		var fx = efecto_muerte_scene.instantiate()
		get_parent().add_child(fx)
		fx.global_position = global_position # El efecto sale donde renazco
	
	# 5. VOLVER A LA VIDA
	visible = true
	$CollisionShape2D.set_deferred("disabled", false)
	set_state(State.IDLE) # Vuelve a estado Idle (o Stalking si sigues ahí)
	esta_renaciendo = false

# --- [NUEVO] BUSCAR PUNTO ALEATORIO EN LA SALA ---
func _obtener_posicion_random_en_sala() -> Vector2:
	if room_graph_manual and "astar" in room_graph_manual:
		var ids = room_graph_manual.astar.get_point_ids()
		if ids.size() > 0:
			var id_random = ids[randi() % ids.size()]
			return room_graph_manual.astar.get_point_position(id_random)
	
	# Si no hay grafo, volvemos a la posición inicial por seguridad
	return posicion_inicial

# --- CÁLCULO DE RUTA ---
func _calcular_ruta_a_un_nodo_distancia():
	if not room_graph_manual or not "astar" in room_graph_manual:
		ruta_manual = []; return
	var astar = room_graph_manual.astar
	var id_npc = astar.get_closest_point(global_position)
	var id_player = astar.get_closest_point(player.global_position)
	if id_npc == -1 or id_player == -1: return

	if room_graph_manual.has_method("obtener_ruta_tactica"):
		var pos_inicio = astar.get_point_position(id_npc)
		var pos_fin = astar.get_point_position(id_player)
		var ruta_completa = room_graph_manual.obtener_ruta_tactica(pos_inicio, pos_fin, mis_pesos, pos_fin)
		
		if ruta_completa.size() > 1:
			ruta_completa.resize(ruta_completa.size() - 1)
			ruta_manual = ruta_completa
			indice_ruta = 0
			if ruta_manual.size() > 0 and global_position.distance_to(ruta_manual[0]) < arrival_threshold:
				indice_ruta = 1
		else:
			ruta_manual = []
	else:
		ruta_manual = []

# --- UTILS ---
func _rotar_visual(vector_movimiento: Vector2, delta):
	if vector_movimiento.length() > 5.0:
		var ajuste = PI/2 if sprite_faces_up else 0.0
		rotation = lerp_angle(rotation, vector_movimiento.angle() + ajuste, rotation_speed * delta)

func _rotar_hacia_objetivo(objetivo: Vector2, delta):
	var dir = (objetivo - global_position).normalized()
	var ajuste = PI/2 if sprite_faces_up else 0.0
	rotation = lerp_angle(rotation, dir.angle() + ajuste, rotation_speed * delta)

func _mover_por_ruta(delta, velocidad):
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		if current_state == State.IDLE and idle_timer.is_stopped(): idle_timer.start(2.0)
		return
	var objetivo = ruta_manual[indice_ruta]
	if global_position.distance_to(objetivo) < arrival_threshold:
		indice_ruta += 1
		return
	_mover_hacia(objetivo, velocidad, delta)

func set_state(new_state):
	current_state = new_state
	if new_state == State.IDLE: _calcular_ruta_random()
	elif new_state == State.STALKING: idle_timer.stop()

func _calcular_ruta_random():
	if room_graph_manual and "astar" in room_graph_manual:
		var ids = room_graph_manual.astar.get_point_ids()
		if ids.size() > 0:
			var destino = room_graph_manual.astar.get_point_position(ids[randi() % ids.size()])
			ruta_manual = room_graph_manual.obtener_ruta_tactica(global_position, destino, mis_pesos, Vector2.ZERO)
			indice_ruta = 0

func _actualizar_grafo(sala: Node):
	habitacion_actual_npc = sala
	if sala.has_node("Waypoints"): room_graph_manual = sala.get_node("Waypoints")

func _on_idle_timer_timeout():
	if current_state == State.IDLE: _calcular_ruta_random()
