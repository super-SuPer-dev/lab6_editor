class_name CharacterAnims

# Lab 6: animations for the student character (Blender model, Mixamo bone names,
# retargeted with Mixamo BoneMap.tres) taken from Godot4-OpenAnimationLibraries.
# The game code uses the kit's short names (Idle / Run / Jump ...), so ALIASES maps
# them onto clips from the Melee and Shooter libraries.

const LIBRARIES := {
	"melee": preload("res://Assets/Animations/MeleeLib.res"),
	"shooter": preload("res://Assets/Animations/ShooterLib.res"),
}

const ALIASES := {
	"Idle": "shooter/idle",
	"Walk": "shooter/walk",
	"Run": "shooter/run_067",
	"Jump": "shooter/jump",
	"Fall": "shooter/fall",
	"Land": "shooter/fall-landing",
	"Flip": "melee/Roll",
	"Dodge": "shooter/roll",
	"Hurt": "shooter/hurt1",
	"Death": "melee/Die1",
	"Victory": "shooter/handsup-idle",
}

# Adds "melee", "shooter" and the alias library ("") to an AnimationPlayer whose
# root node is the character model.
static func setup(anim: AnimationPlayer, model: Node) -> void:
	var skeleton: Skeleton3D = model.find_child("GeneralSkeleton", true, false)
	for lib_name in LIBRARIES:
		if not anim.has_animation_library(lib_name):
			anim.add_animation_library(lib_name, clean_library(LIBRARIES[lib_name], skeleton))
	var aliases := AnimationLibrary.new()
	for short_name in ALIASES:
		aliases.add_animation(short_name, anim.get_animation(ALIASES[short_name]))
	if anim.has_animation_library(""):
		anim.remove_animation_library("")
	anim.add_animation_library("", aliases)

# Copies a library without root-motion clips and without tracks for bones the
# character doesn't have (Weapon, Root), so the mixer doesn't warn about them.
static func clean_library(src: AnimationLibrary, skeleton: Skeleton3D) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for anim_name in src.get_animation_list():
		if anim_name.begins_with("root-") or anim_name.begins_with("Armature|"):
			continue
		var a: Animation = src.get_animation(anim_name).duplicate()
		for i in range(a.get_track_count() - 1, -1, -1):
			var bone := str(a.track_get_path(i).get_concatenated_subnames())
			if bone != "" and skeleton.find_bone(bone) == -1:
				a.remove_track(i)
		lib.add_animation(anim_name, a)
	return lib

# Every playable clip as "library/name", for the animation browser.
static func list_all(anim: AnimationPlayer) -> PackedStringArray:
	var names := PackedStringArray()
	for lib_name in LIBRARIES:
		for anim_name in anim.get_animation_library(lib_name).get_animation_list():
			names.append("%s/%s" % [lib_name, anim_name])
	return names
