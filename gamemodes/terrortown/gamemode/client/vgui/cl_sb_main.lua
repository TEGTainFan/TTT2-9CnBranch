---
-- @desc VGUI panel version of the scoreboard, based on TEAM GARRY's sandbox mode
-- scoreboard.
-- @section Scoreboard

local surface = surface
local draw = draw
local math = math
local string = string
local vgui = vgui
local GetTranslation = LANG.GetTranslation
local GetPTranslation = LANG.GetParamTranslation
local table = table
local player = player
local pairs = pairs
local ipairs = ipairs
local timer = timer
local IsValid = IsValid
local playerGetAll = player.GetAll

ttt_include("vgui__cl_sb_team")

---
-- @realm client
-- @todo add Team!
local cv_ttt_scoreboard_sorting = CreateConVar(
    "ttt_scoreboard_sorting",
    "name",
    FCVAR_ARCHIVE,
    "name | role | karma | score | deaths | ping"
)

---
-- @realm client
local cv_ttt_scoreboard_ascending = CreateConVar(
    "ttt_scoreboard_ascending",
    "1",
    FCVAR_ARCHIVE,
    "Should scoreboard ordering be in ascending order"
)

GROUP_TERROR = 1
GROUP_NOTFOUND = 2
GROUP_FOUND = 3
GROUP_SPEC = 4

GROUP_COUNT = 4

---
-- Utility function to register a score group
-- @param string name
-- @realm client
function AddScoreGroup(name)
    if _G["GROUP_" .. name] then
        error("Group of name '" .. name .. "' already exists!")

        return
    end

    GROUP_COUNT = GROUP_COUNT + 1

    _G["GROUP_" .. name] = GROUP_COUNT
end

---
-- Returns the score group of a @{Player}
-- @param Player ply
-- @return number|string
-- @realm client
function ScoreGroup(ply)
    if not IsValid(ply) then -- will not match any group panel
        return -1
    end

    ---
    -- @realm client
    local group = hook.Run("TTTScoreGroup", ply)

    if group then -- If that hook gave us a group, use it
        return group
    end

    if gameloop.IsDetectiveMode() and ply:IsSpec() and not ply:Alive() then
        if ply:TTT2NETGetBool("body_found", false) then
            return GROUP_FOUND
        else
            local client = LocalPlayer()

            -- To terrorists, missing players show as alive
            if
                client:IsSpec()
                or client:IsActive() and client:GetSubRoleData().isOmniscientRole
                or gameloop.GetRoundState() ~= ROUND_ACTIVE and client:IsTerror()
            then
                return GROUP_NOTFOUND
            else
                return GROUP_TERROR
            end
        end
    end

    return ply:IsTerror() and GROUP_TERROR or GROUP_SPEC
end

TTTScoreboard = TTTScoreboard or {}
TTTScoreboard.Logo = surface.GetTextureID("vgui/ttt/score_logo_3")

surface.CreateFont("cool_small", {
    font = "coolvetica",
    size = 20,
    weight = 400,
})

surface.CreateFont("cool_large", {
    font = "coolvetica",
    size = 24,
    weight = 400,
})

surface.CreateFont("treb_small", {
    font = "Trebuchet18",
    size = 14,
    weight = 700,
})

---
-- Comparison functions used to sort scoreboard
sboard_sort = {
    name = function(plya, plyb)
        return 0 -- Automatically sorts by name if this returns 0
    end,
    ping = function(plya, plyb)
        return plya:Ping() - plyb:Ping()
    end,
    deaths = function(plya, plyb)
        return plya:Deaths() - plyb:Deaths()
    end,
    score = function(plya, plyb)
        return plya:Frags() - plyb:Frags()
    end,
    role = function(plya, plyb)
        local comp = (plya:GetSubRole() or 0) - (plyb:GetSubRole() or 0)
        -- Reverse on purpose
        --	otherwise the default ascending order puts boring innocents first
        comp = 0 - comp

        return comp
    end,
    karma = function(plya, plyb)
        return (plya:GetBaseKarma() or 0) - (plyb:GetBaseKarma() or 0)
    end,
}

---
-- @class PANEL
-- @section TTTScoreboard

local PANEL = {}

---
-- @ignore
function PANEL:Init()
    self.hostdesc = vgui.Create("DLabel", self)
    self.hostdesc:SetText(GetTranslation("sb_playing"))
    self.hostdesc:SetContentAlignment(9)

    self.hostname = vgui.Create("DLabel", self)
    self.hostname:SetText(GetHostName())
    self.hostname:SetContentAlignment(6)

    self.mapchange = vgui.Create("DLabel", self)
    self.mapchange:SetText("Map changes in 00 rounds or in 00:00:00")
    self.mapchange:SetContentAlignment(9)

    self.mapchange.Think = function(sf)
        if gameloop.HasLevelLimits() then
            local r, t = gameloop.UntilMapChange()

            sf:SetText(
                GetPTranslation(
                    "sb_mapchange_mode_" .. gameloop.GetLevelLimitsMode(),
                    { num = r + 1, time = t }
                )
            )
        else
            sf:SetText(GetTranslation("sb_mapchange_mode_0"))
        end

        sf:SizeToContents()
    end

    self.ply_frame = vgui.Create("TTTPlayerFrame", self)
    self.ply_groups = {}

    local t = vgui.Create("TTTScoreGroup", self.ply_frame:GetCanvas())
    t:SetGroupInfo(GetTranslation("terrorists"), Color(120, 140, 120, 100), GROUP_TERROR)     -- 浅绿灰色恐怖分子
    self.ply_groups[GROUP_TERROR] = t

    t = vgui.Create("TTTScoreGroup", self.ply_frame:GetCanvas())
    t:SetGroupInfo(GetTranslation("spectators"), Color(110, 120, 125, 100), GROUP_SPEC)       -- 中性灰色旁观者
    self.ply_groups[GROUP_SPEC] = t

    if gameloop.IsDetectiveMode() then
        t = vgui.Create("TTTScoreGroup", self.ply_frame:GetCanvas())
        t:SetGroupInfo(GetTranslation("sb_mia"), Color(140, 130, 120, 100), GROUP_NOTFOUND)    -- 暖灰色失踪者
        self.ply_groups[GROUP_NOTFOUND] = t

        t = vgui.Create("TTTScoreGroup", self.ply_frame:GetCanvas())
        t:SetGroupInfo(GetTranslation("sb_confirmed"), Color(130, 125, 110, 100), GROUP_FOUND) -- 棕灰色确认死亡
        self.ply_groups[GROUP_FOUND] = t
    end

    ---
    -- @realm client
    hook.Run("TTTScoreGroups", self.ply_frame:GetCanvas(), self.ply_groups)

    -- the various score column headers
    self.cols = {}

    self:AddColumn(GetTranslation("sb_ping"), nil, nil, "ping")
    self:AddColumn(GetTranslation("sb_deaths"), nil, nil, "deaths")
    self:AddColumn(GetTranslation("sb_score"), nil, nil, "score")

    if KARMA.IsEnabled() then
        self:AddColumn(GetTranslation("sb_karma"), nil, nil, "karma")
    end

    self.sort_headers = {}

    -- Reuse some translations
    self:AddFakeColumn(GetTranslation("sb_sortby"), nil, nil, nil) -- "Sort by:"
    self:AddFakeColumn(GetTranslation("equip_spec_name"), nil, nil, "name")
    self:AddFakeColumn(GetTranslation("col_roles"), nil, nil, "role")

    ---
    -- Let hooks add their column headers (via AddColumn() or AddFakeColumn())
    -- @realm client
    hook.Run("TTTScoreboardColumns", self)

    self:UpdateScoreboard()
    self:StartUpdateTimer()
end

local function sort_header_handler(self_, lbl)
    return function()
        surface.PlaySound("ui/buttonclick.wav")

        if lbl.HeadingIdentifier == cv_ttt_scoreboard_sorting:GetString() then
            cv_ttt_scoreboard_ascending:SetBool(not cv_ttt_scoreboard_ascending:GetBool())
        else
            cv_ttt_scoreboard_sorting:SetString(lbl.HeadingIdentifier)
            cv_ttt_scoreboard_ascending:SetBool(true)
        end

        for _, scoregroup in pairs(self_.ply_groups) do
            scoregroup:UpdateSortCache()
            scoregroup:InvalidateLayout()
        end

        self_:ApplySchemeSettings()
    end
end

---
-- For headings only the label parameter is relevant, second param is included for
-- parity with sb_row
local function column_label_work(self_, table_to_add, label, width, sort_identifier, sort_func)
    local lbl = vgui.Create("DLabel", self_)
    lbl:SetText(label)

    local can_sort = false

    lbl.IsHeading = true
    lbl.Width = width or 50 -- Retain compatibility with existing code

    if sort_identifier ~= nil then
        can_sort = true
        -- If we have an identifier and an existing sort function then it was a built-in
        -- Otherwise...
        if _G.sboard_sort[sort_identifier] == nil then
            if sort_func == nil then
                ErrorNoHaltWithStack(
                    "Sort ID provided without a sorting function, Label = ",
                    label,
                    " ; ID = ",
                    sort_identifier
                )

                can_sort = false
            else
                _G.sboard_sort[sort_identifier] = sort_func
            end
        end
    end

    if can_sort then
        lbl:SetMouseInputEnabled(true)
        lbl:SetCursor("hand")

        lbl.HeadingIdentifier = sort_identifier
        lbl.DoClick = sort_header_handler(self_, lbl)
    end

    table.insert(table_to_add, lbl)

    return lbl
end

---
-- Adds column headers with player-specific data
-- @param string label
-- @param any _
-- @param number width
-- @param number sort_id
-- @param function sort_func
-- @return Panel DLabel
-- @see PANEL:AddFakeColumn
-- @realm client
function PANEL:AddColumn(label, _, width, sort_id, sort_func)
    return column_label_work(self, self.cols, label, width, sort_id, sort_func)
end

---
-- Returns the current columns
-- @return table
-- @realm client
function PANEL:GetColumns()
    return self.cols
end

---
-- Adds just column headers without player-specific data
-- Identical to PANEL:AddColumn except it adds to the sort_headers table instead
-- @param string label
-- @param any _
-- @param number width
-- @param number sort_id
-- @param function sort_func
-- @return Panel DLabel
-- @see PANEL:AddColumn
-- @realm client
function PANEL:AddFakeColumn(label, _, width, sort_id, sort_func)
    return column_label_work(self, self.sort_headers, label, width, sort_id, sort_func)
end

local function _sbfunc()
    local pnl = GAMEMODE:GetScoreboardPanel()

    if IsValid(pnl) then
        pnl:UpdateScoreboard()
    end
end

---
-- Starts the update timer (if not already started)
-- @realm client
function PANEL:StartUpdateTimer()
    if not timer.Exists("TTTScoreboardUpdater") then
        timer.Create("TTTScoreboardUpdater", 0.3, 0, _sbfunc)
    end
end

local colors = {
    bg = Color(35, 39, 46, 245),              -- 现代深蓝灰色背景
    bgHeader = Color(25, 29, 35, 255),        -- 更深的头部背景
    bar = Color(52, 152, 219, 255),           -- 现代蓝色条形
    barGlow = Color(52, 152, 219, 100),       -- 蓝色光晕
    shadow = Color(0, 0, 0, 120),             -- 阴影色
    text = Color(255, 255, 255, 255),         -- 主文字色
    textSecondary = Color(180, 185, 195, 255), -- 次要文字色
}

local y_logo_off = 120  -- logo区域高度，适配新logo尺寸

---
-- @ignore
function PANEL:Paint()
    local w, h = self:GetWide(), self:GetTall()
    
    -- Logo区域背景阴影
    draw.RoundedBox( 12, -6, -6, w + 12, y_logo_off + 12, colors.shadow )
    
    -- Logo区域背景
    draw.RoundedBox( 12, 0, 0, w, y_logo_off, Color(30, 34, 40, 230) )
    
    -- 主背景阴影
    draw.RoundedBox( 12, -6, y_logo_off - 6, w + 12, h - y_logo_off + 12, colors.shadow )
    
    -- 主背景
    draw.RoundedBox( 12, 0, y_logo_off, w, h - y_logo_off, colors.bg )
    
    -- 头部区域背景
    draw.RoundedBoxEx( 12, 0, y_logo_off + 2, w, 40, colors.bgHeader, true, true, false, false )
    
    -- TTT Logo - 居左显示
    local logo_width = 299  -- logo宽度 (499像素缩放到60%)
    local logo_height = 154  -- logo高度 (256像素缩放到60%)
    local logo_x = 15  -- 左边距
    local logo_y = (y_logo_off - logo_height) * 0.5 - 8  -- 在logo区域内垂直居中并稍微下移
    
    surface.SetTexture(TTTScoreboard.Logo)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(logo_x, logo_y, logo_width, logo_height)
end

---
-- @ignore
function PANEL:PerformLayout()
    -- position groups and find their total size
    local gy = 0

    -- can't just use pairs (undefined ordering) or ipairs (group 2 and 3 might not exist)
    for i = 1, GROUP_COUNT do
        local group = self.ply_groups[i]

        if IsValid(group) then
            if group:HasRows() then
                group:SetVisible(true)
                group:SetPos(0, gy)
                group:SetSize(self.ply_frame:GetWide(), group:GetTall())
                group:InvalidateLayout()

                gy = gy + group:GetTall() + 5
            else
                group:SetVisible(false)
            end
        end
    end

    self.ply_frame:GetCanvas():SetSize(self.ply_frame:GetCanvas():GetWide(), gy)

    local h = y_logo_off + 45 + self.ply_frame:GetCanvas():GetTall()

    -- if we will have to clamp our height, enable the mouse so player can scroll
    local scrolling = h > ScrH() * 0.95
    --	gui.EnableScreenClicker(scrolling)
    self.ply_frame:SetScroll(scrolling)

    h = math.Clamp(h, 45 + y_logo_off, ScrH() * 0.95)

    local w = math.max(ScrW() * 0.6, 640)

    self:SetSize(w, h)
    self:SetPos((ScrW() - w) * 0.5, math.min(72, (ScrH() - h) * 0.25))

    self.ply_frame:SetPos(8, y_logo_off + 45)
    self.ply_frame:SetSize(self:GetWide() - 16, self:GetTall() - 45 - y_logo_off - 5)

    -- server stuff - 重新定位到logo右侧
    local logo_width = 299
    local logo_end_x = 15 + logo_width + 25  -- logo右边缘加间距
    local info_start_y = (y_logo_off - 60) * 0.5  -- 在logo区域内垂直居中信息块
    
    self.hostdesc:SizeToContents()
    self.hostdesc:SetPos(w - self.hostdesc:GetWide() - 8, info_start_y)

    local hw = w - logo_end_x - 16

    self.hostname:SetSize(hw, 22)
    self.hostname:SetPos(w - self.hostname:GetWide() - 8, info_start_y + 20)

    surface.SetFont("cool_large")

    local hname = self.hostname:GetValue()
    local tw = surface.GetTextSize(hname)

    while tw > hw do
        hname = string.sub(hname, 1, -6) .. "..."
        tw, th = surface.GetTextSize(hname)
    end

    self.hostname:SetText(hname)

    self.mapchange:SizeToContents()
    self.mapchange:SetPos(w - self.mapchange:GetWide() - 8, info_start_y + 45)

    -- score columns
    local cy = y_logo_off + 12
    local cx = w - 8 - (scrolling and 16 or 0)

    for _, v in ipairs(self.cols) do
        v:SizeToContents()

        cx = cx - v.Width

        v:SetPos(cx - v:GetWide() * 0.5, cy)
    end

    -- sort headers
    -- reuse cy
    -- cx = logo width + buffer space
    cx = 256 + 8

    for _, v in ipairs(self.sort_headers) do
        v:SizeToContents()

        cx = cx + v.Width

        v:SetPos(cx - v:GetWide() * 0.5, cy)
    end
end

---
-- @ignore
function PANEL:ApplySchemeSettings()
    self.hostdesc:SetFont("cool_small")
    self.hostname:SetFont("cool_large")
    self.mapchange:SetFont("treb_small")

    self.hostdesc:SetTextColor(colors.textSecondary)    -- 现代次要文字色
    self.hostname:SetTextColor(colors.text)             -- 现代主文字色
    self.mapchange:SetTextColor(colors.textSecondary)   -- 现代次要文字色

    local sorting = cv_ttt_scoreboard_sorting:GetString()
    local highlight_color = Color(52, 152, 219, 255)    -- 蓝色高亮
    local default_color = colors.text                     -- 现代默认文字色

    for _, v in pairs(self.cols) do
        v:SetFont("treb_small")

        if sorting == v.HeadingIdentifier then
            v:SetTextColor(highlight_color)
        else
            v:SetTextColor(default_color)
        end
    end

    for _, v in pairs(self.sort_headers) do
        v:SetFont("treb_small")

        if sorting == v.HeadingIdentifier then
            v:SetTextColor(highlight_color)
        else
            v:SetTextColor(default_color)
        end
    end
end

---
-- @param boolean force
-- @realm client
function PANEL:UpdateScoreboard(force)
    if not force and not self:IsVisible() then
        return
    end

    local layout = false

    -- Put players where they belong. Groups will dump them as soon as they don't
    -- anymore.
    local plys = playerGetAll()
    for i = 1, #plys do
        local p = plys[i]
        if IsValid(p) then
            local group = ScoreGroup(p)

            if self.ply_groups[group] and not self.ply_groups[group]:HasPlayerRow(p) then
                self.ply_groups[group]:AddPlayerRow(p)

                layout = true
            end
        end
    end

    for _, group in pairs(self.ply_groups) do
        if IsValid(group) then
            group:SetVisible(group:HasRows())
            group:UpdatePlayerData()
        end
    end

    if layout then
        self:PerformLayout()
    else
        self:InvalidateLayout()
    end
end

vgui.Register("TTTScoreboard", PANEL, "Panel")

---
-- PlayerFrame is defined in sandbox and is basically a little scrolling
-- hack. Just putting it here (slightly modified) because it's tiny.
-- @section TTTPlayerFrame

PANEL = {}

---
-- @ignore
function PANEL:Init()
    self.pnlCanvas = vgui.Create("Panel", self)
    self.YOffset = 0

    self.scroll = vgui.Create("DVScrollBar", self)
end

---
-- @return Panel
-- @realm client
function PANEL:GetCanvas()
    return self.pnlCanvas
end

---
-- @param number dlta
-- @realm client
function PANEL:OnMouseWheeled(dlta)
    self.scroll:AddScroll(dlta * -2)

    self:InvalidateLayout()
end

---
-- Toggle scrolling
-- @param boolean st
-- @realm client
function PANEL:SetScroll(st)
    self.scroll:SetEnabled(st)
end

---
-- @ignore
function PANEL:PerformLayout()
    self.pnlCanvas:SetVisible(self:IsVisible())

    -- scrollbar
    self.scroll:SetPos(self:GetWide() - 16, 0)
    self.scroll:SetSize(16, self:GetTall())

    local was_on = self.scroll.Enabled

    self.scroll:SetUp(self:GetTall(), self.pnlCanvas:GetTall())
    self.scroll:SetEnabled(was_on) -- setup mangles enabled state

    self.YOffset = self.scroll:GetOffset()

    self.pnlCanvas:SetPos(0, self.YOffset)
    self.pnlCanvas:SetSize(
        self:GetWide() - (self.scroll.Enabled and 16 or 0),
        self.pnlCanvas:GetTall()
    )
end

vgui.Register("TTTPlayerFrame", PANEL, "Panel")

---
-- Called to determine if the player should be listed in a different scoreboard group than they would normally be in.
-- These correspond to the four groups in the scoreboard of living, dead but not found, confirmed dead, and spectators.
-- @param Player ply The player whose score group should be modified
-- @return nil|number The scoregroup, it must be one of: GROUP_TERROR, GROUP_NOTFOUND, GROUP_FOUND, or GROUP_SPEC
-- @hook
-- @realm client
function GM:TTTScoreGroup(ply) end

---
-- Called when initializing the scoreboard. In this hook you could add additional panels for new player groups,
-- combined with @{GM:TTTScoreGroup }to place players in those groups.
-- @param Panel parent The panel containing the player group panels
-- @param table playerGroup A table of the player group panels
-- @hook
-- @realm client
function GM:TTTScoreGroups(parent, playerGroup) end

---
-- Use this hook to add a new column to the scoreboard. Use @{TTTPlayerFrame:AddColumn}
-- to add a new column.
-- @param TTTPlayerFrame panel The player frame panel where a new column can be added
-- @hook
-- @realm client
function GM:TTTScoreboardColumns(panel) end
