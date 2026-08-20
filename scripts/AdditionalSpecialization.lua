--
-- AdditionalSpecialization
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

local modName = g_currentModName

-- specializations to add by type manager
local additionalSpecsByType = {
  ["vehicle"] = {
    prerequisite = Dischargeable,
    specsBySpecialization = {
      ["pallet"] = {
        modName .. ".manualBigBag",
      },
      ["bigBag"] = {
        modName .. ".manualBigBag",
      },
    },
  },
  ["handTool"] = {
    prerequisite = HandToolHands,
    specsBySpecialization = {
      ["hands"] = {
        modName .. ".handToolManualBigBag",
      },
    },
  },
}

AdditionalSpecialization = {}

---Finalize types
-- @param table typeManager type manager
function AdditionalSpecialization.finalizeTypes(typeManager)
  if not g_modIsLoaded[modName] then
    return
  end

  local typeConfig = additionalSpecsByType[typeManager.typeName]

  if typeConfig == nil then
    return
  end

  for typeName, typeEntry in pairs(typeManager:getTypes()) do
    if SpecializationUtil.hasSpecialization(typeConfig.prerequisite, typeEntry.specializations) then
      for baseSpecializationName, specializationsToAdd in pairs(typeConfig.specsBySpecialization) do
        if typeEntry.specializationsByName[baseSpecializationName] ~= nil then
          for _, specializationName in ipairs(specializationsToAdd) do
            if typeEntry.specializationsByName[specializationName] == nil then
              typeManager:addSpecialization(typeName, specializationName)
            end
          end
        end
      end
    end
  end
end

---
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, AdditionalSpecialization.finalizeTypes)
