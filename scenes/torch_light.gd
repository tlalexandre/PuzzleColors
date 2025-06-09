# Attach this to your Light2D node temporarily to generate texture
extends PointLight2D

func _ready():
	create_cone_texture()

func create_cone_texture():
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var center = Vector2(64, 64)
	
	for x in range(128):
		for y in range(64, 128):  # Only bottom half for cone
			var pos = Vector2(x, y)
			var dist = center.distance_to(pos)
			var angle = center.angle_to_point(pos)
			
			# Create cone shape (adjust angle range as needed)
			if abs(angle) < PI/2:  # 60-degree cone
				var alpha = max(0, 1.0 - (dist / 64.0))
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	var texture = ImageTexture.new()
	texture.set_image(img)
	self.texture = texture
