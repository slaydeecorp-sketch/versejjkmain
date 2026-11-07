timer.Create("VERSE::Decal::Cleaner", 2 * 60, 0, function() RunConsoleCommand("r_cleardecals") end)

local mouseX, mouseY
local cursorUnlocked = false
function GM:ShowSpare1(ply)
    cursorUnlocked = not cursorUnlocked
    if cursorUnlocked then
        if not (mouseX and mouseY) then
            gui.SetMousePos(ScrW() * .5, ScrH() * .5)
        else
            gui.SetMousePos(mouseX, mouseY)
        end
    else
        mouseX, mouseY = gui.MousePos()
    end

    gui.EnableScreenClicker(cursorUnlocked)
end