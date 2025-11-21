extends NavigationRegion2D

# 🛑 DEBES ARRASTRAR EL NODO 'GrafoRegiones' AQUÍ EN EL INSPECTOR
@export var grafo_regiones_container: Node2D 

func _ready():
	if grafo_regiones_container == null:
		printerr("GeneradorWaypoints: ❌ ERROR. Asigna el 'GrafoRegiones' en el Inspector.")
		return

	call_deferred("iniciar_generacion")

func iniciar_generacion():
	# Limpia los Waypoints viejos
	for child in grafo_regiones_container.get_children():
		if child is Marker2D:
			child.queue_free()

	generar_waypoints_desde_navmesh()
	
	# Llama al script del GrafoRegiones para que conecte los Waypoints
	if grafo_regiones_container.has_method("conectar_nodos_generados"):
		grafo_regiones_container.conectar_nodos_generados(navigation_polygon) 

func generar_waypoints_desde_navmesh():
	var nav_mesh = navigation_polygon 
	
	if nav_mesh == null:
		printerr("GeneradorWaypoints: No se encontró NavigationMesh.")
		return

	for i in range(nav_mesh.get_polygon_count()):
		var polygon = nav_mesh.get_polygon(i)
		
		# Calcula el centroide del polígono
		var centroide = Vector2.ZERO
		for vert_idx in polygon:
			centroide += nav_mesh.get_vertices()[vert_idx]
		centroide /= polygon.size()
		
		var marker = Marker2D.new()
		marker.name = "Waypoint_" + str(i)
		marker.position = centroide
		
		var sprite = Sprite2D.new()
		# Asegúrate de que tienes un archivo 'icon.svg' o cambia la ruta a tu sprite de Waypoint
		sprite.texture = load("res://icon.svg") 
		sprite.scale = Vector2(0.2, 0.2) 
		marker.add_child(sprite)
		
		grafo_regiones_container.add_child(marker)
