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

        loadingscreen.currentTipText, loadingscreen.currentTipKeys = tips.GetRandomTip()

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

    ---
    -- @realm client
    local cvLoadingScreenTips = CreateConVar("ttt_tips_enable", "1", { FCVAR_ARCHIVE })

    -- 动画时间追踪
    loadingscreen.state = LS_HIDDEN
    loadingscreen.timeStateChange = SysTime()
    loadingscreen.animationStartTime = 0
    
    -- 粒子系统
    loadingscreen.particles = {}
    
    -- LOGO材质
    loadingscreen.logoMaterial = nil
    
    -- 提示文本
    loadingscreen.currentTipText = nil
    loadingscreen.currentTipKeys = {}
    
    -- 初始化粒子
    local function InitParticles()
        loadingscreen.particles = {}
        local particleCount = LoadingScreenVisual and LoadingScreenVisual.GetParticleCount() or 20
        
        for i = 1, particleCount do
            table.insert(loadingscreen.particles, {
                x = math.random(0, ScrW()),
                y = math.random(0, ScrH()),
                size = math.random(2, 6),
                speed = math.random(10, 30),
                alpha = math.random(50, 150),
                direction = math.random(0, 360),
                life = math.random(3, 8)
            })
        end
    end
    
    -- 初始化提示文本 - 使用原版提示系统
    local function InitTips()
        -- 确保tips系统已初始化
        if tips and tips.Initialize then
            tips.Initialize()
        end
        
        if tips and tips.GetRandomTip then
            loadingscreen.currentTipText, loadingscreen.currentTipKeys = tips.GetRandomTip()
        else
            -- 备用提示
            loadingscreen.currentTipText = "tip1"
            loadingscreen.currentTipKeys = {}
        end
    end
    
    -- 加载LOGO材质
    local function LoadLogo()
        local logoPath = LoadingScreenVisual and LoadingScreenVisual.GetLogoPath() or "materials/tttr/logo24.png"
        
        if logoPath ~= "" and isstring(logoPath) and file.Exists(logoPath, "GAME") then
            if not loadingscreen.logoMaterial then
                -- 安全地处理路径字符串，只取第一个返回值
                local materialPath = string.gsub(logoPath, "^materials/", "")
                
                -- 添加错误处理
                local success, result = pcall(function()
                    return Material(materialPath)
                end)
                
                if success and result then
                    loadingscreen.logoMaterial = result
                else
                    loadingscreen.logoMaterial = nil
                    ErrorNoHaltWithStack("Failed to load LOGO material: " .. tostring(materialPath))
                end
            end
        else
            loadingscreen.logoMaterial = nil
        end
    end
    
    -- 绘制圆形辅助函数
    local function DrawCircle(x, y, radius, segments)
        local points = {}
        segments = segments or 36
        
        for i = 1, segments do
            local angle = (i / segments) * math.pi * 2
            table.insert(points, {
                x = x + math.cos(angle) * radius,
                y = y + math.sin(angle) * radius
            })
        end
        
        surface.DrawPoly(points)
    end
    
    -- 绘制LOGO
    local function DrawLogo(progress)
        if not loadingscreen.logoMaterial or not LoadingScreenVisual or not LoadingScreenVisual.ShouldShowLogo() then
            return
        end
        
        local centerX, centerY = ScrW() / 2, ScrH() / 2
        local animSpeed = LoadingScreenVisual.GetAnimationSpeed()
        local time = (SysTime() - loadingscreen.animationStartTime) * animSpeed
        
        -- LOGO尺寸配置
        local logoSize = LoadingScreenVisual.GetLogoSize()
        local logoWidth = logoSize * 2
        local logoHeight = logoSize * 2
        
        -- 动画效果
        local fadeProgress = math.min(progress * 2, 1) -- LOGO比其他元素更快出现
        local scaleAnim = 0.8 + math.sin(time * 1.5) * 0.1 -- 轻微的缩放动画
        local rotateAnim = math.sin(time * 0.5) * 2 -- 轻微的摆动
        
        -- 计算最终尺寸
        local finalWidth = logoWidth * scaleAnim
        local finalHeight = logoHeight * scaleAnim
        
        -- LOGO阴影
        surface.SetMaterial(loadingscreen.logoMaterial)
        surface.SetDrawColor(0, 0, 0, 100 * fadeProgress)
        
        local shadowOffset = 5
        surface.DrawTexturedRectRotated(
            centerX + shadowOffset, 
            centerY + shadowOffset, 
            finalWidth, 
            finalHeight, 
            rotateAnim
        )
        
        -- 主LOGO
        surface.SetDrawColor(255, 255, 255, 255 * fadeProgress)
        surface.DrawTexturedRectRotated(
            centerX, 
            centerY, 
            finalWidth, 
            finalHeight, 
            rotateAnim
        )
        
        -- LOGO光晕效果
        if LoadingScreenVisual.ShouldShowLogoGlow() then
            local glowAlpha = (math.sin(time * 3) * 0.3 + 0.7) * fadeProgress * 30
            surface.SetDrawColor(vskin.GetAccentColor().r, vskin.GetAccentColor().g, vskin.GetAccentColor().b, glowAlpha)
            surface.DrawTexturedRectRotated(
                centerX, 
                centerY, 
                finalWidth * 1.2, 
                finalHeight * 1.2, 
                rotateAnim
            )
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
            loadingscreen.animationStartTime = SysTime()
            

            
            -- 初始化粒子效果
            InitParticles()
            
            -- 初始化提示文本
            InitTips()
            
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

    -- 绘制动态粒子
    local function DrawParticles(progress)
        local animSpeed = LoadingScreenVisual and LoadingScreenVisual.GetAnimationSpeed() or 1
        local frameTime = FrameTime() * animSpeed
        
        for i = #loadingscreen.particles, 1, -1 do
            local particle = loadingscreen.particles[i]
            
            -- 更新粒子位置
            particle.x = particle.x + math.cos(math.rad(particle.direction)) * particle.speed * frameTime
            particle.y = particle.y + math.sin(math.rad(particle.direction)) * particle.speed * frameTime
            particle.life = particle.life - frameTime
            
            -- 边界检查
            if particle.x < 0 then particle.x = ScrW() end
            if particle.x > ScrW() then particle.x = 0 end
            if particle.y < 0 then particle.y = ScrH() end
            if particle.y > ScrH() then particle.y = 0 end
            
            -- 移除过期粒子
            if particle.life <= 0 then
                table.remove(loadingscreen.particles, i)
            else
                -- 绘制粒子
                local alpha = particle.alpha * progress * (particle.life / 8)
                surface.SetDrawColor(255, 255, 255, alpha)
                surface.DrawRect(particle.x - particle.size/2, particle.y - particle.size/2, particle.size, particle.size)
            end
        end
    end
    
    -- 绘制渐变背景
    local function DrawGradientBackground(progress)
        local centerX, centerY = ScrW() / 2, ScrH() / 2
        local baseColor = vskin.GetDarkAccentColor()
        local time = SysTime() - loadingscreen.animationStartTime
        
        -- 多层渐变效果
        for i = 1, 5 do
            local radius = (ScrW() + ScrH()) * 0.3 * i
            local offsetX = math.sin(time * 0.5 + i) * 50
            local offsetY = math.cos(time * 0.3 + i) * 30
            
            local alpha = (50 - i * 8) * progress
            local color = Color(baseColor.r + i * 10, baseColor.g + i * 5, baseColor.b + i * 15, alpha)
            
            draw.NoTexture()
            surface.SetDrawColor(color)
            
            -- 绘制径向渐变圆
            local segments = 32
            surface.DrawPoly({
                { x = centerX + offsetX, y = centerY + offsetY },
                { x = centerX + offsetX + radius, y = centerY + offsetY },
                { x = centerX + offsetX, y = centerY + offsetY + radius },
                { x = centerX + offsetX - radius, y = centerY + offsetY },
                { x = centerX + offsetX, y = centerY + offsetY - radius }
            })
        end
    end
    
    -- 绘制装饰性几何图形
    local function DrawDecoElements(progress, baseColor)
        local animSpeed = LoadingScreenVisual and LoadingScreenVisual.GetAnimationSpeed() or 1
        local time = (SysTime() - loadingscreen.animationStartTime) * animSpeed
        local centerX, centerY = ScrW() / 2, ScrH() / 2
        
        -- 旋转的六边形
        for i = 1, 3 do
            local size = 100 + i * 50
            local rotation = time * (30 + i * 10)
            local alpha = 30 * progress
            
            surface.SetDrawColor(255, 255, 255, alpha)
            
            local points = {}
            for j = 1, 6 do
                local angle = math.rad(rotation + j * 60)
                table.insert(points, {
                    x = centerX + math.cos(angle) * size,
                    y = centerY + math.sin(angle) * size
                })
            end
            
            surface.DrawPoly(points)
        end
        
        -- 脉冲圆环
        local pulseSize = 150 + math.sin(time * 3) * 30
        surface.SetDrawColor(vskin.GetAccentColor().r, vskin.GetAccentColor().g, vskin.GetAccentColor().b, 40 * progress)
        draw.NoTexture()
        
        -- 绘制圆环 (外圆)
        DrawCircle(centerX, centerY, pulseSize, 48)
        
        -- 绘制内圆 (用背景色遮盖)
        surface.SetDrawColor(baseColor.r, baseColor.g, baseColor.b, 200 * progress)
        DrawCircle(centerX, centerY, pulseSize - 4, 48)
    end

    ---
    -- Handles the loading screen drawing.
    -- @internal
    -- @realm client
    function loadingscreen.Draw()
        -- 添加基础状态调试
        if not cvLoadingScreen:GetBool() then
            print("[TTT2加载屏幕] 已禁用 (cvLoadingScreen = false)")
            return
        end
        
        if loadingscreen.state == LS_HIDDEN then
            print("[TTT2加载屏幕] 隐藏状态")
            return
        end

        local progress = 1

        if loadingscreen.state == LS_FADE_IN then
            progress = math.min((SysTime() - loadingscreen.timeStateChange) / durationStateChange, 1.0)
            print("[TTT2加载屏幕] 淡入状态 - 进度:", math.floor(progress * 100), "%")
        elseif loadingscreen.state == LS_FADE_OUT then
            progress = 1 - math.min((SysTime() - loadingscreen.timeStateChange) / durationStateChange, 1.0)
            print("[TTT2加载屏幕] 淡出状态 - 进度:", math.floor(progress * 100), "%")
        end

        -- 调试信息：显示关键状态
        local debugInfo = {
            state = loadingscreen.state,
            progress = progress,
            timeStateChange = loadingscreen.timeStateChange,
            currentTime = SysTime(),
            hasLoadingScreenVisual = LoadingScreenVisual ~= nil,
            hasVskin = vskin ~= nil,
            hasAppearance = appearance ~= nil,
            logoMaterial = loadingscreen.logoMaterial ~= nil,
            currentTipText = loadingscreen.currentTipText ~= nil,
            screenWidth = ScrW(),
            screenHeight = ScrH(),
            centerX = ScrW() / 2,
            centerY = ScrH() / 2,
            hasPureSkinRole = surface.GetFont("PureSkinRole") ~= nil,
            cvLoadingScreen = cvLoadingScreen:GetBool(),
            cvLoadingScreenTips = cvLoadingScreenTips:GetBool()
        }
        
        -- 格式化输出调试信息
        print("=== TTT2加载屏幕调试信息 ===")
        for k, v in pairs(debugInfo) do
            print(string.format("[TTT2加载屏幕] %s: %s", k, tostring(v)))
        end
        print("==========================")

        -- 在绘制加载文本之前添加更详细的调试
        local dotCount = math.floor(time * 2) % 4
        local loadingDots = string.rep(".", dotCount)
        local loadingText = "加载中" .. loadingDots
        
        -- 检查字体是否可用
        local fontAvailable = false
        pcall(function()
            local font = surface.GetFont("PureSkinRole")
            fontAvailable = font ~= nil
        end)
        
        print("=== TTT2加载文本状态 ===")
        print(string.format("[TTT2加载屏幕] 文本内容: %s", loadingText))
        print(string.format("[TTT2加载屏幕] 点数量: %d", dotCount))
        print(string.format("[TTT2加载屏幕] 位置: X=%d, Y=%d", ScrW() / 2, ScrH() / 2 + 50))
        print(string.format("[TTT2加载屏幕] 字体状态: %s", fontAvailable and "可用" or "不可用"))
        print("========================")

        -- 如果字体不可用，使用备用字体
        local fontName = fontAvailable and "PureSkinRole" or "DermaLarge"
        
        -- 绘制加载文本
        pcall(function()
            draw.AdvancedText(
                loadingText,
                fontName,
                ScrW() / 2,
                ScrH() / 2 + 50,
                Color(255, 255, 255, 255 * progress),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER,
                true,
                appearance and appearance.GetGlobalScale and appearance.GetGlobalScale() or 1
            )
        end)

        -- 提示文本区域
        

        
        if cvLoadingScreenTips:GetBool() then
            local tipY = ScrH() * 0.8 -- 恢复到80%位置
            
            -- 提示背景装饰 - 更深的背景提高对比度
            local tipBgAlpha = 80 * progress
            surface.SetDrawColor(0, 0, 0, tipBgAlpha)
            surface.DrawRect(ScrW() * 0.15, tipY - 20, ScrW() * 0.7, 85) -- 进一步紧凑的背景框
            
            -- 提示边框 - 更亮的边框
            surface.SetDrawColor(255, 255, 100, 150 * progress) -- 亮黄色边框
            surface.DrawOutlinedRect(ScrW() * 0.15, tipY - 20, ScrW() * 0.7, 85) -- 进一步紧凑的背景框
            
            -- 提示标题阴影
            local tipTitle = LANG.TryTranslation("tips_panel_tip") or "提示"
            draw.AdvancedText(
                tipTitle,
                "PureSkinRole",
                ScrW() / 2 + 1,
                tipY - 5 + 1,
                Color(0, 0, 0, 150 * progress),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER,
                true,
                appearance.GetGlobalScale()
            )
            
            -- 提示标题主文字
            draw.SimpleText(
                tipTitle,
                "DermaLarge", -- 恢复原来的字体
                ScrW() / 2,
                tipY + 5, -- 标题在框内下移
                Color(255, 255, 100, 255), -- 亮黄色标题
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

            -- 提示内容
            local tipContent
            if loadingscreen.currentTipText and loadingscreen.currentTipKeys then
                tipContent = LANG.GetParamTranslation(
                    loadingscreen.currentTipText,
                    loadingscreen.currentTipKeys
                )
                
                -- 如果翻译结果为空，使用备用内容
                if not tipContent or tipContent == "" or tipContent == loadingscreen.currentTipText then
                    tipContent = "欢迎来到 TTT2！准备好开始新一轮的游戏了吗？"
                end
            else
                -- 备用提示内容
                tipContent = "欢迎来到 TTT2！准备好开始新一轮的游戏了吗？"
            end
            
            local textWrapped, _, heightText = draw.GetWrappedText(
                tipContent,
                ScrW() * 0.7,
                "DermaLarge", -- 使用与绘制相同的字体
                1 -- 不使用缩放
            )

            local heightLine = heightText / #textWrapped
            local startY = tipY + 35 -- 内容文本在框内下移
            
            for i = 1, #textWrapped do
                -- 文字阴影
                draw.SimpleText(
                    textWrapped[i],
                    "DermaLarge", -- 恢复原来的字体
                    ScrW() / 2 + 3,
                    startY + (i-1) * (heightLine + 5) + 3, -- 减少行距和阴影偏移
                    Color(0, 0, 0, 180), -- 阴影
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
                
                -- 主文字
                draw.SimpleText(
                    textWrapped[i],
                    "DermaLarge", -- 恢复原来的字体
                    ScrW() / 2,
                    startY + (i-1) * (heightLine + 5), -- 减少行距
                    Color(255, 255, 255, 255), -- 白色主文字
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end
    end
end
