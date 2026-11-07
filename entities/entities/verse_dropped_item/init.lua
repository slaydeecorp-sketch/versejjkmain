AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self._worldModel or "models/props_junk/cardboard_box004a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:DrawShadow(false)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(5)
    end

    timer.Simple(1.5, function()
        if not IsValid(self) then return end
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetCollisionBounds(Vector(-20, -20, -10), Vector(20, 20, 30))

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end

        self:SetNWBool("Settled", true)
    end)

    timer.Simple(300, function()
        if IsValid(self) then self:Remove() end
    end)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if self._pickingUp then return end

    local itemId = self:GetItemID()
    local amount = self:GetAmount()
    local metadata = self._metadata

    if not itemId or itemId == "" or amount <= 0 then return end

    local INV = VERSE.Inventory
    if not INV then return end

    local charId = INV:GetCharacterUID(activator)
    if not charId then return end

    self._pickingUp = true

    INV:AddItem(charId, itemId, amount, metadata, function(ok, err)
        if ok then
            if IsValid(self) then self:Remove() end
            INV:SendSync(activator, charId)
            local def = INV:GetItemDef(itemId)
            local name = def and def.name or itemId
            local text = amount > 1 and ("+" .. amount .. "x " .. name) or ("+" .. name)
            if isfunction(activator.Notify) then
                activator:Notify(text, NOTIFY_HINT, 3)
            end
        else
            self._pickingUp = false
            if isfunction(activator.Notify) then
                activator:Notify("Inventaire plein.", NOTIFY_ERROR, 3)
            end
        end
    end)
end

function ENT:SetDropData(data)
    if not data then return end
    self:SetItemID(data.item_id or "")
    self:SetAmount(data.amount or 1)
    self._metadata = data.metadata
end
