--
-- AdditionalSpecialization
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

local modName = g_currentModName

AdditionalSpecialization = {}

---Finalize types
-- @param table typeManager type manager
function AdditionalSpecialization.finalizeTypes(typeManager)
  if not g_modIsLoaded[modName] then
    return
  end

  if typeManager.typeName == "vehicle" then
    local specializationName = modName .. ".manualBigBag"

    for typeName, typeEntry in pairs(typeManager:getTypes()) do
      if SpecializationUtil.hasSpecialization(Dischargeable, typeEntry.specializations)
        and (typeEntry.specializationsByName.pallet ~= nil or typeEntry.specializationsByName.bigBag ~= nil)
        and typeEntry.specializationsByName[specializationName] == nil then
        typeManager:addSpecialization(typeName, specializationName)
      end
    end
  elseif typeManager.typeName == "handTool" then
    local specializationName = modName .. ".handToolManualBigBag"

    for typeName, typeEntry in pairs(typeManager:getTypes()) do
      if SpecializationUtil.hasSpecialization(HandToolHands, typeEntry.specializations)
        and typeEntry.specializationsByName.hands ~= nil
        and typeEntry.specializationsByName[specializationName] == nil then
        typeManager:addSpecialization(typeName, specializationName)
      end
    end
  end
end

---
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, AdditionalSpecialization.finalizeTypes)
