class_name BattleDoctrines
extends RefCounted


const DEFINITIONS: = [
	["COMB", "Combined Arms", "Coordinate front, reserves and follow-on forces; avoid unsupported advances."], 
	["BLIZ", "Blitzkrieg", "Exploit weak sectors quickly; stop when flank or follow-on cover fails."], 
	["TRCH", "Trench Warfare", "Hold the line, prepare limited advances and consolidate after an offensive."], 
	["DEF", "Defense", "Defend and retake pre-war homeland; never invade enemy homeland."], 
	["PLAN", "Grand Battleplan", "Prepare a coordinated city offensive, then reorganize if its route becomes unsafe."], 
	["DEEP", "Deep Battle", "Alternate fresh waves and reserves through supported breakthroughs."], 
	["MASS", "Mass Mobilization", "Cover a broad front, reinforce gaps and attack with numerical advantage."], 
	["INFIL", "Infiltration Warfare", "Use small groups along weak routes while preserving support and escape."], 
	["ELAS", "Elastic Defense", "Yield homeland ground in order and counterattack stretched enemies; never invade."], 
	["DEPTH", "Defense in Depth", "Maintain layered homeland anchors and contain breakthroughs; never invade."], 
	["MDEF", "Mobile Defense", "Hold the front and rush mobile reserves to homeland threats; never invade."], 
	["BITE", "Bite and Hold", "Take one limited step, secure and reinforce it, then advance again."], 
	["ATTR", "Attritional Warfare", "Prefer sustainable exchanges and rotate damaged forces out of costly attacks."], 
	["ENC", "Encirclement Warfare", "Seek safe flank routes and secure closure; abandon exposed attempts."], 
	["WITH", "Fighting Withdrawal", "Withdraw damaged groups by stages under a covering force, then regroup."], 
	["GUER", "Guerrilla Warfare", "Strike isolated weak enemies and evade superior conventional forces."], 
	["RAID", "Raiding Warfare", "Visit exposed enemy cities or bases, then return before resistance gathers."], 
	["URB", "Urban Warfare", "Anchor forces in controlled cities and concentrate supported attacks on cities."], 
	["DIST", "Distributed Operations", "Split into supported small objectives; regroup against strong resistance."], 
	["PREC", "Precision Warfare", "Concentrate on exposed real cities or bases without inventing precision weapons."], 
]
const DEFENSIVE: = ["DEF", "ELAS", "DEPTH", "MDEF"]

static func definition(label: String) -> Array:
	for entry: Array in DEFINITIONS:
		if entry[0] == label or entry[1] == label:
			return entry
	return DEFINITIONS[0]

static func full_name(label: String) -> String:
	return definition(label)[1]

static func short_label(value: String) -> String:
	return definition(value)[0]

static func tooltip(value: String) -> String:
	var entry: = definition(value)
	return "%s: %s" % [entry[0], entry[2]]

static func homeland_only(value: String) -> bool:
	return short_label(value) in DEFENSIVE
