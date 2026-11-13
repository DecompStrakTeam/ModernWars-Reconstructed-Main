class_name ConflictRuntimeState
extends RefCounted

const _NATIVE_CONFLICT_EXTENSION = preload("res://native/mw_conflict_core.gdextension")

signal land_pocket_resolved(event: Dictionary)





signal war_ended(result: Dictionary)

enum WarState{
	IDLE, 
	MOBILIZING, 
	RUNNING, 
	RESULT, 
	STOPPED, 
}

const SPEED_STEPS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0]
const MAX_PLAYABLE_SPEED_INDEX: int = 7
const GRID_RESOLUTION: = 0.1
const INFLUENCE_RATE: = 0.18
const INFLUENCE_RADIUS: = 0.4
const UNIT_DENSITY_FACTOR: = 0.022
const MAX_UNITS_PER_SIDE: = 1800
const PER_COUNTRY_SPAWN_CAP: = 100

const FORMATION_BASELINE_MULTIPLIER: = 1.5
const FORMATION_COUNTRY_CAP: = 150
const DENSE_COUNTRY_SAFETY_CAP: = 600
const MIN_FORMATION_PERSONNEL: = 500
const FRONT_FORMATION_SPACING: = 0.08
const TRANSIT_CELL_SECONDS: = 0.75
var formation_slots: = preload("res://src/game/front_formation_slots.gd").new()
var sector_cohesion: = preload("res://src/game/frontline_cohesion.gd").new()
var city_deployment: = preload("res://src/game/city_deployment_routes.gd").new()
var city_muster: = preload("res://src/game/city_muster.gd").new()
var city_transit_policy: MWCityTransitPolicy = MWCityTransitPolicy.new()
const REINFORCEMENT_TRANSIT_BOOST: = 2.5
const DEPLOYMENT_ACCELERATION: = 0.00065
const MOVEMENT_INTENT = preload("res://src/game/formation_movement_intent.gd")
const FRONT_COVERAGE_RADIUS: = 0.3
const FRONT_COVERAGE_TICKS: = 15

const UNIT_SPEED: = 0.0036
const SOURCE_UNIT_SPEED: = 0.003
const MOVEMENT_ACCELERATION_FACTOR: = 0.38
const MOVEMENT_BRAKE_FACTOR: = 0.42
const SUPPORT_ROW_PERIOD: = 3
const MOVEMENT_CORRIDOR = preload("res://src/game/movement_corridor.gd")
const UNIT_HEALTH: = 100.0
const COMBAT_DAMAGE: = 0.7
const BASE_RECRUITMENT_CHANCE: = 0.006
const UNIT_TO_SOLDIER_RATIO: = 5000.0
const DEPLOYMENT_TICKS: = 30
const HASH_CELL_SIZE: = 2.5
const SPAWN_CELL_CACHE_TICKS: = 45
const RECRUITMENT_CONTROL_THRESHOLD: = 0.5
const MOP_UP_SAMPLE_COUNT: = 250
const RESULT_DURATION_SECONDS: = 2.5
const ENCIRCLEMENT_STEP: = 8
const ENCIRCLEMENT_PASS_TICKS: = 60
const ENCIRCLEMENT_COLLAPSE_TICKS: = 120
const ATTRITION_DAMAGE: = 0.06
const ENCIRCLEMENT_DAMAGE_MULTIPLIER: = 2.5

var state: WarState = WarState.IDLE
var is_paused: = false
var speed_index: = 1
var frame_accumulator: = 0.0
var sim_frame_count: = 0
var sim_tick_count: = 0
var visual_loop_count: = 0
var last_mechanics_frame: = 0
var result_elapsed: = 0.0
var render_revision: = 0
var visual_revisions: MWVisualRevisions = MWVisualRevisions.new()

var movement_speed_override: = 0.0

var grid_size: = Vector2i.ZERO
var scenario_snapshot: Dictionary = {}
var prewar_world_owners: = PackedInt32Array()
var prewar_de_jure_owners: = PackedInt32Array()
var prewar_land_mask: = PackedByteArray()
var world_owners: = PackedInt32Array()
var de_jure_owners: = PackedInt32Array()
var land_mask: = PackedByteArray()
var occupation: = PackedFloat32Array()
var primary_occupier: = PackedInt32Array()

var sides: Array = []
var country_to_side: Dictionary = {}
var country_names: Dictionary = {}
var country_colors: Dictionary = {}
var initial_combatants: Array[Dictionary] = []
var country_cells: Dictionary = {}
var frontline_cells: Dictionary = {}
var formation_launch_counts: Dictionary = {}
var _initial_staging_fronts: Dictionary = {}
var source_launch_counts: = PackedInt32Array([0, 0])
var front_coverage: Dictionary = {}
var _active_front_cells: Dictionary = {}


var render_front_quads: Dictionary = {}
var native_front_trace: = PackedVector2Array()
var native_front_trace_revision: = -1
var _coverage_hash: Dictionary = {}
var _coverage_tick: = -1
var _unit_geo_cache: = PackedVector2Array()
var _target_bucket_cache: Dictionary = {}

var contact_index_enabled: = true
var contact_index_min_units: = 384
var _contact_index_active: = false
var _contact_index: = preload("res://src/game/unit_contact_index.gd").new()
var native_conflict_enabled: = true
var native_planner_route_enabled: = true
var native_spacing_cache_enabled: = true
var native_front_slot_assignment_enabled: = true

var native_contact_lazy_enabled: = true
var native_pocket_graph_enabled: = true
var muster_active_fastpath_enabled: = true
var influence_commit_fastpath_enabled: = true
var _native_conflict_core: Object = ClassDB.instantiate("MWConflictCore")
var _native_source_clock: Object = ClassDB.instantiate("MWSourceClock")


var native_authoritative_enabled: = false
var _native_authoritative_active: = false
var native_render_snapshot: Dictionary = {}
var native_last_changed_control_cells: = 0

var native_skip_render: = false
var native_last_advance: Dictionary = {}
var native_render_sync_count: = 0
var native_render_snapshot_count: = 0
var _native_planner_visual_snapshot: Dictionary = {}
var _native_planner_visual_tick: = -1

var country_frontline_state: Dictionary = {}
var side_victory_ratios: = PackedFloat64Array([0.0, 0.0])
var theater_cells: = PackedInt32Array()
var theater_bounds: = Rect2i()
var active_theater_city_ids: Dictionary = {}
var city_cell_set: Dictionary = {}
var country_city_counts: Dictionary = {}
var country_city_positions: Dictionary = {}
var country_city_records: Dictionary = {}

var units: Array[Dictionary] = []


var _city_transit_actor_indices: = PackedInt32Array()

var movement_audit: = Callable()
var bases: Array[Dictionary] = []
var active_battles: Array[Dictionary] = []
var _battle_buckets: Dictionary = {}
var _battle_index_size: = -1
var encirclement_popups: Array[Dictionary] = []
var encirclement_topology: = EncirclementTopology.new()
var land_pockets: = LandPocketResolver.new()
var simulation_seconds: = 0.0
var _inside_advance: = false
var _pockets_initialized: = false
var encirclement_pass_count: = 0
var encirclement_collapse_count: = 0
var last_encirclement_usec: = 0
var encirclement_revision: = 0
var _encirclement_cities: = PackedVector2Array()
var _encirclement_city_cells: = PackedInt32Array()
var recruitment_events: Array[Dictionary] = []
var reinforcement_counts: = PackedInt32Array()
var queued_reinforcements: Dictionary = {}


var unit_spatial_hash: Dictionary = {}
var side_casualties: = PackedInt64Array()
var side_personnel: = PackedInt64Array()
var side_initial_personnel: = PackedInt64Array()
var country_casualties: Dictionary = {}
var side_control_percent: = PackedFloat32Array()
var frontline_segment_count: = 0

var frontline_geometry_revision: = 0
var conflict_name: = ""
var launch_options: Dictionary = {}
var force_density: = 1.0
var occupation_radius: = INFLUENCE_RADIUS
var country_doctrines: Dictionary = {}
var country_roles: Dictionary = {}
var battle_planner: = CountryBattlePlanner.new()
var planner_cities: Array[Dictionary] = []
var prewar_capitals: Dictionary = {}
var surrendered_countries: Dictionary = {}
var surrender_events: Array[Dictionary] = []
var surrender_on_capital_capture: = false
var side_soldiers_per_unit: = PackedFloat64Array([UNIT_TO_SOLDIER_RATIO, UNIT_TO_SOLDIER_RATIO])
var country_soldiers_per_unit: Dictionary = {}
var country_initial_personnel: Dictionary = {}
var _unit_side_cache: = PackedInt32Array()


var _contact_alive: = PackedByteArray()
var _contact_inactive: = PackedByteArray()
var _contact_weight: = PackedFloat64Array()
var _homeland_lookup: Dictionary = {}
var _casualty_exact: = PackedFloat64Array([0.0, 0.0])
var result: Dictionary = {}

var death_events: Array[Dictionary] = []
var damage_this_tick: = 0.0
var engagement_damage_this_tick: = 0.0
var longest_no_damage_ticks: = 0
var _no_damage_ticks: = 0
var _garrison_cache: Dictionary = {}
var _garrison_cache_frame: = -1
var last_tick_usec: = 0
var last_tick_phases_usec: = PackedInt64Array([0, 0, 0, 0])

var performance_profile_enabled: = false
var exclusive_profile: = MWCombatPerformanceTrace.new()
var verification_input_trace_enabled: = false
var verification_input_trace: Array[PackedFloat64Array] = []
var last_profile_usec: Dictionary = {}
var render_profile_usec: Dictionary = {}
var render_profile_frame: Dictionary = {}
var render_profile_counts: Dictionary = {}
var _profile_movement_usec: = 0
var _profile_swept_usec: = 0
var _profile_spatial_usec: = 0
var _profile_front_usec: = 0
var _profile_recruitment_usec: = 0
var _profile_diffuse_usec: = 0
var _profile_unit_influence_usec: = 0
var _profile_targeting_usec: = 0
var _profile_garrison_usec: = 0
var _profile_damage_usec: = 0
var _profile_battle_records_usec: = 0

var combat_trace_enabled: = false
var combat_events: Array[Dictionary] = []
var combat_event_counts: Dictionary = {}
var carried_direct_count: = 0

var verification_enabled: = false
var verification_events: Array[Dictionary] = []
var verification_encirclements: Array[Dictionary] = []
var verification_topology_snapshots: Array[Dictionary] = []
var verification_damage_totals: Dictionary = {}
var verification_windows: Dictionary = {}
var _verification_direct_frames: Dictionary = {}

var _rng: = RandomNumberGenerator.new()
var _next_unit_id: = 1
var _side_initial_cells: = PackedInt32Array()
var _held_control_cells: = PackedInt32Array()
var _country_controlled_cells: Dictionary = {}
var _occupied_home_cells: Dictionary = {}
var _spawn_cell_cache: Dictionary = {}
var _country_city_spatial_hash: Dictionary = {}
var _city_front_route_cache: Dictionary = {}
var _control_revision: = 0
var _dominance_anchor_tick: = -1
var _decisive_anchor_tick: = -1
var _stalemate_anchor_tick: = 0
var _stalemate_anchor_score: = -1.0
var _last_result_state: = WarState.IDLE


func begin_mobilization() -> void :
	state = WarState.MOBILIZING
	is_paused = false
	result = {}
	result_elapsed = 0.0


func launch(
	scenario: ScenarioData, 
	setup: RefCounted, 
	source_owner_ids: PackedInt32Array, 
	seed_value: int = 0
) -> bool:
	if scenario == null or setup == null or source_owner_ids.is_empty():
		return false
	var side_a: Array = setup.call("countries_for_side", MWConflictSetupState.SIDE_A)
	var side_b: Array = setup.call("countries_for_side", MWConflictSetupState.SIDE_B)
	if side_a.is_empty() or side_b.is_empty() or setup.active_side_count() != 2:
		return false
	var selected: Dictionary = {}
	for country_id: int in side_a:
		if selected.has(country_id):
			return false
		selected[country_id] = 0
	for country_id: int in side_b:
		if selected.has(country_id):
			return false
		selected[country_id] = 1

	begin_mobilization()
	grid_size = Vector2i(scenario.grid_width(), scenario.grid_height())
	if source_owner_ids.size() != grid_size.x * grid_size.y:
		state = WarState.IDLE
		return false

	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

	scenario_snapshot = {
		"display_name": scenario.display_name, 
		"source_path": scenario.source_path, 
		"grid_resolution": scenario.grid_resolution, 
		"country_count": scenario.countries.size(), 
		"city_count": scenario.cities.size(), 
	}
	world_owners = source_owner_ids.duplicate()
	de_jure_owners = source_owner_ids.duplicate()
	prewar_world_owners = source_owner_ids.duplicate()
	prewar_de_jure_owners = source_owner_ids.duplicate()

	country_names.clear()
	country_colors.clear()
	for country: CountryData in scenario.countries:
		country_names[country.id] = country.country_name
		var opaque: = country.color
		opaque.a = 1.0
		country_colors[country.id] = opaque

	sides = [side_a.duplicate(), side_b.duplicate()]
	country_to_side.clear()
	initial_combatants.clear()
	country_casualties.clear()
	active_battles.clear()
	_clear_encirclement()
	recruitment_events.clear()
	death_events.clear()
	combat_events.clear()
	verification_events.clear()
	verification_encirclements.clear()
	verification_topology_snapshots.clear()
	verification_damage_totals.clear()
	verification_windows.clear()
	_verification_direct_frames.clear()
	combat_event_counts.clear()
	carried_direct_count = 0
	_garrison_cache.clear()
	_garrison_cache_frame = -1
	longest_no_damage_ticks = 0
	_no_damage_ticks = 0
	reinforcement_counts = PackedInt32Array([0, 0])
	queued_reinforcements.clear()
	_spawn_cell_cache.clear()
	_city_front_route_cache.clear()
	city_deployment.clear()
	city_muster.clear()
	sector_cohesion.clear(int(_rng.seed))
	_control_revision = 0
	_country_controlled_cells.clear()
	_occupied_home_cells.clear()
	for side_index: int in range(2):
		for country_id: int in sides[side_index]:
			country_to_side[country_id] = side_index
			country_casualties[country_id] = 0
			queued_reinforcements[country_id] = 0
			_occupied_home_cells[country_id] = {}
			initial_combatants.append({
				"id": country_id, 
				"name": String(country_names.get(country_id, "Country %d" % country_id)), 
				"side_index": side_index, 
				"pole": side_index % 2, 
			})

	launch_options = setup.launch_options()
	force_density = float(launch_options["force_density"])
	occupation_radius = INFLUENCE_RADIUS
	country_doctrines.clear()
	country_roles.clear()
	surrendered_countries.clear()
	surrender_events.clear()
	surrender_on_capital_capture = bool(launch_options.get("surrender_on_capital_capture", false))
	for country_id: int in selected:
		country_doctrines[country_id] = MWBattleDoctrines.full_name(setup.country_doctrines.get(country_id, "Combined Arms"))
		country_roles[country_id] = setup.country_roles.get(country_id, "OFFENSE")
	conflict_name = String(launch_options["conflict_name"])
	if conflict_name.is_empty():
		conflict_name = _build_default_conflict_name(side_a, side_b)
	conflict_name = conflict_name.to_upper()
	_prepare_grid_and_theater(selected)
	if theater_cells.is_empty():
		state = WarState.IDLE
		return false
	_prepare_frontlines()
	_prepare_theater_cities(scenario.cities)
	_initialize_land_pockets()
	_spawn_initial_units()
	_spawn_initial_bases()
	_build_unit_spatial_hash()
	_initialize_personnel()

	simulation_seconds = 0.0
	frame_accumulator = 0.0
	sim_frame_count = 0
	sim_tick_count = 0
	visual_loop_count = 0
	last_mechanics_frame = 0
	speed_index = 1
	is_paused = false
	result_elapsed = 0.0
	result = {}
	_dominance_anchor_tick = -1
	_decisive_anchor_tick = -1
	_stalemate_anchor_tick = 0
	_stalemate_anchor_score = -1.0
	state = WarState.RUNNING
	country_frontline_state.clear()
	_update_frontline_coordination(_build_force_counts(), true)
	battle_planner.initialize(self, int(_rng.seed))
	_last_result_state = state
	render_revision += 1
	_update_control_totals()
	if native_authoritative_enabled:
		if _native_conflict_core == null or not _native_conflict_core.has_method("native_war_start_production") or \
		not _native_conflict_core.native_war_start_production(self):
			push_error("Native war launch failed: a compatible C++ conflict runtime is required")
			state = WarState.IDLE
			return false
		_native_authoritative_active = true
		native_render_snapshot = _native_conflict_core.native_tick_render_snapshot()
		_native_planner_visual_snapshot.clear()
		_native_planner_visual_tick = -1
	return true


func advance(delta: float) -> int:
	if _native_authoritative_active:
		var tick_started: = Time.get_ticks_usec()
		var step: Dictionary = _native_conflict_core.native_tick_advance(delta, speed_index, is_paused)
		native_last_advance = step
		native_skip_render = bool(step.get("skip_render", false))
		var native_result_state: = int(step.get("state", -1)) as WarState
		if not bool(step.get("active", false)) or \
		String(step.get("actor_step", "")) != "production_native_v1" and native_result_state != WarState.RESULT:
			push_error("Native war tick failed; refusing GDScript simulation fallback")
			assert (false, "Native war tick must remain authoritative")
			return -1
		if int(step.get("ticks", 0)) > 0:


			last_tick_usec = Time.get_ticks_usec() - tick_started
		var changed_cells: PackedInt32Array = step.get("changed_control_cells", PackedInt32Array())
		native_last_changed_control_cells = changed_cells.size()
		_apply_native_presentation_delta(int(step.get("ticks", 0)))
		return int(step.get("ticks", 0))



	if _native_source_clock == null or not _native_source_clock.has_method("advance"):
		push_error("MWSourceClock is unavailable: rebuild and reload the native extension")
		assert (false, "MWSourceClock is required for ConflictRuntimeState.advance")
		return -1
	return int(_native_source_clock.advance(self, delta))


func native_authoritative_active() -> bool:
	return _native_authoritative_active and _native_conflict_core != null and \
	bool(_native_conflict_core.native_tick_active())


func planning_visual_state() -> Dictionary:
	if not native_authoritative_active():
		return {"commander_groups": battle_planner.commander_groups, 
			"operations": battle_planner.operations, 
			"officer_group_count": battle_planner.officer_groups.size(), 
			"sector_candidates": battle_planner._sector_candidates}
	if _native_planner_visual_tick != sim_tick_count:
		if not _native_conflict_core.has_method("native_war_planner_visual_snapshot"):
			push_error("Native planner presentation API unavailable")
			return {}
		_native_planner_visual_snapshot = _native_conflict_core.native_war_planner_visual_snapshot()
		if not bool(_native_planner_visual_snapshot.get("active", false)):
			push_error("Native planner presentation state unavailable")
			return {}
		_native_planner_visual_tick = sim_tick_count
	return _native_planner_visual_snapshot


func native_differential_snapshot() -> Dictionary:



	if not native_authoritative_active(): return {}
	var snapshot: Dictionary = _native_conflict_core.native_tick_state_snapshot()
	var planner: Dictionary = _native_conflict_core.native_war_planner_snapshot()


	var plans: Dictionary = planner.get("plans", {}).duplicate(true)
	for country: int in plans:
		plans[country]["country"] = country
	var operations: Dictionary = planner.get("operations", {}).duplicate(true)
	for operation_id: int in operations:
		operations[operation_id]["id"] = operation_id
		operations[operation_id]["officers"] = Array(operations[operation_id].get("officers", PackedInt64Array()))
		operations[operation_id]["lane_cells"] = Array(operations[operation_id].get("lane_cells", PackedInt32Array()))
	var officers: Dictionary = planner.get("officer_groups", {}).duplicate(true)
	for group_id: int in officers:
		officers[group_id]["id"] = group_id
		officers[group_id]["parent"] = officers[group_id].get("parent_operation")
		officers[group_id].erase("parent_operation")
		officers[group_id]["units"] = Array(officers[group_id].get("units", PackedInt64Array()))
	var commanders: Dictionary = planner.get("commander_groups", {}).duplicate(true)
	for group_id: int in commanders:
		commanders[group_id]["id"] = group_id
		commanders[group_id]["officers"] = Array(commanders[group_id].get("officers", PackedInt64Array()))
	var pocket_rows: Array = []
	for pocket: Dictionary in snapshot.get("pockets", []):
		pocket_rows.append([pocket.get("side"), pocket.get("outcome"), 
			pocket.get("owned"), pocket.get("since"), pocket.get("cities"), 
			pocket.get("allowance")])
	var native_rng: PackedInt64Array = snapshot.get("rng", PackedInt64Array())
	var control_percent: = PackedFloat32Array()
	var native_percent: PackedFloat64Array = snapshot.get("side_control_percent", PackedFloat64Array())
	for value: float in native_percent: control_percent.append(value)


	var formation_rows: Array = snapshot.get("formations", [])
	if int(snapshot.get("sim_tick_count", -1)) == 0:
		formation_rows = _native_conflict_core.formation_state_export()
	else:
		var base_rows: Array = _native_conflict_core.formation_state_export()
		for index: int in formation_rows.size():
			var native_unit: Dictionary = formation_rows[index]
			if String(native_unit.get("city_exit_slot", "")).is_empty():
				native_unit.erase("city_exit_slot")
			if String(native_unit.get("departure_exit_slot", "")).is_empty():
				native_unit.erase("departure_exit_slot")
			if ((int(native_unit.get("deploy_ticks", 0)) > 0 or \
			int(snapshot.get("sim_tick_count", 0)) <= DEPLOYMENT_TICKS) and \
			int(native_unit.get("reinforcement_city_id", -1)) < 0) or \
			String(native_unit.get("deployment_phase", "")) == "MUSTERING":
				var deployed: Dictionary = base_rows[index]

				for key: String in ["sector_role", "sector_destination", "sector_operation", 
					"sector_commit_until", "sector_recover_until", "sector_slot", 
					"sector_route", "sector_route_cursor", "sector_checked_revision", 
					"sector_lookahead_tick", "sector_route_blocked", 
					"formation_target", "reserved_slot", "formation_slot_id", 
					"front_sector", "formation_row", "formation_assignment_tick", "formation_normal", 
					"formation_tangent", "row_rotation"]:
					if native_unit.has(key): deployed[key] = native_unit[key]
				if String(native_unit.get("deployment_phase", "")) == "MUSTERING":
					deployed.erase("reserved_slot")
					deployed.erase("formation_target")
					deployed.erase("sector_destination")
					deployed.erase("reinforcement_checked_revision")
					for key: String in ["deployment_phase", "deployment_transit", 
						"muster_city", "muster_anchor", "muster_started", "muster_until", 
						"muster_checked_revision", "muster_retry_time", "city_exit_slot", 
						"departure_exit_slot", "city_exit_target", "deployment_assigned_sector", 
						"departure_waypoint"]:
						if native_unit.has(key): deployed[key] = native_unit[key]
					if int(native_unit.get("damage_tick", -1)) >= 0:
						deployed["damage_tick"] = native_unit["damage_tick"]
						deployed["hits_this_tick"] = native_unit["hits_this_tick"]
				formation_rows[index] = deployed
				continue

			native_unit.erase("transit_boost_entitled")
			native_unit.erase("route_checked_epoch")
			native_unit.erase("pocket_outcome")
			if int(native_unit.get("reinforcement_city_id", -1)) < 0:
				for key: String in ["deployment_phase", "muster_until", "muster_started", 
					"deployment_assigned_sector", "muster_anchor", "muster_checked_revision", "reinforcement_checked_revision", 
					"muster_retry_time", "muster_city", "city_exit_slot", 
					"departure_exit_slot", "city_exit_target", "departure_exit_pending", 
					"deployment_released"]:
					native_unit.erase(key)
			elif String(native_unit.get("deployment_phase", "")) == "MUSTERING":

				native_unit.erase("reinforcement_checked_revision")
			elif String(native_unit.get("deployment_phase", "")) == "STRANDED" and \
			int(native_unit.get("reinforcement_checked_revision", -1)) == -1:
				native_unit.erase("reinforcement_checked_revision")
			if String(native_unit.get("deployment_phase", "")) == "STRANDED" and \
			float(native_unit.get("deployment_released", 0.0)) <= 0.0:
				for key: String in ["damage_dealt_multiplier", "speed_buff_multiplier", 
					"last_ally_weight", "local_enemy_count", "enemy_delta", 
					"border_retreat", "departure_exit_pending", "deployment_released"]:
					native_unit.erase(key)
			if String(native_unit.get("deployment_phase", "")) == "RELOCATING" and \
			float(native_unit.get("deployment_released", 0.0)) <= 0.0:
				for key: String in ["damage_dealt_multiplier", "speed_buff_multiplier", 
					"last_ally_weight", "local_enemy_count", "enemy_delta", 
					"border_retreat", "deployment_released", "departure_exit_pending"]:
					native_unit.erase(key)
			if int(native_unit.get("damage_tick", -1)) < 0:
				native_unit.erase("damage_tick")
				native_unit.erase("hits_this_tick")
			formation_rows[index] = native_unit
	var cohesion_sectors: Dictionary = snapshot.get("cohesion_sectors", {}).duplicate(true)
	for sector_cell: int in cohesion_sectors:
		for key: String in ["units", "front", "reserve"]:
			cohesion_sectors[sector_cell][key] = Array(cohesion_sectors[sector_cell].get(key, PackedInt64Array()))
	return {
		"formations": formation_rows, 
		"personnel_casualties": [snapshot.get("side_personnel"), 
			snapshot.get("side_casualties"), snapshot.get("country_casualties"), 
			snapshot.get("casualty_exact"), country_initial_personnel, 
			snapshot.get("queued_reinforcements")], 
		"control": [snapshot.get("world_owners"), snapshot.get("de_jure_owners"), 
			snapshot.get("occupation"), snapshot.get("primary_occupier"), 
			snapshot.get("control_revision"), control_percent, 
			snapshot.get("held_control_cells"), snapshot.get("country_controlled_cells")], 
		"pockets": [pocket_rows, snapshot.get("encirclement_popups"), 
			snapshot.get("encirclement_collapse_count"), 
			snapshot.get("encirclement_revision"), 
			snapshot.get("encirclement_pass_count")], 
		"planner": [plans, operations, 
			officers, commanders, 
			planner.get("unit_orders"), planner.get("decisions"), 
			snapshot.get("country_frontline_state")], 
		"cohesion": [cohesion_sectors, snapshot.get("cohesion_operations"), 
			snapshot.get("cohesion_history"), snapshot.get("front_slots"), 
			snapshot.get("front_slot_reservations")], 
		"deployment": [snapshot.get("city_muster_exits"), snapshot.get("city_allocations"), 
			snapshot.get("sector_allocations"), snapshot.get("recruitment_events"), 
			snapshot.get("reinforcement_counts"), snapshot.get("next_unit_id")], 
		"battles": snapshot.get("battles"), 
		"combat_events": [snapshot.get("combat_events"), snapshot.get("combat_event_counts"), 
			snapshot.get("damage_this_tick"), snapshot.get("engagement_damage_this_tick"), 
			snapshot.get("death_events"), snapshot.get("surrender_events")], 
		"rng": Array(native_rng), 
		"clock_result": [snapshot.get("sim_tick_count"), snapshot.get("sim_frame_count"), 
			snapshot.get("visual_loop_count"), snapshot.get("simulation_seconds"), 
			snapshot.get("frame_accumulator"), snapshot.get("last_mechanics_frame"), 
			snapshot.get("state"), snapshot.get("result"), 
			snapshot.get("paused"), snapshot.get("speed_index")], 
	}


func _apply_native_presentation_delta(committed_ticks: int) -> void :


	if not _native_conflict_core.native_war_sync_presentation(self, committed_ticks):
		push_error("Native presentation state unavailable for authoritative war")


func direct_combat_permitted(distance: float, last_combat_frame: int) -> bool:

	return distance <= 0.05 or (last_combat_frame != 0 and sim_frame_count - last_combat_frame < 2)


func perform_simulation_tick() -> void :
	if state != WarState.RUNNING:
		return
	var tick_started: = Time.get_ticks_usec()
	if performance_profile_enabled: exclusive_profile.begin(tick_started)
	_profile_movement_usec = 0
	_profile_swept_usec = 0
	_profile_spatial_usec = 0
	_profile_front_usec = 0
	_profile_recruitment_usec = 0
	_profile_diffuse_usec = 0
	_profile_unit_influence_usec = 0
	_profile_targeting_usec = 0
	_profile_garrison_usec = 0
	_profile_damage_usec = 0
	_profile_battle_records_usec = 0
	sim_tick_count += 1
	if not _inside_advance:

		simulation_seconds += 1.0 / 60.0
	last_mechanics_frame = sim_frame_count
	damage_this_tick = 0.0
	engagement_damage_this_tick = 0.0
	active_battles.clear()
	var spatial_hash: = _build_unit_spatial_hash()
	if sim_frame_count % 30 == 0 and units.size() > 40:
		_consolidate_unit_stacks(spatial_hash, true)
		spatial_hash = _build_unit_spatial_hash()
	var side_centroids: = _build_side_centroids()
	if _garrison_cache_frame != sim_frame_count:
		_garrison_cache.clear()
		_garrison_cache_frame = sim_frame_count
	var force_counts: = _build_force_counts()
	if performance_profile_enabled:
		exclusive_profile.count(&"living_formations", int(force_counts.sides[0]) + int(force_counts.sides[1]))
		exclusive_profile.count(&"world_grid_cells", land_mask.size())
		exclusive_profile.count(&"initial_participating_owned_cells", theater_cells.size())
		exclusive_profile.count(&"active_front_cells", _active_front_cells.size())
		exclusive_profile.count(&"front_segments", frontline_segment_count)
		exclusive_profile.count(&"cities", planner_cities.size())
		for country: int in force_counts.countries:
			exclusive_profile.count(StringName("living_country_%d" % country), force_counts.countries[country])
			exclusive_profile.count(StringName("initial_owned_country_%d" % country), country_cells[country].size())
	_update_frontline_coordination(force_counts)
	var planner_started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	if performance_profile_enabled: exclusive_profile.enter(&"planner")
	battle_planner.update(self)
	sector_cohesion.update(self)
	if performance_profile_enabled: exclusive_profile.leave()
	var planner_usec: = Time.get_ticks_usec() - planner_started if performance_profile_enabled else 0
	var side_unit_counts: PackedInt32Array = force_counts["sides"]
	var country_unit_counts: Dictionary = force_counts["countries"]
	var unit_count_at_start: = units.size()
	var verification_positions: Dictionary = {}
	if verification_enabled:
		for observed_unit: Dictionary in units:
			verification_positions[int(observed_unit["id"])] = Vector2(observed_unit["longitude"], observed_unit["latitude"])
	var tactics_started: = Time.get_ticks_usec()
	_city_transit_actor_indices.clear()

	for unit_index: int in range(unit_count_at_start - 1, -1, -1):
		if unit_index >= units.size():
			break
		var unit: Dictionary = units[unit_index]
		if float(unit.get("health", 0.0)) <= 0.0:
			continue
		unit["direction"] = Vector2.ZERO
		if performance_profile_enabled: exclusive_profile.enter(&"deployment_lifecycle")
		var muster_owns_tick: = false
		var deployment_phase: String = unit.get("deployment_phase", "")
		if not muster_active_fastpath_enabled or deployment_phase == "MUSTERING" or deployment_phase == "RELOCATING" or deployment_phase == "STRANDED":
			muster_owns_tick = _update_unit_muster(unit_index)
		else:


			_contact_inactive[unit_index] = 0
		if performance_profile_enabled: exclusive_profile.leave()
		if muster_owns_tick:
			continue
		if unit.get("deployment_phase", "") == "TRANSIT":
			_city_transit_actor_indices.append(unit_index)
		if int(unit.get("deploy_ticks", 0)) > 0:
			unit["deploy_ticks"] = int(unit["deploy_ticks"]) - 1
			units[unit_index] = unit
			continue
		var boosted: = int(unit.get("victory_boost_ticks", 0)) > 0
		unit["damage_dealt_multiplier"] = 1.4 if boosted else 1.0
		unit["speed_buff_multiplier"] = 1.3 if boosted else 1.0
		if boosted:
			unit["victory_boost_ticks"] = int(unit["victory_boost_ticks"]) - 1
		if performance_profile_enabled: exclusive_profile.enter(&"pocket_unit_effects")
		_apply_encircled_unit_effects(unit_index)
		if performance_profile_enabled: exclusive_profile.leave()
		if float(unit["health"]) <= 0.0:
			continue
		var target_index: = _nearest_enemy_unit_index(unit_index, spatial_hash)
		if performance_profile_enabled: exclusive_profile.enter(&"border_safety")
		unit["border_retreat"] = _frontline_border_safety(unit_index)
		if performance_profile_enabled: exclusive_profile.leave()
		if float(unit["health"]) <= 0.0:
			continue
		var garrison: = _garrison_objective(unit, target_index, spatial_hash)
		if is_finite(garrison.x):
			var phase: = float(unit.get("tactical_phase", 0.0))
			var own_geo: = Vector2(float(unit["longitude"]), float(unit["latitude"]))
			var delta: = _wrapped_geo_delta(own_geo, garrison) + Vector2(cos(phase * 100.0), sin(phase * 100.0)) * 0.08


			_move_garrison_unit(unit_index, delta)
			continue
		if target_index >= 0 and target_index < units.size():
			var target: Dictionary = units[target_index]
			var delta_geo: = _wrapped_geo_delta(
				Vector2(float(unit["longitude"]), float(unit["latitude"])), 
				Vector2(float(target["longitude"]), float(target["latitude"]))
			)
			var phase: = float(unit.get("tactical_phase", 0.0))
			var target_delta: = delta_geo + Vector2(cos(phase * 100.0), sin(phase * 100.0)) * 0.08
			if direct_combat_permitted(target_delta.length(), int(unit.get("last_combat_tick", -1000))):
				if performance_profile_enabled:
					exclusive_profile.enter(&"combat_resolution")
					exclusive_profile.count(&"direct_pairs")
				_trace_combat("direct", unit, target, target_delta.length())
				var target_damage: = COMBAT_DAMAGE * 0.7 * float(unit.get("damage_dealt_multiplier", 1.0))
				var self_damage: = 0.0 if city_muster.inactive(target) else COMBAT_DAMAGE * 0.8 * _defense_multiplier(unit) * float(unit.get("damage_taken_multiplier", 1.0))
				_trace_combat("direct_return", target, unit, target_delta.length(), direct_combat_permitted(target_delta.length(), int(unit.get("last_combat_tick", -1000))))
				_record_damage(target_index, target_damage, "direct", int(unit["id"]))
				_record_damage(unit_index, self_damage, "direct_return", int(target["id"]))
				unit["last_combat_tick"] = sim_frame_count
				target["last_combat_tick"] = sim_frame_count
				_apply_engagement_knockback(unit_index, target_index, delta_geo, target_damage, self_damage)
				if combat_trace_enabled:
					for event_index: int in range(maxi(0, combat_events.size() - 2), combat_events.size()):
						combat_events[event_index]["post_recoil_distance"] = _wrapped_geo_delta(Vector2(unit["longitude"], unit["latitude"]), Vector2(target["longitude"], target["latitude"])).length()
				if float(target["health"]) <= 0.0:
					unit["victory_boost_ticks"] = 180
				_record_battle(unit, target)
				if performance_profile_enabled: exclusive_profile.leave()
				if bool(unit.get("row_rotation", false)):
					_move_unit_toward(unit_index, unit.get("formation_normal", Vector2.UP))
			else:
				_move_unit_toward(unit_index, target_delta.normalized())
		else:
			var enemy_side: = 1 - int(unit["side_index"])
			if side_unit_counts[enemy_side] <= 0:
				var objective: = _mop_up_objective_for_unit(unit_index, country_unit_counts)
				if is_finite(objective.x) and is_finite(objective.y):
					var own_geo: = Vector2(float(unit["longitude"]), float(unit["latitude"]))
					var objective_delta: = _wrapped_geo_delta(own_geo, objective)
					if objective_delta.length_squared() > 1e-06:
						_move_unit_toward(unit_index, objective_delta.normalized())
			elif side_centroids.has(enemy_side):
				var own_geo: = Vector2(float(unit["longitude"]), float(unit["latitude"]))
				var strategic_delta: = _wrapped_geo_delta(own_geo, side_centroids[enemy_side])
				if strategic_delta.length_squared() > 1e-06:
					_move_unit_toward(unit_index, strategic_delta.normalized())

	_finish_city_transit_handoffs()
	if verification_enabled:
		for observed_unit: Dictionary in units:
			var previous_geo: Vector2 = verification_positions.get(int(observed_unit["id"]), Vector2(observed_unit["longitude"], observed_unit["latitude"]))
			_verify_event("movement", observed_unit, -1, 0.0, {"displacement": _wrapped_geo_delta(previous_geo, Vector2(observed_unit["longitude"], observed_unit["latitude"]))})
	var influence_started: = Time.get_ticks_usec()
	if performance_profile_enabled: exclusive_profile.enter(&"influence")
	_apply_unit_influence()
	_resolve_capital_surrenders()
	if performance_profile_enabled: exclusive_profile.leave()

	if performance_profile_enabled: exclusive_profile.enter(&"pocket_topology")
	_resolve_land_pockets()
	if performance_profile_enabled: exclusive_profile.leave()
	var recovery_started: = Time.get_ticks_usec()
	if performance_profile_enabled: exclusive_profile.enter(&"recruitment_cleanup")
	_no_damage_ticks = _no_damage_ticks + 1 if engagement_damage_this_tick <= 0.0 else 0
	if sim_tick_count >= 300 and side_unit_counts[0] > 0 and side_unit_counts[1] > 0:
		longest_no_damage_ticks = maxi(longest_no_damage_ticks, _no_damage_ticks)
	_remove_destroyed_units()
	city_muster.prune(units)
	_try_reinforcements()


	_build_unit_spatial_hash()
	if sim_tick_count % 15 == 0:
		_update_control_totals()
		_evaluate_terminal_outcome()
	_age_encirclement_popups()
	if performance_profile_enabled: exclusive_profile.leave()
	render_revision += 1
	visual_revisions.publish_dynamic()
	last_tick_usec = Time.get_ticks_usec() - tick_started
	last_tick_phases_usec[0] = tactics_started - tick_started
	last_tick_phases_usec[1] = influence_started - tactics_started
	last_tick_phases_usec[2] = recovery_started - influence_started
	last_tick_phases_usec[3] = last_tick_usec - (recovery_started - tick_started)
	if performance_profile_enabled:
		exclusive_profile.finish()
		last_profile_usec = {
			"authoritative": last_tick_usec, 
			"movement": _profile_movement_usec, 
			"swept_path": _profile_swept_usec, 
			"spatial_hash": _profile_spatial_usec, 
			"front_slots": _profile_front_usec, 
			"recruitment": _profile_recruitment_usec, 
			"planner": planner_usec, 
			"influence_control_pockets": recovery_started - influence_started, 
			"diffusion": _profile_diffuse_usec, 
			"unit_influence": _profile_unit_influence_usec, 
			"targeting_including_contact": _profile_targeting_usec, 
			"garrison": _profile_garrison_usec, 
			"damage_accounting": _profile_damage_usec, 
			"battle_records": _profile_battle_records_usec, 
			"pocket_resolution": last_encirclement_usec, 
		}


func record_render_profile(label: StringName, elapsed_usec: int, accumulate: bool = false) -> void :
	if performance_profile_enabled:
		var same_frame: = int(render_profile_frame.get(label, -1)) == Engine.get_process_frames()
		render_profile_usec[label] = elapsed_usec + (int(render_profile_usec.get(label, 0)) if accumulate and same_frame else 0)
		render_profile_frame[label] = Engine.get_process_frames()
		render_profile_counts[label] = int(render_profile_counts.get(label, 0)) + 1


func set_paused(paused: bool) -> void :
	if _native_authoritative_active and _native_conflict_core.has_method("native_war_control"):
		_native_conflict_core.native_war_control(self, "pause", int(paused), MAX_PLAYABLE_SPEED_INDEX)
		return
	if state == WarState.RUNNING:
		is_paused = paused


func toggle_pause() -> bool:
	if _native_authoritative_active and _native_conflict_core.has_method("native_war_control"):
		_native_conflict_core.native_war_control(self, "toggle_pause", 0, MAX_PLAYABLE_SPEED_INDEX)
		return is_paused
	if state == WarState.RUNNING:
		is_paused = not is_paused
	return is_paused


func current_speed() -> float:
	return SPEED_STEPS[clampi(speed_index, 0, SPEED_STEPS.size() - 1)]


func set_random_seed(seed_value: int) -> void :


	_rng.seed = seed_value


func decrease_speed() -> float:
	if _native_authoritative_active and _native_conflict_core.has_method("native_war_control"):
		_native_conflict_core.native_war_control(self, "speed_down", 0, MAX_PLAYABLE_SPEED_INDEX)
		return current_speed()
	speed_index = maxi(0, speed_index - 1)
	return current_speed()


func increase_speed() -> float:
	if _native_authoritative_active and _native_conflict_core.has_method("native_war_control"):
		_native_conflict_core.native_war_control(self, "speed_up", 0, MAX_PLAYABLE_SPEED_INDEX)
		return current_speed()
	speed_index = mini(MAX_PLAYABLE_SPEED_INDEX, speed_index + 1)
	return current_speed()


func cycle_speed() -> float:
	if _native_authoritative_active and _native_conflict_core.has_method("native_war_control"):
		_native_conflict_core.native_war_control(self, "speed_cycle", 0, MAX_PLAYABLE_SPEED_INDEX)
		return current_speed()
	speed_index = (speed_index + 1) % (MAX_PLAYABLE_SPEED_INDEX + 1)
	return current_speed()


func quick_restart() -> PackedInt32Array:
	stop()
	world_owners = prewar_world_owners.duplicate()
	de_jure_owners = prewar_de_jure_owners.duplicate()
	land_mask = prewar_land_mask.duplicate()
	occupation = PackedFloat32Array()
	primary_occupier = PackedInt32Array()
	state = WarState.IDLE
	return world_owners.duplicate()


func stop() -> void :


	state = WarState.STOPPED
	if _native_authoritative_active and _native_conflict_core != null:
		_native_conflict_core.native_tick_clear()
	_native_authoritative_active = false
	native_render_snapshot.clear()
	native_front_trace.clear()
	native_front_trace_revision = -1
	native_last_changed_control_cells = 0
	_native_planner_visual_snapshot.clear()
	_native_planner_visual_tick = -1
	movement_audit = Callable()
	is_paused = false
	frame_accumulator = 0.0
	units.clear()
	_clear_contact_reads()
	bases.clear()
	active_battles.clear()
	battle_planner.clear()
	sector_cohesion.clear()
	city_deployment.clear()
	city_muster.clear()
	_clear_encirclement()
	unit_spatial_hash.clear()
	recruitment_events.clear()
	_spawn_cell_cache.clear()
	_city_front_route_cache.clear()
	queued_reinforcements.clear()
	_occupied_home_cells.clear()
	render_revision += 1
	visual_revisions.reset(grid_size)


func has_active_war() -> bool:
	return state == WarState.MOBILIZING or state == WarState.RUNNING or state == WarState.RESULT


func should_return_to_setup() -> bool:
	return state == WarState.RESULT and result_elapsed >= RESULT_DURATION_SECONDS


func result_title() -> String:
	return String(result.get("title", "CONFLICT CONCLUDED"))


func unit_count_for_side(side_index: int) -> int:
	if _native_authoritative_active:
		var sides_column: PackedInt32Array = native_render_snapshot.get("sides", PackedInt32Array())
		var health_column: PackedFloat64Array = native_render_snapshot.get("health", PackedFloat64Array())
		var native_count: = 0
		for i: int in mini(sides_column.size(), health_column.size()):
			if sides_column[i] == side_index and health_column[i] > 0.0: native_count += 1
		return native_count
	var count: = 0
	for unit: Dictionary in units:
		if int(unit.get("side_index", -1)) == side_index and float(unit.get("health", 0.0)) > 0.0:
			count += 1
	return count


func country_color(country_id: int) -> Color:
	return country_colors.get(country_id, Color("#5d6770"))


func geo_for_grid_index(index: int) -> Vector2:
	if grid_size.x <= 0:
		return Vector2.ZERO
	var x: = index % grid_size.x
	var y: = int(float(index) / float(grid_size.x))
	return Vector2(
		(float(x) + 0.5) * 360.0 / float(grid_size.x) - 180.0, 
		90.0 - (float(y) + 0.5) * 180.0 / float(grid_size.y)
	)


func grid_index_for_geo(longitude: float, latitude: float) -> int:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return -1
	var wrapped_longitude: = fposmod(longitude + 180.0, 360.0) - 180.0
	var x: = clampi(int(floor((wrapped_longitude + 180.0) / 360.0 * grid_size.x)), 0, grid_size.x - 1)
	var y: = clampi(int(floor((90.0 - latitude) / 180.0 * grid_size.y)), 0, grid_size.y - 1)
	return y * grid_size.x + x


func effective_owner_at(index: int) -> int:
	if index < 0 or index >= world_owners.size():
		return 0
	if index < primary_occupier.size() and absf(occupation[index]) > 0.05 and primary_occupier[index] > 0:
		return primary_occupier[index]
	return world_owners[index]


func finish_war(winner_side: int, reason: String = "FULL_CAPITULATION") -> void :
	if state != WarState.RUNNING:
		return
	_apply_treaty(winner_side, reason)


func _prepare_grid_and_theater(selected: Dictionary) -> void :
	visual_revisions.reset(grid_size)
	var cell_total: = world_owners.size()
	land_mask.resize(cell_total)
	land_mask.fill(0)
	occupation.resize(cell_total)
	occupation.fill(0.0)
	primary_occupier.resize(cell_total)
	primary_occupier.fill(0)
	theater_cells = PackedInt32Array()
	country_cells.clear()
	var temporary_cells: Dictionary = {}
	for country_id: int in selected:
		temporary_cells[country_id] = []
	var min_x: = grid_size.x - 1
	var max_x: = 0
	var min_y: = grid_size.y - 1
	var max_y: = 0
	for index: int in range(cell_total):
		var owner_id: = world_owners[index]
		if owner_id <= 0:
			continue
		land_mask[index] = 1
		if not selected.has(owner_id):
			continue
		land_mask[index] = 2
		var side_index: int = int(selected[owner_id])
		occupation[index] = 1.0 if side_index % 2 == 0 else -1.0
		primary_occupier[index] = owner_id
		theater_cells.append(index)
		var bucket: Array = temporary_cells[owner_id]
		bucket.append(index)
		var x: = index % grid_size.x
		var y: = int(float(index) / float(grid_size.x))
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)
	prewar_land_mask = land_mask.duplicate()
	for index: int in theater_cells:
		prewar_land_mask[index] = 1
	for country_id: int in temporary_cells:
		var owned_cells: = PackedInt32Array(temporary_cells[country_id])
		country_cells[country_id] = owned_cells
		_country_controlled_cells[country_id] = owned_cells.size()
	theater_bounds = Rect2i(min_x, min_y, maxi(1, max_x - min_x + 1), maxi(1, max_y - min_y + 1))
	_side_initial_cells.resize(2)
	_side_initial_cells.fill(0)
	for country_id: int in country_cells:
		var side_index: int = int(country_to_side[country_id])
		_side_initial_cells[side_index] += (country_cells[country_id] as PackedInt32Array).size()
	_held_control_cells = _side_initial_cells.duplicate()


func _prepare_frontlines() -> void :
	frontline_cells.clear()
	_active_front_cells.clear()
	render_front_quads.clear()
	front_coverage.clear()
	_coverage_tick = -1
	frontline_segment_count = 0
	var temporary_fronts: Dictionary = {}
	for country_id: int in country_cells:
		temporary_fronts[country_id] = []
	var cardinal: = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for index: int in theater_cells:
		_refresh_render_front_quad(index)
		var owner_id: = world_owners[index]
		var side_index: int = int(country_to_side[owner_id])
		var x: = index % grid_size.x
		var y: = int(float(index) / float(grid_size.x))
		if x + 1 < grid_size.x and land_mask[index + 1] == 2 and occupation[index] * occupation[index + 1] < 0.0:
			frontline_segment_count += 1
		if index + grid_size.x < occupation.size() and land_mask[index + grid_size.x] == 2 and occupation[index] * occupation[index + grid_size.x] < 0.0:
			frontline_segment_count += 1
		var push_grid: = Vector2.ZERO
		var is_front: = false
		for direction: Vector2i in cardinal:
			var nx: = x + direction.x
			var ny: = y + direction.y
			if nx < 0 or nx >= grid_size.x or ny < 0 or ny >= grid_size.y:
				continue
			var neighbor_id: = world_owners[ny * grid_size.x + nx]
			if country_to_side.has(neighbor_id) and int(country_to_side[neighbor_id]) != side_index:
				is_front = true
				push_grid -= Vector2(direction)
		if is_front:
			_active_front_cells[index] = true
			var push: = push_grid.normalized()
			var front_bucket: Array = temporary_fronts[owner_id]
			front_bucket.append({"index": index, "push_lon": push.x, "push_lat": - push.y})
	for country_id: int in temporary_fronts:
		frontline_cells[country_id] = temporary_fronts[country_id]


func _prepare_theater_cities(source_cities: Array[CityData]) -> void :
	planner_cities.clear()
	prewar_capitals.clear()
	_encirclement_cities.clear()
	active_theater_city_ids.clear()
	city_cell_set.clear()
	country_city_counts.clear()
	country_city_positions.clear()
	country_city_records.clear()
	_country_city_spatial_hash.clear()
	for country_id: int in country_cells:
		country_city_counts[country_id] = 0
		country_city_positions[country_id] = []
		country_city_records[country_id] = []
		_country_city_spatial_hash[country_id] = {}
	for city: CityData in source_cities:
		var index: = grid_index_for_geo(city.longitude, city.latitude)
		if index >= 0 and index < land_mask.size() and land_mask[index] == 2:
			var city_record: = {"id": city.id, "name": city.city_name, "cell": index, "geo": Vector2(city.longitude, city.latitude), "home_owner": prewar_world_owners[index], "capital": city.is_capital}
			planner_cities.append(city_record)
			if city.is_capital and country_to_side.has(prewar_world_owners[index]):
				prewar_capitals[prewar_world_owners[index]] = city_record.duplicate()
			_encirclement_cities.append(Vector2(city.longitude, city.latitude))
			active_theater_city_ids[city.id] = true
			city_cell_set[index] = true
			var sovereign_id: = world_owners[index]
			if country_city_counts.has(sovereign_id):
				country_city_counts[sovereign_id] = int(country_city_counts[sovereign_id]) + 1
				(country_city_records[sovereign_id] as Array).append(city_record)
				var positions: Array = country_city_positions[sovereign_id]
				var city_geo: = Vector2(city.longitude, city.latitude)
				positions.append(city_geo)
				var city_hash: Dictionary = _country_city_spatial_hash[sovereign_id]
				var key: = _spatial_key(city.longitude, city.latitude)
				if not city_hash.has(key):
					city_hash[key] = []
				var bucket: Array = city_hash[key]
				bucket.append(city_geo)


func _spawn_initial_units() -> void :
	units.clear()
	_clear_contact_reads()
	formation_slots.clear()
	_prepare_allied_staging()
	formation_launch_counts.clear()
	source_launch_counts.fill(0)
	_next_unit_id = 1
	var side_unit_counts: = PackedInt32Array([0, 0])
	for side_index: int in range(2):
		for country_id: int in sides[side_index]:
			var cells: PackedInt32Array = country_cells.get(country_id, PackedInt32Array())
			if cells.is_empty():
				continue
			var source_desired: = source_formation_count(cells.size(), force_density)

			var manpower_baseline: = source_formation_count(cells.size(), 1.0)
			source_launch_counts[side_index] += mini(manpower_baseline, MAX_UNITS_PER_SIDE - source_launch_counts[side_index])
			var front_count: int = (frontline_cells.get(country_id, []) as Array).size()
			var coverage_count: int = maxi(front_count, (_initial_staging_fronts.get(country_id, []) as Array).size())
			var forward_samples: = int(ceil(coverage_count * GRID_RESOLUTION / FRONT_FORMATION_SPACING * force_density))
			var baseline: = int(ceil(source_desired * FORMATION_BASELINE_MULTIPLIER))
			var reserve_budget: = int(ceil(coverage_count * 0.5 * force_density))
			var desired: = maxi(baseline + reserve_budget, forward_samples * 2)
			var pool: = manpower_baseline * int(UNIT_TO_SOLDIER_RATIO)
			var manual: PackedInt64Array = launch_options.get("manual_manpower", PackedInt64Array([0, 0]))
			if manual[side_index] > 0:
				var side_baseline: = 0
				for ally: int in sides[side_index]:
					side_baseline += source_formation_count((country_cells.get(ally, PackedInt32Array()) as PackedInt32Array).size(), 1.0)
				pool = int(float(manual[side_index]) * manpower_baseline / maxi(1, side_baseline))
			desired = mini(desired, maxi(1, int(pool / float(MIN_FORMATION_PERSONNEL))))
			desired = mini(desired, int(round(DENSE_COUNTRY_SAFETY_CAP * force_density)))
			desired = mini(desired, MAX_UNITS_PER_SIDE - side_unit_counts[side_index])
			formation_launch_counts[country_id] = {"source": source_desired, "expanded": desired, "front_cells": front_count, "coverage_floor": forward_samples * 2, "baseline": baseline, "reserve_budget": reserve_budget, "manpower_baseline": manpower_baseline, "allied_staging_cells": (_initial_staging_fronts.get(country_id, []) as Array).size()}
			var prior_budget: = mini(maxi(baseline, int(ceil(front_count * force_density))), int(round(FORMATION_COUNTRY_CAP * force_density)))
			formation_launch_counts[country_id]["pressure_weight"] = float(prior_budget) / maxi(1, desired)
			for unit_number: int in range(maxi(0, desired)):
				if _spawn_unit(side_index, country_id, false, true, unit_number, desired):
					side_unit_counts[side_index] += 1
	formation_slots.update(self, true)
	for unit: Dictionary in units:
		if unit.has("formation_target"):
			var target: Vector2 = unit.formation_target
			unit.longitude = target.x
			unit.latitude = target.y
	_refresh_front_coverage(true)
	_initial_staging_fronts.clear()

func _prepare_allied_staging() -> void :



	_initial_staging_fronts.clear()
	var remote_countries: Array[int] = []
	for side: Array in sides:
		for country: int in side:
			if (frontline_cells.get(country, []) as Array).is_empty() and not MWBattleDoctrines.homeland_only(String(country_doctrines.get(country, "Combined Arms"))): remote_countries.append(country)
	if remote_countries.is_empty(): return
	var component_ids: = PackedInt32Array()
	component_ids.resize(world_owners.size())
	var component_fronts: Dictionary = {}
	var fronts_by_cell: Dictionary = {}
	for fronts: Array in frontline_cells.values():
		for front: Dictionary in fronts: fronts_by_cell[int(front["index"])] = front
	var component_id: = 0
	var queue: = PackedInt32Array()
	for country: int in remote_countries:
		var side: = int(country_to_side[country])
		var reachable_components: = {}
		for start: int in country_cells.get(country, PackedInt32Array()):
			if component_ids[start] == 0:
				component_id += 1
				var fronts: Array[Dictionary] = []
				queue.resize(0)
				queue.append(start)
				component_ids[start] = component_id
				var cursor: = 0
				while cursor < queue.size():
					var cell: = queue[cursor]
					cursor += 1
					if fronts_by_cell.has(cell): fronts.append(fronts_by_cell[cell])
					var x: = cell % grid_size.x
					for direction: int in range(4):
						var neighbor: = cell
						match direction:
							0: neighbor = cell - x + posmod(x - 1, grid_size.x)
							1: neighbor = cell - x + posmod(x + 1, grid_size.x)
							2: neighbor = cell - grid_size.x
							3: neighbor = cell + grid_size.x
						if neighbor < 0 or neighbor >= component_ids.size() or component_ids[neighbor] != 0 or land_mask[neighbor] != 2: continue
						var friendly: = occupation[neighbor] > 0.5 if side == 0 else occupation[neighbor] < -0.5
						if not friendly: continue
						component_ids[neighbor] = component_id
						queue.append(neighbor)
				component_fronts[component_id] = fronts
			reachable_components[component_ids[start]] = true
		var staging: Array[Dictionary] = []
		for reachable: int in reachable_components: staging.append_array(component_fronts[reachable])
		staging.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return a["index"] < b["index"])
		if not staging.is_empty(): _initial_staging_fronts[country] = staging


static func source_formation_count(land_cells: int, density: float) -> int:
	var size_factor: = maxf(1.0, float(land_cells) / 1500.0)
	var desired: = maxi(3, int(floor(land_cells * UNIT_DENSITY_FACTOR / pow(size_factor, 0.65) * density)))
	return mini(desired, maxi(3, int(round(PER_COUNTRY_SPAWN_CAP * density))))


func _spawn_initial_bases() -> void :
	bases.clear()
	for side_index: int in range(2):
		var side_cells: = PackedInt32Array()
		for country_id: int in sides[side_index]:
			side_cells.append_array(country_cells.get(country_id, PackedInt32Array()))
		if side_cells.is_empty():
			continue
		var base_count: = mini(8, maxi(2, int(floor(float(side_cells.size()) / 500.0))))
		for base_number: int in range(base_count):
			var index: = side_cells[_rng.randi_range(0, side_cells.size() - 1)]
			var geographic: = geo_for_grid_index(index)
			bases.append({
				"sovereign_id": world_owners[index], 
				"longitude": geographic.x, 
				"latitude": geographic.y, 
				"side_index": side_index, 
				"team": "A" if side_index == 0 else "B", 
			})


func _initialize_personnel() -> void :
	country_soldiers_per_unit.clear()
	country_initial_personnel.clear()
	side_casualties.resize(2)
	side_casualties.fill(0)
	side_personnel.resize(2)
	side_initial_personnel.resize(2)
	_casualty_exact.fill(0.0)
	for side_index: int in range(2):
		var personnel: = int(round(source_launch_counts[side_index] * UNIT_TO_SOLDIER_RATIO))
		var manual: PackedInt64Array = launch_options.get("manual_manpower", PackedInt64Array([0, 0]))
		if manual[side_index] > 0:
			personnel = manual[side_index]
		side_soldiers_per_unit[side_index] = float(personnel) / float(maxi(1, unit_count_for_side(side_index)))
		side_personnel[side_index] = personnel
		side_initial_personnel[side_index] = personnel
		var remaining: = personnel
		for country_id: int in sides[side_index]:
			var source_count: = int(formation_launch_counts.get(country_id, {}).get("manpower_baseline", 0))
			var pool: = int(round(float(personnel) * source_count / maxi(1, source_launch_counts[side_index])))
			pool = remaining if country_id == sides[side_index][-1] else mini(pool, remaining)
			remaining -= pool
			var count: = 0
			for unit: Dictionary in units:
				if int(unit.sovereign_id) == country_id: count += 1
			country_initial_personnel[country_id] = pool
			country_soldiers_per_unit[country_id] = float(pool) / maxi(1, count)
	for unit: Dictionary in units:
		unit["personnel_per_unit"] = country_soldiers_per_unit.get(int(unit.sovereign_id), side_soldiers_per_unit[int(unit.side_index)])


func unit_personnel(unit: Dictionary) -> float:
	return maxf(0.0, float(unit.health)) / UNIT_HEALTH * float(unit.get("personnel_per_unit", side_soldiers_per_unit[int(unit.side_index)]))


func _spawn_unit(side_index: int, country_id: int, _prefer_enemy_front: bool, initial_deployment: bool = false, slot_number: int = 0, desired_count: int = 1) -> bool:
	if unit_count_for_side(side_index) >= MAX_UNITS_PER_SIDE:
		return false
	var cells: PackedInt32Array = country_cells.get(country_id, PackedInt32Array())
	var fronts: Array = []
	var reinforcement_source: Dictionary = {}
	if initial_deployment:
		fronts = _initial_staging_fronts.get(country_id, frontline_cells.get(country_id, []))
	else:
		reinforcement_source = _select_reinforcement_city(country_id, side_index)
		if reinforcement_source.is_empty():
			return false
	if cells.is_empty():
		return false
	var selected_index: int
	var push_lon: = 0.0
	var push_lat: = 0.0
	var from_front: = initial_deployment and not fronts.is_empty()
	if from_front:
		var slot: int
		if initial_deployment:

			slot = int(floor(float(slot_number) * fronts.size() / desired_count)) if desired_count < fronts.size() else slot_number % fronts.size()
		else:
			_refresh_front_coverage()
			slot = _weakest_front_slot(fronts, side_index)
		var front: Dictionary = fronts[slot]
		selected_index = int(front["index"])
		push_lon = float(front["push_lon"])
		push_lat = float(front["push_lat"])
	elif initial_deployment:
		selected_index = cells[_rng.randi_range(0, cells.size() - 1)]
	else:
		selected_index = int(reinforcement_source["cell"])
	var geographic: Vector2 = reinforcement_source.get("geo", geo_for_grid_index(selected_index))
	var jitter_range: = GRID_RESOLUTION * (0.4 if initial_deployment else 0.8)
	var pushback: = GRID_RESOLUTION * (0.4 if initial_deployment else 0.35) if from_front else 0.0


	var longitude: = geographic.x - GRID_RESOLUTION * 0.5 + _rng.randf_range(-0.5, 0.5) * jitter_range + push_lon * pushback if initial_deployment else geographic.x
	var latitude: = geographic.y - GRID_RESOLUTION * 0.5 + _rng.randf_range(-0.5, 0.5) * jitter_range + push_lat * pushback if initial_deployment else geographic.y
	var final_index: = grid_index_for_geo(longitude, latitude)
	var legal_control: = final_index >= 0 and (occupation[final_index] > RECRUITMENT_CONTROL_THRESHOLD if side_index == 0 else occupation[final_index] < - RECRUITMENT_CONTROL_THRESHOLD)
	var allied_staging: = initial_deployment and _initial_staging_fronts.has(country_id)
	var legal_owner: = final_index >= 0 and (int(country_to_side.get(world_owners[final_index], -1)) == side_index if allied_staging else world_owners[final_index] == country_id)
	if not legal_owner or (( not initial_deployment or allied_staging) and not legal_control):
		longitude = geographic.x
		latitude = geographic.y
	var assigned_sector: = int(reinforcement_source.get("front_cell", selected_index if from_front else -1))
	var initial_row: = int(slot_number / float(maxi(1, fronts.size()))) % 3
	var initial_lane: = int(slot_number / float(maxi(1, fronts.size() * 3)))
	var support_row: = not initial_deployment or initial_row > 0
	var route: PackedInt32Array = reinforcement_source.get("route", PackedInt32Array())
	var formation_personnel: = float(country_soldiers_per_unit.get(country_id, side_soldiers_per_unit[side_index]))
	if not initial_deployment:


		formation_personnel = float(roundi(formation_personnel))
	units.append({
		"id": _next_unit_id, 
		"tactical_phase": _rng.randf(), 
		"longitude": longitude, 
		"latitude": latitude, 
		"team": "A" if side_index % 2 == 0 else "B", 
		"side_index": side_index, 
		"sovereign_id": country_id, 
		"beneficiary_id": country_id, 
		"health": UNIT_HEALTH, 
		"formation_weight": float(formation_launch_counts.get(country_id, {}).get("pressure_weight", 1.0)), 
		"personnel_per_unit": formation_personnel, 
		"deploy_ticks": DEPLOYMENT_TICKS, 
		"last_combat_tick": -1000, 
		"victory_boost_ticks": 0, 
		"encircled": false, 
		"damage_taken_multiplier": 1.0, 
		"last_ally_count": 1, 
		"target_search_cooldown": 0, 
		"mop_up_target_index": -1, 
		"last_mop_up_country_id": -1, 
		"direction": Vector2.ZERO, 
		"velocity": Vector2.ZERO, 
		"heading": Vector2.ZERO, 
		"front_sector": assigned_sector, 
		"formation_row": "support" if support_row else "forward", 
		"formation_slot_id": "%s:%d" % ["S" if support_row else "F", assigned_sector], 
		"reserved_slot": "%d:%d:%d:%d" % [side_index, assigned_sector, initial_row, initial_lane] if initial_deployment and from_front else "", 
		"formation_assignment_tick": 0 if initial_deployment else sim_tick_count, 
		"reinforcement_city_id": int(reinforcement_source.get("id", -1)), 
		"reinforcement_route": route, 
		"reinforcement_route_cursor": 0, 
		"reinforcement_destination": assigned_sector, 
		"deployment_transit": not initial_deployment and not route.is_empty(), 
		"route_revision": _control_revision, 
		"allied_staged": allied_staging, 
	})
	_next_unit_id += 1
	if not initial_deployment:
		city_deployment.committed(country_id, int(reinforcement_source.id), assigned_sector)
		city_muster.begin(self, units[-1], reinforcement_source)
	_coverage_tick = -1
	return true


func _coverage_key(geo: Vector2) -> Vector2i:
	return Vector2i(int(floor(fposmod(geo.x + 180.0, 360.0) / FRONT_COVERAGE_RADIUS)), int(floor((geo.y + 90.0) / FRONT_COVERAGE_RADIUS)))


func _front_weight(index: int, side_index: int, presence_only: bool = false) -> float:
	var geo: = geo_for_grid_index(index)
	var key: = _coverage_key(geo)
	var weight: = 0.0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for unit_index: int in _coverage_hash.get(Vector2i(posmod(key.x + dx, 1200), key.y + dy), []):
				if unit_index >= units.size():
					continue
				var unit: Dictionary = units[unit_index]
				if float(unit["health"]) > 0.0 and not city_muster.inactive(unit) and int(unit["side_index"]) == side_index and _wrapped_geo_delta(geo, Vector2(unit["longitude"], unit["latitude"])).length_squared() <= FRONT_COVERAGE_RADIUS * FRONT_COVERAGE_RADIUS:
					weight += float(unit["health"]) / UNIT_HEALTH
					if presence_only: return weight
	return weight


func _refresh_front_coverage(force: bool = false) -> void :
	if not force and _coverage_tick >= 0 and sim_tick_count - _coverage_tick < FRONT_COVERAGE_TICKS:
		return
	_coverage_tick = sim_tick_count
	_coverage_hash.clear()
	for unit_index: int in range(units.size()):
		var unit: Dictionary = units[unit_index]
		if float(unit["health"]) <= 0.0:
			continue
		var key: = _coverage_key(Vector2(unit["longitude"], unit["latitude"]))
		if not _coverage_hash.has(key):
			_coverage_hash[key] = []
		(_coverage_hash[key] as Array).append(unit_index)
	if native_conflict_enabled and _native_conflict_core != null and _native_conflict_core.has_method("build_spacing_coverage_index"):
		_native_conflict_core.build_spacing_coverage_index(_coverage_hash)
	for country_id: int in country_to_side:
		var side_index: int = country_to_side[country_id]
		var covered: = 0
		var fronts: Array = frontline_cells.get(country_id, [])
		for front: Dictionary in fronts:
			if _front_weight(int(front["index"]), side_index, true) > 0.0:
				covered += 1
		front_coverage[country_id] = {"samples": fronts.size(), "covered": covered, "ratio": float(covered) / fronts.size() if not fronts.is_empty() else 1.0}


func _assign_uncovered_front_sectors() -> void :

	var assigned: Dictionary = {}
	var sectors: Array = _active_front_cells.keys()
	sectors.sort()
	for index: int in sectors:
		var side_index: = 0 if occupation[index] > 0.0 else 1
		if _front_weight(index, side_index, true) > 0.0:
			continue
		var geo: = geo_for_grid_index(index)
		var key: = _coverage_key(geo)
		var best: = -1
		var best_distance: = 0.9 * 0.9
		for dy: int in range(-3, 4):
			for dx: int in range(-3, 4):
				for candidate: int in _coverage_hash.get(Vector2i(posmod(key.x + dx, 1200), key.y + dy), []):
					if candidate >= units.size() or assigned.has(candidate):
						continue
					var unit: Dictionary = units[candidate]
					if city_muster.owns_assignment(unit): continue
					if int(unit["side_index"]) != side_index or float(unit["health"]) <= 0.0 or bool(unit.get("encircled", false)) or int(unit.get("deploy_ticks", 0)) > 0 or sim_frame_count - int(unit.get("last_combat_tick", -1000)) < 2 or unit.get("border_retreat", Vector2.ZERO) != Vector2.ZERO:
						continue
					var old_sector: = int(unit.get("front_sector", -1))
					if old_sector >= 0 and _active_front_cells.has(old_sector) and _front_weight(old_sector, side_index) <= 1.0:
						continue
					var distance: = _wrapped_geo_delta(geo, Vector2(unit["longitude"], unit["latitude"])).length_squared()
					if distance < best_distance:
						best_distance = distance
						best = candidate
		if best >= 0:
			units[best]["front_sector"] = index
			units[best]["formation_row"] = "forward"
			units[best]["formation_slot_id"] = "F:%d" % index
			units[best]["formation_assignment_tick"] = sim_tick_count
			assigned[best] = true


func _weakest_front_slot(fronts: Array, side_index: int) -> int:
	var weakest: = INF
	var selected: = 0
	for slot: int in range(fronts.size()):
		var weight: = _front_weight(int(fronts[slot]["index"]), side_index)
		if weight < weakest:
			weakest = weight
			selected = slot
	return selected



func front_coverage_report() -> Dictionary:
	var cached_hash: = _coverage_hash.duplicate()
	var cached_coverage: = front_coverage.duplicate(true)
	var cached_tick: = _coverage_tick
	_refresh_front_coverage(true)
	var active: = [{"samples": 0, "covered": 0}, {"samples": 0, "covered": 0}]
	var uncovered: Dictionary = {}
	for index: int in _active_front_cells:
		var side_index: = 0 if occupation[index] > 0.0 else 1
		if side_index < 0 or _local_frontline_edge_count(index) == 0:
			continue
		active[side_index]["samples"] += 1
		if _front_weight(index, side_index, true) > 0.0:
			active[side_index]["covered"] += 1
		else:
			uncovered[index] = true
	var largest_run: = 0
	var visited: Dictionary = {}
	for index: int in uncovered:
		if visited.has(index):
			continue
		var queue: Array[int] = [index]
		visited[index] = true
		var cursor: = 0
		while cursor < queue.size():
			var cell: = queue[cursor]
			cursor += 1
			for neighbor: int in _cardinal_indices(cell):
				if uncovered.has(neighbor) and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)
		largest_run = maxi(largest_run, queue.size())
	for side: Dictionary in active:
		side["ratio"] = float(side["covered"]) / side["samples"] if int(side["samples"]) > 0 else 1.0
	var report: = {"sovereign": front_coverage.duplicate(true), "active": active, "largest_uncovered_component": largest_run}
	_coverage_hash = cached_hash
	front_coverage = cached_coverage
	_coverage_tick = cached_tick
	return report


func _cardinal_indices(index: int) -> PackedInt32Array:
	var neighbors: = PackedInt32Array([index - index % grid_size.x + posmod(index % grid_size.x - 1, grid_size.x), index - index % grid_size.x + posmod(index % grid_size.x + 1, grid_size.x)])
	if index >= grid_size.x:
		neighbors.append(index - grid_size.x)
	if index + grid_size.x < occupation.size():
		neighbors.append(index + grid_size.x)
	return neighbors


func _recruitment_cells_for_country(country_id: int, side_index: int) -> Dictionary:
	var cached: Dictionary = _spawn_cell_cache.get(country_id, {})
	var cached_tick: = int(cached.get("tick", - SPAWN_CELL_CACHE_TICKS - 1))
	if cached_tick <= sim_frame_count and sim_frame_count - cached_tick < SPAWN_CELL_CACHE_TICKS:
		return cached

	var eligible_cells: = PackedInt32Array()
	var source_cells: PackedInt32Array = country_cells.get(country_id, PackedInt32Array())
	var pole_a: = side_index % 2 == 0
	for index: int in source_cells:
		var control: = occupation[index]
		if (pole_a and control > RECRUITMENT_CONTROL_THRESHOLD) or ( not pole_a and control < - RECRUITMENT_CONTROL_THRESHOLD):
			eligible_cells.append(index)

	var eligible_fronts: Array = []
	var active_indices: Array = _active_front_cells.keys()
	active_indices.sort()
	for index: int in active_indices:
		if world_owners[index] != country_id:
			continue
		var control: = occupation[index]
		if not ((pole_a and control > RECRUITMENT_CONTROL_THRESHOLD) or ( not pole_a and control < - RECRUITMENT_CONTROL_THRESHOLD)):
			continue
		if _local_frontline_edge_count(index) > 0:
			var push: = Vector2.ZERO
			for neighbor: int in _cardinal_indices(index):
				if land_mask[neighbor] == 2 and occupation[index] * occupation[neighbor] < 0.0:
					push -= _wrapped_geo_delta(geo_for_grid_index(index), geo_for_grid_index(neighbor)).normalized()
			eligible_fronts.append({"index": index, "push_lon": push.normalized().x, "push_lat": push.normalized().y})
	if eligible_fronts.is_empty():
		for front: Dictionary in frontline_cells.get(country_id, []):
			var control: = occupation[int(front["index"])]
			if (pole_a and control > RECRUITMENT_CONTROL_THRESHOLD) or ( not pole_a and control < - RECRUITMENT_CONTROL_THRESHOLD):
				eligible_fronts.append(front)

	var recruitment_cache: = {
		"tick": sim_frame_count, 
		"theater": eligible_cells, 
		"fronts": eligible_fronts, 
	}
	_spawn_cell_cache[country_id] = recruitment_cache
	return recruitment_cache


func _eligible_reinforcement_cities(country_id: int, side_index: int) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for city: Dictionary in country_city_records.get(country_id, []):
		var cell: = int(city["cell"])
		if cell < 0 or cell >= land_mask.size() or land_mask[cell] != 2:
			continue
		if effective_owner_at(cell) != country_id:
			continue
		var friendly: = occupation[cell] > RECRUITMENT_CONTROL_THRESHOLD if side_index == 0 else occupation[cell] < - RECRUITMENT_CONTROL_THRESHOLD
		if friendly:
			eligible.append(city)
	eligible.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	return eligible


func _select_reinforcement_city(country_id: int, side_index: int) -> Dictionary:
	var cached: Dictionary = _city_front_route_cache.get(country_id, {})
	if int(cached.get("revision", -1)) != _control_revision:
		cached = {"revision": _control_revision, "cities": city_deployment.build(self, country_id, side_index)}
		_city_front_route_cache[country_id] = cached
	var cities: Array[Dictionary] = cached.get("cities", [] as Array[Dictionary])
	return city_deployment.select(self, country_id, side_index, cities)


func _build_unit_spatial_hash() -> Dictionary:
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	if performance_profile_enabled:
		exclusive_profile.enter(&"contact_index_rebuild")
		exclusive_profile.count(&"contact_index_rebuilds")
	var hash_result: = _build_unit_spatial_hash_impl()
	if performance_profile_enabled: exclusive_profile.leave()
	if performance_profile_enabled:
		_profile_spatial_usec += Time.get_ticks_usec() - started
	return hash_result


func _update_unit_muster(unit_index: int) -> bool:
	var waiting: = city_muster.update(self, unit_index)
	_contact_inactive[unit_index] = int(city_muster.inactive(units[unit_index]))
	return waiting


func _finish_city_transit_handoffs() -> void :
	if _city_transit_actor_indices.is_empty(): return
	var actor_indices: = PackedInt32Array()
	var actor_points: = PackedFloat64Array()
	var actor_flags: = PackedByteArray()
	var candidate_offsets: = PackedInt32Array([0])
	var slot_points: = PackedFloat64Array()
	var slot_rows: = PackedInt32Array()
	var slot_identities: = PackedInt32Array()
	var candidate_slots: Array[Dictionary] = []
	var identities: = {}
	for unit_index: int in _city_transit_actor_indices:
		if unit_index >= units.size(): continue
		var unit: Dictionary = units[unit_index]
		if unit.get("deployment_phase", "") != "TRANSIT": continue
		var destination: = int(unit.get("deployment_assigned_sector", unit.get("reinforcement_destination", -1)))
		var target: = geo_for_grid_index(destination) if destination >= 0 and destination < land_mask.size() else Vector2(INF, INF)
		var origin: = Vector2(float(unit.longitude), float(unit.latitude))
		var side: = int(unit.side_index)
		var healthy: bool = float(unit.health) > 0.0
		var valid_sector: bool = destination >= 0 and _active_front_cells.has(destination) and int(unit.get("front_sector", -1)) == destination and city_deployment.friendly(self, destination, side, unit)
		var normal_role: bool = unit.get("sector_role", "") in ["Hold", "Cover", "Reserve", "Reinforce"]
		actor_indices.append(unit_index)
		for value: float in [origin.x, origin.y, target.x, target.y]: actor_points.append(value)
		actor_flags.append(int(healthy))
		actor_flags.append(int(valid_sector))
		actor_flags.append(int(normal_role))
		if healthy and valid_sector and normal_role and _wrapped_geo_delta(origin, target).length_squared() <= 0.0001 and formation_slots._cached_lanes.size() > side:



			for row: int in range(2):
				for lane: int in range(int(formation_slots._cached_lanes[side])):
					var id: = "%d:%d:%d:%d" % [side, destination, row, lane]
					if not formation_slots.slots.has(id) or formation_slots.reservations.has(id): continue
					var slot: Dictionary = formation_slots.slots[id]
					if not unit_can_enter_cell(unit, int(slot.target_cell)) or not city_deployment.friendly(self, int(slot.target_cell), side, unit): continue
					if not identities.has(id): identities[id] = identities.size()
					candidate_slots.append(slot)
					slot_identities.append(int(identities[id]))
					slot_points.append(float(slot.target.x))
					slot_points.append(float(slot.target.y))
					slot_rows.append(int(slot.row))
		candidate_offsets.append(candidate_slots.size())
	var decisions: PackedInt32Array = city_transit_policy.decide_handoffs(actor_points, actor_flags, candidate_offsets, slot_points, slot_rows, slot_identities)
	if decisions.size() != actor_indices.size():
		push_error("Native city-transit handoff batch failed; keeping recruits in TRANSIT")
		return
	for i: int in range(actor_indices.size()):
		var unit_index: = actor_indices[i]
		var unit: Dictionary = units[unit_index]
		var decision: = decisions[i]
		if decision == -2:
			var failed_target: = int(unit.get("transit_failed_target", -1))
			var destination: = int(unit.get("reinforcement_destination", -1))



			if failed_target != destination or sim_tick_count >= int(unit.get("route_retry_tick", 0)):
				unit["transit_failed_target"] = destination
				unit["route_retry_tick"] = sim_tick_count + 60
				var repaired: PackedInt32Array = city_deployment.reroute(self, unit)
				if not repaired.is_empty():
					unit["reinforcement_route"] = repaired
					unit["reinforcement_route_cursor"] = 0
					unit["deployment_assigned_sector"] = int(unit.reinforcement_destination)
					unit["reinforcement_checked_revision"] = -1
					unit["reinforcement_route_blocked"] = false
					unit["reinforcement_lookahead_tick"] = -1
					unit.erase("transit_failed_target")
		elif decision >= 0:
			unit.erase("transit_failed_target")
			var slot: Dictionary = candidate_slots[decision]
			var id: String = slot.id
			if formation_slots.reservations.has(id): continue
			formation_slots.reservations[id] = unit_index
			unit["reserved_slot"] = id
			unit["formation_slot_id"] = id
			unit["front_sector"] = int(slot.cell)
			unit["formation_row"] = ["forward", "support", "operational"][int(slot.row)]
			unit["formation_target"] = slot.target
			unit["formation_normal"] = slot.normal
			unit["formation_tangent"] = slot.tangent
			unit["sector_role"] = "Reinforce"
			unit["sector_destination"] = slot.target
			unit["sector_slot"] = id
			unit["formation_assignment_tick"] = sim_tick_count
			unit["deployment_transit"] = false
			unit["deployment_phase"] = "ACTIVE"
			unit["departure_exit_pending"] = false
			city_muster.release_exit(unit)
		else:
			unit.erase("transit_failed_target")
		units[unit_index] = unit


func _clear_contact_reads() -> void :
	_contact_alive.clear()
	_contact_inactive.clear()
	_contact_weight.clear()


func _contact_unit_moved(unit_index: int, point: Vector2) -> void :
	if native_conflict_enabled and _native_conflict_core != null and _native_conflict_core.has_method("spacing_unit_moved"):
		_native_conflict_core.spacing_unit_moved(unit_index, point)
	if not _contact_index_active:
		return
	if not (native_conflict_enabled and native_contact_lazy_enabled and _native_conflict_core != null and _native_conflict_core.has_method("uses_lazy_contact_index")):
		_contact_index.moved(unit_index, point)
	if native_conflict_enabled and _native_conflict_core != null:
		_native_conflict_core.contact_unit_moved(unit_index, point)


func _build_unit_spatial_hash_impl() -> Dictionary:
	if native_conflict_enabled and _native_conflict_core != null:
		return _native_conflict_core.build_unit_spatial_hash(self)
	_contact_index_active = contact_index_enabled and units.size() >= contact_index_min_units
	unit_spatial_hash.clear()
	_target_bucket_cache.clear()
	_unit_geo_cache.resize(units.size())
	_unit_side_cache.resize(units.size())
	_contact_alive.resize(units.size())
	_contact_inactive.resize(units.size())
	_contact_weight.resize(units.size())
	var coarse_keys: = PackedVector2Array()
	var living: = PackedByteArray()
	if _contact_index_active:
		coarse_keys.resize(units.size())
		living.resize(units.size())
	for unit_index: int in range(units.size()):
		var unit: Dictionary = units[unit_index]
		_unit_side_cache[unit_index] = int(unit.side_index)
		_unit_geo_cache[unit_index] = Vector2(float(unit["longitude"]), float(unit["latitude"]))
		_contact_alive[unit_index] = int(float(unit.get("health", 0.0)) > 0.0)
		_contact_inactive[unit_index] = int(city_muster.inactive(unit))
		_contact_weight[unit_index] = float(unit.get("formation_weight", 1.0))
		if _contact_alive[unit_index] == 0:
			continue
		var key: = _spatial_key(float(unit["longitude"]), float(unit["latitude"]))
		if _contact_index_active:
			coarse_keys[unit_index] = Vector2(key)
			living[unit_index] = 1
		if not unit_spatial_hash.has(key):
			unit_spatial_hash[key] = []
		var bucket: Array = unit_spatial_hash[key]
		bucket.append(unit_index)
	if _contact_index_active: _contact_index.rebuild(_unit_geo_cache, coarse_keys, living)
	return unit_spatial_hash


func _consolidate_unit_stacks(spatial_hash: Dictionary, preserve_reservations: bool = false) -> void :
	var removed: Dictionary = {}
	var merge_distance_sq: = 0.14 * 0.14
	var maximum_health: = UNIT_HEALTH * 5.0
	for unit_index: int in range(units.size()):
		if removed.has(unit_index):
			continue
		var unit: Dictionary = units[unit_index]
		if float(unit.get("health", 0.0)) >= maximum_health or int(unit.get("deploy_ticks", 0)) > 0 or city_muster.owns_assignment(unit):
			continue
		var key: = _spatial_key(float(unit["longitude"]), float(unit["latitude"]))
		var bucket: Array = spatial_hash.get(key, [])
		for other_index: int in bucket:
			if other_index <= unit_index or removed.has(other_index) or other_index >= units.size():
				continue
			var other: Dictionary = units[other_index]
			if preserve_reservations and (unit.has("reserved_slot") or other.has("reserved_slot")) and unit.get("reserved_slot", "") != other.get("reserved_slot", ""):
				continue
			if int(unit.get("front_sector", -1)) != int(other.get("front_sector", -1)):
				continue
			if int(other["side_index"]) != int(unit["side_index"]) or int(other["sovereign_id"]) != int(unit["sovereign_id"]) or int(other.get("deploy_ticks", 0)) > 0 or city_muster.owns_assignment(other):
				continue
			var delta: = _wrapped_geo_delta(
				Vector2(float(unit["longitude"]), float(unit["latitude"])), 
				Vector2(float(other["longitude"]), float(other["latitude"]))
			)
			if delta.length_squared() >= merge_distance_sq:
				continue
			var transfer: = minf(maximum_health - float(unit["health"]), float(other["health"]))
			unit["health"] = float(unit["health"]) + transfer
			other["health"] = float(other["health"]) - transfer
			units[unit_index] = unit
			units[other_index] = other
			if float(other["health"]) <= 0.0:
				removed[other_index] = true
			if float(unit["health"]) >= maximum_health:
				break
	if removed.is_empty():
		return
	var consolidated: Array[Dictionary] = []
	for unit_index: int in range(units.size()):
		if not removed.has(unit_index):
			consolidated.append(units[unit_index])
	units = consolidated
	_coverage_tick = -1


func _spatial_key(longitude: float, latitude: float) -> Vector2i:
	return Vector2i(
		int(floor((fposmod(longitude + 180.0, 360.0)) / HASH_CELL_SIZE)), 
		int(floor((latitude + 90.0) / HASH_CELL_SIZE))
	)


func _ordered_target_candidates(origin_key: Vector2i, spatial_hash: Dictionary) -> Array[int]:
	if not _target_bucket_cache.has(origin_key):
		var ordered_candidates: Array[int] = []
		var columns: = int(ceil(360.0 / HASH_CELL_SIZE))
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var key: = Vector2i(posmod(origin_key.x + dx, columns), origin_key.y + dy)
				ordered_candidates.append_array(spatial_hash.get(key, []))
		_target_bucket_cache[origin_key] = ordered_candidates
	return _target_bucket_cache[origin_key]


func _nearest_enemy_unit_index(unit_index: int, spatial_hash: Dictionary) -> int:
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	if performance_profile_enabled: exclusive_profile.enter(&"contact_construction")
	var nearest_index: = _nearest_enemy_unit_index_impl(unit_index, spatial_hash)
	if performance_profile_enabled: exclusive_profile.leave()
	if performance_profile_enabled: _profile_targeting_usec += Time.get_ticks_usec() - started
	return nearest_index


func _nearest_enemy_unit_index_impl(unit_index: int, spatial_hash: Dictionary) -> int:
	if native_conflict_enabled and _contact_index_active and _native_conflict_core != null:
		var native_unit: Dictionary = units[unit_index]
		var native_doctrine: String = country_doctrines.get(int(native_unit.sovereign_id), "Combined Arms")
		var homeland_restricted: = MWBattleDoctrines.homeland_only(native_doctrine)
		return _native_conflict_core.nearest_enemy_contact(self, unit_index, spatial_hash, homeland_restricted)
	var unit: Dictionary = units[unit_index]
	var origin_key: = _spatial_key(float(unit["longitude"]), float(unit["latitude"]))
	var origin_geo: = _unit_geo_cache[unit_index]
	var side_index: = int(unit["side_index"])
	var max_key_x: = int(ceil(360.0 / HASH_CELL_SIZE))
	var best_index: = -1
	var best_distance_sq: = INF
	var ally_count: = 1
	var ally_weight: float = unit.get("formation_weight", 1.0)
	var enemy_count: = 0
	var enemy_delta_sum: = Vector2.ZERO
	var repulsion: Vector2 = unit.get("repulsion", Vector2.ZERO)
	var noise: = sin(float(unit.get("tactical_phase", 0.0)) + sim_frame_count * 0.02) * 0.03
	var target_noise: = Vector2(noise, noise)
	var restricted: = MWBattleDoctrines.homeland_only(country_doctrines.get(int(unit.sovereign_id), "Combined Arms"))





	if performance_profile_enabled: exclusive_profile.enter(&"contact_window_discovery")
	var candidates: Array[int] = _contact_index.ordered_window(origin_geo, origin_key, max_key_x) if _contact_index_active else _ordered_target_candidates(origin_key, spatial_hash)
	if performance_profile_enabled: exclusive_profile.leave()
	var accepted_candidates: = 0
	for candidate_index: int in candidates:
		var delta_geo: = _unit_geo_cache[candidate_index] - origin_geo
		var wrapped: = absf(_unit_geo_cache[candidate_index].x - origin_geo.x) > 180.0
		if delta_geo.x > 180.0: delta_geo.x -= 360.0
		elif delta_geo.x < -180.0: delta_geo.x += 360.0
		var distance_sq: = delta_geo.length_squared()
		if _contact_index_active and distance_sq > _contact_index.RADIUS * _contact_index.RADIUS: continue
		accepted_candidates += 1
		if candidate_index == unit_index or candidate_index >= units.size():
			continue



		if wrapped:
			delta_geo = _wrapped_geo_delta(origin_geo, _unit_geo_cache[candidate_index])
			distance_sq = delta_geo.length_squared()
		var candidate_side: = _unit_side_cache[candidate_index]
		var noisy_distance: = (delta_geo + target_noise).length_squared()


		if distance_sq >= 0.36 and (candidate_side == side_index or noisy_distance >= best_distance_sq): continue
		if _contact_alive[candidate_index] == 0: continue
		if candidate_side == side_index:
			if distance_sq < 0.36:
				if _contact_inactive[candidate_index] != 0: continue
				ally_count += 1
				ally_weight += _contact_weight[candidate_index]


				if distance_sq < 0.0025 and distance_sq > 1e-05:
					repulsion -= delta_geo.normalized() * (1.0 - sqrt(distance_sq) / 0.05)
			continue
		if restricted and not _contact_target_legal(candidate_index, unit):
			continue
		if distance_sq < 0.36:
			enemy_count += 1
			enemy_delta_sum += delta_geo
			if distance_sq < 0.04 and float(unit["health"]) > 0.0:
				var candidate: Dictionary = units[candidate_index]
				if performance_profile_enabled:
					exclusive_profile.enter(&"combat_resolution")
					exclusive_profile.count(&"proximity_pairs")
				_trace_combat("proximity", unit, candidate, sqrt(distance_sq))
				var proximity: = COMBAT_DAMAGE * 0.07 * float(unit.get("damage_dealt_multiplier", 1.0)) * (1.0 - sqrt(distance_sq) / 0.2)
				_trace_combat("proximity_return", candidate, unit, sqrt(distance_sq))


				_record_damage(candidate_index, proximity * float(unit.get("formation_weight", 1.0)), "proximity", int(unit["id"]))
				if _contact_inactive[candidate_index] == 0:
					_record_damage(unit_index, proximity * _contact_weight[candidate_index] * 0.8 * float(unit.get("damage_taken_multiplier", 1.0)), "proximity_return", int(candidate["id"]))
				unit["last_combat_tick"] = sim_frame_count
				candidate["last_combat_tick"] = sim_frame_count
				if float(candidate["health"]) <= 0.0:
					unit["victory_boost_ticks"] = 240
				_record_battle(unit, candidate)
				if performance_profile_enabled: exclusive_profile.leave()
		if _contact_alive[candidate_index] != 0 and noisy_distance < best_distance_sq:
			best_distance_sq = noisy_distance
			best_index = candidate_index
	if performance_profile_enabled:
		exclusive_profile.count(&"contact_window_visits", candidates.size())
		exclusive_profile.count(&"directed_contact_candidates", accepted_candidates)



	var safe_radius: = _contact_index.RADIUS - target_noise.length() - 1e-05
	if _contact_index_active and best_distance_sq >= safe_radius * safe_radius:
		if performance_profile_enabled:
			exclusive_profile.enter(&"contact_nearest_fallback")
			exclusive_profile.count(&"contact_nearest_fallbacks")
		var legal: = _contact_target_legal.bind(unit) if restricted else Callable()
		best_index = _contact_index.nearest_enemy(origin_geo, target_noise, origin_key, max_key_x, side_index, _unit_geo_cache, units, legal)
		if performance_profile_enabled: exclusive_profile.leave()
	unit["last_ally_count"] = ally_count
	unit["last_ally_weight"] = ally_weight
	unit["local_enemy_count"] = enemy_count
	unit["enemy_delta"] = enemy_delta_sum / float(maxi(1, enemy_count))
	unit["repulsion"] = repulsion
	units[unit_index] = unit
	return best_index


func _contact_target_legal(candidate_index: int, unit: Dictionary) -> bool:
	var candidate: Dictionary = units[candidate_index]
	return unit_can_enter_cell(unit, grid_index_for_geo(candidate.longitude, candidate.latitude))


func _garrison_objective(unit: Dictionary, target_index: int, spatial_hash: Dictionary) -> Vector2:
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	if performance_profile_enabled: exclusive_profile.enter(&"garrison_query")
	var objective_geo: = _garrison_objective_impl(unit, target_index, spatial_hash)
	if performance_profile_enabled: exclusive_profile.leave()
	if performance_profile_enabled: _profile_garrison_usec += Time.get_ticks_usec() - started
	return objective_geo


func _garrison_objective_impl(unit: Dictionary, target_index: int, spatial_hash: Dictionary) -> Vector2:
	var sovereign: = int(unit["sovereign_id"])
	var own_geo: = Vector2(float(unit["longitude"]), float(unit["latitude"]))
	var closest: = Vector2(INF, INF)
	var distance: = 0.35 * 0.35
	var city_hash: Dictionary = _country_city_spatial_hash.get(sovereign, {})
	var city_key: = _spatial_key(own_geo.x, own_geo.y)
	var city_columns: = int(ceil(360.0 / HASH_CELL_SIZE))
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for city_geo: Vector2 in city_hash.get(Vector2i(posmod(city_key.x + dx, city_columns), city_key.y + dy), []):
				var d: = _wrapped_geo_delta(own_geo, city_geo).length_squared()
				if d < distance:
					distance = d
					closest = city_geo
	if not is_finite(closest.x):
		unit["is_garrison"] = false
		return closest
	var key: = Vector3(closest.x, closest.y, float(sovereign))
	if not _garrison_cache.has(key):
		var friends: = 0
		var enemy_near: = false
		var center: = _spatial_key(closest.x, closest.y)
		var columns: = int(ceil(360.0 / HASH_CELL_SIZE))
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				for index: int in spatial_hash.get(Vector2i(posmod(center.x + dx, columns), center.y + dy), []):
					var candidate: Dictionary = units[index]
					if float(candidate["health"]) <= 0.0:
						continue
					var d: = _wrapped_geo_delta(closest, Vector2(float(candidate["longitude"]), float(candidate["latitude"]))).length_squared()
					if int(candidate["side_index"]) == int(unit["side_index"]):
						if int(candidate["sovereign_id"]) == sovereign and d < 0.25 * 0.25:
							friends += 1
					elif d < 0.55 * 0.55:
						enemy_near = true
		_garrison_cache[key] = {"friends": friends, "enemy_near": enemy_near}
	var evaluation: Dictionary = _garrison_cache[key]
	unit["is_garrison"] = int(evaluation["friends"]) <= 5 or bool(evaluation["enemy_near"])
	if not bool(unit["is_garrison"]):
		return Vector2(INF, INF)
	if bool(evaluation["enemy_near"]) and target_index >= 0:
		var target: Dictionary = units[target_index]
		return closest + _wrapped_geo_delta(closest, Vector2(float(target["longitude"]), float(target["latitude"]))) * 0.5
	return closest


func _border_direction(unit: Dictionary, current_index: int) -> Vector2:
	if int(unit.get("border_index", -2)) == current_index and sim_frame_count - int(unit.get("border_tick", -100)) < 10:
		return unit.get("border_direction", Vector2.ZERO)
	var own_geo: = Vector2(float(unit["longitude"]), float(unit["latitude"]))
	var best: = Vector2.ZERO
	var best_distance: = INF
	var cx: = current_index % grid_size.x
	var cy: = int(float(current_index) / float(grid_size.x))
	for radius: int in range(1, 13):
		for dy: int in range( - radius, radius + 1):
			var y: = cy + dy
			if y < 0 or y >= grid_size.y:
				continue
			for dx: int in range( - radius, radius + 1):


				if absi(dx) < radius and absi(dy) < radius:
					continue
				var index: = y * grid_size.x + posmod(cx + dx, grid_size.x)
				if land_mask[index] != 2 or absf(occupation[index]) > 0.25:
					continue
				var delta: = _wrapped_geo_delta(own_geo, geo_for_grid_index(index) - Vector2.ONE * GRID_RESOLUTION * 0.5)
				if delta.length_squared() < best_distance:
					best_distance = delta.length_squared()
					best = delta.normalized()
		if best_distance < INF:
			break
	unit["border_index"] = current_index
	unit["border_tick"] = sim_frame_count
	unit["border_direction"] = best
	return best


func _build_side_centroids() -> Dictionary:
	var sums: = [Vector2.ZERO, Vector2.ZERO]
	var counts: = [0, 0]
	for unit: Dictionary in units:
		if float(unit.get("health", 0.0)) <= 0.0:
			continue
		var side_index: int = int(unit["side_index"])
		sums[side_index] += Vector2(float(unit["longitude"]), float(unit["latitude"]))
		counts[side_index] += 1
	var centroids: Dictionary = {}
	for side_index: int in range(2):
		if counts[side_index] > 0:
			centroids[side_index] = sums[side_index] / float(counts[side_index])
	return centroids


func _build_force_counts() -> Dictionary:
	var side_counts: = PackedInt32Array([0, 0])
	var country_counts: Dictionary = {}
	for country_id: int in country_cells:
		country_counts[country_id] = 0
	for unit: Dictionary in units:
		if float(unit.get("health", 0.0)) <= 0.0:
			continue
		var side_index: = int(unit.get("side_index", -1))
		if side_index >= 0 and side_index < side_counts.size():
			side_counts[side_index] += 1
		var sovereign_id: = int(unit.get("sovereign_id", 0))
		if country_counts.has(sovereign_id):
			country_counts[sovereign_id] = int(country_counts[sovereign_id]) + 1
	return {"sides": side_counts, "countries": country_counts}


func _mop_up_objective_for_unit(unit_index: int, country_unit_counts: Dictionary) -> Vector2:
	if unit_index < 0 or unit_index >= units.size():
		return Vector2(INF, INF)
	var unit: Dictionary = units[unit_index]
	var side_index: = int(unit["side_index"])
	var enemy_side: = 1 - side_index
	var possible_countries: Array[int] = []
	for country_id: int in sides[enemy_side]:
		if int(_country_controlled_cells.get(country_id, 0)) > 0 and int(country_unit_counts.get(country_id, 0)) == 0:
			possible_countries.append(country_id)
	if possible_countries.is_empty():
		for country_id: int in sides[enemy_side]:
			if int(_country_controlled_cells.get(country_id, 0)) > 0:
				possible_countries.append(country_id)
	if possible_countries.is_empty():
		return Vector2(INF, INF)

	var cooldown: = maxi(0, int(unit.get("target_search_cooldown", 0)) - 1)
	unit["target_search_cooldown"] = cooldown
	var cached_index: = int(unit.get("mop_up_target_index", -1))
	var cached_country: = int(unit.get("last_mop_up_country_id", -1))
	var cached_valid: = cached_index >= 0 and cached_index < occupation.size() and possible_countries.has(cached_country)
	if cached_valid:
		var cached_control: = occupation[cached_index]
		cached_valid = cached_control < 0.85 if side_index == 0 else cached_control > -0.85
	if cooldown > 0 and cached_valid:
		units[unit_index] = unit
		return geo_for_grid_index(cached_index)

	var target_country: = possible_countries[_rng.randi_range(0, possible_countries.size() - 1)]
	var target_cells: PackedInt32Array = country_cells.get(target_country, PackedInt32Array())
	if target_cells.is_empty():
		units[unit_index] = unit
		return Vector2(INF, INF)

	var best_index: = -1
	var best_score: = - INF
	var own_geo: = Vector2(float(unit["longitude"]), float(unit["latitude"]))
	var sample_count: = mini(MOP_UP_SAMPLE_COUNT, target_cells.size())
	for sample_number: int in range(sample_count):
		var candidate_index: = target_cells[_rng.randi_range(0, target_cells.size() - 1)]
		var control: = occupation[candidate_index]
		if (side_index == 0 and control >= 0.85) or (side_index == 1 and control <= -0.85):
			continue
		var candidate_geo: = geo_for_grid_index(candidate_index)
		var distance_sq: = _wrapped_geo_delta(own_geo, candidate_geo).length_squared()
		var occupation_favor: = (1.0 - absf(control)) * 120.0
		var score: = occupation_favor - distance_sq * 0.4
		if candidate_geo.y > 65.0:
			score -= 800.0
		if candidate_geo.y > 35.0 and candidate_geo.y < 60.0 and candidate_geo.x > -10.0 and candidate_geo.x < 40.0:
			score += 200.0
		if score > best_score:
			best_score = score
			best_index = candidate_index
	if best_index < 0:
		best_index = target_cells[_rng.randi_range(0, target_cells.size() - 1)]

	unit["target_search_cooldown"] = _rng.randi_range(15, 34)
	unit["mop_up_target_index"] = best_index
	unit["last_mop_up_country_id"] = target_country
	units[unit_index] = unit
	return geo_for_grid_index(best_index)


func _update_frontline_coordination(force_counts: Dictionary, initial: bool = false) -> void :
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	if performance_profile_enabled: exclusive_profile.enter(&"front_slot_maintenance")
	_update_frontline_coordination_impl(force_counts, initial)
	if performance_profile_enabled: exclusive_profile.leave()
	if performance_profile_enabled:
		_profile_front_usec += Time.get_ticks_usec() - started


func _update_frontline_coordination_impl(force_counts: Dictionary, initial: bool = false) -> void :
	if performance_profile_enabled: exclusive_profile.enter(&"front_coverage_refresh")
	_refresh_front_coverage(initial)
	if performance_profile_enabled: exclusive_profile.leave()
	if performance_profile_enabled: exclusive_profile.enter(&"front_slot_update")
	formation_slots.update(self, initial)
	if performance_profile_enabled: exclusive_profile.leave()
	var country_counts: Dictionary = force_counts["countries"]
	var side_counts: PackedInt32Array = force_counts["sides"]
	var winners: = PackedInt32Array([0, 0])
	for unit: Dictionary in units:
		if float(unit["health"]) > 0.0 and int(unit.get("victory_boost_ticks", 0)) > 0:
			winners[int(unit["side_index"])] += 1
	var count_interval: = maxi(15, int(floor(15.0 * current_speed())))
	for side_index: int in range(2):
		side_victory_ratios[side_index] = float(winners[side_index]) / float(side_counts[side_index]) if side_counts[side_index] > 0 else 0.0
	for country_id: int in country_to_side:
		var tactical: Dictionary = country_frontline_state.get(country_id, {"saturated": false, "surging": false})
		var count: = int(country_counts.get(country_id, 0))


		var fronts: Array = frontline_cells.get(country_id, [])
		tactical["frontline_cells"] = fronts.size()
		tactical["units"] = count
		if initial or sim_frame_count % count_interval == 0:
			var covered: = int(front_coverage.get(country_id, {}).get("covered", 0))
			tactical["covered_sectors"] = covered
			if covered >= fronts.size():
				tactical["saturated"] = true
			elif covered < float(fronts.size()) * 0.85:
				tactical["saturated"] = false
		var ratio: = side_victory_ratios[int(country_to_side[country_id])]
		tactical["victory_ratio"] = ratio
		if not bool(tactical["surging"]) and ratio > 0.6 and bool(tactical["saturated"]):
			tactical["surging"] = true
		elif bool(tactical["surging"]) and ratio < 0.35:
			tactical["surging"] = false
		if not bool(tactical["saturated"]):
			tactical["surging"] = false
		country_frontline_state[country_id] = tactical


func frontline_push_readiness(unit: Dictionary, effectively_friendly: bool, too_near_border: bool, retreating: bool) -> float:
	if effectively_friendly or too_near_border or retreating:
		return 1.0
	var tactical: Dictionary = country_frontline_state.get(int(unit["sovereign_id"]), {})
	var weariness: = minf(0.85, float(sim_frame_count) / 15000.0)
	var readiness: = 0.7 * (1.0 - weariness)
	if bool(tactical.get("surging", false)):
		var spearhead: = 0.85 + (sin(float(unit.get("tactical_phase", 0.0)) * 777.0) * 0.5 + 0.5) * 0.3
		readiness = 4.2 * minf(1.8, side_victory_ratios[int(unit["side_index"])] * 2.5) * spearhead * (1.0 - weariness * 0.5)
		if int(unit.get("victory_boost_ticks", 0)) > 0:
			readiness *= 1.4
	if int(unit.get("last_ally_count", 1)) < 3:
		readiness = 0.0
	if not bool(tactical.get("saturated", false)):
		readiness = 0.3
	return readiness


func _formation_support_cell(front_cell: int, unit: Dictionary) -> int:
	if front_cell < 0 or front_cell >= occupation.size():
		return front_cell
	var side_index: = int(unit["side_index"])
	var front_geo: = geo_for_grid_index(front_cell)
	var enemy_direction: = Vector2.ZERO
	for neighbor: int in _cardinal_indices(front_cell):
		if land_mask[neighbor] == 2 and occupation[front_cell] * occupation[neighbor] < 0.0:
			enemy_direction += _wrapped_geo_delta(front_geo, geo_for_grid_index(neighbor)).normalized()
	if enemy_direction == Vector2.ZERO:
		return front_cell
	var inward: = - enemy_direction.normalized()
	var best: = front_cell
	var best_score: = - INF
	for neighbor: int in _cardinal_indices(front_cell):
		if land_mask[neighbor] != 2 or not unit_can_enter_cell(unit, neighbor):
			continue
		var friendly: = occupation[neighbor] > 0.0 if side_index == 0 else occupation[neighbor] < 0.0
		if not friendly:
			continue
		var score: = _wrapped_geo_delta(front_geo, geo_for_grid_index(neighbor)).normalized().dot(inward)
		if score > best_score:
			best_score = score
			best = neighbor
	return best


func _formation_target_cell(unit: Dictionary) -> int:
	if unit.has("formation_target"):
		var target: Vector2 = unit.formation_target
		return grid_index_for_geo(target.x, target.y)
	var front_cell: = int(unit.get("front_sector", -1))
	if String(unit.get("formation_row", "forward")) == "support":
		return _formation_support_cell(front_cell, unit)
	return front_cell


func _stabilize_formation_rows() -> void :
	for unit_index: int in range(units.size()):
		var unit: Dictionary = units[unit_index]
		var sector: = int(unit.get("front_sector", -1))
		if sector < 0:
			continue
		if not unit.has("formation_row"):
			unit["formation_row"] = "support" if int(unit["id"]) % SUPPORT_ROW_PERIOD == 0 else "forward"
			unit["formation_assignment_tick"] = sim_tick_count
		var row: = String(unit["formation_row"])
		if row == "support" and _formation_support_cell(sector, unit) == sector:
			row = "forward"
			unit["formation_row"] = row
			unit["formation_assignment_tick"] = sim_tick_count
		unit["formation_slot_id"] = "%s:%d" % ["S" if row == "support" else "F", sector]
		units[unit_index] = unit


func _frontline_border_safety(unit_index: int) -> Vector2:


	var unit: Dictionary = units[unit_index]
	var cell: = grid_index_for_geo(unit["longitude"], unit["latitude"])
	var side_index: = int(unit["side_index"])
	if cell < 0 or land_mask[cell] != 2 or int(country_to_side.get(world_owners[cell], -1)) != side_index:
		return Vector2.ZERO
	var control: = occupation[cell]
	if (side_index == 0 and control >= 0.06) or (side_index == 1 and control <= -0.06):
		return Vector2.ZERO
	_record_damage(unit_index, COMBAT_DAMAGE * 0.15 * (1.0 + absf(control) * 2.0) * float(unit.get("damage_taken_multiplier", 1.0)), "border_skirmish")
	var best_score: = - INF if side_index == 0 else INF
	var best: = Vector2.ZERO
	for offset: Vector2 in [Vector2(0, 0.6), Vector2(0, -0.6), Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(0.42, 0.42), Vector2(-0.42, -0.42), Vector2(0.42, -0.42), Vector2(-0.42, 0.42)]:
		var sample: = grid_index_for_geo(float(unit["longitude"]) + offset.x, float(unit["latitude"]) + offset.y)
		var score: = occupation[sample] if sample >= 0 else 0.0
		if sample < 0 or land_mask[sample] == 0:
			score = -999.0 if side_index == 0 else 999.0
		elif land_mask[sample] != 2:
			score = -2500.0 if side_index == 0 else 2500.0
		elif int(country_to_side.get(world_owners[sample], -1)) != side_index:
			score = -800.0 if side_index == 0 else 800.0
		if (side_index == 0 and score > best_score) or (side_index == 1 and score < best_score):
			best_score = score
			best = offset
	return best.normalized() * 6.0


func _move_garrison_unit(unit_index: int, delta: Vector2) -> void :
	var unit: Dictionary = units[unit_index]
	if performance_profile_enabled: exclusive_profile.enter(&"movement_intent")
	var intent: = MOVEMENT_INTENT.resolve(self, unit, delta.normalized())
	if performance_profile_enabled: exclusive_profile.leave()



	var owns_movement: bool = intent.kind in [MOVEMENT_INTENT.Kind.SAFETY, MOVEMENT_INTENT.Kind.DEPLOYMENT, MOVEMENT_INTENT.Kind.SECTOR, MOVEMENT_INTENT.Kind.ADVANCE]
	if owns_movement or not direct_combat_permitted(delta.length(), int(unit.get("last_combat_tick", -1000))):
		_move_unit_toward(unit_index, delta.normalized(), intent)


func _move_unit_toward(unit_index: int, direction: Vector2, resolved_intent: Dictionary = {}) -> void :
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	if performance_profile_enabled: exclusive_profile.enter(&"movement_steering")
	_move_unit_toward_impl(unit_index, direction, resolved_intent)
	if performance_profile_enabled: exclusive_profile.leave()
	if performance_profile_enabled:
		_profile_movement_usec += Time.get_ticks_usec() - started


func _move_unit_toward_impl(unit_index: int, direction: Vector2, resolved_intent: Dictionary = {}) -> void :
	if unit_index < 0 or unit_index >= units.size() or not direction.is_finite():
		return
	var unit: Dictionary = units[unit_index]
	var current_geo: = Vector2(unit.longitude, unit.latitude)
	if performance_profile_enabled: exclusive_profile.enter(&"movement_intent")
	var intent: = MOVEMENT_INTENT.resolve(self, unit, direction) if resolved_intent.is_empty() else resolved_intent
	if performance_profile_enabled: exclusive_profile.leave()
	direction = intent.direction
	var retreating: bool = intent.kind == MOVEMENT_INTENT.Kind.SAFETY
	var route_forced: bool = intent.kind == MOVEMENT_INTENT.Kind.DEPLOYMENT
	var sector_forced: bool = intent.kind in [MOVEMENT_INTENT.Kind.SECTOR, MOVEMENT_INTENT.Kind.ADVANCE]
	var route_target: Vector2 = intent.target
	var sector_target: Vector2 = intent.target
	var formation_distance: = _wrapped_geo_delta(current_geo, sector_target).length() if sector_forced else INF
	var current_index: = grid_index_for_geo(float(unit.longitude), float(unit.latitude))
	var current_control: = occupation[current_index] if current_index >= 0 else 0.0
	var side_index: = int(unit.side_index)
	var strongly_friendly: = current_control > 0.5 if side_index == 0 else current_control < -0.5
	var effectively_friendly: = current_control > 0.35 if side_index == 0 else current_control < -0.35
	var sovereign_friendly: = current_index >= 0 and int(country_to_side.get(world_owners[current_index], -1)) == side_index
	var too_near_border: = sovereign_friendly and (current_control < 0.06 if side_index == 0 else current_control > -0.06)
	var land_speed_multiplier: = 1.8 if strongly_friendly else 1.2
	var push_readiness: = frontline_push_readiness(unit, effectively_friendly, too_near_border, retreating)


	unit["repulsion"] = Vector2.ZERO
	var movement_speed: = movement_speed_override if movement_speed_override > 0.0 else UNIT_SPEED
	var target_speed: = movement_speed * land_speed_multiplier * float(unit.get("speed_buff_multiplier", 1.0)) * push_readiness * 0.8
	if route_forced and not retreating:

		target_speed = GRID_RESOLUTION / (60.0 * TRANSIT_CELL_SECONDS) * movement_speed / UNIT_SPEED



	if bool(unit.get("deployment_transit", false)) and route_forced and not retreating:
		target_speed *= REINFORCEMENT_TRANSIT_BOOST
	if retreating:
		target_speed *= 5.5
	if formation_distance < 0.12 and not retreating:
		target_speed *= clampf(formation_distance / 0.08, 0.0, 1.0)
	target_speed *= encircled_retreat_efficiency(unit)
	var prior_heading: Vector2 = unit.get("heading", Vector2.ZERO)
	var desired_heading: = _friendly_passing_heading(unit, direction.normalized())
	var heading: = desired_heading
	if prior_heading != Vector2.ZERO and desired_heading != Vector2.ZERO:


		heading = prior_heading.rotated(prior_heading.angle_to(desired_heading) * MOVEMENT_BRAKE_FACTOR).normalized()



	unit["heading"] = heading
	var velocity: Vector2 = unit.get("velocity", Vector2.ZERO)
	var target_velocity: = heading * target_speed
	var acceleration: = DEPLOYMENT_ACCELERATION if bool(unit.get("deployment_transit", false)) and route_forced else maxf(movement_speed * 0.08, target_speed * MOVEMENT_ACCELERATION_FACTOR)
	velocity = velocity.move_toward(target_velocity, acceleration)
	var move: = velocity
	if route_forced:
		var remaining: = _wrapped_geo_delta(current_geo, route_target).length()
		move = move.limit_length(remaining)
	elif sector_forced and not retreating:
		move = move.limit_length(formation_distance)
	move = _spacing_limited_displacement(unit_index, move)
	var next_longitude: = fposmod(float(unit["longitude"]) + move.x + 180.0, 360.0) - 180.0
	var next_latitude: = clampf(float(unit["latitude"]) + move.y, -89.9, 89.9)
	var next_index: = grid_index_for_geo(next_longitude, next_latitude)
	if next_index < 0 or next_index >= land_mask.size() or land_mask[next_index] != 2:

		var lon_only: = grid_index_for_geo(next_longitude, float(unit["latitude"]))
		var lat_only: = grid_index_for_geo(float(unit["longitude"]), next_latitude)
		if lon_only >= 0 and land_mask[lon_only] == 2:
			next_latitude = float(unit["latitude"])
		elif lat_only >= 0 and land_mask[lat_only] == 2:
			next_longitude = float(unit["longitude"])
		else:
			unit["velocity"] = Vector2.ZERO
			units[unit_index] = unit
			return
	var prior_geo: = PackedFloat64Array([unit["longitude"], unit["latitude"]])
	var legal_geo: = _swept_land_destination(unit, next_longitude, next_latitude)
	if (route_forced or sector_forced) and not retreating and grid_index_for_geo(legal_geo[0], legal_geo[1]) != current_index:
		legal_geo = MOVEMENT_CORRIDOR.clipped_precise(unit.longitude, unit.latitude, legal_geo[0], legal_geo[1], grid_size, _sector_step_legal.bind(unit, current_index, sector_forced and not route_forced))
	if legal_geo == prior_geo:
		unit["velocity"] = Vector2.ZERO
		units[unit_index] = unit
		return
	next_longitude = legal_geo[0]
	next_latitude = legal_geo[1]
	unit["longitude"] = next_longitude
	unit["latitude"] = next_latitude
	unit["velocity"] = _wrapped_geo_delta(Vector2(prior_geo[0], prior_geo[1]), Vector2(next_longitude, next_latitude))
	unit["heading"] = move.normalized() if move != Vector2.ZERO else heading
	unit["direction"] = unit["heading"]
	units[unit_index] = unit
	if unit_index < _unit_geo_cache.size():
		_unit_geo_cache[unit_index] = Vector2(next_longitude, next_latitude)
		_contact_unit_moved(unit_index, _unit_geo_cache[unit_index])
	if movement_audit.is_valid():
		movement_audit.call(self, unit, prior_geo, legal_geo, "advance", move)


func _sector_step_legal(cell: int, unit: Dictionary, origin: int, attacking: bool) -> bool:
	if not _movement_land_legal(cell, unit): return false
	if cell == origin or sector_cohesion.friendly(self, cell, int(unit.side_index)): return true
	if not attacking or unit.get("sector_role", "") not in ["Advance", "Exploit"]: return false
	var operation: Dictionary = sector_cohesion.operations.get(int(unit.get("sector_operation", -1)), {})
	return not operation.is_empty() and cell == int(operation.target_cell) and operation.phase == "pushing"


func _apply_deployment_step(index: int, target: Vector2, max_step: float) -> void :
	var unit: Dictionary = units[index]
	var origin: = Vector2(unit.longitude, unit.latitude)
	var step: = _spacing_limited_displacement(index, _wrapped_geo_delta(origin, target).limit_length(max_step))
	var prior: = PackedFloat64Array([unit.longitude, unit.latitude])
	var goal: = origin + step
	var accepted: = MOVEMENT_CORRIDOR.clipped_precise(unit.longitude, unit.latitude, goal.x, goal.y, grid_size, city_muster._legal.bind(self, unit))
	unit.longitude = accepted[0]
	unit.latitude = accepted[1]
	unit.velocity = _wrapped_geo_delta(origin, Vector2(unit.longitude, unit.latitude))
	if unit.velocity != Vector2.ZERO:
		unit.heading = unit.velocity.normalized()
		unit.direction = unit.heading
	if index < _unit_geo_cache.size():
		_unit_geo_cache[index] = Vector2(unit.longitude, unit.latitude)
		_contact_unit_moved(index, _unit_geo_cache[index])
	if movement_audit.is_valid(): movement_audit.call(self, unit, prior, accepted, "city_emergence", step)


func _formation_waypoint(unit: Dictionary, target: Vector2) -> Vector2:
	var origin: = Vector2(unit.longitude, unit.latitude)
	var target_cell: = grid_index_for_geo(target.x, target.y)
	var start: = grid_index_for_geo(origin.x, origin.y)
	if start == target_cell: return target
	var changed: bool = unit.get("formation_route_target", Vector2(INF, INF)) != target
	if changed or sim_tick_count >= int(unit.get("formation_route_refresh", -1)):
		unit["formation_route_refresh"] = sim_tick_count + 24 + int(unit.id) % 7
		unit["formation_route_target"] = target
		var clipped: = MOVEMENT_CORRIDOR.clipped_precise(unit.longitude, unit.latitude, target.x, target.y, grid_size, _sector_step_legal.bind(unit, start, false))
		unit["formation_route_direct"] = absf(clipped[0] - target.x) < 1e-06 and absf(clipped[1] - target.y) < 1e-06
		if not bool(unit.formation_route_direct):
			if performance_profile_enabled: exclusive_profile.count(&"formation_bfs_calls")


			var parents: = {start: -1}
			var queue: Array[int] = [start]
			var cursor: = 0
			while cursor < queue.size() and cursor < 512 and not parents.has(target_cell):
				var cell: = queue[cursor]
				cursor += 1
				for next: int in _cardinal_indices(cell):
					if parents.has(next) or not _sector_step_legal(next, unit, start, false): continue
					parents[next] = cell
					queue.append(next)
			if performance_profile_enabled: exclusive_profile.count(&"formation_bfs_cells", cursor)
			var path: Array[int] = []
			if parents.has(target_cell):
				var cell: = target_cell
				while cell != start:
					path.push_front(cell)
					cell = parents[cell]
			unit["formation_route"] = PackedInt32Array(path)
			unit["formation_route_cursor"] = 0
			unit["formation_checked_revision"] = -1
			unit["formation_lookahead_tick"] = -1
	if bool(unit.get("formation_route_direct", false)): return target
	var waypoint: = _route_waypoint(unit, "formation", false)
	return waypoint if waypoint.is_finite() else origin


func _route_waypoint(unit: Dictionary, prefix: String, attacking: bool) -> Vector2:
	var path: PackedInt32Array = unit.get(prefix + "_route", PackedInt32Array())
	var cursor: = int(unit.get(prefix + "_route_cursor", 0))
	var origin: = Vector2(unit.longitude, unit.latitude)
	if prefix == "reinforcement" and unit.get("deployment_phase", "") == "TRANSIT" and unit.has("transit_failed_target") and int(unit.transit_failed_target) == int(unit.get("reinforcement_destination", -1)):


		return origin
	if cursor >= path.size():
		if prefix == "reinforcement" and unit.get("deployment_phase", "") == "TRANSIT":
			var destination: = int(unit.get("reinforcement_destination", -1))
			if destination >= 0 and destination < land_mask.size(): return geo_for_grid_index(destination)
		return Vector2(INF, INF)
	var origin_cell: = grid_index_for_geo(unit.longitude, unit.latitude)


	if int(unit.get(prefix + "_checked_revision", -1)) != _control_revision:
		for i: int in range(cursor, path.size()):
			if not _sector_step_legal(path[i], unit, origin_cell, attacking):
				unit[prefix + "_route_blocked"] = true
				if prefix == "formation": unit["formation_route_refresh"] = -1
				if prefix == "reinforcement":
					if unit.get("deployment_phase", "") == "RELOCATING":
						unit["deployment_phase"] = "STRANDED"
						return origin
					if sim_tick_count >= int(unit.get("route_retry_tick", 0)):
						unit["route_retry_tick"] = sim_tick_count + 60
						var repaired: PackedInt32Array = city_deployment.reroute(self, unit)
						if not repaired.is_empty():
							unit["reinforcement_route"] = repaired
							unit["reinforcement_route_cursor"] = 0
							unit["deployment_assigned_sector"] = int(unit.reinforcement_destination)
							unit["reinforcement_checked_revision"] = -1
							unit["reinforcement_route_blocked"] = false
							unit.erase("transit_failed_target")
						else:
							unit["transit_failed_target"] = int(unit.get("reinforcement_destination", -1))
				return origin
		unit[prefix + "_checked_revision"] = _control_revision
		unit[prefix + "_route_blocked"] = false
	while cursor < path.size() and _wrapped_geo_delta(origin, geo_for_grid_index(path[cursor])).length_squared() <= 0.0001:
		cursor += 1
	if cursor >= path.size():
		unit[prefix + "_route_cursor"] = cursor
		if prefix == "reinforcement" and unit.get("deployment_phase", "") == "TRANSIT":
			var destination: = int(unit.get("reinforcement_destination", -1))
			if destination >= 0 and destination < land_mask.size(): return geo_for_grid_index(destination)
		return Vector2(INF, INF)


	if sim_tick_count >= int(unit.get(prefix + "_lookahead_tick", -1)):
		for candidate: int in range(mini(path.size() - 1, cursor + 3), cursor, -1):
			var goal: = geo_for_grid_index(path[candidate])
			var clipped: = MOVEMENT_CORRIDOR.clipped_precise(unit.longitude, unit.latitude, goal.x, goal.y, grid_size, _sector_step_legal.bind(unit, origin_cell, attacking))
			if absf(clipped[0] - goal.x) < 1e-06 and absf(clipped[1] - goal.y) < 1e-06:
				cursor = candidate
				break
		unit[prefix + "_lookahead_tick"] = sim_tick_count + 12
	unit[prefix + "_route_cursor"] = cursor
	return geo_for_grid_index(path[cursor])


func _friendly_passing_heading(unit: Dictionary, desired: Vector2) -> Vector2:





	if int(unit.get("movement_intent", -1)) not in [MOVEMENT_INTENT.Kind.DEPLOYMENT, MOVEMENT_INTENT.Kind.SECTOR]: return desired
	if unit.get("sector_role", "") != "Reinforce" and int(unit.get("movement_intent", -1)) != MOVEMENT_INTENT.Kind.DEPLOYMENT: return desired
	if sim_frame_count - int(unit.get("last_combat_tick", -1000)) < 2: return desired


	if int(unit.get("local_enemy_count", 0)) > 0 or int(unit.get("spacing_blocked_ticks", 0)) < 18: return desired
	var target: Vector2 = unit.get("movement_intent_target", Vector2(INF, INF))
	if not target.is_finite() or _wrapped_geo_delta(Vector2(unit.longitude, unit.latitude), target).length_squared() < 0.0225: return desired
	var index: = int(unit.get("spacing_blocker_index", -1))
	if index < 0 or index >= units.size() or desired == Vector2.ZERO: return desired
	var blocker: Dictionary = units[index]
	if int(blocker.id) != int(unit.get("spacing_blocker_id", -1)) or float(blocker.health) <= 0.0 or int(blocker.side_index) != int(unit.side_index):
		unit.erase("spacing_blocker_index")
		return desired
	var delta: = _wrapped_geo_delta(Vector2(unit.longitude, unit.latitude), Vector2(blocker.longitude, blocker.latitude))
	if delta.length_squared() > 0.0225 or delta.dot(desired) < -0.015:
		unit.erase("spacing_blocker_index")
		return desired



	var origin: = Vector2(unit.longitude, unit.latitude)
	if int(unit.get("passing_waypoint_blocker", -1)) != int(blocker.id):
		var tangent: = Vector2( - desired.y, desired.x) * float(unit.get("passing_side", 1.0))
		var candidate_waypoint: = Vector2(blocker.longitude, blocker.latitude) + tangent * 0.075
		var cell: = grid_index_for_geo(candidate_waypoint.x, candidate_waypoint.y)
		if not _sector_step_legal(cell, unit, grid_index_for_geo(origin.x, origin.y), false): return desired
		unit["passing_waypoint"] = candidate_waypoint
		unit["passing_waypoint_blocker"] = int(blocker.id)
	var waypoint: Vector2 = unit.passing_waypoint
	var offset: = _wrapped_geo_delta(origin, waypoint)
	if offset.length_squared() < 0.0004:
		unit.erase("spacing_blocker_index")
		unit.erase("passing_waypoint_blocker")
		unit["spacing_blocked_ticks"] = 0
		return desired


	if delta.length_squared() < 0.001225 and offset.dot(delta) > 0.0:
		return (offset.normalized() - delta.normalized() * 1.2).normalized()
	return offset.normalized()


func _spacing_limited_displacement(unit_index: int, movement: Vector2) -> Vector2:
	if native_conflict_enabled and _native_conflict_core != null:
		if native_spacing_cache_enabled and _native_conflict_core.has_method("spacing_limited_displacement_cached"):
			return _native_conflict_core.spacing_limited_displacement_cached(self, unit_index, movement)
		return _native_conflict_core.spacing_limited_displacement(self, unit_index, movement)
	if movement.length_squared() < 1e-09: return movement
	if performance_profile_enabled: exclusive_profile.enter(&"movement_spacing")
	var profiled_neighbor_visits: = 0
	var unit: Dictionary = units[unit_index]
	var origin: = Vector2(unit.longitude, unit.latitude)
	var key: = _coverage_key(origin)
	var limit: = 1.0
	var blocker_index: = -1
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for other_index: int in _coverage_hash.get(Vector2i(posmod(key.x + dx, 1200), key.y + dy), []):
				if performance_profile_enabled: profiled_neighbor_visits += 1
				if other_index == unit_index or other_index >= units.size(): continue
				var other: Dictionary = units[other_index]
				if float(other.health) <= 0.0: continue
				var delta: = _wrapped_geo_delta(origin, Vector2(other.longitude, other.latitude))
				var gap: = 0.035 if int(other.side_index) == int(unit.side_index) else 0.045
				var distance_sq: = delta.length_squared()



				if delta.dot(movement) <= 1e-09: continue
				if distance_sq <= gap * gap:


					limit = 0.0
					blocker_index = other_index
					continue
				var projection: = delta.dot(movement) / movement.length_squared()
				if projection < 0.0 or projection > 1.0 + gap / movement.length(): continue
				var perpendicular_sq: = distance_sq - projection * projection * movement.length_squared()
				if perpendicular_sq >= gap * gap: continue
				var candidate_limit: = maxf(0.0, projection - sqrt(gap * gap - maxf(0.0, perpendicular_sq)) / movement.length())
				if candidate_limit < limit:
					limit = candidate_limit
					blocker_index = other_index
	if blocker_index >= 0:
		var blocker: Dictionary = units[blocker_index]
		if int(blocker.side_index) == int(unit.side_index):
			if int(unit.get("spacing_blocker_id", -1)) != int(blocker.id):
				unit["passing_side"] = 1.0 if int(unit.id) % 2 == 0 else -1.0
				unit["spacing_blocked_ticks"] = 0
			unit["spacing_blocked_ticks"] = int(unit.get("spacing_blocked_ticks", 0)) + 1
			unit["spacing_blocker_id"] = int(blocker.id)
			unit["spacing_blocker_index"] = blocker_index
		else:
			unit.erase("spacing_blocker_index")
			unit["spacing_blocked_ticks"] = 0
	elif int(unit.get("spacing_blocked_ticks", 0)) < 18:
		unit["spacing_blocked_ticks"] = 0
	if performance_profile_enabled:
		exclusive_profile.count(&"movement_spacing_neighbor_visits", profiled_neighbor_visits)
		exclusive_profile.leave()
	return movement * limit


func _apply_engagement_knockback(
	unit_index: int, 
	target_index: int, 
	delta_geo: Vector2, 
	target_damage: float, 
	self_damage: float
) -> void :
	if unit_index < 0 or target_index < 0 or unit_index >= units.size() or target_index >= units.size():
		return
	var distance: = delta_geo.length()
	if distance <= 1e-06:
		return
	var direction: = delta_geo / distance
	var total_damage: = maxf(1e-06, target_damage + self_damage)

	var base_push: = SOURCE_UNIT_SPEED * 1.2
	var target_factor: = minf(1.5, target_damage / total_damage * 1.5)
	var self_factor: = minf(1.0, self_damage / total_damage)
	_apply_raw_land_push(target_index, direction * base_push * target_factor, "knockback")
	_apply_raw_land_push(unit_index, - direction * base_push * 0.5 * self_factor)


func _apply_raw_land_push(unit_index: int, movement: Vector2, kind: String = "recoil") -> void :
	if unit_index < 0 or unit_index >= units.size() or not movement.is_finite() or movement.length_squared() <= 0.0:
		return
	var unit: Dictionary = units[unit_index]
	var next_longitude: = fposmod(float(unit["longitude"]) + movement.x + 180.0, 360.0) - 180.0
	var next_latitude: = clampf(float(unit["latitude"]) + movement.y, -89.9, 89.9)
	var prior_geo: = PackedFloat64Array([unit["longitude"], unit["latitude"]])
	var legal_geo: = _swept_land_destination(unit, next_longitude, next_latitude)
	if legal_geo == prior_geo: return
	next_longitude = legal_geo[0]
	next_latitude = legal_geo[1]
	unit["longitude"] = next_longitude
	unit["latitude"] = next_latitude
	_verify_event("recoil", unit, -1, 0.0, {"displacement": movement, "health_damage": 0.0})
	units[unit_index] = unit
	if unit_index < _unit_geo_cache.size():
		_unit_geo_cache[unit_index] = Vector2(next_longitude, next_latitude)
		_contact_unit_moved(unit_index, _unit_geo_cache[unit_index])
	if movement_audit.is_valid():
		movement_audit.call(self, unit, prior_geo, legal_geo, kind, movement)


func _movement_land_legal(cell: int, unit: Dictionary) -> bool:
	return cell >= 0 and cell < land_mask.size() and land_mask[cell] == 2 and unit_can_enter_cell(unit, cell)


func _swept_land_destination(unit: Dictionary, longitude: float, latitude: float) -> PackedFloat64Array:
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	if performance_profile_enabled: exclusive_profile.enter(&"swept_movement")
	var swept_result: = _swept_land_destination_impl(unit, longitude, latitude)
	if performance_profile_enabled: exclusive_profile.leave()
	if performance_profile_enabled:
		_profile_swept_usec += Time.get_ticks_usec() - started
	return swept_result


func _swept_land_destination_impl(unit: Dictionary, longitude: float, latitude: float) -> PackedFloat64Array:
	var start: = grid_index_for_geo(unit["longitude"], unit["latitude"])
	var end: = grid_index_for_geo(longitude, latitude)


	if start == end and _movement_land_legal(start, unit): return PackedFloat64Array([longitude, latitude])
	return MOVEMENT_CORRIDOR.clipped_precise(unit["longitude"], unit["latitude"], longitude, latitude, grid_size, _movement_land_legal.bind(unit))


func _defense_multiplier(unit: Dictionary) -> float:
	var index: = grid_index_for_geo(float(unit["longitude"]), float(unit["latitude"]))
	var sovereign_id: = int(unit["sovereign_id"])
	var defense: = 1.0
	if index >= 0 and index < de_jure_owners.size() and de_jure_owners[index] == int(unit["sovereign_id"]):
		defense *= 0.65
	if index >= 0 and index < world_owners.size() and world_owners[index] == sovereign_id and absf(occupation[index]) < 0.2:
		defense *= 0.85
	var own_geo: = Vector2(float(unit["longitude"]), float(unit["latitude"]))
	if _is_near_friendly_city(sovereign_id, own_geo):
		defense *= 0.45
	if sim_frame_count > 6000:
		defense *= 0.75
	return defense


func _is_near_friendly_city(sovereign_id: int, own_geo: Vector2) -> bool:
	var positions: Array = country_city_positions.get(sovereign_id, [])


	if positions.size() <= 9:
		for city_geo: Vector2 in positions:
			if _wrapped_geo_delta(own_geo, city_geo).length_squared() < 0.04:
				return true
		return false
	var city_hash: Dictionary = _country_city_spatial_hash.get(sovereign_id, {})
	var origin_key: = _spatial_key(own_geo.x, own_geo.y)
	var max_key_x: = int(ceil(360.0 / HASH_CELL_SIZE))
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var key: = Vector2i(posmod(origin_key.x + dx, max_key_x), origin_key.y + dy)
			for city_geo: Vector2 in city_hash.get(key, []):
				if _wrapped_geo_delta(own_geo, city_geo).length_squared() < 0.04:
					return true
	return false


func _record_damage(unit_index: int, damage: float, cause: String = "combat", attacker_id: int = -1) -> void :
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	_record_damage_impl(unit_index, damage, cause, attacker_id)
	if performance_profile_enabled: _profile_damage_usec += Time.get_ticks_usec() - started


func _record_damage_impl(unit_index: int, damage: float, cause: String = "combat", attacker_id: int = -1) -> void :
	if unit_index < 0 or unit_index >= units.size() or damage <= 0.0:
		return
	var unit: Dictionary = units[unit_index]
	var old_health: = maxf(0.0, float(unit.get("health", 0.0)))
	var new_health: = maxf(0.0, old_health - damage)
	var actual_damage: = old_health - new_health
	if actual_damage <= 0.0:
		return
	if verification_enabled:
		_verify_event(cause, unit, attacker_id, actual_damage, {"health_before": old_health, "health_after": new_health})
	if combat_trace_enabled:
		for event_index: int in range(combat_events.size() - 1, maxi(-1, combat_events.size() - 5), -1):
			var event: Dictionary = combat_events[event_index]
			if event["kind"] == cause and int(event["target"]) == int(unit["id"]) and int(event["attacker"]) == attacker_id:
				event["actual_damage"] = actual_damage
				event["health_before"] = old_health
				event["health_after"] = new_health
				break
	damage_this_tick += actual_damage
	if cause in ["direct", "direct_return", "proximity", "proximity_return"]:
		engagement_damage_this_tick += actual_damage
	if int(unit.get("damage_tick", -1)) != sim_tick_count:
		unit["hits_this_tick"] = 0
		unit["damage_tick"] = sim_tick_count
	unit["hits_this_tick"] = int(unit.get("hits_this_tick", 0)) + 1
	if new_health <= 0.0:
		death_events.append({"tick": sim_tick_count, "unit_id": int(unit["id"]), "side": int(unit["side_index"]), "cause": cause, "attacker": attacker_id, "hits": int(unit["hits_this_tick"]), "health_before": old_health, "damage": actual_damage})
		if death_events.size() > 512:
			death_events.pop_front()
	unit["health"] = new_health
	if unit_index < _contact_alive.size(): _contact_alive[unit_index] = int(new_health > 0.0)
	units[unit_index] = unit
	if native_conflict_enabled and _native_conflict_core != null and _native_conflict_core.has_method("spacing_unit_health_changed"):
		_native_conflict_core.spacing_unit_health_changed(unit_index, new_health)
	var side_index: int = int(unit["side_index"])
	var previous_casualties: = int(round(_casualty_exact[side_index]))
	_casualty_exact[side_index] += actual_damage / UNIT_HEALTH * float(unit.get("personnel_per_unit", side_soldiers_per_unit[side_index]))
	var loss: = int(round(_casualty_exact[side_index])) - previous_casualties
	if loss <= 0:
		return
	side_casualties[side_index] += loss
	side_personnel[side_index] = maxi(0, side_personnel[side_index] - loss)
	var sovereign_id: int = int(unit["sovereign_id"])
	country_casualties[sovereign_id] = int(country_casualties.get(sovereign_id, 0)) + loss


func _verify_event(kind: String, unit: Dictionary, attacker_id: int, actual_damage: float, extra: Dictionary = {}) -> void :
	if not verification_enabled:
		return
	var cell: = grid_index_for_geo(unit["longitude"], unit["latitude"])
	var side_index: = int(unit["side_index"])
	var owner_side: = int(country_to_side.get(world_owners[cell], -1)) if cell >= 0 else -1
	var control: = occupation[cell] if cell >= 0 else 0.0
	var friendly_control: = control > 0.0 if side_index == 0 else control < 0.0
	var location: = "friendly" if owner_side == side_index and friendly_control else "occupied_friendly" if owner_side == side_index else "enemy" if owner_side >= 0 else "neutral_or_water"
	var entry: = {"kind": kind, "tick": sim_tick_count, "source_frame": sim_frame_count, "side": side_index, "unit": int(unit["id"]), "attacker": attacker_id, "actual_damage": actual_damage, "position": Vector2(unit["longitude"], unit["latitude"]), "direction": unit.get("direction", Vector2.ZERO), "last_combat": int(unit.get("last_combat_tick", -1000)), "combat_age": sim_frame_count - int(unit.get("last_combat_tick", -1000)), "allies": unit.get("last_ally_count", 1), "enemies": unit.get("local_enemy_count", 0), "land": location, "control": control, "encircled": unit_is_encircled(unit), "border_retreat": unit.get("border_retreat", Vector2.ZERO)}
	entry["last_direct_frame"] = int(_verification_direct_frames.get(int(unit["id"]), -1000))
	entry["direct_age"] = sim_frame_count - int(entry["last_direct_frame"])
	if kind in ["direct", "direct_return"]:
		_verification_direct_frames[int(unit["id"])] = sim_frame_count
	for source_event: Dictionary in combat_events.slice(maxi(0, combat_events.size() - 4)):
		if source_event["kind"] == kind and int(source_event["target"]) == int(unit["id"]) and int(source_event["attacker"]) == attacker_id:
			entry["distance"] = source_event["distance"]
			entry["gate_distance"] = source_event["gate_distance"]
			entry["permitted"] = source_event["permitted"]
			entry["attacker_last_combat"] = source_event["last_combat"]
	entry.merge(extra, true)
	verification_events.append(entry)
	if verification_events.size() > 2048:
		verification_events.pop_front()
	if actual_damage > 0.0:
		verification_damage_totals[kind] = float(verification_damage_totals.get(kind, 0.0)) + actual_damage
	var window: = int(sim_tick_count / 100.0)
	if not verification_windows.has(window):
		verification_windows[window] = {"tick": sim_tick_count, "source_frame": sim_frame_count, "damage": {}, "battle_positions": [], "formations": []}
	var record: Dictionary = verification_windows[window]
	var damage: Dictionary = record["damage"]
	if actual_damage > 0.0:
		damage[kind] = float(damage.get(kind, 0.0)) + actual_damage
	if kind == "movement" and sim_tick_count % 100 == 0:
		record["formations"].append({"unit": entry["unit"], "side": side_index, "position": entry["position"], "health": unit["health"]})
		record["battle_positions"] = active_battles.duplicate(true)
	if verification_windows.size() > 32:
		verification_windows.erase(verification_windows.keys()[0])


func _trace_combat(kind: String, unit: Dictionary, target: Dictionary, gate_distance: float, return_permitted: bool = true) -> void :
	if not combat_trace_enabled:
		return
	var stamp: = int(unit.get("last_combat_tick", -1000))
	var age: = sim_frame_count - stamp
	var true_distance: = _wrapped_geo_delta(Vector2(float(unit["longitude"]), float(unit["latitude"])), Vector2(float(target["longitude"]), float(target["latitude"]))).length()
	var carried: = kind == "direct" and gate_distance > 0.05 and age > 0 and age < 2
	if carried:
		carried_direct_count += 1
	combat_event_counts[kind] = int(combat_event_counts.get(kind, 0)) + 1
	var permitted: = direct_combat_permitted(gate_distance, stamp) if kind == "direct" else return_permitted
	if kind.begins_with("proximity"):
		permitted = gate_distance < 0.2
	combat_events.append({"kind": kind, "attacker": int(unit["id"]), "target": int(target["id"]), "distance": true_distance, "gate_distance": gate_distance, "frame": sim_frame_count, "visual_loop": visual_loop_count, "tick": sim_tick_count, "last_combat": stamp, "target_last_combat": int(target.get("last_combat_tick", -1000)), "permitted": permitted, "carry_over": carried, "direction": unit.get("direction", Vector2.ZERO), "border_retreat": unit.get("border_retreat", Vector2.ZERO), "attacker_geo": [unit["longitude"], unit["latitude"]], "target_geo": [target["longitude"], target["latitude"]], "tactical": country_frontline_state.get(int(unit["sovereign_id"]), {}).duplicate(), "battle_clusters": active_battles.size()})
	if combat_events.size() > 4096:
		combat_events.pop_front()


func _record_battle(unit: Dictionary, target: Dictionary) -> void :
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	_record_battle_impl(unit, target)
	if performance_profile_enabled: _profile_battle_records_usec += Time.get_ticks_usec() - started


func _record_battle_impl(unit: Dictionary, target: Dictionary) -> void :
	var midpoint: = Vector2(
		(float(unit["longitude"]) + float(target["longitude"])) * 0.5, 
		(float(unit["latitude"]) + float(target["latitude"])) * 0.5
	)


	if _battle_index_size != active_battles.size():
		_battle_buckets.clear()
		for i: int in range(active_battles.size()):
			var item: Dictionary = active_battles[i]
			_battle_index_add(i, _battle_key(Vector2(item.longitude, item.latitude)))
		_battle_index_size = active_battles.size()
	var key: = _battle_key(midpoint)
	var selected: = -1
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for i: int in _battle_buckets.get(Vector2i(posmod(key.x + dx, 900), key.y + dy), []):
				if selected >= 0 and i >= selected: continue
				var candidate: Dictionary = active_battles[i]
				if _wrapped_geo_delta(Vector2(candidate.longitude, candidate.latitude), midpoint).length_squared() < 0.16:
					selected = i
	if selected >= 0:
		var battle: Dictionary = active_battles[selected]
		var battle_geo: = Vector2(float(battle["longitude"]), float(battle["latitude"]))
		var participants: = int(battle["participants"]) + 1
		battle["participants"] = participants
		battle["longitude"] = lerpf(float(battle["longitude"]), midpoint.x, 1.0 / participants)
		battle["latitude"] = lerpf(float(battle["latitude"]), midpoint.y, 1.0 / participants)
		battle["damage_tick"] = sim_tick_count
		var previous_key: = _battle_key(battle_geo)
		var next_key: = _battle_key(Vector2(battle.longitude, battle.latitude))
		if previous_key != next_key:
			_battle_buckets[previous_key].erase(selected)
			_battle_index_add(selected, next_key)
		return
	active_battles.append({
		"longitude": midpoint.x, 
		"latitude": midpoint.y, 
		"participants": 2, 
		"damage_tick": sim_tick_count, 
	})
	_battle_index_add(active_battles.size() - 1, key)
	_battle_index_size = active_battles.size()


func _battle_key(geo: Vector2) -> Vector2i:
	return Vector2i(int(floor(fposmod(geo.x + 180.0, 360.0) / 0.4)), int(floor((geo.y + 90.0) / 0.4)))


func _battle_index_add(index: int, key: Vector2i) -> void :
	if not _battle_buckets.has(key): _battle_buckets[key] = []
	_battle_buckets[key].append(index)


func _apply_unit_influence() -> void :
	var profile_started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	var base_influence: = INFLUENCE_RATE * minf(1.0, 0.05 + float(sim_frame_count) / 600.0 * 0.95)
	if unit_count_for_side(0) == 0 or unit_count_for_side(1) == 0:
		base_influence *= 6.0
	if sim_frame_count % 2 == 0:
		var diffuse_started: = Time.get_ticks_usec() if performance_profile_enabled else 0
		_diffuse_occupation()
		if performance_profile_enabled:
			_profile_diffuse_usec += Time.get_ticks_usec() - diffuse_started
	var processed: = 0
	for offset: int in range(units.size()):
		var unit_index: = (sim_frame_count * 30 + offset) % units.size()
		var unit: Dictionary = units[unit_index]
		if float(unit["health"]) <= 0.0 or int(unit.get("deploy_ticks", 0)) > 0 or city_muster.inactive(unit):
			continue
		if sim_frame_count - int(unit.get("last_combat_tick", -1000)) <= 5:
			continue
		processed += 1
		if processed > 300:
			break
		var phase: = float(unit.get("tactical_phase", 0.0))
		var organic_noise: = 0.8 + sin(phase * 1000.0 + sim_frame_count * 0.05) * 0.4
		var delta: = base_influence * organic_noise * (1.0 if int(unit["side_index"]) == 0 else -1.0) * float(unit.get("formation_weight", 1.0))
		var radius: = occupation_radius * (0.9 + sin(phase * 500.0 + sim_frame_count * 0.1) * 0.2)
		if int(unit.get("victory_boost_ticks", 0)) > 0:
			delta *= 3.0
			radius *= 1.4
		var longitude: = float(unit["longitude"])
		var latitude: = float(unit["latitude"])
		var radius_squared: = radius * radius
		var credited_id: = int(unit["beneficiary_id"])
		var credited_side: = int(unit["side_index"])
		var concentration: = minf(2.5, float(unit.get("last_ally_weight", unit.get("last_ally_count", 1))) / 5.0)
		var homeland_only: = MWBattleDoctrines.homeland_only(String(country_doctrines.get(int(unit["sovereign_id"]), "Combined Arms")))
		var min_x: = clampi(int(floor((longitude - radius + 180.0) / GRID_RESOLUTION)), 0, grid_size.x - 1)
		var max_x: = clampi(int(floor((longitude + radius + 180.0) / GRID_RESOLUTION)), 0, grid_size.x - 1)
		var min_y: = clampi(int(floor((90.0 - (latitude + radius)) / GRID_RESOLUTION)), 0, grid_size.y - 1)
		var max_y: = clampi(int(floor((90.0 - (latitude - radius)) / GRID_RESOLUTION)), 0, grid_size.y - 1)
		if native_conflict_enabled and _native_conflict_core != null:
			var updates: Dictionary = _native_conflict_core.unit_influence_updates(self, longitude, latitude, GRID_RESOLUTION, radius, delta, concentration, homeland_only, int(unit["sovereign_id"]))
			if performance_profile_enabled: exclusive_profile.count(&"influence_candidate_cell_visits", int(updates.get("candidate_visits", 0)))
			var update_indices: PackedInt64Array = updates["indices"]
			var update_values: PackedFloat64Array = updates["values"]
			for update_index: int in range(update_indices.size()):
				if state != WarState.RUNNING:
					return
				_apply_unit_influence_cell(int(update_indices[update_index]), update_values[update_index], unit, credited_id, credited_side)
			continue
		if performance_profile_enabled: exclusive_profile.count(&"influence_candidate_cell_visits", (max_x - min_x + 1) * (max_y - min_y + 1))
		for y: int in range(min_y, max_y + 1):
			for x: int in range(min_x, max_x + 1):
				var index: = y * grid_size.x + x
				if state != WarState.RUNNING or index < 0 or index >= occupation.size():
					return
				if land_mask[index] != 2:
					continue
				if homeland_only and prewar_de_jure_owners[index] != int(unit["sovereign_id"]):
					continue
				if (delta > 0.0 and occupation[index] >= 1.0) or (delta < 0.0 and occupation[index] <= -1.0):
					continue


				var cell_longitude: = float(x) * GRID_RESOLUTION - 180.0
				var cell_latitude: = 90.0 - float(y + 1) * GRID_RESOLUTION
				var delta_longitude: = fposmod(cell_longitude - longitude + 180.0, 360.0) - 180.0
				var delta_latitude: = cell_latitude - latitude
				var distance_sq: = delta_longitude * delta_longitude + delta_latitude * delta_latitude
				if distance_sq >= radius_squared:
					continue
				var distance: = sqrt(distance_sq)
				var cell_delta: = delta
				if city_cell_set.has(index):
					cell_delta *= 0.35
				var radial_weight: = 1.0 - distance / radius
				var weight: = radial_weight * radial_weight * concentration
				var new_value: = clampf(occupation[index] + cell_delta * weight, -1.0, 1.0)
				_apply_unit_influence_cell(index, new_value, unit, credited_id, credited_side)
	if performance_profile_enabled:
		_profile_unit_influence_usec += Time.get_ticks_usec() - profile_started - _profile_diffuse_usec


func _apply_unit_influence_cell(index: int, new_value: float, _unit: Dictionary, credited_id: int, credited_side: int) -> void :
	var previous_control: = occupation[index]
	var current_id: = primary_occupier[index]
	var previous_visual_owner: = current_id if absf(previous_control) > 0.05 and current_id > 0 else world_owners[index]
	var current_side: int = int(country_to_side.get(current_id, -1))
	var credit_changes: = absf(new_value) > 0.05 and (current_side != credited_side or current_id <= 0) and ((new_value > 0.0 and credited_side == 0) or (new_value < 0.0 and credited_side == 1))
	var sign_changed: = signf(previous_control) != signf(new_value)
	var owner_threshold_changed: = (absf(previous_control) > 0.05) != (absf(new_value) > 0.05)
	var needs_incremental: = sign_changed or owner_threshold_changed or credit_changes
	if influence_commit_fastpath_enabled and not needs_incremental:


		occupation[index] = new_value
		if performance_profile_enabled and previous_control != occupation[index]: exclusive_profile.occupation_written(index, grid_size.x)
		if _pockets_initialized and LandPocketResolver.classification(previous_control) != LandPocketResolver.classification(new_value):
			land_pockets.changed(index, new_value)
		visual_revisions.changed(index, previous_control != occupation[index], false)
		return
	var previous_effective_owner: = effective_owner_at(index) if needs_incremental else -1
	var previous_frontline_edges: = _local_frontline_edge_count(index) if sign_changed else 0
	occupation[index] = new_value
	if performance_profile_enabled and previous_control != occupation[index]: exclusive_profile.occupation_written(index, grid_size.x)
	if sign_changed:
		_update_country_controlled_count(index, previous_control, new_value)
	if credit_changes:
		primary_occupier[index] = credited_id
	if _pockets_initialized and LandPocketResolver.classification(previous_control) != LandPocketResolver.classification(new_value):
		land_pockets.changed(index, new_value)
	if needs_incremental:
		_update_incremental_control(index, previous_effective_owner, previous_frontline_edges, previous_control, true)
	visual_revisions.changed(index, previous_control != occupation[index], previous_visual_owner != effective_owner_at(index))


func _diffuse_occupation() -> void :




	var probability: = float(theater_cells.size()) / float(land_mask.size())
	var log_miss: = log(1.0 - probability) if probability < 1.0 else - INF
	var sample: = 0
	var profiled_seeds: = 0
	var profiled_neighbors: = 0
	while sample < 35000:
		if probability < 1.0:
			sample += int(floor(log(maxf(1e-10, _rng.randf())) / log_miss))
		if sample >= 35000:
			break
		sample += 1
		var index: = theater_cells[_rng.randi_range(0, theater_cells.size() - 1)]
		if performance_profile_enabled: profiled_seeds += 1
		var x: = index % grid_size.x
		var y: = int(float(index) / float(grid_size.x))
		if x <= 0 or x >= grid_size.x - 1 or y <= 0 or y >= grid_size.y - 1:
			continue
		var total: = 0.0
		if performance_profile_enabled: profiled_neighbors += 9
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				total += occupation[index + dy * grid_size.x + dx]
		var previous: = occupation[index]
		var smoothed: = previous * 0.75 + total / 9.0 * 0.25

		var spread_owner: = primary_occupier[index]
		var previous_visual_owner: = spread_owner if absf(previous) > 0.05 and spread_owner > 0 else world_owners[index]
		if country_doctrines.has(spread_owner) and MWBattleDoctrines.homeland_only(country_doctrines[spread_owner]) and prewar_de_jure_owners[index] != spread_owner:
			continue
		if smoothed == previous:
			continue
		var sign_changed: = signf(previous) != signf(smoothed)
		var owner_threshold_changed: = primary_occupier[index] > 0 and (absf(previous) > 0.05) != (absf(smoothed) > 0.05)
		var needs_incremental: = sign_changed or owner_threshold_changed
		var previous_owner: = effective_owner_at(index) if needs_incremental else -1
		var previous_edges: = _local_frontline_edge_count(index) if sign_changed else 0
		occupation[index] = smoothed
		if performance_profile_enabled and previous != occupation[index]: exclusive_profile.occupation_written(index, grid_size.x)
		if sign_changed:
			_update_country_controlled_count(index, previous, smoothed)
		if _pockets_initialized and LandPocketResolver.classification(previous) != LandPocketResolver.classification(smoothed):
			land_pockets.changed(index, smoothed)
		if needs_incremental:
			_update_incremental_control(index, previous_owner, previous_edges, previous, true)
		visual_revisions.changed(index, previous != occupation[index], previous_visual_owner != effective_owner_at(index))
	if performance_profile_enabled:
		exclusive_profile.count(&"diffusion_seed_cells", profiled_seeds)
		exclusive_profile.count(&"diffusion_neighbor_cell_visits", profiled_neighbors)


func _update_country_controlled_count(index: int, previous_control: float, current_control: float) -> void :
	var sovereign_id: = world_owners[index]
	if not _country_controlled_cells.has(sovereign_id):
		return
	var side_index: = int(country_to_side.get(sovereign_id, -1))
	if side_index < 0:
		return
	var was_controlled: = previous_control > 0.0 if side_index == 0 else previous_control < 0.0
	var is_controlled: = current_control > 0.0 if side_index == 0 else current_control < 0.0
	if was_controlled == is_controlled:
		return
	var delta: = 1 if is_controlled else -1
	_country_controlled_cells[sovereign_id] = maxi(0, int(_country_controlled_cells[sovereign_id]) + delta)
	var occupied: Dictionary = _occupied_home_cells.get(sovereign_id, {})
	if is_controlled:
		occupied.erase(index)
	else:
		occupied[index] = true
	_occupied_home_cells[sovereign_id] = occupied


func occupied_home_cells(country_id: int) -> Array[int]:
	var cells: Array[int] = []
	for cell: int in (_occupied_home_cells.get(country_id, {}) as Dictionary):
		cells.append(cell)
	cells.sort()
	return cells


func _remove_destroyed_units() -> void :
	for unit_index: int in range(units.size() - 1, -1, -1):
		if float(units[unit_index].get("health", 0.0)) <= 0.0:
			units.remove_at(unit_index)
			_coverage_tick = -1


func _try_reinforcements() -> void :
	var started: = Time.get_ticks_usec() if performance_profile_enabled else 0
	_try_reinforcements_impl()
	if performance_profile_enabled:
		_profile_recruitment_usec += Time.get_ticks_usec() - started


func _try_reinforcements_impl() -> void :
	var force_counts: = _build_force_counts()
	var side_counts: PackedInt32Array = force_counts["sides"]
	var country_counts: Dictionary = force_counts["countries"]
	for side_index: int in range(2):
		if side_counts[side_index] >= MAX_UNITS_PER_SIDE:
			continue
		for country_id: int in sides[side_index]:
			if surrendered_countries.has(country_id):
				continue
			var current_units: = int(country_counts.get(country_id, 0))
			var initial_land: = maxi(1, (country_cells.get(country_id, PackedInt32Array()) as PackedInt32Array).size())
			var current_land: = int(_country_controlled_cells.get(country_id, 0))
			if current_land <= 0:
				continue

			var size_factor: = maxf(1.0, float(current_land) / 2000.0)
			var density_scale: = 1.0 / pow(size_factor, 0.35)
			var city_count: = int(country_city_counts.get(country_id, 0))
			var land_city_multiplier: = 1.0 + float(city_count) * 0.12
			var land_based_cap: = maxi(
				8, 
				int(floor(float(current_land) * UNIT_DENSITY_FACTOR * 1.5 * force_density * density_scale * land_city_multiplier))
			)
			var flexible_limit: = float(MAX_UNITS_PER_SIDE) * (
				1.0 + minf(3.0, float(current_land) / 4000.0 + float(city_count) * 0.15)
			)
			var absolute_cap: = mini(land_based_cap, int(floor(flexible_limit)))
			if current_units >= absolute_cap:
				continue

			var control_ratio: = float(current_land) / float(initial_land)
			var city_bonus: = 0.5 + float(city_count) * 0.5
			var land_ratio: = float(current_land) / 2000.0
			var scale_factor: = maxf(0.5, pow(land_ratio, 0.4))
			var underdog_factor: = (0.4 - control_ratio) * 2.0 if control_ratio < 0.4 else 0.0
			var annexation_urgency: = (0.6 - control_ratio) * 4.0 if control_ratio < 0.6 else 0.0
			var annexation_multiplier: = 1.0 + annexation_urgency
			var fill_ratio: = float(current_units) / float(absolute_cap) if absolute_cap > 0 else 1.0
			var force_depletion: = (0.6 - fill_ratio) * 2.5 if fill_ratio < 0.6 else 0.0
			var enemy_side_count: = side_counts[1 - side_index]
			var side_deficit: = maxf(0.0, float(enemy_side_count - side_counts[side_index]) / float(enemy_side_count)) if enemy_side_count > 0 else 0.0
			var imbalance_multiplier: = 1.0 + side_deficit * 2.0
			var recruitment_chance: = (
				BASE_RECRUITMENT_CHANCE
				* scale_factor
				* (control_ratio + city_bonus + underdog_factor + force_depletion)
				* annexation_multiplier
				* imbalance_multiplier
				* force_density
			)
			var queued: = int(queued_reinforcements.get(country_id, 0))
			if queued <= 0 and _rng.randf() >= recruitment_chance:
				continue
			if not _spawn_unit(side_index, country_id, false):
				if queued <= 0:
					queued_reinforcements[country_id] = 1
				continue
			if queued > 0:
				queued_reinforcements[country_id] = queued - 1
			side_counts[side_index] += 1
			country_counts[country_id] = current_units + 1
			side_personnel[side_index] += int(round(country_soldiers_per_unit.get(country_id, side_soldiers_per_unit[side_index])))
			reinforcement_counts[side_index] += 1
			var recruited: Dictionary = units[-1]
			recruitment_events.append({
				"tick": sim_tick_count, 
				"side_index": side_index, 
				"country_id": country_id, 
				"country_units": current_units + 1, 
				"country_cap": absolute_cap, 
				"controlled_land": current_land, 
				"source_city_id": int(recruited.get("reinforcement_city_id", -1)), 
				"source_cell": grid_index_for_geo(float(recruited["longitude"]), float(recruited["latitude"])), 
				"front_cell": int(recruited.get("front_sector", -1)), 
				"route_cells": (recruited.get("reinforcement_route", PackedInt32Array()) as PackedInt32Array).size(), 
				"queued": queued > 0, 
			})
			if recruitment_events.size() > 256:
				recruitment_events.pop_front()


func _update_control_totals() -> void :
	var total: = maxi(1, _held_control_cells[0] + _held_control_cells[1])
	side_control_percent.resize(2)
	side_control_percent[0] = float(_held_control_cells[0]) / float(total) * 100.0
	side_control_percent[1] = float(_held_control_cells[1]) / float(total) * 100.0


func _clear_encirclement() -> void :
	land_pockets = LandPocketResolver.new()
	_pockets_initialized = false
	encirclement_popups.clear()
	encirclement_topology = EncirclementTopology.new()
	encirclement_pass_count = 0
	encirclement_collapse_count = 0
	encirclement_revision += 1
	last_encirclement_usec = 0


func _initialize_land_pockets() -> void :
	land_pockets.initialize(land_mask, occupation, grid_size, theater_cells)
	land_pockets.native_core = _native_conflict_core if native_conflict_enabled else null
	land_pockets.native_graph_enabled = native_pocket_graph_enabled
	_encirclement_city_cells.clear()
	for geographic: Vector2 in _encirclement_cities:
		var cell: = grid_index_for_geo(geographic.x, geographic.y)
		if cell >= 0 and land_mask[cell] == 2:
			_encirclement_city_cells.append(cell)
	_pockets_initialized = true


func unit_is_encircled(unit: Dictionary) -> bool:
	if not _pockets_initialized:
		return false
	var fine: = grid_index_for_geo(float(unit["longitude"]), float(unit["latitude"]))
	return fine >= 0 and land_pockets.outcome_at(fine, int(unit["side_index"])) != LandPocketResolver.Outcome.OPEN


func encircled_retreat_efficiency(unit: Dictionary) -> float:

	return 0.05 if bool(unit.get("encircled", false)) else 1.0


func _apply_encircled_unit_effects(unit_index: int) -> void :
	var unit: Dictionary = units[unit_index]
	var trapped: = unit_is_encircled(unit)
	unit["encircled"] = trapped
	unit["damage_taken_multiplier"] = 4.0 if trapped else 1.0
	if not trapped:
		return
	unit["damage_dealt_multiplier"] = float(unit.get("damage_dealt_multiplier", 1.0)) * 0.25
	if int(unit.get("victory_boost_ticks", 0)) > 0:
		return
	var enemy_land: = 0
	for country_id: int in sides[1 - int(unit["side_index"])]:
		enemy_land += int(_country_controlled_cells.get(country_id, 0))
	var logistics: = maxf(1.0, log(float(enemy_land) / 500.0 + 1.0) / log(10.0))
	var fine: = grid_index_for_geo(float(unit["longitude"]), float(unit["latitude"]))
	var damage: = ATTRITION_DAMAGE * (1.0 + absf(occupation[fine]) * 3.0) * logistics * (1.0 + float(sim_frame_count) / 8000.0)
	_record_damage(unit_index, damage * ENCIRCLEMENT_DAMAGE_MULTIPLIER * 4.0, "encirclement_attrition")

	if land_pockets.outcome_at(fine, int(unit["side_index"])) == LandPocketResolver.Outcome.INLAND_SEALED and _rng.randf() < 0.001:
		_record_damage(unit_index, float(unit["health"]), "encirclement_attrition_death")


func _encircling_country(geographic: Vector2, side_index: int, radius: float) -> int:
	var votes: Dictionary = {}
	var selected_id: = 0
	var highest: = 0
	for offset: Vector2 in [Vector2.ZERO, Vector2(0, radius), Vector2(0, - radius), Vector2(radius, 0), Vector2( - radius, 0)]:
		var fine: = grid_index_for_geo(geographic.x + offset.x, geographic.y + offset.y)
		if fine < 0:
			continue
		var owner: = primary_occupier[fine]
		if owner > 0 and int(country_to_side.get(owner, -1)) == side_index:
			votes[owner] = int(votes.get(owner, 0)) + 1
	for country_id: int in votes:
		if int(votes[country_id]) > highest:
			highest = int(votes[country_id])
			selected_id = country_id
	if selected_id == 0:
		for country_id: int in country_to_side:
			if int(country_to_side[country_id]) == side_index:
				return country_id
	return selected_id


func _set_encirclement_control(index: int, new_control: float, owner_id: int) -> void :
	var previous_owner: = effective_owner_at(index)
	var previous_edges: = _local_frontline_edge_count(index)
	var previous_control: = occupation[index]
	occupation[index] = new_control
	if performance_profile_enabled and previous_control != occupation[index]: exclusive_profile.occupation_written(index, grid_size.x)
	primary_occupier[index] = owner_id
	_update_country_controlled_count(index, previous_control, new_control)
	_update_incremental_control(index, previous_owner, previous_edges, previous_control)
	visual_revisions.changed(index, previous_control != occupation[index], previous_owner != effective_owner_at(index))


func _effective_side_for_cell(cell: int) -> int:
	return int(country_to_side.get(effective_owner_at(cell), -1))



func _resolve_land_pockets() -> void :
	var started: = Time.get_ticks_usec()
	if not _pockets_initialized:
		_initialize_land_pockets()


	while true:
		var had_dirty_cells: = not land_pockets.dirty.is_empty()
		if performance_profile_enabled: exclusive_profile.enter(&"pocket_refresh")
		land_pockets.refresh(land_mask, simulation_seconds, sim_tick_count)
		if performance_profile_enabled: exclusive_profile.leave()
		if performance_profile_enabled and had_dirty_cells:
			exclusive_profile.count(&"pocket_refresh_calls")
			exclusive_profile.count(&"pocket_scanned_cells", land_pockets.scanned_cells)
		if performance_profile_enabled: exclusive_profile.enter(&"pocket_ready")
		var ready: = land_pockets.ready(_encirclement_city_cells, _effective_side_for_cell, simulation_seconds, sim_tick_count)
		if performance_profile_enabled: exclusive_profile.leave()
		if ready.is_empty():
			break
		if performance_profile_enabled: exclusive_profile.enter(&"pocket_collapse")
		for pocket: Dictionary in ready:
			_collapse_land_pocket(pocket)
		_remove_destroyed_units()
		_build_unit_spatial_hash()
		_update_control_totals()
		if performance_profile_enabled: exclusive_profile.leave()
	if performance_profile_enabled: exclusive_profile.enter(&"pocket_unit_mark")
	for unit: Dictionary in units:
		var trapped: = unit_is_encircled(unit)
		unit["encircled"] = trapped
		unit["damage_taken_multiplier"] = 4.0 if trapped else 1.0
	if performance_profile_enabled: exclusive_profile.leave()
	encirclement_revision = land_pockets.revision
	last_encirclement_usec = Time.get_ticks_usec() - started


	if verification_enabled and sim_tick_count % ENCIRCLEMENT_PASS_TICKS == 0:
		encirclement_pass_count += 1
		encirclement_topology.compute(occupation, land_mask, grid_size, ENCIRCLEMENT_STEP)


func _collapse_land_pocket(pocket: Dictionary) -> void :
	var trapped_side: = int(pocket["side"])
	var identity: = int(pocket["id"])
	var members: PackedInt32Array = pocket["owned"]
	var geographical: = geo_for_grid_index(members[0])
	var center: = Vector2.ZERO
	for cell: int in members:
		var geographic: = geo_for_grid_index(cell)
		center += geographical + _wrapped_geo_delta(geographical, geographic)
	center /= float(members.size())
	var captured_side: = int(pocket["captured_side"]) if trapped_side == 2 else 1 - trapped_side
	var owner_id: = _encircling_country(center, captured_side, 0.4)
	var casualties_before: = side_casualties.duplicate()
	var force_remaining: = 0.0
	var trapped_units: = 0
	for unit_index: int in range(units.size()):
		var unit: Dictionary = units[unit_index]
		var fine: = grid_index_for_geo(float(unit["longitude"]), float(unit["latitude"]))
		if int(unit["side_index"]) == trapped_side and float(unit["health"]) > 0 and land_pockets.label_at(fine, trapped_side) == identity and land_pockets.outcome_at(fine, trapped_side) == LandPocketResolver.Outcome.INLAND_SEALED:
			force_remaining += unit_personnel(unit)
			trapped_units += 1
			_record_damage(unit_index, float(unit["health"]), "encirclement_collapse")
	var flipped: = 0
	for cell: int in members:
		if land_mask[cell] == 2 and LandPocketResolver.classification(occupation[cell]) == (3 if trapped_side == 2 else 2 if trapped_side == 0 else -2):
			_set_encirclement_control(cell, 0.85 if captured_side == 0 else -0.85, owner_id)
			flipped += 1
	encirclement_collapse_count += 1
	var popup_text: = ""
	if force_remaining >= 1.0:
		popup_text = "+%s Encircled" % format_source_soldiers(ceil(force_remaining))
		encirclement_popups.append({"longitude": center.x, "latitude": center.y, "text": popup_text, "life": 240, "max_life": 240})
	var event: = {"tick": sim_tick_count, "source_frame": sim_frame_count, "simulation_seconds": simulation_seconds, "side": trapped_side, "fine_cells": members.size(), "outcome": "EmptyCapture" if trapped_side == 2 else "InlandSealed", "cities": pocket["cities"], "allowance_seconds": pocket["allowance"], "sealed_seconds": simulation_seconds - float(pocket["since"]), "trapped_units": trapped_units, "flipped_cells": flipped, "casualties": [side_casualties[0] - casualties_before[0], side_casualties[1] - casualties_before[1]], "popup": popup_text}
	land_pocket_resolved.emit(event)
	if verification_enabled:
		verification_encirclements.append(event)
		if verification_encirclements.size() > 256:
			verification_encirclements.pop_front()


func _age_encirclement_popups() -> void :
	for index: int in range(encirclement_popups.size() - 1, -1, -1):
		encirclement_popups[index]["life"] = int(encirclement_popups[index]["life"]) - 1
		if int(encirclement_popups[index]["life"]) <= 0:
			encirclement_popups.remove_at(index)


static func format_source_soldiers(value: float) -> String:
	var digits: = str(int(floor(maxf(0.0, value))))
	var formatted: = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted


func _update_incremental_control(index: int, previous_effective_owner: int, previous_frontline_edges: int, previous_control: float, pocket_already_changed: bool = false) -> void :
	if performance_profile_enabled: exclusive_profile.control_changed(index, grid_size.x, signf(previous_control) != signf(occupation[index]))
	if _pockets_initialized and not pocket_already_changed:
		land_pockets.changed(index, occupation[index])
	var current_effective_owner: = effective_owner_at(index)
	if current_effective_owner != previous_effective_owner:
		var previous_side: int = int(country_to_side.get(previous_effective_owner, -1))
		var current_side: int = int(country_to_side.get(current_effective_owner, -1))
		if previous_side >= 0 and previous_side < 2:
			_held_control_cells[previous_side] = maxi(0, _held_control_cells[previous_side] - 1)
		if current_side >= 0 and current_side < 2:
			_held_control_cells[current_side] += 1
		_control_revision += 1
		_city_front_route_cache.clear()
	var route_class_changed: = (previous_control > RECRUITMENT_CONTROL_THRESHOLD) != (occupation[index] > RECRUITMENT_CONTROL_THRESHOLD) or (previous_control < - RECRUITMENT_CONTROL_THRESHOLD) != (occupation[index] < - RECRUITMENT_CONTROL_THRESHOLD)
	if route_class_changed and current_effective_owner == previous_effective_owner:
		_control_revision += 1
		_city_front_route_cache.clear()


	if signf(previous_control) == signf(occupation[index]):
		return
	frontline_geometry_revision += 1
	for quad: int in [index, index - 1, index - grid_size.x, index - grid_size.x - 1]:
		_refresh_render_front_quad(quad)
	if not route_class_changed and current_effective_owner == previous_effective_owner:
		_control_revision += 1
		_city_front_route_cache.clear()
	frontline_segment_count = maxi(0, frontline_segment_count + _local_frontline_edge_count(index) - previous_frontline_edges)
	for cell: int in _cardinal_indices(index):
		if _local_frontline_edge_count(cell) > 0:
			_active_front_cells[cell] = true
		else:
			_active_front_cells.erase(cell)
	if _local_frontline_edge_count(index) > 0:
		_active_front_cells[index] = true
	else:
		_active_front_cells.erase(index)


func _refresh_render_front_quad(index: int) -> void :
	if index < 0 or index + grid_size.x + 1 >= occupation.size() or index % grid_size.x == grid_size.x - 1:
		render_front_quads.erase(index)
		return
	var below: = index + grid_size.x
	if land_mask[index] != 2 or land_mask[index + 1] != 2 or land_mask[below] != 2 or land_mask[below + 1] != 2:
		render_front_quads.erase(index)
		return
	var low: = minf(minf(occupation[index], occupation[index + 1]), minf(occupation[below], occupation[below + 1]))
	var high: = maxf(maxf(occupation[index], occupation[index + 1]), maxf(occupation[below], occupation[below + 1]))
	if low < 0.0 and high > 0.0: render_front_quads[index] = true
	else: render_front_quads.erase(index)


func _local_frontline_edge_count(index: int) -> int:
	if index < 0 or index >= occupation.size() or land_mask[index] != 2:
		return 0
	var x: = index % grid_size.x
	var y: = int(float(index) / float(grid_size.x))
	var count: = 0
	if x > 0 and land_mask[index - 1] == 2 and occupation[index] * occupation[index - 1] < 0.0:
		count += 1
	if x + 1 < grid_size.x and land_mask[index + 1] == 2 and occupation[index] * occupation[index + 1] < 0.0:
		count += 1
	if y > 0 and land_mask[index - grid_size.x] == 2 and occupation[index] * occupation[index - grid_size.x] < 0.0:
		count += 1
	if y + 1 < grid_size.y and land_mask[index + grid_size.x] == 2 and occupation[index] * occupation[index + grid_size.x] < 0.0:
		count += 1
	return count


func _evaluate_terminal_outcome() -> void :
	if state != WarState.RUNNING:
		return
	if units.is_empty() and not _side_has_recruitment_path(0) and not _side_has_recruitment_path(1):
		_apply_treaty(-1, "WHITE_PEACE")
		return
	var side_counts: = PackedInt32Array([unit_count_for_side(0), unit_count_for_side(1)])
	for side_index: int in range(2):
		if side_counts[side_index] > 0:
			continue
		if not _side_has_recruitment_path(side_index):
			_apply_treaty(1 - side_index, "FULL_CAPITULATION")
			return
	var majority_side: = 0 if side_control_percent[0] >= side_control_percent[1] else 1
	var loser_side: = 1 - majority_side
	var majority_share: = side_control_percent[majority_side] / 100.0
	var loser_held: = int(round(side_control_percent[loser_side] / 100.0 * theater_cells.size()))
	var loser_initial: = maxi(1, _side_initial_cells[loser_side])
	var loser_retention: = float(loser_held) / float(loser_initial)
	if majority_share >= 0.95 and loser_retention <= 0.1:
		if _dominance_anchor_tick < 0:
			_dominance_anchor_tick = sim_frame_count
		elif sim_frame_count - _dominance_anchor_tick > 120:
			_apply_treaty(majority_side, "FULL_CAPITULATION")
			return
	else:
		_dominance_anchor_tick = -1
	if majority_share >= 0.85 and loser_retention <= 0.3:
		if _decisive_anchor_tick < 0:
			_decisive_anchor_tick = sim_frame_count
		elif sim_frame_count - _decisive_anchor_tick > 360:
			_apply_treaty(majority_side, "DECISIVE_VICTORY")
			return
	else:
		_decisive_anchor_tick = -1
	if sim_frame_count > 8000:
		var score: = side_control_percent[0]
		if _stalemate_anchor_score < 0.0 or absf(score - _stalemate_anchor_score) > 5.0:
			_stalemate_anchor_score = score
			_stalemate_anchor_tick = sim_frame_count
		elif sim_frame_count - _stalemate_anchor_tick > 10000:
			_apply_treaty(0 if score >= 50.0 else 1, "STALEMATE")


func _side_has_recruitment_path(side_index: int) -> bool:
	for country_id: int in sides[side_index]:
		var controlled_land: = int(_country_controlled_cells.get(country_id, 0))
		var initial_land: = maxi(1, (country_cells.get(country_id, PackedInt32Array()) as PackedInt32Array).size())


		if controlled_land <= 0 or float(controlled_land) / float(initial_land) < 0.25:
			continue
		var eligible: = _recruitment_cells_for_country(country_id, side_index)
		var cells: PackedInt32Array = eligible.get("theater", PackedInt32Array())
		if not cells.is_empty():
			return true
	return false


func _apply_treaty(winner_side: int, reason: String) -> void :
	if state != WarState.RUNNING:
		return
	var changed_cells: = 0
	if winner_side >= 0:
		var fallback_winner_id: int = int(sides[winner_side][0])
		for index: int in theater_cells:
			var occupier_id: = primary_occupier[index]
			var occupier_side: int = int(country_to_side.get(occupier_id, -1))
			if occupier_side == winner_side:
				if world_owners[index] != occupier_id:
					changed_cells += 1
				world_owners[index] = occupier_id
			elif int(country_to_side.get(world_owners[index], -1)) != winner_side:
				if world_owners[index] != fallback_winner_id:
					changed_cells += 1
				world_owners[index] = fallback_winner_id
			occupation[index] = 0.0
			primary_occupier[index] = 0
			land_mask[index] = 1
	else:
		for index: int in theater_cells:
			occupation[index] = 0.0
			primary_occupier[index] = 0
			land_mask[index] = 1
	var winning_name: = ""
	if winner_side >= 0:
		winning_name = _side_display_name(winner_side)
	result = {
		"reason": reason, 
		"winner_side": winner_side, 
		"winner_name": winning_name, 
		"changed_cells": changed_cells, 
		"title": (
			"WHITE PEACE"
			if winner_side < 0
			else "%s VICTORY" % winning_name
		), 
		"casualties_a": side_casualties[0], 
		"casualties_b": side_casualties[1], 
		"ticks": sim_tick_count, 
	}
	units.clear()
	_clear_contact_reads()
	bases.clear()
	active_battles.clear()
	battle_planner.clear()
	_clear_encirclement()
	is_paused = false
	frame_accumulator = 0.0
	result_elapsed = 0.0
	state = WarState.RESULT
	_last_result_state = state
	render_revision += 1
	visual_revisions.reset(grid_size)
	war_ended.emit(result.duplicate(true))


func _build_default_conflict_name(side_a: Array[int], side_b: Array[int]) -> String:
	return "%s VS %s" % [_country_list_name(side_a), _country_list_name(side_b)]


func unit_can_enter_cell(unit: Dictionary, cell: int) -> bool:
	if cell < 0 or cell >= prewar_de_jure_owners.size():
		return false
	var country: = int(unit["sovereign_id"])
	var doctrine: String = country_doctrines.get(country, "Combined Arms")
	if not _homeland_lookup.has(doctrine): _homeland_lookup[doctrine] = MWBattleDoctrines.homeland_only(doctrine)
	return not _homeland_lookup[doctrine] or prewar_de_jure_owners[cell] == country


func _resolve_capital_surrenders() -> void :
	if not surrender_on_capital_capture:
		return
	for country: int in prewar_capitals:
		if surrendered_countries.has(country):
			continue
		var capital: Dictionary = prewar_capitals[country]
		var cell: = int(capital["cell"])
		var home_side: = int(country_to_side.get(country, -1))
		var captor: = effective_owner_at(cell)
		var captor_side: = int(country_to_side.get(captor, -1))
		var hostile: = occupation[cell] < -0.3 if home_side == 0 else occupation[cell] > 0.3
		if not hostile or captor_side < 0 or captor_side == home_side or surrendered_countries.has(captor):
			continue
		surrendered_countries[country] = {"captor": captor, "tick": sim_tick_count}
		var casualty_before: = int(side_casualties[home_side])
		for unit_index: int in range(units.size()):
			if int(units[unit_index]["sovereign_id"]) == country:
				_record_damage(unit_index, float(units[unit_index]["health"]), "capital_surrender")
		_remove_destroyed_units()
		for base_index: int in range(bases.size() - 1, -1, -1):
			if int(bases[base_index].get("sovereign_id", -1)) == country:
				bases.remove_at(base_index)
		var flipped: = 0


		for fine_cell: int in theater_cells:
			if primary_occupier[fine_cell] == country or effective_owner_at(fine_cell) == country:
				_set_encirclement_control(fine_cell, 0.85 if captor_side == 0 else -0.85, captor)
				flipped += 1
		_country_controlled_cells[country] = 0
		_spawn_cell_cache.erase(country)
		_garrison_cache.clear()
		_coverage_tick = -1
		battle_planner.invalidate_country(country, sim_tick_count, "Capital surrendered")
		battle_planner.invalidate_captured_objectives(self)
		active_battles.clear()
		surrender_events.append({"country": country, "captor": captor, "tick": sim_tick_count, "flipped": flipped, "casualties": int(side_casualties[home_side]) - casualty_before})
		encirclement_popups.append({"longitude": capital["geo"].x, "latitude": capital["geo"].y, "text": String(country_names[country]).to_upper() + " ANNEXED", "life": 360, "max_life": 360})
		_build_unit_spatial_hash()
		_refresh_front_coverage(true)
		_update_control_totals()


func _country_list_name(country_ids: Array[int]) -> String:
	var names: PackedStringArray = []
	for country_id: int in country_ids:
		names.append(String(country_names.get(country_id, "COUNTRY %d" % country_id)).to_upper())
	return " AND ".join(names)


func _side_display_name(side_index: int) -> String:
	var country_ids: Array[int] = sides[side_index]
	return _country_list_name(country_ids)


func _wrapped_geo_delta(origin: Vector2, target: Vector2) -> Vector2:
	var longitude_delta: = target.x - origin.x
	if longitude_delta > 180.0:
		longitude_delta -= 360.0
	elif longitude_delta < -180.0:
		longitude_delta += 360.0
	return Vector2(longitude_delta, target.y - origin.y)
