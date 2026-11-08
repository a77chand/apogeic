## Finds optional art by file name (see docs/ART_GUIDE.md).
## Each function returns null when the PNG doesn't exist yet, and the caller then
## keeps its grey-box placeholder.
extends RefCounted


static func module_texture(module_id: String) -> Texture2D:
	return _load("res://art/modules/%s.png" % module_id)


static func icon_texture(meter_id: String) -> Texture2D:
	return _load("res://art/icons/%s.png" % meter_id)


static func background_texture(scenario_id: String) -> Texture2D:
	return _load("res://art/backgrounds/%s.png" % scenario_id)


static func _load(path: String) -> Texture2D:
	# ResourceLoader.exists also works in exported (web) builds, where the
	# original PNG is replaced by its imported version.
	if ResourceLoader.exists(path):
		return load(path)
	return null
