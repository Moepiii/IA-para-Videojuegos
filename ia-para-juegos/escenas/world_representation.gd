# WorldRepresentation.gd
extends Node2D

func _ready():
	create_example_regions()

func create_example_regions():
	# REGIÓN 1 - Ejemplo de habitación
	var region1 = Polygon2D.new()
	region1.polygon = PackedVector2Array([
		Vector2(-2272, 1536),   # Esquina superior izquierda
		Vector2(-1472, 1536),   # Esquina superior derecha
		Vector2(-1472, 2272),   # Esquina inferior derecha
		Vector2(-2272, 2272),   # Esquina inferior izquieda
	])
	region1.color = Color(1, 0, 0, 0.3)  # Rojo semitransparente
	add_child(region1)
	
	# REGIÓN 2 - Otra habitación
	var region2 = Polygon2D.new()
	region2.polygon = PackedVector2Array([
		Vector2(350, 100),
		Vector2(550, 100),
		Vector2(550, 300),
		Vector2(350, 300)
	])
	region2.color = Color(0, 0, 1, 0.3)  # Azul semitransparente
	add_child(region2)
	
	# REGIÓN 3 - Un pasillo
	var region3 = Polygon2D.new()
	region3.polygon = PackedVector2Array([
		Vector2(300, 150),
		Vector2(350, 150),
		Vector2(350, 250),
		Vector2(300, 250)
	])
	region3.color = Color(0, 1, 0, 0.3)  # Verde semitransparente
	add_child(region3)

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Barra espaciadora
		toggle_visibility()

func toggle_visibility():
	# Alternar visibilidad de todas las regiones
	for child in get_children():
		child.visible = !child.visible
