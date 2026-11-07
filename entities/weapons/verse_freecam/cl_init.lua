include("shared.lua")

function SWEP:DrawHUD() end
function SWEP:DrawWorldModel() end
function SWEP:ViewModelDrawn() end

function SWEP:ShouldDrawViewModel()
    return false
end