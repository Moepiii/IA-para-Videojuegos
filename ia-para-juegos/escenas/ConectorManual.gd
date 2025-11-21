extends Node2D
class_name ConectorManual

# Arrastra los Marker2D aquí en el Inspector
@export var punto_salida: Marker2D   # Donde el NPC pisa para activar el salto
@export var punto_llegada: Marker2D  # A donde se teletransporta/camina

func _ready():
	# Se añade solo al grupo para que el Guardia lo encuentre
	add_to_group("Conectores")
