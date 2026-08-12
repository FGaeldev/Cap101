# RewardManager.gd — autoload. Sole writer for the Ch2 reward fields
# (TDD §7). ChallengeManager._grant_reward() redirects to grant_reward()
# here — GameState's add_stars/add_badge/add_stamp/add_memory_page/
# add_hint_tokens must be called ONLY through this file, never directly
# from gameplay code (register-on-ready/call-through-autoload pattern, TDD §2).
extends Node

## Emitted once per awarded item, in display order. Whatever UI owns reward
## popups listens here and calls advance_popup() once it has finished
## showing the front item, to pull the next queued one. Popup rendering
## itself is out of scope for this autoload — this only sequences.
signal popup_queued(kind: String, value)

var _popup_queue: Array = []   # Array of {"kind": String, "value": Variant}, FIFO display order

func award_stars(amount: int) -> void:
	if amount <= 0:
		return
	GameState.add_stars(amount)
	_queue_popup("stars", amount)

func award_badge(badge_id: String) -> void:
	if badge_id.is_empty():
		return
	GameState.add_badge(badge_id)
	_queue_popup("badge", badge_id)

func award_stamp(stamp_id: String) -> void:
	if stamp_id.is_empty():
		return
	GameState.add_stamp(stamp_id)
	_queue_popup("stamp", stamp_id)

func award_memory_page(page_id: String) -> void:
	if page_id.is_empty():
		return
	GameState.add_memory_page(page_id)
	_queue_popup("memory_page", page_id)

func award_hint_token(amount: int) -> void:
	if amount <= 0:
		return
	GameState.add_hint_tokens(amount)
	_queue_popup("hint_token", amount)

## Main entry point — matches ChallengeManager's reward dict shape exactly
## (TDD §6.5: stars/badge/stamp/memory_page/hint_tokens keys). Call order
## below IS popup display order: stars first, then badge/unlock, per GDD
## §3.7 reward-order notes. first_try gates memory_page specifically —
## Grandma Memory Pages reward mastery, not just completion.
func grant_reward(reward: Dictionary, first_try: bool) -> void:
	if reward.get("stars", 0) > 0:
		award_stars(reward["stars"])
	if reward.get("badge", "") != "":
		award_badge(reward["badge"])
	if reward.get("stamp", "") != "":
		award_stamp(reward["stamp"])
	if first_try and reward.get("memory_page", "") != "":
		award_memory_page(reward["memory_page"])
	if reward.get("hint_tokens", 0) > 0:
		award_hint_token(reward["hint_tokens"])

func _queue_popup(kind: String, value) -> void:
	_popup_queue.append({"kind": kind, "value": value})
	popup_queued.emit(kind, value)

## Called by the popup UI once it finishes displaying the front item, to
## drop it from the queue. No re-sort needed — grant_reward() already
## appends in the required display order, this stays strictly FIFO.
func advance_popup() -> void:
	if not _popup_queue.is_empty():
		_popup_queue.pop_front()

func has_pending_popups() -> bool:
	return not _popup_queue.is_empty()

func peek_next_popup() -> Dictionary:
	if _popup_queue.is_empty():
		return {}
	return _popup_queue[0]
