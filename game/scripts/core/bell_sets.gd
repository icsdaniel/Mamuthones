class_name BellSets
extends RefCounted
## The bells everyone plays with. The three loads that once changed the score and the timing were
## removed (Daniele, 2026-10-09): every run uses the Village bells' sound and look, and Session's
## timing windows are the Village ones. IDS stays for the art and sound, which still draw and play by
## set id.

const STANDARD := "village"
const IDS: Array[String] = ["light", "village", "full"]
