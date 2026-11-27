extends Resource
class_name CardMessageWord
## A word of the truth the Message can be given (the designer's twist 10, 2026-11-27: "Allow the player to choose how the Message
## grows and what effects it gets from the events which will have random options"). One file in data/card_message_words/, keyed by
## its file name. An event offers some at random (CardRun.message_offers); the one chosen is a line of the Message from then on, doing
## its Effect each time the Message is played (every enemy for an Apply or Damage, the player for the rest).

## The words themselves, as the Message shows them.
@export_multiline var line := ""
## What it does each time the Message is played; its Amount to begin with.
@export var effect: CardEffect
## How much its amount grows each time the word is deepened.
@export_range(1, 20) var step := 1
## How likely it is to be offered against the others.
@export_range(1, 10) var weight := 1
