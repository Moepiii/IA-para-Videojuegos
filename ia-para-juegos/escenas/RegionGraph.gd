
class_name RegionGraph
extends Node2D

# El grafo lógico que usará el algoritmo A*
var graph = AStar2D.new()

# Diccionarios de traductores
var region_node_to_id = {}
var id_to_region_node = {}

# Contador de IDs para AStar2D 
var point_id_counter = 0

func _ready():
	await get_tree().process_frame
	
	_build_graph_nodes()
	_connect_graph_nodes()
	
	print("Grafo de regiones construido con %s nodos." % graph.get_point_count())


# Paso 1: Añadir todos los nodos al grafo
func _build_graph_nodes():
	for region_node in get_children():
		if not region_node is Habitacion:
			continue
		
		var new_point_id = point_id_counter
		var pos = region_node.marker.global_position
		
		graph.add_point(new_point_id, pos)
		
		region_node_to_id[region_node] = new_point_id
		id_to_region_node[new_point_id] = region_node
		
		point_id_counter += 1

# Paso 2: Conectar los nodos
func _connect_graph_nodes():
	for region_node in get_children():
		if not region_node is Habitacion:
			continue

		var id_from = region_node_to_id[region_node]
		
		for neighbor_path in region_node.neighbors:
			
			var neighbor_node = region_node.get_node(neighbor_path)
			
			if not neighbor_node or not region_node_to_id.has(neighbor_node):
				push_warning("¡Vecino %s no encontrado para %s!" % [neighbor_path, region_node.name])
				continue
				
			var id_to = region_node_to_id[neighbor_node]
			
			graph.connect_points(id_from, id_to, true)


# Funciones Para que los NPCs las usen

## Función 1: Para saber en qué habitación está un NPC o el Jugador
func get_region_node_from_body(body: Node2D) -> Habitacion:
	for region_node in get_children():
		if not region_node is Habitacion:
			continue
		
		if region_node.is_body_inside(body):
			return region_node
	
	return null 


## Función 2: Para pedir una ruta de alto nivel
func get_high_level_path(start_region: Habitacion, end_region: Habitacion) -> Array[Vector2]:
	
	if not start_region or not end_region:
		return []
	if not region_node_to_id.has(start_region) or not region_node_to_id.has(end_region):
		return []
	
	var start_id = region_node_to_id[start_region]
	var end_id = region_node_to_id[end_region]
	
	var id_path: Array = graph.get_id_path(start_id, end_id)
	
	var position_path: Array[Vector2] = []
	for id in id_path:
		var region_node = id_to_region_node[id]
		position_path.append(region_node.marker.global_position)
		
	return position_path



@export var show_debug_graph: bool = true:
	set(value):
		show_debug_graph = value
		queue_redraw() 

func _draw():
	if not show_debug_graph:
		return
	
	if graph.get_point_count() == 0:
		return

	var line_color = Color.LIME 
	var line_width = 4.0
	
	var node_color = Color.YELLOW  
	var node_radius = 10.0         
	
	var point_ids = graph.get_point_ids()
	
	for id_from in point_ids:

		var pos_from = graph.get_point_position(id_from)
		
		draw_circle(pos_from, node_radius, node_color)

		var connections = graph.get_point_connections(id_from)
		
		for id_to in connections:
			if id_from < id_to:
				var pos_to = graph.get_point_position(id_to)
				draw_line(pos_from, pos_to, line_color, line_width)
