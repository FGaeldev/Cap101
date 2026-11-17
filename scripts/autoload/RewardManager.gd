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

# --- Pesos (docs/ECONOMY_PLAN.md) --------------------------------------------
# The only writer of GameState.pesos. Quizzes are pocket money; quests and
# selling are the real income. Money is never taken away: a wrong answer earns
# less, and only the player's own choice to buy or ride spends it.

## Story quiz or minigame (dialogue line), passed / failed.
const STORY_ACTIVITY_PESOS := {true: 5, false: 2}
## NPC Review (quiz, hangman, memory match), passed / failed.
const REVIEW_PESOS := {true: 3, false: 1}
## Most pesos Review can earn per daily day, so it can't be farmed.
const REVIEW_DAILY_CAP: int = 15
## Lola's morning allowance: the floor that keeps a cheap fare affordable.
const ALLOWANCE_PESOS: int = 10
## Only while the player has less than this.
const ALLOWANCE_BELOW: int = 20
## Hour the allowance can be given (the family's morning).
const ALLOWANCE_HOUR: float = 6.0
## Allowance starts once the player lives with Lola in Aklan.
const ALLOWANCE_FLAG := "seen_chapter2_scene0"

func _ready() -> void:
	_connect_clock.call_deferred()  # DayNightManager loads after this autoload

func _connect_clock() -> void:
	DayNightManager.hour_changed.connect(func(_h): check_allowance())
	DayNightManager.daily_reset.connect(check_allowance)

## Adds pesos and shows a "+₱N" toast. `reason` is the toast header.
func award_pesos(amount: int, reason: String = "Pesos") -> void:
	if amount <= 0:
		return
	GameState.add_pesos(amount)
	_queue_popup("pesos", {"amount": amount, "reason": reason})

## Spends pesos if the player has enough. False (and nothing spent) otherwise.
func spend_pesos(amount: int) -> bool:
	if amount < 0 or amount > GameState.pesos:
		return false
	if amount > 0:
		GameState.add_pesos(-amount)
	return true

## A story quiz/minigame resolved (DialogueUI's dialogue-line paths).
func award_story_activity(passed: bool) -> void:
	award_pesos(STORY_ACTIVITY_PESOS[passed], "Well done" if passed else "Good try")

## An NPC Review activity resolved. Capped per daily day.
func award_review(passed: bool) -> void:
	var today: int = GameState.daily_date()
	if GameState.review_earn_date != today:
		GameState.review_earn_date = today
		GameState.review_earned_today = 0
	var amount: int = mini(REVIEW_PESOS[passed], REVIEW_DAILY_CAP - GameState.review_earned_today)
	if amount <= 0:
		return
	GameState.review_earned_today += amount
	award_pesos(amount, "Review")

## Morning allowance from Lola: once per daily day, after ALLOWANCE_HOUR, only
## while the player is low on money. Safe to call any time.
func check_allowance() -> void:
	if not GameState.session_active or not GameState.get_flag(ALLOWANCE_FLAG):
		return
	if GameState.time_of_day < ALLOWANCE_HOUR:
		return
	var today: int = GameState.daily_date()
	if GameState.allowance_date == today:
		return
	GameState.allowance_date = today
	if GameState.pesos < ALLOWANCE_BELOW:
		award_pesos(ALLOWANCE_PESOS, "From Lola")
		GameState.save_game()
