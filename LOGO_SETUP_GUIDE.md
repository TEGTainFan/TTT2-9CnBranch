# TTT2 加载屏幕 LOGO 设置指南

## 概述

TTT2 加载屏幕现在支持在中央显示自定义 LOGO，为服务器添加品牌标识。

## 快速设置

### 方法1: 使用设置面板（推荐）

1. 在游戏中打开控制台（默认 `~` 键）
2. 输入 `ttt2_loadingscreen_visual_settings`
3. 在设置面板中配置 LOGO 相关选项

### 方法2: 使用控制台命令

```bash
# 启用LOGO显示
ttt2_loadingscreen_show_logo 1

# 设置LOGO路径
ttt2_loadingscreen_logo_path "materials/your_logo.png"

# 设置LOGO尺寸
ttt2_loadingscreen_logo_size 250

# 启用LOGO光晕效果
ttt2_loadingscreen_logo_glow 1
```

## LOGO 文件准备

### 支持的格式
- **PNG** (推荐) - 支持透明背景
- **JPG** - 不支持透明背景
- **VTF** - Valve 纹理格式

### 推荐规格
- **分辨率**: 512x512 或 1024x1024
- **宽高比**: 推荐 16:10 或 1:1
- **文件大小**: 建议小于 2MB
- **背景**: 使用透明背景（PNG格式）

### 文件位置
将 LOGO 文件放置在 `garrysmod/materials/` 目录下

**示例文件结构**:
```
garrysmod/
├── materials/
│   ├── ttt2/
│   │   ├── logo.png          ← 默认LOGO路径
│   │   └── server_logo.png
│   └── myserver/
│       ├── brand_logo.png
│       └── event_logo.png
```

## 配置选项详解

### LOGO 显示开关
```bash
ttt2_loadingscreen_show_logo 1    # 显示LOGO
ttt2_loadingscreen_show_logo 0    # 隐藏LOGO
```

### LOGO 路径设置
```bash
# 路径格式: materials/文件夹/文件名.扩展名
ttt2_loadingscreen_logo_path "materials/tttr/logo24.png"
ttt2_loadingscreen_logo_path "materials/myserver/custom_logo.png"
```

### LOGO 尺寸调整
```bash
# 尺寸范围: 50-500 像素
ttt2_loadingscreen_logo_size 200    # 标准尺寸
ttt2_loadingscreen_logo_size 300    # 大尺寸
ttt2_loadingscreen_logo_size 150    # 小尺寸
```

### LOGO 光晕效果
```bash
ttt2_loadingscreen_logo_glow 1     # 启用光晕
ttt2_loadingscreen_logo_glow 0     # 禁用光晕
```

## 视觉效果特性

### 动画效果
- **淡入效果**: LOGO 比其他元素更快出现
- **呼吸动画**: 轻微的缩放效果，增加生动感
- **摆动效果**: 微小的旋转摆动
- **光晕脉冲**: 可选的光晕效果，呈脉冲状变化

### 自适应布局
- **智能定位**: LOGO 自动居中显示
- **文字避让**: 标题和文本自动调整位置避免重叠
- **阴影效果**: 为 LOGO 添加阴影，增强立体感

## 服务器部署

### 单个服务器设置
```lua
-- 在服务器的 autorun 文件中添加
if CLIENT then
    hook.Add("Initialize", "SetServerLogo", function()
        timer.Simple(1, function()
            RunConsoleCommand("ttt2_loadingscreen_logo_path", "materials/myserver/logo.png")
            RunConsoleCommand("ttt2_loadingscreen_logo_size", "250")
        end)
    end)
end
```

### 插件开发者配置
```lua
-- 在插件的客户端初始化文件中
if CLIENT then
    -- 设置插件专用 LOGO
    hook.Add("TTT2Initialize", "MyAddonLogo", function()
        if GetConVar("ttt2_loadingscreen_logo_path"):GetString() == "materials/ttt2/logo.png" then
            RunConsoleCommand("ttt2_loadingscreen_logo_path", "materials/myaddon/logo.png")
        end
    end)
end
```

### 资源文件分发
在插件或服务器配置中添加：
```lua
-- resource.lua 文件
resource.AddFile("materials/myserver/logo.png")

-- 或在服务器脚本中
game.AddParticles("materials/myserver/logo.png")
```

## 常见问题解决

### LOGO 不显示
1. **检查文件路径** - 确保路径正确且文件存在
2. **检查文件格式** - 确保使用支持的图像格式
3. **检查显示开关** - 确保 `ttt2_loadingscreen_show_logo` 设为 1
4. **重新启动** - 尝试重启游戏或重新连接服务器

### LOGO 显示异常
1. **尺寸过大** - 降低 LOGO 尺寸设置
2. **文件损坏** - 重新保存图片文件
3. **透明度问题** - 检查 PNG 文件的透明通道

### 性能问题
1. **优化文件大小** - 压缩图片文件
2. **降低分辨率** - 使用较小的图片分辨率
3. **关闭光晕效果** - 设置 `ttt2_loadingscreen_logo_glow 0`

## 最佳实践

### 设计建议
1. **简洁设计** - 避免过于复杂的图案
2. **高对比度** - 确保在各种背景下都清晰可见
3. **品牌一致性** - 与服务器整体风格保持一致
4. **适当尺寸** - 不要过大影响其他界面元素

### 技术建议
1. **预加载测试** - 在不同分辨率下测试显示效果
2. **版本管理** - 为不同活动准备不同版本的 LOGO
3. **备用方案** - 准备无 LOGO 的备用配置
4. **定期更新** - 根据服务器活动更新 LOGO

## 控制台命令汇总

```bash
# LOGO 相关命令
ttt2_loadingscreen_show_logo "1"
ttt2_loadingscreen_logo_path "materials/ttt2/logo.png"
ttt2_loadingscreen_logo_size "200"
ttt2_loadingscreen_logo_glow "1"

# 打开设置面板
ttt2_loadingscreen_visual_settings

# 其他视觉效果命令
ttt2_loadingscreen_particles "20"
ttt2_loadingscreen_blur "15"
ttt2_loadingscreen_geometry "1"
ttt2_loadingscreen_anim_speed "1"
```

## 技术支持

如果在设置 LOGO 时遇到问题，请检查：
1. 控制台是否有错误信息
2. 文件路径和权限
3. 图片文件的完整性
4. 服务器的资源下载设置