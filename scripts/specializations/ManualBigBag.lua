--
-- ManualBigBag
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

ManualBigBag = {}

---Returns if all prerequisite specializations are present
-- @param table specializations specializations table
-- @return boolean true if all prerequisites are present
function ManualBigBag.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Dischargeable, specializations)
end

function ManualBigBag.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDischargeNodeAutomaticDischarge", ManualBigBag.getDischargeNodeAutomaticDischarge)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "setDischargeState", ManualBigBag.setDischargeState)
end

function ManualBigBag.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", ManualBigBag)
  SpecializationUtil.registerEventListener(vehicleType, "onDischargeTargetObjectChanged", ManualBigBag)
end

---Configures the default discharge raycast equally on the server and every client
function ManualBigBag:onLoad()
  for _, dischargeNode in ipairs(self.spec_dischargeable.dischargeNodes) do
    local raycast = dischargeNode.raycast

    if raycast.yOffset < 0.5 then
      raycast.yOffset = 0.8
    end
  end
end

---Switch an already open spout to a newly detected discharge target
-- @param table|nil object the new discharge target
function ManualBigBag:onDischargeTargetObjectChanged(object)
  if not self.isServer or object == nil then
    return
  end

  local spec = self.spec_dischargeable

  if spec.currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND and self:getCanToggleDischargeToObject() and self:getCanDischargeToObject(spec.currentDischargeNode) then
    self:handleFoundDischargeObject(spec.currentDischargeNode)
  end
end

---Allow switching to an object only after manually starting ground discharge
-- @param function superFunc original function
-- @param table dischargeNode discharge node
-- @return boolean true if should auto-discharge to object
function ManualBigBag:getDischargeNodeAutomaticDischarge(superFunc, dischargeNode)
  return self.spec_dischargeable.currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND
end

---Ensure the vehicle stays awake when discharge state is set manually via handtools
-- @param function superFunc original function
-- @param integer state discharge state
-- @param boolean noEventSend no event send
function ManualBigBag:setDischargeState(superFunc, state, noEventSend)
  if state ~= Dischargeable.DISCHARGE_STATE_OFF then
    self:raiseActive()
  end

  return superFunc(self, state, noEventSend)
end
