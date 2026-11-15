extends Control

const INK := Color("273f38")
const MUTED := Color("6b7b6c")
const CREAM := Color("f4efdf")
const COLORS := [Color("edac66"), Color("86adce"), Color("b49bd5")]
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

