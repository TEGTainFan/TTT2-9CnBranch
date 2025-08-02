---
-- Handles the loading screen that is shown on map reload.
-- @author Mineotopia

if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("ttt2/libraries/loadingscreen_visual_config.lua")

    util.AddNetworkString("TTT2LoadingScreenActive")
end

-- 加载视觉配置
include("ttt2/libraries/loadingscreen_visual_config.lua")

---
-- @realm server
local cvLoadingScreenEnabled = CreateConVar(
    "ttt2_enable_loadingscreen_server",
    "1",
    { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }
)

---
-- @realm server
local cvLoadingScreenMinDuration = CreateConVar(
    "ttt2_loadingscreen_min_duration",
    "4",
    { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }
)

loadingscreen = loadingscreen or {}

loadingscreen.isShown = false
loadingscreen.wasShown = false
loadingscreen.disableSounds = false

---
-- Called when the loading screen should begin.
-- @note Syncs it to the client when called on the server.
-- @internal
-- @realm shared
function loadingscreen.Begin()
    if not cvLoadingScreenEnabled:GetBool() then
        return
    end

    -- add manual syncing so that the loading screen starts as soon as the
    -- cleanup map is started
    if SERVER then
        loadingscreen.timeBegin = SysTime()

        timer.Remove("TTT2LoadingscreenEndTime")

        net.Start("TTT2LoadingScreenActive")
        net.WriteBool(true)
        net.Broadcast()
    end

    if CLIENT then
        timer.Remove("TTT2LoadingscreenShow")
        timer.Remove("TTT2LoadingscreenHide")

        MSTACK:ClearMessages()
    end

    loadingscreen.isShown = true
    loadingscreen.disableSounds = true
end

---
-- Called when the loading screen should end.
-- @internal
-- @realm shared
function loadingscreen.End()
    if CLIENT then
        loadingscreen.isShown = false
    end

    if SERVER then
        local duration = (loadingscreen.timeBegin or SysTime())
            - SysTime()
            + loadingscreen.GetDuration()

        -- this timer makes sure the loading screen is displayed for at least the
        -- time that is set as the minimum time
        timer.Create("TTT2LoadingscreenEndTime", duration, 1, function()
            loadingscreen.isShown = false

            net.Start("TTT2LoadingScreenActive")
            net.WriteBool(false)
            net.Broadcast()

            -- disables sounds a while longer so it stays muted
            timer.Simple(1.5, function()
                loadingscreen.disableSounds = false
            end)
        end)
    end
end

if SERVER then
    -- mutes the sound while the loading screen is shown
    -- this makes it so that you can't hear weapons spawning
    hook.Add("EntityEmitSound", "TTT2PreventReloadingSound", function(data)
        if loadingscreen.disableSounds then
            return false
        end
    end)

    ---
    -- Reads the minimum time that a loadingscreen should have.
    -- @return number The minimum time
    -- @realm server
    function loadingscreen.GetDuration()
        if cvLoadingScreenEnabled:GetBool() then
            return cvLoadingScreenMinDuration:GetFloat()
        else
            return 0
        end
    end
end

if CLIENT then
    local LS_HIDDEN = 0
    local LS_FADE_IN = 1
    local LS_SHOWN = 2
    local LS_FADE_OUT = 3

    local durationStateChange = 0.35

    ---
    -- @realm client
    local cvLoadingScreen = CreateConVar("ttt2_enable_loadingscreen", "1", { FCVAR_ARCHIVE })

    -- 动画状态追踪
    loadingscreen.state = LS_HIDDEN
    loadingscreen.timeStateChange = SysTime()
    
    -- LOGO材质
    loadingscreen.logoMaterial = nil
    
    -- 加载LOGO材质
    local function LoadLogo()
        local logoPath = "materials/tttr/logo24.png"
        
        if logoPath ~= "" and isstring(logoPath) and file.Exists(logoPath, "GAME") then
            if not loadingscreen.logoMaterial then
                local materialPath = string.gsub(logoPath, "^materials/", "")
                
                local success, result = pcall(function()
                    return Material(materialPath)
                end)
                
                if success and result then
                    loadingscreen.logoMaterial = result
                else
                    loadingscreen.logoMaterial = nil
                end
            end
        else
            loadingscreen.logoMaterial = nil
        end
    end

    net.Receive("TTT2LoadingScreenActive", function()
        if net.ReadBool() then
            loadingscreen.Begin()
        else
            loadingscreen.End()
        end
    end)

    ---
    -- Handles the loading screen transistions and drawing.
    -- @internal
    -- @realm client
    function loadingscreen.Handler()
        -- start loadingscreen
        if loadingscreen.isShown and not loadingscreen.wasShown then
            loadingscreen.state = LS_FADE_IN
            loadingscreen.timeStateChange = SysTime()
            
            -- 加载LOGO
            LoadLogo()

            if cvLoadingScreen:GetBool() then
                surface.PlaySound("ttt/loadingscreen.wav")
            end

            timer.Create("TTT2LoadingscreenShow", durationStateChange, 1, function()
                loadingscreen.state = LS_SHOWN
                loadingscreen.timeStateChange = SysTime()
            end)

            loadingscreen.wasShown = true

        -- stop loadingscreen
        elseif not loadingscreen.isShown and loadingscreen.wasShown then
            loadingscreen.state = LS_FADE_OUT
            loadingscreen.timeStateChange = SysTime()

            timer.Create("TTT2LoadingscreenHide", durationStateChange * 2, 1, function()
                loadingscreen.state = LS_HIDDEN
                loadingscreen.timeStateChange = SysTime()

                timer.Remove("TTT2LoadingscreenShow")
            end)

            loadingscreen.wasShown = false
        end

        loadingscreen.Draw()
    end

    ---
    -- Handles the loading screen drawing.
    -- @internal
    -- @realm client
    function loadingscreen.Draw()
        if not cvLoadingScreen:GetBool() or loadingscreen.state == LS_HIDDEN then
            return
        end

        local progress = 1

        if loadingscreen.state == LS_FADE_IN then
            progress = math.min((SysTime() - loadingscreen.timeStateChange) / durationStateChange, 1.0)
        elseif loadingscreen.state == LS_FADE_OUT then
            progress = 1 - math.min((SysTime() - loadingscreen.timeStateChange) / durationStateChange, 1.0)
        end

        -- stop rendering the loadingscreen if the progress is close to 0
        if progress < 0.01 then
            return
        end
        
        -- 背景模糊效果
        local blurIntensity = LoadingScreenVisual and LoadingScreenVisual.GetBlurIntensity() or 15
        draw.BlurredBox(0, 0, ScrW(), ScrH(), progress * blurIntensity)
        
        -- 主背景覆盖层 
        local overlayColor = Color(0, 183, 255, 113, 200 * progress)
        draw.Box(0, 0, ScrW(), ScrH(), overlayColor)

        -- LOGO绘制
        local centerX, centerY = ScrW() / 2, ScrH() / 2
        
        if loadingscreen.logoMaterial then
            local logoSize = 600
            local logoWidth = logoSize
            local logoHeight = logoSize
            
            -- 简单的淡入动画
            local fadeProgress = math.min(progress * 1.5, 1)
            
            -- LOGO阴影
            surface.SetMaterial(loadingscreen.logoMaterial)
            surface.SetDrawColor(0, 0, 0, 80 * fadeProgress)
            surface.DrawTexturedRect(centerX - logoWidth/2 + 3, centerY - logoHeight/2 + 3, logoWidth, logoHeight)
            
            -- 主LOGO
            surface.SetDrawColor(255, 255, 255, 255 * fadeProgress)
            surface.DrawTexturedRect(centerX - logoWidth/2, centerY - logoHeight/2, logoWidth, logoHeight)
        else
            -- 备用文字标题
            local titleText = "TTT2"
            local titleFont = "DermaTTT2TextHuge"
            
            draw.SimpleText(
                titleText,
                titleFont,
                centerX,
                centerY,
                Color(255, 255, 255, 255 * progress),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end
    end

    -- 测试命令 - 用于调试加载页面
    concommand.Add("ttt2_test_loadingscreen", function()
        if loadingscreen.isShown then
            loadingscreen.End()
        else
            loadingscreen.Begin()
        end
    end)
end