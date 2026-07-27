extends RefCounted

## Catalogue of selectable player characters.
##
## Not an autoload — preload this script and call the statics on it:
##     const Appearance := preload("res://multiplayer/player_appearance.gd")
##     Appearance.get_scene(id)
##
## The models are the same PSX character set the game already uses for its
## NPCs (see scenes/npc/npc_base.gd), so multiplayer bodies match the art
## style instead of the untextured capsule ("bønne") the player scene ships
## with — that capsule exists only because the base game is first-person and
## never renders your own body.
##
## `id` is what travels over the network and what gets written to the
## settings file, so **never renumber or reorder existing entries** — append
## new ones at the end instead.

const MODEL_DIR: String = "res://assets/props/Characters_psx/Models/"

const CHARACTERS: Array[Dictionary] = [
	{"id": 0, "name": "Ola", "path": "Male/Character_01.glb"},
	# Character_Female_01 is deliberately NOT used: its mesh has a material but
	# no albedo texture, so it renders as a plain white mannequin in game.
	{"id": 1, "name": "Kari", "path": "Female/Character_Female_02.glb"},
	{"id": 2, "name": "Jonas", "path": "Male/Character_05.glb"},
	{"id": 3, "name": "Ingrid", "path": "Female/Character_Female_05.glb"},
	{"id": 4, "name": "Bjørn", "path": "Male/Character_12.glb"},
	{"id": 5, "name": "Solveig", "path": "Female/Character_Female_11.glb"},
	{"id": 6, "name": "Betjenten", "path": "Male/Character_17_Police.glb"},
	{"id": 7, "name": "Brannmannen", "path": "Male/Character_23_Firefighter.glb"},
	{"id": 8, "name": "Doktoren", "path": "Female/Character_23_Female_Doctor.glb"},
	{"id": 9, "name": "Vaktmesteren", "path": "Male/Character_27_HM.glb"},
]


## The holster "weapon" is a flat hand PNG shown in the first-person
## viewmodel, and it is how the game does gestures (middle finger, peace, …).
## Remote players used to see nothing at all, because the viewmodel renders on
## a layer only its owner's camera draws. These indices are what travel over
## the wire, so — like CHARACTERS — **never reorder them**; append only.
const HAND_TEXTURE_DIR: String = "res://assets/textures/images/"

const HAND_TEXTURES: Array[String] = [
	"hand_fist.png",
	"hand_palmopen.png",
	"hand_midfinger.png",
	"hand_oksign.png",
	"hand_palmfacedaway.png",
	"hand_peace.png",
	"hand_pistol.png",
]


static func get_hand_texture(index: int) -> Texture2D:
	if index < 0 or index >= HAND_TEXTURES.size():
		return null
	var path: String = HAND_TEXTURE_DIR + HAND_TEXTURES[index]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func count() -> int:
	return CHARACTERS.size()


## Wraps an arbitrary int into a valid catalogue id, so a peer running a
## different mod version (or a corrupt settings file) can never make us index
## out of bounds.
static func normalize_id(id: int) -> int:
	if CHARACTERS.is_empty():
		return 0
	return posmod(id, CHARACTERS.size())


static func get_entry(id: int) -> Dictionary:
	if CHARACTERS.is_empty():
		return {}
	return CHARACTERS[normalize_id(id)]


static func get_display_name(id: int) -> String:
	return str(get_entry(id).get("name", "?"))


## Returns null when the model is missing from the build — callers fall back
## to the original capsule rather than spawning a headless player.
static func get_scene(id: int) -> PackedScene:
	var entry: Dictionary = get_entry(id)
	if entry.is_empty():
		return null
	var path: String = MODEL_DIR + str(entry.get("path", ""))
	if not ResourceLoader.exists(path):
		push_warning("[PlayerAppearance] Missing character model: %s" % path)
		return null
	return load(path) as PackedScene


## Fallback used when two players in the same lobby end up on the same
## character and we want to nudge one of them to a free slot.
static func next_free_id(taken: Array, preferred: int) -> int:
	var start: int = normalize_id(preferred)
	for offset in CHARACTERS.size():
		var candidate: int = normalize_id(start + offset)
		if not taken.has(candidate):
			return candidate
	return start
