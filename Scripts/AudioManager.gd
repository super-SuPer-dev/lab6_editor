extends Node

# ---------- VARIABLES ---------- #

# References (jump/coin/walking from the starter kit; the rest are CC0 downloads:
# Juhani Junkala "512 Sound Effects" and Kenney "Interface Sounds", see Assets/Audio/LICENSE_*)
@onready var jump_sfx = $JumpSfx
@onready var coin_sfx = $CoinSfx
@onready var hurt_sfx = $HurtSfx
@onready var fall_sfx = $FallSfx
@onready var checkpoint_sfx = $CheckpointSfx
@onready var door_sfx = $DoorSfx
@onready var locked_sfx = $LockedSfx
@onready var portal_sfx = $PortalSfx
@onready var win_sfx = $WinSfx
@onready var click_sfx = $ClickSfx
@onready var step_sfx = [$StepLeftSfx, $StepRightSfx]
