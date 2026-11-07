VERSE.HoldTypes = VERSE.HoldTypes or {}
VERSE.HoldTypeMeta = VERSE.HoldTypeMeta or {}
VERSE.HoldTypeMeta.__index = VERSE.HoldTypeMeta

VERSE.HoldTypes.State = {
    IDLE = 1,
    WALK = 2,
    RUN = 3,
    CROUCH_IDLE = 4,
    CROUCH_WALK = 5,
    JUMP = 6,
    LAND = 7,
}

VERSE.HoldTypes.StateToAct = {
    [VERSE.HoldTypes.State.IDLE] = ACT_MP_STAND_IDLE,
    [VERSE.HoldTypes.State.WALK] = ACT_MP_WALK,
    [VERSE.HoldTypes.State.RUN] = ACT_MP_RUN,
    [VERSE.HoldTypes.State.CROUCH_IDLE] = ACT_MP_CROUCH_IDLE,
    [VERSE.HoldTypes.State.CROUCH_WALK] = ACT_MP_CROUCHWALK,
    [VERSE.HoldTypes.State.JUMP] = ACT_MP_JUMP,
    [VERSE.HoldTypes.State.LAND] = ACT_MP_JUMP_LAND or ACT_MP_STAND_IDLE,
}

VERSE.HoldTypes.NetLand = "VERSE::HoldTypes::Land"
VERSE.HoldTypes.NetForce = "VERSE::HoldTypes::Force"

function VERSE.HoldTypeMeta:GetBaseHoldType()
    return self.BaseHoldType or "normal"
end

local function _doRegister(self, data)
    if not istable(self) then error("called with invalid self", 2) end
    if not istable(data) then error("got nil/invalid data", 2) end
    if not data.HoldType then error("requires data.HoldType", 2) end
    self[data.HoldType] = setmetatable(data, VERSE.HoldTypeMeta)
    if VERSE.Log and VERSE.Log.Print then VERSE.Log:Print("Registered HoldType: " .. (data.Name or data.HoldType)) end
end

function VERSE.HoldTypes:RegisterHoldType(data)
    if data == nil and istable(self) and self.HoldType then return _doRegister(VERSE.HoldTypes, self) end
    return _doRegister(self, data)
end

function VERSE.RegisterHoldType(data)
    return _doRegister(VERSE.HoldTypes, data)
end

function VERSE.HoldTypes:DecideMoveState(ply)
    if not IsValid(ply) then return self.State.IDLE end
    local mt = ply:GetMoveType()
    if mt == MOVETYPE_LADDER or mt == MOVETYPE_NOCLIP or mt == MOVETYPE_OBSERVER then return self.State.IDLE end
    if ply.InVehicle and ply:InVehicle() then return self.State.IDLE end
    if ply.WaterLevel and ply:WaterLevel() >= 2 then return self.State.IDLE end
    local onGround = ply:IsOnGround()
    if (not onGround) and mt == MOVETYPE_WALK then return self.State.JUMP end
    local vel2D = ply:GetVelocity():Length2D()
    local duckKey = ply:KeyDown(IN_DUCK)
    if duckKey then return (vel2D > 2) and self.State.CROUCH_WALK or self.State.CROUCH_IDLE end
    if vel2D > 10 then
        local runSpeed = (ply.GetRunSpeed and ply:GetRunSpeed()) or 260
        if vel2D > (runSpeed * 0.8) then return self.State.RUN end
        return self.State.WALK
    end
    return self.State.IDLE
end

if CLIENT then
    VERSE.HoldTypes:RegisterHoldType({
        HoldType = "yuji_base",
        Name = "Yuji Combat",
        BaseHoldType = "fist",
        Translations = {
            [VERSE.HoldTypes.State.IDLE] = {
                Sequence = "f606-jjk-yuta-as_cp_110_00_idle_01",
                Weight = 1,
                Rate = 1,
                StartTime = 1.3,
            },
            [VERSE.HoldTypes.State.RUN] = {
                Sequence = "ytr_fils_run_base",
                Weight = 1,
                Rate = 1
            },
            [VERSE.HoldTypes.State.WALK] = {
                Sequence = "ytr_fils_run_base",
                Weight = 1,
                Rate = 1
            },
            [VERSE.HoldTypes.State.JUMP] = {
                Sequence = "f606-jjk-inumaki-as_cp_070_00_jumpairup_01",
                Weight = 1,
                Rate = 1
            },
            [VERSE.HoldTypes.State.LAND] = {
                Sequence = "f606-jjk-sukuna-as_cp_020_00_landing_01",
                Weight = 1,
                Rate = 1
            },
        }
    })
end