# open-tabletop
# Copyright (c) 2020 drwhut
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

extends Control

signal card_in_hand_requested(card)
signal card_out_hand_requested(card_texture)
signal piece_requested(piece_entry)

const HIGHLIGHT_COLOUR = Color(0.25, 1.0, 1.0, 0.5)

onready var _hand = $Hand
onready var _hand_highlight = $Hand/HandHighlight
onready var _objects_dialog = $ObjectsDialog
onready var _objects_tree = $ObjectsDialog/ObjectsTree

var _grabbed_card_from_hand: CardTextureRect = null
var _holding_card = false
var _mouse_in_hand = false

func add_card_to_hand(card: Card, front_face: bool) -> void:
	var texture_rect = _create_card_half_texture(card, front_face)
	_hand.add_child(texture_rect)

func remove_card_from_hand(card: Card) -> void:
	for card_texture in _hand.get_children():
		if card_texture is CardTextureRect:
			if card_texture.card == card:
				_hand.remove_child(card_texture)
				card_texture.queue_free()

func set_piece_tree_from_db(pieces: Dictionary) -> void:
	var root = _objects_tree.create_item()
	_objects_tree.set_hide_root(true)
	
	for game in pieces:
		_add_game_to_tree(game, pieces[game])

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if (not event.is_pressed()) and _grabbed_card_from_hand:
				_grabbed_card_from_hand = null
	
	elif event is InputEventMouseMotion:
		if _grabbed_card_from_hand:
			var hand_rect = Rect2(_hand.rect_position, _hand.rect_size)
			if not hand_rect.has_point(event.global_position):
				emit_signal("card_out_hand_requested", _grabbed_card_from_hand)

func _add_game_to_tree(game_name: String, game_pieces: Dictionary) -> void:
	var game_node = _objects_tree.create_item(_objects_tree.get_root())
	game_node.set_text(0, game_name)
	
	var dice_node = _objects_tree.create_item(game_node)
	dice_node.set_text(0, "Dice")
	
	_add_type_to_tree(dice_node, game_pieces, "d4", "d4")
	_add_type_to_tree(dice_node, game_pieces, "d6", "d6")
	_add_type_to_tree(dice_node, game_pieces, "d8", "d8")
	
	# If there are no dice in this game, delete the dice node.
	if not dice_node.get_children():
		dice_node.free()
	
	_add_type_to_tree(game_node, game_pieces, "cards", "Cards")
	_add_type_to_tree(game_node, game_pieces, "pieces", "Pieces")

func _add_piece_to_tree(parent: TreeItem, piece: Dictionary) -> TreeItem:
	var node = _objects_tree.create_item(parent)
	node.set_text(0, piece["name"])
	
	# Keep the piece entry in the node so we can use it later.
	node.set_metadata(0, piece)
	
	return node

func _add_type_to_tree(parent: TreeItem, game_pieces: Dictionary,
	type_name: String, display_name: String) -> void:
	
	if game_pieces.has(type_name):
			
		var node = _objects_tree.create_item(parent)
		node.set_text(0, display_name)
		
		var array: Array = game_pieces[type_name]
		
		if array.size() > 0:
			for piece in array:
				_add_piece_to_tree(node, piece)
		else:
			node.free()

func _create_card_half_texture(card: Card, front_face: bool) -> CardTextureRect:
	var card_entry = card.piece_entry
	
	var texture = load(card_entry["texture_path"])
	texture.flags = 0
	
	var texture_rect = CardTextureRect.new()
	texture_rect.card = card
	texture_rect.front_face = front_face
	texture_rect.rect_min_size = Vector2(62, 100)
	texture_rect.texture = texture
	
	texture_rect.connect("clicked_on", self, "_on_card_texture_clicked")
	
	return texture_rect

func _on_card_texture_clicked(card_texture: CardTextureRect) -> void:
	_grabbed_card_from_hand = card_texture
	_hand.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_ObjectsButton_pressed():
	_objects_dialog.popup_centered()

func _on_ObjectsTree_item_activated():
	var selected = _objects_tree.get_selected()
	
	# Check the selected item has metadata.
	if selected.get_metadata(0):
		emit_signal("piece_requested", selected.get_metadata(0))

func _on_Room_started_hovering_card(card):
	_holding_card = true
	_mouse_in_hand = false
	_hand.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_Room_stopped_hovering_card(card):
	if _mouse_in_hand:
		emit_signal("card_in_hand_requested", card)
	
	_holding_card = false
	_mouse_in_hand = false
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_Hand_mouse_entered():
	_mouse_in_hand = true

func _on_Hand_mouse_exited():
	_mouse_in_hand = false
