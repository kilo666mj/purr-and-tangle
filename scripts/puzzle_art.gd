extends Control

const INK := Color("273f38")
const MUTED := Color("6b7b6c")
const CREAM := Color("f4efdf")
const COLORS := [Color("edac66"), Color("86adce"), Color("b49bd5")]
const YARN_THREAD = preload("res://assets/ui/yarn_thread.png")
var textures: Dictionary = {}
var font: Font = ThemeDB.fallback_font
var title_font := SystemFont.new()
var show_patterns := true


func panel_style(color: Color, radius: int = 16, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style



func draw_piece(center: Vector2, color: int, yarn: bool, dimensions: float) -> void:
	var names := ["orange", "blue", "purple"]
	var key: String = ("yarn_" if yarn else "cat_") + names[color]
	draw_texture_rect(textures[key], Rect2(center - Vector2.ONE * dimensions * 0.5, Vector2.ONE * dimensions), false)
	if show_patterns and dimensions <= 50:
		var mark := center + Vector2(0, dimensions * 0.33)
		draw_circle(mark, 6.8, INK)
		match color:
			0:
				draw_line(mark + Vector2(-3, -3), mark + Vector2(-1, 3), CREAM, 1.5, true)
				draw_line(mark + Vector2(1, -3), mark + Vector2(3, 3), CREAM, 1.5, true)
			1:
				draw_circle(mark + Vector2(-2.5, 0), 1.6, CREAM)
				draw_circle(mark + Vector2(2.5, 0), 1.6, CREAM)
			2:
				draw_polyline(PackedVector2Array([mark + Vector2(-4, -2), mark + Vector2(-1, 2), mark + Vector2(1, -2), mark + Vector2(4, 2)]), CREAM, 1.5, true)


func draw_yarn_link(first: Vector2, second: Vector2, piece_size: float = 40.0) -> void:
	# A loose U of real wool texture at paw height. A line through the cats'
	# centers is mostly hidden by their faces and reads as a straight bar.
	var distance := first.distance_to(second)
	if distance < 1.0:
		return
	var direction := (second - first) / distance
	var normal := Vector2(-direction.y, direction.x)
	# Hang below a horizontal pair, or beside a vertical pair, keeping the
	# loop out of the faces instead of hiding it under the lower cat's head.
	if (absf(direction.x) >= absf(direction.y) and normal.y < 0.0) or (absf(direction.x) < absf(direction.y) and normal.x < 0.0):
		normal = -normal
	var trim := minf(piece_size * 0.22, distance * 0.3)
	var start := first + direction * trim + normal * piece_size * 0.19
	var end := second - direction * trim + normal * piece_size * 0.19
	var points := PackedVector2Array()
	var edges := PackedVector2Array()
	const STEPS := 24
	for i in range(STEPS + 1):
		var t := float(i) / STEPS
		points.append(start.lerp(end, t) + normal * sin(t * PI) * piece_size * 0.18)
		# Texture has transparent padding above and below its fluffy silhouette.
		# Parallel cross-sections cannot fold over each other as a pair rotates.
		edges.append(normal * piece_size * 0.18)
	for i in range(STEPS):
		# Four broad twists survive downscaling better than the entire strip.
		var u0 := 0.25 + 0.5 * float(i) / STEPS
		var u1 := 0.25 + 0.5 * float(i + 1) / STEPS
		var quad := PackedVector2Array([points[i] - edges[i], points[i + 1] - edges[i + 1], points[i + 1] + edges[i + 1], points[i] + edges[i]])
		var uv := PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])
		draw_polygon(quad, PackedColorArray([Color.WHITE]), uv, YARN_THREAD)


func add_outcome_art(parent: Node, outcome: String, height: float = 190.0) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = "OutcomeCat"
	picture.texture = textures["cat_won" if outcome == "won" else "cat_failure"]
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(0, height)
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture



func card(rect: Rect2, color: Color, radius: int = 16) -> void:
	draw_style_box(panel_style(color, radius), rect)



func text_at(text: String, pos: Vector2, font_size: int, color: Color = INK, face: Font = null) -> void:
	draw_string(font if face == null else face, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)



func format_score(value: int) -> String:
	return "%06d" % value


func pace_label(player: PuzzleSession) -> String:
	var base := player.Difficulty.fall_interval(player.difficulty, player.board.level)
	var current := player.fall_interval()
	var label := "SPEED %.2f×" % (base / current)
	if current <= player.Difficulty.MIN_FALL_SECONDS:
		return label + " · MAX"
	var until_next := ceili(player.Difficulty.SPEED_STEP_SECONDS - fmod(player.play_time, player.Difficulty.SPEED_STEP_SECONDS))
	return label + " · UP IN %ds" % until_next

