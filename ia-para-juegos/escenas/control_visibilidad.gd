extends Node

# Variable para el toggle de regiones
@export var region_representation_node : Node2D

# Variables para el control del NPC
@onready var npc = $NPC
@onready var nav_region = $NavigationRegion2D


# Esta función se llama para cada entrada (mouse, teclado)
func _unhandled_input(event):
	
	# 1. Lógica para el Toggle de Visibilidad (tu código original)
	if event.is_action_pressed("ui_accept"): 
		if region_representation_node:
			region_representation_node.visible = not region_representation_node.visible

	# 2. Lógica para Mover el NPC con Clic
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			
# ... (código del clic)
			if npc:
				# ¡Llamamos a la nueva función de TEST!
				# Le pasamos la posición del clic directamente.
				npc.test_mover_a(event.global_position)
