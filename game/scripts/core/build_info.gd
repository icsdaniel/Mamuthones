class_name BuildInfo
extends RefCounted
## Which commit this build came from. The Android test workflow writes the real commit here before
## exporting; a checkout says "dev".

const SHA := "dev"
