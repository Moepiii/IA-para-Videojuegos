extends Path2D

@onready var line := $Line2D

func _ready():
	var pts = curve.get_baked_points()
	line.points = pts
	line.width = 2
	line.default_color = Color(0, 1, 0)
