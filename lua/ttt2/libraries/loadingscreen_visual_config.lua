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
    local cvBlurIntensity = CreateConVar("ttt2_loadingscreen_blur", "15", { FCVAR_ARCHIVE })

    ---
    -- 获取模糊强度
    function LoadingScreenVisual.GetBlurIntensity()
        return math.Clamp(cvBlurIntensity:GetFloat(), 0, 30)
    end
end 