extends Node

## Script para Ocultar/Mostrar Capas de Depuración
@export var tilemap_node: Node2D
@export var region_representation_node: Node2D

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		if tilemap_node:
			tilemap_node.visible = not tilemap_node.visible
		
		if region_representation_node:
			region_representation_node.visible = not region_representation_node.visible

# Funciones vacías para "atrapar" las señales rotas no hace nada realmente
@warning_ignore("unused_parameter")
func _on_body_entered(body):
	pass 

@warning_ignore("unused_parameter")
func _on_body_exited(body):
	pass
