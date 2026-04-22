class_name CardMoveEvent
extends RefCounted

enum DestType { LADDER, BOARD }

var player_index: int
var source:       GameManager.CardSource
var source_index: int
var dest_type:    DestType
var dest_index:   int
var card:         Card
