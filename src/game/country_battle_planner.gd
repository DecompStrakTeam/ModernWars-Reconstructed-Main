class_name CountryBattlePlanner
extends RefCounted



const CHECK_TICKS: = 30
const FAILURE_TICKS: = 360
const MAX_OPERATIONS_PER_COUNTRY: = 3
const MAX_OFFICERS: = 3
const ROUTE_VISIT_LIMIT: = 24000
const HISTORY_LIMIT: = 128
var plans: Dictionary = {}
var operations: Dictionary = {}
var officer_groups: Dictionary = {}
var commander_groups: Dictionary = {}
var unit_orders: Dictionary = {}
var decisions: Array[Dictionary] = []
var _rng: = RandomNumberGenerator.new()
var revision: = 0
var last_cost_usec: = 0
var _next_operation: = 1
var _route_cache: = preload("res://src/game/planner_route_cache.gd").new()
var _route_progress: Dictionary = {}
var _recovery_targets: Dictionary = {}
var _sector_candidates: Dictionary = {}
var _front_sizes: Dictionary = {}
var _front_axes: Dictionary = {}
var _front_references: Dictionary = {}
var _friendly_city_anchors: Dictionary = {}

func initialize(runtime: ConflictRuntimeState, seed_value: int) -> void :
	plans.clear()
	operations.clear()
	officer_groups.clear()
	commander_groups.clear()
	unit_orders.clear()
	decisions.clear()
	_next_operation = 1
	_route_cache.clear()
	_route_progress.clear()
	_recovery_targets.clear()
	_sector_candidates.clear()
	_front_sizes.clear()
	_front_axes.clear()
	_front_references.clear()
	_friendly_city_anchors.clear()
	_rng.seed = seed_value ^ 4288947
	update(runtime, true)

func clear() -> void :
	plans.clear()
	operations.clear()
	officer_groups.clear()
	commander_groups.clear()
	unit_orders.clear()
	_route_cache.clear()
	_route_progress.clear()
	_sector_candidates.clear()
	_front_sizes.clear()
	_front_axes.clear()
	_front_references.clear()
	_friendly_city_anchors.clear()

func invalidate_country(country_id: int, tick: int, reason: String) -> void :
	for operation_id: int in operations.keys():
		if int(operations[operation_id]["country"]) == country_id:
			_terminate(operation_id, tick, reason)
	plans.erase(country_id)
	for key: Variant in officer_groups.keys():
		if int(officer_groups[key]["country"]) == country_id:
			officer_groups.erase(key)
	_recovery_targets.erase(country_id)
	_sector_candidates.erase(country_id)
	_front_sizes.erase(country_id)
	_front_axes.erase(country_id)
	_front_references.erase(country_id)
	_friendly_city_anchors.erase(country_id)
	for key: Variant in unit_orders.keys():
		if int(unit_orders[key]["country"]) == country_id:
			unit_orders.erase(key)
	revision += 1

func invalidate_captured_objectives(runtime: ConflictRuntimeState) -> void :
	for operation_id: int in operations.keys():
		var operation: Dictionary = operations[operation_id]
		if runtime._effective_side_for_cell(int(operation["objective"]["cell"])) == int(operation["side"]):
			_terminate(operation_id, runtime.sim_tick_count, "Objective captured by capital surrender")

func update(runtime: ConflictRuntimeState, force: bool = false) -> void :
	if not force and runtime.sim_tick_count % CHECK_TICKS != 0:
		return
	var started: = Time.get_ticks_usec()
	if runtime.performance_profile_enabled: _route_cache.begin_profile_pass()
	var by_country: Dictionary = {}
	var strength: = PackedFloat64Array([0.0, 0.0])
	var living_ids: Dictionary = {}
	for unit: Dictionary in runtime.units:
		if float(unit["health"]) <= 0.0:
			continue
		var country: = int(unit["sovereign_id"])
		if not by_country.has(country):
			by_country[country] = []
		by_country[country].append(unit)
		strength[int(unit["side_index"])] += float(unit["health"])
		living_ids[int(unit["id"])] = true
	for unit_id: Variant in unit_orders.keys():
		if not living_ids.has(unit_id):
			unit_orders.erase(unit_id)
	for unit_id: Variant in _route_progress.keys():
		if not living_ids.has(unit_id): _route_progress.erase(unit_id)
	var contexts: Dictionary = {}



	var pass_weights: Dictionary = {}
	var pass_eligible: Dictionary = {}
	var countries: = runtime.country_to_side.keys()
	countries.sort()
	for country: int in countries:
		if runtime.surrendered_countries.has(country):
			continue
		var members: Array = by_country.get(country, [])
		var context: = _context(runtime, country, members, strength)
		contexts[country] = context
		_refresh_sectors(runtime, country, pass_weights)
		var anchors: Array[Vector2] = []
		for city: Dictionary in runtime.planner_cities:
			if runtime.prewar_de_jure_owners[int(city["cell"])] == country and runtime._effective_side_for_cell(int(city["cell"])) == int(context["side"]):
				anchors.append(city["geo"])
		_friendly_city_anchors[country] = anchors
		if runtime.sim_tick_count % 120 == 0 or not _recovery_targets.has(country):


			_recovery_targets[country] = runtime.occupied_home_cells(country)
		if not plans.has(country): plans[country] = _new_plan(runtime, country, context, {})

	for operation_id: int in operations.keys():
		var operation: Dictionary = operations[operation_id]
		var country: = int(operation["country"])
		if not contexts.has(country):
			_terminate(operation_id, runtime.sim_tick_count, "Country surrendered")
			continue
		_update_operation(runtime, operation, by_country.get(country, []), contexts[country], living_ids)


	var candidates: Array[int] = []
	for country: int in countries:
		if not contexts.has(country): continue
		if not (by_country.get(country, []) as Array).is_empty() and not (_sector_candidates.get(country, []) as Array).is_empty(): candidates.append(country)
	for slot: int in range(MAX_OPERATIONS_PER_COUNTRY):
		for side: int in [0, 1]:
			for country: int in candidates:
				if int(contexts[country]["side"]) == side and _country_operation_ids(country).size() <= slot and slot < _desired_operation_count(runtime, country, contexts[country]):
					_admit_country(runtime, country, by_country, contexts)
	for operation: Dictionary in operations.values():
		var country: = int(operation["country"])
		_assign_groups(runtime, country, by_country.get(country, []), operation, contexts[country], pass_weights, pass_eligible)
		_sync_posture(runtime, operation, contexts[country])
	last_cost_usec = Time.get_ticks_usec() - started

func _operation_for_country(country: int) -> int:
	for operation_id: int in operations:
		if int(operations[operation_id]["country"]) == country: return operation_id
	return -1

func _country_operation_ids(country: int) -> Array[int]:
	var identifiers: Array[int] = []
	for operation_id: int in operations:
		if int(operations[operation_id]["country"]) == country: identifiers.append(operation_id)
	identifiers.sort()
	return identifiers

func _desired_operation_count(runtime: ConflictRuntimeState, country: int, context: Dictionary) -> int:
	var sectors: Array = _sector_candidates.get(country, [])
	if sectors.is_empty(): return 0
	var anchor_reference: Vector2 = sectors[0]["geo"]
	var bounds: = Rect2(Vector2.ZERO, Vector2.ZERO)
	for sector: Dictionary in sectors: bounds = bounds.expand(runtime._wrapped_geo_delta(anchor_reference, sector["geo"]))
	var nearby_cities: = 0
	var homeland_only: = MWBattleDoctrines.homeland_only(String(context["doctrine"]))
	for city: Dictionary in runtime.planner_cities:
		var cell: = int(city["cell"])
		if runtime._effective_side_for_cell(cell) != 1 - int(context["side"]): continue
		if homeland_only and runtime.prewar_de_jure_owners[cell] != country: continue
		if not bounds.grow(3.0).has_point(runtime._wrapped_geo_delta(anchor_reference, city["geo"])): continue
		nearby_cities += 1
		if nearby_cities >= 4: break

	if int(_front_sizes.get(country, 0)) >= 48 and nearby_cities >= 4: return 3
	return 2 if nearby_cities >= 2 and int(_front_sizes.get(country, 0)) >= 8 else 1

func _admit_country(runtime: ConflictRuntimeState, country: int, by_country: Dictionary, contexts: Dictionary) -> bool:
	if _country_operation_ids(country).size() >= MAX_OPERATIONS_PER_COUNTRY: return false


	var share: = 0.15 if contexts[country]["doctrine"] in ["INFIL", "RAID", "GUER", "PREC"] else 0.25
	if int(floor((by_country[country] as Array).size() * share)) <= _country_operation_ids(country).size(): return false
	var context: Dictionary = contexts[country]
	var side: = int(context["side"])
	if float(context["condition"]) < 0.35 or float(context["ratio"]) < 0.25: return false
	var objective: = _choose_city(runtime, country, by_country[country], context)
	if objective.is_empty(): return false
	var operation_id: = _next_operation
	_next_operation += 1
	var preparation: = 90 if context["doctrine"] in ["PLAN", "TRCH"] else 30
	var operation: = {"id": operation_id, "country": country, "side": side, "objective": objective, 
		"created": runtime.sim_tick_count, "ready": runtime.sim_tick_count + preparation, "phase": "preparing", 
		"commander_id": operation_id * 10, "officers": [], "anchor_id": "op:%d:anchor" % operation_id, 
		"route_id": "op:%d:route" % operation_id, "progress": 0.0, "failure_since": -1, "anchor_failure_since": -1, 
		"recovery_checks": 0, "reason": "Legal city objective and covered frontline access", "doctrine": context["doctrine"]}
	var desired_count: = _desired_operation_count(runtime, country, context)
	var anchor_candidates: = PackedFloat32Array([0.5, 0.83, 0.17] if desired_count == 3 else ([0.25, 0.75] if desired_count == 2 else [0.5]))
	var anchor_fraction: = anchor_candidates[0]
	var best_separation: = -1.0
	for candidate: float in anchor_candidates:
		var separation: = 1.0
		for existing_id: int in _country_operation_ids(country):
			separation = minf(separation, absf(candidate - float(operations[existing_id].get("anchor_fraction", 0.5))))
		if separation > best_separation:
			best_separation = separation
			anchor_fraction = candidate
	operation["anchor_fraction"] = anchor_fraction
	operation["anchor_regions"] = desired_count
	operations[operation_id] = operation
	var primary_id: = _operation_for_country(country)
	if primary_id == operation_id:
		plans[country] = _new_plan(runtime, country, context, objective)
		operation["posture_kind"] = plans[country]["kind"]
	else:

		operation["posture_kind"] = operations[primary_id]["posture_kind"]
	_refresh_anchor(runtime, operation, true)
	_log(runtime.sim_tick_count, country, "create_operation", "Operation %d: %s" % [operation_id, objective["name"]])
	revision += 1
	return true

func _terminate(operation_id: int, tick: int, reason: String) -> void :
	if not operations.has(operation_id): return
	var operation: Dictionary = operations[operation_id]
	operation["phase"] = "terminated"
	var country: = int(operation["country"])
	_log(tick, country, "cancel", reason)
	decisions[-1]["operation"] = operation_id
	for group_id: int in operation["officers"]: officer_groups.erase(group_id)
	commander_groups.erase(int(operation["commander_id"]))
	for unit_id: int in unit_orders.keys():
		if int(unit_orders[unit_id].get("operation", -1)) == operation_id:
			unit_orders.erase(unit_id)
			_route_progress.erase(unit_id)
	operations.erase(operation_id)
	if plans.has(country) and _operation_for_country(country) < 0:
		plans[country]["objective"] = {}
		plans[country]["operation_id"] = -1
		plans[country]["phase"] = "recovering"
	revision += 1

func _update_operation(runtime: ConflictRuntimeState, operation: Dictionary, members: Array, context: Dictionary, living_ids: Dictionary) -> void :
	var country: = int(operation["country"])
	var tick: = runtime.sim_tick_count
	var reason: = _invalid_reason(runtime, country, operation, context)
	if reason != "":
		_terminate(int(operation["id"]), tick, reason)
		return
	_refresh_anchor(runtime, operation)
	var lanes: Array = operation.get("lane_cells", [])
	var has_anchor: = not lanes.is_empty()
	var access: = false
	if has_anchor:

		if not operation.has("access_checked") or tick - int(operation["access_checked"]) >= 120:
			operation["access_checked"] = tick
			operation["access"] = not connected_route(runtime, int(lanes[int(floor(lanes.size() / 2.0))]), int(operation["objective"]["cell"]), country, MWBattleDoctrines.homeland_only(String(context["doctrine"]))).is_empty()
		access = bool(operation.get("access", false))
	operation["anchor_failure_since"] = -1 if has_anchor else (tick if int(operation["anchor_failure_since"]) < 0 else operation["anchor_failure_since"])
	operation["failure_since"] = -1 if access else (tick if int(operation["failure_since"]) < 0 else operation["failure_since"])
	if int(operation["anchor_failure_since"]) >= 0 and tick - int(operation["anchor_failure_since"]) >= FAILURE_TICKS:
		_terminate(int(operation["id"]), tick, "Sustained destroyed frontline anchor (%d ticks)" % FAILURE_TICKS)
		return
	if int(operation["failure_since"]) >= 0 and tick - int(operation["failure_since"]) >= FAILURE_TICKS:
		_terminate(int(operation["id"]), tick, "Sustained loss of legal route access (%d ticks)" % FAILURE_TICKS)
		return
	if members.is_empty() and int(runtime._country_controlled_cells.get(country, 0)) <= 0:
		_terminate(int(operation["id"]), tick, "Assigned force gone; no controlled recruitment territory")
		return
	var unsafe: = not access or members.is_empty() or int(context["encircled"]) > 0 or float(context["ratio"]) < 0.55 or float(context["coverage"]) < 0.65
	if unsafe:
		operation["phase"] = "recovering" if members.is_empty() or float(context["condition"]) < 0.45 else "paused"
		operation["recovery_checks"] = 0
		operation["reason"] = "Temporary support/route/condition failure; operation retained"
	else:
		operation["recovery_checks"] = int(operation["recovery_checks"]) + 1
		if tick < int(operation["ready"]) or (operation["doctrine"] == "PLAN" and (float(context["coverage"]) < 0.9 or float(context["condition"]) < 0.6)):
			operation["phase"] = "preparing"
		elif int(operation["recovery_checks"]) >= 2:
			operation["phase"] = "pushing"
		if operation["doctrine"] in ["TRCH", "BITE"] and tick - int(operation["created"]) >= 150: operation["phase"] = "recovering"
	for group_id: int in operation["officers"]:
		var group: Dictionary = officer_groups[group_id]
		var survivors: Array[int] = []
		for unit_id: int in group["units"]:
			if living_ids.has(unit_id): survivors.append(unit_id)
		group["units"] = survivors
		group["phase"] = operation["phase"]

func _refresh_anchor(runtime: ConflictRuntimeState, operation: Dictionary, initial: bool = false) -> void :
	var sectors: Array = _sector_candidates.get(int(operation["country"]), [])
	if sectors.is_empty():
		operation["lane_cells"] = []
		return
	var anchor_reference: Vector2 = operation.get("anchor_geo", sectors[0]["geo"])
	var nearby: Array = sectors.duplicate()
	var country: = int(operation["country"])
	var border_reference: Vector2 = _front_references[country]
	var tangent: Vector2 = _front_axes[country]
	nearby.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var first: = runtime._wrapped_geo_delta(border_reference, a["geo"]).dot(tangent)
		var second: = runtime._wrapped_geo_delta(border_reference, b["geo"]).dot(tangent)
		return first < second if first != second else int(a["cell"]) < int(b["cell"]))


	var band_size: = maxi(1, int(ceil(nearby.size() / float(int(operation.get("anchor_regions", 1))))))
	var band_center: = int(round(float(operation.get("anchor_fraction", 0.5)) * (nearby.size() - 1)))
	var band_start: = clampi(band_center - int(floor(band_size / 2.0)), 0, maxi(0, nearby.size() - band_size))
	nearby = nearby.slice(band_start, band_start + band_size)
	var sum: = Vector2.ZERO
	for sector: Dictionary in nearby: sum += runtime._wrapped_geo_delta(anchor_reference, sector["geo"])
	var center: = anchor_reference + sum / nearby.size()
	operation["anchor_geo"] = center if initial else anchor_reference + runtime._wrapped_geo_delta(anchor_reference, center) * 0.25
	operation["anchor_left"] = nearby[0]["geo"]
	operation["anchor_right"] = nearby[-1]["geo"]
	var lanes: Array[int] = []
	for lane: int in range(MAX_OFFICERS):


		var low: = int(floor(lane * nearby.size() / 3.0))
		var high: = maxi(low + 1, int(ceil((lane + 1) * nearby.size() / 3.0)))
		var best: Dictionary = nearby[mini(low, nearby.size() - 1)]
		for position: int in range(low, mini(high, nearby.size())):
			if float(nearby[position]["score"]) > float(best["score"]): best = nearby[position]
		lanes.append(int(best["cell"]))
	operation["lane_cells"] = lanes

func _sync_posture(_runtime: ConflictRuntimeState, operation: Dictionary, context: Dictionary) -> void :
	var plan: Dictionary = plans[int(operation["country"])] if _operation_for_country(int(operation["country"])) == int(operation["id"]) else {}
	plan["objective"] = operation["objective"]
	plan["operation_id"] = operation["id"]
	plan["created"] = operation["created"]
	plan["ready"] = operation["ready"]
	plan["phase"] = operation["phase"]
	plan["doctrine"] = context["doctrine"]

	if operation["phase"] in ["paused", "recovering"]: plan["kind"] = "withdrawal" if float(context["condition"]) < 0.45 else "reorganize"
	elif MWBattleDoctrines.homeland_only(String(context["doctrine"])): plan["kind"] = "recover_homeland"
	else: plan["kind"] = operation["posture_kind"]
	commander_groups[int(operation["commander_id"])] = {"id": operation["commander_id"], "country": operation["country"], "operation": operation["id"], "officers": operation["officers"], "objective": operation["objective"], "anchor_geo": operation["anchor_geo"], "anchor_left": operation["anchor_left"], "anchor_right": operation["anchor_right"], "phase": operation["phase"], "kind": "offensive_line"}

func _context(runtime: ConflictRuntimeState, country: int, members: Array, strength: PackedFloat64Array) -> Dictionary:
	var side: = int(runtime.country_to_side[country])
	var health: = 0.0
	var damaged: = 0
	var encircled: = 0
	for unit: Dictionary in members:
		health += float(unit["health"])
		damaged += int(float(unit["health"]) < 45.0)
		encircled += int(bool(unit.get("encircled", false)))
	var homeland: = runtime.country_cells.get(country, PackedInt32Array()) as PackedInt32Array
	var controlled: = int(runtime._country_controlled_cells.get(country, 0))
	var tactical: Dictionary = runtime.country_frontline_state.get(country, {})
	return {"doctrine": MWBattleDoctrines.short_label(runtime.country_doctrines.get(country, "Combined Arms")), "side": side, 
		"ratio": strength[side] / maxf(100.0, strength[1 - side]), "condition": health / maxf(1.0, members.size() * 100.0), 
		"damaged": float(damaged) / maxf(1.0, members.size()), "encircled": encircled, 
		"lost_home": controlled < homeland.size(), "coverage": float((runtime.front_coverage.get(country, {}) as Dictionary).get("ratio", 1.0)), 
		"saturated": bool(tactical.get("saturated", false)), "tick": runtime.sim_tick_count}

func _refresh_sectors(runtime: ConflictRuntimeState, country: int, pass_weights: Dictionary) -> void :
	var sectors: Array[Dictionary] = []
	var side: = int(runtime.country_to_side[country])
	var restricted_to_homeland: = MWBattleDoctrines.homeland_only(String(runtime.country_doctrines.get(country, "Combined Arms")))
	var fronts: Array[Dictionary] = []
	for cell: int in runtime._active_front_cells:
		if (runtime.world_owners[cell] == country or runtime.primary_occupier[cell] == country) and runtime._effective_side_for_cell(cell) == side and ( not restricted_to_homeland or runtime.prewar_de_jure_owners[cell] == country):
			fronts.append({"index": cell})
	if fronts.is_empty():
		for front: Dictionary in runtime.frontline_cells.get(country, []):
			if runtime._effective_side_for_cell(int(front["index"])) == side: fronts.append(front)
	_front_sizes[country] = fronts.size()

	var stride: = maxi(1, int(ceil(fronts.size() / 32.0)))
	for position: int in range(0, fronts.size(), stride):
		var cell: = int(fronts[position]["index"])
		var geo: = runtime.geo_for_grid_index(cell)
		var allies: = _planner_front_weight(runtime, cell, side, pass_weights)
		var enemies: = _planner_front_weight(runtime, cell, 1 - side, pass_weights)
		sectors.append({"cell": cell, "geo": geo, "allies": allies, "enemies": enemies, "score": allies - enemies})
	sectors.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"] if a["score"] != b["score"] else a["cell"] < b["cell"])
	_sector_candidates[country] = sectors
	if not sectors.is_empty() and not _front_axes.has(country):
		var anchor_reference: Vector2 = sectors[0]["geo"]
		var bounds: = Rect2(Vector2.ZERO, Vector2.ZERO)
		for sector: Dictionary in sectors: bounds = bounds.expand(runtime._wrapped_geo_delta(anchor_reference, sector["geo"]))
		_front_references[country] = anchor_reference
		_front_axes[country] = Vector2.RIGHT if bounds.size.x >= bounds.size.y else Vector2.DOWN


static func candidate_weights(context: Dictionary, has_objective: bool) -> Dictionary:
	var doctrine: = String(context["doctrine"])
	var ratio: = float(context["ratio"])
	var damaged: = float(context["damaged"])
	var weights: = {"hold": 2.0, "reorganize": 1.0, "reinforce": 2.0}
	if bool(context["lost_home"]):
		weights["recover_homeland"] = 8.0
	if damaged > 0.3:
		weights["withdrawal"] = 8.0
	var supported: = ratio >= 0.8 and bool(context["saturated"]) and int(context["encircled"]) == 0
	if has_objective and supported:
		weights["spearhead"] = 4.0
		weights["offensive_line"] = 1.0
		weights["urban_defense"] = 1.0
	match doctrine:
		"COMB": weights["reinforce"] += 3.0
		"BLIZ":
			if supported and has_objective: weights["spearhead"] = 14.0;weights["encircle"] = 6.0
		"TRCH":
			weights["hold"] = 10.0
			if supported and has_objective and int(context["tick"]) % 960 >= 720: weights["offensive_line"] = 15.0
		"DEF": weights = {"recover_homeland": 20.0} if bool(context["lost_home"]) else {"hold": 20.0}
		"PLAN":
			if supported and has_objective: weights["offensive_line"] = 18.0;weights["reorganize"] = 5.0
		"DEEP":
			if supported and has_objective: weights["spearhead"] = 10.0;weights["reinforce"] = 7.0
		"MASS":
			weights["reinforce"] = 14.0
			if ratio > 1.2 and supported and has_objective: weights["offensive_line"] = 16.0
		"INFIL":
			if supported and has_objective: weights["spearhead"] = 14.0
		"ELAS": weights = {"recover_homeland": 16.0, "withdrawal": 6.0} if bool(context["lost_home"]) and ratio > 0.8 else {"hold": 5.0, "withdrawal": 12.0}
		"DEPTH": weights = {"urban_defense": 15.0, "reinforce": 9.0, "recover_homeland": 10.0 if bool(context["lost_home"]) else 0.0}
		"MDEF": weights = {"reinforce": 15.0, "recover_homeland": 18.0 if bool(context["lost_home"]) else 0.0, "hold": 2.0}
		"BITE":
			weights["hold"] = 8.0
			if supported and has_objective: weights["spearhead"] = 12.0
		"ATTR": weights["withdrawal"] = 12.0 if damaged > 0.15 else 1.0;weights["hold"] = 12.0
		"ENC":
			if supported and has_objective: weights["encircle"] = 20.0
		"WITH": weights["withdrawal"] = 20.0 if damaged > 0.15 or ratio < 1.0 else 4.0;weights["reorganize"] = 10.0
		"GUER":
			weights["withdrawal"] = 14.0 if ratio < 1.0 else 1.0
			if supported and has_objective: weights["raid"] = 18.0
		"RAID":
			if supported and has_objective: weights["raid"] = 24.0
		"URB":
			weights["urban_defense"] = 15.0
			if supported and has_objective: weights["offensive_line"] = 8.0
		"DIST":
			weights["reorganize"] = 10.0
			if supported and has_objective: weights["spearhead"] = 14.0
		"PREC":
			if supported and has_objective: weights["raid"] = 18.0;weights["urban_defense"] = 5.0
	return weights

func _new_plan(runtime: ConflictRuntimeState, country: int, context: Dictionary, objective: Dictionary) -> Dictionary:
	var weights: = candidate_weights(context, not objective.is_empty())
	var total: = 0.0
	for value: float in weights.values(): total += maxf(0.0, value)
	var roll: = _rng.randf() * total
	var kind: = "hold"
	for candidate: String in weights:
		roll -= maxf(0.0, float(weights[candidate]))
		if roll <= 0.0: kind = candidate;break
	var preparation: = 90 if context["doctrine"] in ["PLAN", "TRCH"] else 30
	var plan: = {"country": country, "kind": kind, "doctrine": context["doctrine"], "objective": objective, 
		"created": runtime.sim_tick_count, "ready": runtime.sim_tick_count + preparation, 
		"operation_id": -1, "reason": "Initial posture; persistent operation owns lifecycle", "phase": "preparing"}
	_log(runtime.sim_tick_count, country, kind, plan["reason"])
	revision += 1
	return plan

func _invalid_reason(runtime: ConflictRuntimeState, country: int, plan: Dictionary, context: Dictionary) -> String:
	if plan.is_empty(): return ""
	var objective: Dictionary = plan["objective"]
	if not objective.is_empty():
		var cell: = int(objective["cell"])
		if cell < 0 or cell >= runtime.land_mask.size() or runtime.land_mask[cell] != 2: return "Target eliminated or invalid"
		if runtime._effective_side_for_cell(cell) == int(context["side"]): return "Objective captured"
		if runtime._effective_side_for_cell(cell) != 1 - int(context["side"]): return "Target no longer enemy-held"
		if MWBattleDoctrines.homeland_only(String(context["doctrine"])) and runtime.prewar_de_jure_owners[cell] != country: return "Objective outside immutable homeland"
	return ""

func _choose_city(runtime: ConflictRuntimeState, country: int, members: Array, context: Dictionary) -> Dictionary:
	var defensive: = MWBattleDoctrines.homeland_only(String(context["doctrine"]))
	var origin: = Vector2(members[0]["longitude"], members[0]["latitude"])
	var sectors: Array = _sector_candidates.get(country, [])
	if sectors.is_empty(): return {}
	origin = sectors[0]["geo"]
	var reserved: = {}
	var own_targets: = {}
	for operation: Dictionary in operations.values():
		if int(operation["side"]) == int(context["side"]): reserved[int(operation["objective"]["cell"])] = true
		if int(operation["country"]) == country: own_targets[int(operation["objective"]["cell"])] = true
	var candidates: Array[Dictionary] = []
	for city: Dictionary in runtime.planner_cities:
		var cell: = int(city["cell"])
		if own_targets.has(cell): continue
		if runtime._effective_side_for_cell(cell) != 1 - int(context["side"]): continue
		if defensive:
			if runtime.prewar_de_jure_owners[cell] != country: continue
		var score: = runtime._wrapped_geo_delta(origin, city["geo"]).length_squared()


		if context["doctrine"] == "PREC" and bool(city.get("capital", false)):
			score *= 0.4
		candidates.append({"city": city, "score": score, "reserved": reserved.has(cell)})
	candidates.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		if a["reserved"] != b["reserved"]: return not a["reserved"]
		return a["score"] < b["score"] if a["score"] != b["score"] else int(a["city"]["cell"]) < int(b["city"]["cell"]))
	for candidate: Dictionary in candidates:
		var city: Dictionary = candidate["city"]
		var route: = connected_route(runtime, runtime.grid_index_for_geo(origin.x, origin.y), int(city["cell"]), country, defensive)
		if route.is_empty(): continue
		var selected: = city.duplicate()
		selected["route"] = route
		return selected
	return {}


func connected_route(runtime: ConflictRuntimeState, start: int, goal: int, country: int, defensive: bool) -> PackedInt32Array:
	var previous_hits: int = _route_cache.hits
	if runtime.performance_profile_enabled: runtime.exclusive_profile.enter(&"planner_route_search")
	var route: = _route_cache.find(runtime, start, goal, country, defensive, ROUTE_VISIT_LIMIT)
	if runtime.performance_profile_enabled: runtime.exclusive_profile.leave()
	if runtime.performance_profile_enabled:
		runtime.exclusive_profile.count(&"planner_route_queries")
		runtime.exclusive_profile.count(&"planner_route_cache_hits", _route_cache.hits - previous_hits)
	return route




func notify_route_geometry_changed(cells: PackedInt32Array, size: Vector2i) -> void :
	_route_cache.invalidate_cells(cells, size)

func _planner_front_weight(runtime: ConflictRuntimeState, cell: int, side: int, pass_weights: Dictionary) -> float:
	var key: = Vector2i(cell, side)
	if runtime.performance_profile_enabled: runtime.exclusive_profile.count(&"planner_weight_queries")
	if pass_weights.has(key):
		if runtime.performance_profile_enabled: runtime.exclusive_profile.count(&"planner_weight_cache_hits")
		return float(pass_weights[key])
	var value: = runtime._front_weight(cell, side)
	pass_weights[key] = value
	return value

func _eligible_group_members(runtime: ConflictRuntimeState, country: int, members: Array, context: Dictionary, pass_weights: Dictionary, pass_eligible: Dictionary) -> Array:
	if pass_eligible.has(country): return pass_eligible[country]
	var eligible: Array = []
	for unit: Dictionary in members:
		if float(unit["health"]) >= 55.0 and not bool(unit.get("encircled", false)):
			var sector: = int(unit.get("front_sector", -1))
			if sector < 0 or _planner_front_weight(runtime, sector, int(context["side"]), pass_weights) >= 1.25: eligible.append(unit)
	eligible.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return a["health"] > b["health"] if a["health"] != b["health"] else a["id"] < b["id"])
	pass_eligible[country] = eligible
	if runtime.performance_profile_enabled: runtime.exclusive_profile.count(&"planner_eligible_builds")
	return eligible

func _assign_groups(runtime: ConflictRuntimeState, country: int, members: Array, operation: Dictionary, context: Dictionary, pass_weights: Dictionary, pass_eligible: Dictionary) -> void :


	var eligible: = _eligible_group_members(runtime, country, members, context, pass_weights, pass_eligible)
	var share: = 0.15 if operation["doctrine"] in ["INFIL", "RAID", "GUER", "PREC"] else 0.25
	var attacking: = mini(eligible.size(), maxi(0, int(floor(members.size() * share))))
	var country_operations: = _country_operation_ids(country)
	var rank: = country_operations.find(int(operation["id"]))
	attacking = int(floor(attacking / float(country_operations.size()))) + int(rank < attacking % country_operations.size())
	var lanes: Array = operation.get("lane_cells", [])
	var group_count: = mini(MAX_OFFICERS, attacking)
	var assigned: = {}
	for existing: Dictionary in officer_groups.values():
		for unit_id: int in existing["units"]: assigned[unit_id] = true
	for number: int in range(group_count):
		var group_id: = int(operation["id"]) * 10 + number + 1
		if not officer_groups.has(group_id):
			if lanes.is_empty(): continue
			var group: = {"id": group_id, "country": country, "units": [], "route": PackedInt32Array(), 
				"objective": operation["objective"], "kind": "spearhead", "parent": operation["id"], 
				"phase": operation["phase"], "route_key": "op:%d:lane:%d" % [operation["id"], number], 
				"route_id": "op:%d:lane:%d" % [operation["id"], number], "number": number, "count": MAX_OFFICERS, 
				"anchor_cell": -1, "route_revision": 0}
			officer_groups[group_id] = group
			operation["officers"].append(group_id)


	for group_id: int in operation["officers"]:
		var group: Dictionary = officer_groups[group_id]
		var group_rank: int = operation["officers"].find(group_id)
		var group_total: int = operation["officers"].size()
		var desired: = int(floor(attacking / float(maxi(1, group_total)))) + int(group_rank < attacking % maxi(1, group_total))
		while group["units"].size() > desired:
			var released_id: int = group["units"].pop_back()
			assigned.erase(released_id)
			unit_orders.erase(released_id)
			_route_progress.erase(released_id)
		for unit: Dictionary in eligible:
			var unit_id: = int(unit["id"])
			if group["units"].size() >= desired: break
			if assigned.has(unit_id): continue
			group["units"].append(unit_id)
			assigned[unit_id] = true
			unit_orders[unit_id] = {"country": country, "group": group_id, "operation": operation["id"], "kind": "offensive_line"}
		if lanes.is_empty(): continue
		var cell: = int(lanes[mini(int(group["number"]), lanes.size() - 1)])
		if cell != int(group["anchor_cell"]) or (group["route"] as PackedInt32Array).is_empty():
			var route: = connected_route(runtime, cell, int(operation["objective"]["cell"]), country, MWBattleDoctrines.homeland_only(String(context["doctrine"])))
			if not route.is_empty():
				group["route"] = route
				group["anchor_cell"] = cell
				group["route_revision"] = int(group["route_revision"]) + 1
		var geo: = runtime.geo_for_grid_index(cell)
		var previous: Vector2 = group.get("origin_geo", geo)
		group["origin_geo"] = previous + runtime._wrapped_geo_delta(previous, geo) * 0.25
		group["phase"] = operation["phase"]

	operation["support_condition"] = context["ratio"]

func movement_order(runtime: ConflictRuntimeState, unit: Dictionary) -> Dictionary:
	var country: = int(unit["sovereign_id"])
	var plan: Dictionary = plans.get(country, {})
	if plan.is_empty(): return {}
	var order: Dictionary = unit_orders.get(int(unit["id"]), {})
	var owning_operation: Dictionary = operations.get(int(order.get("operation", -1)), {})
	if not owning_operation.is_empty():
		plan = {"doctrine": owning_operation["doctrine"], "kind": owning_operation["posture_kind"], "phase": owning_operation["phase"], "ready": owning_operation["ready"], "created": owning_operation["created"]}
		if plan["phase"] in ["paused", "recovering"]: plan["kind"] = "reorganize"
	var own_geo: = Vector2(unit["longitude"], unit["latitude"])
	var doctrine: = String(plan["doctrine"])
	var kind: = String(plan["kind"])
	var retreat: = kind == "withdrawal" and float(unit["health"]) < (75.0 if doctrine in ["ELAS", "WITH", "GUER"] else 50.0)
	if kind == "recover_homeland" or doctrine == "MDEF":
		var targets: Array = _recovery_targets.get(country, [])
		var best: = -1
		var distance: = INF

		for position: int in range(0, targets.size(), maxi(1, int(ceil(targets.size() / 16.0)))):
			var delta: = runtime._wrapped_geo_delta(own_geo, runtime.geo_for_grid_index(targets[position]))
			if delta.length_squared() < distance: distance = delta.length_squared();best = targets[position]
		if best >= 0: return {"direction": runtime._wrapped_geo_delta(own_geo, runtime.geo_for_grid_index(best)).normalized(), "weight": 0.65}
	if kind in ["reinforce", "reorganize"] or doctrine == "MASS":
		var sector: = int(unit.get("front_sector", -1))
		if sector >= 0 and runtime._front_weight(sector, int(unit["side_index"])) < 1.0:
			return {"direction": runtime._wrapped_geo_delta(own_geo, runtime.geo_for_grid_index(sector)).normalized(), "weight": 0.6}
	if retreat or (doctrine in ["ATTR", "DEEP"] and float(unit["health"]) < 40.0):
		var home: Array = _friendly_city_anchors.get(country, [])
		if not home.is_empty(): return {"direction": runtime._wrapped_geo_delta(own_geo, home[0]).normalized(), "weight": 0.7}
	if kind == "urban_defense" or doctrine == "DEPTH":
		var anchors: Array = _friendly_city_anchors.get(country, [])
		if not anchors.is_empty():
			var anchor: Vector2 = anchors[int(unit["id"]) % anchors.size()]
			var anchor_delta: = runtime._wrapped_geo_delta(own_geo, anchor)

			var ring: = Vector2.from_angle(float(int(unit["id"]) % 8) * TAU / 8.0) * (0.08 + 0.04 * (int(unit["id"]) % 3)) if doctrine == "DEPTH" else Vector2.ZERO
			if anchor_delta.length() > 0.16: return {"direction": (anchor_delta + ring).normalized(), "weight": 0.5}
			return {"hold": int(unit.get("local_enemy_count", 0)) == 0}
	if kind == "hold" and doctrine in ["DEF", "TRCH", "ATTR"]:
		return {"hold": int(unit.get("local_enemy_count", 0)) == 0}
	if int(order.get("group", -1)) >= 0:



		var cover_target: = -1
		var cover_distance: = 1.0
		for sector: Dictionary in _sector_candidates.get(country, []):
			if float(sector["allies"]) >= 1.25: continue
			var sector_distance: = runtime._wrapped_geo_delta(own_geo, sector["geo"]).length_squared()
			if sector_distance < cover_distance:
				cover_distance = sector_distance
				cover_target = int(sector["cell"])
		if cover_target >= 0 and runtime._front_weight(cover_target, int(unit["side_index"])) < 1.25:
			return {"direction": runtime._wrapped_geo_delta(own_geo, runtime.geo_for_grid_index(cover_target)).normalized(), "weight": 0.65}
		if plan["phase"] in ["preparing", "paused", "recovering"]: return {"hold": int(unit.get("local_enemy_count", 0)) == 0}
		var group: Dictionary = officer_groups.get(order["group"], {})
		if group.is_empty(): return {}

		if int(unit.get("local_enemy_count", 0)) > int(unit.get("last_ally_count", 1)) or bool(unit.get("encircled", false)): return {}
		if doctrine == "DEEP" and int(group["number"]) != int((runtime.sim_tick_count - int(plan["ready"])) / 90.0) % maxi(1, int(group["count"])):
			return {"hold": int(unit.get("local_enemy_count", 0)) == 0}
		if doctrine in ["GUER", "RAID", "PREC"] and int(unit.get("local_enemy_count", 0)) > 1:
			return {}
		var route: PackedInt32Array = group["route"]
		if route.size() < 2: return {}
		var progress: Dictionary = _route_progress.get(int(unit["id"]), {})
		var nearest: = int(progress.get("cursor", 0))
		var distance: = INF
		var fresh: bool = progress.get("route_key", "") != group["route_key"] or int(progress.get("revision", -1)) != int(group["route_revision"])
		for point: int in range(0 if fresh else maxi(0, nearest - 3), route.size() if fresh else mini(route.size(), nearest + 5)):
			var delta: = runtime._wrapped_geo_delta(own_geo, runtime.geo_for_grid_index(route[point]))
			if delta.length_squared() < distance: nearest = point;distance = delta.length_squared()
		_route_progress[int(unit["id"])] = {"route_key": group["route_key"], "revision": group["route_revision"], "cursor": nearest}
		var limit: = route.size() - 1
		if doctrine == "BITE": limit = mini(limit, maxi(3, int(route.size() * 0.2)))
		if doctrine == "TRCH": limit = mini(limit, maxi(3, int(route.size() * 0.15)))
		if doctrine in ["RAID", "GUER"] and runtime.sim_tick_count - int(plan["created"]) > 150: limit = 0
		var next: = route[mini(limit, nearest + 1)]
		if runtime.land_mask[next] != 2 or not runtime.unit_can_enter_cell(unit, next): return {}
		var current: = runtime.grid_index_for_geo(own_geo.x, own_geo.y)



		if runtime._effective_side_for_cell(next) != int(unit["side_index"]):
			if next not in runtime._cardinal_indices(current) or runtime._effective_side_for_cell(current) != int(unit["side_index"]): return {}
			if int(unit.get("local_enemy_count", 0)) > int(unit.get("last_ally_count", 1)): return {}
		var operation: Dictionary = operations.get(int(group["parent"]), {})
		if not operation.is_empty(): operation["progress"] = maxf(float(operation["progress"]), nearest / float(maxi(1, route.size() - 1)))
		return {"direction": runtime._wrapped_geo_delta(own_geo, runtime.geo_for_grid_index(next)).normalized(), "weight": 0.55 if doctrine == "BLIZ" else 0.35}
	return {}

func _log(tick: int, country: int, action: String, reason: String) -> void :
	decisions.append({"tick": tick, "country": country, "action": action, "reason": reason})
	if decisions.size() > HISTORY_LIMIT: decisions.pop_front()
