extends CPUParticles2D

func _ready():
	emitting = true
	# Cuando terminen las partículas, borramos el nodo para limpiar memoria
	finished.connect(queue_free)
