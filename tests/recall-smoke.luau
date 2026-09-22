-- Run through tools/test-recall.py against RecallLogic.

assert(RecallLogic.breaksChannel("move") == true)
assert(RecallLogic.breaksChannel("attack") == true)
assert(RecallLogic.breaksChannel("attackMove") == true)
assert(RecallLogic.breaksChannel("ability") == true)
assert(RecallLogic.breaksChannel("stop") == true)
assert(RecallLogic.breaksChannel("ward") == true)
assert(RecallLogic.breaksChannel("control") == true)
assert(RecallLogic.breaksChannel("lens") == true)
assert(RecallLogic.breaksChannel("damage") == true)

assert(RecallLogic.breaksChannel("camera") == false)
assert(RecallLogic.breaksChannel("help") == false)
assert(RecallLogic.breaksChannel("emote") == false)
assert(RecallLogic.breaksChannel("ping") == false)
assert(RecallLogic.breaksChannel("shop") == false)
assert(RecallLogic.breaksChannel("ui") == false)
assert(RecallLogic.breaksChannel("") == false)

-- Fresh press cancels. A direction already held when the channel started does not,
-- until that input returns to rest and moves again.
assert(RecallLogic.isNewMoveOrder(false, true, false) == true)
assert(RecallLogic.isNewMoveOrder(false, false, false) == false)
assert(RecallLogic.isNewMoveOrder(true, true, false) == false)
assert(RecallLogic.isNewMoveOrder(true, false, false) == false)
assert(RecallLogic.isNewMoveOrder(true, true, true) == true)
assert(RecallLogic.isNewMoveOrder(true, false, true) == false)

assert(RecallLogic.movedTooFar(2.5, 2.5) == false)
assert(RecallLogic.movedTooFar(2.51, 2.5) == true)
assert(RecallLogic.movedTooFar(0, 2.5) == false)

print("PASS: recall cancels on new orders, not camera/shop/emote, and not a held move")
