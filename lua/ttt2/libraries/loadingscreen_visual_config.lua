---
-- TTT2 加载屏幕视觉效果配置
-- @author TTT2 Community

if SERVER then
    AddCSLuaFile()
end

-- 视觉效果配置
LoadingScreenVisual = LoadingScreenVisual or {}

if CLIENT then
    -- 视觉效果控制台变量
    local cvParticleCount = CreateConVar("ttt2_loadingscreen_particles", "20", { FCVAR_ARCHIVE })
    local cvShowGeometry = CreateConVar("ttt2_loadingscreen_geometry", "1", { FCVAR_ARCHIVE })
    local cvBlurIntensity = CreateConVar("ttt2_loadingscreen_blur", "15", { FCVAR_ARCHIVE })
    local cvAnimationSpeed = CreateConVar("ttt2_loadingscreen_anim_speed", "1", { FCVAR_ARCHIVE })
    
    -- LOGO相关配置
    local cvShowLogo = CreateConVar("ttt2_loadingscreen_show_logo", "1", { FCVAR_ARCHIVE })
    local cvLogoPath = CreateConVar("ttt2_loadingscreen_logo_path", "materials/ttt2/logo.png", { FCVAR_ARCHIVE })
    local cvLogoSize = CreateConVar("ttt2_loadingscreen_logo_size", "200", { FCVAR_ARCHIVE })
    local cvLogoGlow = CreateConVar("ttt2_loadingscreen_logo_glow", "1", { FCVAR_ARCHIVE })

    ---
    -- 获取粒子数量
    function LoadingScreenVisual.GetParticleCount()
        return math.Clamp(cvParticleCount:GetInt(), 0, 50)
    end

    ---
    -- 是否显示几何装饰
    function LoadingScreenVisual.ShouldShowGeometry()
        return cvShowGeometry:GetBool()
    end

    ---
    -- 获取模糊强度
    function LoadingScreenVisual.GetBlurIntensity()
        return math.Clamp(cvBlurIntensity:GetFloat(), 0, 30)
    end

    ---
    -- 获取动画速度倍数
    function LoadingScreenVisual.GetAnimationSpeed()
        return math.Clamp(cvAnimationSpeed:GetFloat(), 0.1, 3.0)
    end

    ---
    -- 是否显示LOGO
    function LoadingScreenVisual.ShouldShowLogo()
        return cvShowLogo:GetBool()
    end

    ---
    -- 获取LOGO路径
    function LoadingScreenVisual.GetLogoPath()
        return cvLogoPath:GetString()
    end

    ---
    -- 获取LOGO尺寸
    function LoadingScreenVisual.GetLogoSize()
        return math.Clamp(cvLogoSize:GetInt(), 50, 500)
    end

    ---
    -- 是否显示LOGO光晕效果
    function LoadingScreenVisual.ShouldShowLogoGlow()
        return cvLogoGlow:GetBool()
    end

    ---
    -- 创建视觉设置面板
    function LoadingScreenVisual.CreateSettingsPanel()
        local frame = vgui.Create("DFrame")
        frame:SetSize(550, 500)
        frame:SetTitle("加载屏幕视觉效果设置")
        frame:Center()
        frame:MakePopup()

        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        scroll:DockMargin(10, 10, 10, 10)

        -- 粒子数量滑块
        local particleLabel = vgui.Create("DLabel", scroll)
        particleLabel:SetText("粒子数量: " .. cvParticleCount:GetInt())
        particleLabel:Dock(TOP)
        particleLabel:DockMargin(0, 5, 0, 5)

        local particleSlider = vgui.Create("DNumSlider", scroll)
        particleSlider:SetText("")
        particleSlider:SetMin(0)
        particleSlider:SetMax(50)
        particleSlider:SetDecimals(0)
        particleSlider:SetValue(cvParticleCount:GetInt())
        particleSlider:Dock(TOP)
        particleSlider:DockMargin(0, 0, 0, 10)
        particleSlider.OnValueChanged = function(self, value)
            particleLabel:SetText("粒子数量: " .. math.floor(value))
            RunConsoleCommand("ttt2_loadingscreen_particles", tostring(math.floor(value)))
        end

        -- 模糊强度滑块
        local blurLabel = vgui.Create("DLabel", scroll)
        blurLabel:SetText("模糊强度: " .. cvBlurIntensity:GetFloat())
        blurLabel:Dock(TOP)
        blurLabel:DockMargin(0, 5, 0, 5)

        local blurSlider = vgui.Create("DNumSlider", scroll)
        blurSlider:SetText("")
        blurSlider:SetMin(0)
        blurSlider:SetMax(30)
        blurSlider:SetDecimals(1)
        blurSlider:SetValue(cvBlurIntensity:GetFloat())
        blurSlider:Dock(TOP)
        blurSlider:DockMargin(0, 0, 0, 10)
        blurSlider.OnValueChanged = function(self, value)
            blurLabel:SetText("模糊强度: " .. math.Round(value, 1))
            RunConsoleCommand("ttt2_loadingscreen_blur", tostring(value))
        end

        -- 动画速度滑块
        local speedLabel = vgui.Create("DLabel", scroll)
        speedLabel:SetText("动画速度: " .. cvAnimationSpeed:GetFloat() .. "x")
        speedLabel:Dock(TOP)
        speedLabel:DockMargin(0, 5, 0, 5)

        local speedSlider = vgui.Create("DNumSlider", scroll)
        speedSlider:SetText("")
        speedSlider:SetMin(0.1)
        speedSlider:SetMax(3.0)
        speedSlider:SetDecimals(1)
        speedSlider:SetValue(cvAnimationSpeed:GetFloat())
        speedSlider:Dock(TOP)
        speedSlider:DockMargin(0, 0, 0, 10)
        speedSlider.OnValueChanged = function(self, value)
            speedLabel:SetText("动画速度: " .. math.Round(value, 1) .. "x")
            RunConsoleCommand("ttt2_loadingscreen_anim_speed", tostring(value))
        end

        -- 几何装饰开关
        local geometryCheck = vgui.Create("DCheckBoxLabel", scroll)
        geometryCheck:SetText("显示几何装饰效果")
        geometryCheck:SetValue(cvShowGeometry:GetBool())
        geometryCheck:Dock(TOP)
        geometryCheck:DockMargin(0, 5, 0, 10)
        geometryCheck.OnChange = function(self, value)
            RunConsoleCommand("ttt2_loadingscreen_geometry", value and "1" or "0")
        end

        -- LOGO显示开关
        local logoCheck = vgui.Create("DCheckBoxLabel", scroll)
        logoCheck:SetText("显示LOGO")
        logoCheck:SetValue(cvShowLogo:GetBool())
        logoCheck:Dock(TOP)
        logoCheck:DockMargin(0, 5, 0, 10)
        logoCheck.OnChange = function(self, value)
            RunConsoleCommand("ttt2_loadingscreen_show_logo", value and "1" or "0")
        end

        -- LOGO路径设置
        local logoPathLabel = vgui.Create("DLabel", scroll)
        logoPathLabel:SetText("LOGO路径:")
        logoPathLabel:Dock(TOP)
        logoPathLabel:DockMargin(0, 10, 0, 5)

        local logoPathEntry = vgui.Create("DTextEntry", scroll)
        logoPathEntry:SetValue(cvLogoPath:GetString())
        logoPathEntry:Dock(TOP)
        logoPathEntry:DockMargin(0, 0, 0, 10)
        logoPathEntry.OnEnter = function(self)
            RunConsoleCommand("ttt2_loadingscreen_logo_path", self:GetValue())
        end

        -- LOGO尺寸滑块
        local logoSizeLabel = vgui.Create("DLabel", scroll)
        logoSizeLabel:SetText("LOGO尺寸: " .. cvLogoSize:GetInt())
        logoSizeLabel:Dock(TOP)
        logoSizeLabel:DockMargin(0, 5, 0, 5)

        local logoSizeSlider = vgui.Create("DNumSlider", scroll)
        logoSizeSlider:SetText("")
        logoSizeSlider:SetMin(50)
        logoSizeSlider:SetMax(500)
        logoSizeSlider:SetDecimals(0)
        logoSizeSlider:SetValue(cvLogoSize:GetInt())
        logoSizeSlider:Dock(TOP)
        logoSizeSlider:DockMargin(0, 0, 0, 10)
        logoSizeSlider.OnValueChanged = function(self, value)
            logoSizeLabel:SetText("LOGO尺寸: " .. math.floor(value))
            RunConsoleCommand("ttt2_loadingscreen_logo_size", tostring(math.floor(value)))
        end

        -- LOGO光晕开关
        local logoGlowCheck = vgui.Create("DCheckBoxLabel", scroll)
        logoGlowCheck:SetText("LOGO光晕效果")
        logoGlowCheck:SetValue(cvLogoGlow:GetBool())
        logoGlowCheck:Dock(TOP)
        logoGlowCheck:DockMargin(0, 5, 0, 10)
        logoGlowCheck.OnChange = function(self, value)
            RunConsoleCommand("ttt2_loadingscreen_logo_glow", value and "1" or "0")
        end

        -- 预设按钮
        local presetLabel = vgui.Create("DLabel", scroll)
        presetLabel:SetText("快速预设:")
        presetLabel:Dock(TOP)
        presetLabel:DockMargin(0, 15, 0, 5)

        local buttonPanel = vgui.Create("DPanel", scroll)
        buttonPanel:SetTall(30)
        buttonPanel:Dock(TOP)
        buttonPanel:DockMargin(0, 0, 0, 10)
        buttonPanel.Paint = function() end

        local lowBtn = vgui.Create("DButton", buttonPanel)
        lowBtn:SetText("低配置")
        lowBtn:SetSize(80, 25)
        lowBtn:SetPos(0, 0)
        lowBtn.DoClick = function()
            RunConsoleCommand("ttt2_loadingscreen_particles", "5")
            RunConsoleCommand("ttt2_loadingscreen_blur", "5")
            RunConsoleCommand("ttt2_loadingscreen_geometry", "0")
            RunConsoleCommand("ttt2_loadingscreen_anim_speed", "0.5")
        end

        local medBtn = vgui.Create("DButton", buttonPanel)
        medBtn:SetText("标准配置")
        medBtn:SetSize(80, 25)
        medBtn:SetPos(90, 0)
        medBtn.DoClick = function()
            RunConsoleCommand("ttt2_loadingscreen_particles", "20")
            RunConsoleCommand("ttt2_loadingscreen_blur", "15")
            RunConsoleCommand("ttt2_loadingscreen_geometry", "1")
            RunConsoleCommand("ttt2_loadingscreen_anim_speed", "1")
        end

        local highBtn = vgui.Create("DButton", buttonPanel)
        highBtn:SetText("高配置")
        highBtn:SetSize(80, 25)
        highBtn:SetPos(180, 0)
        highBtn.DoClick = function()
            RunConsoleCommand("ttt2_loadingscreen_particles", "40")
            RunConsoleCommand("ttt2_loadingscreen_blur", "25")
            RunConsoleCommand("ttt2_loadingscreen_geometry", "1")
            RunConsoleCommand("ttt2_loadingscreen_anim_speed", "2")
        end

        return frame
    end

    -- 控制台命令
    concommand.Add("ttt2_loadingscreen_visual_settings", function()
        LoadingScreenVisual.CreateSettingsPanel()
    end)
end 