extends Area2D

@export var room_name: String = "DefaultRoom"


func _on_body_entered(body):
	if body.has_method("set_current_room"):
		body.set_current_room(room_name)

func _on_body_exited(body):

	if body.has_method("set_current_room"):
		body.set_current_room("Corridor") 
