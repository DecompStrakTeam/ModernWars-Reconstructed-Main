extends RefCounted



enum Kind{IDLE, SAFETY, DEPLOYMENT, SECTOR, ADVANCE, COMBAT, PLANNER}
const RETREAT_COMMIT_TICKS: = 18

static func resolve(r: RefCounted, unit: Dictionary, fallback: Vector2) -> Dictionary:
	var origin: = Vector2(unit.longitude, unit.latitude)
	var enemies: = int(unit.get("local_enemy_count", 0))
	var allies: = int(unit.get("last_ally_count", 1))
	var retreat: Vector2 = unit.get("border_retreat", Vector2.ZERO)
	var enemy: Vector2 = unit.get("enemy_delta", Vector2.ZERO)
	if enemies >= 5 and enemies > allies * 8 and enemy != Vector2.ZERO:
		retreat -= enemy.normalized()
	if retreat != Vector2.ZERO:
		unit["intent_retreat_until"] = r.sim_tick_count + RETREAT_COMMIT_TICKS
		unit["intent_retreat_direction"] = retreat.normalized()
	elif r.sim_tick_count < int(unit.get("intent_retreat_until", -1)):
		retreat = unit.get("intent_retreat_direction", Vector2.ZERO)
	if retreat != Vector2.ZERO:
		return _record(unit, Kind.SAFETY, retreat.normalized(), Vector2(INF, INF), "legal retreat")




	var route: = Vector2(INF, INF)
	if unit.get("deployment_phase", "") != "ACTIVE":
		route = r._route_waypoint(unit, "reinforcement", false)
	if route.is_finite():
		if bool(unit.get("departure_exit_pending", false)):
			var exit: Vector2 = unit.get("city_exit_target", origin)
			if r._wrapped_geo_delta(origin, exit).length_squared() <= 0.0001:
				unit["departure_exit_pending"] = false
				r.city_muster.release_exit(unit)
			elif r.city_deployment.friendly(r, r.grid_index_for_geo(exit.x, exit.y), int(unit.side_index), unit):
				route = exit
			else:
				unit["departure_exit_pending"] = false
				r.city_muster.release_exit(unit)
		return _record(unit, Kind.DEPLOYMENT, r._wrapped_geo_delta(origin, route).normalized(), route, "owned city route")
	var target: Vector2 = unit.get("sector_destination", Vector2(INF, INF))
	var role: String = unit.get("sector_role", "")
	var operation: Dictionary = r.sector_cohesion.operations.get(int(unit.get("sector_operation", -1)), {})


	if operation.is_empty() and unit.has("formation_target"):
		target = unit.formation_target
	var assigned: bool = not r.unit_is_encircled(unit) and ( not operation.is_empty() or r._active_front_cells.has(int(unit.get("front_sector", -1))))
	if assigned and role in ["Hold", "Cover", "Reserve", "Reinforce", "Secure", "Withdraw"] and target.is_finite():
		if _friendly_target(r, unit, target):
			target = r._formation_waypoint(unit, target)
			return _record(unit, Kind.SECTOR, r._wrapped_geo_delta(origin, target).normalized(), target, role)
	if assigned and role in ["Advance", "Exploit"] and not operation.is_empty():
		if operation.phase == "pushing":
			var approach: Vector2 = r._route_waypoint(unit, "sector", true)
			if approach.is_finite() and not bool(unit.get("sector_route_blocked", false)):
				return _record(unit, Kind.ADVANCE, r._wrapped_geo_delta(origin, approach).normalized(), approach, role)


		target = unit.get("formation_target", origin)
		if not _friendly_target(r, unit, target): target = origin
		return _record(unit, Kind.SECTOR, r._wrapped_geo_delta(origin, target).normalized(), target, "operation paused")

	if assigned and unit.has("formation_target"):
		target = unit.formation_target
		if _friendly_target(r, unit, target):
			target = r._formation_waypoint(unit, target)
			return _record(unit, Kind.SECTOR, r._wrapped_geo_delta(origin, target).normalized(), target, "reserved front slot")
	if enemies > 0 and enemy != Vector2.ZERO:


		return _record(unit, Kind.COMBAT, fallback.normalized(), Vector2(INF, INF), "local contact")
	var order: Dictionary = r.battle_planner.movement_order(r, unit)
	if bool(order.get("hold", false)):
		return _record(unit, Kind.PLANNER, Vector2.ZERO, origin, "planner hold")
	if order.has("direction"):
		return _record(unit, Kind.PLANNER, order.direction.normalized(), Vector2(INF, INF), "planner objective")
	var border: Vector2 = r._border_direction(unit, r.grid_index_for_geo(origin.x, origin.y))
	return _record(unit, Kind.IDLE, border.normalized() if border != Vector2.ZERO else fallback.normalized(), Vector2(INF, INF), "idle regroup")

static func _friendly_target(r: RefCounted, unit: Dictionary, target: Vector2) -> bool:
	var cell: int = r.grid_index_for_geo(target.x, target.y)
	return r._movement_land_legal(cell, unit) and r.sector_cohesion.friendly(r, cell, int(unit.side_index))

static func _record(unit: Dictionary, kind: int, direction: Vector2, target: Vector2, reason: String) -> Dictionary:
	unit["movement_intent"] = kind
	unit["movement_intent_reason"] = reason
	unit["movement_intent_target"] = target
	return {"kind": kind, "direction": direction, "target": target}
