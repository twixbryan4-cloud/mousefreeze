-- Huss Valley Panel 0.6.4
-- Interface inspirada no video de referencia. Nenhuma categoria/catalogo de facas.
-- Sem bibliotecas externas. Recursos especificos do jogo usam adaptadores explicitos.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Input = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Http = game:GetService("HttpService")
local Teleport = game:GetService("TeleportService")
local Replicated = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
if not player then error("Execute no cliente depois de entrar no jogo.") end
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.HussValleyPanel and type(env.HussValleyPanel.Destroy) == "function" then
    pcall(env.HussValleyPanel.Destroy)
end

local defaults = {
    movement=false, speedBoost=false, walkSpeed=24, fly=false, flySpeed=50,
    noclip=false, tpWalk=false, tpSpeed=16, infiniteJump=false, spin=false, spinSpeed=120,
    autoJumpButton=false, freezeButton=false, autoJumpInterval=0.15, freezeDuration=0.12, freezeCooldown=1,
    firstPerson=false, unlockMouse=false, fov=70, customFov=false, fullbright=false, xray=false,
    lockOn=false, radius=30, prediction=0.12, aimSmooth=12, faceTarget=false, teamCheck=false,
    autoAttack=false, attackRange=12, attackDelay=0.4, autoGears=false, gearDelay=1,
    autoRevive=false, autoPick=false, promptDelay=0.6,
    autoDash=false, autoZone=false, autoDown=false, autoTackle=false, dashCooldown=false,
    autoAbility=false, dashSide="Right",dashRange=15,dashDelay=1,dashKey="Q",dashKeyboardFallback=false,tackleRange=6,abilityRange=18,runnerAI=false, catcherAI=false, autoWheel=false, autoJourney=false,
    autoVote=false, disableGameAFK=false, antiIdle=false, antiHit=false,
    esp=false, boxes=true, names=true, tracers=false, health=true, distance=true,
    skeleton=false, headDot=false, healthText=false, roleColors=true, teamFilter=false, espTeams=false,
    espRange=1500, espRate=15, smoothESP=true, chams=false, viewTracer=false, nameHider=false, headless=false, -- smoothESP is accepted for old configs; geometry follows every frame.
    hitbox=false, leaderboard=false, gems=false,
    fpsBoost=false, removeTextures=true, removeDecals=true, removeParticles=true,
    lowDetail=true, noShadows=true, noFog=true, removeAccessories=false,
    unlockFPS=false, fpsCap=120, lowQuality=false,
    shaders=false, shaderFloors=true, shaderWalls=true, shaderPolish=false, shaderShadows=true,
    shaderReflection=0.28, shaderWallReflection=0.14, shaderContrast=0.14, shaderSaturation=-0.06,
    shaderExposure=0.05, shaderBloom=0.12, shaderTemperature=0,
    uiScale=1, opacity=0.94, transparency=6, theme="Dark", accent="Peach", rainbow=false,
    sounds=false, notifications=true, floating=true, toggleKey="RightShift", autoLoad=false,
}
local cfg = {}
for key,value in pairs(defaults) do cfg[key]=value end
local connections, watchers, actions, pages, navs, accentRefreshers = {}, {}, {}, {}, {}, {}
local optionLabels,menuSurfaces,uiDirty={},{},false
local state = {alive=true, booting=true, visible=true, page="Combat", up=false, down=false, pending={}, frames=0, time=0}
local adapters = env.HussValleyAdapters or {}
local API = {Version="0.6.4", Config=cfg, Adapters=adapters,NativeStatusLabels={}}
env.HussValleyPanel = API
local function listen(signal, fn)
    local c=signal:Connect(fn); connections[#connections+1]=c; return c
end
-- Every slider and drag handle shares one global pointer dispatcher.
local pointerSessions={}
local function beginPointer(input,onMove,onEnd)
    pointerSessions[input]={move=onMove,finish=onEnd}
    onMove(input)
end
listen(Input.InputChanged,function(input)
    local session=pointerSessions[input]
    if session then session.move(input)
    elseif input.UserInputType==Enum.UserInputType.MouseMovement then
        for pointer,s in pairs(pointerSessions) do
            if pointer.UserInputType==Enum.UserInputType.MouseButton1 then s.move(input) end
        end
    end
end)
listen(Input.InputEnded,function(input)
    local session=pointerSessions[input];pointerSessions[input]=nil
    if session and session.finish then session.finish(input) end
end)
listen(Input.WindowFocusReleased,function()
    for input,session in pairs(pointerSessions) do
        pointerSessions[input]=nil
        if session.finish then session.finish(input) end
    end
end)
local function create(class,props,parent)
    local object=Instance.new(class)
    for key,value in pairs(props or {}) do object[key]=value end
    object.Parent=parent
    return object
end
local function round(object,amount) create("UICorner",{CornerRadius=UDim.new(0,amount or 7)},object) end
local function tween(object,props,duration)
    local t=Tween:Create(object,TweenInfo.new(duration or 0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
    t:Play(); return t
end
local palette = {Peach=Color3.fromRGB(244,157,143),Purple=Color3.fromRGB(168,135,246),
    Blue=Color3.fromRGB(106,168,255),Pink=Color3.fromRGB(241,126,190),Green=Color3.fromRGB(110,212,172)}
local accent = palette.Peach
local colors={bg=Color3.fromRGB(16,14,23),card=Color3.fromRGB(27,23,36),text=Color3.fromRGB(235,232,240),muted=Color3.fromRGB(147,140,158)}
local themes, accentItems = {}, {}
local function pageOf(object)
    local p=object.Parent
    while p do
        local entry=pages[p.Name]
        if entry and entry.root==p then return p end
        p=p.Parent
    end
end
local function surface(object,base)
    menuSurfaces[#menuSurfaces+1]={object=object,base=base,page=pageOf(object)}
end
local function applyAppearance()
    local alpha=cfg.transparency/100
    for _,entry in ipairs(menuSurfaces) do
        if entry.object.Parent and (not entry.page or entry.page.Visible) then
            entry.object.BackgroundTransparency=entry.base+(1-entry.base)*alpha
        end
    end
    uiDirty=false
end
local function themed(object,property,role)
    themes[#themes+1]={object,property,role}; object[property]=colors[role]; return object
end
local function accented(object,property)
    accentItems[#accentItems+1]={object,property,pageOf(object)}; object[property]=accent; return object
end
local function text(parent,value,size,props,untracked)
    local p={Text=value,TextSize=size or 12,Font=Enum.Font.GothamMedium,TextColor3=colors.text,
        BackgroundTransparency=1,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,0,0,20)}
    for k,v in pairs(props or {}) do p[k]=v end
    local label=create("TextLabel",p,parent)
    if untracked then return label end
    themed(label,"TextColor3","text")
    local page=pageOf(label);if page then pages[page.Name].texts[#pages[page.Name].texts+1]=label end
    return label
end
local function button(parent,value,size,props)
    local p={Text=value,TextSize=size or 12,Font=Enum.Font.GothamMedium,TextColor3=colors.text,
        BackgroundColor3=colors.card,BorderSizePixel=0,AutoButtonColor=false,Size=UDim2.new(1,0,0,28)}
    for k,v in pairs(props or {}) do p[k]=v end
    local b=create("TextButton",p,parent); round(b,5); themed(b,"TextColor3","text"); themed(b,"BackgroundColor3","card")
    local page=pageOf(b);if page then pages[page.Name].texts[#pages[page.Name].texts+1]=b end
    local ancestor=parent
    while ancestor do
        if ancestor.Name=="Window" then if (p.BackgroundTransparency or 0)<1 then surface(b,p.BackgroundTransparency or 0) end;break end
        ancestor=ancestor.Parent
    end
    return b
end

local gui=create("ScreenGui",{Name="HussValleyPanel",ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=2147483000})
local parented=false
if type(gethui)=="function" then parented=pcall(function() gui.Parent=gethui() end) end
if not parented then parented=pcall(function() gui.Parent=game:GetService("CoreGui") end) end
if not parented then gui.Parent=player:WaitForChild("PlayerGui",10) end
if not gui.Parent then gui:Destroy(); error("Nao foi possivel abrir a interface.") end
-- Temporary cinematic loading screen: native GUI, no downloaded artwork or libraries.
local boot,bootProgress
do
    local loading={active=true,tweens={},started=os.clock(),target=0}
    API.Loading=loading
    local blue=Color3.fromRGB(112,170,255)
    local coral=Color3.fromRGB(247,166,152)
    local lavender=Color3.fromRGB(170,145,251)
    boot=create("Frame",{Name="Welcome",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(8,10,20),
        BorderSizePixel=0,Active=true,ZIndex=70},gui)
    create("UIGradient",{Rotation=32,Color=ColorSequence.new(Color3.fromRGB(15,20,42),Color3.fromRGB(8,8,15))},boot)
    local content=create("CanvasGroup",{Name="LoadingCard",AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.48),Size=UDim2.fromOffset(560,310),
        BackgroundTransparency=1,GroupTransparency=1,ZIndex=72},boot)
    local sizing=create("UIScale",{Scale=1},content)
    function loading.Fit(size)
        if loading.active then sizing.Scale=math.max(0.2,math.min(1,(size.X-30)/560,(size.Y-34)/330)) end
    end
    loading.Fit(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720))
    local function animate(object,props,duration,repeatCount)
        local t=Tween:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,repeatCount or 0),props)
        loading.tweens[#loading.tweens+1]=t;t:Play();return t
    end
    local function label(value,size,x,y,w,h,color,font)
        return create("TextLabel",{Text=value,TextSize=size,Font=font or Enum.Font.GothamMedium,
            TextColor3=color or Color3.fromRGB(239,241,255),BackgroundTransparency=1,
            Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            TextXAlignment=Enum.TextXAlignment.Center,ZIndex=74},content)
    end
    for i=1,28 do
        local dot=create("Frame",{Position=UDim2.fromScale(((i*37)%97)/100,((i*53)%89)/100),
            Size=UDim2.fromOffset(i%4==0 and 3 or 2,i%4==0 and 3 or 2),
            BackgroundColor3=i%2==0 and blue or coral,BackgroundTransparency=0.65+(i%3)*0.08,
            BorderSizePixel=0,ZIndex=71},boot);round(dot,9)
    end
    for i=1,3 do
        local orbit=create("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.48),
            Size=UDim2.fromScale(0.48+i*0.12,0.48+i*0.12),BackgroundTransparency=1,
            Rotation=i*23,ZIndex=71},boot)
        round(orbit,999)
        create("UIStroke",{Color=i%2==0 and blue or lavender,Transparency=0.93,Thickness=1},orbit)
    end
    local emblem=create("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromOffset(280,10),
        Size=UDim2.fromOffset(52,52),BackgroundColor3=Color3.fromRGB(23,28,49),BorderSizePixel=0,Rotation=45,ZIndex=73},content)
    round(emblem,13);create("UIStroke",{Color=blue,Transparency=0.25,Thickness=1},emblem)
    create("UIGradient",{Rotation=45,Color=ColorSequence.new(blue,lavender)},emblem)
    local monogram=create("TextLabel",{Text="HV",Font=Enum.Font.GothamBold,TextSize=19,
        TextColor3=Color3.fromRGB(242,246,255),Rotation=-45,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=74},emblem)
    label("HUSS VALLEY",37,25,83,510,45,nil,Enum.Font.GothamBold)
    label("P R E P A R A N D O   S E U   P A I N E L",10,25,135,510,20,Color3.fromRGB(148,158,188))
    local track=create("Frame",{Name="LoadingTrack",Position=UDim2.fromOffset(40,185),Size=UDim2.fromOffset(480,10),
        BackgroundColor3=Color3.fromRGB(30,35,54),BorderSizePixel=0,ClipsDescendants=true,ZIndex=73},content);round(track,99)
    local fill=create("Frame",{Name="LoadingFill",Size=UDim2.fromScale(0,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=74},track);round(fill,99)
    create("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,blue),ColorSequenceKeypoint.new(0.55,lavender),ColorSequenceKeypoint.new(1,coral)})},fill)
    local shine=create("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=75},fill)
    local shineGradient=create("UIGradient",{Offset=Vector2.new(-1,0),Rotation=20,
        Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.45,1),
            NumberSequenceKeypoint.new(0.5,0.65),NumberSequenceKeypoint.new(0.55,1),NumberSequenceKeypoint.new(1,1)})},shine)
    animate(shineGradient,{Offset=Vector2.new(1,0)},1.65,-1)
    local status=label("Construindo a interface...",11,40,205,415,22,Color3.fromRGB(168,177,202))
    status.TextXAlignment=Enum.TextXAlignment.Left
    local percent=label("0%",11,455,205,65,22,blue,Enum.Font.GothamBold)
    percent.TextXAlignment=Enum.TextXAlignment.Right
    local avatar=create("ImageLabel",{Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=100&h=100",
        Position=UDim2.fromOffset(178,257),Size=UDim2.fromOffset(27,27),BackgroundColor3=Color3.fromRGB(28,32,51),BorderSizePixel=0,ZIndex=74},content);round(avatar,99)
    local welcome=label("Bem-vindo, "..player.DisplayName,11,213,258,300,25,Color3.fromRGB(196,202,221))
    welcome.TextXAlignment=Enum.TextXAlignment.Left
    label("v"..API.Version,9,40,289,480,15,Color3.fromRGB(99,111,143))
    local amount=create("NumberValue",{Value=0},boot)
    local changed=amount.Changed:Connect(function(value)
        if not loading.active then return end
        fill.Size=UDim2.fromScale(math.clamp(value,0,1),1)
        percent.Text=string.format("%d%%",math.floor(value*100+0.5))
    end)
    local progressTween
    bootProgress=function(value,message)
        if not loading.active then return end
        loading.target=math.max(loading.target,math.clamp(value,0,1))
        if progressTween then progressTween:Cancel() end
        progressTween=animate(amount,{Value=loading.target},0.32)
        status.Text=message
    end
    function loading.Stop()
        if not loading.active then return end
        loading.active=false;changed:Disconnect()
        for _,t in ipairs(loading.tweens) do t:Cancel() end
        loading.tweens={};boot:Destroy()
    end
    function loading.Finish(callback)
        bootProgress(1,"Tudo pronto. Vamos comecar.")
        task.delay(math.max(0.38,1.35-(os.clock()-loading.started)),function()
            if not loading.active or not state.alive then return end
            amount.Value=1
            animate(content,{GroupTransparency=1},0.3)
            animate(boot,{BackgroundTransparency=1},0.3)
            for _,object in ipairs(boot:GetDescendants()) do
                if object:IsA("UIStroke") then animate(object,{Transparency=1},0.28)
                elseif object:IsA("Frame") and not object:IsDescendantOf(content) then animate(object,{BackgroundTransparency=1},0.28) end
            end
            task.delay(0.32,function()
                if not loading.active or not state.alive then return end
                loading.Stop();state.booting=false;callback()
            end)
        end)
    end
    animate(content,{GroupTransparency=0},0.35)
    bootProgress(0.06,"Iniciando seu painel...")
end
local visuals=create("Folder",{Name="HussValleyLocalVisuals"},workspace)
local overlay=create("Frame",{Name="ESP",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
local toast=text(gui,"",11,{Name="Notice",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-14,1,-18),
    Size=UDim2.fromOffset(300,58),BackgroundColor3=colors.card,BackgroundTransparency=0.05,
    TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Visible=false,ZIndex=50})
round(toast,7)
create("UISizeConstraint",{MaxSize=Vector2.new(300,58),MinSize=Vector2.new(120,58)},toast)
create("UIPadding",{PaddingLeft=UDim.new(0,15),PaddingRight=UDim.new(0,12)},toast)
local toastLine=accented(create("Frame",{Size=UDim2.new(0,3,1,-14),Position=UDim2.fromOffset(0,7),BorderSizePixel=0},toast),"BackgroundColor3")
local toastProgress=accented(create("Frame",{Name="Progress",Position=UDim2.new(0,10,1,-3),Size=UDim2.new(1,-20,0,2),BorderSizePixel=0},toast),"BackgroundColor3")
local toastID=0
local function notify(message,kind)
    if not state.alive then return end
    toastID=toastID+1; local id=toastID
    local wasVisible=toast.Visible
    toast.Text=message; toast.Visible=true;toastLine.BackgroundColor3=kind=="off" and colors.muted or accent
    if not wasVisible then toast.Position=UDim2.new(1,310,1,-18) end
    tween(toast,{Position=UDim2.new(1,-14,1,-18)},0.16)
    toastProgress.Size=UDim2.new(1,-20,0,2);tween(toastProgress,{Size=UDim2.new(0,0,0,2)},2.7)
    task.delay(2.7,function() if state.alive and id==toastID then
        tween(toast,{Position=UDim2.new(1,310,1,-18)},0.14)
        task.delay(0.15,function() if state.alive and id==toastID then toast.Visible=false end end)
    end end)
end
API.Notify=notify
local tooltip=text(gui,"",10,{Name="Tooltip",Size=UDim2.fromOffset(235,80),BackgroundColor3=colors.card,
    BackgroundTransparency=0.05,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,Visible=false,ZIndex=45})
round(tooltip,6)
create("UIPadding",{PaddingTop=UDim.new(0,9),PaddingBottom=UDim.new(0,9),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},tooltip)
accented(create("UIStroke",{Thickness=0.8,Transparency=0.4},tooltip),"Color")

-- Every modified property keeps its original value. Groups do not overlap.
local originals={}
local function patch(group,object,property,value)
    if not object then return end
    local g=originals[group]
    if not g then g=setmetatable({},{__mode="k"}); originals[group]=g end
    local record=g[object]
    if not record then record={}; g[object]=record end
    local ok=pcall(function()
        if record[property]==nil then record[property]={object[property]} end
        object[property]=value
    end)
    return ok
end
local function restore(group)
    local g=originals[group]; if not g then return end
    for object,record in pairs(g) do
        for property,old in pairs(record) do pcall(function() object[property]=old[1] end) end
    end
    originals[group]=nil
end
local actorCache=setmetatable({},{__mode="k"})
local function actor(p)
    local char=p.Character;local a=actorCache[p]
    if not a or a.char~=char then a={char=char};actorCache[p]=a end
    if char then
        if not a.hum or not a.hum.Parent then a.hum=char:FindFirstChildOfClass("Humanoid") end
        if not a.root or not a.root.Parent then a.root=char:FindFirstChild("HumanoidRootPart") end
    end
    return a
end
local function character()
    local a=actor(player);return a.char,a.hum,a.root
end
local function watch(key,fn)
    watchers[key]=watchers[key] or {}; table.insert(watchers[key],fn); fn(cfg[key])
end
local set,refreshTheme,refreshAccent,fit,updateFlight,refreshPerformance,refreshPreview
local requiresAdapter={autoDash="AutoDash",autoZone="AutoZone",autoDown="AutoDown",autoTackle="AutoTackle",
    dashCooldown="DashCooldown",autoAbility="AutoAbility",runnerAI="RunnerAI",catcherAI="CatcherAI",
    autoWheel="AutoSpinWheel",autoJourney="AutoClaimJourney",autoVote="AutoMapVote",disableGameAFK="DisableGameAFK",
    hitbox="HitBox",leaderboard="LeaderboardVisuals",gems="GemsAndCoins",antiHit="AntiHit"}
local ranges={walkSpeed={8,150},flySpeed={5,150},tpSpeed={1,80},spinSpeed={10,360},fov={40,120},radius={5,150},
    prediction={0,0.5},aimSmooth={1,25},attackRange={2,50},attackDelay={0.15,3},gearDelay={0.2,10},
    promptDelay={0.25,3},dashRange={2,100},dashDelay={0.25,10},tackleRange={2,12},abilityRange={2,40},espRange={50,3000},espRate={2,30},fpsCap={30,240},
    shaderReflection={0,0.65},shaderWallReflection={0,0.65},shaderContrast={0,0.4},shaderSaturation={-0.4,0.4},
    shaderExposure={-1,1},shaderBloom={0,0.6},shaderTemperature={-1,1},uiScale={0.45,1.6},opacity={0.15,1},transparency={0,85},
    autoJumpInterval={0.1,1},freezeDuration={0.05,3},freezeCooldown={0.5,5}}
local function valid(key,value)
    if defaults[key]==nil or type(value)~=type(defaults[key]) then return false end
    if type(value)=="number" then
        if value~=value or math.abs(value)==math.huge then return false end
        local r=ranges[key]; if r then value=math.clamp(value,r[1],r[2]) end
    elseif key=="theme" and value~="Dark" and value~="Black" then return false
    elseif key=="accent" and not palette[value] then return false
    elseif key=="dashSide" and value~="Right" and value~="Left" then return false
    elseif key=="dashKey" and value~="Q" and value~="E" and value~="F" and value~="LeftShift" and value~="LeftControl" and value~="Space" then return false
    elseif key=="toggleKey" then
        local ok,k=pcall(function() return Enum.KeyCode[value] end)
        if not ok or not k or k==Enum.KeyCode.Unknown then return false end
    end
    return true,value
end
set=function(key,value,quiet)
    local ok,newValue=valid(key,value); if not ok then return false end
    if newValue==true and requiresAdapter[key] and type(adapters[requiresAdapter[key]])~="function" then
        if not quiet then notify(key=="antiHit" and "Anti-Hit ainda nao validado: falta confirmar como o servidor aplica os hits." or "Essa funcao ainda precisa de integracao com o Huss Valley.") end
        return false
    end
    if key=="unlockFPS" and newValue and type(setfpscap)~="function" then notify("Esta versao do executor nao fornece setfpscap."); return false end
    if cfg[key]==newValue then return true end
    cfg[key]=newValue
    for _,fn in ipairs(watchers[key] or {}) do fn(newValue) end
    if actions[key] then
        local success,err=pcall(actions[key],newValue)
        if not success then
            cfg[key]=defaults[key]
            for _,fn in ipairs(watchers[key] or {}) do fn(cfg[key]) end
            pcall(actions[key],cfg[key]); notify("Nao foi possivel aplicar: "..key); warn("[HV] "..tostring(err)); return false
        end
    end
    if not quiet then
        if type(newValue)=="boolean" and (cfg.notifications or key=="notifications") then
            notify((optionLabels[key] or key)..(newValue and " ativado" or " desativado"),newValue and "on" or "off")
        end
        if type(newValue)=="boolean" and cfg.sounds and API.PlaySound then API.PlaySound() end
    end
    return true
end
API.Set=set
function API.RegisterAction(name,callback)
    assert(type(name)=="string" and type(callback)=="function","Adaptador invalido")
    adapters[name]=callback
end

-- A compact sidebar and two columns follow the reference; the layout fits the viewport.
local window=themed(create("Frame",{Name="Window",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.46),
    Size=UDim2.fromOffset(730,438),BackgroundTransparency=1-cfg.opacity,BorderSizePixel=0,ClipsDescendants=true,Visible=false},gui),"BackgroundColor3","bg")
round(window,11)
surface(window,0)
local scale=create("UIScale",{Scale=1},window)
local border=create("UIStroke",{Color=Color3.fromRGB(65,52,70),Thickness=1,Transparency=0.25},window)
create("UIGradient",{Rotation=32,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(180,167,205))},window)
local rail=themed(create("Frame",{Name="Sidebar",Size=UDim2.new(0,54,1,0),BorderSizePixel=0,BackgroundTransparency=0.3},window),"BackgroundColor3","card")
surface(rail,0.3)
local brand=button(rail,"HV",13,{Name="Brand",Size=UDim2.fromOffset(32,30),Position=UDim2.fromOffset(11,12),Font=Enum.Font.GothamBold})
accented(brand,"TextColor3")
local heading=text(window,"02 / COMBAT",10,{Name="PageTitle",Position=UDim2.fromOffset(70,13),Size=UDim2.new(1,-200,0,16),Font=Enum.Font.GothamBold})
themed(heading,"TextColor3","muted")
local minimize=button(window,"-",17,{Name="Minimize",Position=UDim2.new(1,-62,0,8),Size=UDim2.fromOffset(23,23),BackgroundTransparency=1})
local close=button(window,"x",12,{Name="Close",Position=UDim2.new(1,-34,0,8),Size=UDim2.fromOffset(23,23),BackgroundTransparency=1})
local quickButton=button(window,"UI",10,{Name="QuickUIButton",Position=UDim2.new(1,-94,0,8),Size=UDim2.fromOffset(25,23),BackgroundTransparency=1})
local dragbar=create("Frame",{Name="DragBar",Position=UDim2.fromOffset(60,0),Size=UDim2.new(1,-166,0,34),BackgroundTransparency=1,Active=true},window)
local body=create("Frame",{Name="Body",Position=UDim2.fromOffset(68,38),Size=UDim2.new(1,-82,1,-68),BackgroundTransparency=1},window)
local footer=text(window,"HUSS VALLEY  /  v"..API.Version,9,{Name="Footer",Position=UDim2.new(0,70,1,-23),Size=UDim2.new(1,-160,0,14)})
themed(footer,"TextColor3","muted")
local fpsLabel=text(window,"-- FPS",9,{Name="FPS",Position=UDim2.new(1,-90,1,-23),Size=UDim2.fromOffset(72,14),TextXAlignment=Enum.TextXAlignment.Right})
API.UI={FloatingHost=create("CanvasGroup",{Name="FloatingHost",Position=UDim2.new(0,9,0.36,-3),Size=UDim2.fromOffset(48,48),
    BackgroundTransparency=1,GroupTransparency=1,Visible=false,ZIndex=20},gui)}
local floating=button(API.UI.FloatingHost,"HV",13,{Name="FloatingButton",Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(42,42),ZIndex=20,Font=Enum.Font.GothamBold})
accented(floating,"TextColor3"); accented(create("UIStroke",{Thickness=1,Transparency=0.4},floating),"Color")
local flightPad=create("Frame",{Name="FlightControls",Position=UDim2.new(1,-66,0.5,-45),Size=UDim2.fromOffset(50,96),BackgroundTransparency=1,Visible=false},gui)
local flyUp=button(flightPad,"+",22,{Name="FlyUp",Size=UDim2.fromOffset(44,42)})
local flyDown=button(flightPad,"-",22,{Name="FlyDown",Position=UDim2.fromOffset(0,48),Size=UDim2.fromOffset(44,42)})
fit=function()
    local cam=workspace.CurrentCamera
    local size=cam and cam.ViewportSize or Vector2.new(1280,720)
    scale.Scale=math.max(0.25,math.min((size.X-24)/730,(size.Y-32)/438,1.1)*cfg.uiScale)
    -- Fit the size without changing either user-dragged position.
    scale.Scale=math.min(scale.Scale,(size.X-16)/730,(size.Y-24)/438)
    toast.Size=UDim2.fromOffset(math.min(300,math.max(120,size.X-28)),58)
    if API.Loading then API.Loading.Fit(size) end
end
local show
do
    local ui=API.UI
    local fadeTween,fadeConnection
    local floatingDrag={moved=false,suppressUntil=0}
    local function stopFade()
        if fadeConnection then fadeConnection:Disconnect();fadeConnection=nil end
        if fadeTween then fadeTween:Cancel();fadeTween=nil end
    end
    ui.Stop=stopFade
    function ui.UpdateFloating(immediate)
        stopFade()
        local wanted=not state.visible
        local host=ui.FloatingHost
        if immediate then host.GroupTransparency=wanted and 0 or 1;host.Visible=wanted;return end
        if wanted then host.Visible=true end
        if not host.Visible then host.GroupTransparency=1;return end
        fadeTween=Tween:Create(host,TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=wanted and 0 or 1})
        local activeTween=fadeTween
        fadeConnection=activeTween.Completed:Connect(function()
            if fadeTween~=activeTween then return end
            fadeConnection:Disconnect();fadeConnection=nil;fadeTween=nil
            if state.alive and host.Parent then host.Visible=not state.visible end
        end)
        activeTween:Play()
    end
    show=function(value)
        if not state.alive or state.booting then return end
        state.visible=value;window.Visible=value;tooltip.Visible=false
        ui.UpdateFloating()
        if value then if refreshAccent then refreshAccent() end;applyAppearance() end
    end
    local function draggable(handle,target,dragState)
        local activeInput
        listen(handle.InputBegan,function(input)
            if activeInput or (input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch) then return end
            activeInput=input
            local start,startPos=input.Position,target.Position
            if dragState then dragState.moved=false end
            beginPointer(input,function(current)
                local delta=current.Position-start
                if dragState and delta.X*delta.X+delta.Y*delta.Y>=25 then
                    dragState.moved=true;dragState.suppressUntil=os.clock()+0.2
                end
                target.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
            end,function()
                activeInput=nil
                if dragState and dragState.moved then dragState.suppressUntil=os.clock()+0.2 end
            end)
        end)
    end
    ui.Draggable=draggable
    draggable(dragbar,window)
    draggable(floating,ui.FloatingHost,floatingDrag)
    listen(floating.Activated,function()
        if not state.visible and not floatingDrag.moved and os.clock()>=floatingDrag.suppressUntil then show(true) end
    end)
    listen(brand.Activated,function() show(false) end)
    listen(minimize.Activated,function() show(false) end)
    listen(close.Activated,function() show(false) end)
end

-- Optional draggable action buttons. Their menu toggles control their existence on screen.
do
    local quick={buttons={},jumping=false,freezeQueued=false,readyAt=0,generation=0,clock=0,lastJump=-math.huge}
    API.QuickActions=quick
    local function make(key,title,y)
        local host=create("CanvasGroup",{Name=key.."Host",Position=UDim2.new(1,-184,y,0),
            Size=UDim2.fromOffset(158,52),BackgroundTransparency=1,GroupTransparency=1,Visible=false,ZIndex=25},gui)
        local hit=create("TextButton",{Name=key,Text="",Size=UDim2.new(1,-4,1,-4),Position=UDim2.fromOffset(2,2),
            BackgroundColor3=colors.card,BackgroundTransparency=0.12,AutoButtonColor=false,BorderSizePixel=0,ZIndex=26},host)
        round(hit,10)
        local edge=create("UIStroke",{Color=accent,Thickness=1,Transparency=0.65},hit)
        local titleLabel=text(hit,title,11,{Position=UDim2.fromOffset(12,6),Size=UDim2.new(1,-24,0,18),
            Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=27},true)
        local status=text(hit,"DESLIGADO",9,{Position=UDim2.fromOffset(8,26),Size=UDim2.new(1,-16,0,15),
            TextXAlignment=Enum.TextXAlignment.Center,ZIndex=27},true)
        local entry={host=host,hit=hit,title=titleLabel,status=status,edge=edge,drag={moved=false,suppressUntil=0}}
        quick.buttons[key]=entry
        API.UI.Draggable(hit,host,entry.drag)
        return entry
    end
    local jump=make("AutoJump","AUTO JUMP",0.60)
    local freeze=make("Freeze","FREEZE",0.42)
    local function visibility(entry,wanted)
        if entry.wanted==wanted then return end
        entry.wanted=wanted
        if entry.done then entry.done:Disconnect();entry.done=nil end
        if entry.fade then entry.fade:Cancel();entry.fade=nil end
        if wanted then entry.host.Visible=true end
        if not entry.host.Visible then return end
        entry.fade=tween(entry.host,{GroupTransparency=wanted and 0 or 1},0.18)
        local current=entry.fade
        entry.done=current.Completed:Connect(function()
            if entry.fade~=current then return end
            entry.done:Disconnect();entry.done=nil;entry.fade=nil
            if state.alive and entry.host.Parent then entry.host.Visible=entry.wanted end
        end)
    end
    function quick.Refresh()
        if not state.alive then return end
        local now=os.clock()
        local remaining=math.max(0,math.ceil(quick.readyAt-now))
        local style=quick.displayed
        if style and style.jumping==quick.jumping and style.queued==quick.freezeQueued and style.remaining==remaining
            and style.accent==accent and style.text==colors.text and style.card==colors.card and style.muted==colors.muted then return end
        style=style or {};quick.displayed=style
        style.jumping=quick.jumping;style.queued=quick.freezeQueued;style.remaining=remaining
        style.accent=accent;style.text=colors.text;style.card=colors.card;style.muted=colors.muted
        jump.status.Text=quick.jumping and "LIGADO" or "DESLIGADO"
        jump.status.TextColor3=quick.jumping and Color3.fromRGB(130,231,177) or colors.muted
        jump.hit.BackgroundColor3=quick.jumping and Color3.fromRGB(25,57,46) or colors.card
        freeze.status.Text=quick.freezeQueued and "CONGELANDO..." or remaining>0 and ("COOLDOWN: "..remaining) or "PRONTO"
        freeze.status.TextColor3=(quick.freezeQueued or remaining>0) and Color3.fromRGB(246,191,128) or colors.muted
        freeze.hit.BackgroundColor3=(quick.freezeQueued or remaining>0) and Color3.fromRGB(62,44,31) or colors.card
        for _,entry in pairs(quick.buttons) do entry.edge.Color=accent;entry.title.TextColor3=colors.text end
    end
    function quick.Update()
        if not cfg.autoJumpButton then quick.jumping=false end
        if not cfg.freezeButton then quick.generation=quick.generation+1;quick.freezeQueued=false;quick.readyAt=0 end
        visibility(jump,cfg.autoJumpButton and not state.booting)
        visibility(freeze,cfg.freezeButton and not state.booting)
        quick.Refresh()
    end
    function quick.Reset()
        quick.jumping=false;quick.generation=quick.generation+1
        quick.freezeQueued=false;quick.readyAt=0;quick.lastJump=-math.huge
        quick.Refresh()
    end
    function quick.ToggleJump()
        if not state.alive or state.booting or not cfg.autoJumpButton then return false end
        quick.jumping=not quick.jumping;quick.Refresh();return true
    end
    function quick.FreezeNow()
        if not state.alive or state.booting or not cfg.freezeButton or quick.freezeQueued or os.clock()<quick.readyAt then return false end
        local char,hum=character()
        if not hum or hum.Health<=0 then notify("Entre no jogo com um personagem vivo para usar Freeze.");return false end
        quick.generation=quick.generation+1
        local ticket=quick.generation
        local duration=math.clamp(cfg.freezeDuration,0.05,3)
        quick.freezeQueued=true;quick.Refresh()
        -- Give the button feedback one frame, then stall this client for the bounded duration.
        -- No anchoring, remote traffic, cooldown modification, or claim of protection from hits.
        task.delay(0.035,function()
            if not state.alive or not cfg.freezeButton or ticket~=quick.generation then return end
            if player.Character~=char or hum.Health<=0 then quick.Reset();return end
            local untilTime=os.clock()+duration
            while os.clock()<untilTime do end
            quick.freezeQueued=false;quick.readyAt=os.clock()+cfg.freezeCooldown;quick.Refresh()
        end)
        return true
    end
    for _,item in ipairs({{jump,quick.ToggleJump},{freeze,quick.FreezeNow}}) do
        local entry,callback=item[1],item[2]
        listen(entry.hit.Activated,function()
            if not entry.drag.moved and os.clock()>=entry.drag.suppressUntil then callback() end
        end)
    end
    function quick.Step(dt)
        if not cfg.autoJumpButton and not cfg.freezeButton and not quick.jumping and not quick.freezeQueued then return end
        quick.clock=quick.clock+dt
        if quick.clock>=0.1 then quick.clock=0;quick.Refresh() end
        if not quick.jumping or not cfg.autoJumpButton or state.booting then return end
        local _,hum,root=character()
        if not hum or not root or hum.Health<=0 then quick.Reset();return end
        if cfg.fly or root.Anchored or hum.Sit or hum.PlatformStand or Input:GetFocusedTextBox() then return end
        local now=os.clock()
        if now-quick.lastJump>=cfg.autoJumpInterval and hum.FloorMaterial~=Enum.Material.Air
            and hum:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
            quick.lastJump=now;hum.Jump=true;hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
    function quick.Stop()
        quick.Reset()
        for _,entry in pairs(quick.buttons) do
            if entry.done then entry.done:Disconnect() end
            if entry.fade then entry.fade:Cancel() end
        end
    end
    actions.autoJumpButton=quick.Update;actions.freezeButton=quick.Update
    listen(player.CharacterRemoving,quick.Reset)
    listen(player.CharacterAdded,quick.Reset)
end

-- Icons are made from GUI primitives, without fonts or remote image dependencies.
local function line(parent,x1,y1,x2,y2,color,thickness)
    local dx,dy=x2-x1,y2-y1
    return create("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),
        Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),thickness or 1.3),Rotation=math.deg(math.atan2(dy,dx)),
        BackgroundColor3=color or colors.muted,BorderSizePixel=0},parent)
end
local function ring(parent,x,y,w,h)
    local f=create("Frame",{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1},parent)
    round(f,99); create("UIStroke",{Thickness=1.2,Color=colors.muted},f); return f
end
local function icon(parent,kind)
    local f=create("Frame",{Size=UDim2.fromOffset(20,20),Position=UDim2.fromOffset(10,8),BackgroundTransparency=1},parent)
    if kind=="Combat" then
        ring(f,4,4,12,12); ring(f,8,8,4,4)
        for _,p in ipairs({{10,0,10,4},{10,16,10,20},{0,10,4,10},{16,10,20,10}}) do line(f,table.unpack(p)) end
    elseif kind=="AI" then
        ring(f,2,3,16,14); text(f,"AI",8,{TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromOffset(20,20)})
    elseif kind=="ESP" then ring(f,1,5,18,10); ring(f,7,7,6,6)
    elseif kind=="World" then ring(f,1,1,18,18); ring(f,6,1,8,18); line(f,1,10,19,10); line(f,3,5,17,5); line(f,3,15,17,15)
    elseif kind=="Shaders" then
        line(f,10,0,13,7);line(f,13,7,20,10);line(f,20,10,13,13);line(f,13,13,10,20)
        line(f,10,20,7,13);line(f,7,13,0,10);line(f,0,10,7,7);line(f,7,7,10,0)
    elseif kind=="Automation" then
        ring(f,5,5,10,10)
        for i=0,7 do local a=i*math.pi/4; line(f,10+math.cos(a)*6,10+math.sin(a)*6,10+math.cos(a)*9,10+math.sin(a)*9) end
    elseif kind=="Performance" then line(f,2,15,6,8);line(f,6,8,10,12);line(f,10,12,17,3);line(f,14,3,17,3);line(f,17,3,17,6)
    elseif kind=="Emotes" then ring(f,1,1,18,18);line(f,6,7,6,8);line(f,14,7,14,8);line(f,6,13,10,15);line(f,10,15,14,13)
    else ring(f,3,3,14,14);ring(f,7,7,6,6) end
    return f
end
local function page(name,number)
    local scroll=create("ScrollingFrame",{Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=2,ScrollBarImageColor3=accent,ScrollingDirection=Enum.ScrollingDirection.Y,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Visible=false},body)
    create("UIPadding",{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,8),PaddingRight=UDim.new(0,5),PaddingLeft=UDim.new(0,1)},scroll)
    create("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},scroll)
    local columns={}
    for i=1,2 do
        local col=create("Frame",{Name="Column"..i,Size=UDim2.new(0.5,-5,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=i},scroll)
        create("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},col);columns[i]=col
    end
    pages[name]={root=scroll,columns=columns,number=number,texts={}}
    return columns[1],columns[2]
end
local function selectPage(name)
    if not pages[name] then return end
    if state.page==name and pages[name].root.Visible then return end
    state.page=name
    for key,p in pairs(pages) do p.root.Visible=key==name end
    heading.Text=string.format("%02d / %s",pages[name].number,string.upper(name))
    for key,n in pairs(navs) do
        n.button.BackgroundTransparency=key==name and 0.65 or 1
        n.stroke.Transparency=key==name and 0.25 or 1
        n.marker.Visible=key==name
    end
    -- Fade text only: avoids CanvasGroup render textures on low-memory phones.
    for _,o in ipairs(pages[name].texts) do
        local visible=true;local p=o.Parent
        while p and p~=pages[name].root do
            if p:IsA("GuiObject") and not p.Visible then visible=false;break end;p=p.Parent
        end
        if visible and o.Parent and o.Text~="" then
            o.TextTransparency=1; tween(o,{TextTransparency=0},0.16)
        end
    end
    applyAppearance();if refreshAccent then refreshAccent() end
    if name=="ESP" and refreshPreview then task.defer(refreshPreview) end
end
API.SelectPage=selectPage
local navOrder={"Combat","AI","ESP","World","Shaders","Automation","Performance","Emotes","Config"}
for i,name in ipairs(navOrder) do
    local b=button(rail,"",10,{Name="Nav"..name,Position=UDim2.fromOffset(7,53+(i-1)*35),Size=UDim2.fromOffset(40,31),BackgroundTransparency=1})
    local stroke=accented(create("UIStroke",{Thickness=0.8,Transparency=1},b),"Color")
    local marker=accented(create("Frame",{Position=UDim2.fromOffset(-6,10),Size=UDim2.fromOffset(2,15),BorderSizePixel=0,Visible=false},b),"BackgroundColor3")
    icon(b,name); navs[name]={button=b,stroke=stroke,marker=marker}
    listen(b.Activated,function() selectPage(name) end)
    listen(b.MouseEnter,function() heading.Text=string.format("%02d / %s",i+1,string.upper(name)) end)
    listen(b.MouseLeave,function() local p=pages[state.page]; if p then heading.Text=string.format("%02d / %s",p.number,string.upper(state.page)) end end)
end
create("ImageLabel",{Name="Avatar",Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=100&h=100",
    Size=UDim2.fromOffset(25,25),Position=UDim2.new(0,15,1,-38),BackgroundTransparency=1},rail)
local function card(parent,title,key,description)
    local f=themed(create("Frame",{Name=key or title,Size=UDim2.new(1,0,0,36),AutomaticSize=Enum.AutomaticSize.None,
        BorderSizePixel=0,BackgroundTransparency=0.3,ClipsDescendants=true},parent),"BackgroundColor3","card")
    round(f,6)
    surface(f,0.3)
    local stroke=accented(create("UIStroke",{Thickness=0.8,Transparency=0.95},f),"Color")
    create("UIGradient",{Rotation=18,Color=ColorSequence.new(Color3.fromRGB(200,188,216),Color3.fromRGB(255,245,240))},f)
    local top=button(f,"",12,{Name="Header",Size=UDim2.new(1,0,0,36),BackgroundTransparency=1})
    local label=text(top,title,11,{Position=UDim2.fromOffset(10,7),Size=UDim2.new(1,-84,0,22),Font=Enum.Font.GothamBold})
    local expand=button(top,"+",14,{Name="Expand",Position=UDim2.new(1,-69,0,8),Size=UDim2.fromOffset(19,20),BackgroundTransparency=0.6})
    local toggle=button(top,"",10,{Name="Toggle",Position=UDim2.new(1,-43,0,11),Size=UDim2.fromOffset(29,15),BackgroundColor3=Color3.fromRGB(60,54,70)})
    round(toggle,20)
    local knob=create("Frame",{Name="Knob",Position=UDim2.fromOffset(2,2),Size=UDim2.fromOffset(11,11),BackgroundColor3=colors.muted,BorderSizePixel=0},toggle);round(knob,20)
    local content=create("Frame",{Name="Options",Position=UDim2.fromOffset(10,37),Size=UDim2.new(1,-20,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=false},f)
    create("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},content)
    create("UIPadding",{PaddingBottom=UDim.new(0,10)},content)
    if description then
        local d=text(content,description,10,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=-100})
        themed(d,"TextColor3","muted")
        listen(top.MouseEnter,function()
            local cam=workspace.CurrentCamera;if not cam or Input.TouchEnabled then return end
            local pos=Input:GetMouseLocation();local view=cam.ViewportSize
            tooltip.Text=title.."\n"..description
            tooltip.Position=UDim2.fromOffset(math.clamp(pos.X+14,0,math.max(0,view.X-240)),math.clamp(pos.Y+16,0,math.max(0,view.Y-90)))
            tooltip.Visible=true
        end)
        listen(top.MouseLeave,function() tooltip.Visible=false end)
    end
    local expanded=false
    local function expandCard()
        expanded=not expanded;content.Visible=expanded;expand.Text=expanded and "-" or "+"
        f.AutomaticSize=expanded and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
        f.Size=UDim2.new(1,0,0,expanded and 37 or 36)
    end
    listen(expand.Activated,expandCard);listen(top.Activated,expandCard)
    if key then
        optionLabels[key]=title
        local function redraw(value,instant)
            local change=instant and function(o,p) for k,v in pairs(p) do o[k]=v end end or tween
            change(knob,{Position=UDim2.fromOffset(value and 16 or 2,2),BackgroundColor3=value and accent or colors.muted})
            change(toggle,{BackgroundColor3=value and accent:Lerp(colors.card,0.65) or Color3.fromRGB(60,54,70)})
            change(stroke,{Transparency=value and 0.5 or 0.95})
            change(f,{BackgroundColor3=value and accent:Lerp(colors.card,0.88) or colors.card})
            label.TextColor3=value and colors.text or colors.muted
        end
        watch(key,redraw)
        accentRefreshers[#accentRefreshers+1]={pageOf(f),function() redraw(cfg[key],true) end}
        listen(toggle.Activated,function() set(key,not cfg[key]) end)
    else toggle.Visible=false;expand.Position=UDim2.new(1,-29,0,8);label.Size=UDim2.new(1,-46,0,22) end
    return content,expandCard,f
end
local function checkbox(parent,label,key)
    optionLabels[key]=label
    local b=button(parent,label,10,{Name=key,Size=UDim2.new(1,0,0,23),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left})
    local mark=button(b,"",9,{Position=UDim2.new(1,-18,0,4),Size=UDim2.fromOffset(14,14),BackgroundTransparency=0.4})
    local function update(v) mark.Text=v and "+" or "";mark.BackgroundColor3=v and accent or Color3.fromRGB(58,51,65) end
    watch(key,update)
    accentRefreshers[#accentRefreshers+1]={pageOf(b),function() update(cfg[key]) end}
    local function toggle() set(key,not cfg[key]) end
    listen(b.Activated,toggle);listen(mark.Activated,toggle)
    return b
end
local function slider(parent,label,key,min,max,step,unit)
    local f=create("Frame",{Name=key,Size=UDim2.new(1,0,0,36),BackgroundTransparency=1},parent)
    text(f,label,10,{Size=UDim2.new(0.66,0,0,18)})
    local value=create("TextBox",{Name="Value",Size=UDim2.new(0.34,0,0,18),Position=UDim2.fromScale(0.66,0),Text="",
        TextColor3=accent,TextSize=10,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Right,
        BackgroundTransparency=1,ClearTextOnFocus=false},f)
    local pg=pageOf(value);if pg then pages[pg.Name].texts[#pages[pg.Name].texts+1]=value end
    accented(value,"TextColor3")
    local hit=button(f,"",10,{Name="SliderInput",Position=UDim2.fromOffset(0,18),Size=UDim2.new(1,0,0,18),BackgroundTransparency=1})
    local track=create("Frame",{Name="Track",Position=UDim2.fromOffset(0,7),Size=UDim2.new(1,0,0,4),BackgroundColor3=Color3.fromRGB(64,53,68),BorderSizePixel=0},hit)
    round(track,4)
    local fill=accented(create("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BorderSizePixel=0},track),"BackgroundColor3"); round(fill,5)
    local knob=create("Frame",{Name="Knob",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(1,0.5),Size=UDim2.fromOffset(6,6),BackgroundColor3=colors.text,BorderSizePixel=0},fill);round(knob,9)
    local function redraw(v)
        fill.Size=UDim2.fromScale((v-min)/(max-min),1)
        if not value:IsFocused() then value.Text=(step>=1 and string.format("%.0f",v) or string.format("%.2f",v))..(unit or "") end
    end
    watch(key,redraw)
    local function update(input)
        if track.AbsoluteSize.X<=0 then return end
        local x=math.clamp((input.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local v=math.clamp(math.floor((min+(max-min)*x)/step+0.5)*step,min,max); set(key,v)
    end
    listen(hit.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then beginPointer(input,update) end
    end)
    listen(value.FocusLost,function()
        local v=tonumber((value.Text:gsub("[^%d%.%-]","")))
        if v then set(key,math.clamp(v,min,max)) else redraw(cfg[key]) end
    end)
end
local function actionButton(parent,title,fn)
    local b=button(parent,title,10,{Name=title});listen(b.Activated,function()
        local ok,err=pcall(fn);if not ok then notify("Nao foi possivel concluir: "..title);warn("[HV] "..tostring(err)) end
    end);return b
end
local function cycle(parent,title,key,options)
    local b=button(parent,"",10,{Name=key,TextXAlignment=Enum.TextXAlignment.Left})
    watch(key,function(v) b.Text="  "..title..": "..v.."  >" end)
    listen(b.Activated,function()
        local at=1;for i,v in ipairs(options) do if v==cfg[key] then at=i end end
        set(key,options[at%#options+1])
    end)
end
local function pending(parent,title,key)
    local c=card(parent,title,key,"Integracao ainda nao mapeada. O video nao revela os eventos e argumentos que este recurso usa no jogo.")
    actionButton(c,"Copiar diagnostico",function() API.ExportDiagnostics() end)
    return c
end

local quickPanel=create("Frame",{Name="QuickUI",Position=UDim2.new(1,-246,0,36),Size=UDim2.fromOffset(230,156),
    BackgroundColor3=colors.card,BorderSizePixel=0,Visible=false,ZIndex=20},window)
round(quickPanel,8);surface(quickPanel,0)
accented(create("UIStroke",{Thickness=0.8,Transparency=0.45},quickPanel),"Color")
create("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,10)},quickPanel)
create("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},quickPanel)
text(quickPanel,"AJUSTES DO MENU",10,{Font=Enum.Font.GothamBold})
slider(quickPanel,"Escala do menu","uiScale",0.45,1.6,0.05,"x")
slider(quickPanel,"Transparencia","transparency",0,85,1,"%")
checkbox(quickPanel,"Notificacoes","notifications")
listen(quickButton.Activated,function() quickPanel.Visible=not quickPanel.Visible;uiDirty=true end)

local left,right=page("Combat",2)
local c=card(left,"Auto Revive","autoRevive","Aciona prompts proximos com Revive/Reviver. Nao implementa reviver a si mesmo por um evento desconhecido.")
slider(c,"Intervalo","promptDelay",0.25,3,0.05,"s")
c=card(left,"Speed Boost","speedBoost","Ajuste local de velocidade; o servidor pode corrigir esse valor.")
slider(c,"WalkSpeed","walkSpeed",8,150,1)
c=card(left,"Auto Zone","autoZone","Ao ligar, faz um unico TP para a zona segura registrada. A zona B do registro e reconhecida pela area Safe carregada; pontos de outros mapas nao sao reutilizados.")
API.NativeStatusLabels.zone=text(c,"Destino: zona B registrada",9,{Size=UDim2.new(1,0,0,32),TextWrapped=true})
actionButton(c,"Marcar zona aqui",function() if API.Native then API.Native.CaptureZone() end end)
c=card(left,"Player Lock On","lockOn","Mira no jogador vivo mais proximo dentro do raio. A captura do jogo precisa de integracao separada.")
slider(c,"Radius","radius",5,150,1," studs");slider(c,"Prediction","prediction",0,0.5,0.01,"s")
slider(c,"Smoothness","aimSmooth",1,25,1);checkbox(c,"Auto Face Target","faceTarget");checkbox(c,"Ignorar mesmo time","teamCheck")
c=card(left,"Auto Use Gears","autoGears","No Huss Valley, pede o uso do gear selecionado pelo jogo, separado da habilidade. Em outros jogos, usa a ferramenta equipada.")
slider(c,"Intervalo","gearDelay",0.2,10,0.1,"s")
API.NativeStatusLabels.gear=text(c,"Status: aguardando ativacao",9)
pending(left,"Auto Down","autoDown")
c=card(right,"Auto Dash","autoDash","Aciona o botao de dash do jogo quando um oponente entra no alcance. No toque, nao simula teclas. O fallback por teclado exige ativacao explicita no PC e a tecla correta do jogo.")
slider(c,"Alcance do inimigo","dashRange",2,100,1," studs");slider(c,"Delay","dashDelay",0.25,10,0.25,"s")
checkbox(c,"Fallback por tecla (PC)","dashKeyboardFallback")
cycle(c,"Tecla do dash (fallback)","dashKey",{"Q","E","F","LeftShift","LeftControl","Space"})
API.NativeStatusLabels.dash=text(c,"Status: aguardando partida",9)
actionButton(c,"Testar dash agora",function() if API.Native then API.Native.Dash(true) end end)
c=card(right,"Auto Attack","autoAttack","Ataque do jogo contra runners proximos quando voce e catcher. Aguarda a resposta e o intervalo do jogo.")
slider(c,"Range","attackRange",2,50,1," studs");slider(c,"Delay","attackDelay",0.15,3,0.05,"s")
API.NativeStatusLabels.attack=text(c,"Status: aguardando partida",9)
c=card(right,"Auto Pick","autoPick","Aciona prompts proximos de coleta (pick up, collect, coletar). Precisa de fireproximityprompt no executor.")
slider(c,"Intervalo","promptDelay",0.25,3,0.05,"s")
c=card(right,"Auto Tackle","autoTackle","Tackle contra runners proximos quando voce e catcher. O jogo continua decidindo a captura.")
slider(c,"Alcance","tackleRange",2,12,0.5," studs");API.NativeStatusLabels.tackle=text(c,"Status: aguardando partida",9)
pending(right,"Dash Cooldown","dashCooldown")
c=card(right,"Auto Ability","autoAbility","Usa a habilidade equipada quando um oponente esta perto. Aguarda a disponibilidade do jogo.")
slider(c,"Distancia do oponente","abilityRange",2,40,1," studs");API.NativeStatusLabels.ability=text(c,"Status: aguardando partida",9)
c=card(right,"Anti-Hit (pendente)","antiHit","Protecao ainda nao validada. Use Gravar meu escudo antes de equipar e ativar o OneHitShield pelo jogo; marque a ativacao e copie o registro depois.")
local hitStatus=text(c,"Status: aguardando analise",10)
actionButton(c,"Gravar meu escudo",function() API.StartShieldDiagnostics() end)
actionButton(c,"Marcar escudo ativado",function() API.MarkDiagnostics("Escudo ativado") end)
actionButton(c,"Aguardar meu hit",function() API.StartHitDiagnostics() end)
actionButton(c,"Gravar 20s agora",function() API.StartHitDiagnostics(false) end)
actionButton(c,"Encerrar e copiar",function() API.StopHitDiagnostics(true) end)
actionButton(c,"Copiar ultimo registro",function() API.CopyHitDiagnostics() end)
actionButton(c,"Gravar rodada inteira",function() API.StartGeneralDiagnostics() end)
left,right=page("AI",3)
pending(left,"Runner AI","runnerAI");pending(right,"Catcher AI","catcherAI")
local info=card(left,"Huss Valley / integracao",nil,"O caminho do mapa, zonas seguras, equipes e controles precisam ser identificados dentro do jogo. Use o diagnostico para a proxima etapa.")
actionButton(info,"Copiar diagnostico",function() API.ExportDiagnostics() end)

left,right=page("ESP",4)
c=card(left,"Players","esp","Marcadores acompanham a posicao atual a cada quadro, depois da camera. Dados e limites do avatar usam cache.")
for _,v in ipairs({{"Boxes","boxes"},{"Names","names"},{"Tracers","tracers"},{"Health","health"},{"Distance","distance"},
    {"Skeleton","skeleton"},{"Head Dot","headDot"},{"Health Text","healthText"}}) do checkbox(c,v[1],v[2]) end
card(left,"ESP de times","espTeams","Mostra jogador e nome do time na cor da equipe. Substitui boxes, esqueleto e outros desenhos enquanto ligado. Usa Runner/Catcher quando o jogo publica papeis em vez de times.")
c=card(left,"Roles & Threat",nil,"Cores por papel publicado pelo jogo: catcher em vermelho e runner em verde. Usa o time quando nao ha papel disponivel.")
checkbox(c,"Cores por papel / time","roleColors");checkbox(c,"Ignorar mesmo time","teamFilter")
c=card(left,"Appearance",nil);cycle(c,"Accent","accent",{"Peach","Purple","Blue","Pink","Green"})
card(left,"View Tracer","viewTracer","Mostra a direcao em que os outros jogadores olham.")
pending(left,"Leaderboard Visuals","leaderboard")
card(left,"Name Hider","nameHider","Oculta o nome padrao sobre seu personagem apenas neste cliente.")
c=card(right,"Settings",nil);slider(c,"Max distance","espRange",50,3000,50," studs");slider(c,"Dados / cores","espRate",2,30,1," Hz")
card(right,"Chams","chams","Contorno local dos jogadores com Highlight.")
pending(right,"Hit Box","hitbox");pending(right,"Gems & Coins","gems")
card(right,"Headless","headless","Esconde sua cabeca apenas neste cliente.")
local previewOptions,previewExpand=card(right,"ESP PREVIEW",nil)
local viewport=create("ViewportFrame",{Name="AvatarPreview",Size=UDim2.new(1,0,0,155),BackgroundTransparency=1,
    Ambient=Color3.fromRGB(200,190,205),LightColor=Color3.fromRGB(255,235,225),LightDirection=Vector3.new(-1,-1,-2)},previewOptions)
local previewWorld=create("WorldModel",{},viewport)
local previewCam=create("Camera",{FieldOfView=35},viewport);viewport.CurrentCamera=previewCam
local previewNote=text(previewOptions,"Seu avatar / preview local",9,{TextXAlignment=Enum.TextXAlignment.Center})
themed(previewNote,"TextColor3","muted");previewExpand()

left,right=page("World",5)
do
    local content=card(left,"Auto Jump","autoJumpButton","Liga o botao flutuante. Toque nele para iniciar ou parar os saltos; arraste para reposicionar.")
    slider(content,"Intervalo dos saltos","autoJumpInterval",0.1,1,0.05,"s")
    content=card(left,"Freeze","freezeButton","Liga o botao flutuante para uma travada curta da tela/jogo e retorno automatico.")
    slider(content,"Duracao da travada","freezeDuration",0.05,3,0.01,"s")
    slider(content,"Intervalo entre usos","freezeCooldown",0.5,5,0.25,"s")
end
card(left,"Environment","fullbright","Iluminacao local mais clara.")
c=card(left,"Teleport Walk","tpWalk","Deslocamento local adicional; nao garante ignorar validacao do servidor.")
slider(c,"Speed","tpSpeed",1,80,1)
card(left,"X-Ray","xray","Transparencia local de partes do cenario.")
card(left,"Infinite Jump","infiniteJump","Permite pedir um salto no ar.")
c=card(right,"Movement","movement");slider(c,"WalkSpeed","walkSpeed",8,150,1)
checkbox(c,"Fly","fly");slider(c,"Fly Speed","flySpeed",5,150,1);checkbox(c,"NoClip","noclip")
c=card(right,"Spin","spin");slider(c,"Degrees / second","spinSpeed",10,360,10)
c=card(right,"Camera",nil);checkbox(c,"First Person","firstPerson");checkbox(c,"Unlock Mouse","unlockMouse")
checkbox(c,"Custom FOV","customFov");slider(c,"FOV","fov",40,120,1)

left,right=page("Shaders",6)
do
    local content,expand=card(left,"Corredor MM2","shaders","Visual inspirado no corredor: cores neutras, contraste e acabamento refletivo. Os reflexos sao do ambiente; espelhos de personagens e moedas como no video dependem de outros recursos de renderizacao.")
    API.ShaderStatus=text(content,"Status: desligado",9,{Size=UDim2.new(1,0,0,34),TextWrapped=true})
    text(content,"Acompanha mapas novos enquanto ligado",9,{TextWrapped=true,Size=UDim2.new(1,0,0,30)})
    checkbox(content,"Sombras","shaderShadows")
    slider(content,"Exposicao","shaderExposure",-1,1,0.05)
    slider(content,"Contraste","shaderContrast",0,0.4,0.01)
    slider(content,"Saturacao","shaderSaturation",-0.4,0.4,0.02)
    slider(content,"Temperatura","shaderTemperature",-1,1,0.05)
    slider(content,"Bloom","shaderBloom",0,0.6,0.02)
    actionButton(content,"Restaurar visual do jogo",function() set("shaders",false) end)
    expand()
    content,expand=card(right,"Superficies",nil,"Trata superficies planas e solidas do cenario, preservando personagens, itens e areas invisiveis. Os materiais originais ficam preservados por padrao; o acabamento liso e opcional.")
    checkbox(content,"Pisos e tetos","shaderFloors");slider(content,"Reflexo do piso","shaderReflection",0,0.65,0.01)
    checkbox(content,"Paredes","shaderWalls");slider(content,"Reflexo das paredes","shaderWallReflection",0,0.65,0.01)
    checkbox(content,"Acabamento liso","shaderPolish")
    text(content,"Pecas novas recebem o efeito automaticamente. Desligar restaura os valores anteriores.",9,{TextWrapped=true,Size=UDim2.new(1,0,0,45)})
    text(content,"Shaders desliga FPS Booster, baixa qualidade e Fullbright para manter o visual consistente.",9,{TextWrapped=true,Size=UDim2.new(1,0,0,45)})
    expand()
end

left,right=page("Automation",7)
pending(left,"Auto Spin Wheel","autoWheel");pending(left,"Auto Map Vote","autoVote")
c=card(left,"Utilities",nil);checkbox(c,"Anti-Idle","antiIdle")
actionButton(c,"Rejoin Server",function() API.Rejoin() end)
pending(right,"Auto Claim Journey","autoJourney");pending(right,"Disable Anti-AFK","disableGameAFK")
local _,expandUtility=card(right,"Sobre Anti-Idle",nil,"Anti-Idle so usa a API do cliente ao ficar ocioso. O sistema AFK proprio do jogo continua dependendo da integracao.")
expandUtility()

left,right=page("Performance",8)
local perfContent,perfExpand=card(left,"FPS Booster","fpsBoost","Reduz efeitos visuais localmente. Desligue uma opcao ou use Restore para recuperar os valores originais.")
local perfStatus=text(perfContent,"Status: off",9)
for _,v in ipairs({{"Remove Textures","removeTextures"},{"Remove Decals","removeDecals"},{"Remove Particles & Effects","removeParticles"},
    {"Low-Detail Materials","lowDetail"},{"Disable Shadows","noShadows"},{"No Fog & Atmosphere","noFog"},{"Remove Accessories","removeAccessories"}}) do checkbox(perfContent,v[1],v[2]) end
actionButton(perfContent,"Restore Graphics",function() set("fpsBoost",false);set("lowQuality",false) end);perfExpand()
c=card(right,"Display & Quality",nil,"FPS cap so aparece como ativo se o executor fornecer a API. O desempenho depende do aparelho e do jogo.")
checkbox(c,"Low render quality","lowQuality");checkbox(c,"Unlock FPS","unlockFPS");slider(c,"FPS Cap","fpsCap",30,240,10," fps")

left,right=page("Emotes",9)
local emoteContent,emoteExpand=card(left,"Avatar Emotes",nil,"Lista os emotes que ja estao equipados no seu avatar. A disponibilidade depende do rig e das animacoes carregadas.")
local emoteList=create("Frame",{Name="EmoteList",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},emoteContent)
create("UIListLayout",{Padding=UDim.new(0,4)},emoteList)
actionButton(emoteContent,"Refresh Emotes",function() API.RefreshEmotes() end);emoteExpand()
c=card(right,"Playback",nil);actionButton(c,"Stop Emote",function() API.StopEmote() end)

left,right=page("Config",10)
local customizeExpand
c,customizeExpand=card(left,"Customize UI",nil,"Cores, transparencia e escala. A interface se ajusta ao tamanho da tela.")
slider(c,"Escala do menu","uiScale",0.45,1.6,0.05,"x");cycle(c,"Theme","theme",{"Dark","Black"})
slider(c,"Transparencia","transparency",0,85,1,"%");checkbox(c,"Notificacoes","notifications");checkbox(c,"Sound Effects","sounds")
cycle(c,"Accent Color","accent",{"Peach","Purple","Blue","Pink","Green"});checkbox(c,"Rainbow Accent","rainbow")
customizeExpand()
c=card(left,"Interface",nil,"O botao aparece ao recolher a janela. Arraste o botao ou o topo do painel livremente.");cycle(c,"Toggle Menu Key","toggleKey",{"RightShift","LeftAlt","Insert","F4"})
actionButton(c,"Reset Position",function() window.Position=UDim2.fromScale(0.5,0.46);fit() end)
do
    local content=card(left,"Gravador geral",nil,"Grava ate 30 min, inclusive lobby e respawns. Use os marcadores logo apos cada acao. Ao terminar, copie as partes ou salve o JSON.")
    API.DiagnosticStatus=text(content,"Status: parado",10,{Name="GeneralTraceStatus",TextWrapped=true,Size=UDim2.new(1,0,0,34)})
    actionButton(content,"Iniciar gravacao geral",function() API.StartGeneralDiagnostics() end)
    for _,label in ipairs({"Recebi hit","Cai","Matei","Zona","Revivi","Habilidade"}) do
        actionButton(content,"Marcar: "..label,function() API.MarkDiagnostics(label) end)
    end
    actionButton(content,"Encerrar e copiar",function() API.StopHitDiagnostics(true) end)
    actionButton(content,"Copiar proxima parte",function() API.CopyNextDiagnosticsPart() end)
    actionButton(content,"Copiar resumo de acoes",function() API.CopyActionDiagnostics() end)
    actionButton(content,"Copiar tudo",function() API.CopyHitDiagnostics() end)
    actionButton(content,"Salvar JSON",function() API.SaveDiagnostics() end)
    API.TraceToolbar=create("Frame",{Name="TraceToolbar",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,6),
        Size=UDim2.new(0.72,0,0,56),BackgroundColor3=colors.card,BorderSizePixel=0,Visible=false,ZIndex=35},gui)
    round(API.TraceToolbar,6)
    create("UISizeConstraint",{MinSize=Vector2.new(260,56),MaxSize=Vector2.new(490,56)},API.TraceToolbar)
    text(API.TraceToolbar,"GRAVANDO / marque logo apos a acao",9,{Position=UDim2.fromOffset(8,2),Size=UDim2.new(1,-16,0,17),ZIndex=36})
    for i,item in ipairs({{"Hit","Recebi hit"},{"Cai","Cai"},{"Matei","Matei"},{"Zona","Zona"},{"Revivi","Revivi"},{"Habil.","Habilidade"},{"Parar"}}) do
        local marker=button(API.TraceToolbar,item[1],9,{Name="TraceMarker"..i,Position=UDim2.new((i-1)/7,2,0,23),Size=UDim2.new(1/7,-4,0,27),ZIndex=36})
        listen(marker.Activated,function() if i==6 then API.MarkAbilityDiagnostics() elseif item[2] then API.MarkDiagnostics(item[2]) else API.StopHitDiagnostics(true) end end)
    end
end
local configs,configExpand=card(right,"Configs",nil,"Salve com um nome. Selecione um perfil na lista e use Load para aplicar suas opcoes.")
local configName=create("TextBox",{Name="ConfigName",Size=UDim2.new(1,0,0,27),Text="my-config",PlaceholderText="Config name",ClearTextOnFocus=false,
    BackgroundColor3=Color3.fromRGB(36,29,44),TextColor3=colors.text,TextSize=10,Font=Enum.Font.GothamMedium,BorderSizePixel=0},configs);round(configName,5)
surface(configName,0)
do
    local ui={Rows={},Selected=nil,Names={}}
    API.ConfigUI=ui
    local selected=text(configs,"Selecionada: nenhuma",10,{Name="SelectedConfig",Size=UDim2.new(1,0,0,21)})
    local list=create("ScrollingFrame",{Name="SavedConfigs",Size=UDim2.new(1,0,0,104),
        BackgroundTransparency=0.5,BackgroundColor3=colors.bg,BorderSizePixel=0,ScrollBarThickness=3,
        CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y},configs);round(list,5)
    local empty=text(list,"Nenhuma configuracao salva.",10,{Name="EmptyConfigs",Size=UDim2.new(1,-12,0,35),
        Position=UDim2.fromOffset(6,3),TextWrapped=true})
    function ui.Paint()
        list.BackgroundColor3=colors.bg;list.ScrollBarImageColor3=accent
        for name,row in pairs(ui.Rows) do
            local active=ui.Selected==name
            row.button.BackgroundColor3=active and accent:Lerp(colors.card,0.78) or colors.card
            row.button.TextColor3=active and accent or colors.text
            row.edge.Color=accent;row.edge.Transparency=active and 0.25 or 1
        end
    end
    function ui.Select(name)
        ui.Selected=name;selected.Text="Selecionada: "..(name or "nenhuma")
        if name then configName.Text=name end
        ui.Paint()
        if ui.AfterSelect then ui.AfterSelect(name) end
    end
    function ui.SetNames(names,preferred)
        ui.Names=names
        local found={}
        for i,name in ipairs(names) do
            found[name]=true
            local row=ui.Rows[name]
            if not row then
                local b=create("TextButton",{Name="ConfigEntry",Text="  "..name,TextSize=10,
                    Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Left,
                    BackgroundColor3=colors.card,TextColor3=colors.text,AutoButtonColor=false,
                    BorderSizePixel=0,Size=UDim2.new(1,-12,0,25)},list);round(b,4)
                row={button=b,edge=create("UIStroke",{Color=accent,Thickness=1,Transparency=1},b)}
                row.connection=b.Activated:Connect(function() ui.Select(name) end)
                ui.Rows[name]=row
            end
            row.button.Position=UDim2.fromOffset(5,(i-1)*28+5)
        end
        for name,row in pairs(ui.Rows) do
            if not found[name] then row.connection:Disconnect();row.button:Destroy();ui.Rows[name]=nil end
        end
        list.CanvasSize=UDim2.fromOffset(0,#names*28+10);empty.Visible=#names==0
        ui.Select(found[preferred] and preferred or found[ui.Selected] and ui.Selected or names[1])
    end
    function ui.Stop() for _,row in pairs(ui.Rows) do row.connection:Disconnect() end end
    accentRefreshers[#accentRefreshers+1]={pageOf(list),ui.Paint}
end
actionButton(configs,"Save Config",function() API.SaveConfig(configName.Text) end)
actionButton(configs,"Load Config",function()
    if not API.ConfigUI.Selected then notify("Selecione uma configuracao salva na lista.");return end
    API.LoadConfig(API.ConfigUI.Selected)
end)
actionButton(configs,"Delete Config",function()
    if not API.ConfigUI.Selected then notify("Selecione uma configuracao salva na lista.");return end
    API.DeleteConfig(API.ConfigUI.Selected)
end)
actionButton(configs,"Atualizar lista",function() API.RefreshConfigs() end)
checkbox(configs,"Auto-Load This Config On Launch","autoLoad");configExpand()
local suite,suiteExpand=card(right,"Suite",nil,"HUSS VALLEY / "..API.Version)
actionButton(suite,"Rejoin Server",function() API.Rejoin() end)
actionButton(suite,"Destroy Menu",function() API.Destroy() end)
actionButton(suite,"Copiar diagnostico",function() API.ExportDiagnostics() end);suiteExpand()
bootProgress(0.7,"Conectando controles e recursos...")

-- Rainbow updates only accent colors on visible pages, never the full theme.
refreshAccent=function()
    accent=cfg.rainbow and Color3.fromHSV((os.clock()*0.08)%1,0.45,1) or palette[cfg.accent]
    if API.QuickActions then API.QuickActions.Refresh() end
    if not state.visible then return end
    for _,entry in ipairs(accentItems) do if entry[1].Parent and (not entry[3] or entry[3].Visible) then entry[1][entry[2]]=accent end end
    for _,entry in ipairs(accentRefreshers) do if not entry[1] or entry[1].Visible then entry[2]() end end
end
refreshTheme=function()
    colors.bg=cfg.theme=="Black" and Color3.fromRGB(7,7,10) or Color3.fromRGB(16,14,23)
    colors.card=cfg.theme=="Black" and Color3.fromRGB(20,19,25) or Color3.fromRGB(27,23,36)
    for _,entry in ipairs(themes) do if entry[1].Parent then entry[1][entry[2]]=colors[entry[3]] end end
    refreshAccent();applyAppearance()
end
local clickSound=create("Sound",{Name="UITick",SoundId="rbxasset://sounds/electronicpingshort.wav",Volume=0.15},gui)
function API.PlaySound() if cfg.sounds then pcall(function() clickSound:Play() end) end end
actions.uiScale=fit
actions.transparency=function(v) cfg.opacity=1-v/100;uiDirty=true end
actions.opacity=function(v) set("transparency",(1-v)*100,true) end
actions.theme=refreshTheme;actions.accent=refreshAccent;actions.rainbow=refreshAccent
actions.floating=function() API.UI.UpdateFloating() end -- old configs retain this key; the closed menu always has a launcher.

-- Character and camera features.
local flight
local function stopFlight()
    if flight then for _,obj in ipairs(flight) do obj:Destroy() end;flight=nil end
    restore("flight");flightPad.Visible=false;state.up=false;state.down=false
end
updateFlight=function()
    stopFlight()
    if not cfg.fly then return end
    local _,hum,root=character();if not root or not hum then return end
    local a=create("Attachment",{Name="HVFlightAttachment"},root)
    local v=create("LinearVelocity",{Name="HVFlightVelocity",Attachment0=a,VectorVelocity=Vector3.zero,
        RelativeTo=Enum.ActuatorRelativeTo.World,VelocityConstraintMode=Enum.VelocityConstraintMode.Vector,ForceLimitsEnabled=false},root)
    local o=create("AlignOrientation",{Name="HVFlightOrientation",Attachment0=a,Mode=Enum.OrientationAlignmentMode.OneAttachment,
        MaxTorque=1000000,Responsiveness=25},root)
    flight={a,v,o};patch("flight",hum,"PlatformStand",true);patch("flight",hum,"AutoRotate",false)
    flightPad.Visible=Input.TouchEnabled
end
actions.fly=updateFlight
local collisionParts,collisionConnection={},nil
actions.noclip=function(v)
    if collisionConnection then collisionConnection:Disconnect();collisionConnection=nil end
    collisionParts={}
    restore("collision")
    if not v then return end
    local char=player.Character;if not char then return end
    for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then collisionParts[#collisionParts+1]=part end end
    collisionConnection=char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then collisionParts[#collisionParts+1]=part end
    end)
end
local function applySpeed()
    if cfg.movement or cfg.speedBoost then local _,h=character();if h then patch("speed",h,"WalkSpeed",cfg.walkSpeed) end
    else restore("speed") end
end
actions.movement=applySpeed;actions.speedBoost=applySpeed;actions.walkSpeed=applySpeed
local function applyFov()
    if cfg.customFov and workspace.CurrentCamera then patch("camera",workspace.CurrentCamera,"FieldOfView",cfg.fov) else restore("camera") end
end
actions.customFov=applyFov;actions.fov=applyFov
actions.firstPerson=function(v) if v then patch("firstPerson",player,"CameraMode",Enum.CameraMode.LockFirstPerson) else restore("firstPerson") end end
actions.unlockMouse=function(v) if not v then restore("mouse") end end
actions.fullbright=function(v)
    if v and cfg.shaders then set("shaders",false,true) end
    restore("brightness")
    if v then for k,val in pairs({Brightness=2,ClockTime=14,Ambient=Color3.fromRGB(180,180,180),OutdoorAmbient=Color3.fromRGB(180,180,180)}) do patch("brightness",Lighting,k,val) end end
end
actions.nameHider=function(v)
    restore("nameHider");local _,h=character();if v and h then patch("nameHider",h,"DisplayDistanceType",Enum.HumanoidDisplayDistanceType.None) end
end
actions.headless=function(v)
    restore("headless");local char=player.Character;local head=char and char:FindFirstChild("Head")
    if v and head then patch("headless",head,"LocalTransparencyModifier",1) end
end
listen(flyUp.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then state.up=true end end)
listen(flyDown.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then state.down=true end end)
listen(Input.InputEnded,function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then state.up=false;state.down=false end
end)
listen(Input.JumpRequest,function() if cfg.infiniteJump then local _,h=character();if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
listen(Input.InputBegan,function(i,processed)
    if processed or Input:GetFocusedTextBox() then return end
    if i.KeyCode==Enum.KeyCode[cfg.toggleKey] then show(not state.visible) end
end)
listen(workspace:GetPropertyChangedSignal("CurrentCamera"),function() restore("camera");applyFov();fit() end)
local cameraSizeConnection
local function bindCameraSize()
    if cameraSizeConnection then cameraSizeConnection:Disconnect() end
    local cam=workspace.CurrentCamera
    if cam then cameraSizeConnection=cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
end
bindCameraSize();listen(workspace:GetPropertyChangedSignal("CurrentCamera"),bindCameraSize)

-- Visual performance changes are cancellable, batched, and reversible.
local perfToken,perfQueued,perfCache=0,false,nil
local function ownObject(o) return o:IsDescendantOf(gui) or o:IsDescendantOf(visuals) end
local function characterPart(o)
    local model=o:FindFirstAncestorOfClass("Model")
    while model do if model:FindFirstChildOfClass("Humanoid") then return true end;model=model:FindFirstAncestorOfClass("Model") end
    return false
end
local function optimize(o)
    if ownObject(o) then return end
    if cfg.removeTextures and o:IsA("MeshPart") then patch("perf",o,"TextureID","") end
    if cfg.removeTextures and o:IsA("SpecialMesh") then patch("perf",o,"TextureId","") end
    if cfg.removeDecals and (o:IsA("Decal") or o:IsA("Texture")) then patch("perf",o,"Transparency",1) end
    if cfg.removeParticles and (o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") or o:IsA("PostEffect")) then patch("perf",o,"Enabled",false) end
    if o:IsA("BasePart") then
        if cfg.lowDetail then patch("perf",o,"Material",Enum.Material.SmoothPlastic);patch("perf",o,"Reflectance",0) end
        if cfg.noShadows then patch("perf",o,"CastShadow",false) end
        if cfg.removeAccessories and o:FindFirstAncestorOfClass("Accessory") then patch("perf",o,"LocalTransparencyModifier",1) end
    end
    if cfg.noFog and o:IsA("Atmosphere") then patch("perf",o,"Density",0);patch("perf",o,"Haze",0) end
end
refreshPerformance=function()
    perfToken=perfToken+1;local token=perfToken;restore("perf")
    if not cfg.fpsBoost then perfCache=nil;perfStatus.Text="Status: off";return end
    if cfg.noShadows then patch("perf",Lighting,"GlobalShadows",false) end
    if cfg.noFog then patch("perf",Lighting,"FogEnd",1000000);patch("perf",Lighting,"FogStart",1000000) end
    perfStatus.Text="Aplicando..."
    task.spawn(function()
        if not perfCache then
            perfCache=setmetatable({},{__mode="k"})
            for _,o in ipairs(workspace:GetDescendants()) do perfCache[o]=true end
            for _,o in ipairs(Lighting:GetDescendants()) do perfCache[o]=true end
        end
        local count,inspected=0,0
        for o in pairs(perfCache) do
            if not state.alive or token~=perfToken then return end
            inspected=inspected+1
            if o.Parent then optimize(o);count=count+1 end
            if inspected%160==0 then task.wait() end
        end
        if state.alive and token==perfToken then perfStatus.Text="Status: on | "..count.." objetos avaliados" end
    end)
end
local function schedulePerformance()
    if perfQueued then return end
    perfQueued=true
    task.defer(function() perfQueued=false;if state.alive and cfg.fpsBoost then refreshPerformance() end end)
end
actions.fpsBoost=function(v)
    if v then if cfg.shaders then set("shaders",false,true) end;schedulePerformance() else refreshPerformance() end
end
for _,key in ipairs({"removeTextures","removeDecals","removeParticles","lowDetail","noShadows","noFog","removeAccessories"}) do actions[key]=function() if cfg.fpsBoost then schedulePerformance() end end end
listen(Lighting.DescendantAdded,function(o) if cfg.fpsBoost then if perfCache then perfCache[o]=true end;optimize(o) end end)
actions.lowQuality=function(v)
    if v and cfg.shaders then set("shaders",false,true) end
    restore("quality");if v then
        assert(patch("quality",UserSettings():GetService("UserGameSettings"),"SavedQualityLevel",Enum.SavedQualitySetting.QualityLevel1),"Qualidade grafica protegida nesta versao.")
    end
end
local originalFPS
if type(getfpscap)=="function" then local ok,v=pcall(getfpscap);if ok and type(v)=="number" then originalFPS=v end end
local function applyFPS()
    if cfg.unlockFPS then setfpscap(cfg.fpsCap)
    elseif state.capChanged and originalFPS then setfpscap(originalFPS)
    elseif state.capChanged then notify("O executor nao informa o limite anterior. Ajuste o FPS nas configuracoes do Roblox.") end
    state.capChanged=cfg.unlockFPS
end
actions.unlockFPS=applyFPS;actions.fpsCap=function() if cfg.unlockFPS then applyFPS() end end

-- Native shader look: persistent across streamed/replaced maps, with no scene clones.
do
    local S={running=false,generation=0,connections={},effects={},records=setmetatable({},{__mode="k"}),
        candidates=setmetatable({},{__mode="k"}),pending=setmetatable({},{__mode="k"}),light={},desired={}}
    API.Shaders=S
    function S.Same(a,b)
        if type(a)=="number" and type(b)=="number" then return math.abs(a-b)<0.00001 end
        return a==b
    end
    function S.Status(message)
        if state.alive and API.ShaderStatus then API.ShaderStatus.Text=message end
    end
    function S.Write(object,record,property,value)
        local ok,current=pcall(function() return object[property] end);if not ok then return false end
        local entry=record[property]
        if not entry then entry={value=current,last=current};record[property]=entry
        elseif not S.Same(current,entry.last) then entry.value=current end
        entry.last=value
        if S.Same(current,value) then return true end
        return pcall(function() object[property]=value end)
    end
    function S.RestoreProperty(object,record,property)
        local entry=record[property];if not entry then return end
        -- A newer game-authored value wins over a stale snapshot when restoring.
        pcall(function() if S.Same(object[property],entry.last) then object[property]=entry.value end end)
        record[property]=nil
    end
    function S.RestorePart(object)
        local record=S.records[object];if not record then return end
        for property in pairs(record) do S.RestoreProperty(object,record,property) end
        S.records[object]=nil
    end
    function S.Surface(object)
        if not object:IsA("BasePart") or object:IsA("Terrain") or not object:IsDescendantOf(workspace) or ownObject(object)
            or not object.Anchored or not object.CanCollide or object.Transparency>=0.95 or characterPart(object)
            or object:FindFirstAncestorOfClass("Tool") or object:FindFirstAncestorOfClass("Accessory") then return end
        if object.Material==Enum.Material.Neon or object.Material==Enum.Material.ForceField then return end
        local size,cf=object.Size,object.CFrame
        local thickness,area,normal=size.Y,size.X*size.Z,cf.UpVector
        if size.X<thickness then thickness,area,normal=size.X,size.Y*size.Z,cf.RightVector end
        if size.Z<thickness then thickness,area,normal=size.Z,size.X*size.Y,cf.LookVector end
        if area<16 or thickness>math.max(size.X,size.Y,size.Z)*0.35 then return end
        local vertical=math.abs(normal.Y)
        if vertical>=0.75 then return "floor" elseif vertical<=0.35 then return "wall" end
    end
    function S.ApplyPart(object)
        if not S.running or not cfg.shaders then return end
        local kind=S.Surface(object)
        if not kind or (kind=="floor" and not cfg.shaderFloors) or (kind=="wall" and not cfg.shaderWalls) then S.RestorePart(object);return end
        local record=S.records[object] or {};S.records[object]=record
        S.Write(object,record,"Reflectance",kind=="floor" and cfg.shaderReflection or cfg.shaderWallReflection)
        S.Write(object,record,"CastShadow",cfg.shaderShadows)
        if cfg.shaderPolish then
            S.Write(object,record,"Material",Enum.Material.SmoothPlastic);S.Write(object,record,"MaterialVariant","")
        else
            S.RestoreProperty(object,record,"Material");S.RestoreProperty(object,record,"MaterialVariant")
        end
    end
    function S.RefreshStatus()
        if not S.running then return end
        local count=0;for object in pairs(S.records) do if object:IsDescendantOf(workspace) then count=count+1 end end
        S.Status("Ligado | "..count.." superficies | acompanha mapas novos")
    end
    function S.Flush()
        if S.worker or not S.running then return end
        S.worker=true;local generation=S.generation
        task.defer(function()
            local count=0
            while S.running and cfg.shaders and generation==S.generation and next(S.pending) do
                local batch=S.pending;S.pending=setmetatable({},{__mode="k"})
                for object in pairs(batch) do
                    if not S.running or not cfg.shaders or generation~=S.generation then return end
                    if object:IsDescendantOf(workspace) then S.ApplyPart(object) end
                    count=count+1;if count%160==0 then task.wait() end
                end
            end
            if generation==S.generation then S.worker=false;S.RefreshStatus() end
        end)
    end
    function S.Queue(object)
        if not S.running or not object:IsA("BasePart") or ownObject(object) then return end
        S.candidates[object]=true;S.pending[object]=true;S.Flush()
    end
    function S.RefreshSurfaces()
        if not S.running then return end
        for object in pairs(S.candidates) do
            if object:IsDescendantOf(workspace) then S.pending[object]=true else S.RestorePart(object);S.candidates[object]=nil end
        end
        S.Flush()
    end
    function S.ApplyLighting()
        if not S.running or not cfg.shaders then return end
        S.desired={Brightness=2.1,Ambient=Color3.fromRGB(70,72,78),OutdoorAmbient=Color3.fromRGB(110,114,122),
            EnvironmentDiffuseScale=0.65,EnvironmentSpecularScale=1,ExposureCompensation=cfg.shaderExposure,
            GlobalShadows=cfg.shaderShadows,ShadowSoftness=0.18}
        for property,value in pairs(S.desired) do S.Write(Lighting,S.light,property,value) end
        if not S.effects.color or S.effects.color.Parent~=Lighting then
            S.effects.color=create("ColorCorrectionEffect",{Name="HussShaderColor"},Lighting)
        end
        if not S.effects.bloom or S.effects.bloom.Parent~=Lighting then
            S.effects.bloom=create("BloomEffect",{Name="HussShaderBloom"},Lighting)
        end
        local t=cfg.shaderTemperature
        local tint=t>=0 and Color3.fromRGB(255,238,218) or Color3.fromRGB(225,238,255)
        local color=S.effects.color
        color.Enabled=true;color.Brightness=0;color.Contrast=cfg.shaderContrast;color.Saturation=cfg.shaderSaturation
        color.TintColor=Color3.new(1,1,1):Lerp(tint,math.abs(t))
        local bloom=S.effects.bloom
        bloom.Enabled=cfg.shaderBloom>0;bloom.Intensity=cfg.shaderBloom;bloom.Size=18;bloom.Threshold=1.3
    end
    function S.ScheduleLighting()
        if not S.running or S.lightQueued then return end
        S.lightQueued=true;local generation=S.generation
        task.defer(function()
            if S.running and cfg.shaders and generation==S.generation then S.lightQueued=false;S.ApplyLighting() end
        end)
    end
    function S.Stop()
        S.running=false;S.generation=S.generation+1
        for _,connection in ipairs(S.connections) do connection:Disconnect() end;S.connections={}
        for _,effect in pairs(S.effects) do pcall(function() effect:Destroy() end) end;S.effects={}
        for object in pairs(S.records) do S.RestorePart(object) end
        for property in pairs(S.light) do S.RestoreProperty(Lighting,S.light,property) end
        S.records=setmetatable({},{__mode="k"});S.candidates=setmetatable({},{__mode="k"});S.pending=setmetatable({},{__mode="k"})
        S.light={};S.desired={};S.worker=false;S.lightQueued=false;S.elapsed=0;S.Status("Status: desligado")
    end
    function S.Start()
        S.Stop()
        for _,key in ipairs({"fpsBoost","lowQuality","fullbright"}) do if cfg[key] then set(key,false,true) end end
        S.running=true;S.generation=S.generation+1;local generation=S.generation
        local function connect(signal,callback) S.connections[#S.connections+1]=signal:Connect(callback) end
        connect(workspace.DescendantAdded,function(object) S.Queue(object) end)
        connect(workspace.DescendantRemoving,function(object)
            if S.candidates[object] then S.RestorePart(object);S.candidates[object]=nil;S.pending[object]=nil end
        end)
        connect(Lighting.Changed,function(property)
            local desired=S.desired[property]
            if desired==nil or S.Same(Lighting[property],desired) then return end
            if S.light[property] then S.light[property].value=Lighting[property];S.light[property].last=Lighting[property] end
            S.ScheduleLighting()
        end)
        connect(Lighting.DescendantRemoving,function(object)
            if object==S.effects.color or object==S.effects.bloom then S.ScheduleLighting() end
        end)
        -- Reused maps may reset properties without adding/removing any instances.
        -- Reconcile the cached parts in batches after two idle seconds, not the whole workspace.
        connect(Run.Heartbeat,function(dt)
            if S.worker then return end
            S.elapsed=(S.elapsed or 0)+dt
            if S.elapsed>=2 then S.elapsed=0;S.RefreshSurfaces() end
        end)
        S.ApplyLighting();S.Status("Aplicando visual ao mapa...")
        task.spawn(function()
            for index,object in ipairs(workspace:GetDescendants()) do
                if not state.alive or not S.running or not cfg.shaders or generation~=S.generation then return end
                S.Queue(object);if index%240==0 then task.wait() end
            end
            if generation==S.generation then S.RefreshStatus() end
        end)
    end
    actions.shaders=function(enabled) if enabled then S.Start() else S.Stop() end end
    for _,key in ipairs({"shaderFloors","shaderWalls","shaderPolish","shaderReflection","shaderWallReflection"}) do actions[key]=S.RefreshSurfaces end
    actions.shaderShadows=function() S.RefreshSurfaces();S.ScheduleLighting() end
    for _,key in ipairs({"shaderContrast","shaderSaturation","shaderExposure","shaderBloom","shaderTemperature"}) do actions[key]=S.ScheduleLighting end
end
-- End native shaders.
local xrayToken=0
actions.xray=function(v)
    xrayToken=xrayToken+1;local token=xrayToken;restore("xray")
    if v then task.spawn(function()
        for i,o in ipairs(workspace:GetDescendants()) do
            if not state.alive or token~=xrayToken then return end
            if o:IsA("BasePart") and not characterPart(o) and not ownObject(o) then patch("xray",o,"LocalTransparencyModifier",0.65) end
            if i%200==0 then task.wait() end
        end
    end) end
end

-- Reusable target selection does not assume undocumented team/role names.
local roster=Players:GetPlayers()
listen(Players.PlayerAdded,function(p) roster[#roster+1]=p end)
listen(Players.PlayerRemoving,function(p)
    actorCache[p]=nil
    for i=#roster,1,-1 do if roster[i]==p then table.remove(roster,i) end end
end)
local function sameTeam(p)
    local mine,other=player:GetAttribute("GameRole"),p:GetAttribute("GameRole")
    if (mine=="Runner" or mine=="Catcher") and (other=="Runner" or other=="Catcher") then return mine==other end
    return player.Team~=nil and p.Team==player.Team
end
local function nearest(radius)
    local _,_,root=character();if not root then return end
    local origin=root.Position
    local target,best
    best=radius*radius
    for _,p in ipairs(roster) do
        if p~=player and not (cfg.teamCheck and sameTeam(p)) then
            local a=actor(p);local h,r=a.hum,a.root
            if h and r and h.Health>0 then local delta=r.Position-origin;local d=delta.X*delta.X+delta.Y*delta.Y+delta.Z*delta.Z;if d<=best then best=d;target=r end end
        end
    end
    return target,math.sqrt(best)
end
local prompts,promptsReady,promptsScanning={},false,false
local function indexPrompt(o) if o:IsA("ProximityPrompt") then prompts[o]=true end end
local function preparePrompts(immediate)
    if promptsReady then return end
    local function scan(allowYield)
        for i,o in ipairs(workspace:GetDescendants()) do
            if not state.alive then return end
            indexPrompt(o);if allowYield and i%300==0 then task.wait() end
        end
        promptsReady=true;promptsScanning=false
    end
    if immediate then scan(false)
    elseif not promptsScanning then promptsScanning=true;task.spawn(function() scan(true) end) end
end
listen(workspace.DescendantAdded,function(o)
    indexPrompt(o)
    if cfg.fpsBoost then if perfCache then perfCache[o]=true end;optimize(o) end
    if cfg.xray and o:IsA("BasePart") and not ownObject(o) then task.defer(function()
        if state.alive and cfg.xray and o.Parent and not characterPart(o) then patch("xray",o,"LocalTransparencyModifier",0.65) end
    end) end
end)
listen(workspace.DescendantRemoving,function(o) prompts[o]=nil end)
local function processPrompts()
    if not cfg.autoRevive and not cfg.autoPick then return end
    local _,_,root=character();if not root then return end
    local origin=root.Position
    for prompt in pairs(prompts) do
        if prompt.Parent and prompt.Enabled then
            local parent=prompt.Parent;local pos
            if parent:IsA("Attachment") then pos=parent.WorldPosition elseif parent:IsA("BasePart") then pos=parent.Position
            elseif parent:IsA("Model") then pos=parent:GetPivot().Position end
            if pos then
                local delta=pos-origin;local range=prompt.MaxActivationDistance
                if range>=0 and delta.X*delta.X+delta.Y*delta.Y+delta.Z*delta.Z<=range*range then
                    local label=string.lower(prompt.ActionText.." "..prompt.ObjectText.." "..prompt.Name)
                    local wanted=(cfg.autoRevive and label:find("reviv",1,true)) or
                        (cfg.autoPick and (label:find("pick",1,true) or label:find("collect",1,true) or label:find("colet",1,true)))
                    if wanted then
                        local ok=pcall(fireproximityprompt,prompt)
                        if not ok then set("autoPick",false);set("autoRevive",false);notify("O executor nao conseguiu acionar esse prompt.") end
                        return ok
                    end
                end
            end
        end
    end
    return false
end
local function checkPromptCapability(v)
    if v and type(fireproximityprompt)~="function" then error("fireproximityprompt indisponivel") end
    if v then preparePrompts() end
end
actions.autoPick=checkPromptCapability;actions.autoRevive=checkPromptCapability
local function triggerTool(attack)
    if game.GameId==10764627709 then
        if not API.Native then return false end
        if attack then return API.Native.AttackNearest(cfg.attackRange) end
        return API.Native.UseGear()
    end
    if attack and API.Native and API.Native.HasMelee() then return API.Native.AttackNearest(cfg.attackRange) end
    local char=player.Character;local tool=char and char:FindFirstChildOfClass("Tool")
    if tool and tool.Enabled then return pcall(function() tool:Activate() end) end
    return false
end
local adapterTimers,activeAdapters,adapterGeneration={},{},{}
local function stepAdapters(dt)
    for key,name in pairs(activeAdapters) do
        if cfg[key] and type(adapters[name])=="function" and not state.pending[key] then
            adapterTimers[key]=(adapterTimers[key] or 0)+dt
            local callback=adapters[name]
            local perFrame=API.Native and API.Native.ProximityAdapters[name]==callback
            local ready=true
            if perFrame and API.Native.ProximityReady[name] then
                local ok,result=pcall(API.Native.ProximityReady[name])
                ready=ok and result~=nil and result~=false
                if not ok then set(key,false,true);notify("Integracao interrompida: "..name);warn("[HV] "..tostring(result)) end
            end
            if ready and (perFrame or adapterTimers[key]>=0.25) then
                local delta=adapterTimers[key];adapterTimers[key]=0;state.pending[key]=true
                local generation,char=adapterGeneration[key],player.Character
                local function isActive() return state.alive and cfg[key] and adapterGeneration[key]==generation and player.Character==char and adapters[name]==callback end
                task.spawn(function()
                    if not isActive() then state.pending[key]=nil;return end
                    local ok,err=pcall(callback,{Player=player,Config=cfg,Character=char,Delta=delta,Enabled=true,IsActive=isActive})
                    state.pending[key]=nil
                    if not ok and isActive() then set(key,false,true);notify("Integracao interrompida: "..name);warn("[HV] "..tostring(err)) end
                end)
            end
        end
    end
end
for key,name in pairs(requiresAdapter) do actions[key]=function(v)
    -- Auto Zone is one immediate request per activation, never a repeating TP loop.
    activeAdapters[key]=v and key~="autoZone" and name or nil;adapterTimers[key]=0
    adapterGeneration[key]=(adapterGeneration[key] or 0)+1
    local generation,char=adapterGeneration[key],player.Character
    if type(adapters[name])=="function" and (not v or key=="autoZone") then
        adapters[name]({Player=player,Config=cfg,Character=player.Character,Enabled=v,
            IsActive=function() return state.alive and cfg[key] and adapterGeneration[key]==generation and player.Character==char end})
    end
end end
-- Native commands transcribed from the user's runtime trace, never enabled by default.
do
    local N={Status={},Mapped={},ProximityAdapters={},ProximityReady={}}
    API.Native=N
    local paths={melee="ChickenOrHero.Game.MeleeEvent",tackle="ChickenOrHero.Game.GameAction",
        ability="ChickenOrHero.Gear.GearEvent",gear="ChickenOrHero.Gear.GearEvent",dash="ChickenOrHero.Presentation.BoostRequest",replay="ChickenOrHero.Game.HitReplayEvent"}
    local cached,bound,pending,recent,readyAt,lastAttempt={},{},{},{},{},{}
    local roleColors={Catcher=Color3.fromRGB(244,115,125),Runner=Color3.fromRGB(110,212,172)}
    local function finite(value) return type(value)=="number" and value==value and math.abs(value)~=math.huge end
    local function status(kind,message)
        local row=N.Status[kind]
        if row and row.message==message then return row end
        row=row or {sent=0,accepted=0,rejected=0,timeouts=0,failed=0};N.Status[kind]=row;row.message=message
        local label=API.NativeStatusLabels[kind]
        if state.alive and label and label.Text~=message then label.Text=message end
        return row
    end
    local function remote(kind)
        if game.GameId~=10764627709 then return end
        local object=cached[kind];if object and object.Parent then return object end
        object=Replicated
        for segment in paths[kind]:gmatch("[^%.]+") do object=object and object:FindFirstChild(segment) end
        if object and object:IsA("RemoteEvent") then cached[kind]=object;return object end
    end
    local function clock()
        local ok,value=pcall(function() return workspace:GetServerTimeNow() end)
        if ok and finite(value) then return value end
    end
    local function flatUnit(value)
        if typeof(value)~="Vector3" or not finite(value.X) or not finite(value.Z) then return end
        local horizontal=Vector3.new(value.X,0,value.Z)
        if horizontal.Magnitude>0.001 then return horizontal.Unit end
    end
    function N.GameRole(p)
        local role=p:GetAttribute("GameRole")
        if role=="Runner" or role=="Catcher" then return role end
    end
    function N.ESPColor(p)
        local role=N.GameRole(p)
        return role and roleColors[role] or (p.Team and p.TeamColor.Color) or accent
    end
    function N.ESPTeam(p)
        if p.Team and p.Neutral~=true then return p.Team.Name,p.TeamColor.Color end
        local role=N.GameRole(p)
        if role then return role,roleColors[role] end
        return "Sem time",colors.muted
    end
    local function active(kind,requiredRole)
        if not state.alive then return end
        local char,hum,root=character();local role=N.GameRole(player)
        if not char or not hum or not root or hum.Health<=0 or player:GetAttribute("RunState")~="Active" or not role or (requiredRole and role~=requiredRole) then
            status(kind,"Aguardando papel e rodada ativos");return
        end
        return char,hum,root,role
    end
    local function opponent(root,radius,role)
        local target,best=nil,radius*radius
        local origin=root.Position
        for _,p in ipairs(roster) do
            if p~=player then
                local run,targetRole=p:GetAttribute("RunState"),N.GameRole(p)
                if targetRole~=role and targetRole~=nil and (run==nil or run=="Active") then
                    local a=actor(p)
                    if a.hum and a.root and a.hum.Health>0 then
                        local delta=a.root.Position-origin;local distance=delta.X*delta.X+delta.Y*delta.Y+delta.Z*delta.Z
                        if distance<=best then best=distance;target=a.root end
                    end
                end
            end
        end
        return target
    end
    local function cancel(kind)
        if kind=="dash" and N.ReleaseDashInput then N.ReleaseDashInput() end
        pending[kind]=nil;status(kind,"Desativado")
    end
    local function available(kind,serverNow,attribute)
        local request=pending[kind]
        if request then
            if os.clock()-request.started<5 then status(kind,"Aguardando resposta do jogo");return false end
            pending[kind]=nil;local row=status(kind,"Resposta nao observada");row.timeouts=row.timeouts+1
        end
        local delay=kind=="attack" and cfg.attackDelay or kind=="gear" and cfg.gearDelay or 1.1
        if os.clock()-(lastAttempt[kind] or -math.huge)<delay then return false end
        local untilTime=readyAt[kind] or 0
        if attribute then local value=player:GetAttribute(attribute);if finite(value) then untilTime=math.max(untilTime,value) end end
        if serverNow<untilTime then status(kind,"Aguardando disponibilidade do jogo");return false end
        return true
    end
    local function send(kind,r,id,...)
        if (kind=="ability" and not cfg.autoAbility) or (kind=="gear" and not cfg.autoGears) then return false end
        local now=os.clock();lastAttempt[kind]=now
        for key,entry in pairs(recent) do if now-entry.at>10 then recent[key]=nil end end
        if id then pending[kind]={id=id,started=now};recent[id]={kind=kind,at=now} end
        local row=status(kind,"Comando enviado; aguardando o jogo")
        local ok=pcall(function(...) r:FireServer(...) end,...)
        if not ok then pending[kind]=nil;row.failed=row.failed+1;status(kind,"Nao foi possivel enviar o comando");return false end
        row.sent=row.sent+1
        return true
    end
    local function acknowledge(kind,id,accepted,data)
        local request=pending[kind]
        if not request or request.id~=id or type(accepted)~="boolean" then return end
        pending[kind]=nil
        if type(data)=="table" then
            if finite(data.readyAt) then readyAt[kind]=math.max(readyAt[kind] or 0,data.readyAt) end
            if type(data.canonicalId)=="string" then recent[data.canonicalId]={kind=kind,at=os.clock()} end
        end
        local row=status(kind,accepted and "Pedido aceito pelo jogo" or "Pedido recusado pelo jogo")
        row[accepted and "accepted" or "rejected"]=row[accepted and "accepted" or "rejected"]+1
        if not accepted then local now=clock();if now then readyAt[kind]=math.max(readyAt[kind] or 0,now+2) end end
    end
    local function bind(kind,callback)
        local r=remote(kind)
        if r and not bound[r] then bound[r]=true;listen(r.OnClientEvent,callback) end
    end
    function N.HasMelee() return remote("melee")~=nil end
    function N.AttackNearest(radius)
        local _,_,root,role=active("attack","Catcher");if not root then return false end
        local r,now=remote("melee"),clock();if not r or not now or not available("attack",now) then return false end
        local target=opponent(root,radius or cfg.attackRange,role);if not target then status("attack","Nenhum runner ativo no alcance");return false end
        local direction=flatUnit(target.Position-root.Position) or flatUnit(root.CFrame.LookVector);if not direction then return false end
        local id=Http:GenerateGUID(false)
        return send("attack",r,id,{id=id,direction=direction,at=now,position=root.Position})
    end
    local function readyTackle()
        local _,_,root,role=active("tackle","Catcher");if not root then return end
        local r,now=remote("tackle"),clock();if not r or not now or not available("tackle",now,"TackleReadyAt") then return end
        local target=opponent(root,cfg.tackleRange,role);if not target then status("tackle","Nenhum runner ativo no alcance");return end
        return root,r,now,target
    end
    function N.Tackle()
        local root,r,now,target=readyTackle();if not root then return false end
        local direction=flatUnit(target.Position-root.Position) or flatUnit(root.CFrame.LookVector);if not direction then return false end
        local velocity=root.AssemblyLinearVelocity;local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
        if not finite(speed) then return false end
        local id=Http:GenerateGUID(false)
        return send("tackle",r,id,"Tackle",{id=id,at=now,direction=direction,position=root.Position,speed=speed})
    end
    local abilityAttributes={"GhostAbilityReadyAt","CloneAbilityReadyAt","TruckAbilityReadyAt"}
    local function readyAbility()
        local _,_,root,role=active("ability");if not root then return end
        local r,now=remote("ability"),clock();if not r or not now or not available("ability",now,"AbilityReadyAt") then return end
        for _,attribute in ipairs(abilityAttributes) do
            local value=player:GetAttribute(attribute);if finite(value) and value>now then status("ability","Aguardando disponibilidade do jogo");return end
        end
        local target=opponent(root,cfg.abilityRange,role);if not target then status("ability","Nenhum oponente ativo por perto");return end
        return root,r,now,target
    end
    function N.UseAbility()
        if not cfg.autoAbility then return false end
        local root,r,now,target=readyAbility();if not root then return false end
        local direction=flatUnit(target.Position-root.Position) or flatUnit(root.CFrame.LookVector);if not direction then return false end
        local id=Http:GenerateGUID(false)
        return send("ability",r,id,"UseAbility",nil,direction,id,nil,nil)
    end
    function N.UseGear()
        if not state.alive or not cfg.autoGears then return false end
        local char,hum,root=character();if not char or not hum or not root or hum.Health<=0 then return false end
        local r,now=remote("gear"),clock();if not r or not now or not available("gear",now,"GearReadyAt") then return false end
        -- The user's trace distinguishes Use (gear) from UseAbility; never activate an arbitrary Tool here.
        local id=Http:GenerateGUID(false)
        return send("gear",r,id,"Use",nil,nil,id,nil,nil)
    end
    local dashInput={buttons={},scanAt=-math.huge,retryAt=0,heldKey=nil,manager=nil,observation=nil}
    function N.ReleaseDashInput()
        if dashInput.heldKey and dashInput.manager then
            pcall(function() dashInput.manager:SendKeyEvent(false,dashInput.heldKey,false,game) end)
        end
        dashInput.heldKey=nil;dashInput.keyToken=nil;dashInput.observation=nil
    end
    local function visibleButton(object,playerGui)
        if not object.Parent or object:IsDescendantOf(gui) or not object:IsDescendantOf(playerGui) then return false end
        local parent=object
        while parent and parent~=playerGui do
            if parent:IsA("GuiObject") and not parent.Visible then return false end
            if parent:IsA("ScreenGui") and not parent.Enabled then return false end
            parent=parent.Parent
        end
        return true
    end
    local function findDashButtons()
        local playerGui=player:FindFirstChildOfClass("PlayerGui");if not playerGui then return nil end
        if os.clock()-dashInput.scanAt>=3 then
            dashInput.scanAt=os.clock();dashInput.buttons={}
            for _,object in ipairs(playerGui:GetDescendants()) do
                if (object:IsA("TextButton") or object:IsA("ImageButton")) and not object:IsDescendantOf(gui) then
                    local name=string.lower(object.Name)
                    local match=name=="dash" or name=="dashbutton" or name=="dashbtn" or name=="touchdash" or name=="dashaction"
                    if object:IsA("TextButton") and string.lower(object.Text):match("^%s*dash%s*$") then match=true end
                    if not match then
                        for _,child in ipairs(object:GetChildren()) do
                            if child:IsA("TextLabel") and string.lower(child.Text):match("^%s*dash%s*$") then match=true;break end
                        end
                    end
                    if match and #dashInput.buttons<12 then dashInput.buttons[#dashInput.buttons+1]=object end
                end
            end
        end
        return playerGui
    end
    local function activateDashButton(isActive)
        local playerGui=findDashButtons();if not playerGui then return false end
        for _,object in ipairs(dashInput.buttons) do
            if not isActive() then return false,nil,true end
            if visibleButton(object,playerGui) then
                for _,event in ipairs({"Activated","MouseButton1Click"}) do
                    local signal=object[event];local ok,list=false,nil
                    if type(getconnections)=="function" then ok,list=pcall(getconnections,signal) end
                    if ok and type(list)=="table" then
                        local callbacks={}
                        for _,connection in ipairs(list) do
                            local good,callback=pcall(function()
                                if connection.Enabled~=false and connection.Connected~=false then return connection.Function end
                            end)
                            if good and type(callback)=="function" then callbacks[#callbacks+1]=callback end
                        end
                        if #callbacks>0 then
                            for _,callback in ipairs(callbacks) do
                                if not isActive() then return false,nil,true end
                                if not pcall(callback,nil,1) then return false,"Falha no botao de dash; sem tentar outra entrada",true end
                            end
                            return true,"Botao do jogo",true
                        end
                    elseif type(firesignal)=="function" then
                        if not isActive() then return false,nil,true end
                        if pcall(firesignal,signal,nil,1) then return true,"Sinal do botao",true end
                        return false,"Falha no sinal de dash; sem tentar outra entrada",true
                    end
                end
            end
        end
        return false
    end
    local function keyboardFallbackAllowed()
        if not cfg.dashKeyboardFallback or Input.TouchEnabled then return false end
        local ok,preferred=pcall(function() return Input.PreferredInput end)
        if ok and preferred~=nil and preferred~=Enum.PreferredInput.KeyboardAndMouse then return false end
        return true
    end
    local function pressDashKey()
        if not keyboardFallbackAllowed() then return false end
        local key=Enum.KeyCode[cfg.dashKey]
        if Input:IsKeyDown(key) then return false end
        local ok,manager=pcall(function() return game:GetService("VirtualInputManager") end)
        if not ok or not manager then return false end
        dashInput.manager=manager
        local sent=pcall(function() manager:SendKeyEvent(true,key,false,game) end)
        if not sent then pcall(function() manager:SendKeyEvent(false,key,false,game) end);return false end
        dashInput.heldKey=key
        local token={};dashInput.keyToken=token
        task.delay(0.06,function()
            if dashInput.heldKey==key and dashInput.keyToken==token then
                pcall(function() manager:SendKeyEvent(false,key,false,game) end);dashInput.heldKey=nil;dashInput.keyToken=nil
            end
        end)
        return true,"Tecla "..cfg.dashKey
    end
    local function readyDash(test)
        if not state.alive or game.GameId~=10764627709 then return end
        local char,hum,root,role
        if test==true then
            char,hum,root=character()
            if not char or not hum or not root or hum.Health<=0 then return end
        else
            char,hum,root,role=active("dash");if not char then return end
        end
        if Input:GetFocusedTextBox() then status("dash","Aguardando fechar o campo de texto");return end
        if char:GetAttribute("DashReady")==false then status("dash","Aguardando dash disponivel");return end
        if os.clock()-(lastAttempt.dash or -math.huge)<cfg.dashDelay then status("dash","Aguardando delay configurado");return end
        if test~=true and not opponent(root,cfg.dashRange,role) then status("dash","Nenhum oponente no alcance");return end
        if os.clock()<dashInput.retryAt then return end
        if not keyboardFallbackAllowed() then
            local playerGui=findDashButtons();local found=false
            if playerGui then for _,button in ipairs(dashInput.buttons) do if visibleButton(button,playerGui) then found=true;break end end end
            if not found then status("dash",Input.TouchEnabled and "Botao de dash indisponivel; teclas bloqueadas no toque" or "Botao de dash indisponivel; fallback por tecla desligado");return end
        end
        return char
    end
    function N.Dash(test,stillEnabled)
        local char=readyDash(test);if not char then return false end
        local before=char:GetAttribute("DashCount")
        local function isActive() return state.alive and player.Character==char and (test==true or cfg.autoDash) and (not stillEnabled or stillEnabled()) end
        local fired,source,attempted=activateDashButton(isActive)
        if not fired and not attempted and isActive() then fired,source=pressDashKey() end
        if not fired then
            dashInput.retryAt=os.clock()+0.5
            if isActive() then status("dash",source or "Entrada indisponivel; nenhuma tecla automatica foi enviada") end
            return false
        end
        if not isActive() then return false end
        lastAttempt.dash=os.clock()
        local row=status("dash",source.." acionado; verificando dash")
        row.sent=row.sent+1;row.source=source
        local observation={};dashInput.observation=observation
        local function confirm()
            if not state.alive or dashInput.observation~=observation or player.Character~=char then return end
            dashInput.observation=nil
            local after=char:GetAttribute("DashCount")
            if finite(before) and finite(after) and after>before then
                row.confirmed=(row.confirmed or 0)+1;status("dash","DashCount mudou apos "..source)
            else
                row.unconfirmed=(row.unconfirmed or 0)+1;status("dash","Entrada acionada; dash nao confirmado")
            end
        end
        if finite(before) and finite(char:GetAttribute("DashCount")) and char:GetAttribute("DashCount")>before then confirm() else task.delay(0.8,confirm) end
        return true
    end
    -- Auto Zone: the trace confirms this root position on side B, not a remote command.
    do
        local zone={generation=0,saved=nil,recorded=Vector3.new(105.64381408691406,22.99999237060547,126.02445220947266)}
        function zone.mapRoot(object)
            local top
            while object and object~=workspace do
                local name=string.lower(object.Name)
                if name:match("^map%d+$") or (object.Parent and string.lower(object.Parent.Name)=="maps") then return object end
                top=object;object=object.Parent
            end
            if top and (top:IsA("Model") or top:IsA("Folder")) and not top:FindFirstChild("Humanoid") then return top end
        end
        function zone.resolveMap(value)
            if typeof(value)=="Instance" and value:IsDescendantOf(workspace) then return value end
            if type(value)~="string" then return end
            local object=workspace
            for segment in value:gmatch("[^%./]+") do
                if string.lower(segment)~="workspace" then object=object and object:FindFirstChild(segment) end
            end
            if object and object~=workspace then return object end
        end
        function zone.activeMap()
            local gameFolder=Replicated:FindFirstChild("ChickenOrHero")
            local owners={workspace}
            if gameFolder then owners[#owners+1]=gameFolder;local f=gameFolder:FindFirstChild("Game");if f then owners[#owners+1]=f end end
            for _,owner in ipairs(owners) do
                for _,key in ipairs({"ActiveMap","CurrentMap"}) do
                    local map=zone.resolveMap(owner:GetAttribute(key));if map then return map end
                    local ref=owner:FindFirstChild(key)
                    if ref and ref:IsA("ObjectValue") then map=zone.resolveMap(ref.Value);if map then return map end end
                end
            end
        end
        function zone.standingMap(char,root)
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={char,visuals}
            local hit=workspace:Raycast(root.Position,Vector3.new(0,-40,0),params)
            return hit and zone.mapRoot(hit.Instance)
        end
        function zone.safeAnchor(part)
            local object=part
            while object and object~=workspace do
                local name=string.lower(object.Name):gsub("[^%w]","")
                if name:match("^safe") then return object end
                object=object.Parent
            end
        end
        function zone.sideOf(object)
            while object and object~=workspace do
                local side=object:GetAttribute("SafeSide") or object:GetAttribute("Side")
                if side=="A" or side=="B" then return side end
                local name=string.lower(object.Name):gsub("[^%w]","")
                if name=="a" or name=="safea" or name=="safezonea" then return "A" end
                if name=="b" or name=="safeb" or name=="safezoneb" then return "B" end
                object=object.Parent
            end
        end
        function zone.contains(part,point)
            local p=part.CFrame:PointToObjectSpace(point);local size=part.Size
            return math.abs(p.X)<=size.X/2+0.25 and math.abs(p.Z)<=size.Z/2+0.25 and math.abs(p.Y)<=size.Y/2+6
        end
        function zone.destination(char,root)
            local current=zone.activeMap() or zone.standingMap(char,root)
            local saved=zone.saved
            if saved and saved.map.Parent and current==saved.map then return saved end
            local target
            -- Only scan on activation. Coordinates alone do not identify a map.
            for _,object in ipairs(workspace:GetDescendants()) do
                if object:IsA("BasePart") and not object:IsDescendantOf(visuals) then
                    local anchor=zone.safeAnchor(object)
                    if anchor and zone.sideOf(object)~="A" and zone.contains(object,zone.recorded) then
                        local map=zone.mapRoot(anchor)
                        if map and (not current or map==current or object:IsDescendantOf(current)) then
                            if target and target.map~=map then return nil,"Zona B ambigua: marque a zona deste mapa" end
                            target={position=zone.recorded,side="B",map=map,anchor=anchor}
                        end
                    end
                end
            end
            return target,"Zona B nao identificada neste mapa. Entre na zona e use Marcar zona aqui"
        end
        function N.CancelZone()
            zone.generation=zone.generation+1;status("zone","Desativado")
        end
        function N.CaptureZone()
            if not state.alive or game.GameId~=10764627709 then return false end
            local char,hum,root=character();local side=player:GetAttribute("SafeSide")
            if not root or not hum or hum.Health<=0 or player:GetAttribute("RunState")~="Safe" or (side~="A" and side~="B") then
                notify("Entre na zona segura antes de marcar o destino.");return false
            end
            local map=zone.activeMap() or zone.standingMap(char,root)
            if not map or map==char or map==visuals or not map.Parent then
                notify("Nao foi possivel identificar o mapa sob a zona.");return false
            end
            zone.saved={position=root.Position,side=side,map=map}
            status("zone","Zona "..side.." marcada neste mapa")
            notify("Zona "..side.." marcada. Desligue e ligue Auto Zone para fazer o TP.")
            return true
        end
        function N.TeleportZone()
            if not state.alive or game.GameId~=10764627709 then return false,"Auto Zone disponivel apenas no Huss Valley" end
            local char,hum,root=character();local run=player:GetAttribute("RunState")
            if not char or not hum or not root or hum.Health<=0 or player:GetAttribute("GameRole")~="Runner" or (run~="Active" and run~="Safe") then
                return false,"Auto Zone aguarda um runner vivo na rodada"
            end
            local target,reason=zone.destination(char,root)
            if not target then status("zone",reason);return false,reason end
            zone.generation=zone.generation+1;local generation=zone.generation
            local ok=pcall(function()
                -- Preserve the model's pivot offset and current orientation.
                char:PivotTo(char:GetPivot()+(target.position-root.Position))
                root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
            end)
            if not ok then return false,"Nao foi possivel aplicar o TP para a zona" end
            local row=status("zone","TP para zona "..target.side.." aplicado; verificando")
            row.sent=row.sent+1
            task.delay(0.8,function()
                if not state.alive or not cfg.autoZone or zone.generation~=generation or player.Character~=char then return end
                if not root.Parent or not target.map.Parent then status("zone","Personagem ou mapa mudou apos o TP");return end
                if (root.Position-target.position).Magnitude>12 then
                    row.rejected=row.rejected+1;status("zone","O jogo corrigiu a posicao apos o TP")
                elseif player:GetAttribute("RunState")=="Safe" and player:GetAttribute("SafeSide")==target.side then
                    row.confirmed=(row.confirmed or 0)+1;status("zone","Zona "..target.side.." confirmada no estado do jogo")
                else
                    row.unconfirmed=(row.unconfirmed or 0)+1;status("zone","TP aplicado; entrada na zona ainda nao confirmada")
                end
            end)
            return true
        end
        function N.AutoZone(ctx)
            if not ctx.Enabled then N.CancelZone();return end
            if ctx.IsActive and not ctx.IsActive() then return end
            local ok,reason=N.TeleportZone()
            if not ok then
                local generation=zone.generation
                task.defer(function()
                    if state.alive and cfg.autoZone and zone.generation==generation then
                        set("autoZone",false,true);status("zone",reason);notify(reason)
                    end
                end)
            end
        end
    end
    -- End Auto Zone.
    local function perform(ctx,kind,fn)
        if ctx.Enabled then
            if not ctx.IsActive or ctx.IsActive() then
                if kind=="dash" then fn(nil,ctx.IsActive) else fn() end
            end
        else cancel(kind) end
    end
    local function installProximity(name,kind,fn,ready)
        if remote(kind) and type(adapters[name])~="function" then
            local callback=function(ctx) perform(ctx,kind,fn) end
            adapters[name]=callback;N.ProximityAdapters[name]=callback;N.ProximityReady[name]=ready
        end
    end
    local function install()
        if type(adapters.AutoZone)~="function" then adapters.AutoZone=N.AutoZone end
        N.Mapped.zone=type(adapters.AutoZone)=="function"
        installProximity("AutoDash","dash",N.Dash,readyDash)
        installProximity("AutoTackle","tackle",N.Tackle,readyTackle)
        installProximity("AutoAbility","ability",N.UseAbility,readyAbility)
        N.Mapped.attack=remote("melee")~=nil;N.Mapped.dash=remote("dash")~=nil;N.Mapped.tackle=remote("tackle")~=nil;N.Mapped.ability=remote("ability")~=nil;N.Mapped.gear=remote("gear")~=nil
        bind("melee",function(id,accepted,data) acknowledge("attack",id,accepted,data) end)
        bind("tackle",function(action,id,accepted,data) if action=="TackleResult" then acknowledge("tackle",id,accepted,data) end end)
        bind("ability",function(action,data)
            if action=="PredictionResult" and type(data)=="table" then
                acknowledge("ability",data.requestId,data.accepted,data)
                acknowledge("gear",data.requestId,data.accepted,data)
            end
        end)
        bind("replay",function(action,data)
            if action~="Verdict" or type(data)~="table" or data.source~="Server" then return end
            local request=recent[data.id];if not request or os.clock()-request.at>10 then return end
            local row=status(request.kind,data.accepted and "Acerto confirmado pelo servidor" or "Acerto recusado: "..tostring(data.reason))
            row.lastVerdict={accepted=data.accepted,reason=data.reason,source=data.source}
        end)
    end
    actions.autoAttack=function(value) if not value then cancel("attack") end end
    actions.autoGears=function(value) if not value then cancel("gear") end end
    actions.dashKeyboardFallback=N.ReleaseDashInput
    actions.dashKey=N.ReleaseDashInput
    if game.GameId==10764627709 then
        install()
        listen(player.CharacterAdded,function()
            pending={};recent={};N.ReleaseDashInput();dashInput.scanAt=-math.huge;dashInput.retryAt=0
            if cfg.autoZone then set("autoZone",false,true) else N.CancelZone() end
        end)
        listen(Replicated.DescendantAdded,function(object)
            if object:IsA("RemoteEvent") and (object.Name=="MeleeEvent" or object.Name=="GameAction" or object.Name=="GearEvent" or object.Name=="BoostRequest" or object.Name=="HitReplayEvent") then install() end
        end)
        listen(player.DescendantAdded,function(object)
            if (object:IsA("GuiButton") or object:IsA("PlayerGui")) and not object:IsDescendantOf(gui) then
                dashInput.scanAt=-math.huge;dashInput.retryAt=0
            end
        end)
    end
end
listen(player.Idled,function()
    if not cfg.antiIdle then return end
    if Input.TouchEnabled then
        set("antiIdle",false,true);notify("Anti-Idle por mouse desativado no toque para preservar os controles moveis.");return
    end
    local ok=pcall(function()
        local vu=game:GetService("VirtualUser");vu:CaptureController();vu:ClickButton2(Vector2.new(0,0))
    end)
    if not ok then set("antiIdle",false);notify("Anti-Idle indisponivel nesta versao do executor.") end
end)
function API.Rejoin()
    if game.JobId~="" then Teleport:TeleportToPlaceInstance(game.PlaceId,game.JobId,player) else Teleport:Teleport(game.PlaceId,player) end
end

-- ESP objects are created per player and reused. Nothing is drawn while disabled.
do
    local geometry={}
    API.ESPGeometry=geometry
    local bodyNames={Head=true,Torso=true,["Left Arm"]=true,["Right Arm"]=true,["Left Leg"]=true,["Right Leg"]=true,
        UpperTorso=true,LowerTorso=true,LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,
        RightUpperArm=true,RightLowerArm=true,RightHand=true,LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,
        RightUpperLeg=true,RightLowerLeg=true,RightFoot=true}
    function geometry.BodyBounds(record,char,root,refresh)
        -- Only R6/R15 body parts: tools, accessories, effects and auxiliary hitboxes do not size the box.
        if refresh or record.bodyCharacter~=char then
            record.bodyParts={};record.bodyCharacter=char
            for _,part in ipairs(char:GetChildren()) do
                if bodyNames[part.Name] and part:IsA("BasePart") then record.bodyParts[#record.bodyParts+1]=part end
            end
        end
        local rootCF=root.CFrame
        local inverse=rootCF:Inverse()
        local minX,minY,minZ,maxX,maxY,maxZ=math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge
        local count=0
        for _,part in ipairs(record.bodyParts) do
            if part.Parent==char then
                local relative=inverse*part.CFrame
                local pos,size=relative.Position,part.Size
                local halfX,halfY,halfZ=size.X*0.5,size.Y*0.5,size.Z*0.5
                local right,up,look=relative.RightVector,relative.UpVector,relative.LookVector
                local x=math.abs(right.X)*halfX+math.abs(up.X)*halfY+math.abs(look.X)*halfZ
                local y=math.abs(right.Y)*halfX+math.abs(up.Y)*halfY+math.abs(look.Y)*halfZ
                local z=math.abs(right.Z)*halfX+math.abs(up.Z)*halfY+math.abs(look.Z)*halfZ
                minX=math.min(minX,pos.X-x);minY=math.min(minY,pos.Y-y);minZ=math.min(minZ,pos.Z-z)
                maxX=math.max(maxX,pos.X+x);maxY=math.max(maxY,pos.Y+y);maxZ=math.max(maxZ,pos.Z+z);count=count+1
            end
        end
        if count==0 then return rootCF,root.Size end
        return rootCF*CFrame.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2),Vector3.new(maxX-minX,maxY-minY,maxZ-minZ)
    end
    function geometry.ProjectBounds(cam,cf,size)
        local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
        local near=math.max(0.05,math.abs(cam.NearPlaneZ))
        for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
            local v=cam:WorldToViewportPoint(cf*Vector3.new(size.X*x/2,size.Y*y/2,size.Z*z/2))
            -- A corner behind/inside the near plane can project to an arbitrarily large rectangle.
            if v.Z<=near or v.X~=v.X or v.Y~=v.Y then return end
            minX=math.min(minX,v.X);minY=math.min(minY,v.Y);maxX=math.max(maxX,v.X);maxY=math.max(maxY,v.Y)
        end end end
        local width,height=cam.ViewportSize.X,cam.ViewportSize.Y
        minX=math.clamp(minX,0,width);minY=math.clamp(minY,0,height)
        maxX=math.clamp(maxX,0,width);maxY=math.clamp(maxY,0,height)
        if maxX>minX and maxY>minY then return minX,minY,maxX-minX,maxY-minY end
    end
end
local espRecords={}
local function clearRecord(p)
    local r=espRecords[p]
    if r then r.frame:Destroy();r.highlight:Destroy();espRecords[p]=nil end
end
local function recordFor(p)
    local r=espRecords[p];if r then return r end
    local f=create("Frame",{Name="PlayerESP",BackgroundTransparency=1,Size=UDim2.new(),Visible=false},overlay)
    local box=create("Frame",{Name="Box",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},f)
    local stroke=create("UIStroke",{Color=accent,Thickness=1,Transparency=0.1},box)
    local name=text(f,"",10,{Name="Name",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.fromScale(0.5,0),Size=UDim2.fromOffset(190,16),TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0.3},true)
    local team=text(f,"",10,{Name="Team",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0,-17),
        Size=UDim2.fromOffset(230,17),TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.GothamBold,
        TextStrokeTransparency=0.15,Visible=false},true)
    local hp=create("Frame",{Name="Health",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(0,-4,1,0),Size=UDim2.new(0,2,1,0),BackgroundColor3=Color3.fromRGB(112,226,151),BorderSizePixel=0},f)
    local detail=text(f,"",9,{Name="Distance",Position=UDim2.new(0,-30,1,2),Size=UDim2.new(1,60,0,15),TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0.3},true)
    local tracer=line(f,0,0,0,0,accent,1)
    local view=line(f,0,0,0,0,accent,1)
    local dot=create("Frame",{Name="HeadDot",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundColor3=accent,BorderSizePixel=0},f);round(dot,6)
    local highlight=create("Highlight",{Name="HVChams",Enabled=false,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
        FillTransparency=0.7,OutlineTransparency=0.1,FillColor=accent,OutlineColor=accent},visuals)
    r={frame=f,box=box,stroke=stroke,name=name,team=team,hp=hp,detail=detail,tracer=tracer,view=view,dot=dot,highlight=highlight,joints={},bones={}}
    espRecords[p]=r;return r
end
local espLineCache=setmetatable({},{__mode="k"})
local function moveLine(object,x1,y1,x2,y2)
    local cached=espLineCache[object]
    if cached and cached[1]==x1 and cached[2]==y1 and cached[3]==x2 and cached[4]==y2 then return end
    cached=cached or {};espLineCache[object]=cached
    cached[1]=x1;cached[2]=y1;cached[3]=x2;cached[4]=y2
    local dx,dy=x2-x1,y2-y1;object.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2)
    object.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),1);object.Rotation=math.deg(math.atan2(dy,dx))
end
local function writeChanged(object,property,value) if object[property]~=value then object[property]=value end end
local function setESPBounds(r,x,y,w,h)
    if r.x~=x or r.y~=y then r.x=x;r.y=y;r.frame.Position=UDim2.fromOffset(x,y) end
    if r.width~=w or r.height~=h then r.width=w;r.height=h;r.frame.Size=UDim2.fromOffset(w,h) end
end
local function projectESPPart(r,cam,part)
    local cached=r.projected[part]
    if not cached then cached={};r.projected[part]=cached end
    if cached.frame~=r.projectionFrame then cached.frame=r.projectionFrame;cached.point=cam:WorldToViewportPoint(part.Position) end
    return cached.point
end
local updateESP
local function renderESP(dt)
    if not (cfg.esp or cfg.espTeams or cfg.chams or cfg.viewTracer) then return end
    state.espClock=(state.espClock or 0)+dt
    updateESP(false)
end
updateESP=function(forceData)
    local cam=workspace.CurrentCamera;local _,_,localRoot=character()
    if not cam or not localRoot then for p in pairs(espRecords) do clearRecord(p) end;return end
    if not (cfg.esp or cfg.espTeams or cfg.chams or cfg.viewTracer) then for p in pairs(espRecords) do clearRecord(p) end;return end
    local draw2D=cfg.esp or cfg.espTeams or cfg.viewTracer
    local geometry=cfg.esp and not cfg.espTeams
    local origin,rangeSquared,now=localRoot.Position,cfg.espRange*cfg.espRange,state.espClock or 0
    local near=math.abs(cam.NearPlaneZ)
    for _,p in ipairs(roster) do
        if p~=player then
            local a=actor(p);local ch,h,root=a.char,a.hum,a.root
            local distanceSquared=math.huge
            if root then local delta=root.Position-origin;distanceSquared=delta.X*delta.X+delta.Y*delta.Y+delta.Z*delta.Z end
            local eligible=root and h and h.Health>0 and distanceSquared<=rangeSquared and not(cfg.teamFilter and sameTeam(p))
            if not eligible then clearRecord(p)
            else
                local r=recordFor(p)
                local dataDue=forceData or r.dataCharacter~=ch or not r.nextData or now>=r.nextData
                if dataDue then
                    r.color=cfg.roleColors and API.Native.ESPColor(p) or accent
                    r.teamName,r.teamColor=API.Native.ESPTeam(p)
                    if cfg.espTeams then r.color=r.teamColor end
                    r.dataCharacter=ch;r.nextData=now+1/cfg.espRate
                    local color=r.color or accent
                    writeChanged(r.highlight,"Enabled",cfg.chams);writeChanged(r.highlight,"Adornee",ch)
                    writeChanged(r.highlight,"FillColor",color);writeChanged(r.highlight,"OutlineColor",color)
                    if draw2D then
                        writeChanged(r.box,"Visible",geometry and cfg.boxes);writeChanged(r.stroke,"Color",color)
                        writeChanged(r.name,"Visible",cfg.espTeams or cfg.esp and cfg.names)
                        writeChanged(r.name,"TextColor3",cfg.espTeams and color or colors.text)
                        writeChanged(r.team,"Visible",cfg.espTeams);writeChanged(r.team,"TextColor3",r.teamColor or color)
                        writeChanged(r.detail,"Visible",geometry and (cfg.distance or cfg.healthText))
                        if r.name.Visible then writeChanged(r.name,"Text",p.DisplayName) end
                        if cfg.espTeams then writeChanged(r.team,"Text",r.teamName or "Sem time") end
                        if r.detail.Visible then
                            writeChanged(r.detail,"Text",(cfg.distance and string.format("%d studs",math.floor(math.sqrt(distanceSquared))) or "")..(cfg.healthText and string.format("  %d HP",math.floor(h.Health)) or ""))
                        end
                        writeChanged(r.hp,"Visible",geometry and cfg.health)
                        writeChanged(r.tracer,"Visible",geometry and cfg.tracers);writeChanged(r.tracer,"BackgroundColor3",color)
                        writeChanged(r.view,"BackgroundColor3",color);writeChanged(r.dot,"BackgroundColor3",color)
                    end
                end
                if not draw2D then writeChanged(r.frame,"Visible",false)
                else
                    local center,on=cam:WorldToViewportPoint(root.Position)
                    local minX,minY,width,height
                    if on then
                        local cf,size=API.ESPGeometry.BodyBounds(r,ch,root,dataDue)
                        minX,minY,width,height=API.ESPGeometry.ProjectBounds(cam,cf,size)
                    end
                    writeChanged(r.frame,"Visible",minX~=nil)
                    if minX then
                        setESPBounds(r,minX,minY,width,height)
                        if r.projectedCharacter~=ch then r.projectedCharacter=ch;r.projected={} end
                        r.projectionFrame=(r.projectionFrame or 0)+1
                        local rootProjection=r.projected[root]
                        if not rootProjection then rootProjection={};r.projected[root]=rootProjection end
                        rootProjection.frame=r.projectionFrame;rootProjection.point=center
                        if r.hp.Visible then
                            local healthRatio=math.clamp(h.Health/math.max(1,h.MaxHealth),0,1)
                            if r.healthRatio~=healthRatio then r.healthRatio=healthRatio;r.hp.Size=UDim2.new(0,2,healthRatio,0) end
                        end
                        local color=r.color or accent
                        if r.tracer.Visible then moveLine(r.tracer,cam.ViewportSize.X/2-minX,cam.ViewportSize.Y-minY,center.X-minX,height) end
                        local start,finish
                        if cfg.viewTracer or (geometry and cfg.headDot) then
                            if not a.head or not a.head.Parent then a.head=ch:FindFirstChild("Head") end
                            local head=a.head or root;start=projectESPPart(r,cam,head)
                            if cfg.viewTracer then finish=cam:WorldToViewportPoint(head.Position+head.CFrame.LookVector*5) end
                        end
                        writeChanged(r.view,"Visible",cfg.viewTracer and start.Z>near and finish.Z>near)
                        if r.view.Visible then moveLine(r.view,start.X-minX,start.Y-minY,finish.X-minX,finish.Y-minY) end
                        writeChanged(r.dot,"Visible",geometry and cfg.headDot and start.Z>near)
                        if r.dot.Visible then
                            if r.dotX~=start.X-minX or r.dotY~=start.Y-minY then
                                r.dotX=start.X-minX;r.dotY=start.Y-minY;r.dot.Position=UDim2.fromOffset(r.dotX,r.dotY)
                            end
                        end
                        if cfg.skeleton and geometry then
                            local boneColorChanged=r.boneColor~=color;r.boneColor=color
                            if r.character~=ch then
                                for _,b in ipairs(r.bones) do b:Destroy() end;r.joints={};r.bones={};r.character=ch
                                for _,joint in ipairs(ch:GetDescendants()) do
                                    if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 and joint.Part0.Parent==ch and joint.Part1.Parent==ch then
                                        r.joints[#r.joints+1]=joint;r.bones[#r.bones+1]=line(r.frame,0,0,0,0,color,1)
                                    end
                                end
                            end
                            for i,joint in ipairs(r.joints) do
                                local b=r.bones[i];local visible=false
                                if joint.Part0 and joint.Part1 then
                                    local first=projectESPPart(r,cam,joint.Part0);local last=projectESPPart(r,cam,joint.Part1)
                                    visible=first.Z>near and last.Z>near
                                    if visible then moveLine(b,first.X-minX,first.Y-minY,last.X-minX,last.Y-minY) end
                                end
                                writeChanged(b,"Visible",visible)
                                if boneColorChanged then writeChanged(b,"BackgroundColor3",color) end
                            end
                        else for _,b in ipairs(r.bones) do writeChanged(b,"Visible",false) end end
                    end
                end
            end
        end
    end
end
listen(Players.PlayerRemoving,clearRecord)
for _,key in ipairs({"esp","espTeams","chams","viewTracer","boxes","names","distance","health","healthText","tracers","headDot","skeleton","roleColors","teamFilter","espRange","espRate","smoothESP"}) do
    actions[key]=function() updateESP(true) end
end
local previewCharacter
refreshPreview=function()
    if not state.alive or state.page~="ESP" then return end
    local char=player.Character;if not char then previewNote.Text="Avatar carregando...";return end
    if previewCharacter==char and #previewWorld:GetChildren()>0 then return end
    previewWorld:ClearAllChildren();previewCharacter=nil
    local old=char.Archivable;char.Archivable=true
    local ok,clone=pcall(function() return char:Clone() end);char.Archivable=old
    if not ok or not clone then previewNote.Text="Preview indisponivel";return end
    for _,o in ipairs(clone:GetDescendants()) do if o:IsA("LuaSourceContainer") or o:IsA("Tool") then o:Destroy()
        elseif o:IsA("BasePart") then o.Anchored=true end end
    clone.Parent=previewWorld
    previewCharacter=char
    local cf,size=clone:GetBoundingBox();local distance=math.max(size.X,size.Y,size.Z)*1.9
    previewCam.CFrame=CFrame.lookAt(cf.Position+Vector3.new(0,size.Y*0.05,-distance),cf.Position)
    previewNote.Text=player.DisplayName.." / preview local"
end

-- Emotes are read from the avatar instead of downloading a cosmetics catalog.
local emoteTracks={}
function API.StopEmote() for _,track in ipairs(emoteTracks) do pcall(function() track:Stop(0.15) end) end;emoteTracks={} end
function API.RefreshEmotes()
    for _,o in ipairs(emoteList:GetChildren()) do if o:IsA("GuiObject") then o:Destroy() end end
    local _,hum=character();if not hum then text(emoteList,"Entre no jogo para carregar os emotes.",10);return end
    local ok,list=pcall(function() return hum:GetAppliedDescription():GetEmotes() end)
    if not ok or not next(list) then text(emoteList,"Nenhum emote equipado encontrado.",10);return end
    local names={};for name in pairs(list) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do actionButton(emoteList,name,function()
        API.StopEmote();local _,h=character();if not h then return end
        local animator=h:FindFirstChildOfClass("Animator");local before={}
        if animator then for _,t in ipairs(animator:GetPlayingAnimationTracks()) do before[t]=true end end
        local success,result=pcall(function() return h:PlayEmote(name) end)
        if not success or not result then notify("Este emote nao pode tocar neste personagem.");return end
        task.delay(0.2,function() if not state.alive then return end
            if animator then for _,t in ipairs(animator:GetPlayingAnimationTracks()) do if not before[t] then emoteTracks[#emoteTracks+1]=t end end end
        end)
    end) end
end

-- Named profiles have a persistent index, legacy-file discovery and a separate selected row.
local loadRecord
do
    env.HussValleyConfigSession=type(env.HussValleyConfigSession)=="table" and env.HussValleyConfigSession or {}
    local session=env.HussValleyConfigSession
    env.HussValleyConfigVolatile=type(env.HussValleyConfigVolatile)=="table" and env.HussValleyConfigVolatile or {}
    local volatile=env.HussValleyConfigVolatile
    local fileStore=type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function"
    local folder="HussValleyPanel"
    local applying=false
    local function safeName(name)
        local result=tostring(name or ""):gsub("[^%w_%-]",""):sub(1,40)
        assert(#result>0,"Escolha um nome com letras ou numeros.")
        local lower=string.lower(result)
        assert(lower~="_autoload" and lower~="_index","Este nome e reservado.")
        return result
    end
    local function profileName(name)
        return type(name)=="string" and #name>0 and #name<=40 and not name:find("[^%w_%-]")
            and string.lower(name)~="_autoload" and string.lower(name)~="_index"
    end
    local function path(name) return folder.."/"..name..".json" end
    local function saveRecord(name,data)
        session[name]=data;volatile[name]=true
        if not fileStore then return false end
        local ok=pcall(function()
            if type(makefolder)=="function" then pcall(makefolder,folder) end
            local encoded=Http:JSONEncode(data)
            writefile(path(name),encoded)
            assert(isfile(path(name)) and readfile(path(name))==encoded,"A gravacao nao foi confirmada.")
        end)
        if ok then volatile[name]=nil end
        return ok
    end
    loadRecord=function(name)
        if volatile[name] then return type(session[name])=="table" and session[name] or nil end
        if fileStore then
            local ok,data=pcall(function()
                if isfile(path(name)) then return Http:JSONDecode(readfile(path(name))) end
            end)
            if ok and type(data)=="table" then session[name]=data;return data end
        end
        return type(session[name])=="table" and session[name] or nil
    end
    local function isProfile(data)
        if type(data)~="table" then return false end
        for key in pairs(defaults) do if data[key]~=nil then return true end end
        return false
    end
    local function packPosition(position)
        return {position.X.Scale,position.X.Offset,position.Y.Scale,position.Y.Offset}
    end
    local function layoutData()
        return {window=packPosition(window.Position),launcher=packPosition(API.UI.FloatingHost.Position),
            autoJump=packPosition(API.QuickActions.buttons.AutoJump.host.Position),
            freeze=packPosition(API.QuickActions.buttons.Freeze.host.Position)}
    end
    local function restoreLayout(layout)
        if type(layout)~="table" then return end
        for _,entry in ipairs({{"window",window},{"launcher",API.UI.FloatingHost},
            {"autoJump",API.QuickActions.buttons.AutoJump.host},{"freeze",API.QuickActions.buttons.Freeze.host}}) do
            local values=layout[entry[1]]
            if type(values)=="table" then
                local validPosition=true
                for i=1,4 do local n=values[i]
                    if type(n)~="number" or n~=n or math.abs(n)>10000000 then validPosition=false end
                end
                if validPosition then entry[2].Position=UDim2.new(values[1],values[2],values[3],values[4]) end
            end
        end
    end
    local function configData()
        local data={_schema=2,_layout=layoutData()}
        for key in pairs(defaults) do data[key]=cfg[key] end
        return data
    end
    function API.ListConfigs()
        local candidates={}
        local index=loadRecord("_index")
        if index and type(index.names)=="table" then
            for _,name in ipairs(index.names) do if profileName(name) then candidates[name]=true end end
        end
        for name,data in pairs(session) do if profileName(name) and isProfile(data) then candidates[name]=true end end
        if fileStore and type(listfiles)=="function" then
            local ok,files=pcall(listfiles,folder)
            if ok and type(files)=="table" then for _,file in ipairs(files) do
                if type(file)=="string" then
                    local normalized=file:gsub("\\","/")
                    local name=normalized:match("([^/]+)%.json$")
                    if profileName(name) then candidates[name]=true end
                end
            end end
        end
        local names={}
        for name in pairs(candidates) do if isProfile(loadRecord(name)) then names[#names+1]=name end end
        table.sort(names,function(a,b) local x,y=string.lower(a),string.lower(b);return x==y and a<b or x<y end)
        return names
    end
    local function syncAutoLoad(name)
        local record=loadRecord("_autoload")
        cfg.autoLoad=record~=nil and record.enabled==true and record.name==name
        for _,fn in ipairs(watchers.autoLoad or {}) do fn(cfg.autoLoad) end
    end
    API.ConfigUI.AfterSelect=syncAutoLoad
    function API.RefreshConfigs(preferred)
        local names=API.ListConfigs()
        API.ConfigUI.SetNames(names,preferred or API.ConfigUI.Selected)
        return names
    end
    function API.SaveConfig(name)
        name=safeName(name);configName.Text=name
        local persisted=saveRecord(name,configData())
        local indexed=saveRecord("_index",{schema=2,names=API.ListConfigs()})
        if cfg.autoLoad then saveRecord("_autoload",{name=name,enabled=true}) end
        API.RefreshConfigs(name)
        notify(persisted and indexed and ("Config salva: "..name) or ("Config disponivel nesta sessao: "..name))
        return true,persisted and indexed
    end
    function API.LoadConfig(name,quiet)
        name=safeName(name)
        local data=loadRecord(name)
        if not isProfile(data) then
            if not quiet then notify("Config nao encontrada ou invalida: "..name) end
            return false
        end
        local values={}
        for key,initial in pairs(defaults) do
            local candidate=data[key]
            if key=="transparency" and candidate==nil and type(data.opacity)=="number" then candidate=(1-data.opacity)*100 end
            local ok,value=valid(key,candidate)
            if ok then values[key]=value else values[key]=initial end
        end
        -- Stop transient presses and drags; selecting a row alone never enters this path.
        for input,pointer in pairs(pointerSessions) do
            pointerSessions[input]=nil;if pointer.finish then pointer.finish(input) end
        end
        API.QuickActions.Reset()
        applying=true
        -- Parameters first, then disabled flags, then enabled flags.
        for key,initial in pairs(defaults) do
            if type(initial)~="boolean" and key~="opacity" then set(key,values[key],true) end
        end
        for _,enabled in ipairs({false,true}) do for key,initial in pairs(defaults) do
            if type(initial)=="boolean" and key~="autoLoad" and values[key]==enabled then set(key,enabled,true) end
        end end
        applying=false
        restoreLayout(data._layout)
        API.RefreshConfigs(name);API.QuickActions.Update()
        if not quiet then notify("Config carregada: "..name) end
        return true
    end
    function API.DeleteConfig(name)
        name=safeName(name)
        if fileStore then
            local checked,exists=pcall(isfile,path(name))
            if not checked then notify("Nao foi possivel conferir a configuracao salva.");return false end
            if exists then
                if type(delfile)~="function" then notify("Este executor nao permite excluir arquivos.");return false end
                local removed=pcall(function() delfile(path(name));assert(not isfile(path(name))) end)
                if not removed then notify("Nao foi possivel excluir; o perfil foi mantido na lista.");return false end
            end
        end
        session[name]=nil;volatile[name]=nil
        local auto=loadRecord("_autoload")
        if auto and auto.name==name then saveRecord("_autoload",{enabled=false}) end
        saveRecord("_index",{schema=2,names=API.ListConfigs()})
        API.RefreshConfigs()
        notify("Config removida: "..name);return true
    end
    actions.autoLoad=function(value)
        if applying then return end
        local name=API.ConfigUI.Selected
        if value then
            assert(name and isProfile(loadRecord(name)),"Salve e selecione uma configuracao primeiro.")
            local durable=saveRecord("_autoload",{name=name,enabled=true})
            if not durable then notify("Auto-load disponivel somente nesta sessao do executor.") end
        else
            local auto=loadRecord("_autoload")
            if auto and (not name or auto.name==name) then saveRecord("_autoload",{enabled=false}) end
        end
    end
end

-- Diagnostic data stays local: only paths/classes and selected game-state attributes.
local endHitTrace
do
local diagnosticBox
local function presentDiagnostic(data,message)
    if type(setclipboard)=="function" and pcall(setclipboard,data) then notify(message or "Diagnostico copiado.")
    else
        if not diagnosticBox then
            diagnosticBox=create("TextBox",{Name="DiagnosticText",Size=UDim2.fromScale(0.85,0.65),Position=UDim2.fromScale(0.075,0.15),
                MultiLine=true,ClearTextOnFocus=false,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
                Font=Enum.Font.Code,TextSize=10,TextColor3=colors.text,BackgroundColor3=colors.bg,ZIndex=60},gui)
            local dismiss=button(diagnosticBox,"Fechar",12,{Position=UDim2.new(1,-70,0,-30),Size=UDim2.fromOffset(70,26),ZIndex=61})
            listen(dismiss.Activated,function() diagnosticBox.Visible=false end)
        end
        diagnosticBox.Text=data;diagnosticBox.Visible=true;diagnosticBox:CaptureFocus()
    end
    return data
end
function API.ExportDiagnostics()
    preparePrompts(true)
    local report={version=API.Version,placeId=game.PlaceId,gameId=game.GameId,remotes={},prompts={},roles={}}
    for _,o in ipairs(Replicated:GetDescendants()) do
        if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") or o:IsA("UnreliableRemoteEvent") then
            report.remotes[#report.remotes+1]={path=o:GetFullName(),class=o.ClassName}
            if #report.remotes>=500 then report.remoteListTruncated=true;break end
        end
    end
    for prompt in pairs(prompts) do if prompt.Parent and #report.prompts<100 then report.prompts[#report.prompts+1]={path=prompt:GetFullName(),action=prompt.ActionText,object=prompt.ObjectText} end end
    for _,p in ipairs(Players:GetPlayers()) do
        local row={team=p.Team and p.Team.Name or "none",attributes={}}
        for _,key in ipairs({"GameRole","RunState","Role","Team","State","Downed","Caught","IsCatcher","IsRunner","InRound","AFK","KnockdownStreak"}) do
            local v=p:GetAttribute(key);if type(v)=="string" or type(v)=="boolean" or type(v)=="number" then row.attributes[key]=v end
            local ch=p.Character;local cv=ch and ch:GetAttribute(key);if type(cv)=="string" or type(cv)=="boolean" or type(cv)=="number" then row.attributes["Character."..key]=cv end
        end
        report.roles[#report.roles+1]=row
    end
    return presentDiagnostic(Http:JSONEncode(report),"Diagnostico copiado. Envie o texto para mapear as automacoes.")
end

-- Explicitly started traces; every collector is disconnected when the session ends.
local hitTrace={current=nil,last=nil,parts={},nextPart=1}
local function traceClip(value,limit)
    if #value<=limit then return value end
    while limit>0 and string.byte(value,limit+1)>=128 and string.byte(value,limit+1)<192 do limit=limit-1 end
    return string.sub(value,1,limit)
end
function hitTrace.actionTag(first,second)
    if type(first)=="table" then first=rawget(first,"action") or rawget(first,"Action") or rawget(first,"command") or rawget(first,"type") or rawget(first,"op") end
    if type(first)~="string" or #first>96 then return "" end
    local tag=string.gsub(first,"[%c]","")
    if #tag==36 and string.match(tag,"^%x+%-%x+%-%x+%-%x+%-%x+$") then
        if type(second)=="boolean" then return second and "[request-id]:accepted" or "[request-id]:rejected" end
        return type(second)=="string" and #second<=32 and string.gsub(second,"[%c]","") or "[request-id]"
    end
    if (tag=="Verdict" or tag=="PredictionResult" or tag=="FX") and type(second)=="table" then
        for _,name in ipairs({"item","kind","reason"}) do
            local value=rawget(second,name)
            if type(value)=="string" and #value<=32 then tag=tag..":"..string.gsub(value,"[%c]","") end
        end
        if type(rawget(second,"accepted"))=="boolean" then tag=tag..":"..tostring(rawget(second,"accepted")) end
    end
    return tag
end
local function traceValue(value,depth,seen,gameStrings)
    local kind=typeof(value)
    seen._nodes=(seen._nodes or 0)+1
    if seen._nodes>64 then return {type=kind,truncated=true} end
    if kind=="nil" then return {type="nil"}
    elseif kind=="boolean" then return value
    elseif kind=="number" then return value==value and math.abs(value)~=math.huge and value or "non-finite"
    elseif kind=="string" then
        if #value>(gameStrings and 96 or 64) then return {type="string",length=#value} end
        if gameStrings then return string.gsub(value,"[%c]","") end
        local lower=string.lower(value)
        if lower=="runner" or lower=="catcher" or lower=="chaser" or lower=="lobby" or lower=="playing" or lower=="alive" or lower=="spectating" or lower=="normal" then return value end
        for _,word in ipairs({"damage","hit","attack","melee","tackle","caught","capture","dead","death","kill","down","reviv","invul","immune","stun","knock","ragdoll","dodge","parry","block","shield","protect"}) do
            if #value<=64 and string.find(lower,word,1,true) then return string.gsub(value,"[%c]","") end
        end
        return {type="string",length=#value}
    elseif kind=="Instance" then
        -- Dot calls preserve the pending __namecall method in the outbound observer.
        local ok,path=pcall(function() return value.GetFullName(value) end)
        return {type="Instance",class=value.ClassName,path=ok and traceClip(path,200) or "unavailable"}
    elseif kind=="Vector3" or kind=="Vector2" then return {type=kind,x=traceValue(value.X,3,{}),y=traceValue(value.Y,3,{}),z=kind=="Vector3" and traceValue(value.Z,3,{}) or nil}
    elseif kind=="CFrame" then return {type="CFrame",position=traceValue(value.Position,3,{})}
    elseif kind=="EnumItem" then return tostring(value)
    elseif kind=="table" then
        if depth>=3 or seen[value] then return {type="table",truncated=true} end
        seen[value]=true;local out,count={},0
        for key,child in next,value do
            count=count+1;if count>12 then out.truncated=true;break end
            local name=(type(key)=="string" or type(key)=="number") and traceClip(tostring(key),64) or "[key]"
            local lower=string.lower(name)
            if string.find(lower,"token",1,true) or string.find(lower,"secret",1,true) or string.find(lower,"password",1,true) or string.find(lower,"auth",1,true) then out[name]="[redacted]"
            else out[name]=traceValue(child,depth+1,seen,gameStrings) end
        end
        seen[value]=nil;return out
    end
    return {type=kind}
end
local function relevantAttribute(name)
    local lower=string.lower(name)
    if lower:find("token",1,true) or lower:find("secret",1,true) or lower:find("password",1,true) or lower:find("auth",1,true) then return false end
    for _,part in ipairs({"health","damage","dead","alive","death","caught","captur","down","state","status","role","team","round","invul","immune","iframe","stun","knock","ragdoll","zone","safe","kill","dash","cooldown","ability","tackle","gem","coin","journey","vote","afk","map","reviv","shield","block","protect","gear"}) do
        if lower:find(part,1,true) then return true end
    end
    return false
end
local function hitSnapshot(gameStrings)
    local char,hum,root=character();local sample={attributes={},features={}}
    if hum then sample.health=hum.Health;sample.maxHealth=hum.MaxHealth;sample.platformStand=hum.PlatformStand
        local ok,s=pcall(function() return hum:GetState() end);if ok then sample.humanoidState=tostring(s) end
    end
    if root then sample.position=traceValue(root.Position,0,{});sample.velocity=traceValue(root.AssemblyLinearVelocity,0,{}) end
    sample.team=player.Team and player.Team.Name or "none"
    local tool=char and char:FindFirstChildOfClass("Tool");if tool then sample.tool=traceValue(tool,0,{}) end
    for _,owner in ipairs({player,char}) do
        if owner then for key,value in pairs(owner:GetAttributes()) do
            if relevantAttribute(key) then sample.attributes[(owner==player and "Player." or "Character.")..key]=traceValue(value,0,{},gameStrings) end
        end end
    end
    for _,key in ipairs({"movement","speedBoost","fly","noclip","tpWalk","autoAttack","autoDash","autoZone","autoTackle","autoAbility","lockOn","antiHit"}) do sample.features[key]=cfg[key] end
    if API.Native then
        sample.native={}
        for name,row in pairs(API.Native.Status) do sample.native[name]={sent=row.sent,accepted=row.accepted,rejected=row.rejected,timeouts=row.timeouts,failed=row.failed,confirmed=row.confirmed,unconfirmed=row.unconfirmed,source=row.source,message=row.message} end
    end
    return sample
end
hitTrace.reserves={outbound=180,inbound=140,critical=100,state=80,telemetry=100}
function hitTrace.shieldAttribute(key)
    local lower=string.lower(key)
    for _,word in ipairs({"shield","block","protect","invul","immune","iframe","gear","health","dead","caught","downed","runstate","gamerole"}) do
        if lower:find(word,1,true) then return true end
    end
    return false
end
function hitTrace.rememberShieldID(ctx,id,subject)
    if type(id)~="string" or #id>96 then return end
    if not ctx.shieldIDs[id] then
        if #ctx.shieldIDOrder>=64 then ctx.shieldIDs[table.remove(ctx.shieldIDOrder,1)]=nil end
        ctx.shieldIDOrder[#ctx.shieldIDOrder+1]=id
    end
    ctx.shieldIDs[id]={subject=subject,time=os.clock()}
end
function hitTrace.shieldSubject(ctx,remote,direction,args)
    local data=type(args[2])=="table" and args[2] or (type(args[1])=="table" and args[1] or nil)
    local id=data and (rawget(data,"requestId") or rawget(data,"id")) or nil
    if direction=="out" then
        if remote.Name=="GearEvent" and type(args[4])=="string" then id=args[4] end
        hitTrace.rememberShieldID(ctx,id,"localRequest")
        return "localRequest"
    end
    local subject
    if data then
        local targetId,target=rawget(data,"targetId"),rawget(data,"target")
        if targetId==player.UserId or (target~=nil and target==player.Character) then subject="localTarget"
        elseif type(targetId)=="number" or typeof(target)=="Instance" then return "otherPlayer" end
        for _,field in ipairs({"targetIds","targets"}) do
            local list=rawget(data,field)
            if type(list)=="table" then
                local checked=0
                for _,value in next,list do
                    checked=checked+1;if checked>64 then break end
                    if value==player.UserId or (value~=nil and value==player.Character) then subject="localTarget";break end
                end
            end
        end
        if not subject then
            local actorId=rawget(data,"actorId") or rawget(data,"ownerId")
            local actor=rawget(data,"character")
            if actorId==player.UserId or (actor~=nil and actor==player.Character) then subject="localActor"
            elseif actorId~=nil or actor~=nil or type(rawget(data,"targetIds"))=="table" or type(rawget(data,"targets"))=="table" then return "otherPlayer" end
        end
        local known=ctx.shieldIDs[id or false]
        if not subject and known and os.clock()-known.time<=20 then subject=known.subject end
        if subject then
            hitTrace.rememberShieldID(ctx,id,subject)
            hitTrace.rememberShieldID(ctx,rawget(data,"canonicalId"),subject)
        end
    end
    if not subject and type(args[1])=="string" then
        local known=ctx.shieldIDs[args[1]] or ctx.shieldIDs[type(args[2])=="string" and args[2] or false]
        if known and os.clock()-known.time<=20 then subject=known.subject end
    end
    return subject or "unattributed"
end
function hitTrace.group(kind,data)
    if kind=="remote" then return data.direction=="out" and "outbound" or "inbound" end
    if kind=="humanoidState" then
        for _,word in ipairs({"Dead","FallingDown","Ragdoll","GettingUp"}) do
            if string.find(data.current,word,1,true) then return "critical" end
        end
        return "telemetry"
    end
    if kind=="attribute" then
        local key=string.lower(data.name)
        if key=="dashcooldownuntil" or key=="movementstate" then return "telemetry" end
        for _,word in ipairs({"role","runstate","health","dead","caught","downed","knocked","tackleactive","dashready","zone"}) do
            if string.find(key,word,1,true) then return "critical" end
        end
        return "state"
    end
    if kind=="stat" then return "state" end
    return "critical"
end
local function recordHitEvent(ctx,kind,data)
    if not ctx.active then return end
    ctx.report.eventsSeen=ctx.report.eventsSeen+1
    local limit=ctx.general and 600 or (ctx.waiting and 20 or 160)
    local group=ctx.general and hitTrace.group(kind,data) or nil
    if #ctx.report.events>=limit then
        local remove=1
        if ctx.general then
            -- Each class borrows unused space, but cannot evict another class below its reserve.
            local victim=group
            if (ctx.report.retainedByGroup[group] or 0)<hitTrace.reserves[group] then
                local largest=0
                for candidate,reserve in pairs(hitTrace.reserves) do
                    local excess=(ctx.report.retainedByGroup[candidate] or 0)-reserve
                    if excess>largest then largest=excess;victim=candidate end
                end
            end
            for i,event in ipairs(ctx.report.events) do if event.group==victim then remove=i;break end end
            local previous=ctx.report.events[remove].group
            ctx.report.retainedByGroup[previous]=ctx.report.retainedByGroup[previous]-1
            ctx.report.eventsDroppedByGroup[previous]=(ctx.report.eventsDroppedByGroup[previous] or 0)+1
        else
            for i,event in ipairs(ctx.report.events) do if event.kind=="remote" then remove=i;break end end
        end
        table.remove(ctx.report.events,remove);ctx.report.eventsDropped=ctx.report.eventsDropped+1
    end
    local event={t=math.floor((os.clock()-ctx.started)*1000+0.5)/1000,seq=ctx.report.eventsSeen,kind=kind,data=data,group=group}
    ctx.report.events[#ctx.report.events+1]=event
    if group then ctx.report.retainedByGroup[group]=(ctx.report.retainedByGroup[group] or 0)+1 end
    if ctx.shield and (kind=="remote" or kind=="marker" or kind=="health" or kind=="died" or kind=="respawn"
        or kind=="attribute" and hitTrace.shieldAttribute(data.name)) then
        local focused=ctx.report.shield
        if #focused.events>=80 then table.remove(focused.events,1);focused.eventsDropped=focused.eventsDropped+1 end
        focused.events[#focused.events+1]=event
    end
    return event
end
local function recordAttribute(ctx,owner,key,previous,value)
    if not ctx.general then
        return recordHitEvent(ctx,"attribute",{owner=owner,name=key,previous=traceValue(previous,0,{}),value=traceValue(value,0,{})})
    end
    local now=os.clock()-ctx.started
    local id=owner.."@"..key
    local summary=ctx.report.attributeStats[id]
    ctx.report.attributeChangesSeen=ctx.report.attributeChangesSeen+1
    if not summary and ctx.attributeSummaryCount<128 then
        summary={owner=owner,name=key,changes=0,recorded=0,coalesced=0,firstT=now,previous=traceValue(previous,0,{},true)}
        ctx.report.attributeStats[id]=summary;ctx.attributeSummaryCount=ctx.attributeSummaryCount+1
    end
    local serialized=traceValue(value,0,{},true)
    if summary then summary.changes=summary.changes+1;summary.last=serialized;summary.lastT=now end
    local lower=string.lower(key)
    local interval=lower=="dashcooldownuntil" and 5 or (lower=="movementstate" and 0.5 or 0)
    if summary and interval>0 and summary.lastRecordedT and now-summary.lastRecordedT<interval then
        summary.coalesced=summary.coalesced+1;ctx.report.eventsCoalesced=ctx.report.eventsCoalesced+1
        return
    end
    if summary then summary.recorded=summary.recorded+1;summary.lastRecordedT=now end
    return recordHitEvent(ctx,"attribute",{owner=owner,name=key,previous=traceValue(previous,0,{},true),value=serialized})
end
local function traceStatus(message)
    if state.alive then hitStatus.Text=message;API.DiagnosticStatus.Text=message end
end
local function makeTraceParts(report,actionsOnly)
    local encoded=Http:JSONEncode(report)
    if not actionsOnly then hitTrace.encoded=encoded end
    hitTrace.partMode=actionsOnly and "acoes" or "completo";hitTrace.parts={};hitTrace.nextPart=1
    -- Split only between UTF-8 characters. Parts are labelled fragments of one JSON.
    local start=1
    repeat
        local finish=math.min(start+8999,#encoded)
        while finish<#encoded and encoded:byte(finish+1)>=128 and encoded:byte(finish+1)<192 do finish=finish-1 end
        hitTrace.parts[#hitTrace.parts+1]=encoded:sub(start,finish);start=finish+1
    until start>#encoded
end
function API.CopyNextDiagnosticsPart(index)
    if not hitTrace.last then notify("Grave e encerre uma analise primeiro.");return false end
    if #hitTrace.parts==0 then makeTraceParts(hitTrace.last) end
    index=index or hitTrace.nextPart
    if type(index)~="number" or index%1~=0 or index<1 or index>#hitTrace.parts then return false end
    local total=#hitTrace.parts
    hitTrace.nextPart=index%total+1
    local header="[HUSS TRACE "..hitTrace.last.session.." | "..hitTrace.partMode.." | parte "..index.."/"..total.."]\n"
    traceStatus("Copiada parte "..index.."/"..total.." | proxima: "..hitTrace.nextPart)
    return presentDiagnostic(header..hitTrace.parts[index],"Parte "..index.."/"..total.." copiada. Envie aqui; depois copie a proxima.")
end
function API.CopyActionDiagnostics()
    local report=hitTrace.last
    if not report then notify("Grave e encerre uma analise primeiro.");return false end
    local markers={}
    for _,event in ipairs(report.events) do if event.kind=="marker" then markers[#markers+1]=event end end
    while #markers>24 do table.remove(markers,1) end
    local samples={}
    for _,row in ipairs(report.remoteSamples) do
        samples[#samples+1]={remote=row.remote,direction=row.direction,action=row.action,first=row.first,
            latest=row.latest and row.latest.seq~=row.first.seq and row.latest or nil}
    end
    local summary={kind="HussValleyActionSummary",version=report.version,session=report.session,placeId=report.placeId,gameId=report.gameId,
        duration=report.duration,reason=report.reason,capabilities=report.capabilities,collectorErrors=report.collectorErrors,
        initial=report.initial,final=report.final,remoteStats=report.remoteStats,remoteSamples=samples,markers=markers,
        eventsSeen=report.eventsSeen,eventsDropped=report.eventsDropped,eventsCoalesced=report.eventsCoalesced,healthDecreases=report.healthDecreases,
        remoteSampleEventsOmitted=report.remoteSampleEventsOmitted,
        note="Resumo de amostras inicial/recente por endpoint, direcao e acao. Nao substitui o historico completo, disponivel em Salvar JSON."}
    if report.shield then
        summary.kind="HussValleyShieldSummary";summary.shield=report.shield
        summary.remoteSamples=nil;summary.markers=nil
        summary.note="Captura focada no escudo. localTarget indica alvo/candidato, nao confirma acerto. unattributed nao tem dono confirmado. Fonte do inventario: State recebido neste cliente. Nao demonstra imunidade permanente."
    end
    makeTraceParts(summary,true)
    return API.CopyNextDiagnosticsPart(1)
end
endHitTrace=function(reason,copy)
    local ctx=hitTrace.current
    if not ctx then return false end
    ctx.active=false;hitTrace.current=nil
    if ctx.detachOutbound then ctx.report.outboundCleanup=ctx.detachOutbound();ctx.detachOutbound=nil end
    for _,connection in ipairs(ctx.connections) do connection:Disconnect() end
    for _,connection in ipairs(ctx.characterConnections) do connection:Disconnect() end
    ctx.report.duration=math.floor((os.clock()-ctx.started)*1000+0.5)/1000
    ctx.report.reason=reason;ctx.report.final=hitSnapshot(ctx.general)
    hitTrace.last=ctx.report;API.LastHitDiagnostics=ctx.report;API.LastGeneralDiagnostics=ctx.general and ctx.report or API.LastGeneralDiagnostics
    hitTrace.encoded=nil;hitTrace.parts={};hitTrace.nextPart=1
    traceStatus("Encerrado | "..#ctx.report.events.." registros | vida caiu: "..ctx.report.healthDecreases)
    if API.TraceToolbar then API.TraceToolbar.Visible=false end
    if copy and state.alive then
        if ctx.general then API.CopyActionDiagnostics()
        else presentDiagnostic(Http:JSONEncode(ctx.report),"Analise de hits copiada. Envie o texto aqui.") end
    end
    return ctx.report
end
local function triggerHitTrace(ctx,reason)
    if not ctx.active or not ctx.waiting then return end
    ctx.waiting=false;ctx.report.trigger={reason=reason,snapshot=hitSnapshot()}
    recordHitEvent(ctx,"trigger",{reason=reason})
    hitStatus.Text="Sinal detectado | coletando mais 5s..."
    notify("Sinal de hit/captura registrado. A analise termina em 5 segundos.")
    task.delay(5,function() if state.alive and hitTrace.current==ctx then endHitTrace("signalDetected",true) end end)
end
local function isHitAttribute(key,value,previous)
    local lower=string.lower(key)
    if value==true or value==1 then
        for _,word in ipairs({"caught","captur","dead","downed","knocked","stunned"}) do if lower:find(word,1,true) then return true end end
    end
    if type(value)=="string" then
        local text=string.lower(value)
        if lower:find("state",1,true) or lower:find("status",1,true) then
            for _,word in ipairs({"caught","captured","dead","downed","knocked","stunned"}) do if text==word then return true end end
        end
        if (lower=="role" or lower=="gamerole" or lower=="team") and type(previous)=="string" and string.lower(previous)=="runner" and (text=="catcher" or text=="chaser") then return true end
    end
    return false
end
local function generalRemote(path)
    if path=="ReplicatedStorage.chrono.Shared.Remotes.Death" then return true end
    local prefix="ReplicatedStorage.ChickenOrHero."
    if path:sub(1,#prefix)~=prefix then return false end
    for _,part in ipairs({".Admin.",".Audio.",".Bots.","Chat","PrivateInvite","PrivateServer","ChronoView","Snapshot"}) do
        if path:find(part,1,true) then return false end
    end
    return true
end
local function observeOutbound(ctx,capture)
    -- A detachable raw-metatable shim is used only when all required APIs exist.
    -- It never calls FireServer/InvokeServer itself, and never edits their arguments.
    if type(getrawmetatable)~="function" or type(getnamecallmethod)~="function" or type(setreadonly)~="function"
        or type(isreadonly)~="function" or type(newcclosure)~="function" then return "unavailable" end
    local function assign(mt,value)
        local ok,locked=pcall(isreadonly,mt);if not ok then return false end
        if not pcall(setreadonly,mt,false) then return false end
        local written=pcall(function() mt.__namecall=value end)
        local restored=pcall(setreadonly,mt,locked)
        return written and restored
    end
    local slot=env.HussValleyTraceBridge
    if type(slot)~="table" or not slot.installed then
        local ok,mt=pcall(getrawmetatable,game)
        if not ok or type(mt)~="table" or type(mt.__namecall)~="function" then return "unavailable" end
        slot={metatable=mt,previous=mt.__namecall}
        local methodName=getnamecallmethod
        local wrapped,wrapper=pcall(newcclosure,function(self,...)
            -- Fetch the method before any diagnostic work; use no yielding engine calls here.
            local ok,method=pcall(methodName)
            if ok and slot.handler and (method=="FireServer" or method=="InvokeServer") then
                pcall(slot.handler,self,method,...)
            end
            return slot.previous(self,...)
        end)
        if not wrapped or type(wrapper)~="function" then return "unavailable" end
        slot.wrapper=wrapper
        if not assign(mt,wrapper) then
            if mt.__namecall==wrapper then assign(mt,slot.previous) end
            return "setupFailed"
        end
        slot.installed=true;env.HussValleyTraceBridge=slot
    end
    slot.handler=function(remote,method,...)
        if ctx.active and ctx.remotePaths[remote] then
            local ok=pcall(capture,remote,"out",method,...)
            if not ok then ctx.report.collectorErrors=ctx.report.collectorErrors+1 end
        end
    end
    ctx.detachOutbound=function()
        -- A newer hook may chain ours: release the session, keeping an inert pass-through.
        slot.handler=nil
        if slot.metatable.__namecall==slot.wrapper and assign(slot.metatable,slot.previous) then
            slot.installed=false
            if env.HussValleyTraceBridge==slot then env.HussValleyTraceBridge=nil end
            return "restored"
        end
        return "inactivePassThrough"
    end
    return slot.metatable.__namecall==slot.wrapper and "installed" or "chainReused"
end
function API.MarkDiagnostics(label)
    local ctx=hitTrace.current
    if not ctx or not ctx.general then notify("Inicie o gravador geral primeiro.");return false end
    if type(label)~="string" then return false end
    label=traceClip(label:gsub("[%c]",""),40)
    recordHitEvent(ctx,"marker",{label=label,snapshot=hitSnapshot(true)})
    traceStatus("Gravando | marcado: "..label)
    return true
end
function API.MarkAbilityDiagnostics()
    return API.MarkDiagnostics(hitTrace.current and hitTrace.current.shield and "Escudo ativado" or "Habilidade")
end
function API.StartGeneralDiagnostics() return API.StartHitDiagnostics("general") end
function API.StartShieldDiagnostics() return API.StartHitDiagnostics("shield") end
function API.StartHitDiagnostics(waitForHit)
    if not state.alive then return false end
    if hitTrace.current then notify("Ja existe uma gravacao. Use Encerrar e copiar antes de iniciar outra.");return false end
    local ctx={active=true,started=os.clock(),general=waitForHit=="general" or waitForHit=="shield",shield=waitForHit=="shield",waiting=waitForHit~=false and waitForHit~="general" and waitForHit~="shield",
        connections={},characterConnections={},subscribed={},remotePaths={},remoteCount=0,attributeSummaryCount=0,remoteSampleGroups={}}
    ctx.report={kind=ctx.general and "HussValleyGeneralTrace" or "HussValleyHitTrace",version=API.Version,placeId=game.PlaceId,gameId=game.GameId,
        session=tostring(os.time()).."-"..tostring(math.random(100000,999999)),
        mode=ctx.general and "round30m" or (ctx.waiting and "waitForLocalSignal" or "record20s"),
        initial=hitSnapshot(ctx.general),events={},eventsSeen=0,eventsDropped=0,healthDecreases=0,observedRemotes={},missingRemotesAtStart={},
        capabilities={getconnections=type(getconnections)=="function",decompile=type(decompile)=="function",getscriptbytecode=type(getscriptbytecode)=="function"},
        remoteStats={},remoteSamples={},remoteSampleEventsOmitted=0,initialStats={},observedValues={},collectorErrors=0,
        attributeStats={},attributeChangesSeen=0,eventsCoalesced=0,retainedByGroup={},eventsDroppedByGroup={},
        note="Observacao do cliente; eventos recebidos podem se referir a outros jogadores. Marcadores sao relatos do usuario; zoneContact e apenas uma pista. O registro nao contem logica do servidor."}
    if ctx.shield then
        ctx.shieldIDs={};ctx.shieldIDOrder={}
        ctx.report.kind="HussValleyShieldTrace";ctx.report.mode="shield15m"
        ctx.report.shield={localPlayerId=player.UserId,events={},eventsDropped=0,inventorySamples={},inventorySamplesDropped=0,excludedOtherPlayerEvents=0}
    end
    hitTrace.current=ctx
    local function attach(signal,fn,bucket)
        bucket=bucket or ctx.connections
        bucket[#bucket+1]=signal:Connect(function(...)
            if ctx.active then local ok=pcall(fn,...);if not ok then ctx.report.collectorErrors=ctx.report.collectorErrors+1 end end
        end)
    end
    local function watchCharacter(char)
        for _,connection in ipairs(ctx.characterConnections) do connection:Disconnect() end
        ctx.characterConnections={}
        if not char then return end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum then
            task.spawn(function()
                local h=char:WaitForChild("Humanoid",8)
                if ctx.active and h and player.Character==char then watchCharacter(char) end
            end)
            return
        end
        local last=hum.Health
        local attributes=char:GetAttributes()
        if ctx.general then
            for _,summary in pairs(ctx.report.attributeStats) do if summary.owner=="Character" then summary.lastRecordedT=nil end end
        end
        attach(hum.HealthChanged,function(value)
            if value<last then ctx.report.healthDecreases=ctx.report.healthDecreases+1;triggerHitTrace(ctx,"healthDecreased") end
            recordHitEvent(ctx,"health",{previous=last,current=value});last=value
        end,ctx.characterConnections)
        attach(hum.Died,function() triggerHitTrace(ctx,"humanoidDied");recordHitEvent(ctx,"died",hitSnapshot(ctx.general)) end,ctx.characterConnections)
        attach(hum.StateChanged,function(old,new)
            recordHitEvent(ctx,"humanoidState",{previous=tostring(old),current=tostring(new)})
        end,ctx.characterConnections)
        attach(char.AttributeChanged,function(key)
            if relevantAttribute(key) then
                local value,previous=char:GetAttribute(key),attributes[key];attributes[key]=value
                if isHitAttribute(key,value,previous) then triggerHitTrace(ctx,"characterAttribute:"..key) end
                recordAttribute(ctx,"Character",key,previous,value)
            end
        end,ctx.characterConnections)
        if ctx.general then
            local watched={};local contacts=setmetatable({},{__mode="k"})
            local function watchPart(object)
                if watched[object] then return end
                if object:IsA("Tool") then
                    watched[object]=true
                    attach(object.Activated,function() recordHitEvent(ctx,"toolActivated",{tool=traceValue(object,0,{})}) end,ctx.characterConnections)
                elseif object.Name=="HumanoidRootPart" and object:IsA("BasePart") then
                    watched[object]=true
                    attach(object.Touched,function(part)
                        if not part or part:IsDescendantOf(char) then return end
                        local path=part:GetFullName();local lower=string.lower(path)
                        if not (lower:find("zone",1,true) or lower:find("safe",1,true) or lower:find("finish",1,true) or lower:find("checkpoint",1,true)) then return end
                        local now=os.clock();if contacts[part] and now-contacts[part]<2 then return end;contacts[part]=now
                        recordHitEvent(ctx,"zoneContact",{part=traceValue(part,0,{}),position=traceValue(part.Position,0,{}),size=traceValue(part.Size,0,{}),snapshot=hitSnapshot(true)})
                    end,ctx.characterConnections)
                end
            end
            for _,object in ipairs(char:GetDescendants()) do watchPart(object) end
            attach(char.DescendantAdded,watchPart,ctx.characterConnections)
        end
    end
    local playerAttributes=player:GetAttributes()
    attach(player.AttributeChanged,function(key)
        if relevantAttribute(key) then
            local value,previous=player:GetAttribute(key),playerAttributes[key];playerAttributes[key]=value
            if isHitAttribute(key,value,previous) then triggerHitTrace(ctx,"playerAttribute:"..key) end
            recordAttribute(ctx,"Player",key,previous,value)
        end
    end)
    attach(player.CharacterAdded,function(char) recordHitEvent(ctx,"respawn",{});watchCharacter(char) end)
    if ctx.general then attach(player:GetPropertyChangedSignal("Team"),function() recordHitEvent(ctx,"team",hitSnapshot(true)) end) end
    watchCharacter(player.Character)
    local paths={"chrono.Shared.Remotes.Death","ChickenOrHero.Game.GameAction","ChickenOrHero.Game.MeleeEvent",
        "ChickenOrHero.Game.HitReplayEvent","ChickenOrHero.Game.RescueEvent","ChickenOrHero.Game.TeamEventRemote",
        "ChickenOrHero.Presentation.MovementGuardEvent"}
    if ctx.shield then paths={"chrono.Shared.Remotes.Death","ChickenOrHero.Game.GameAction","ChickenOrHero.Game.MeleeEvent",
        "ChickenOrHero.Game.HitReplayEvent","ChickenOrHero.Gear.GearEvent","ChickenOrHero.Weapons.ArmoryEvent"} end
    local wanted={};for _,path in ipairs(paths) do wanted["ReplicatedStorage."..path]=true end
    local function capture(remote,direction,method,...)
        local path=ctx.remotePaths[remote];if not path then return end
        local args=table.pack(...);local subject
        if ctx.shield then
            subject=hitTrace.shieldSubject(ctx,remote,direction,args)
            if subject=="otherPlayer" then ctx.report.shield.excludedOtherPlayerEvents=ctx.report.shield.excludedOtherPlayerEvents+1;return end
            if direction=="in" and remote.Name=="ArmoryEvent" and args[1]=="State" and type(args[2])=="table" and type(rawget(args[2],"gear"))=="table" then
                local gear=rawget(args[2],"gear");local samples=ctx.report.shield.inventorySamples
                if #samples>=16 then table.remove(samples,1);ctx.report.shield.inventorySamplesDropped=ctx.report.shield.inventorySamplesDropped+1 end
                samples[#samples+1]={t=os.clock()-ctx.started,subject=subject,gear=traceValue(gear,0,{},true),oneHitShield=traceValue(rawget(gear,"OneHitShield"),0,{},true)}
            end
        end
        local key=direction..":"..path
        local stats=ctx.report.remoteStats[key]
        if not stats then stats={calls=0,sampled=0,suppressed=0};ctx.report.remoteStats[key]=stats end
        stats.calls=stats.calls+1
        local now=os.clock()
        if ctx.general then
            local sample=ctx.subscribed[remote][direction]
            if not sample or now-sample.start>=1 then sample={start=now,count=0};ctx.subscribed[remote][direction]=sample end
            if sample.count>=(ctx.shield and 16 or (direction=="out" and 8 or 4)) then stats.suppressed=stats.suppressed+1;return end
            sample.count=sample.count+1
        elseif ctx.waiting then
            local last=ctx.subscribed[remote].last or -math.huge
            if now-last<0.25 then stats.suppressed=stats.suppressed+1;return end
            ctx.subscribed[remote].last=now
        end
        local data={remote=path,direction=direction,method=method,argumentCount=args.n,arguments={},subject=subject}
        local seen={};for i=1,math.min(args.n,8) do data.arguments[i]=traceValue(args[i],0,seen,ctx.general) end
        if args.n>8 then data.argumentsTruncated=true end
        stats.sampled=stats.sampled+1
        local event=recordHitEvent(ctx,"remote",data)
        if ctx.general then
            -- Keep first/latest samples per action independently of chronological event eviction.
            local first,second=select(1,...)
            local tag=hitTrace.actionTag(first,second)
            local sampleKey=key.."\0"..tag
            local samples=ctx.remoteSampleGroups[sampleKey]
            if not samples and #ctx.report.remoteSamples<64 then
                samples={remote=path,direction=direction,action=tag,first=event};ctx.remoteSampleGroups[sampleKey]=samples
                ctx.report.remoteSamples[#ctx.report.remoteSamples+1]=samples
            end
            if samples then samples.latest=event else ctx.report.remoteSampleEventsOmitted=ctx.report.remoteSampleEventsOmitted+1 end
        end
    end
    local function subscribe(remote)
        if ctx.subscribed[remote] or ctx.remoteCount>=160 or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") or (ctx.general and remote:IsA("RemoteFunction"))) then return end
        local path=remote:GetFullName();if not (ctx.shield and wanted[path] or not ctx.shield and (ctx.general and generalRemote(path) or not ctx.general and wanted[path])) then return end
        ctx.subscribed[remote]={};ctx.remotePaths[remote]=path;ctx.remoteCount=ctx.remoteCount+1
        ctx.report.observedRemotes[#ctx.report.observedRemotes+1]=path
        if not remote:IsA("RemoteFunction") then attach(remote.OnClientEvent,function(...) capture(remote,"in","OnClientEvent",...) end) end
    end
    local initialObjects=ctx.general and Replicated:GetDescendants() or {}
    if ctx.general then
        for _,object in ipairs(initialObjects) do subscribe(object) end
    else
        for _,path in ipairs(paths) do
            local object=Replicated
            for segment in path:gmatch("[^%.]+") do object=object and object:FindFirstChild(segment) end
            if object then subscribe(object) else ctx.report.missingRemotesAtStart[#ctx.report.missingRemotesAtStart+1]="ReplicatedStorage."..path end
        end
    end
    attach(Replicated.DescendantAdded,subscribe)
    if ctx.general then
        local watchedValues,watchedFolders={},{}
        local valueCount=0
        local function watchValue(object,localStat)
            if ctx.shield or watchedValues[object] or valueCount>=100 or not object:IsA("ValueBase") then return end
            local path=object:GetFullName()
            if not localStat and not (generalRemote(path) and relevantAttribute(object.Name)) then return end
            local name=string.lower(object.Name)
            for _,word in ipairs({"token","secret","password","auth"}) do if name:find(word,1,true) then return end end
            watchedValues[object]=true;valueCount=valueCount+1
            local last=traceValue(object.Value,0,{},true)
            ctx.report.initialStats[path]=last;ctx.report.observedValues[#ctx.report.observedValues+1]=path
            attach(object:GetPropertyChangedSignal("Value"),function()
                local value=traceValue(object.Value,0,{},true)
                recordHitEvent(ctx,"stat",{path=path,previous=last,value=value});last=value
            end)
        end
        local function watchFolder(folder)
            if watchedFolders[folder] then return end;watchedFolders[folder]=true
            for _,object in ipairs(folder:GetDescendants()) do watchValue(object,true) end
            attach(folder.DescendantAdded,function(object) watchValue(object,true) end)
        end
        local stats=player:FindFirstChild("leaderstats");if stats then watchFolder(stats) end
        attach(player.ChildAdded,function(object) if object.Name=="leaderstats" then watchFolder(object) end end)
        local function watchReplicated(object)
            watchValue(object,false)
            local path=object:GetFullName()
            if watchedFolders[object] or not (path=="ReplicatedStorage.ChickenOrHero" or path=="ReplicatedStorage.ChickenOrHero.Game") then return end
            watchedFolders[object]=true
            local attributes=object:GetAttributes()
            for name,value in pairs(attributes) do if relevantAttribute(name) then ctx.report.initialStats[path.."@"..name]=traceValue(value,0,{},true) end end
            attach(object.AttributeChanged,function(name)
                if relevantAttribute(name) then
                    local value,previous=object:GetAttribute(name),attributes[name];attributes[name]=value
                    recordAttribute(ctx,path,name,previous,value)
                end
            end)
        end
        for _,object in ipairs(initialObjects) do watchReplicated(object) end
        attach(Replicated.DescendantAdded,watchReplicated)
        local ok,promptService=pcall(function() return game:GetService("ProximityPromptService") end)
        ctx.report.capabilities.promptObserver=ok and promptService~=nil
        if ok and promptService then attach(promptService.PromptTriggered,function(prompt,who)
            if who==player then recordHitEvent(ctx,"prompt",{prompt=traceValue(prompt,0,{}),action=traceValue(prompt.ActionText,0,{},true),snapshot=hitSnapshot(true)}) end
        end) end
        ctx.report.capabilities.outbound=observeOutbound(ctx,capture)
        local reserves={};for name,value in pairs(hitTrace.reserves) do reserves[name]=value end
        ctx.report.limits={events=600,inboundPerRemotePerSecond=ctx.shield and 16 or 4,outboundPerRemotePerSecond=ctx.shield and 16 or 8,remotes=160,values=100,maxSeconds=ctx.shield and 900 or 1800,
            maxArguments=8,tableDepth=3,tableFields=12,valueNodes=64,stringBytes=96,
            reservedEvents=reserves,remoteSampleGroups=64,attributeSummaries=128,dashCooldownSampleSeconds=5,movementStateSampleSeconds=0.5}
        ctx.report.excluded="Chat, private/admin, audio/bots and high-frequency replication; RemoteFunction callbacks and direct-dot remote calls are not intercepted."
        if ctx.shield then ctx.report.limits.shieldEvents=80;ctx.report.limits.shieldIDs=64;ctx.report.limits.shieldInventorySamples=16 end
        traceStatus((ctx.shield and "Gravando escudo | ate 15 min | saida: " or "Gravando rodada | ate 30 min | saida: ")..ctx.report.capabilities.outbound)
        API.TraceToolbar.TraceMarker6.Text=ctx.shield and "Escudo" or "Habil."
        API.TraceToolbar.Visible=true
        notify(ctx.shield and "Gravando seu escudo. Equipe e ative pelo jogo; marque a ativacao e use Encerrar e copiar depois." or "Gravador geral iniciado. Marque suas acoes na barra superior e use Parar ao terminar.")
        task.delay(ctx.shield and 900 or 1800,function() if state.alive and hitTrace.current==ctx then endHitTrace(ctx.shield and "shieldTimeout" or "generalTimeout",true) end end)
    elseif ctx.waiting then
        hitStatus.Text="Aguardando seu hit | limite: 15 min"
        notify("Analise armada. Jogue normalmente; ela aguarda um sinal de dano/captura por ate 15 minutos.")
        task.delay(900,function() if state.alive and hitTrace.current==ctx and ctx.waiting then endHitTrace("waitTimeout",true) end end)
    else
        hitStatus.Text="Gravando por 20s..."
        notify("Gravacao de 20 segundos iniciada.")
        task.delay(20,function() if state.alive and hitTrace.current==ctx then endHitTrace("timeout",true) end end)
    end
    return true
end
function API.StopHitDiagnostics(copy)
    local result=endHitTrace("manual",copy~=false)
    if not result and state.alive then notify("Nenhuma analise em andamento.") end
    return result
end
function API.CopyHitDiagnostics()
    if not hitTrace.last then notify("Grave e encerre uma analise primeiro.");return false end
    return presentDiagnostic(hitTrace.encoded or Http:JSONEncode(hitTrace.last),"Registro completo copiado. Envie o texto aqui.")
end
function API.SaveDiagnostics()
    if not hitTrace.last then notify("Encerre a gravacao primeiro.");return false end
    if type(writefile)~="function" then notify("Este executor nao permite salvar arquivos. Use as partes copiadas.");return false end
    if not hitTrace.encoded then hitTrace.encoded=Http:JSONEncode(hitTrace.last) end
    local filename="huss-valley-trace-"..hitTrace.last.session..".json"
    local ok=pcall(writefile,filename,hitTrace.encoded)
    if not ok then notify("Nao foi possivel salvar. Use as partes copiadas.");return false end
    notify("Salvo no executor: "..filename)
    return filename
end
end

-- Proximity uses current positions each heartbeat; cooldowns start only when an action is attempted.
local elapsed,speedElapsed,hueElapsed=0,0,0
local lastAction={attack=-math.huge,gear=-math.huge,prompt=-math.huge,promptPending=false}
actions.lockOn=function() state.aimTarget=nil end
actions.radius=function() state.aimTarget=nil end
actions.teamCheck=function() state.aimTarget=nil end
listen(Run.Heartbeat,function(dt)
    if not state.alive then return end
    API.QuickActions.Step(dt)
    local now=os.clock()
    elapsed=elapsed+dt;state.elapsed=elapsed;speedElapsed=speedElapsed+dt;hueElapsed=hueElapsed+dt
    local char,hum,root=character();local cam=workspace.CurrentCamera
    if speedElapsed>=0.1 then speedElapsed=0;if cfg.movement or cfg.speedBoost then applySpeed() end end
    if root and hum and hum.Health>0 then
        if cfg.fly and flight and cam then
            local up=state.up;local down=state.down
            if not Input:GetFocusedTextBox() then up=up or Input:IsKeyDown(Enum.KeyCode.Space);down=down or Input:IsKeyDown(Enum.KeyCode.LeftControl) end
            local direction=hum.MoveDirection+Vector3.new(0,(up and 1 or 0)-(down and 1 or 0),0)
            if direction.Magnitude>1 then direction=direction.Unit end
            flight[2].VectorVelocity=direction*cfg.flySpeed;flight[3].CFrame=cam.CFrame.Rotation
        end
        if cfg.noclip then for i=#collisionParts,1,-1 do
            local part=collisionParts[i]
            if not part.Parent then table.remove(collisionParts,i) elseif part.CanCollide then patch("collision",part,"CanCollide",false) end
        end end
        if cfg.tpWalk and not cfg.fly then root.CFrame=root.CFrame+hum.MoveDirection*cfg.tpSpeed*math.min(dt,0.1) end
        if cfg.spin and not cfg.fly then root.CFrame=root.CFrame*CFrame.Angles(0,math.rad(cfg.spinSpeed)*dt,0) end
        if cfg.autoAttack then
            if game.GameId==10764627709 or API.Native.HasMelee() then API.Native.AttackNearest(cfg.attackRange)
            elseif now-lastAction.attack>=cfg.attackDelay and nearest(cfg.attackRange) and triggerTool(true) then lastAction.attack=now end
        end
        if cfg.autoGears and now-lastAction.gear>=cfg.gearDelay and triggerTool() then lastAction.gear=now end
    end
    if (cfg.autoPick or cfg.autoRevive) and not lastAction.promptPending and now-lastAction.prompt>=cfg.promptDelay then
        lastAction.promptPending=true
        local fired=processPrompts()
        if fired then lastAction.prompt=os.clock() end
        lastAction.promptPending=false
    end
    if cfg.lockOn then state.aimTarget=nearest(cfg.radius) end
    stepAdapters(dt)
    if hueElapsed>=0.15 then hueElapsed=0;if cfg.rainbow then refreshAccent() end end
end)
local renderBindingName="HussValleyPanelCamera_"..player.UserId
Run:BindToRenderStep(renderBindingName,Enum.RenderPriority.Camera.Value+1,function(dt)
    if not state.alive then return end
    state.frames=state.frames+1;state.time=state.time+dt
    if uiDirty and state.visible then applyAppearance() end
    if cfg.unlockMouse then patch("mouse",Input,"MouseBehavior",Enum.MouseBehavior.Default) end
    local _,hum,root=character();local cam=workspace.CurrentCamera
    if cfg.lockOn and cam and root and hum and hum.Health>0 then
        local target=state.aimTarget
        if target and target.Parent and (target.Position-root.Position).Magnitude<=cfg.radius then
            local predicted=target.Position+target.AssemblyLinearVelocity*cfg.prediction
            local pos=cam.CFrame.Position
            if (predicted-pos).Magnitude>0.1 then cam.CFrame=cam.CFrame:Lerp(CFrame.lookAt(pos,predicted),1-math.exp(-cfg.aimSmooth*dt)) end
            if cfg.faceTarget then
                local look=Vector3.new(predicted.X,root.Position.Y,predicted.Z)
                if (look-root.Position).Magnitude>0.1 then root.CFrame=CFrame.lookAt(root.Position,look) end
            end
        end
    end
    renderESP(dt) -- project current poses after all camera changes, without positional interpolation.
    if state.time>=0.75 then fpsLabel.Text=string.format("%d FPS",math.floor(state.frames/state.time+0.5));state.frames=0;state.time=0 end
end)
listen(player.CharacterAdded,function()
    stopFlight();restore("speed");restore("collision");restore("headless");restore("nameHider")
    task.spawn(function()
        local char=player.Character;if not char then return end
        char:WaitForChild("HumanoidRootPart",8)
        if not state.alive or player.Character~=char then return end
        updateFlight();applySpeed();actions.noclip(cfg.noclip);actions.headless(cfg.headless);actions.nameHider(cfg.nameHider)
        previewCharacter=nil;previewWorld:ClearAllChildren()
        refreshPreview();API.RefreshEmotes()
    end)
end)
function API.Destroy()
    if not state.alive then return end
    state.alive=false;perfToken=perfToken+1;xrayToken=xrayToken+1
    if API.UI then API.UI.Stop() end
    if API.Loading then API.Loading.Stop() end
    if API.QuickActions then API.QuickActions.Stop() end
    if API.ConfigUI then API.ConfigUI.Stop() end
    for input in pairs(pointerSessions) do pointerSessions[input]=nil end
    if API.Shaders then API.Shaders.Stop() end
    endHitTrace("panelClosed",false)
    if API.Native and API.Native.ReleaseDashInput then API.Native.ReleaseDashInput() end
    for key,name in pairs(requiresAdapter) do if cfg[key] and type(adapters[name])=="function" then pcall(adapters[name],{Enabled=false,Player=player,Config=cfg}) end end
    for _,c in ipairs(connections) do c:Disconnect() end
    Run:UnbindFromRenderStep(renderBindingName)
    if cameraSizeConnection then cameraSizeConnection:Disconnect() end
    if collisionConnection then collisionConnection:Disconnect();collisionConnection=nil end
    stopFlight();API.StopEmote()
    for group in pairs(originals) do restore(group) end
    if state.capChanged and originalFPS and type(setfpscap)=="function" then pcall(setfpscap,originalFPS) end
    for p in pairs(espRecords) do clearRecord(p) end
    visuals:Destroy();gui:Destroy()
    if env.HussValleyPanel==API then env.HussValleyPanel=nil end
end
fit();refreshTheme();selectPage("Combat")
window.Visible=false
task.defer(function()
    if not state.alive then return end
    bootProgress(0.85,"Carregando seus perfis...")
    API.RefreshConfigs();API.RefreshEmotes();local auto=loadRecord("_autoload")
    if auto and auto.enabled and type(auto.name)=="string" then API.LoadConfig(auto.name,true) end
    API.Loading.Finish(function()
        API.QuickActions.Update();show(true)
        notify("Huss Valley / painel carregado.")
    end)
end)
return API




