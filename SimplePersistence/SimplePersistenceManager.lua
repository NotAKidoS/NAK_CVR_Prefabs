UnityEngine = require("UnityEngine")
UI = require("UnityEngine.UI")
Time = UnityEngine.Time

-- Utility Functions --

local function sanitizeString(str)
    if type(str) ~= "string" or str == "" then
        return "empty"
    end

    -- Removes all illegal characters
    -- Only allows letters and digits... and yet still explodes
    local sanitized = str:gsub("[^%w]", "")
    return sanitized
end

-- Debugging --

local DEBUG = true  -- Set to true to enable logging

local function PrintDebug(message)
    if DEBUG then
        print(message)
    end
end

-- Simple Persistence Manager --

SimplePersistenceManager = {
    frameCounter = 0,
    currentObjectIndex = 1,
    objectList = {},
    worldSettings = {},

    -- World settings don't need to be Private / encrypted
    storage = Storage.Public,

    -- Only one BoundObject is checked for changes every x frames to keep somewhat performant
    -- https://feedback.abinteractive.net/p/cannot-reliably-save-persistance-values-in-ondestroy-please-provide-alternatives
    CHECK_FOR_CHANGE_EVERY_X_FRAMES = 5,

    -- Beware of using illegal characters for keys
    -- https://feedback.abinteractive.net/p/persistance-blows-up-deserializing-when-illegal-characters-are-used
    WORLD_SETTINGS_KEY = "SPM-World-Settings"
}

-- Behavior Definitions --

-- I cannot think of anything else other than Toggles, GameObjects, and Transforms rn
-- but maybe just generic MonoBehaviour.enabled ?

local behaviors = {}

behaviors["UnityEngine.UI.Toggle"] = {
    applyState = function(obj, state)
        if state and state.isOn ~= nil then
            obj.isOn = state.isOn
            -- CVRBUG: Cannot log gameObject or name due to missing inherited bindings
            -- https://feedback.abinteractive.net/p/scripting-rcc-ui-tmp-module-bindings-do-not-inherit-monobehaviour-behaviour-bindings
            PrintDebug("Applied 'isOn' state for '" .. tostring(obj) .. "': " .. tostring(state.isOn))
        end
    end,
    getState = function(obj)
        return { isOn = obj.isOn }
    end,
    hasStateChanged = function(obj, previousState, currentState)
        return previousState.isOn ~= currentState.isOn
    end,
    getDefaultState = function(obj)
        return { isOn = obj.isOn }
    end
}

behaviors["UnityEngine.GameObject"] = {
    applyState = function(obj, state)
        if state and state.active ~= nil then
            obj:SetActive(state.active)
            PrintDebug("Applied 'active' state for '" .. obj.gameObject.name .. "': " .. tostring(state.active))
        end
    end,
    getState = function(obj)
        return { active = obj.activeSelf }
    end,
    hasStateChanged = function(obj, previousState, currentState)
        return previousState.active ~= currentState.active
    end,
    getDefaultState = function(obj)
        return { active = obj.activeSelf }
    end
}

behaviors["UnityEngine.Transform"] = {
    applyState = function(obj, state)
        if state then
            if state.position then
                obj.position = UnityEngine.NewVector3(state.position.x, state.position.y, state.position.z)
                PrintDebug("Applied 'position' for '" .. obj.gameObject.name .. "'")
            end
            if state.rotation then
                obj.rotation = UnityEngine.Quaternion.Euler(state.rotation.x, state.rotation.y, state.rotation.z)
                PrintDebug("Applied 'rotation' for '" .. obj.gameObject.name .. "'")
            end
        end
    end,
    getState = function(obj)
        local pos = obj.position
        local rot = obj.rotation.eulerAngles
        return {
            position = { x = pos.x, y = pos.y, z = pos.z },
            rotation = { x = rot.x, y = rot.y, z = rot.z }
        }
    end,
    hasStateChanged = function(obj, previousState, currentState)
        local positionChanged = previousState.position.x ~= currentState.position.x or
                                previousState.position.y ~= currentState.position.y or
                                previousState.position.z ~= currentState.position.z

        local rotationChanged = previousState.rotation.x ~= currentState.rotation.x or
                                previousState.rotation.y ~= currentState.rotation.y or
                                previousState.rotation.z ~= currentState.rotation.z

        return positionChanged or rotationChanged
    end,
    getDefaultState = function(obj)
        local pos = obj.position
        local rot = obj.rotation.eulerAngles
        return {
            position = { x = pos.x, y = pos.y, z = pos.z },
            rotation = { x = rot.x, y = rot.y, z = rot.z }
        }
    end
}

-- Implementation --

function SimplePersistenceManager:Start()

    -- Ensure master key is not illegal...
    self.WORLD_SETTINGS_KEY = sanitizeString(self.WORLD_SETTINGS_KEY)

    -- Copy all values to our local worldSettings table as we cannot modify the returned output...
    self.worldSettings = self.storage:GetTable(self.WORLD_SETTINGS_KEY)
    local isDirty = false

    -- Build objectList and apply saved states
    for name, obj in pairs(BoundObjects) do
        local sanitizedName = sanitizeString(name)
        local objType = typeof(obj)
        if objType then
            local behavior = behaviors[objType]
            if behavior then
                self.objectList[#self.objectList + 1] = { name = name, sanitizedName = sanitizedName, obj = obj, type = objType }
                local settings = self.worldSettings[sanitizedName]
                if settings then
                    behavior.applyState(obj, settings)
                else
                    local defaultState = behavior.getDefaultState(obj)
                    self.worldSettings[sanitizedName] = defaultState
                    isDirty = true
                    PrintDebug("No saved state for '" .. name .. "'. Using current state.")
                end
            else
                PrintDebug("No behavior defined for type '" .. objType .. "'")
            end
        else
            PrintDebug("Unknown object type for '" .. name .. "'")
        end
    end

    -- Remove settings for non-existent objects
    for savedName in pairs(self.worldSettings) do
        local found = false
        for _, item in ipairs(self.objectList) do
            if item.sanitizedName == savedName then
                found = true
                break
            end
        end
        if not found then
            PrintDebug("Removing settings for '" .. savedName .. "' as it no longer exists.")
            self.worldSettings[savedName] = nil
            isDirty = true
        end
    end

    -- Save updated settings if dirty
    if isDirty then
        self.storage:SetTable(self.WORLD_SETTINGS_KEY, self.worldSettings)
    end
end

function SimplePersistenceManager:Update()

    self.frameCounter = self.frameCounter + 1

    -- MoonSharp is slow so we only check for a single change every x frames 
    if self.frameCounter % self.CHECK_FOR_CHANGE_EVERY_X_FRAMES == 0 and #self.objectList > 0 then
        local item = self.objectList[self.currentObjectIndex]
        local name = item.name
        local sanitizedName = item.sanitizedName
        local obj = item.obj
        local objType = item.type
        local behavior = behaviors[objType]

        if behavior then
            local previousState = self.worldSettings[sanitizedName] or behavior.getDefaultState(obj)
            local currentState = behavior.getState(obj)

            if behavior.hasStateChanged(obj, previousState, currentState) then
                PrintDebug("State change detected for '" .. name .. "'. Saving new state.")
                self.worldSettings[sanitizedName] = currentState
                self.storage:SetTable(self.WORLD_SETTINGS_KEY, self.worldSettings)
            end
        else
            PrintDebug("No behavior defined for type '" .. objType .. "'")
        end

        -- Move to the next object
        self.currentObjectIndex = self.currentObjectIndex + 1
        if self.currentObjectIndex > #self.objectList then
            self.currentObjectIndex = 1
        end
    end
end

-- Unity Events --

function Start()
    SimplePersistenceManager:Start()
end

function Update()
    SimplePersistenceManager:Update()
end
