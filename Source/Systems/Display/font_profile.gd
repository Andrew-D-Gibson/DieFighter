class_name FontProfile
extends Resource
## One locale's fonts: the FontFace each font role is drawn in. FontRoles
## applies the current language's profile (res://Assets/Fonts/Profiles/
## <locale>.tres) when Localization switches language.
##
## To make a role smaller or larger in one language, change that role's face
## here (or the face's size): every slot of the role follows together.

## Most UI text: the theme's default font (m3x6 in English).
@export var small: FontFace
## Larger text: titles, the info panel, world-space readouts (m5x7 in English).
@export var body: FontFace
## The numbers and words that float off ships (DamageNumber).
@export var popup: FontFace


## The face for [param role], one of FontRoles.ROLES.
func face(role: StringName) -> FontFace:
	return get(role) as FontFace
