include("shared.lua")

if VERSE and VERSE.Flags and VERSE.Flags.AutoInit and not VERSE._didInit then
    VERSE._didInit = true
    VERSE:Init()
    VERSE._ActiveFrames = VERSE._ActiveFrames or 0
    VERSE.IsFrame = function()
        return (VERSE._ActiveFrames or 0) > 0
    end
end

-- Supprime les notifications de tutoriel par défaut de GMod (menu apparitions, drag&drop)
local _origAddLegacy = notification.AddLegacy
notification.AddLegacy = function(text, ...)
    local t = tostring(text or "")
    if string.find(t, "KP_PLUS", 1, true)
    or string.find(t, "MENU DES APPARITIONS", 1, true)
    or string.find(t, "spawn menu", 1, true)
    or string.find(t, "spawnmenu", 1, true)
    or string.find(t, "listes d'apparition", 1, true)
    or string.find(t, "spawn list", 1, true)
    then return end
    return _origAddLegacy(text, ...)
end

VERSE.Hook.AddNS("Client Init", "InitPostEntity", "VERSE::InitPostEntity::Init", function()
    RunConsoleCommand("hud_deathnotice_time", "0")
    VERSE.Hook.Run("VERSE::ClientPostInit")

    local rse = "RenderScreenspaceEffects"
    local rsc = "RenderScene"
    VERSE.Hook.Remove(rse, "RenderBloom")
    VERSE.Hook.Remove(rse, "RenderBokeh")
    VERSE.Hook.Remove(rse, "RenderColorModify")
    VERSE.Hook.Remove(rse, "RenderTexturize")
    VERSE.Hook.Remove(rse, "RenderMaterialOverlay")
    VERSE.Hook.Remove(rse, "RenderMotionBlur")
    VERSE.Hook.Remove(rse, "RenderSharpen")
    VERSE.Hook.Remove(rse, "RenderSobel")
    VERSE.Hook.Remove(rse, "RenderSunbeams")
    VERSE.Hook.Remove(rse, "RenderTexturize")
    VERSE.Hook.Remove(rse, "RenderToyTown")
    VERSE.Hook.Remove(rsc, "RenderStereoscopy")
    VERSE.Hook.Remove(rsc, "RenderSuperDoF")
    VERSE.Hook.Remove("GUIMousePressed", "SuperDOFMouseDown")
    VERSE.Hook.Remove("GUIMouseReleased", "SuperDOFMouseUp")
    VERSE.Hook.Remove("PreventScreenClicks", "SuperDOFPreventClicks")
    VERSE.Hook.Remove("PostRender", "RenderFrameBlend")
    VERSE.Hook.Remove("PreRender", "PreRenderFrameBlend")
    VERSE.Hook.Remove("Think", "DOFThink")
    VERSE.Hook.Remove("NeedsDepthPass", "NeedsDepthPass_Bokeh")
    VERSE.Hook.Remove("PostDrawEffects", "RenderWidgets")
end)

function GM:PlayerStartVoice(ply) end
function GM:PlayerEndVoice(ply) end