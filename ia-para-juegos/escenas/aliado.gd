class_name PrisioneroNPC
extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var speed: float = 120.0
@export var acceleration: float = 20.0
@export var rotation_speed: float = 10.0 # Velocidad de giro al moverse
@export var spin_speed: float = 8.0      # [NUEVO] Velocidad de giro al llegar
@export var sprite_faces_up: bool = true 

@export var assigned_room_node_path: NodePath
@export var destino_final: Node2D 

@export var region_graph: RegionGraph
@export var room_graph_manual: Node2D 

var ruta_manual: PackedVector2Array = []
var indice_ruta: int = 0
var habitacion_actual_npc: Node = null

# --- PERFIL TÁCTICO ---
var mis_pesos = {
	"w_cobertura": 0.0,
	"w_luz": -5.0,  # Prefiere luz
	"w_alto": 0.0,
	"w_peligro": 0.0
}

enum State { SCARED, ESCAPING, FREE }
var current_state = State.SCARED

func _ready():
	await get_tree().process_frame
	if assigned_room_node_path:
		var sala = get_node(assigned_room_node_path)
		if sala: _actualizar_grafo(sala)

func _physics_process(delta):
	if not destino_final or not room_graph_manual: return
	
	match current_state:
		State.SCARED:
			velocity = Vector2.ZERO
			_intentar_escapar()
			
		State.ESCAPING:
			_mover_por_ruta(delta)
			
		State.FREE:
			# --- COMPORTAMIENTO AL LLEGAR ---
			velocity = Vector2.ZERO
			
			# ¡Girar sobre sí mismo infinitamente! (Celebración / Escaneo)
			rotation += spin_speed * delta

func _mover_por_ruta(delta):
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		current_state = State.FREE
		print("💡 ¡Libre en la luz!")
		return

	var objetivo = ruta_manual[indice_ruta]
	
	# Verificación de luz
	if _es_nodo_oscuro(objetivo):
		print("🌑 ¡Oscuridad! Me detengo.")
		current_state = State.SCARED
		return

	if global_position.distance_to(objetivo) < 5.0:
		indice_ruta += 1
		return

	# MOVIMIENTO
	var dir = (objetivo - global_position).normalized()
	velocity = velocity.lerp(dir * speed, acceleration * delta)
	move_and_slide()
	
	# Rotación hacia donde camina
	_rotar_hacia_movimiento(delta)

func _rotar_hacia_movimiento(delta):
	if velocity.length() > 5.0:
		var angle = velocity.angle()
		if sprite_faces_up:
			angle += PI / 2
		rotation = lerp_angle(rotation, angle, rotation_speed * delta)

# --- RESTO DE FUNCIONES ---
func _intentar_escapar():
	if not room_graph_manual or not room_graph_manual.has_method("obtener_ruta_tactica"): return
	
	var posible_ruta = room_graph_manual.obtener_ruta_tactica(
		global_position, 
		destino_final.global_position, 
		mis_pesos, 
		Vector2.ZERO
	)
	
	if posible_ruta.is_empty(): return
	
	var camino_seguro = true
	for punto in posible_ruta:
		if punto.distance_to(global_position) < 10.0: continue
		if _es_nodo_oscuro(punto):
			camino_seguro = false
			break
	
	if camino_seguro:
		print("☀️ Luz detectada. ¡Escapando!")
		ruta_manual = posible_ruta
		indice_ruta = 0
		current_state = State.ESCAPING

func _es_nodo_oscuro(pos: Vector2) -> bool:
	if room_graph_manual and "astar" in room_graph_manual:
		var id = room_graph_manual.astar.get_closest_point(pos)
		if room_graph_manual.id_to_node.has(id):
			var nodo_real = room_graph_manual.id_to_node[id]
			if "es_iluminado" in nodo_real and not nodo_real.es_iluminado:
				return true
	return false

func _actualizar_grafo(sala: Node):
	habitacion_actual_npc = sala
	if sala.has_node("Waypoints"):
		room_graph_manual = sala.get_node("Waypoints")
