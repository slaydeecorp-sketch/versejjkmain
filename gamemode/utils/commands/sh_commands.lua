VERSE.Commands = VERSE.Commands or {}
VERSE.Commands._list = VERSE.Commands._list or {}
VERSE.Commands.ReloadNet = VERSE.Commands.ReloadNet or "VERSE::Commands::HotReload"
VERSE.Commands.ReloadFileNet = VERSE.Commands.ReloadFileNet or "VERSE::Commands::HotReloadFile"

local function logErr(...)
    if VERSE.Log then VERSE.Log:Error(...) else MsgN(...) end
end

local function hasPerm(ply, perm)
    if not perm or perm == "" then return true end
    if not IsValid(ply) then return true end
    if perm == "developer" then return ply:IsDeveloper() end
    if perm == "staff" then return ply:IsStaff() end
    if perm == "staffplus" then return ply:IsStaffPlus() end
    return false
end

function VERSE.Commands.Add(name, fn, perm, realm)
    if not name or name == "" then return end
    if not isfunction(fn) then return end

    realm = realm or "both"
    VERSE.Commands._list[name] = { fn = fn, perm = perm, realm = realm }

    if SERVER and VERSE.Commands._RegisterSV then
        VERSE.Commands._RegisterSV(name)
    elseif CLIENT and VERSE.Commands._RegisterCL then
        VERSE.Commands._RegisterCL(name)
    end
end

function VERSE.Commands._Execute(name, ply, args, argStr)
    local def = VERSE.Commands._list[name]
    if not def then return end

    if not hasPerm(ply, def.perm) then return end

    local ok, err = pcall(def.fn, ply, args or {}, argStr or "")
    if not ok then
        logErr("[CMD ERROR]", name, err)
    end
end
