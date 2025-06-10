---
-- Traitor equipment menu
-- @section shop

local GetTranslation = LANG.GetTranslation
local GetPTranslation = LANG.GetParamTranslation
local SafeTranslate = LANG.TryTranslation
local table = table
local net = net
local pairs = pairs
local IsValid = IsValid
local hook = hook

-- create ClientConVars

---
-- @realm client
local numColsVar = CreateConVar(
    "ttt_bem_cols",
    5,
    FCVAR_ARCHIVE,
    "Sets the number of columns in the Traitor/Detective menu's item list."
)

---
-- @realm client
local numRowsVar = CreateConVar(
    "ttt_bem_rows",
    6,
    FCVAR_ARCHIVE,
    "Sets the number of rows in the Traitor/Detective menu's item list."
)

---
-- @realm client
local itemSizeVar = CreateConVar(
    "ttt_bem_size",
    64,
    FCVAR_ARCHIVE,
    "Sets the item size in the Traitor/Detective menu's item list."
)

---
-- @realm client
local showCustomVar =
    CreateConVar("ttt_bem_marker_custom", 1, FCVAR_ARCHIVE, "Should custom items get a marker?")

---
-- @realm client
local showFavoriteVar =
    CreateConVar("ttt_bem_marker_fav", 1, FCVAR_ARCHIVE, "Should favorite items get a marker?")

---
-- @realm client
local showSlotVar =
    CreateConVar("ttt_bem_marker_slot", 1, FCVAR_ARCHIVE, "Should items get a slot-marker?")

---
-- @realm client
local alwaysShowShopVar = CreateConVar(
    "ttt_bem_always_show_shop",
    1,
    FCVAR_ARCHIVE,
    "Should the shop be opened/closed instead of the score menu during preparing / at the end of a round?"
)

---
-- @realm client
local enableDoubleClickBuy = CreateConVar(
    "ttt_bem_enable_doubleclick_buy",
    1,
    FCVAR_ARCHIVE,
    "Sets if you will be able to double click on an Item to buy it."
)

-- get serverside ConVars
local allowChangeVar = GetConVar("ttt_bem_allow_change")
local serverColsVar = GetConVar("ttt_bem_sv_cols")
local serverRowsVar = GetConVar("ttt_bem_sv_rows")
local serverSizeVar = GetConVar("ttt_bem_sv_size")

---
-- Some database functions of the shop

local color_bad = Color(244, 67, 54, 255)
--local color_good = Color(76, 175, 80, 255)
local color_darkened = Color(255, 255, 255, 80)

-- Buyable weapons are loaded automatically. Buyable items are defined in
-- equip_items_shd.lua

local eqframe = nil
local dlist = nil
local curSearch = nil

-- Shop sizes and layout configuration (similar to SEARCHSCREEN)
local EQUIPSCREEN = EQUIPSCREEN or {}
EQUIPSCREEN.sizes = EQUIPSCREEN.sizes or {}

---
-- Calculates and caches the dimensions of the equipment shop UI.
-- @realm client
function EQUIPSCREEN:CalculateSizes()
    -- calculate dimensions
    local numCols, numRows, itemSize

    if allowChangeVar:GetBool() then
        numCols = numColsVar:GetInt()
        numRows = numRowsVar:GetInt()
        itemSize = itemSizeVar:GetInt()
    else
        numCols = serverColsVar:GetInt()
        numRows = serverRowsVar:GetInt()
        itemSize = serverSizeVar:GetInt()
    end

    -- margin and padding
    self.sizes.padding = 15
    local itemSizePad = itemSize + 2

    -- item list dimensions
    local dlistw = itemSizePad * numCols + 20
    local dlisth = itemSizePad * numRows + 20

    -- Modern layout sizes (similar to SEARCHSCREEN)
    self.sizes.width = math.max(dlistw + 350, 900)  -- Wider for modern layout
    self.sizes.height = math.max(dlisth + 150, 650)
    
    self.sizes.heightButton = 45
    self.sizes.widthButton = 140
    self.sizes.heightBottomButtonPanel = self.sizes.heightButton + self.sizes.padding + 1

    self.sizes.widthMainArea = self.sizes.width - 2 * self.sizes.padding
    self.sizes.heightMainArea = self.sizes.height
        - self.sizes.heightBottomButtonPanel
        - 3 * self.sizes.padding
        - vskin.GetHeaderHeight()
        - vskin.GetBorderSize()

    -- Equipment list area
    self.sizes.widthEquipArea = dlistw
    self.sizes.heightEquipArea = dlisth
    
    -- Info panel area  
    self.sizes.widthInfoArea = self.sizes.width - self.sizes.widthEquipArea - 3 * self.sizes.padding
    self.sizes.heightInfoArea = self.sizes.heightMainArea

    -- Store calculated values for equipment list
    self.itemSize = itemSize
    self.numCols = numCols
    self.numRows = numRows
end

--
--     GENERAL HELPER FUNCTIONS
--

local function RolenameToRole(val)
    local rlsList = roles.GetList()

    for i = 1, #rlsList do
        local v = rlsList[i]

        if SafeTranslate(v.name) == val then
            return v.index
        end
    end

    return 0
end

local function ItemIsWeapon(item)
    return not items.IsItem(item.id)
end

local function CanCarryWeapon(item)
    return LocalPlayer():CanCarryWeapon(item)
end

--
-- Creates tabel of labels showing the status of ordering prerequisites
--

local function PreqLabels(parent, x, y)
    local client = LocalPlayer()

    local tbl = {}
    
    -- 创建一个容器来更好地布局这些标签 - 增大容器尺寸
    local container = vgui.Create("DPanel", parent)
    container:SetPos(x, y)
    container:SetSize(parent:GetWide() - x * 2, 180)  -- 从120增加到180
    container:SetPaintBackground(false)
    
    -- Credits section - 增大尺寸和间距
    tbl.credits = vgui.Create("DLabel", container)
    tbl.credits:SetPos(8, 8)                         -- 稍微增加边距
    tbl.credits:SetSize(160, 35)                     -- 从120x25增加到160x35

    -- coins icon - 增大图标尺寸
    tbl.credits.img = vgui.Create("DImage", container)
    tbl.credits.img:SetSize(32, 32)                  -- 从24x24增加到32x32
    tbl.credits.img:SetPos(8, 12)                    -- 调整位置适配
    tbl.credits.img:SetImage("vgui/ttt/equip/coin.png")

    -- remaining credits text  
    tbl.credits.Check = function(s, sel)
        local credits = client:GetCredits()
        local cr = sel and sel.credits or 1

        return credits >= cr,
            " " .. cr .. " / " .. credits,
            GetPTranslation("equip_cost", { num = credits })
    end

    -- Owned/Carry section - 增大尺寸和间距
    tbl.owned = vgui.Create("DLabel", container)
    tbl.owned:SetPos(8, 50)                          -- 从35增加到50，增大间距
    tbl.owned:SetSize(160, 35)                       -- 从120x25增加到160x35

    -- carry icon - 增大图标尺寸
    tbl.owned.img = vgui.Create("DImage", container)
    tbl.owned.img:SetSize(32, 32)                    -- 从24x24增加到32x32
    tbl.owned.img:SetPos(8, 54)                      -- 调整位置适配
    tbl.owned.img:SetImage("vgui/ttt/equip/briefcase.png")

    tbl.owned.Check = function(s, sel)
        if ItemIsWeapon(sel) and not CanCarryWeapon(sel) then
            return false,
                MakeKindValid(sel.Kind),
                GetPTranslation("equip_carry_slot", { slot = MakeKindValid(sel.Kind) })
        elseif not ItemIsWeapon(sel) and sel.limited and client:HasEquipmentItem(sel.id) then
            return false, "X", GetTranslation("equip_carry_own")
        else
            if ItemIsWeapon(sel) then
                local cv_maxCount = GetConVar(ORDERED_SLOT_TABLE[MakeKindValid(sel.Kind)])

                local maxCount = cv_maxCount and cv_maxCount:GetInt() or 0
                maxCount = maxCount < 0 and "∞" or maxCount

                return true,
                    " " .. #client:GetWeaponsOnSlot(MakeKindValid(sel.Kind)) .. " / " .. maxCount,
                    GetTranslation("equip_carry")
            else
                return true, "✔", GetTranslation("equip_carry")
            end
        end
    end

    -- Stock/Bought section - 增大尺寸和间距
    tbl.bought = vgui.Create("DLabel", container)
    tbl.bought:SetPos(8, 92)                         -- 从65增加到92，增大间距
    tbl.bought:SetSize(160, 35)                      -- 从120x25增加到160x35

    -- stock icon - 增大图标尺寸
    tbl.bought.img = vgui.Create("DImage", container)
    tbl.bought.img:SetSize(32, 32)                   -- 从24x24增加到32x32
    tbl.bought.img:SetPos(8, 96)                     -- 调整位置适配
    tbl.bought.img:SetImage("vgui/ttt/equip/package.png")

    tbl.bought.Check = function(s, sel)
        if sel.limited and client:HasBought(tostring(sel.id)) then
            return false, "X", GetTranslation("equip_stock_deny")
        else
            return true, "✔", GetTranslation("equip_stock_ok")
        end
    end

    -- Custom info section - 增大尺寸和间距
    tbl.info = vgui.Create("DLabel", container)
    tbl.info:SetPos(8, 134)                          -- 从95增加到134，增大间距
    tbl.info:SetSize(160, 35)                        -- 从120x25增加到160x35

    -- info icon - 增大图标尺寸
    tbl.info.img = vgui.Create("DImage", container)
    tbl.info.img:SetSize(32, 32)                     -- 从24x24增加到32x32
    tbl.info.img:SetPos(8, 138)                      -- 调整位置适配
    tbl.info.img:SetImage("vgui/ttt/equip/icon_info")

    tbl.info.Check = function(s, sel)
        if not istable(sel) then
            return false, "X", "No table given."
        end

        local isBuyable, statusCode = shop.CanBuyEquipment(client, sel.id)
        local iconText = isBuyable and "✔" or "X"
        local tooltipText

        if statusCode == shop.statusCode.SUCCESS then
            tooltipText = "Ok"
        elseif statusCode == shop.statusCode.INVALIDID then
            ErrorNoHaltWithStack("[TTT2][ERROR] Missing id in table:", sel)
            PrintTable(sel)
            tooltipText = "No ID"
        elseif statusCode == shop.statusCode.NOTBUYABLE then
            tooltipText = "This equipment cannot be bought."
        elseif statusCode == shop.statusCode.NOTENOUGHPLAYERS then
            iconText = " " .. #util.GetActivePlayers() .. " / " .. sel.minPlayers
            tooltipText = "Minimum amount of active players needed."
        elseif statusCode == shop.statusCode.LIMITEDBOUGHT then
            tooltipText = "This equipment is limited and is already bought."
        elseif statusCode == shop.statusCode.GLOBALLIMITEDBOUGHT then
            tooltipText = "This equipment is globally limited and is already bought by someone."
        elseif statusCode == shop.statusCode.TEAMLIMITEDBOUGHT then
            tooltipText = "This equipment is limited in team and is already bought by a teammate."
        elseif statusCode == shop.statusCode.NOTBUYABLEFORROLE then
            tooltipText = "Your role can't buy this equipment."
        else
            tooltipText = "Undefined statusCode " .. tostring(statusCode)
        end

        return isBuyable, iconText, tooltipText
    end

    -- 设置所有标签的字体和初始文本
    for _, pnl in pairs(tbl) do
        pnl:SetFont("DermaLarge")                     -- 从DermaDefault改为DermaLarge，增大字体
        pnl:SetText(" - ")
        
        -- 调整文本位置，为图标留出更多空间
        local x, y = pnl:GetPos()
        pnl:SetPos(x + 40, y)                        -- 从30增加到40，为更大的图标留出空间
        pnl:SetSize(pnl:GetWide() - 40, pnl:GetTall()) -- 相应调整文本区域宽度
    end

    return function(selected)
        local allow = true

        for _, pnl in pairs(tbl) do
            local result, text, tooltip = pnl:Check(selected)

            pnl:SetTextColor(result and COLOR_WHITE or color_bad)
            pnl:SetText(text)
            pnl:SizeToContents()
            pnl:SetTooltip(tooltip)

            pnl.img:SetImageColor(result and COLOR_WHITE or color_bad)
            pnl.img:SetTooltip(tooltip)

            allow = allow and result
        end

        return allow
    end
end

--
-- PANEL OVERRIDES
-- quick, very basic override of DPanelSelect
--

local PANEL = {}

local function DrawSelectedEquipment(pnl)
    surface.SetDrawColor(0, 110, 255, 255)  -- Modern blue color
    surface.DrawOutlinedRect(0, 0, pnl:GetWide(), pnl:GetTall(), 2)
    
    -- Add subtle glow effect
    surface.SetDrawColor(0, 110, 255, 60)
    surface.DrawOutlinedRect(-1, -1, pnl:GetWide() + 2, pnl:GetTall() + 2, 1)
end

---
-- @param Panel pnl
-- @realm client
-- @local
function PANEL:SelectPanel(pnl)
    if not pnl then
        return
    end

    pnl.PaintOver = nil

    self.BaseClass.SelectPanel(self, pnl)

    if pnl then
        pnl.PaintOver = DrawSelectedEquipment
    end
end
vgui.Register("EquipSelect", PANEL, "DPanelSelect")

--
-- Create Equipment GUI / refresh
--

local function PerformStarLayout(s)
    s:AlignTop(2)
    s:AlignRight(2)
    s:SetSize(12, 12)
end

local function PerformMarkerLayout(s)
    s:AlignBottom(2)
    s:AlignRight(2)
    s:SetSize(16, 16)
end

local function CreateEquipmentList(t)
    t = t or {}

    setmetatable(t, {
        __index = {
            search = nil,
            role = nil,
            notalive = false,
        },
    })

    if t.search == LANG.GetTranslation("shop_search") .. "..." or t.search == "" then
        t.search = nil
    end

    -- icon size = 64 x 64
    if IsValid(dlist) then
        ---@cast dlist -nil
        dlist:Clear()
    else
        TraitorMenuPopup()

        return
    end

    local client = LocalPlayer()
    local currole = client:GetSubRole()
    local credits = client:GetCredits()

    local itemSize = 64

    if allowChangeVar:GetBool() then
        itemSize = itemSizeVar:GetInt()
    end

    -- make sure that the players old role is not used anymore
    if t.notalive then
        currole = t.role or ROLE_NONE
    end

    -- Determine if we already have equipment
    local owned_ids = {}
    local weps = client:GetWeapons()

    for i = 1, #weps do
        local wep = weps[i]

        if wep.IsEquipment and wep:IsEquipment() then
            owned_ids[#owned_ids + 1] = wep:GetClass()
        end
    end

    -- Stick to one value for no equipment
    if #owned_ids == 0 then
        owned_ids = nil
    end

    local itms = {}
    local tmp = GetEquipmentForRole(client, currole, t.notalive)

    for i = 1, #tmp do
        if not tmp[i].notBuyable then
            itms[#itms + 1] = tmp[i]
        end
    end

    if #itms == 0 and not t.notalive then
        client:ChatPrint(
            "[TTT2][SHOP] You need to run 'shopeditor' as admin in the developer console to create a shop for this role. Link it with another shop or click on the icons to add weapons and items to the shop."
        )

        return
    end

    -- temp table for sorting
    local paneltablefav = {}
    local paneltable = {}
    local col = client:GetRoleColor()

    for k = 1, #itms do
        local item = itms[k]
        local equipName = GetEquipmentTranslation(item.name, item.PrintName)

        if
            t.search and string.find(string.lower(equipName), string.lower(t.search), 1, true)
            or not t.search
        then
            local ic = nil

            -- Create icon panel
            if item.iconMaterial then
                ic = vgui.Create("LayeredIcon", dlist)

                if item.builtin and showCustomVar:GetBool() then
                    -- Custom marker icon
                    local marker = vgui.Create("DImage")
                    marker:SetImage("vgui/ttt/vskin/markers/builtin")
                    marker:SetImageColor(col)

                    marker.PerformLayout = PerformMarkerLayout

                    marker:SetTooltip(GetTranslation("builtin_marker"))

                    ic:AddLayer(marker)
                    ic:EnableMousePassthrough(marker)
                end

                -- Favorites marker icon
                ic.favorite = false

                if shop.IsFavorite(item.id) then
                    ic.favorite = true

                    if showFavoriteVar:GetBool() then
                        local star = vgui.Create("DImage")
                        star:SetImage("icon16/star.png")

                        star.PerformLayout = PerformStarLayout

                        star:SetTooltip("Favorite")

                        ic:AddLayer(star)
                        ic:EnableMousePassthrough(star)
                    end
                end

                -- Slot marker icon
                if ItemIsWeapon(item) and showSlotVar:GetBool() then
                    local slot = vgui.Create("SimpleIconLabelled")
                    slot:SetIcon("vgui/ttt/slotcap")
                    slot:SetIconColor(col or COLOR_LGRAY)
                    slot:SetIconSize(16)
                    slot:SetIconText(MakeKindValid(item.Kind))
                    slot:SetIconProperties(
                        COLOR_WHITE,
                        "DefaultBold",
                        { opacity = 220, offset = 1 },
                        { 10, 8 }
                    )

                    ic:AddLayer(slot)
                    ic:EnableMousePassthrough(slot)
                end

                ic:SetIconSize(itemSize or 64)
                ic:SetMaterial(item.iconMaterial)
            elseif item.itemModel then
                ic = vgui.Create("SpawnIcon", dlist)
                ic:SetModel(item.itemModel)
            else
                ErrorNoHaltWithStack(
                    "Equipment item does not have model or material specified:" .. equipName
                )
                PrintTable(item)

                continue
            end

            ic.item = item

            ic:SetTooltip(equipName .. " (" .. SafeTranslate(item.type) .. ")")

            -- If we cannot order this item, darken it
            if
                not t.notalive
                and (
                    (
                                                -- already owned
table.HasValue(owned_ids, item.id)
                        or items.IsItem(item.id) and item.limited and client:HasEquipmentItem(
                            item.id
                        )
                        -- already carrying a weapon for this slot
                        or ItemIsWeapon(item) and not CanCarryWeapon(item)
                        or not shop.CanBuyEquipment(client, item.id)
                        -- already bought the item before
                        or item.limited and client:HasBought(item.id)
                    ) or (item.credits or 1) > credits
                )
            then
                ic:SetIconColor(color_darkened)
            end

            if ic.favorite then
                paneltablefav[k] = ic
            else
                paneltable[k] = ic
            end

            -- icon doubleclick to buy
            ic.PressedLeftMouse = function(self, doubleClick)
                if
                    not doubleClick
                    or self.item.disabledBuy
                    or not enableDoubleClickBuy:GetBool()
                then
                    return
                end

                shop.BuyEquipment(client, self.item.id)

                ---@cast eqframe -nil
                eqframe:Close()
            end
        end
    end

    -- add favorites first
    for _, panel in pairs(paneltablefav) do
        dlist:AddPanel(panel)
    end

    -- non favorites second
    for _, panel in pairs(paneltable) do
        dlist:AddPanel(panel)
    end
end

local currentEquipmentCoroutine = coroutine.create(function(tbl)
    while true do
        tbl = coroutine.yield(CreateEquipmentList(tbl))
    end
end)

--
-- Create/Show Shop frame
--
--  dframe
--   \-> dsheet
--      \-> dequip
--         \-> dlist
--         \-> depanel
--            \-> dsearch
--         \-> dbtnpnl
--         \-> dinfobg
--            \-> dhelp
--
--

local color_bggrey = Color(90, 90, 95, 255)

---
-- Creates / opens the shop frame with modern TTT2 styling
-- @realm client
function TraitorMenuPopup()
    local client = LocalPlayer()

    if not IsValid(client) then
        return
    end

    local subrole = client:GetSubRole()
    local fallbackRole = GetShopFallback(subrole)
    local rd = roles.GetByIndex(fallbackRole)
    local notalive = false
    local fallback = GetGlobalString("ttt_" .. rd.abbr .. "_shop_fallback")

    if client:Alive() and client:IsActive() and fallback == SHOP_DISABLED then
        return
    end

    -- Close shop if player clicks button again
    if IsValid(eqframe) then
        ---@cast eqframe -nil
        eqframe:Close()

        return
    end

    -- if the player is not alive / the round is not active let him choose his shop
    if not client:Alive() or not client:IsActive() then
        notalive = true
    end

    -- Close any existing traitor menu
    if IsValid(eqframe) then
        ---@cast eqframe -nil
        eqframe:Close()
    end

    EQUIPSCREEN:CalculateSizes()

    local credits = client:GetCredits()
    local can_order = true
    local name = GetTranslation("equip_title")

    if GetGlobalBool("ttt2_random_shops") then
        name = name .. " (RANDOM)"
    end

    -- Use modern TTT2 frame generation (same as SEARCHSCREEN)
    local frame = vguihandler.GenerateFrame(
        EQUIPSCREEN.sizes.width,
        EQUIPSCREEN.sizes.height,
        GetTranslation("equip_title")
    )
    
    frame:SetPadding(EQUIPSCREEN.sizes.padding, EQUIPSCREEN.sizes.padding, EQUIPSCREEN.sizes.padding, EQUIPSCREEN.sizes.padding)
    
    -- any keypress closes the frame (same as SEARCHSCREEN)
    frame:SetKeyboardInputEnabled(true)
    frame.OnKeyCodePressed = util.BasicKeyHandler

    -- Main content area using modern TTT2 panels
    local contentBox = vgui.Create("DPanelTTT2", frame)
    contentBox:SetSize(EQUIPSCREEN.sizes.widthMainArea, EQUIPSCREEN.sizes.heightMainArea)
    contentBox:Dock(TOP)

    -- Equipment list area (left side)
    local equipmentBox = vgui.Create("DPanelTTT2", contentBox)
    equipmentBox:SetSize(EQUIPSCREEN.sizes.widthEquipArea, EQUIPSCREEN.sizes.heightEquipArea)
    equipmentBox:Dock(LEFT)
    equipmentBox:DockMargin(0, 0, EQUIPSCREEN.sizes.padding, 0)

    -- Search panel at top of equipment area
    local searchPanel = vgui.Create("DPanelTTT2", equipmentBox)
    searchPanel:SetSize(EQUIPSCREEN.sizes.widthEquipArea, 40)
    searchPanel:Dock(TOP)
    searchPanel:DockMargin(0, 0, 0, 10)

    local dsearch = vgui.Create("DTextEntry", searchPanel)
    dsearch:Dock(FILL)
    dsearch:DockMargin(5, 5, 5, 5)
    dsearch:SetUpdateOnType(true)
    dsearch:SetEditable(true)
    dsearch:SetText(LANG.GetTranslation("shop_search") .. "...")
    dsearch.selectAll = true

    -- Role selector for non-alive players
    local drolesel = nil
    if notalive then
        local rolePanel = vgui.Create("DPanelTTT2", equipmentBox)
        rolePanel:SetSize(EQUIPSCREEN.sizes.widthEquipArea, 35)
        rolePanel:Dock(TOP)
        rolePanel:DockMargin(0, 0, 0, 5)

        drolesel = vgui.Create("DComboBox", rolePanel)
        drolesel:Dock(FILL)
        drolesel:DockMargin(5, 5, 5, 5)

        local rlsList = roles.GetList()
        for k = 1, #rlsList do
            local v = rlsList[k]
            if v:IsShoppingRole() then
                drolesel:AddChoice(SafeTranslate(v.name))
            end
        end
        drolesel:SetValue(LANG.GetTranslation("shop_role_select") .. " ...")
    end

    -- Equipment list
    dlist = vgui.Create("EquipSelect", equipmentBox)
    dlist:Dock(FILL)
    dlist:EnableVerticalScrollbar(true)
    dlist:EnableHorizontal(true)

    -- Info area (right side) using modern scroll panel
    local infoAreaScroll = vgui.Create("DScrollPanelTTT2", contentBox)
    infoAreaScroll:SetVerticalScrollbarEnabled(true)
    infoAreaScroll:SetSize(EQUIPSCREEN.sizes.widthInfoArea, EQUIPSCREEN.sizes.heightInfoArea)
    infoAreaScroll:Dock(RIGHT)

    -- Equipment info panel using traditional labels (avoid DInfoItemTTT2 issues for now)
    local infoContainer = vgui.Create("DPanelTTT2", infoAreaScroll)
    infoContainer:Dock(TOP)
    infoContainer:DockMargin(5, 5, 5, 10)
    infoContainer:SetSize(EQUIPSCREEN.sizes.widthInfoArea - 20, 200)

    -- Equipment details using traditional labels
    local equipNameLabel = vgui.Create("DLabel", infoContainer)
    equipNameLabel:SetFont("TabLarge")
    equipNameLabel:SetText("Select an item")
    equipNameLabel:Dock(TOP)
    equipNameLabel:DockMargin(10, 10, 10, 5)
    equipNameLabel:SetAutoStretchVertical(true)

    local equipTypeLabel = vgui.Create("DLabel", infoContainer)
    equipTypeLabel:SetFont("DermaDefault")
    equipTypeLabel:SetText("")
    equipTypeLabel:Dock(TOP)
    equipTypeLabel:DockMargin(10, 0, 10, 5)
    equipTypeLabel:SetAutoStretchVertical(true)

    local equipDescLabel = vgui.Create("DLabel", infoContainer)
    equipDescLabel:SetFont("DermaDefaultBold")
    equipDescLabel:SetText("")
    equipDescLabel:SetWrap(true)
    equipDescLabel:Dock(TOP)
    equipDescLabel:DockMargin(10, 0, 10, 10)
    equipDescLabel:SetAutoStretchVertical(true)
    equipDescLabel:SetTall(70)

    -- Prerequisites panel
    local prereqPanel = vgui.Create("DPanelTTT2", infoAreaScroll)
    prereqPanel:Dock(TOP)
    prereqPanel:DockMargin(5, 5, 5, 10)
    prereqPanel:SetSize(EQUIPSCREEN.sizes.widthInfoArea - 20, 240)

    local update_preqs = PreqLabels(prereqPanel, 10, 10)

    -- Bottom button area using modern TTT2 buttons
    local buttonArea = vgui.Create("DButtonPanelTTT2", frame)
    buttonArea:SetSize(EQUIPSCREEN.sizes.width, EQUIPSCREEN.sizes.heightBottomButtonPanel)
    buttonArea:Dock(BOTTOM)

    -- Favorite button - use text instead of icon to avoid material issues
    local dfav = vgui.Create("DButtonTTT2", buttonArea)
    dfav:SetText("★")  -- Use star unicode character instead of icon
    dfav:SetSize(45, EQUIPSCREEN.sizes.heightButton)
    dfav:SetPos(0, EQUIPSCREEN.sizes.padding + 1)
    dfav:SetEnabled(true)
    dfav:SetTooltip("Add to favorites")

    -- Confirm/Buy button
    local dconfirm = vgui.Create("DButtonTTT2", buttonArea)
    dconfirm:SetPos(55, EQUIPSCREEN.sizes.padding + 1)
    dconfirm:SetSize(EQUIPSCREEN.sizes.widthButton, EQUIPSCREEN.sizes.heightButton)
    dconfirm:SetEnabled(false)
    dconfirm:SetText(GetTranslation("equip_confirm"))

    -- Close button
    local dcancel = vgui.Create("DButtonTTT2", buttonArea)
    dcancel:SetPos(
        EQUIPSCREEN.sizes.widthMainArea - EQUIPSCREEN.sizes.widthButton,
        EQUIPSCREEN.sizes.padding + 1
    )
    dcancel:SetSize(EQUIPSCREEN.sizes.widthButton, EQUIPSCREEN.sizes.heightButton)
    dcancel:SetEnabled(true)
    dcancel:SetText(GetTranslation("close"))

    -- Equipment list population
    coroutine.resume(currentEquipmentCoroutine, { notalive = notalive })

    -- Search functionality
    dsearch.OnValueChange = function(slf, text)
        if text == "" then
            text = nil
        end

        curSearch = text

        local crole
        if drolesel then
            crole = RolenameToRole(drolesel:GetValue())
        end

        coroutine.resume(
            currentEquipmentCoroutine,
            { search = text, role = crole, notalive = notalive }
        )
    end

    -- Role selection for non-alive players
    if drolesel then
        drolesel.OnSelect = function(panel, index, value)
            Dev(2, LANG.GetParamTranslation("shop_role_selected", { role = value }))

            coroutine.resume(
                currentEquipmentCoroutine,
                { role = RolenameToRole(value), search = dsearch:GetValue(), notalive = notalive }
            )
        end
    end

    -- Equipment selection handler (modern styling)
    dlist.OnActivePanelChanged = function(_, _, new)
        if not IsValid(new) or not new.item then
            return
        end

        -- Update info panel with traditional labels
        local itemData = new.item
        equipNameLabel:SetText(GetEquipmentTranslation(itemData.name, itemData.PrintName) or "Unknown")
        equipTypeLabel:SetText(SafeTranslate(itemData.type) or "Equipment")
        equipDescLabel:SetText(SafeTranslate(itemData.desc) or "No description available.")

        can_order = update_preqs(new.item)
        new.item.disabledBuy = not can_order
        dconfirm:SetEnabled(can_order)
    end

    -- Button handlers
    dconfirm.DoClick = function()
        local pnl = dlist.SelectedPanel

        if not pnl or not pnl.item then
            return
        end

        local choice = pnl.item
        shop.BuyEquipment(client, choice.id)
        frame:CloseFrame()
    end

    dcancel.DoClick = function()
        frame:CloseFrame()
    end

    dfav.DoClick = function()
        local pnl = dlist.SelectedPanel
        local role = drolesel and RolenameToRole(drolesel:GetValue()) or client:GetSubRole()

        if not pnl or not pnl.item then
            return
        end

        shop.SetFavoriteState(pnl.item.id, not pnl.favorite)

        -- Reload item list
        coroutine.resume(
            currentEquipmentCoroutine,
            { role = role, search = curSearch, notalive = notalive }
        )
    end

    -- Show the frame
    frame:MakePopup()

    eqframe = frame
end
concommand.Add("ttt_cl_traitorpopup", TraitorMenuPopup)

--
-- Force closes the menu
--

local function ForceCloseTraitorMenu(ply, cmd, args)
    if IsValid(eqframe) then
        ---@cast eqframe -nil
        eqframe:Close()
    end
end
concommand.Add("ttt_cl_traitorpopup_close", ForceCloseTraitorMenu)

--
-- NET RELATED STUFF:
--

local r = 0

local function ReceiveBought()
    local client = LocalPlayer()
    if not IsValid(client) then
        return
    end

    client.bought = {}

    local num = net.ReadUInt(8)

    for i = 1, num do
        local equipmentName = net.ReadString()
        if equipmentName ~= "" then
            client.bought[#client.bought + 1] = equipmentName

            shop.SetEquipmentBought(LocalPlayer(), equipmentName)
            shop.SetEquipmentTeamBought(client, equipmentName)
        end
    end

    -- This usermessage sometimes fails to contain the last weapon that was
    -- bought, even though resending then works perfectly. Possibly a bug in
    -- bf_read. Anyway, this hack is a workaround: we just request a new umsg.
    if num ~= #client.bought and r < 10 then -- r is an infinite loop guard
        RunConsoleCommand("ttt_resend_bought")

        r = r + 1
    else
        r = 0
    end
end
net.Receive("TTT_Bought", ReceiveBought)

-- Player received the item he has just bought, so run clientside init
local function ReceiveBoughtItem()
    local id = net.ReadString()

    local item = items.GetStored(id)
    if item and isfunction(item.Bought) then
        item:Bought(LocalPlayer())
    end

    ---
    -- I can imagine custom equipment wanting this, so making a hook
    -- @realm client
    hook.Run("TTTBoughtItem", item ~= nil, (item and item.oldId or nil) or id)
end
net.Receive("TTT_BoughtItem", ReceiveBoughtItem)

--
-- HOOKS / GAMEMODE RELATED STUFF:
--

---
-- Called when the context menu keybind (+menu_context) is pressed, which by default is C.<br />
-- See also @{GM:OnContextMenuClose}.
-- @hook
-- @realm client
-- @ref https://wiki.facepunch.com/gmod/GM:OnContextMenuOpen
-- @local
function GM:OnContextMenuOpen()
    local rs = gameloop.GetRoundState()

    if (rs == ROUND_PREP or rs == ROUND_POST) and not alwaysShowShopVar:GetBool() then
        CLSCORE:Toggle()

        return
    end

    -- this will close the CLSCORE panel if its currently visible
    if IsValid(CLSCORE.Panel) and CLSCORE.Panel:IsVisible() then
        CLSCORE.Panel:SetVisible(false)

        return
    end

    ---
    -- @realm client
    if hook.Run("TTT2PreventAccessShop", LocalPlayer()) then
        return
    end

    if IsValid(eqframe) then
        ---@cast eqframe -nil
        eqframe:Close()
    else
        RunConsoleCommand("ttt_cl_traitorpopup")
    end
end

-- Closes menu when roles are selected
hook.Add("TTTBeginRound", "TTTBEMCleanUp", function()
    if not IsValid(eqframe) then
        return
    end

    ---@cast eqframe -nil
    eqframe:Close()
end)

-- Closes menu when round is overwritten
hook.Add("TTTEndRound", "TTTBEMCleanUp", function()
    if not IsValid(eqframe) then
        return
    end

    ---@cast eqframe -nil
    eqframe:Close()
end)

-- Search text field focus hooks
local function getKeyboardFocus(pnl)
    if IsValid(eqframe) and pnl:HasParent(eqframe) then
        ---@cast eqframe -nil
        eqframe:SetKeyboardInputEnabled(true)
    end

    if not pnl.selectAll then
        return
    end

    pnl:SelectAllText()
end
hook.Add("OnTextEntryGetFocus", "BEM_GetKeyboardFocus", getKeyboardFocus)

local function loseKeyboardFocus(pnl)
    if not IsValid(eqframe) or not pnl:HasParent(eqframe) then
        return
    end

    ---@cast eqframe -nil
    eqframe:SetKeyboardInputEnabled(false)
end
hook.Add("OnTextEntryLoseFocus", "BEM_LoseKeyboardFocus", loseKeyboardFocus)

---
-- Called after TTT's settings window has been created. Used to add
-- your own tab to the settings window.
-- @param DPropertySheet dSheet The property sheet where contents can be added
-- @hook
-- @realm client
function GM:TTTEquipmentTabs(dSheet) end

---
-- A clientside hook that is called on the client of the player
-- that just bought an item. You probably don't want to use this as it
-- is recommended to use @{ITEM:Bought}.
-- @param boolean True if item, false if weapon
-- @param string idOrCls The id of the @{ITEM} or @{Weapon}, old id for @{ITEM} and class for @{Weapon}
-- @hook
-- @realm client
function GM:TTTBoughtItem(isItem, idOrCls) end

---
-- Cancelable hook to prevent the usage of the shop on the client.
-- @param Player ply The player that tries to access the shop
-- @return boolean Return true to prevent shop access
-- @hook
-- @realm client
function GM:TTT2PreventAccessShop(ply) end
