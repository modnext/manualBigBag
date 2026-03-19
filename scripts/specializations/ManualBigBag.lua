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

---Allow automatic discharge only if we are already manually discharging to the ground
-- @param function superFunc original function
-- @param table dischargeNode discharge node
-- @return boolean true if should auto-discharge to object
function ManualBigBag:getDischargeNodeAutomaticDischarge(superFunc, dischargeNode)
  local spec = self.spec_dischargeable

  if spec ~= nil and spec.currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND then
    return true
  end

  return false
end

---Ensure the vehicle stays awake when discharge state is set manually via handtools
-- @param function superFunc original function
-- @param integer state discharge state
-- @param boolean noEventSend no event send
function ManualBigBag:setDischargeState(superFunc, state, noEventSend)
  if state ~= Dischargeable.DISCHARGE_STATE_OFF then
    self:raiseActive()
  end

  superFunc(self, state, noEventSend)
end
