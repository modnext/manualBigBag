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
HandToolManualBigBag.TARGET_MAX_DISTANCE = 4
HandToolManualBigBag.MIN_DISCHARGE_HEIGHT = 0.3

---Register all functions from the specialization that can be called on handTool level
-- @param table handToolType hand tool type
function HandToolManualBigBag.registerFunctions(handToolType)
  SpecializationUtil.registerFunction(handToolType, "getHasUnloadTarget", HandToolManualBigBag.getHasUnloadTarget)
  SpecializationUtil.registerFunction(handToolType, "getUnloadVehicle", HandToolManualBigBag.getUnloadVehicle)
  SpecializationUtil.registerFunction(handToolType, "isAboveMinHeight", HandToolManualBigBag.isAboveMinHeight)
  SpecializationUtil.registerFunction(handToolType, "getHasVehicleUnderneath", HandToolManualBigBag.getHasVehicleUnderneath)
  SpecializationUtil.registerFunction(handToolType, "vehicleUnderneathRaycastCallback", HandToolManualBigBag.vehicleUnderneathRaycastCallback)
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
    spec.openCrosshair:setColor(nil, nil, nil, 0.25)

    spec.closeCrosshair = self:createCrosshairOverlay("guiElementsManualBigBag.close_bigBag")
    spec.closeCrosshair:setColor(nil, nil, nil, 0.25)
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
end

---Called when the hand tool ceases to be held
function HandToolManualBigBag:onHeldEnd()
  local carryingPlayer = self:getCarryingPlayer()

  if carryingPlayer == nil or not carryingPlayer.isOwner then
    return
  end

  carryingPlayer.targeter:removeTargetType(HandToolManualBigBag)
end

---Called on register action events
function HandToolManualBigBag:onRegisterActionEvents()
  if not self:getIsActiveForInput(true) then
    return
  end

  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  local _, actionEventId = self:addActionEvent(InputAction.TOGGLE_UNLOAD_ON_FOOT, self, HandToolManualBigBag.onToggleUnloadAction, false, true, false, true, nil)
  g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
  g_inputBinding:setActionEventText(actionEventId, spec.actionText)
  g_inputBinding:setActionEventActive(actionEventId, false)
  spec.toggleActionEventId = actionEventId
end

---Called on update
-- @param float dt time since last call in ms
function HandToolManualBigBag:onUpdate(dt)
  local carryingPlayer = self:getCarryingPlayer()

  if carryingPlayer == nil or not carryingPlayer.isOwner then
    return
  end

  if not self:getIsHeld() then
    return
  end

  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  spec.unloadVehicle = self:getUnloadVehicle(carryingPlayer)

  local isActive = spec.unloadVehicle ~= nil

  g_inputBinding:setActionEventActive(spec.toggleActionEventId, isActive)

  if isActive then
    local dischargeSpec = spec.unloadVehicle.spec_dischargeable

    if dischargeSpec.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
      g_inputBinding:setActionEventText(spec.toggleActionEventId, spec.actionText)
    else
      g_inputBinding:setActionEventText(spec.toggleActionEventId, spec.actionStopText)
    end
  end
end

---Called on draw
function HandToolManualBigBag:onDraw()
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  if spec.unloadVehicle == nil then
    return
  end

  local carryingPlayer = self:getCarryingPlayer()

  if carryingPlayer ~= nil and carryingPlayer.isOwner then
    if carryingPlayer.camera.isFirstPerson then
      local dischargeSpec = spec.unloadVehicle.spec_dischargeable

      if dischargeSpec.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
        spec.openCrosshair:render()
      else
        spec.closeCrosshair:render()
      end
    end
  end
end

---Toggle the unload action for the targeted big bag or pallet
-- @param integer actionId the action event id
-- @param float inputValue the input value
function HandToolManualBigBag:onToggleUnloadAction(actionId, inputValue)
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]
  local unloadVehicle = spec.unloadVehicle

  if unloadVehicle == nil then
    return
  end

  local dischargeSpec = unloadVehicle.spec_dischargeable
  local dischargeNode = dischargeSpec.currentDischargeNode

  if dischargeNode == nil then
    return
  end

  local isDischargeActive = dischargeSpec.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF

  if isDischargeActive then
    unloadVehicle:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
  else
    local hitObject = dischargeNode.dischargeHitObject
    local isOnVehicle = hitObject ~= nil and hitObject:isa(Vehicle)

    if not isOnVehicle then
      isOnVehicle = self:getHasVehicleUnderneath(dischargeNode, unloadVehicle)
    end

    local canDischargeToObject = unloadVehicle:getCanDischargeToObject(dischargeNode)
    local canDischargeToGround = unloadVehicle:getCanDischargeToGround(dischargeNode) and unloadVehicle:getCanDischargeToLand(dischargeNode) and unloadVehicle:getCanDischargeAtPosition(dischargeNode)

    if canDischargeToObject then
      unloadVehicle:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
    elseif canDischargeToGround and not isOnVehicle then
      unloadVehicle:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
    end
  end
end

---Gets the targeted dischargeable vehicle (BigBag/Pallet) from the player's targeter
-- @param table player the carrying player
-- @return table|nil unloadVehicle the targeted vehicle or nil
function HandToolManualBigBag:getUnloadVehicle(player)
  local targetNode = player.targeter:getClosestTargetedNodeFromType(HandToolManualBigBag)

  if targetNode == nil then
    return nil
  end

  local object = g_currentMission:getNodeObject(targetNode)

  if object == nil then
    return nil
  end

  local dischargeSpec = object.spec_dischargeable

  if dischargeSpec == nil or #dischargeSpec.dischargeNodes == 0 then
    return nil
  end

  local hasAccess = g_currentMission.accessHandler:canPlayerAccess(object, player)
  local dischargeNode = dischargeSpec.currentDischargeNode

  if not hasAccess or dischargeNode == nil then
    return nil
  end

  -- object:raiseActive()

  if dischargeNode.raycast ~= nil and (dischargeNode.raycast.yOffset or 0) < 0.5 then
    dischargeNode.raycast.yOffset = 0.8
  end

  local isDischargeActive = dischargeSpec.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF

  if isDischargeActive then
    return object
  end

  if not self:isAboveMinHeight(object) then
    return nil
  end

  local hitObject = dischargeNode.dischargeHitObject
  local isOnVehicle = hitObject ~= nil and hitObject:isa(Vehicle)

  if not isOnVehicle then
    isOnVehicle = self:getHasVehicleUnderneath(dischargeNode, object)
  end

  local canDischargeToObject = object:getCanDischargeToObject(dischargeNode)
  local canDischargeToGround = object:getCanDischargeToGround(dischargeNode) and object:getCanDischargeToLand(dischargeNode) and object:getCanDischargeAtPosition(dischargeNode)
  local hasValidTarget = canDischargeToObject or (canDischargeToGround and not isOnVehicle)

  return hasValidTarget and object or nil
end

---Checks if the vehicle's discharge node is above the minimum height from the ground
-- @param table object the vehicle to check
-- @return boolean isAboveMinHeight true if above the minimum height
function HandToolManualBigBag:isAboveMinHeight(object)
  local dischargeSpec = object.spec_dischargeable
  local dischargeNode = dischargeSpec.currentDischargeNode

  if dischargeNode == nil or dischargeNode.node == nil then
    return false
  end

  local x, y, z = getWorldTranslation(dischargeNode.node)
  local terrainHeight = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)

  return (y - terrainHeight) > HandToolManualBigBag.MIN_DISCHARGE_HEIGHT
end

---Checks if a valid unload target is currently available
-- @return boolean hasTarget true if the player has a valid unload target
function HandToolManualBigBag:getHasUnloadTarget()
  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  return spec.unloadVehicle ~= nil
end

---Checks via synchronous physics raycast if a vehicle is under the Big Bag's discharge node
-- @param table dischargeNode the discharge node of the Big Bag
-- @param table bigbagObject the Big Bag object itself (to exclude from results)
-- @return boolean true if a vehicle is directly underneath
function HandToolManualBigBag:getHasVehicleUnderneath(dischargeNode, bigbagObject)
  if dischargeNode == nil or dischargeNode.raycast == nil or dischargeNode.raycast.node == nil then
    return false
  end

  local spec = self[HandToolManualBigBag.SPEC_TABLE_NAME]

  spec.vehicleRaycastResult = false
  spec.vehicleRaycastIgnore = bigbagObject

  local x, y, z = getWorldTranslation(dischargeNode.raycast.node)
  y = y + (dischargeNode.raycast.yOffset or 0)

  local dx, dy, dz = 0, -1, 0
  if not dischargeNode.raycast.useWorldNegYDirection then
    dx, dy, dz = localDirectionToWorld(dischargeNode.raycast.node, 0, -1, 0)
  end

  raycastAll(x, y, z, dx, dy, dz, dischargeNode.maxDistance, "vehicleUnderneathRaycastCallback", self, HandToolManualBigBag.TARGET_MASK)

  return spec.vehicleRaycastResult
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

  if object ~= nil and object:isa(Vehicle) then
    spec.vehicleRaycastResult = true
    return false
  end

  return true
end
