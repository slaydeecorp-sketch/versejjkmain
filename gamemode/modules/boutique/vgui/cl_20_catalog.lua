local BT = VERSE.Boutique
local R = VERSE.Responsive
local _ui = BT._ui
local _CAT_COL_DIVIDER = Color(255, 255, 255, 255)
local function buildCatalogPage(parent, pageId)
    local selected = _ui.getSelectedProduct(pageId)
    if not selected then
        _ui.createBackButton(parent)
        return
    end
    _ui.buildLeftInfoCard(parent, pageId, selected)
    local divider = vgui.Create("DPanel", parent)
    divider:SetPos(R:XY(661, 235))
    divider:SetSize(R:XY(5, 715))
    divider.Paint = function(_, w, h) RNDX.Draw(R:Y(8), 0, 0, w, h, _CAT_COL_DIVIDER) end
    local products = BT:GetPageProductList(pageId)
    local positions = {{758, 235}, {1135, 235}, {1512, 235}, {758, 604}}
    for i = 1, #products do
        local pos = positions[i]
        if pos then _ui.createCatalogCard(parent, products[i], R:X(pos[1]), R:Y(pos[2]), R:X(342), R:Y(342), pageId) end
    end

    _ui.createBackButton(parent)
end

_ui.buildCatalogPage = buildCatalogPage