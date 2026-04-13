class_name Deck
extends RefCounted

var cards: Array[Card] = []

static func build(num_decks: int = 3) -> Deck:
	var d := Deck.new()
	for _deck in range(num_decks):
		for suit in [Card.Suit.SPADES, Card.Suit.HEARTS,
				Card.Suit.DIAMONDS, Card.Suit.CLUBS]:
			for value in range(1, 14):
				d.cards.append(Card.new(suit, value))
		d.cards.append(Card.new(Card.Suit.JOKER, 0))
		d.cards.append(Card.new(Card.Suit.JOKER, 0))
	d.shuffle()
	return d

func shuffle() -> void:
	cards.shuffle()

func draw() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_back()

func draw_many(n: int) -> Array[Card]:
	var drawn: Array[Card] = []
	for i in range(n):
		var c := draw()
		if c != null:
			drawn.append(c)
	return drawn

func size() -> int:
	return cards.size()

func add_cards(new_cards: Array[Card]) -> void:
	cards.append_array(new_cards)
	shuffle()
