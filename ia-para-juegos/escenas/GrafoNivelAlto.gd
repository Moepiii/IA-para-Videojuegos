extends Node2D

var astar = AStar2D.new()
# var color_linea = Color.BLUE # Ya no se usa para dibujar

# 🛑 DEBES ARRASTRAR EL NODO 'NavigationRegion2D' AQUÍ EN EL INSPECTOR
@export var navigation_region: NavigationRegion2D = null

func _ready():
	if navigation_region == null:
		printerr("GrafoNivelAlto: ❌ ERROR. Asigna el 'NavigationRegion2D' en el Inspector.")
		
# 🛑 FUNCIÓN _draw() ELIMINADA PARA EVITAR CONFLICTOS VISUALES 🛑


func conectar_nodos_generados(_nav_mesh_source: NavigationPolygon): 
	print("GrafoNivelAlto: Conectando nodos generados...")
	
	astar = AStar2D.new()
	var nodos_generados = []
	
	for child in get_children():
		if child is Marker2D:
			nodos_generados.append(child)
	
	if nodos_generados.size() < 2:
		return

	# 1. Añadir todos los nodos a AStar2D
	var id_contador = 0
	for nodo_marker in nodos_generados:
		nodo_marker.set_meta("id_astar", id_contador)
		astar.add_point(id_contador, nodo_marker.position)
		id_contador += 1
		
	# 2. Conectar los nodos (usando la sintaxis correcta del NavigationServer2D)
	var navigation_map = navigation_region.get_navigation_map()
	
	var query_parameters = NavigationPathQueryParameters2D.new()
	var query_result = NavigationPathQueryResult2D.new() 

	query_parameters.map = navigation_map
	query_parameters.navigation_layers = navigation_region.navigation_layers
	query_parameters.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_NONE 
	
	# La línea path_max_distance que causaba error fue eliminada.
	
	for i in range(nodos_generados.size()):
		for j in range(i + 1, nodos_generados.size()):
			var nodo_a = nodos_generados[i]
			var nodo_b = nodos_generados[j]

			var id_a = nodo_a.get_meta("id_astar")
			var id_b = nodo_b.get_meta("id_astar")
			
			query_parameters.start_position = nodo_a.position
			query_parameters.target_position = nodo_b.position
			
			NavigationServer2D.query_path(query_parameters, query_result) 
			var path_check = query_result.path
			
			if path_check.size() > 1:
				astar.connect_points(id_a, id_b)
				astar.connect_points(id_b, id_a) 
				
	print(str(astar.get_point_count()) + " Waypoints enlazados con éxito.")


func encontrar_ruta_alto_nivel(posicion_origen: Vector2, posicion_destino: Vector2) -> Array[Vector2]:
	if astar.get_point_count() < 2:
		return []

	var id_origen_astar = astar.get_closest_point(posicion_origen)
	var id_destino_astar = astar.get_closest_point(posicion_destino)
	
	if id_origen_astar == -1 or id_destino_astar == -1:
		return []
		
	var ruta_ids = astar.id_get_path(id_origen_astar, id_destino_astar)
	
	var ruta_posiciones = []
	for id in ruta_ids:
		ruta_posiciones.append(astar.get_point_position(id))
			
	return ruta_posiciones

func get_random_waypoint_position() -> Vector2:
	if astar.get_point_count() == 0:
		return Vector2.ZERO
	
	var ids = astar.get_point_ids() 
	var random_id = ids[randi_range(0, ids.size() - 1)] 
	return astar.get_point_position(random_id)
