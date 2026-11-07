imstate = {}
imstate.__version = 1.1
imstate.__index = imstate
local function newImstate(_, vars, AlwaysThink)
    local newObj = {
        vars = vars or {},
        AlwaysThink = AlwaysThink or function() end,
        noState = {
            IdleThink = function(self) end,
            EnterThink = function(self) return true end,
            ExitThink = function(self) return true end,
            EnterOnce = function(self) end,
            ExitOnce = function(self) end,
        },
        state = nil,
        states = {},
        _transitionComplete = nil,
    }

    newObj.state = newObj.noState
    newObj.Update = newObj.state.IdleThink
    return setmetatable(newObj, imstate)
end

imstate.__call = newImstate
setmetatable(imstate, {
    __call = imstate.__call,
})

function imstate:__tostring()
    return "[imstate]"
end

function imstate:_SetNext(nextState)
end

function imstate:ChangeTo(newStateName)
    self.state:ExitOnce()
    self.Update = self.state.ExitThink
    local newState = self.states[newStateName]
    self._nextFunc = function()
        self.state = newState
        self.Update = newState.EnterThink
        self._nextFunc = function()
            newState.EnterOnce(newState, machine)
            self.Update = newState.IdleThink
        end
    end
end

function imstate:Perform(...)
    self.AlwaysThink(self.state, self, ...)
    local doTransition = self.Update(self.state, self)
    if doTransition then self._nextFunc() end
end

local function fn()
    return
end

local function fnt()
    return true
end

function imstate:Add(id, state)
    state.IdleThink = state.IdleThink or fn
    state.EnterThink = state.EnterThink or fnt
    state.ExitThink = state.ExitThink or fnt
    state.EnterOnce = state.EnterOnce or fn
    state.ExitOnce = state.ExitOnce or fn
    self.states[id] = state
end

function imstate:Remove(id)
    if self.state == self.states[id] then self.state = self.noState end
    self.states[id] = nil
end

function imstate:Clear()
    self.states = {}
    self.state = self.noState
end