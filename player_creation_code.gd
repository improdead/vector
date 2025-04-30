# Create the Player (KinematicBody2D)
var player = KinematicBody2D.new()
player.name = "Player"
current_scene.add_child(player)
player.owner = current_scene

# Create a Sprite for the Player
var player_sprite = Sprite2D.new()
player_sprite.name = "Sprite"
player.add_child(player_sprite)
player_sprite.owner = current_scene

# Load a placeholder texture
player_sprite.texture = load("res://icon.svg") # Replace with your player's texture

# Create a CollisionShape2D for the Player
var player_collision = CollisionShape2D.new()
player_collision.name = "CollisionShape2D"
player.add_child(player_collision)
player_collision.owner = current_scene

# Create a simple rectangle shape (replace with your player's shape)
var player_shape = RectangleShape2D.new()
player_shape.extents = Vector2(player_sprite.texture.get_width() / 2, 
                              player_sprite.texture.get_height() / 2)
player_collision.shape = player_shape

# Position the player (adjust as needed)
player.position = Vector2(100, 100)
