class_name Habitacion 

extends Node2D

@export var neighbors: Array[NodePath]

# marca de l ahabitacion
@onready var marker: Marker2D = $Marker2D
@onready var room_polygon: Polygon2D = $Polygon2D
@onready var room_sensor: Area2D = $RoomSensor

func _ready():
	if not marker:
		push_warning("¡Habitación %s no tiene un Marker2D hijo!" % name)
	if not room_sensor:
		push_warning("¡Habitación %s no tiene un RoomSensor hijo!" % name)


## Función que nos dice si un "cuerpo" está actualmente dentro de nuestra área de sensor.
func is_body_inside(body: Node2D) -> bool:
	
	if not room_sensor:

		push_error("¡La habitación '%s' no tiene 'room_sensor' asignado!" % name)

		return false
	
	# Si pasamos la comprobación, el código original se ejecuta sin peligro.
	for b in room_sensor.get_overlapping_bodies():
		if b == body:
			return true
	return false
