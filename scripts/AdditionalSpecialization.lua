--
-- AdditionalSpecialization
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

local modName = g_currentModName

-- specializations to add
local additionalSpecsBySpecialization = {
  ["pallet"] = {
    modName .. ".manualBigBag",
  },
  ["bigBag"] = {
    modName .. ".manualBigBag",
  },
}

-- specializations to add to hand tool types
local additionalHandToolSpecsBySpecialization = {
  ["hands"] = {
    modName .. ".handToolManualBigBag",
  },
}

AdditionalSpecialization = {}

---Finalize types
-- @param table typeManager type manager
function AdditionalSpecialization.finalizeTypes(typeManager)
  if not g_modIsLoaded[modName] then
    return
  end

  local specsBySpecialization

  if typeManager.typeName == "vehicle" then
    specsBySpecialization = additionalSpecsBySpecialization
  elseif typeManager.typeName == "handTool" then
    specsBySpecialization = additionalHandToolSpecsBySpecialization
  end

  if specsBySpecialization ~= nil then
    for typeName, typeEntry in pairs(typeManager:getTypes()) do
      for specIndex = #typeEntry.specializationNames, 1, -1 do
        local currentSpecName = typeEntry.specializationNames[specIndex]
        local additionalSpecs = specsBySpecialization[currentSpecName]

        if additionalSpecs ~= nil then
          for i = 1, #additionalSpecs do
            local additionalSpec = additionalSpecs[i]

            if typeEntry.specializationsByName[additionalSpec] == nil then
              typeManager:addSpecialization(typeName, additionalSpec)
            end
          end
        end
      end
    end
  end
end

---
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, AdditionalSpecialization.finalizeTypes)
