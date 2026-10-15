-- ThrottleHold
-- Keeps a vehicle applying a chosen amount of throttle while nobody is driving it,
-- so a stuck vehicle keeps pushing while you pull it out with another one.

ThrottleHold = {}

ThrottleHold.MOD_NAME = g_currentModName
ThrottleHold.SPEC_NAME = g_currentModName .. ".throttleHold"
ThrottleHold.SPEC_TABLE_NAME = "spec_" .. ThrottleHold.SPEC_NAME

ThrottleHold.PERCENT_MIN = 5
ThrottleHold.PERCENT_MAX = 100
ThrottleHold.PERCENT_STEP = 5
ThrottleHold.PERCENT_DEFAULT = 50

function ThrottleHold.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Drivable, specializations)
        and SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function ThrottleHold.initSpecialization()
    local schemaSavegame = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?)." .. ThrottleHold.SPEC_NAME
    schemaSavegame:register(XMLValueType.INT, key .. "#percent", "Throttle hold percentage", ThrottleHold.PERCENT_DEFAULT)
    schemaSavegame:register(XMLValueType.BOOL, key .. "#reverse", "Throttle hold drives in reverse", false)
end

function ThrottleHold.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setThrottleHoldState", ThrottleHold.setThrottleHoldState)
    SpecializationUtil.registerFunction(vehicleType, "getIsThrottleHoldApplying", ThrottleHold.getIsThrottleHoldApplying)
    SpecializationUtil.registerFunction(vehicleType, "getThrottleHoldAxis", ThrottleHold.getThrottleHoldAxis)
end

function ThrottleHold.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateVehiclePhysics", ThrottleHold.updateVehiclePhysics)
    if Motorized.getStopMotorOnLeave ~= nil then
        SpecializationUtil.registerOverwrittenFunction(vehicleType, "getStopMotorOnLeave", ThrottleHold.getStopMotorOnLeave)
    end
end

function ThrottleHold.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ThrottleHold)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ThrottleHold)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ThrottleHold)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ThrottleHold)
    SpecializationUtil.registerEventListener(vehicleType, "onPostUpdate", ThrottleHold)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", ThrottleHold)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ThrottleHold)
end

function ThrottleHold:onLoad(savegame)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]

    spec.isActive = false
    spec.percent = ThrottleHold.PERCENT_DEFAULT
    spec.isReverse = false
    spec.physicsUpdatedThisFrame = false
    spec.actionEvents = {}

    if savegame ~= nil and not savegame.resetVehicles then
        local key = savegame.key .. "." .. ThrottleHold.SPEC_NAME
        spec.percent = savegame.xmlFile:getValue(key .. "#percent", spec.percent)
        spec.isReverse = savegame.xmlFile:getValue(key .. "#reverse", spec.isReverse)
        spec.percent = MathUtil.clamp(spec.percent, ThrottleHold.PERCENT_MIN, ThrottleHold.PERCENT_MAX)
    end
end

-- The armed state is deliberately not saved: a vehicle should never drive off on its own after loading a savegame.
function ThrottleHold:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    xmlFile:setValue(key .. "#percent", spec.percent)
    xmlFile:setValue(key .. "#reverse", spec.isReverse)
end

function ThrottleHold:onReadStream(streamId, connection)
    local isActive = streamReadBool(streamId)
    local percent = streamReadUIntN(streamId, 7)
    local isReverse = streamReadBool(streamId)
    self:setThrottleHoldState(isActive, percent, isReverse, true)
end

function ThrottleHold:onWriteStream(streamId, connection)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    streamWriteBool(streamId, spec.isActive)
    streamWriteUIntN(streamId, spec.percent, 7)
    streamWriteBool(streamId, spec.isReverse)
end

function ThrottleHold:setThrottleHoldState(isActive, percent, isReverse, noEventSend)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]

    percent = MathUtil.clamp(percent, ThrottleHold.PERCENT_MIN, ThrottleHold.PERCENT_MAX)
    if spec.isActive == isActive and spec.percent == percent and spec.isReverse == isReverse then
        return
    end

    ThrottleHoldEvent.sendEvent(self, isActive, percent, isReverse, noEventSend)

    spec.isActive = isActive
    spec.percent = percent
    spec.isReverse = isReverse

    ThrottleHold.updateActionEventTexts(self)
end

-- True while the hold is armed and nobody (player or AI) is controlling the vehicle.
function ThrottleHold:getIsThrottleHoldApplying()
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    if not spec.isActive then
        return false
    end

    if self.getIsAIActive ~= nil and self:getIsAIActive() then
        return false
    end

    if self.getIsControlled ~= nil then
        return not self:getIsControlled()
    end

    return not self:getIsEntered()
end

function ThrottleHold:getThrottleHoldAxis()
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    local axis = spec.percent / 100
    if spec.isReverse then
        axis = -axis
    end
    return axis
end

function ThrottleHold:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    if self.isServer and self:getIsThrottleHoldApplying() then
        spec.physicsUpdatedThisFrame = true
        return superFunc(self, self:getThrottleHoldAxis(), 0, false, dt)
    end

    return superFunc(self, axisForward, axisSide, doHandbrake, dt)
end

function ThrottleHold:getStopMotorOnLeave(superFunc)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    if spec.isActive then
        return false
    end

    return superFunc(self)
end

function ThrottleHold:onLeaveVehicle(wasEntered)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    if self.isServer and spec.isActive and not self:getIsMotorStarted() then
        if self.getCanMotorRun == nil or self:getCanMotorRun() then
            self:startMotor()
        end
    end
end

function ThrottleHold:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    if not spec.isActive then
        return
    end

    if self:getIsThrottleHoldApplying() then
        -- unattended vehicles go to sleep; keep this one updating while the hold is armed
        self:raiseActive()
    elseif self.getIsEntered ~= nil and self:getIsEntered() then
        local direction = g_i18n:getText(spec.isReverse and "throttleHold_reverse" or "throttleHold_forward")
        g_currentMission:addExtraPrintText(string.format(g_i18n:getText("throttleHold_armedInfo"), spec.percent, direction))
    end
end

-- Drivable may or may not push physics for an unattended vehicle; if it didn't this frame, do it ourselves.
function ThrottleHold:onPostUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    if self.isServer and self:getIsThrottleHoldApplying() and not spec.physicsUpdatedThisFrame then
        self:updateVehiclePhysics(self:getThrottleHoldAxis(), 0, false, dt)
    end
    spec.physicsUpdatedThisFrame = false
end

function ThrottleHold:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if not self.isClient then
        return
    end

    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    self:clearActionEventsTable(spec.actionEvents)

    if isActiveForInputIgnoreSelection then
        local _, toggleId = self:addActionEvent(spec.actionEvents, InputAction.THROTTLEHOLD_TOGGLE, self, ThrottleHold.actionEventToggle, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(toggleId, GS_PRIO_HIGH)
        spec.toggleActionEventId = toggleId

        local _, upId = self:addActionEvent(spec.actionEvents, InputAction.THROTTLEHOLD_UP, self, ThrottleHold.actionEventChangePercent, false, true, false, true, 1)
        g_inputBinding:setActionEventTextPriority(upId, GS_PRIO_NORMAL)
        g_inputBinding:setActionEventText(upId, string.format(g_i18n:getText("throttleHold_up"), ThrottleHold.PERCENT_STEP))

        local _, downId = self:addActionEvent(spec.actionEvents, InputAction.THROTTLEHOLD_DOWN, self, ThrottleHold.actionEventChangePercent, false, true, false, true, -1)
        g_inputBinding:setActionEventTextPriority(downId, GS_PRIO_NORMAL)
        g_inputBinding:setActionEventText(downId, string.format(g_i18n:getText("throttleHold_down"), ThrottleHold.PERCENT_STEP))

        local _, directionId = self:addActionEvent(spec.actionEvents, InputAction.THROTTLEHOLD_DIRECTION, self, ThrottleHold.actionEventDirection, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(directionId, GS_PRIO_NORMAL)
        spec.directionActionEventId = directionId

        ThrottleHold.updateActionEventTexts(self)
    end
end

function ThrottleHold:updateActionEventTexts()
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    local direction = g_i18n:getText(spec.isReverse and "throttleHold_reverse" or "throttleHold_forward")

    if spec.toggleActionEventId ~= nil then
        local textKey = spec.isActive and "throttleHold_disarm" or "throttleHold_arm"
        g_inputBinding:setActionEventText(spec.toggleActionEventId, string.format(g_i18n:getText(textKey), spec.percent, direction))
    end

    if spec.directionActionEventId ~= nil then
        g_inputBinding:setActionEventText(spec.directionActionEventId, string.format(g_i18n:getText("throttleHold_direction"), direction))
    end
end

function ThrottleHold.actionEventToggle(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    self:setThrottleHoldState(not spec.isActive, spec.percent, spec.isReverse)
end

function ThrottleHold.actionEventChangePercent(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    self:setThrottleHoldState(spec.isActive, spec.percent + callbackState * ThrottleHold.PERCENT_STEP, spec.isReverse)
end

function ThrottleHold.actionEventDirection(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self[ThrottleHold.SPEC_TABLE_NAME]
    self:setThrottleHoldState(spec.isActive, spec.percent, not spec.isReverse)
end
