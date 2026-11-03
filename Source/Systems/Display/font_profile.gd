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
## The words that float off ships (DamageNumber callouts).
@export var popup: FontFace
## The figures that float off ships, and a capped figure's smaller lead.
## m5x7 and m3x6 in every language, so popups look alike in all of them.
@export var digits: FontFace
@export var digits_small: FontFace

## Readable Font's faces in this language, when the default readable profile
## (res://Assets/Fonts/Profiles/readable.tres, fitted at 16) doesn't suit:
## each readable face must have the unit size of the face it leads, or this
## language's fonts, drawing behind it as fallbacks, leave their pixel grid.
## Empty for the default. Unused on the readable profiles themselves.
@export var readable: FontProfile


## The face for [param role], one of FontRoles.ROLES.
func face(role: StringName) -> FontFace:
	return get(role) as FontFace
