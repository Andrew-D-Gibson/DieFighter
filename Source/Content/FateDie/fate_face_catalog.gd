class_name FateFaceCatalog
extends RefCounted
## Finds the FateFaceResource for each face of Fate's Die, by its id: the file
## Faces/<id>.tres beside this script (FateDie.face_id()).

const FACES_DIR: String = "res://Source/Content/FateDie/Faces"

static var _cache: Dictionary[FateDie.Face, FateFaceResource] = {}


## The resource describing [param face]. Null only if its file is missing,
## which test_authored_content would catch.
static func get_face(face: FateDie.Face) -> FateFaceResource:
	if _cache.has(face):
		return _cache[face]
	var path: String = FACES_DIR.path_join(FateDie.face_id(face) + ".tres")
	var res: FateFaceResource = null
	if ResourceLoader.exists(path):
		res = load(path) as FateFaceResource
	if res == null:
		push_error("FateFaceCatalog: no face resource at %s" % path)
		return null
	_cache[face] = res
	return res


## The colour a face is drawn in. White for a face with no resource.
static func color_of(face: FateDie.Face) -> Color:
	var res: FateFaceResource = get_face(face)
	return res.color if res else Color.WHITE
