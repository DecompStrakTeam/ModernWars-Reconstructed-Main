class_name WebMercator
extends RefCounted




const MAX_LATITUDE: = 85.0511287798066


static func project(longitude: float, latitude: float) -> Vector2:
	var wrapped_longitude: = wrap_longitude(longitude)
	var clamped_latitude: = clampf(latitude, - MAX_LATITUDE, MAX_LATITUDE)
	var latitude_radians: = deg_to_rad(clamped_latitude)
	return Vector2(
		(wrapped_longitude + 180.0) / 360.0, 
		(1.0 - asinh(tan(latitude_radians)) / PI) * 0.5
	)


static func unproject(normalized: Vector2) -> Vector2:
	var wrapped_x: = fposmod(normalized.x, 1.0)
	var clamped_y: = clampf(normalized.y, 0.0, 1.0)
	return Vector2(
		wrapped_x * 360.0 - 180.0, 
		rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * clamped_y))))
	)


static func wrap_longitude(longitude: float) -> float:
	return fposmod(longitude + 180.0, 360.0) - 180.0


static func shortest_wrapped_x_delta(point_x: float, center_x: float) -> float:
	return fposmod(point_x - center_x + 0.5, 1.0) - 0.5
