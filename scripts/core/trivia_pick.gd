extends RefCounted
## Which trivia questions a round asks (pure rules, no screen). Used by trivia.gd.

## The questions for one round. Unseen questions first; a level whose questions have all
## been seen is forgotten (its ids removed from seen) and starts over.
static func pick_round(all: Array, per_level: Array, seen: Dictionary) -> Array:
	var out: Array = []
	for level in range(per_level.size()):
		var pool: Array = all.filter(func(q: Variant) -> bool: return int((q as Dictionary).get("difficulty", 1)) == level + 1)
		var fresh: Array = pool.filter(func(q: Variant) -> bool: return not seen.has(str((q as Dictionary).get("id", ""))))
		var want: int = mini(int(per_level[level]), pool.size())
		fresh.shuffle()
		if fresh.size() < want:
			# this level is used up: start it over, but still ask the unseen ones first
			for q in pool:
				seen.erase(str((q as Dictionary).get("id", "")))
			var rest: Array = pool.filter(func(q: Variant) -> bool: return not fresh.has(q))
			rest.shuffle()
			fresh.append_array(rest)
		for k in range(want):
			out.append(fresh[k])
	return out
