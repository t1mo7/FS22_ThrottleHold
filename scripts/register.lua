-- Adds the throttleHold specialization to every drivable, motorized vehicle type.

local modName = g_currentModName
local specName = modName .. ".throttleHold"

local function addThrottleHoldSpecialization(typeManager)
    if typeManager.typeName ~= "vehicle" then
        return
    end

    local numAdded = 0
    for typeName, typeEntry in pairs(typeManager:getTypes()) do
        if typeEntry.specializationsByName["drivable"] ~= nil
            and typeEntry.specializationsByName["motorized"] ~= nil
            and typeEntry.specializationsByName[specName] == nil then
            typeManager:addSpecialization(typeName, specName)
            numAdded = numAdded + 1
        end
    end

    print(string.format("[ThrottleHold] Added to %d vehicle types", numAdded))
end

TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, addThrottleHoldSpecialization)
