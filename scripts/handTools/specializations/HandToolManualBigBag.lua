--
-- HandToolManualBigBag
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

HandToolManualBigBag = {}

---
HandToolManualBigBag.SPEC_TABLE_NAME = "spec_" .. g_currentModName .. ".handToolManualBigBag"

---
HandToolManualBigBag.TARGET_MASK = CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.VEHICLE
HandToolManualBigBag.VEHICLE_UNDERNEATH_MASK = CollisionFlag.VEHICLE
HandToolManualBigBag.TARGET_MAX_DISTANCE = 4
HandToolManualBigBag.MIN_DISCHARGE_HEIGHT = 0.3

---Register all functions from the specialization that can be called on handTool level
-- @param table handToolType hand tool type
function HandToolManualBigBag.registerFunctions(handToolType)
  SpecializationUtil.registerFunction(handToolType, "getManualBigBagHasUnloadTarget", HandToolManualBigBag.getHasUnloadTarget)
  SpecializationUtil.registerFunction(handToolType, "getManualBigBagUnloadVehicle", HandToolManualBigBag.getUnloadVehicle)
  SpecializationUtil.registerFunction(handToolType, "isManualBigBagAboveMinHeight", HandToolManualBigBag.isAboveMinHeight)
  SpecializationUtil.registerFunction(handToolType, "getManualBigBagHasVehicleUnderneath", HandToolManualBigBag.getHasVehicleUnderneath)
  SpecializationUtil.registerFunction(handToolType, "manualBigBagVehicleUnderneathRaycastCallback", HandToolManualBigBag.vehicleUnderneathRaycastCallback)
end

---Register all events that should be called for this specialization
-- @param table handToolType hand tool type
function HandToolManualBigBag.registerEventListeners(handToolType)
  SpecializationUtil.registerEventListener(handToolType, "onLoad", HandToolManualBigBag)
  SpecializationUtil.registerEventListener(handToolType, "onDelete", HandToolManualBigBag)
  SpecializationUtil.registerEventListener(handToolType, "onUpdate", HandToolManualBigBag)
  SpecializationUtil.registerEventListener(handToolType, "onDraw", HandToolManualBigBag)
  SpecializationUtil.registerEventListener(handToolType, "onRegisterActionEvents", HandToolManualBigBag)
  SpecializationUtil.registerEventListener(handToolType, "onHeldStart", HandToolManualBigBag)
  SpecializationUtil.registerEventListener(handToolType, "onHeldEnd", HandToolManualBigBag)
end

---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function HandToolManualBigBag.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(HandToolHands, specializations)
end

---Called on loading
-- @param integer xmlFile xml file
-- @param string baseDirectory base directory
function HandToolManualBigBag:onLoad(xmlFile, baseDirectory)
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  spec.unloadVehicle = nil
  spec.toggleActionEventId = nil

  spec.actionText = g_i18n:getText("action_manualBigBag")
  spec.actionStopText = g_i18n:getText("action_stopManualBigBag")

  if self.isClient then
    spec.openCrosshair = self:createCrosshairOverlay("guiElementsManualBigBag.open_bigBag")
    if spec.openCrosshair ~= nil then
      spec.openCrosshair:setColor(nil, nil, nil, 0.25)
    end

    spec.closeCrosshair = self:createCrosshairOverlay("guiElementsManualBigBag.close_bigBag")
    if spec.closeCrosshair ~= nil then
      spec.closeCrosshair:setColor(nil, nil, nil, 0.25)
    end
  end
end

---Called on deleting
function HandToolManualBigBag:onDelete()
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  if spec.openCrosshair ~= nil then
    spec.openCrosshair:delete()
    spec.openCrosshair = nil
  end

  if spec.closeCrosshair ~= nil then
    spec.closeCrosshair:delete()
    spec.closeCrosshair = nil
  end
end

---Called when the hand tool is equipped and held
function HandToolManualBigBag:onHeldStart()
  local carryingPlayer = self:getCarryingPlayer()

  if carryingPlayer == nil or not carryingPlayer.isOwner then
    return
  end

  carryingPlayer.targeter:addTargetType(HandToolManualBigBag, HandToolManualBigBag.TARGET_MASK, 0.5, HandToolManualBigBag.TARGET_MAX_DISTANCE)
  carryingPlayer.targeter:addFilterToTargetType(HandToolManualBigBag, function(hitNode)
    local object = g_currentMission:getNodeObject(hitNode)

    if object == nil or object.isDeleted or object.isDeleting or (object.spec_bigBag == nil and object.spec_pallet == nil) then
      return false
    end

    local dischargeSpec = object.spec_dischargeable

    return object:getIsSynchronized() and dischargeSpec ~= nil and object:getCurrentDischargeNode() ~= nil and g_currentMission.accessHandler:canPlayerAccess(object, carryingPlayer)
  end)
end

---Called when the hand tool ceases to be held
function HandToolManualBigBag:onHeldEnd()
  local carryingPlayer = self:getCarryingPlayer()
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  spec.unloadVehicle = nil

  if carryingPlayer == nil or not carryingPlayer.isOwner then
    return
  end

  carryingPlayer.targeter:removeTargetType(HandToolManualBigBag)
end

---Called on register action events
function HandToolManualBigBag:onRegisterActionEvents()
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]
  spec.toggleActionEventId = nil

  if not self:getIsActiveForInput(true) then
    return
  end

  local eventAdded, actionEventId = self:addActionEvent(InputAction.TOGGLE_UNLOAD_ON_FOOT, self, HandToolManualBigBag.onToggleUnloadAction, false, true, false, true, nil)

  if not eventAdded then
    return
  end

  g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
  g_inputBinding:setActionEventText(actionEventId, spec.actionText)
  g_inputBinding:setActionEventActive(actionEventId, false)
  spec.toggleActionEventId = actionEventId
end

---Called on update
-- @param float dt time since last call in ms
function HandToolManualBigBag:onUpdate(dt)
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]
  local carryingPlayer = self:getCarryingPlayer()

  if carryingPlayer == nil or not carryingPlayer.isOwner or not self:getIsHeld() then
    spec.unloadVehicle = nil
    return
  end

  spec.unloadVehicle = self:getManualBigBagUnloadVehicle(carryingPlayer)

  if spec.toggleActionEventId == nil then
    return
  end

  local isActive = spec.unloadVehicle ~= nil
  g_inputBinding:setActionEventActive(spec.toggleActionEventId, isActive)

  if isActive then
    spec.unloadVehicle:raiseActive()

    if spec.unloadVehicle:getDischargeState() == Dischargeable.DISCHARGE_STATE_OFF then
      g_inputBinding:setActionEventText(spec.toggleActionEventId, spec.actionText)
    else
      g_inputBinding:setActionEventText(spec.toggleActionEventId, spec.actionStopText)
    end
  end
end

---Called on draw
function HandToolManualBigBag:onDraw()
  if not self:getManualBigBagHasUnloadTarget() then
    return
  end

  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]
  local carryingPlayer = self:getCarryingPlayer()

  if carryingPlayer ~= nil and carryingPlayer.isOwner and carryingPlayer.camera ~= nil and carryingPlayer.camera.isFirstPerson then
    if spec.unloadVehicle:getDischargeState() == Dischargeable.DISCHARGE_STATE_OFF then
      spec.openCrosshair:render()
    else
      spec.closeCrosshair:render()
    end
  end
end

---Toggles the unload action for the targeted big bag or pallet
-- @param integer actionId the action event id
-- @param float inputValue the input value
function HandToolManualBigBag:onToggleUnloadAction(actionId, inputValue)
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]
  local carryingPlayer = self:getCarryingPlayer()

  if carryingPlayer == nil or not carryingPlayer.isOwner or not self:getIsHeld() then
    spec.unloadVehicle = nil
    return
  end

  local unloadVehicle = self:getManualBigBagUnloadVehicle(carryingPlayer)
  spec.unloadVehicle = unloadVehicle

  if unloadVehicle == nil then
    return
  end

  local dischargeNode = unloadVehicle:getCurrentDischargeNode()
  local isDischargeActive = unloadVehicle:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF

  if isDischargeActive then
    unloadVehicle:setManualDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
    return
  end

  if not self:isManualBigBagAboveMinHeight(unloadVehicle) then
    g_currentMission:showBlinkingWarning(g_i18n:getText("warning_unloadTargetTooLow"), 2000)
    return
  end

  -- discharge to object
  if unloadVehicle:getCanDischargeToObject(dischargeNode) then
    unloadVehicle:setManualDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
    return
  end

  -- discharge to ground
  if unloadVehicle:getCanDischargeToGround(dischargeNode) then
    if not unloadVehicle:getCanDischargeToLand(dischargeNode) then
      g_currentMission:showBlinkingWarning(g_i18n:getText("warning_youDontHaveAccessToThisLand"), 2000)
      return
    end

    local canDischarge = unloadVehicle:getCanDischargeAtPosition(dischargeNode)

    if canDischarge then
      local hitObject = dischargeNode.dischargeHitObject
      local isOnVehicle = hitObject ~= nil and hitObject.isa ~= nil and hitObject:isa(Vehicle)

      if not isOnVehicle then
        isOnVehicle = self:getManualBigBagHasVehicleUnderneath(dischargeNode, unloadVehicle)
      end

      canDischarge = not isOnVehicle
    end

    if canDischarge then
      unloadVehicle:setManualDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
    else
      g_currentMission:showBlinkingWarning(g_i18n:getText("warning_actionNotAllowedHere"), 2000)
    end

    return
  end

  -- show discharge-specific warning
  local warningText = unloadVehicle:getDischargeNotAllowedWarning(dischargeNode)
  g_currentMission:showBlinkingWarning(warningText, 2000)
end

---Gets the targeted dischargeable vehicle (BigBag/Pallet) from the player's targeter
-- @param table player the carrying player
-- @return table|nil the targeted vehicle or nil
function HandToolManualBigBag:getUnloadVehicle(player)
  if player == nil or player.targeter == nil then
    return nil
  end

  local targetNode = player.targeter:getClosestTargetedNodeFromType(HandToolManualBigBag)

  if targetNode == nil or targetNode == 0 or not entityExists(targetNode) then
    return nil
  end

  local object = g_currentMission:getNodeObject(targetNode)

  if object == nil or object.isDeleted or object.isDeleting or (object.spec_bigBag == nil and object.spec_pallet == nil) or not object:getIsSynchronized() then
    return nil
  end

  local dischargeSpec = object.spec_dischargeable

  if dischargeSpec == nil or object:getCurrentDischargeNode() == nil or not g_currentMission.accessHandler:canPlayerAccess(object, player) then
    return nil
  end

  return object
end

---Checks if the vehicle's discharge node is above the minimum height from the ground
-- @param table object the vehicle to check
-- @return boolean true if above the minimum height
function HandToolManualBigBag:isAboveMinHeight(object)
  if object == nil or object.spec_dischargeable == nil then
    return false
  end

  local dischargeNode = object:getCurrentDischargeNode()

  if dischargeNode == nil or dischargeNode.node == nil or dischargeNode.node == 0 or not entityExists(dischargeNode.node) then
    return false
  end

  local x, y, z = getWorldTranslation(dischargeNode.node)
  local terrainHeight = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)

  return (y - terrainHeight) > HandToolManualBigBag.MIN_DISCHARGE_HEIGHT
end

---Checks if a manual unload object is currently targeted
-- @return boolean hasTarget true if the player has a manual unload target
function HandToolManualBigBag:getHasUnloadTarget()
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  return spec.unloadVehicle ~= nil and spec.toggleActionEventId ~= nil and spec.openCrosshair ~= nil and spec.closeCrosshair ~= nil
end

---Checks via synchronous physics raycast if a vehicle is under the Big Bag's discharge node
-- @param table dischargeNode the discharge node of the Big Bag
-- @param table bigbagObject the Big Bag object itself (to exclude from results)
-- @return boolean true if a vehicle is directly underneath
function HandToolManualBigBag:getHasVehicleUnderneath(dischargeNode, bigbagObject)
  local raycast = dischargeNode ~= nil and dischargeNode.raycast or nil

  if raycast == nil or raycast.node == nil or raycast.node == 0 or not entityExists(raycast.node) then
    return false
  end

  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  spec.vehicleRaycastResult = false
  spec.vehicleRaycastIgnore = bigbagObject

  local x, y, z = getWorldTranslation(raycast.node)
  y = y + (raycast.yOffset or 0)

  local dx, dy, dz = 0, -1, 0
  if not raycast.useWorldNegYDirection then
    dx, dy, dz = localDirectionToWorld(raycast.node, 0, -1, 0)
  end

  raycastAll(x, y, z, dx, dy, dz, dischargeNode.maxDistance, "manualBigBagVehicleUnderneathRaycastCallback", self, HandToolManualBigBag.VEHICLE_UNDERNEATH_MASK)

  local result = spec.vehicleRaycastResult
  spec.vehicleRaycastResult = nil
  spec.vehicleRaycastIgnore = nil

  return result
end

---Raycast callback for vehicle-underneath detection
-- @param integer hitActorId the hit actor id
-- @param float x hit position x
-- @param float y hit position y
-- @param float z hit position z
-- @param float distance hit distance
function HandToolManualBigBag:vehicleUnderneathRaycastCallback(hitActorId, x, y, z, distance)
  if hitActorId == nil or hitActorId == 0 then
    return false
  end

  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]
  local object = g_currentMission:getNodeObject(hitActorId)

  if object == spec.vehicleRaycastIgnore then
    return true
  end

  if object ~= nil and object.isa ~= nil and object:isa(Vehicle) then
    spec.vehicleRaycastResult = true
    return false
  end

  return true
end
