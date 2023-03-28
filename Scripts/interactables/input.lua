---@class Input : ShapeClass
Input = class()

local consumeActions = {
    [sm.interactable.actions.zoomIn] = true,
    [sm.interactable.actions.zoomOut] = true
}

local itemSwitchBlock = {
    [sm.interactable.actions.item0] = true,
    [sm.interactable.actions.item1] = true,
    [sm.interactable.actions.item2] = true,
    [sm.interactable.actions.item3] = true,
    [sm.interactable.actions.item4] = true,
    [sm.interactable.actions.item5] = true,
    [sm.interactable.actions.item6] = true,
    [sm.interactable.actions.item7] = true,
    [sm.interactable.actions.item8] = true,
    [sm.interactable.actions.item9] = true
}

function Input:server_onFixedUpdate()
    local int = self.interactable
    for v, player in pairs(sm.player.getAllPlayers()) do
        local char = player.character
        if char ~= nil and char:getLockingInteractable() == nil then
            char:setLockingInteractable(int)
        end
    end
end

function Input:client_onAction( action, state )
    local player = sm.localPlayer.getPlayer()
    local publicData = player:getClientPublicData()
    if publicData.input[action] ~= nil then
        publicData.input[action] = state
    end

    return not publicData.spectating and itemSwitchBlock[action] == true or
        consumeActions[action] == true or
        publicData.spectating and action ~= 0
end