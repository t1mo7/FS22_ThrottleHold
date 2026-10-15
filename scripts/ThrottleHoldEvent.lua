-- Syncs throttle hold state (armed, percent, direction) between clients and server.

ThrottleHoldEvent = {}
local ThrottleHoldEvent_mt = Class(ThrottleHoldEvent, Event)

InitEventClass(ThrottleHoldEvent, "ThrottleHoldEvent")

function ThrottleHoldEvent.emptyNew()
    return Event.new(ThrottleHoldEvent_mt)
end

function ThrottleHoldEvent.new(vehicle, isActive, percent, isReverse)
    local self = ThrottleHoldEvent.emptyNew()
    self.vehicle = vehicle
    self.isActive = isActive
    self.percent = percent
    self.isReverse = isReverse
    return self
end

function ThrottleHoldEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isActive = streamReadBool(streamId)
    self.percent = streamReadUIntN(streamId, 7)
    self.isReverse = streamReadBool(streamId)
    self:run(connection)
end

function ThrottleHoldEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isActive)
    streamWriteUIntN(streamId, self.percent, 7)
    streamWriteBool(streamId, self.isReverse)
end

function ThrottleHoldEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end

    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setThrottleHoldState(self.isActive, self.percent, self.isReverse, true)
    end
end

function ThrottleHoldEvent.sendEvent(vehicle, isActive, percent, isReverse, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ThrottleHoldEvent.new(vehicle, isActive, percent, isReverse), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(ThrottleHoldEvent.new(vehicle, isActive, percent, isReverse))
        end
    end
end
