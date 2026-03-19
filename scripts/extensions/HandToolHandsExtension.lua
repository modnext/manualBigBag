--
-- HandToolHandsExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

---Hide default crosshairs when manual BigBag crosshair is active
local function onHandToolHandsOnDraw(handTool, superFunc)
  if handTool.getHasUnloadTarget ~= nil and handTool:getHasUnloadTarget() then
    return
  end

  superFunc(handTool)
end

---
HandToolHands.onDraw = Utils.overwrittenFunction(HandToolHands.onDraw, onHandToolHandsOnDraw)
