class_name Card
extends Resource

enum Suit { SPADES, HEARTS, DIAMONDS, CLUBS, JOKER }

var suit: Suit
var value: int   # 1=Ace, 2-10, 11=J, 12=Q, 13=K, 0=Joker
var is_joker: bool

func _init(s: Suit, v: int) -> void:
	suit = s
	value = v
	is_joker = (s == Suit.JOKER)

func display_value() -> String:
	match value:
		0:  return "JK"
		1:  return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_:  return str(value)

func suit_symbol() -> String:
	match suit:
		Suit.SPADES:   return "♠"
		Suit.HEARTS:   return "♥"
		Suit.DIAMONDS: return "♦"
		Suit.CLUBS:    return "♣"
		Suit.JOKER:    return "★"
		_:             return "?"

func label() -> String:
	return display_value() + suit_symbol()
