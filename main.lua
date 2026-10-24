-- Huss Valley Panel 0.6.33
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

-- One-time cleanup of the retired media test and its exact, panel-owned cache files.
do
    local probe=env.HussValleyVideoProbe
    if type(probe)=="table" and type(probe.Stop)=="function" then pcall(probe.Stop) end
    env.HussValleyVideoProbe=nil
    if not env.HussValleyRetiredMediaCleaned and type(delfile)=="function" then
        local complete=true
        for _,path in ipairs({"HussPanelVideo_390b9da02d00.mp4","HussPanelVideo_41a40e874d52.webm",
            "HussPanelVideo_bd61603df84a.webm","HussVideoSupport_2f1edb938a27.webm"}) do
            local remove=true
            if type(isfile)=="function" then
                local ok,exists=pcall(isfile,path);remove=ok and exists
                if not ok then complete=false end
            end
            if remove and not pcall(delfile,path) then complete=false end
        end
        if complete then env.HussValleyRetiredMediaCleaned=true end
    end
end

local defaults = {
    movement=false, speedBoost=false, walkSpeed=24, fly=false, flySpeed=50,
    noclip=false, tpWalk=false, tpSpeed=16, infiniteJump=false, spin=false, spinSpeed=120,
    autoJumpButton=false, freezeButton=false, autoJumpInterval=0.15, freezeDuration=0.12, freezeCooldown=1,
    resizeJumpButton=false, jumpButtonScale=1.5,
    resizeShiftLock=false, shiftLockScale=1.5, selectedButtonScale=1,
    mobilador=false, pcInputMode=false, mobiladorShift=true, mobiladorShiftKey="V", mobiladorRightMode="Segurar", mobiladorRecoverKey="F8",
    mobiladorCustomCamera=false, mobiladorFixedSensitivity=false, mobiladorSensitivity=1,
    mobiladorReticle=true, mobiladorReticleSize=22,
    mobiladorManual=true, mobiladorDirectLook=true, mobiladorLookSpeed=1, mobiladorCursorScope="Sempre", mobiladorReticleStyle="Cruz", mobiladorReticleColor="Branco",
    mobiladorReticleThickness=2, mobiladorReticleGap=4, mobiladorReticleOpacity=100, mobiladorReticleImage="",
    firstPerson=false, unlockMouse=false, fov=70, customFov=false, fullbright=false, xray=false,
    lockOn=false, radius=30, prediction=0.12, aimSmooth=12, faceTarget=false, teamCheck=false,
    lockMode="Console", lockButton=false, lockKey="L", lockReleaseRange=80, lockWallCheck=true, lockCameraFreedom=85,
    autoAttack=false, attackRange=12, attackDelay=0.4, autoGears=false, gearDelay=1,
    autoRevive=false, autoPick=false, promptDelay=0.6,
    chessAssistant=false,
    autoDash=false, autoZone=false, autoDown=false, autoTackle=false, dashCooldown=false,
    autoAbility=false, dashSide="Right",dashRange=15,dashDelay=1,dashKey="Q",dashKeyboardFallback=false,tackleRange=6,abilityRange=18,runnerAI=false, catcherAI=false, autoWheel=false, autoJourney=false,
    autoVote=false, disableGameAFK=false, antiIdle=false, antiHit=false,
    esp=false, boxes=true, names=true, tracers=false, health=true, distance=true,
    skeleton=false, headDot=false, healthText=false, roleColors=true, teamFilter=false, espTeams=false,
    espRange=1500, espRate=15, smoothESP=true, chams=false, viewTracer=false, nameHider=false, headless=false, -- smoothESP is accepted for old configs; geometry follows every frame.
    hitbox=false, leaderboard=false, gems=false,
    fpsBoost=false, removeTextures=true, removeDecals=true, removeParticles=true,
    lowDetail=true, noShadows=true, noFog=true, removeAccessories=false,
    unlockFPS=false, fpsCap=120, fpsUnlimited=false, lowQuality=false,
    shaders=false, shaderFloors=true, shaderWalls=true, shaderPolish=false, shaderShadows=true,
    shaderReflection=0.28, shaderWallReflection=0.14, shaderContrast=0.14, shaderSaturation=-0.06,
    shaderExposure=0.05, shaderBloom=0.12, shaderTemperature=0,
    uiScale=1, opacity=0.94, transparency=6, theme="Dark", accent="Peach", rainbow=false,
    sounds=false, notifications=true, floating=true, toggleKey="F4", autoLoad=false,
}
local cfg = {}
for key,value in pairs(defaults) do cfg[key]=value end
local connections, watchers, actions, pages, navs, accentRefreshers = {}, {}, {}, {}, {}, {}
local optionLabels,menuSurfaces,uiDirty={},{},false
local state = {alive=true, booting=true, visible=true, page="Combat", up=false, down=false, pending={}, frames=0, time=0}
local adapters = env.HussValleyAdapters or {}
local API = {Version="0.6.33", Config=cfg, Adapters=adapters,NativeStatusLabels={}}
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
        local current=object[property]
        if record[property]==nil then record[property]={current} end
        if current~=value then object[property]=value end
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
local set,refreshTheme,refreshAccent,fit,updateFlight,refreshPerformance
local requiresAdapter={autoDash="AutoDash",autoZone="AutoZone",autoDown="AutoDown",autoTackle="AutoTackle",
    dashCooldown="DashCooldown",autoAbility="AutoAbility",runnerAI="RunnerAI",catcherAI="CatcherAI",
    autoWheel="AutoSpinWheel",autoJourney="AutoClaimJourney",autoVote="AutoMapVote",disableGameAFK="DisableGameAFK",
    hitbox="HitBox",leaderboard="LeaderboardVisuals",gems="GemsAndCoins",antiHit="AntiHit"}
local ranges={walkSpeed={8,150},flySpeed={5,150},tpSpeed={1,80},spinSpeed={10,360},fov={40,120},radius={5,150},
    prediction={0,0.5},aimSmooth={1,25},lockReleaseRange={5,250},lockCameraFreedom={26,110},attackRange={2,50},attackDelay={0.15,3},gearDelay={0.2,10},
    promptDelay={0.25,3},dashRange={2,100},dashDelay={0.25,10},tackleRange={2,12},abilityRange={2,40},espRange={50,3000},espRate={2,30},fpsCap={30,240},
    shaderReflection={0,0.65},shaderWallReflection={0,0.65},shaderContrast={0,0.4},shaderSaturation={-0.4,0.4},
    shaderExposure={-1,1},shaderBloom={0,0.6},shaderTemperature={-1,1},uiScale={0.45,1.6},opacity={0.15,1},transparency={0,85},
    autoJumpInterval={0.1,1},freezeDuration={0.05,3},freezeCooldown={0.5,5},jumpButtonScale={0.5,3},shiftLockScale={0.5,3},selectedButtonScale={0.5,3},mobiladorSensitivity={0.1,3},mobiladorReticleSize={4,64},
    mobiladorReticleThickness={1,6},mobiladorReticleGap={0,16},mobiladorReticleOpacity={10,100},mobiladorLookSpeed={0.25,3}}
local function valid(key,value,keyContext)
    keyContext=keyContext or cfg
    if defaults[key]==nil or type(value)~=type(defaults[key]) then return false end
    if type(value)=="number" then
        if value~=value or math.abs(value)==math.huge then return false end
        local r=ranges[key]; if r then value=math.clamp(value,r[1],r[2]) end
    elseif key=="theme" and value~="Dark" and value~="Black" then return false
    elseif key=="accent" and not palette[value] then return false
    elseif key=="dashSide" and value~="Right" and value~="Left" then return false
    elseif key=="lockMode" and value~="Console" and value~="Classico" then return false
    elseif key=="mobiladorRightMode" and value~="Segurar" and value~="Alternar" and value~="Desligado" then return false
    elseif key=="mobiladorCursorScope" and value~="Sempre" and value~="So na captura" then return false
    elseif key=="mobiladorReticleStyle" and value~="Cruz" and value~="Ponto" and value~="Circulo" and value~="Cruz e ponto" and value~="Imagem" then return false
    elseif key=="mobiladorReticleColor" and value~="Branco" and value~="Verde" and value~="Ciano" and value~="Vermelho" and value~="Amarelo" and value~="Rosa" then return false
    elseif key=="mobiladorReticleImage" then
        if #value>80 then return false end
        value=value:match("^%s*(.-)%s*$")
        if value~="" then
            local id=value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
            if not id or #id>20 or not id:find("[1-9]") then return false end
            value="rbxassetid://"..id
        end
    elseif key=="mobiladorShiftKey" or key=="mobiladorRecoverKey" then
        local ok,k=pcall(function() return Enum.KeyCode[value] end)
        if not ok or not k or k==Enum.KeyCode.Unknown or value=="Escape" or value:match("^Button") or value:match("^DPad") or value:match("^Thumbstick") then return false end
        if value==keyContext.toggleKey or value==keyContext.lockKey then return false end
        if value=="LeftShift" or value=="RightShift" then return false end
        local other=key=="mobiladorShiftKey" and "mobiladorRecoverKey" or "mobiladorShiftKey"
        if value==keyContext[other] then return false end
    elseif key=="dashKey" and value~="Q" and value~="E" and value~="F" and value~="LeftShift" and value~="LeftControl" and value~="Space" then return false
    elseif key=="toggleKey" or key=="lockKey" then
        if value=="LeftShift" or value=="RightShift" then return false end
        local ok,k=pcall(function() return Enum.KeyCode[value] end)
        if not ok or not k or k==Enum.KeyCode.Unknown then return false end
        if key=="lockKey" and (value=="Escape" or value==keyContext.toggleKey or value:match("^Button") or value:match("^DPad") or value:match("^Thumbstick")) then return false end
        if key=="toggleKey" and value==keyContext.lockKey then return false end
        if keyContext.mobilador and (value==keyContext.mobiladorShiftKey or value==keyContext.mobiladorRecoverKey) then return false end
    end
    return true,value
end
set=function(key,value,quiet,keyContext)
    local ok,newValue=valid(key,value,keyContext); if not ok then return false end
    if newValue==true and requiresAdapter[key] and type(adapters[requiresAdapter[key]])~="function" then
        if not quiet then notify(key=="antiHit" and "Anti-Hit ainda nao validado: falta confirmar como o servidor aplica os hits." or "Essa funcao ainda precisa de integracao com o Huss Valley.") end
        return false
    end
    if key=="unlockFPS" and newValue and type(setfpscap)~="function" and type(env.setfpscap)~="function" then notify("Esta versao do executor nao fornece setfpscap."); return false end
    if key=="chessAssistant" and newValue and API.Chess and not API.Chess.IsGame() then
        API.Chess.Status("Disponivel somente no RoChess");notify("Assistente de xadrez especifico do RoChess.");return false
    end
    if key=="pcInputMode" and newValue and API.InputMode then
        local available,reason=API.InputMode.CanEnable()
        if not available then API.InputMode.Status(reason);notify(reason);return false end
    end
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
    local lock=make("LockOn","LOCK ON",0.24)
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
        local lockState=API.LockOn and (API.LockOn.StatusText or API.LockOn.Status) or "PRONTO"
        local style=quick.displayed
        if style and style.jumping==quick.jumping and style.queued==quick.freezeQueued and style.remaining==remaining
            and style.lockState==lockState
            and style.accent==accent and style.text==colors.text and style.card==colors.card and style.muted==colors.muted then return end
        style=style or {};quick.displayed=style
        style.jumping=quick.jumping;style.queued=quick.freezeQueued;style.remaining=remaining
        style.lockState=lockState
        style.accent=accent;style.text=colors.text;style.card=colors.card;style.muted=colors.muted
        jump.status.Text=quick.jumping and "LIGADO" or "DESLIGADO"
        jump.status.TextColor3=quick.jumping and Color3.fromRGB(130,231,177) or colors.muted
        jump.hit.BackgroundColor3=quick.jumping and Color3.fromRGB(25,57,46) or colors.card
        freeze.status.Text=quick.freezeQueued and "CONGELANDO..." or remaining>0 and ("COOLDOWN: "..remaining) or "PRONTO"
        freeze.status.TextColor3=(quick.freezeQueued or remaining>0) and Color3.fromRGB(246,191,128) or colors.muted
        freeze.hit.BackgroundColor3=(quick.freezeQueued or remaining>0) and Color3.fromRGB(62,44,31) or colors.card
        lock.status.Text=lockState
        lock.status.TextColor3=lockState=="TRAVADO" and Color3.fromRGB(130,231,177) or colors.muted
        lock.hit.BackgroundColor3=lockState=="TRAVADO" and Color3.fromRGB(25,57,46) or colors.card
        for _,entry in pairs(quick.buttons) do entry.edge.Color=accent;entry.title.TextColor3=colors.text end
    end
    function quick.Update()
        if not cfg.autoJumpButton then quick.jumping=false end
        if not cfg.freezeButton then quick.generation=quick.generation+1;quick.freezeQueued=false;quick.readyAt=0 end
        visibility(jump,cfg.autoJumpButton and not state.booting)
        visibility(freeze,cfg.freezeButton and not state.booting)
        visibility(lock,cfg.lockOn and cfg.lockButton and not state.booting)
        quick.Refresh()
    end
    function quick.Reset()
        if API.LockOn then API.LockOn.Reset("Pronto para escolher um alvo") end
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
    function quick.ToggleLock()
        if API.LockOn then return API.LockOn.Toggle() end
        return false
    end
    for _,item in ipairs({{jump,quick.ToggleJump},{freeze,quick.FreezeNow},{lock,quick.ToggleLock}}) do
        local entry,callback=item[1],item[2]
        listen(entry.hit.Activated,function()
            if not entry.drag.moved and os.clock()>=entry.drag.suppressUntil then callback() end
        end)
    end
    function quick.Step(dt)
        if not cfg.autoJumpButton and not cfg.freezeButton and not (cfg.lockOn and cfg.lockButton) and not quick.jumping and not quick.freezeQueued then return end
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
    actions.autoJumpButton=quick.Update;actions.freezeButton=quick.Update;actions.lockButton=quick.Update
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
c=card(left,"Player Lock On","lockOn","Console: botao ou tecla escolhe/solta o alvo. Liberdade lateral ajustavel com assistencia continua; aproxima em vista elevada e olha para cima se o alvo subir.")
cycle(c,"Modo","lockMode",{"Console","Classico"})
checkbox(c,"Mostrar botao flutuante","lockButton")
API.LockKeyButton=actionButton(c,"Tecla: L (toque para trocar)",function() if API.LockOn then API.LockOn.BeginBind() end end)
watch("lockKey",function(value) API.LockKeyButton.Text="Tecla: "..value.." (toque para trocar)" end)
actionButton(c,"Travar / soltar alvo",function() if API.LockOn then API.LockOn.Toggle() end end)
actionButton(c,"Copiar ultima soltura",function() if API.CopyLockDiagnostics then API.CopyLockDiagnostics() end end)
slider(c,"Raio para escolher alvo","radius",5,150,1," studs")
slider(c,"Soltar alem de","lockReleaseRange",5,250,1," studs")
checkbox(c,"Verificar paredes (Console)","lockWallCheck")
slider(c,"Suavidade da camera","aimSmooth",1,25,1)
slider(c,"Liberdade lateral (Console)","lockCameraFreedom",26,110,1," graus")
slider(c,"Prediction (Classico)","prediction",0,0.5,0.01,"s")
checkbox(c,"Auto Face Target","faceTarget");checkbox(c,"Ignorar mesmo time","teamCheck")
API.LockStatusLabel=text(c,"Desligado",9,{Size=UDim2.new(1,0,0,36),TextWrapped=true})
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
do
    local content=card(right,"Assistente de xadrez - RoChess","chessAssistant","Ligue durante a partida para receber sugestoes automaticamente na sua vez. Quadro arrastavel e setas no tabuleiro; usa o motor local do jogo.")
    API.ChessStatus=text(content,"Desligado",9,{Size=UDim2.new(1,0,0,36),TextWrapped=true})
    actionButton(content,"Copiar diagnostico do xadrez",function() if API.CopyChessDiagnostics then API.CopyChessDiagnostics() end end)
end
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

left,right=page("World",5)
do
    local content=card(left,"Auto Jump","autoJumpButton","Liga o botao flutuante. Toque nele para iniciar ou parar os saltos; arraste para reposicionar.")
    slider(content,"Intervalo dos saltos","autoJumpInterval",0.1,1,0.05,"s")
    content=card(left,"Botao de pulo (Roblox)","resizeJumpButton","Ajusta o botao nativo no celular. Use Editar posicoes para arrastar. Desligar restaura tamanho e posicao do jogo.")
    slider(content,"Escala do botao","jumpButtonScale",0.5,3,0.05,"x")
    API.JumpButtonSizeStatus=text(content,"Status: desligado",9,{Size=UDim2.new(1,0,0,30),TextWrapped=true})
    actionButton(content,"Restaurar tamanho original",function() set("resizeJumpButton",false) end)
    content=card(left,"Botao Shift Lock","resizeShiftLock","Ajusta o botao Shift Lock existente. Se nao for encontrado, toque em Selecionar Shift Lock e escolha o botao na tela.")
    slider(content,"Escala do Shift Lock","shiftLockScale",0.5,3,0.05,"x")
    API.ShiftLockSizeStatus=text(content,"Status: desligado",9,{Size=UDim2.new(1,0,0,34),TextWrapped=true})
    actionButton(content,"Selecionar Shift Lock",function() if API.TouchControls then API.TouchControls.PickShiftLock() end end)
    actionButton(content,"Restaurar tamanho original",function() set("resizeShiftLock",false) end)
    content=card(left,"Editar qualquer botao",nil,"Escolha um botao existente do jogo por toque. Cada selecionado tem seu tamanho e posicao. Salve um perfil para guardar; nao aciona a funcao durante a escolha.")
    actionButton(content,"Selecionar botao na tela",function() if API.TouchControls then API.TouchControls.PickButton() end end)
    actionButton(content,"Proximo selecionado",function() if API.TouchControls then API.TouchControls.NextSelected() end end)
    slider(content,"Tamanho do selecionado","selectedButtonScale",0.5,3,0.05,"x")
    API.SelectedButtonStatus=text(content,"Nenhum botao selecionado",9,{Size=UDim2.new(1,0,0,42),TextWrapped=true})
    actionButton(content,"Restaurar e remover selecionado",function() if API.TouchControls then API.TouchControls.RemoveSelected() end end)
    actionButton(content,"Restaurar todos os extras",function() if API.TouchControls then API.TouchControls.ClearSelected() end end)
    content=card(left,"Posicoes dos botoes",nil,"Ative pulo/Shift Lock ou selecione outros botoes. Toque em Editar posicoes, arraste os botoes e conclua. Salve um perfil para guardar a configuracao.")
    API.TouchEditButton=actionButton(content,"Editar posicoes",function() if API.TouchControls then API.TouchControls.ToggleEditor() end end)
    actionButton(content,"Restaurar posicoes do jogo",function() if API.TouchControls then API.TouchControls.ResetPositions() end end)
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

do
    local content=card(right,"Mobilador / mouse","mobilador","V prende / solta por padrao; esquerdo fica com o jogo. Os dois Shifts ficam com o jogo. F4 abre o painel. A entrada nativa evita disputar o giro da camera.")
    checkbox(content,"Somente a tecla prende","mobiladorManual")
    checkbox(content,"Ativar tecla de captura","mobiladorShift")
    API.MobiladorKeyButton=actionButton(content,"Tecla de captura",function() if API.Mobilador then API.Mobilador.BeginBind("mobiladorShiftKey") end end)
    watch("mobiladorShiftKey",function(v) API.MobiladorKeyButton.Text="Prender / soltar: "..v.." (trocar)" end)
    checkbox(content,"Entrada nativa sem clicar","mobiladorDirectLook")
    slider(content,"Sensibilidade da captura","mobiladorLookSpeed",0.25,3,0.05,"x")
    cycle(content,"Botao direito","mobiladorRightMode",{"Segurar","Alternar","Desligado"})
    text(content,"Botao direito e captura automatica da primeira pessoa so atuam com Somente a tecla desligado.",9,{Size=UDim2.new(1,0,0,32),TextWrapped=true})
    checkbox(content,"Cursor personalizado","mobiladorReticle")
    cycle(content,"Usar cursor","mobiladorCursorScope",{"Sempre","So na captura"})
    text(content,"Sempre: funciona mesmo com Mobilador desligado; acompanha o mouse livre e o cursor central do Shift Lock. Desenhos de botoes e miras proprias da interface do jogo ficam com o jogo.",9,{Size=UDim2.new(1,0,0,44),TextWrapped=true})
    cycle(content,"Tipo de mira","mobiladorReticleStyle",{"Cruz","Ponto","Circulo","Cruz e ponto","Imagem"})
    cycle(content,"Cor da mira","mobiladorReticleColor",{"Branco","Verde","Ciano","Vermelho","Amarelo","Rosa"})
    slider(content,"Tamanho da mira","mobiladorReticleSize",4,64,1," px")
    slider(content,"Espessura","mobiladorReticleThickness",1,6,1," px")
    slider(content,"Abertura da cruz","mobiladorReticleGap",0,16,1," px")
    slider(content,"Opacidade da mira","mobiladorReticleOpacity",10,100,1,"%")
    local imageBox=create("TextBox",{Name="CustomCursorImage",Size=UDim2.new(1,0,0,25),BackgroundTransparency=0.5,
        BackgroundColor3=colors.bg,TextColor3=colors.text,PlaceholderText="ID de imagem Roblox (mira Imagem)",Text="",TextSize=10,
        Font=Enum.Font.GothamMedium,ClearTextOnFocus=false},content)
    round(imageBox,4)
    watch("mobiladorReticleImage",function(v) if not imageBox:IsFocused() then imageBox.Text=v end end)
    listen(imageBox.FocusLost,function()
        if not set("mobiladorReticleImage",imageBox.Text,true) then notify("Use um ID numerico de imagem Roblox ou rbxassetid://ID.") end
        imageBox.Text=cfg.mobiladorReticleImage
    end)
    text(content,"Imagem privada ou indisponivel usa um ponto de reserva ate carregar. Ajustes ficam no perfil salvo.",9,{Size=UDim2.new(1,0,0,32),TextWrapped=true})
    API.MobiladorRecoverButton=actionButton(content,"Tecla de recuperacao",function() if API.Mobilador then API.Mobilador.BeginBind("mobiladorRecoverKey") end end)
    watch("mobiladorRecoverKey",function(v) API.MobiladorRecoverButton.Text="Recuperar: "..v.." (trocar)" end)
    actionButton(content,"Recuperar mouse agora",function() if API.Mobilador then API.Mobilador.Recover() end end)
    text(content,"Recuperar limpa a captura do painel e devolve a camera ao jogo. V captura novamente.",9,{Size=UDim2.new(1,0,0,32),TextWrapped=true})
    checkbox(content,"Aplicar em camera personalizada","mobiladorCustomCamera")
    checkbox(content,"Fixar multiplicador do mouse","mobiladorFixedSensitivity")
    slider(content,"Multiplicador do mouse","mobiladorSensitivity",0.1,3,0.05,"x")
    API.MobiladorStatus=text(content,"Status: desligado",9,{Size=UDim2.new(1,0,0,42),TextWrapped=true})
    actionButton(content,"Copiar diagnostico do mouse",function() if API.CopyMobiladorDiagnostics then API.CopyMobiladorDiagnostics() end end)
end

do
    local content=card(right,"Compatibilidade de teclado / mouse","pcInputMode","Modo PC opcional para consultas de entrada dos scripts do jogo. Depois de ligar, feche o painel, mova o mouse e pressione uma tecla real do jogo.")
    API.InputModeStatus=text(content,"Modo PC: desligado",9,{Size=UDim2.new(1,0,0,44),TextWrapped=true})
    text(content,"Depende das APIs do executor. Uma escolha de controles guardada pelo jogo ao entrar pode exigir integracao propria; este modo nao recria essas acoes.",9,{Size=UDim2.new(1,0,0,44),TextWrapped=true})
    actionButton(content,"Reaplicar modo PC",function()
        if cfg.pcInputMode then set("pcInputMode",false,true) end
        set("pcInputMode",true)
    end)
    actionButton(content,"Testar teclas e cliques (15s)",function() if API.InputMode then API.InputMode.BeginTest() end end)
    actionButton(content,"Encerrar teste",function() if API.InputMode then API.InputMode.EndTest("manual") end end)
    text(content,"No teste, segure o esquerdo sobre um objeto e tente sentar com Shift. Registra estados, eventos Mouse e acoes vinculadas; nao grava texto nem envia comandos.",9,{Size=UDim2.new(1,0,0,44),TextWrapped=true})
    actionButton(content,"Copiar diagnostico de entrada",function() if API.CopyInputModeDiagnostics then API.CopyInputModeDiagnostics() end end)
end

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
c=card(right,"Display & Quality",nil,"Escolha o limite e use Aplicar limite. O pedido ao executor e o FPS real aparecem separados; o aparelho e o cliente determinam o resultado.")
checkbox(c,"Low render quality","lowQuality");checkbox(c,"Unlock FPS","unlockFPS")
slider(c,"FPS Cap","fpsCap",30,240,1," fps");checkbox(c,"Sem limite","fpsUnlimited")
API.FPSStatus=text(c,"Desligado",9,{TextWrapped=true,Size=UDim2.new(1,0,0,46)})
API.FPSReadout=text(c,"Real: -- FPS | quadro: -- ms",9,{TextWrapped=true,Size=UDim2.new(1,0,0,30)})
actionButton(c,"Aplicar limite",function() if API.FPS then API.FPS.ApplySelected() end end)

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
c=card(left,"Interface",nil,"O botao aparece ao recolher a janela. Arraste o botao ou o topo do painel livremente.");cycle(c,"Toggle Menu Key","toggleKey",{"F4","Insert","Home","LeftAlt"})
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
actions.unlockMouse=function(v)
    if v and cfg.mobilador then set("mobilador",false,true) end
    if not v then restore("mouse") end
end
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
    if i.KeyCode==Enum.KeyCode.LeftShift or i.KeyCode==Enum.KeyCode.RightShift then return end
    if processed or Input:GetFocusedTextBox() then return end
    if API.LockOn and API.LockOn.binding then return end
    if API.Mobilador and API.Mobilador.bindKey then return end
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

-- Mobile button geometry and an explicit layout editor; native activation stays with the game.
do
    local T={generation=0,connections={},entries={},positions={},customKeys={},serial=0}
    API.TouchControls=T;API.JumpButtonSize=T
    T.entries.jump={label="PULO",enabled="resizeJumpButton",scale="jumpButtonScale",status=API.JumpButtonSizeStatus}
    T.entries.shift={label="SHIFT LOCK",enabled="resizeShiftLock",scale="shiftLockScale",status=API.ShiftLockSizeStatus}
    local layer=create("Frame",{Name="TouchLayoutEditor",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,ZIndex=75},gui)
    local finish=create("TextButton",{Name="FinishTouchLayout",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-16),
        Size=UDim2.new(1,-32,0,42),Text="Arraste os botoes | CONCLUIR",Font=Enum.Font.GothamBold,TextSize=13,
        TextColor3=colors.text,BackgroundColor3=colors.card,BackgroundTransparency=0.05,BorderSizePixel=0,ZIndex=84},layer)
    round(finish,8)
    local picker=create("TextButton",{Name="ChooseShiftLock",Size=UDim2.fromScale(1,1),Text="Toque no botao Shift Lock que voce usa",
        TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=colors.text,
        BackgroundTransparency=0.8,BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Visible=false,Active=true,ZIndex=82},layer)
    local function enabled(entry) return entry.custom or cfg[entry.enabled] end
    local function scaleOf(entry) return entry.custom and entry.factor or cfg[entry.scale] end
    function T.SelectedStatus()
        local entry=T.entries[T.selectedKey]
        local message=entry and (entry.label.." | "..(entry.message or "aguardando")) or "Nenhum botao selecionado"
        if API.SelectedButtonStatus.Text~=message then API.SelectedButtonStatus.Text=message end
    end
    local function status(entry,message)
        entry.message=message
        if entry.status and entry.status.Text~=message then entry.status.Text=message end
        if T.entries[T.selectedKey]==entry then T.SelectedStatus() end
    end
    local function write(object,property,value) if object[property]~=value then object[property]=value end end
    local function disconnect(list) for _,c in ipairs(list) do c:Disconnect() end end
    local function roots()
        local result,seen={},{}
        local function add(key,object) if object and not seen[object] then seen[object]=true;result[#result+1]={key=key,object=object} end end
        add("player",player:FindFirstChildOfClass("PlayerGui"))
        if type(gethui)=="function" then local ok,root=pcall(gethui);if ok then add("hui",root) end end
        local ok,core=pcall(function() return game:GetService("CoreGui") end);if ok then add("core",core) end
        return result
    end
    local function nativeJump()
        local pg=player:FindFirstChildOfClass("PlayerGui")
        local touch=pg and pg:FindFirstChild("TouchGui")
        local frame=touch and touch:FindFirstChild("TouchControlFrame")
        local b=frame and frame:FindFirstChild("JumpButton")
        if b and b:IsA("GuiButton") then return b end
    end
    local function externalButton(b)
        if not b or not b:IsA("GuiButton") or not b.Parent or not b.Parent:IsA("GuiBase2d") or b:IsDescendantOf(gui) then return false end
        if b:IsDescendantOf(player) then return true end
        for _,root in ipairs(T.scopes or roots()) do if b:IsDescendantOf(root.object) then return true end end
        return false
    end
    local function nameKey(value) return string.lower(value):gsub("[^%w]","") end
    local function shiftScore(b)
        if not externalButton(b) or b==nativeJump() then return 0 end
        local name=nameKey(b.Name)
        if name=="shiftlock" or name=="shiftlockbutton" or name=="mouselock" or name=="mouselockbutton" or name=="shiftlockicon" then return 4 end
        if b:IsA("ImageButton") then
            local image=string.lower(b.Image)
            if image:find("mouselock_",1,true) or image:find("shiftlock",1,true) then return 5 end
        elseif b:IsA("TextButton") and nameKey(b.Text)=="shiftlock" then return 4 end
        local parent=b.Parent
        for _=1,2 do
            if not parent then break end
            name=nameKey(parent.Name)
            if name=="shiftlock" or name=="shiftlockgui" or name=="mouselockgui" then return 2 end
            parent=parent.Parent
        end
        return 0
    end
    local function resolveSelector(selector)
        if not selector then return end
        for _,root in ipairs(roots()) do if root.key==selector.root then
            local object=root.object
            for i,name in ipairs(selector.path) do
                local ordinal=selector.indices and selector.indices[i] or 1
                if ordinal==1 then object=object and object:FindFirstChild(name)
                elseif object then
                    local found,count=nil,0
                    for _,child in ipairs(object:GetChildren()) do if child.Name==name then
                        count=count+1;if count==ordinal then found=child;break end
                    end end
                    object=found
                end
            end
            if externalButton(object) then return object end
        end end
    end
    local displayed
    local function findShift()
        local explicit=resolveSelector(T.selector);if explicit and explicit~=nativeJump() then return explicit end
        local current=T.entries.shift.record
        if current and externalButton(current.button) and displayed(current.button) then return current.button end
        local now=os.clock()
        if T.nextScan and now<T.nextScan then
            if not T.scanQueued then
                T.scanQueued=true;local generation=T.generation
                task.delay(T.nextScan-now,function()
                    if generation~=T.generation then return end
                    T.scanQueued=false;T.Queue("shift")
                end)
            end
            return current and externalButton(current.button) and current.button or nil
        end
        T.nextScan=now+0.5
        local best,score,tied,seen=nil,0,false,{}
        for _,root in ipairs(roots()) do
            local ok,objects=pcall(function() return root.object:GetDescendants() end)
            if ok then for _,b in ipairs(objects) do if not seen[b] then
                seen[b]=true
                local value=shiftScore(b)
                if value>0 and displayed(b) then value=value+10 end
                if value>score then best=b;score=value;tied=false elseif value>0 and value==score then tied=true end
            end end end
        end
        if not tied then return best end
    end
    displayed=function(b)
        if not b or not b.Parent then return false end
        local object=b;local screen=false
        while object do
            if object:IsA("GuiObject") and not object.Visible then return false end
            if object:IsA("ScreenGui") then if not object.Enabled then return false end;screen=true end
            object=object.Parent
        end
        return screen and b.AbsoluteSize.X>0 and b.AbsoluteSize.Y>0
    end
    function T.Release(entry)
        local r=entry.record;entry.record=nil
        if not r then return end
        disconnect(r.connections)
        pcall(function()
            if r.button.Size==r.appliedSize then r.button.Size=r.size end
            if r.button.Position==r.appliedPosition then r.button.Position=r.position end
        end)
    end
    function T.Draw()
        for _,entry in pairs(T.entries) do
            local r=entry.record;local visible=T.editing and enabled(entry) and r and displayed(r.button)
            write(entry.handle,"Visible",not not visible)
            if visible then
                local point=r.button.AbsolutePosition-layer.AbsolutePosition
                write(entry.handle,"Position",UDim2.fromOffset(point.X,point.Y))
                write(entry.handle,"Size",UDim2.fromOffset(r.button.AbsoluteSize.X,r.button.AbsoluteSize.Y))
            end
        end
    end
    function T.Apply(key,entry)
        local r=entry.record;if not r or not r.button.Parent then return end
        local parent=r.button.Parent;local view=parent.AbsoluteSize
        local screen=layer.AbsoluteSize;local origin=layer.AbsolutePosition
        local width=r.size.X.Scale*view.X+r.size.X.Offset
        local height=r.size.Y.Scale*view.Y+r.size.Y.Offset
        if view.X<=0 or view.Y<=0 or screen.X<=0 or screen.Y<=0 or width<=0 or height<=0 then status(entry,"Status: aguardando tamanho da tela");return end
        local factor=math.min(scaleOf(entry),screen.X/width,screen.Y/height)
        local anchor=r.button.AnchorPoint
        local w,h=width*factor,height*factor
        local saved=T.positions[key]
        local x,y
        if saved then
            x=origin.X+saved[1]*screen.X+(anchor.X-0.5)*w
            y=origin.Y+saved[2]*screen.Y+(anchor.Y-0.5)*h
        else
            x=parent.AbsolutePosition.X+r.position.X.Scale*view.X+r.position.X.Offset+(0.5-anchor.X)*(width-w)
            y=parent.AbsolutePosition.Y+r.position.Y.Scale*view.Y+r.position.Y.Offset+(0.5-anchor.Y)*(height-h)
        end
        if factor~=1 or saved then
            x=math.clamp(x,origin.X+anchor.X*w,origin.X+math.max(anchor.X*w,screen.X-(1-anchor.X)*w))
            y=math.clamp(y,origin.Y+anchor.Y*h,origin.Y+math.max(anchor.Y*h,screen.Y-(1-anchor.Y)*h))
        end
        local size=UDim2.new(r.size.X.Scale*factor,r.size.X.Offset*factor,r.size.Y.Scale*factor,r.size.Y.Offset*factor)
        local position=UDim2.new(r.position.X.Scale,x-parent.AbsolutePosition.X-r.position.X.Scale*view.X,
            r.position.Y.Scale,y-parent.AbsolutePosition.Y-r.position.Y.Scale*view.Y)
        r.appliedSize=size;r.appliedPosition=position;r.writing=true
        if r.button.Size~=size then r.button.Size=size end
        if r.button.Position~=position then r.button.Position=position end
        r.writing=false
        status(entry,string.format("Status: %.2fx | %.0f x %.0f px",factor,w,h))
    end
    function T.Queue(key)
        if not T.running then return end
        if type(key)=="string" then T.dirty=T.dirty or {};T.dirty[key]=true else T.fullRefresh=true end
        if T.queued then return end
        T.queued=true;local generation=T.generation
        task.defer(function()
            if generation~=T.generation then return end
            T.queued=false
            local dirty
            if not T.fullRefresh then dirty=T.dirty end
            T.dirty=nil;T.fullRefresh=nil
            if state.alive and T.running then T.Refresh(dirty) end
        end)
    end
    function T.Bind(key,entry,b)
        local r=entry.record
        if r and r.button==b and r.parent==b.Parent then return end
        if not r or r.button~=b then
            T.Release(entry)
            if not b then return end
            r={button=b,size=b.Size,position=b.Position,connections={}};entry.record=r
        else disconnect(r.connections) end
        r.parent=b.Parent
        local function queue() T.Queue(key) end
        local function geometry(property)
            if r.writing or entry.record~=r then return end
            local value=b[property]
            if value==r["applied"..property] then return end
            r[property=="Size" and "size" or "position"]=value;queue()
        end
        r.connections={b:GetPropertyChangedSignal("Size"):Connect(function() geometry("Size") end),
            b:GetPropertyChangedSignal("Position"):Connect(function() geometry("Position") end),
            b:GetPropertyChangedSignal("AnchorPoint"):Connect(queue),b:GetPropertyChangedSignal("Parent"):Connect(queue),
            b.Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue),
            b.Parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(queue)}
    end
    function T.Refresh(dirty)
        local occupied={}
        for _,key in ipairs({"jump","shift"}) do
            local entry=T.entries[key]
            if not dirty or dirty[key] then
                if enabled(entry) then
                    local b=key=="jump" and nativeJump() or nil
                    if key=="shift" then b=findShift() end
                    -- Hand ownership back before capturing the native base of an aliased control.
                    if b then for _,id in ipairs(T.customKeys) do
                        local custom=T.entries[id]
                        if custom.record and custom.record.button==b then T.Release(custom) end
                    end end
                    T.Bind(key,entry,b)
                    if entry.record then T.Apply(key,entry)
                    else status(entry,key=="shift" and "Status: toque em Selecionar Shift Lock" or "Status: aguardando botao nativo de pulo") end
                else T.Release(entry);status(entry,"Status: desligado") end
            end
            if entry.record then occupied[entry.record.button]=true end
        end
        for _,key in ipairs(T.customKeys) do
            local entry=T.entries[key];local r=entry.record
            if not dirty or dirty[key] then
                local b=r and externalButton(r.button) and r.button or resolveSelector(entry.selector)
                if occupied[b] or b==nativeJump() then b=nil end
                T.Bind(key,entry,b)
                if entry.record then T.Apply(key,entry) else status(entry,"Status: aguardando o botao selecionado") end
            end
            if entry.record then occupied[entry.record.button]=true end
        end
        if T.selectedKey and T.entries[T.selectedKey] then T.Select(T.selectedKey) end
        T.Draw()
    end
    local function cancelDrag()
        if T.drag then pointerSessions[T.drag]=nil;T.drag=nil end
    end
    function T.EndEditor()
        cancelDrag();T.editing=false
        if T.editorConnection then T.editorConnection:Disconnect();T.editorConnection=nil end
        API.TouchEditButton.Text="Editar posicoes"
        layer.Visible=T.picking==true;T.Draw()
    end
    function T.CancelPicker()
        T.picking=false;picker.Visible=false;layer.Visible=T.editing==true
        finish.Text="Arraste os botoes | CONCLUIR"
    end
    function T.Stop()
        T.running=false;T.generation=T.generation+1;T.queued=false;T.dirty=nil;T.fullRefresh=nil;T.nextScan=nil;T.scanQueued=false
        T.EndEditor();T.CancelPicker();disconnect(T.connections);T.connections={};T.scopes=nil
        for _,entry in pairs(T.entries) do T.Release(entry);status(entry,"Status: desligado") end
    end
    function T.Configure()
        if not state.alive or not (cfg.resizeJumpButton or cfg.resizeShiftLock or #T.customKeys>0) then T.Stop();return end
        if not Input.TouchEnabled then
            T.Stop();for _,entry in pairs(T.entries) do if enabled(entry) then status(entry,"Status: disponivel em dispositivos com toque") end end
            return
        end
        if not T.running then
            T.running=true;T.scopes=roots()
            local function changed(object)
                if object==gui or object:IsDescendantOf(gui) then return end
                for key,entry in pairs(T.entries) do
                    if entry.record and (object==entry.record.button or entry.record.button:IsDescendantOf(object)) then T.Queue(key) end
                end
                if #T.customKeys>0 and (object:IsA("GuiBase2d") or object:IsA("PlayerGui")) then
                    for _,key in ipairs(T.customKeys) do if not T.entries[key].record then T.Queue(key) end end
                end
                if object.Name=="JumpButton" or object.Name=="TouchControlFrame" or object.Name=="TouchGui" or object:IsA("PlayerGui")
                    or (cfg.resizeShiftLock and (not T.entries.shift.record or not displayed(T.entries.shift.record.button)) and object:IsA("GuiButton")) then T.Queue() end
            end
            T.connections={player.DescendantAdded:Connect(changed),player.DescendantRemoving:Connect(changed),
                layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() T.Queue() end),
                layer:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() T.Queue() end)}
            for _,root in ipairs(T.scopes) do if root.key~="player" then
                local ok,a,b=pcall(function() return root.object.DescendantAdded:Connect(changed),root.object.DescendantRemoving:Connect(changed) end)
                if ok then T.connections[#T.connections+1]=a;T.connections[#T.connections+1]=b end
            end end
        end
        T.Refresh()
    end
    function T.ToggleEditor()
        if T.editing then T.EndEditor();show(true);return end
        if not Input.TouchEnabled then notify("O editor e para os botoes de toque.");return end
        T.CancelPicker();T.Configure()
        local found=false
        for _,entry in pairs(T.entries) do if enabled(entry) and entry.record and displayed(entry.record.button) then found=true end end
        if not found then notify("Ative pulo/Shift Lock ou selecione um botao visivel para editar.");return end
        T.editing=true;layer.Visible=true;API.TouchEditButton.Text="Concluir edicao"
        show(false);T.Draw();T.editorConnection=Run.RenderStepped:Connect(T.Draw)
    end
    function T.ResetPositions()
        cancelDrag();T.positions={};T.Configure();notify("Posicoes originais dos botoes restauradas.")
    end
    local function selectorFor(b)
        for _,root in ipairs(roots()) do if b:IsDescendantOf(root.object) then
            local path,indices,object={},{},b
            while object and object~=root.object do
                local ordinal=0
                for _,child in ipairs(object.Parent:GetChildren()) do if child.Name==object.Name then
                    ordinal=ordinal+1;if child==object then break end
                end end
                table.insert(path,1,object.Name);table.insert(indices,1,ordinal);object=object.Parent
            end
            if object then return {root=root.key,path=path,indices=indices} end
        end end
    end
    local function underPointer(point)
        local candidates,seen,ranks,orders={},{},{},{}
        local function add(object,rank)
            local b=object
            while b and not b:IsA("GuiButton") do b=b.Parent end
            if externalButton(b) and not seen[b] and displayed(b) then
                seen[b]=true;candidates[#candidates+1]=b
                local screen=b.Parent;while screen and not screen:IsA("ScreenGui") do screen=screen.Parent end
                ranks[b]={display=screen and screen.DisplayOrder or 0,stack=rank or math.huge,z=b.ZIndex or 1}
                orders[b]=#candidates
            end
        end
        for _,root in ipairs(roots()) do
            local ok,objects=pcall(function() return root.object:GetGuiObjectsAtPosition(point.X,point.Y) end)
            if ok then for rank,object in ipairs(objects) do if not object:IsDescendantOf(gui) then add(object,rank) end end
            else
                local scanned,list=pcall(function() return root.object:GetDescendants() end)
                if scanned then for _,b in ipairs(list) do if externalButton(b) and displayed(b) then
                    local p,s=b.AbsolutePosition,b.AbsoluteSize
                    if point.X>=p.X and point.X<=p.X+s.X and point.Y>=p.Y and point.Y<=p.Y+s.Y then add(b) end
                end end end
            end
        end
        table.sort(candidates,function(a,b)
            if T.pickMode=="shift" then
                local aa,bb=shiftScore(a),shiftScore(b)
                if aa~=bb then return aa>bb end
            end
            local aa,bb=ranks[a],ranks[b]
            if aa.display~=bb.display then return aa.display>bb.display end
            if aa.stack~=bb.stack then return aa.stack<bb.stack end
            if aa.z~=bb.z then return aa.z>bb.z end
            local areaA,areaB=a.AbsoluteSize.X*a.AbsoluteSize.Y,b.AbsoluteSize.X*b.AbsoluteSize.Y
            if areaA~=areaB then return areaA<areaB end
            return orders[a]<orders[b]
        end)
        return candidates[1]
    end
    local function pick(mode)
        if not Input.TouchEnabled then notify("A selecao e para botoes de toque.");return end
        T.EndEditor();T.pickMode=mode;T.picking=true;picker.Visible=true;layer.Visible=true
        picker.Text=mode=="shift" and "Toque no botao Shift Lock que voce usa" or "Toque no botao do jogo que deseja ajustar"
        finish.Text="Cancelar selecao";show(false)
    end
    function T.PickShiftLock() pick("shift") end
    function T.PickButton() pick("custom") end
    local function copySelector(selector)
        if type(selector)~="table" or (selector.root~="player" and selector.root~="core" and selector.root~="hui") or type(selector.path)~="table" or #selector.path<1 or #selector.path>32 then return end
        local result={root=selector.root,path={},indices={}}
        if selector.indices~=nil and type(selector.indices)~="table" then return end
        for i,name in ipairs(selector.path) do
            if type(name)~="string" or #name<1 or #name>128 then return end
            local ordinal=selector.indices and selector.indices[i] or 1
            if type(ordinal)~="number" or ordinal~=math.floor(ordinal) or ordinal<1 or ordinal>512 then return end
            result.path[i]=name;result.indices[i]=ordinal
        end
        return result
    end
    function T.MakeHandle(key,entry)
        local id,current=key,entry
        current.handle=create("TextButton",{Name="Move_"..key,Text="ARRASTE\n"..entry.label,Font=Enum.Font.GothamBold,TextSize=12,
            TextColor3=colors.text,BackgroundColor3=accent,BackgroundTransparency=0.35,BorderSizePixel=0,Visible=false,Active=true,ZIndex=80},layer)
        round(current.handle,10)
        current.handleConnection=current.handle.InputBegan:Connect(function(input)
            if not T.editing or T.drag or not current.record or (input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1) then return end
            T.Select(id)
            local r=current.record;local start=input.Position
            local center=r.button.AbsolutePosition+r.button.AbsoluteSize*0.5
            T.drag=input
            beginPointer(input,function(nextInput)
                if not T.editing or current.record~=r or not r.button.Parent then return end
                local size=layer.AbsoluteSize
                if size.X<=0 or size.Y<=0 then return end
                local point=center+Vector2.new(nextInput.Position.X-start.X,nextInput.Position.Y-start.Y)-layer.AbsolutePosition
                T.positions[id]={math.clamp(point.X/size.X,0,1),math.clamp(point.Y/size.Y,0,1)}
                T.Apply(id,current);T.Draw()
            end,function() if T.drag==input then T.drag=nil end end)
        end)
    end
    for key,entry in pairs(T.entries) do T.MakeHandle(key,entry) end
    function T.Select(key)
        local entry=T.entries[key];T.selectedKey=entry and key or nil
        if entry then
            T.syncingSelection=true;set("selectedButtonScale",scaleOf(entry),true);T.syncingSelection=false
        end
        T.SelectedStatus()
    end
    function T.NextSelected()
        local keys={}
        for _,key in ipairs({"jump","shift"}) do if enabled(T.entries[key]) then keys[#keys+1]=key end end
        for _,key in ipairs(T.customKeys) do keys[#keys+1]=key end
        local index=0;for i,key in ipairs(keys) do if key==T.selectedKey then index=i;break end end
        T.Select(keys[index%math.max(1,#keys)+1])
    end
    local function removeCustom(key)
        local entry=T.entries[key];if not entry or not entry.custom then return end
        T.Release(entry)
        entry.handleConnection:Disconnect();entry.handle:Destroy()
        T.entries[key]=nil;T.positions[key]=nil
        for i,id in ipairs(T.customKeys) do if id==key then table.remove(T.customKeys,i);break end end
    end
    function T.RemoveSelected()
        local key=T.selectedKey;local entry=T.entries[key];if not entry then return end
        cancelDrag();T.positions[key]=nil
        if entry.custom then removeCustom(key) else set(entry.enabled,false,true) end
        T.selectedKey=nil;T.Configure();T.NextSelected()
    end
    function T.ClearSelected()
        T.EndEditor()
        for i=#T.customKeys,1,-1 do removeCustom(T.customKeys[i]) end
        T.Select(nil);T.Configure()
    end
    local function sameSelector(a,b)
        if a.root~=b.root or #a.path~=#b.path then return false end
        for i,name in ipairs(a.path) do
            if name~=b.path[i] or (a.indices and a.indices[i] or 1)~=(b.indices and b.indices[i] or 1) then return false end
        end
        return true
    end
    local function addCustom(selector,factor)
        if #T.customKeys>=32 then return end
        for _,key in ipairs(T.customKeys) do if sameSelector(T.entries[key].selector,selector) then return end end
        T.serial=T.serial+1;local key="custom"..T.serial
        local entry={label=selector.path[#selector.path],custom=true,selector=selector,factor=factor}
        T.entries[key]=entry;T.customKeys[#T.customKeys+1]=key;T.MakeHandle(key,entry)
        return key
    end
    function T.AddButton(b)
        if not externalButton(b) then return end
        local key
        if b==nativeJump() then key="jump"
        elseif T.entries.shift.record and T.entries.shift.record.button==b or shiftScore(b)>=4 then key="shift" end
        if key then
            for i=#T.customKeys,1,-1 do
                local id=T.customKeys[i];local entry=T.entries[id]
                if entry.record and entry.record.button==b or resolveSelector(entry.selector)==b then removeCustom(id) end
            end
            if key=="shift" then T.Release(T.entries.shift);T.selector=selectorFor(b) end
            set(T.entries[key].enabled,true,true)
        else
            for _,id in ipairs(T.customKeys) do
                local entry=T.entries[id]
                if entry.record and entry.record.button==b or resolveSelector(entry.selector)==b then key=id;break end
            end
            if not key then local selector=selectorFor(b);if selector then key=addCustom(selector,1) end end
        end
        if not key then notify("Limite de 32 botoes selecionados. Remova um para escolher outro.");return end
        T.Select(key);T.Configure();return key
    end
    local function copyPosition(p)
        if type(p)=="table" and type(p[1])=="number" and type(p[2])=="number" and p[1]==p[1] and p[2]==p[2]
            and p[1]>=0 and p[1]<=1 and p[2]>=0 and p[2]<=1 then return {p[1],p[2]} end
    end
    function T.ExportLayout()
        local result={selector=copySelector(T.selector),custom={}}
        for _,key in ipairs({"jump","shift"}) do result[key]=copyPosition(T.positions[key]) end
        for _,key in ipairs(T.customKeys) do
            local entry=T.entries[key]
            local selector=entry.record and selectorFor(entry.record.button) or entry.selector
            result.custom[#result.custom+1]={selector=copySelector(selector),scale=entry.factor,position=copyPosition(T.positions[key])}
        end
        return result
    end
    function T.ImportLayout(layout)
        T.Stop()
        for i=#T.customKeys,1,-1 do removeCustom(T.customKeys[i]) end
        T.Select(nil);T.positions={};T.selector=nil
        if type(layout)=="table" then
            T.selector=copySelector(layout.selector)
            for _,key in ipairs({"jump","shift"}) do T.positions[key]=copyPosition(layout[key]) end
            if type(layout.custom)=="table" then for i=1,math.min(32,#layout.custom) do
                local data=layout.custom[i]
                if type(data)=="table" then
                    local selector=copySelector(data.selector);local factor=data.scale
                    if selector and type(factor)=="number" and factor==factor and math.abs(factor)~=math.huge then
                        local key=addCustom(selector,math.clamp(factor,0.5,3));if key then T.positions[key]=copyPosition(data.position) end
                    end
                end
            end end
        end
        T.Configure();T.NextSelected()
    end
    function T.Destroy()
        T.Stop()
        for _,entry in pairs(T.entries) do if entry.handleConnection then entry.handleConnection:Disconnect() end end
    end
    listen(finish.Activated,function() if T.picking then T.CancelPicker() else T.EndEditor() end;show(true) end)
    listen(picker.InputBegan,function(input)
        if not T.picking or (input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1) then return end
        local b=underPointer(input.Position)
        if not b then notify("Toque no centro de um botao; Cancelar volta ao painel.");return end
        local mode=T.pickMode
        if mode=="shift" and b==nativeJump() then notify("Esse e o botao de pulo. Escolha o Shift Lock.");return end
        T.CancelPicker()
        if mode=="shift" then
            for i=#T.customKeys,1,-1 do
                local key=T.customKeys[i];local entry=T.entries[key]
                if entry.record and entry.record.button==b or resolveSelector(entry.selector)==b then removeCustom(key) end
            end
            T.Release(T.entries.shift);T.selector=selectorFor(b)
            set("resizeShiftLock",true,true);T.Select("shift");T.Configure()
        else T.AddButton(b) end
        show(true);notify("Botao selecionado. Ajuste Tamanho do selecionado ou use Editar posicoes.")
    end)
    actions.selectedButtonScale=function(value)
        if T.syncingSelection then return end
        local entry=T.entries[T.selectedKey];if not entry then return end
        if entry.custom then entry.factor=value;T.Queue(T.selectedKey)
        else set(entry.scale,value,true) end
    end
    actions.resizeJumpButton=T.Configure;actions.jumpButtonScale=T.Configure
    actions.resizeShiftLock=T.Configure;actions.shiftLockScale=T.Configure
    listen(Input:GetPropertyChangedSignal("TouchEnabled"),function() if cfg.resizeJumpButton or cfg.resizeShiftLock or #T.customKeys>0 then T.Configure() end end)
    listen(Input.WindowFocusReleased,function() if T.editing or T.picking then T.EndEditor();T.CancelPicker();show(true) end end)
end
-- End mobile button layout controls.

-- Optional mouse capture compatibility; native camera and game input handlers remain in charge.
do
    local M={running=false,connections={},records={},focused=true,cursorFocused=true,events={},stats={moves=0,nonzero=0,maxDelta=0},shift=false}
    API.Mobilador=M
    -- A passive viewport-sized canvas; shapes and images never receive game clicks.
    local markerGui=create("ScreenGui",{Name="HussMobiladorMarker",ResetOnSpawn=false,IgnoreGuiInset=true,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=2147483001,Enabled=false},gui.Parent)
    pcall(function() markerGui.ScreenInsets=Enum.ScreenInsets.None end)
    M.markerGui=markerGui
    local marker=create("Frame",{Name="CaptureMarker",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(22,22),BackgroundTransparency=1,BorderSizePixel=0,Active=false,Selectable=false},markerGui)
    M.marker=marker
    local parts={}
    local function arm(name)
        local border=create("Frame",{Name=name,AnchorPoint=Vector2.new(0.5,0.5),
            BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.12,BorderSizePixel=0,Active=false,Selectable=false},marker)
        local ink=create("Frame",{Name="Ink",Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),
            BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Active=false,Selectable=false},border)
        parts[name]={border=border,ink=ink}
        if name=="Center" then round(border,99);round(ink,99) end
    end
    for _,name in ipairs({"Left","Right","Top","Bottom","Center"}) do arm(name) end
    local circles={}
    for i=1,2 do
        local frame=create("Frame",{Name=i==1 and "CircleBorder" or "CircleInk",AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.fromScale(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Active=false,Selectable=false,ZIndex=i},marker)
        round(frame,99)
        circles[i]={frame=frame,stroke=create("UIStroke",{Color=Color3.new(0,0,0),Thickness=2},frame)}
    end
    local image=create("ImageLabel",{Name="CustomImage",Position=UDim2.fromScale(0,0),Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,Image="",Visible=false,Active=false,Selectable=false,ScaleType=Enum.ScaleType.Fit},marker)
    M.markerImage=image;M.markerParts=parts;M.markerCircles=circles;M.markerDirty=true
    local markerColors={Branco=Color3.new(1,1,1),Verde=Color3.fromRGB(80,255,100),Ciano=Color3.fromRGB(70,230,255),
        Vermelho=Color3.fromRGB(255,75,75),Amarelo=Color3.fromRGB(255,235,60),Rosa=Color3.fromRGB(255,100,215)}
    local function put(object,key,value) if object[key]~=value then object[key]=value end end
    function M.DrawMarker()
        local size=cfg.mobiladorReticleSize
        local thickness=math.min(cfg.mobiladorReticleThickness,math.max(1,(size-2)/2))
        local style,color=cfg.mobiladorReticleStyle,markerColors[cfg.mobiladorReticleColor]
        local alpha=1-cfg.mobiladorReticleOpacity/100
        M.markerSize=size;put(marker,"Size",UDim2.fromOffset(size,size))
        put(image,"Image",style=="Imagem" and cfg.mobiladorReticleImage or "");put(image,"ImageTransparency",alpha);put(image,"ImageColor3",color)
        local loaded=style=="Imagem" and cfg.mobiladorReticleImage~="" and image.IsLoaded
        put(image,"Visible",not not loaded)
        local cross=style=="Cruz" or style=="Cruz e ponto"
        local dot=style=="Ponto" or style=="Cruz e ponto" or style=="Imagem" and not loaded
        local gap=math.min(cfg.mobiladorReticleGap,math.max(0,(size-2)/2))
        local length=math.max(1,(size-2*gap)/2)
        for name,part in pairs(parts) do
            local center=name=="Center"
            put(part.border,"Visible",center and dot or not center and cross)
            put(part.border,"BackgroundTransparency",1-(1-alpha)*0.88)
            put(part.ink,"BackgroundColor3",color);put(part.ink,"BackgroundTransparency",alpha)
            local x,y,w,h=size/2,size/2,thickness,thickness
            if center then w=style=="Ponto" and size or math.max(2,thickness);h=w
            elseif name=="Left" then x=x-gap-length/2;w=length
            elseif name=="Right" then x=x+gap+length/2;w=length
            elseif name=="Top" then y=y-gap-length/2;h=length
            else y=y+gap+length/2;h=length end
            put(part.border,"Position",UDim2.fromOffset(x,y));put(part.border,"Size",UDim2.fromOffset(w+2,h+2))
        end
        for i,circle in ipairs(circles) do
            put(circle.frame,"Visible",style=="Circulo")
            local diameter=math.max(1,size-thickness-2)
            put(circle.frame,"Size",UDim2.fromOffset(diameter,diameter))
            put(circle.stroke,"Thickness",i==1 and thickness+2 or thickness)
            put(circle.stroke,"Color",i==1 and Color3.new(0,0,0) or color)
            put(circle.stroke,"Transparency",i==1 and 1-(1-alpha)*0.88 or alpha)
        end
        M.markerDirty=false
    end
    function M.CursorIcon(value)
        local r=M.cursorRecord
        if value==nil then
            M.cursorRecord=nil
            if r then pcall(function() if Input.MouseIconEnabled==r.last then Input.MouseIconEnabled=r.base end end) end
            return true
        end
        if (M.cursorFailures or 0)>=3 then return false end
        local ok=pcall(function()
            local current=Input.MouseIconEnabled
            if not r then r={base=current};M.cursorRecord=r elseif current~=r.last then r.base=current end
            if current~=value then Input.MouseIconEnabled=value end
            if Input.MouseIconEnabled~=value then error("cursor readback") end
            r.last=value
        end)
        if not ok then M.cursorFailures=(M.cursorFailures or 0)+1 end
        return ok
    end
    function M.PlaceFreeCursor()
        local ok,point=pcall(Input.GetMouseLocation,Input)
        if not ok or not point or point.X~=point.X or point.Y~=point.Y
            or math.abs(point.X)==math.huge or math.abs(point.Y)==math.huge then return false end
        put(marker,"Position",UDim2.fromOffset(point.X,point.Y))
        return true
    end
    local function drawCursor(captured)
        local global=cfg.mobiladorCursorScope=="Sempre"
        local wanted=not not (state.alive and not M.cursorDestroyed and not state.booting and M.cursorFocused and cfg.mobiladorReticle
            and (Input.MouseEnabled or Input.KeyboardEnabled or M.seenMouse or M.cursorSeenMouse)
            and (global or captured and M.running and cfg.mobilador))
        if wanted and M.markerDirty then M.DrawMarker() end
        if wanted then
            local center=not global or Input.MouseBehavior==Enum.MouseBehavior.LockCenter
            if center then put(marker,"Position",UDim2.fromScale(0.5,0.5))
            else wanted=M.PlaceFreeCursor() end
        end
        if wanted then wanted=M.CursorIcon(false)
        elseif M.running and M.cursorFocused then M.CursorIcon(not captured)
        else M.CursorIcon(nil) end
        if markerGui.Enabled~=wanted then markerGui.Enabled=wanted end
    end
    function M.SuspendCursor()
        if M.cursorFault then return end
        M.cursorFault=true;M.CursorIcon(nil);pcall(function() markerGui.Enabled=false end)
        notify("Cursor personalizado indisponivel; ponteiro original restaurado. Mude um ajuste para tentar novamente.")
    end
    function M.SetMarker(captured)
        if M.cursorFault then return end
        if not pcall(drawCursor,captured) then M.SuspendCursor() end
    end
    function M.UpdateCursor()
        M.SetMarker(M.running and M.target~=Enum.MouseBehavior.Default and Input.MouseBehavior==Enum.MouseBehavior.LockCenter
            and M.CameraAllowed(workspace.CurrentCamera,M.hum,M.root) and not M.Blocked())
    end
    function M.CursorMoved(input)
        if input.UserInputType~=Enum.UserInputType.MouseMovement or not state.alive or M.cursorDestroyed then return end
        M.cursorSeenMouse=true
        if not cfg.mobiladorReticle or M.cursorFault or (M.cursorFailures or 0)>=3 or not M.cursorFocused or state.booting then return end
        -- Position only: no styling, camera input, interpolation or pointer capture in this fast path.
        if markerGui.Enabled then
            if Input.MouseBehavior==Enum.MouseBehavior.LockCenter or cfg.mobiladorCursorScope~="Sempre" then
                put(marker,"Position",UDim2.fromScale(0.5,0.5))
            elseif M.PlaceFreeCursor() then M.cursorEventSamples=(M.cursorEventSamples or 0)+1 end
        elseif cfg.mobiladorCursorScope=="Sempre" then M.UpdateCursor() end
    end
    M.cursorConnection=listen(Input.InputChanged,function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement and not pcall(M.CursorMoved,input) then M.SuspendCursor() end
    end)
    M.imageConnection=image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
        M.markerDirty=true
        M.UpdateCursor()
    end)
    listen(Input.WindowFocusReleased,function() M.cursorFocused=false;M.SetMarker(false) end)
    listen(Input.WindowFocused,function() M.cursorFocused=true;M.UpdateCursor() end)
    local binding="HussValleyMobilador_"..player.UserId
    local finalBinding=binding.."_Capture"
    local serviceOK,GuiService=pcall(function() return game:GetService("GuiService") end)
    if not serviceOK then GuiService=nil end
    local function finite(value) return type(value)=="number" and value==value and math.abs(value)~=math.huge end
    local function enumName(value) return value and value.Name or "none" end
    function M.Release(property)
        local r=M.records[property];M.records[property]=nil
        if r then pcall(function() if Input[property]==r.last and Input[property]~=r.base then Input[property]=r.base end end) end
    end
    function M.ReleaseAll()
        M.SyncModals(false)
        M.SetMarker(false)
        M.ReleaseMouse();M.Release("MouseDeltaSensitivity")
    end
    local function applyProperty(property,value)
        local current=Input[property];local r=M.records[property]
        if not r then r={base=current};M.records[property]=r
        elseif current~=r.last and property~="MouseBehavior" then r.base=current end
        if current~=value then Input[property]=value end
        if Input[property]~=value then error("capture readback") end
        r.last=value
    end
    function M.Write(property,value)
        local ok=pcall(applyProperty,property,value)
        if not ok then
            M.failures=(M.failures or 0)+1;M.retryAt=os.clock()+0.5
            M.lastError=property;return false
        end
        return true
    end
    function M.Status(mode,message)
        if M.mode~=mode then
            M.mode=mode;M.phaseMoves=0
            if #M.events>=40 then table.remove(M.events,1) end
            M.events[#M.events+1]={at=os.clock(),mode=mode}
            M.nextStatus=nil
        end
        local now=os.clock()
        if M.nextStatus and now<M.nextStatus then return end
        M.nextStatus=now+0.3
        local value="Status: "..message
        if API.MobiladorStatus and API.MobiladorStatus.Text~=value then API.MobiladorStatus.Text=value end
    end
    function M.ClearPresses(clearShift)
        M.rightHeld=false;M.rightToggle=false;M.rightDown=false;M.keyDown=false
        M.rightSeenDown=false;M.keySeenDown=false;M.leftDown=false;M.rightPollAfter=nil;M.rightUpSince=nil;M.keyPressedAt=nil
        if clearShift then M.shift=false;M.freeRequested=false;M.nativeLocked=false;M.capturePulse=nil end
        M.ResetMotion()
    end
    function M.ExplicitFree() return cfg.mobiladorManual and M.freeRequested==true end
    function M.ReadNativeChoice()
        local native,known=M.NativeLock()
        if M.ExplicitFree() and known then
            if M.freeNativeKnown and native~=M.freeNativeValue then
                M.freeRequested=false;M.ResetMotion();M.ReleaseMouse();M.target=nil
            else M.freeNativeKnown=true;M.freeNativeValue=native end
        end
        return native,known
    end
    function M.PollKey(now)
        if not M.keyDown then return end
        local ok,down=pcall(Input.IsKeyDown,Input,Enum.KeyCode[cfg.mobiladorShiftKey])
        if ok and down then M.keySeenDown=true
        elseif ok and (M.keySeenDown or now-(M.keyPressedAt or now)>=0.2) then
            M.keyDown=false;M.keySeenDown=false;M.keyPressedAt=nil
            M.stats.keyPollReleases=(M.stats.keyPollReleases or 0)+1
        end
    end
    -- Only explicit capture suppresses modal pointer overrides. Restore each owned flag on release.
    function M.SyncModals(wanted)
        wanted=wanted==true
        if M.modalActive==wanted then return end
        M.modalActive=wanted;M.modalGeneration=(M.modalGeneration or 0)+1
        for _,connection in ipairs(M.modalConnections or {}) do connection:Disconnect() end;M.modalConnections={}
        for button,record in pairs(M.modalRecords or {}) do
            if record.connection then record.connection:Disconnect() end
            if record.base~=nil then pcall(function() if button.Modal==record.last then button.Modal=record.base end end) end
        end
        M.modalRecords={};M.modalCount=0
        if not wanted then return end
        local generation=M.modalGeneration
        local function eligible()
            return M.modalActive and generation==M.modalGeneration and M.running and state.alive
                and not M.Blocked() and M.WantsCapture() and M.CameraAllowed(workspace.CurrentCamera,M.hum,M.root)
        end
        local function watchModal(button)
            if not eligible() or M.modalRecords[button] then return end
            local ok,isButton=pcall(function() return button:IsA("GuiButton") end)
            if not ok or not isButton or not button.Parent then return end
            local record={};M.modalRecords[button]=record
            local function reconcile()
                if record.writing or (record.failures or 0)>=3 or not eligible() then return end
                local success=pcall(function()
                    if button.Modal then
                        record.base=true;record.writing=true
                        button.Modal=false;record.last=false
                        assert(button.Modal==false,"modal readback")
                        if not record.counted then
                            record.counted=true;M.modalCount=M.modalCount+1;M.capturePulse=true
                        end
                    end
                end)
                record.writing=false
                if not success then
                    record.failures=(record.failures or 0)+1;M.stats.modalFailures=(M.stats.modalFailures or 0)+1
                    if record.failures>=3 and record.connection then record.connection:Disconnect() end
                end
            end
            local linked,connection=pcall(function() return button:GetPropertyChangedSignal("Modal"):Connect(reconcile) end)
            if linked then record.connection=connection end
            reconcile()
        end
        local function removeModal(button)
            local record=M.modalRecords[button];if not record then return end
            M.modalRecords[button]=nil
            if record.connection then record.connection:Disconnect() end
            if record.base~=nil then pcall(function() if button.Modal==record.last then button.Modal=record.base end end) end
            if record.counted then M.modalCount=math.max(0,M.modalCount-1) end
        end
        local roots,seen={},{}
        local function add(root)
            if not root or seen[root] then return end
            seen[root]=true;roots[#roots+1]=root
            local ok,connection=pcall(function() return root.DescendantAdded:Connect(watchModal) end)
            if ok then M.modalConnections[#M.modalConnections+1]=connection end
            local removed,link=pcall(function() return root.DescendantRemoving:Connect(removeModal) end)
            if removed then M.modalConnections[#M.modalConnections+1]=link end
        end
        add(player)
        local ok,core=pcall(game.GetService,game,"CoreGui");if ok then add(core) end
        if type(gethui)=="function" then local got,root=pcall(gethui);if got then add(root) end end
        task.spawn(function()
            for _,root in ipairs(roots) do
                if not eligible() then return end
                local got,objects=pcall(root.GetDescendants,root)
                if got then for i,object in ipairs(objects) do
                    if not eligible() then return end
                    watchModal(object)
                    if i%300==0 then task.wait() end
                end end
            end
        end)
    end
    function M.WriteCapture(value)
        if M.capturePulse and value==Enum.MouseBehavior.LockCenter then
            M.capturePulse=nil;M.ResetMotion();M.inputCaptured=nil
            if not M.Write("MouseBehavior",Enum.MouseBehavior.Default) then M.mouseOwned=true;return false end
            M.stats.capturePulses=(M.stats.capturePulses or 0)+1
        end
        local ok=M.Write("MouseBehavior",value);M.mouseOwned=true;return ok
    end
    -- Native camera input bridge. The camera controller remains the only writer of its pose.
    function M.DetachBridge()
        local b=M.bridge;M.bridge=nil;M.frameActive=false;M.frameBridge=nil
        if not b then return end
        b.active=false
        for key,entry in pairs(b.functions) do
            pcall(function() if b.input[key]==entry.wrapper then b.input[key]=entry.previous end end)
        end
    end
    local function bridgeShape(value)
        return type(value)=="table" and type(rawget(value,"getRotation"))=="function"
            and type(rawget(value,"getRotationActivated"))=="function" and type(rawget(value,"getInputEnabled"))=="function"
            and type(rawget(value,"getZoomDelta"))=="function" and type(rawget(value,"resetInputForFrameEnd"))=="function"
    end
    function M.AttachBridge(input,source)
        if not bridgeShape(input) then M.bridgeStatus="formato indisponivel";return false end
        M.DetachBridge()
        local b={input=input,source=source,active=true,functions={}}
        local previous=input.getRotation
        b.functions.getRotation={previous=previous}
        b.functions.getRotation.wrapper=function(...)
            local original=previous(...)
            b.calls=(b.calls or 0)+1
            if not b.active or M.frameBridge~=b or not M.frameActive then return original end
            if M.frameOwned then
                M.stats.bridgeReads=(M.stats.bridgeReads or 0)+1
                return M.frameRotation
            end
            -- Outside explicit panel capture, keep the native input unless it lacks this real movement.
            if original and original.Magnitude>0.000001 then return original end
            if M.frameRotation.Magnitude>0 then M.stats.bridgeFallbackReads=(M.stats.bridgeFallbackReads or 0)+1;return M.frameRotation end
            return original
        end
        local activated=input.getRotationActivated
        b.functions.getRotationActivated={previous=activated,wrapper=function(...)
            local original=activated(...)
            if not b.active or M.frameBridge~=b or not M.frameActive then return original end
            if M.frameOwned then return M.frameRotation.Magnitude>0 end
            return original or M.frameRotation.Magnitude>0
        end}
        local ok=pcall(function()
            for key,entry in pairs(b.functions) do input[key]=entry.wrapper end
            for key,entry in pairs(b.functions) do assert(input[key]==entry.wrapper,"input bridge readback") end
        end)
        if not ok then
            b.active=false
            for key,entry in pairs(b.functions) do pcall(function() if input[key]==entry.wrapper then input[key]=entry.previous end end) end
            M.bridgeStatus="entrada protegida";return false
        end
        M.bridge=b;M.bridgeStatus="pronta: "..source;return true
    end
    function M.FindNativeCamera()
        M.nativeGeneration=(M.nativeGeneration or 0)+1;local generation=M.nativeGeneration
        M.DetachBridge();M.ResetMotion();M.scanning=true
        M.bridgeStatus="procurando entrada nativa"
        local function finish(status)
            if generation==M.nativeGeneration then M.scanning=false;if status then M.bridgeStatus=status end end
        end
        task.spawn(function()
            local native,input
            pcall(function()
                local scripts=player:FindFirstChild("PlayerScripts")
                local pm=scripts and scripts:FindFirstChild("PlayerModule")
                local cm=pm and pm:FindFirstChild("CameraModule")
                if cm and cm:IsA("ModuleScript") then
                    native=require(cm)
                    local ci=cm:FindFirstChild("CameraInput")
                    if ci and ci:IsA("ModuleScript") then input=require(ci) end
                end
            end)
            if generation~=M.nativeGeneration or not M.running then return end
            M.nativeModule=type(native)=="table" and native or nil
            if not cfg.mobiladorDirectLook then finish("entrada adicional desligada");return end
            if bridgeShape(input) then M.AttachBridge(input,"PlayerModule");finish();return end
            -- Some clients hide the module tree. Accept only one uniquely identifiable native input table.
            if type(getgc)=="function" then
                local ok,objects=pcall(getgc,true)
                if ok and type(objects)=="table" then
                    local candidate,ambiguous
                    for i,object in ipairs(objects) do
                        if generation~=M.nativeGeneration or not M.running then return end
                        if bridgeShape(object) then
                            if candidate and candidate~=object then ambiguous=true;break end
                            candidate=object
                        end
                        if i%800==0 then task.wait() end
                    end
                    if generation~=M.nativeGeneration or not M.running then return end
                    if candidate and not ambiguous then M.AttachBridge(candidate,"runtime");finish();return end
                    if ambiguous then finish("entrada ambigua");return end
                end
            end
            finish("entrada nativa nao acessivel")
        end)
    end
    function M.NativeLock()
        local module=M.nativeModule
        local controller=module and (module.activeMouseLockController or module.activeCameraController)
        if controller and type(controller.GetIsMouseLocked)=="function" then
            local ok,value=pcall(controller.GetIsMouseLocked,controller)
            if ok and type(value)=="boolean" then return value,true end
        end
        return Input.MouseBehavior==Enum.MouseBehavior.LockCenter and not M.mouseOwned,false
    end
    function M.EnsureNativeCapture(native,known)
        if M.ExplicitFree() or not native or not known or M.mouseOwned or Input.MouseBehavior==Enum.MouseBehavior.LockCenter then return true end
        local ok=pcall(function()
            Input.MouseBehavior=Enum.MouseBehavior.LockCenter
            assert(Input.MouseBehavior==Enum.MouseBehavior.LockCenter,"native capture readback")
        end)
        if ok then M.stats.nativeRepairs=(M.stats.nativeRepairs or 0)+1
        else M.failures=(M.failures or 0)+1;M.retryAt=os.clock()+0.5;M.lastError="MouseBehavior" end
        return ok
    end
    function M.ResetMotion()
        M.lookDX=0;M.lookDY=0;M.motionAt=nil;M.absPoint=nil;M.frameActive=false;M.frameBridge=nil
        M.frameRotation=Vector2.new(0,0)
    end
    function M.PrepareInput(cam,dt,owned,native)
        local b=M.bridge
        M.frameActive=false;M.frameBridge=nil
        local ok,point=pcall(Input.GetMouseLocation,Input)
        local absoluteX,absoluteY=0,0
        if ok and point and finite(point.X) and finite(point.Y) then
            if M.absPoint then absoluteX=point.X-M.absPoint.X;absoluteY=point.Y-M.absPoint.Y end
            M.absPoint=point;M.pointerPoint=point
        else M.absPoint=nil end
        if owned and Input.MouseBehavior==Enum.MouseBehavior.LockCenter and (absoluteX~=0 or absoluteY~=0) then
            M.stats.pointerChangesWhileLocked=(M.stats.pointerChangesWhileLocked or 0)+1
        end
        local x,y=M.lookDX or 0,M.lookDY or 0;M.lookDX=0;M.lookDY=0
        local free=M.ExplicitFree()
        -- Released input is transparent: never replace native rotation/activation with zero.
        if free then M.inputSource="nativa";return end
        if not b or not b.active or not cfg.mobiladorDirectLook or not (owned or native) then return end
        for key,entry in pairs(b.functions) do
            if b.input[key]~=entry.wrapper then M.DetachBridge();M.bridgeStatus="entrada alterada pelo jogo; use "..cfg.mobiladorRecoverKey;return end
        end
        local enabledOK,enabled=pcall(b.input.getInputEnabled)
        if not enabledOK or not enabled then return end
        if not M.motionAt or os.clock()-M.motionAt>0.12 then x,y=0,0 end
        local source="evento"
        if x==0 and y==0 then
            source="posicao"
            if math.abs(absoluteX)<=160 and math.abs(absoluteY)<=160 then x,y=absoluteX,absoluteY end
        end
        if math.abs(x)>400 or math.abs(y)>400 then x,y=0,0;M.stats.warps=(M.stats.warps or 0)+1 end
        local scale=math.rad(0.5)*cfg.mobiladorLookSpeed
        local limit=math.rad(720)*math.clamp(dt or 1/60,1/240,1/15)*cfg.mobiladorLookSpeed
        M.frameRotation=Vector2.new(math.clamp(x*scale,-limit,limit),math.clamp(y*scale*0.77*M.lookInvert,-limit,limit))
        M.frameOwned=owned;M.frameActive=true;M.frameBridge=b
        M.inputSource=source
        if M.frameRotation.Magnitude>0 then
            M.stats.motionFrames=(M.stats.motionFrames or 0)+1
            local key=M.leftDown and "motionWithLeft" or "motionWithoutLeft"
            M.stats[key]=(M.stats[key] or 0)+1
            if source=="posicao" then M.stats.absoluteFrames=(M.stats.absoluteFrames or 0)+1 end
        end
    end
    function M.CancelBind()
        M.bindKey=nil
        for _,connection in ipairs(M.bindConnections or {}) do connection:Disconnect() end;M.bindConnections={}
        if M.bindTimeout and type(task.cancel)=="function" then pcall(task.cancel,M.bindTimeout) end
        M.bindTimeout=nil
        if API.MobiladorKeyButton then API.MobiladorKeyButton.Text="Prender / soltar: "..cfg.mobiladorShiftKey.." (trocar)" end
        if API.MobiladorRecoverButton then API.MobiladorRecoverButton.Text="Recuperar: "..cfg.mobiladorRecoverKey.." (trocar)" end
    end
    function M.BeginBind(key)
        if not state.alive or state.booting or not state.visible then return false end
        if key~="mobiladorShiftKey" and key~="mobiladorRecoverKey" then return false end
        M.CancelBind()
        if API.LockOn and API.LockOn.CancelBind then API.LockOn.CancelBind() end
        M.bindKey=key
        local button=key=="mobiladorShiftKey" and API.MobiladorKeyButton or API.MobiladorRecoverButton
        if button then button.Text="Aperte uma tecla | Esc cancela" end
        M.bindConnections={Input.InputBegan:Connect(function(input,processed)
            if input.UserInputType~=Enum.UserInputType.Keyboard or Input:GetFocusedTextBox() then return end
            if input.KeyCode==Enum.KeyCode.Escape then M.CancelBind();return end
            if processed then return end
            if set(key,input.KeyCode.Name,true) then M.CancelBind()
            else notify("Shift fica com o jogo. Use outra tecla sem conflito com menu, Lock On ou recuperacao.") end
        end),Input.WindowFocusReleased:Connect(M.CancelBind)}
        M.bindConnections[#M.bindConnections+1]=window:GetPropertyChangedSignal("Visible"):Connect(function()
            if not window.Visible then M.CancelBind() end
        end)
        M.bindTimeout=task.delay(20,function() M.bindTimeout=nil;M.CancelBind() end)
        return true
    end
    function M.Blocked()
        if not M.focused then return "FOCO","aguardando foco do jogo" end
        if state.booting then return "CARREGANDO","aguardando carregamento" end
        if state.visible then return "MENU","cursor livre no painel" end
        if M.menuOpen then return "MENU ROBLOX","cursor livre no menu Roblox" end
        if Input:GetFocusedTextBox() then return "TEXTO","cursor livre para digitar" end
        local touch=API.TouchControls
        if touch and (touch.editing or touch.picking) then return "EDITOR","cursor livre no editor" end
        if next(pointerSessions) then return "ARRASTO","aguardando gesto da interface" end
    end
    local function localSubject(cam,hum,root)
        local subject=cam.CameraSubject
        if not subject then return false end
        return subject==hum or subject==root or (subject and subject.Parent==player.Character and subject:IsA("BasePart"))
    end
    function M.CameraAllowed(cam,hum,root)
        if not cam or not cam.Parent or not hum or hum.Health<=0 or not localSubject(cam,hum,root) then return false end
        local kind=cam.CameraType
        if kind==Enum.CameraType.Scriptable then
            local lock=API.LockOn
            return cfg.mobiladorCustomCamera or (cfg.lockOn and lock and lock.target~=nil)
        end
        return kind==Enum.CameraType.Custom or kind==Enum.CameraType.Follow or kind==Enum.CameraType.Track
            or kind==Enum.CameraType.Attach or kind==Enum.CameraType.Orbital
    end
    function M.ReleaseMouse()
        if not M.mouseOwned then return end
        local native,known=M.NativeLock()
        local r=M.records.MouseBehavior;M.records.MouseBehavior=nil
        if r and Input.MouseBehavior==r.last then
            pcall(function()
                Input.MouseBehavior=not M.ExplicitFree() and known and native and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
            end)
        end
        M.mouseOwned=false
    end
    function M.ReturnToGame()
        M.SyncModals(false);M.ResetMotion();M.inputCaptured=nil;M.capturePulse=nil
        M.Release("MouseDeltaSensitivity");M.ReleaseMouse();M.target=nil;M.inputSource="nativa"
        M.stats.nativeHandoffs=(M.stats.nativeHandoffs or 0)+1
    end
    function M.Recover()
        if not M.running then notify("Ative Mobilador para recuperar o mouse.");return end
        M.ClearPresses(true);M.freeRequested=true;M.freeNativeValue,M.freeNativeKnown=M.NativeLock()
        M.SyncModals(false);M.ResetMotion();M.failures=0;M.cursorFailures=0;M.retryAt=nil;M.lastError=nil
        M.recoverUntil=os.clock()+0.08;M.target=Enum.MouseBehavior.Default
        M.Write("MouseBehavior",M.target);M.mouseOwned=true
        M.Release("MouseDeltaSensitivity");M.FindNativeCamera();M.UpdateCursor()
        M.Status("RECUPERANDO","recuperando entrada e captura")
    end
    function M.WantsCapture()
        return M.shift or not cfg.mobiladorManual and (M.first or M.rightHeld or M.rightToggle)
    end
    function M.Step(cam,hum,root)
        M.frameActive=false;M.frameBridge=nil
        if not M.running or not state.alive or not cfg.mobilador then return end
        M.hum=hum;M.root=root
        local now=os.clock()
        if M.failures and (M.failures>=3 or M.retryAt and now<M.retryAt) then
            M.target=nil;M.ReleaseAll();M.Status("API INDISPONIVEL","captura indisponivel; use Recuperar mouse");return
        end
        local blocked,message=M.Blocked()
        if blocked then
            if M.blockedMode~=blocked then M.ClearPresses(false);M.ResetMotion() end
            M.SyncModals(false)
            M.blockedMode=blocked;M.target=Enum.MouseBehavior.Default
            M.Write("MouseBehavior",M.target);M.mouseOwned=true
            M.Release("MouseDeltaSensitivity");M.SetMarker(false);M.Status(blocked,message);return
        end
        M.blockedMode=nil
        if M.camera~=cam then M.camera=cam;M.first=false;M.ResetMotion() end
        if not M.CameraAllowed(cam,hum,root) then
            M.target=nil;M.first=false;M.ClearPresses(false);M.ReleaseAll()
            M.Status("CAMERA DO JOGO","controle com a camera do jogo");return
        end
        if not (Input.MouseEnabled or Input.KeyboardEnabled or M.seenMouse) then
            M.target=nil;M.ReleaseAll();M.Status("SEM MOUSE","aguardando mouse ou teclado");return
        end
        M.PollKey(now)
        if M.rightHeld and not M.leftDown and (not M.rightPollAfter or now>=M.rightPollAfter) then
            local ok,down=pcall(Input.IsMouseButtonPressed,Input,Enum.UserInputType.MouseButton2)
            if ok and down then M.rightSeenDown=true;M.rightUpSince=nil
            elseif ok and M.rightSeenDown then
                M.rightUpSince=M.rightUpSince or now
                if now-M.rightUpSince>=0.06 then
                    M.rightHeld=false;M.rightDown=false;M.rightSeenDown=false;M.rightUpSince=nil
                    M.stats.pollReleases=(M.stats.pollReleases or 0)+1
                end
            else M.rightUpSince=nil end
        end
        local distance=(cam.CFrame.Position-cam.Focus.Position).Magnitude
        if player.CameraMode==Enum.CameraMode.LockFirstPerson then M.first=true
        elseif finite(distance) then
            if M.first then M.first=distance<1.4 else M.first=distance<0.9 end
        else M.first=false end
        local recovering=M.recoverUntil and now<M.recoverUntil
        if not recovering then M.recoverUntil=nil end
        local owned=not recovering and M.WantsCapture()
        local wrote=true
        M.SyncModals(owned==true)
        if owned or recovering then
            M.target=owned and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
            wrote=M.WriteCapture(M.target)
        else
            if M.mouseOwned then
                if M.ExplicitFree() then M.ReturnToGame() else M.ReleaseMouse() end
            end
            M.target=nil
        end
        M.nativeLocked,M.nativeKnown=M.ReadNativeChoice()
        if cam.CameraType~=Enum.CameraType.Scriptable and not (cfg.lockOn and API.LockOn and API.LockOn.target) then
            wrote=M.EnsureNativeCapture(M.nativeLocked,M.nativeKnown) and wrote
        end
        local captured=wrote and not recovering and (owned or not M.ExplicitFree() and M.nativeLocked or Input.MouseBehavior==Enum.MouseBehavior.LockCenter)
        M.SetMarker(captured)
        if owned and cfg.mobiladorFixedSensitivity then M.Write("MouseDeltaSensitivity",cfg.mobiladorSensitivity)
        else M.Release("MouseDeltaSensitivity") end
        local mode=recovering and "RECUPERANDO" or owned and "TECLA" or captured and "CAMERA NATIVA" or "LIVRE"
        if not wrote then mode="API INDISPONIVEL" end
        local status=owned and (cfg.mobiladorShiftKey..": captura; "..(M.bridgeStatus or "entrada pendente"))
            or recovering and "recuperando mouse" or M.ExplicitFree() and ("camera com o jogo; "..cfg.mobiladorShiftKey.." captura novamente")
            or captured and "Shift / primeira pessoa com o jogo" or "mouse livre; Shift com o jogo"
        M.Status(mode,status)
    end
    function M.BeforeCamera(dt)
        if not M.running or not state.alive then return end
        local cam=workspace.CurrentCamera
        if M.Blocked() or not M.CameraAllowed(cam,M.hum,M.root) then M.SyncModals(false);M.ResetMotion();M.SetMarker(false);return end
        if M.failures and (M.failures>=3 or M.retryAt and os.clock()<M.retryAt) then M.ResetMotion();return end
        local recovering=M.recoverUntil and os.clock()<M.recoverUntil
        if recovering then M.ResetMotion();return end
        local owned=M.WantsCapture()
        M.SyncModals(owned==true)
        if owned then
            local wrote=M.WriteCapture(Enum.MouseBehavior.LockCenter)
            if not wrote then M.ResetMotion();return end
        elseif M.mouseOwned then
            if M.ExplicitFree() then M.ReturnToGame() else M.ReleaseMouse() end
        end
        if cam.CameraType==Enum.CameraType.Scriptable or cfg.lockOn and API.LockOn and API.LockOn.target then M.ResetMotion();return end
        local native,known=M.ReadNativeChoice()
        if not M.EnsureNativeCapture(native,known) then M.ResetMotion();return end
        native=not M.ExplicitFree() and (native or Input.MouseBehavior==Enum.MouseBehavior.LockCenter and not M.mouseOwned)
        if M.inputCaptured~=(owned or native) then M.ResetMotion();M.inputCaptured=owned or native end
        M.PrepareInput(cam,dt,owned,native)
    end
    function M.FinalizeCapture()
        if not M.running or not state.alive or not cfg.mobilador then return end
        if M.failures and (M.failures>=3 or M.retryAt and os.clock()<M.retryAt) then M.SyncModals(false);return end
        local cam=workspace.CurrentCamera
        if not M.CameraAllowed(cam,M.hum,M.root) then M.SyncModals(false);return end
        local blocked=M.Blocked()
        local recovering=M.recoverUntil and os.clock()<M.recoverUntil
        local owned=not blocked and not recovering and M.WantsCapture()
        M.SyncModals(owned==true)
        if blocked or recovering or owned then
            local target=owned and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
            if Input.MouseBehavior~=target then M.stats.finalCorrections=(M.stats.finalCorrections or 0)+1 end
            M.target=target;M.WriteCapture(target)
        end
        M.UpdateCursor()
    end
    local function pointerHitsUI(input)
        local point=input.Position
        if not point then return false end
        local roots,seen={},{}
        local function add(root) if root and not seen[root] then seen[root]=true;roots[#roots+1]=root end end
        add(player:FindFirstChildOfClass("PlayerGui"))
        if type(gethui)=="function" then local ok,root=pcall(gethui);if ok then add(root) end end
        local coreOK,core=pcall(function() return game:GetService("CoreGui") end);if coreOK then add(core) end
        for _,root in ipairs(roots) do
            local ok,objects=pcall(function() return root:GetGuiObjectsAtPosition(point.X,point.Y) end)
            if ok then for _,object in ipairs(objects) do
                if object:IsA("GuiButton") or object:IsA("TextBox") or object:IsA("ScrollingFrame") then return true end
            end end
        end
        return false
    end
    function M.OnBegan(input,processed)
        if not M.running or not state.alive or M.Blocked() then return end
        -- Left click belongs entirely to the game; it must never start or clear capture.
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            M.leftDown=true;M.rightSeenDown=false;M.rightPollAfter=nil;M.rightUpSince=nil
            M.stats.leftPresses=(M.stats.leftPresses or 0)+1
            return
        end
        if input.UserInputType==Enum.UserInputType.Keyboard and (input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift) then
            if not M.shift then M.freeRequested=false;M.ResetMotion() end
            M.stats.shiftEvents=(M.stats.shiftEvents or 0)+1;return
        end
        -- Native camera/aim bindings can mark real mouse input as processed, too.
        if processed and input.UserInputType==Enum.UserInputType.MouseButton2 and pointerHitsUI(input) then return end
        if input.UserInputType==Enum.UserInputType.MouseButton2 then
            if cfg.mobiladorManual or cfg.mobiladorRightMode=="Desligado" then return end
            M.seenMouse=true
            if M.rightDown then return end
            M.rightDown=true;M.rightSeenDown=false;M.rightUpSince=nil
            if cfg.mobiladorRightMode=="Alternar" then M.rightToggle=not M.rightToggle else M.rightHeld=true end
        elseif input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==Enum.KeyCode[cfg.mobiladorRecoverKey] then M.Recover()
        elseif input.UserInputType==Enum.UserInputType.Keyboard and cfg.mobiladorShift
            and input.KeyCode==Enum.KeyCode[cfg.mobiladorShiftKey] then
            local now=os.clock();M.PollKey(now)
            if M.keyDown then return end
            M.keyDown=true;M.keySeenDown=false;M.keyPressedAt=now;M.lastKeyToggleAt=now
            M.shift=not M.shift;M.freeRequested=not M.shift;M.capturePulse=M.shift or nil
            if not M.shift then M.freeNativeValue,M.freeNativeKnown=M.NativeLock() end
            if not M.shift then M.ReturnToGame() end
            M.ResetMotion()
        end
    end
    function M.OnEnded(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            M.leftDown=false;M.rightSeenDown=false;M.rightPollAfter=os.clock()+0.12;M.rightUpSince=nil
            return
        end
        if input.UserInputType==Enum.UserInputType.MouseButton2 then M.rightHeld=false;M.rightDown=false;M.rightSeenDown=false;M.rightUpSince=nil end
        if input.KeyCode==Enum.KeyCode[cfg.mobiladorShiftKey] then M.keyDown=false;M.keySeenDown=false;M.keyPressedAt=nil end
    end
    function M.OnChanged(input)
        if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
        M.seenMouse=true
        local x,y=input.Delta.X,input.Delta.Y
        if not finite(x) or not finite(y) then return end
        local stats=M.stats;stats.moves=stats.moves+1;stats.dx=x;stats.dy=y
        if x~=0 or y~=0 then stats.nonzero=stats.nonzero+1;M.phaseMoves=(M.phaseMoves or 0)+1 end
        stats.maxDelta=math.max(stats.maxDelta,math.abs(x),math.abs(y))
        if cfg.mobiladorDirectLook and not M.ExplicitFree() and (M.WantsCapture() or M.nativeLocked or Input.MouseBehavior==Enum.MouseBehavior.LockCenter) then
            M.lookDX=math.clamp((M.lookDX or 0)+x,-20000,20000);M.lookDY=math.clamp((M.lookDY or 0)+y,-20000,20000);M.motionAt=os.clock()
        end
    end
    function M.Stop()
        M.CancelBind();M.SyncModals(false);M.DetachBridge();M.ResetMotion()
        M.running=false;M.target=nil;M.camera=nil;M.first=false;M.recoverUntil=nil;M.blockedMode=nil;M.inputCaptured=nil
        M.ReleaseAll();M.ClearPresses(true);M.lastKeyToggleAt=nil
        M.nativeGeneration=(M.nativeGeneration or 0)+1;M.scanning=false;M.nativeModule=nil;M.nativeLocked=false;M.nativeKnown=false
        for _,connection in ipairs(M.connections) do connection:Disconnect() end;M.connections={}
        Run:UnbindFromRenderStep(binding);Run:UnbindFromRenderStep(finalBinding);M.Status("DESLIGADO","desligado")
    end
    function M.Destroy()
        M.cursorDestroyed=true
        if M.cursorConnection then M.cursorConnection:Disconnect();M.cursorConnection=nil end
        M.Stop();M.CursorIcon(nil);if M.imageConnection then M.imageConnection:Disconnect();M.imageConnection=nil end;markerGui:Destroy()
    end
    function M.Configure()
        if M.resolvingKeys then return end
        if not state.alive or not cfg.mobilador then M.Stop();return end
        if cfg.unlockMouse then set("unlockMouse",false,true) end
        M.resolvingKeys=true
        for _,entry in ipairs({{"mobiladorShiftKey",{"V","LeftControl","CapsLock","RightControl"}},
            {"mobiladorRecoverKey",{"F8","F6","F7","Insert"}}}) do
            local key=entry[1]
            if not valid(key,cfg[key],cfg) then for _,candidate in ipairs(entry[2]) do
                if valid(key,candidate,cfg) then set(key,candidate,true);break end
            end end
        end
        M.resolvingKeys=false
        if M.shiftKey~=cfg.mobiladorShiftKey or not cfg.mobiladorShift then M.shift=false;M.keyDown=false;M.freeRequested=false;M.lastKeyToggleAt=nil end
        if M.rightMode~=cfg.mobiladorRightMode or M.manual~=cfg.mobiladorManual then M.ClearPresses(false);M.freeRequested=false end
        M.shiftKey=cfg.mobiladorShiftKey;M.rightMode=cfg.mobiladorRightMode;M.manual=cfg.mobiladorManual;M.markerDirty=true
        M.failures=0;M.cursorFailures=0;M.retryAt=nil;M.lastError=nil
        M.lookInvert=1
        pcall(function()
            local value=UserSettings():GetService("UserGameSettings"):GetCameraYInvertValue()
            if value==1 or value==-1 then M.lookInvert=value end
        end)
        if M.running then
            if M.directLook~=cfg.mobiladorDirectLook then M.FindNativeCamera() end
            M.directLook=cfg.mobiladorDirectLook;M.UpdateCursor();return
        end
        M.running=true;M.focused=true;M.camera=workspace.CurrentCamera;M.first=false;M.directLook=cfg.mobiladorDirectLook
        M.ResetMotion();M.FindNativeCamera()
        local menuOK,opened=pcall(function() return GuiService and GuiService.MenuIsOpen end)
        M.menuOpen=menuOK and opened==true or false
        M.seenMouse=false;M.events={};M.stats={moves=0,nonzero=0,maxDelta=0}
        M.connections={Input.InputBegan:Connect(M.OnBegan),Input.InputEnded:Connect(M.OnEnded),Input.InputChanged:Connect(M.OnChanged),
            Input.WindowFocusReleased:Connect(function() M.focused=false;M.ClearPresses(false);M.target=nil;M.ReleaseAll() end),
            Input.WindowFocused:Connect(function() M.focused=true;M.ClearPresses(false);M.target=nil end),
            player.CharacterAdded:Connect(function() M.ClearPresses(true);M.ResetMotion();M.camera=nil;M.target=nil;M.ReleaseAll();M.FindNativeCamera() end)}
        if GuiService then
            M.connections[#M.connections+1]=GuiService.MenuOpened:Connect(function() M.menuOpen=true;M.ClearPresses(false);M.target=nil end)
            M.connections[#M.connections+1]=GuiService.MenuClosed:Connect(function() M.menuOpen=false;M.ClearPresses(false);M.target=nil end)
        end
        Run:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value-1,M.BeforeCamera)
        Run:BindToRenderStep(finalBinding,Enum.RenderPriority.Last.Value+1,function()
            if not pcall(M.FinalizeCapture) then set("mobilador",false,true);notify("Falha ao reconciliar captura; mouse liberado.") end
        end)
        M.Status("PRONTO","feche o painel; "..cfg.mobiladorShiftKey.." prende / solta")
    end
    function M.Snapshot()
        local cam=workspace.CurrentCamera
        local ok,preferred=pcall(function() return Input.PreferredInput.Name end)
        local gotDelta,delta=pcall(function()
            local value=Input:GetMouseDelta()
            if value and finite(value.X) and finite(value.Y) then return {value.X,value.Y} end
        end)
        local gotButton,rightDown=pcall(Input.IsMouseButtonPressed,Input,Enum.UserInputType.MouseButton2)
        local events={};for _,entry in ipairs(M.events) do events[#events+1]={at=entry.at,mode=entry.mode} end
        local stats={};for key,value in pairs(M.stats) do stats[key]=value end
        return {kind="MobiladorInput",version=API.Version,placeId=game.PlaceId,enabled=cfg.mobilador,running=M.running,
            mode=M.mode,mouseEnabled=Input.MouseEnabled,keyboardEnabled=Input.KeyboardEnabled,touchEnabled=Input.TouchEnabled,
            preferredInput=ok and preferred or "unknown",mouseBehavior=enumName(Input.MouseBehavior),
            requested=M.target and enumName(M.target) or "none",cameraType=cam and enumName(cam.CameraType) or "none",
            firstPerson=M.first,shift=M.shift,rightHeld=M.rightHeld,rightToggle=M.rightToggle,rightMode=cfg.mobiladorRightMode,
            sensitivity=Input.MouseDeltaSensitivity,delta=gotDelta and delta or nil,
            stats=stats,transitions=events,lastError=M.lastError,rightButtonReadback=gotButton and rightDown or false,
            leftDown=M.leftDown,manualOnly=cfg.mobiladorManual,captureKey=cfg.mobiladorShiftKey,
            markerEnabled=markerGui.Enabled,markerSize=cfg.mobiladorReticleSize,markerStyle=cfg.mobiladorReticleStyle,
            customImageLoaded=image.IsLoaded==true,cursorScope=cfg.mobiladorCursorScope,cursorFailures=M.cursorFailures,cursorSuspended=M.cursorFault==true,
            cursorUpdateMode="InputChanged + render",cursorEventSamples=M.cursorEventSamples or 0,
            nativeShift=M.nativeLocked,nativeShiftKnown=M.nativeKnown,bridgeStatus=M.bridgeStatus,bridgeCalls=M.bridge and M.bridge.calls or 0,
            bridgeSource=M.bridge and M.bridge.source or "none",inputSource=M.inputSource or "none",menuKey=cfg.toggleKey,shiftKeysReserved=true,
            freeRequested=M.ExplicitFree(),keyDown=M.keyDown,modalOverrides=M.modalCount or 0,finalCapturePass=true,
            releasedToGame=M.ExplicitFree() and not M.mouseOwned,nativeInputPassthrough=M.ExplicitFree() and not M.frameActive,
            pointerLocation=M.pointerPoint and {M.pointerPoint.X,M.pointerPoint.Y} or nil,
            lookPending={M.lookDX or 0,M.lookDY or 0}}
    end
    for _,key in ipairs({"mobilador","mobiladorShift","mobiladorShiftKey","mobiladorRightMode","mobiladorRecoverKey",
        "mobiladorCustomCamera","mobiladorFixedSensitivity","mobiladorSensitivity","mobiladorManual","mobiladorDirectLook","mobiladorLookSpeed"}) do actions[key]=M.Configure end
    for _,key in ipairs({"mobiladorReticle","mobiladorReticleSize","mobiladorReticleStyle","mobiladorReticleColor",
        "mobiladorReticleThickness","mobiladorReticleGap","mobiladorReticleOpacity","mobiladorReticleImage","mobiladorCursorScope"}) do
        actions[key]=function() M.markerDirty=true;M.cursorFailures=0;M.cursorFault=nil;M.UpdateCursor() end
    end
end
-- End mobilador capture compatibility.

-- Explicit input-route diagnostics: observe native state and bindings without dispatching actions.
do
    local R={connections={}}
    API.InputRoutes=R
    local watched={MouseButton1=true,LeftShift=true,RightShift=true}
    local relevant={MouseButton1=true,MouseButton2=true,LeftShift=true,RightShift=true,Keyboard=true}
    local function enum(value)
        local ok,name=pcall(function() return value.Name end)
        return ok and type(name)=="string" and name or "unknown"
    end
    local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
    -- Also used from the detection shim: property reads only, never a nested namecall.
    function R.Path(object)
        if not object then return "none" end
        local ok,path=pcall(function()
            local names={}
            for _=1,32 do
                if not object or object==game then break end
                table.insert(names,1,string.sub(object.Name,1,48));object=object.Parent
            end
            return string.sub(table.concat(names,"."),1,240)
        end)
        return ok and path or "unavailable"
    end
    local function clone(value)
        if type(value)~="table" then return value end
        local result={};for key,item in pairs(value) do result[key]=clone(item) end;return result
    end
    local function context()
        local m=API.Mobilador;local cam=workspace.CurrentCamera
        return {panelVisible=state.visible==true,mouseBehavior=enum(Input.MouseBehavior),cameraType=cam and enum(cam.CameraType) or "none",
            captureEnabled=cfg.mobilador,captureRequested=m and m.shift==true or false,captureRunning=m and m.running==true or false,
            panelLeftDown=m and m.leftDown==true or false,menuKey=cfg.toggleKey,lockKey=cfg.lockKey,
            captureKey=cfg.mobiladorShiftKey,recoverKey=cfg.mobiladorRecoverKey,nativeShiftReserved=true}
    end
    function R.Bindings()
        local ok,info=pcall(function() return game:GetService("ContextActionService"):GetAllBoundActionInfo() end)
        local result={available=ok and type(info)=="table",actions={},scanned=0,truncated=false}
        if not result.available then return result end
        for name,row in pairs(info) do
            if result.scanned>=256 then result.truncated=true;break end
            result.scanned=result.scanned+1
            if type(name)=="string" and type(row)=="table" and type(row.inputTypes)=="table" then
                local inputs,matched={},false
                for index,value in ipairs(row.inputTypes) do
                    if index>16 then result.truncated=true;break end
                    local input=enum(value);inputs[#inputs+1]=input;if relevant[input] then matched=true end
                end
                if matched then
                    if #result.actions>=32 then result.truncated=true;break end
                    result.actions[#result.actions+1]={name=string.sub(name,1,120),inputs=inputs,
                        priority=finite(row.priorityLevel) and row.priorityLevel or nil,
                        stackOrder=finite(row.stackOrder) and row.stackOrder or nil,touchButton=row.createTouchButton==true}
                end
            end
        end
        table.sort(result.actions,function(a,b) return a.name<b.name end)
        return result
    end
    function R.Listeners(mouse)
        local inspect=getconnections or env.getconnections;local environment=getfenv or env.getfenv
        local result={available=type(inspect)=="function",signals={}}
        if not result.available then return result end
        local signals={{"InputBegan",Input.InputBegan},{"InputEnded",Input.InputEnded}}
        if mouse then
            pcall(function() signals[#signals+1]={"Mouse.Button1Down",mouse.Button1Down};signals[#signals+1]={"Mouse.Button1Up",mouse.Button1Up} end)
        end
        for _,entry in ipairs(signals) do
            local ok,list=pcall(inspect,entry[2]);local row={signal=entry[1],available=ok and type(list)=="table",scanned=0,disabled=0,unknown=0,sources={}}
            result.signals[#result.signals+1]=row
            if row.available then
                local seen={}
                for _,connection in pairs(list) do
                    if row.scanned>=64 then row.truncated=true;break end
                    row.scanned=row.scanned+1
                    local got,enabled,fn=pcall(function() return connection.Enabled,connection.Function end)
                    if got and enabled==false then row.disabled=row.disabled+1 end
                    local path="unavailable"
                    if got and type(fn)=="function" and type(environment)=="function" then
                        local found,scriptObject=pcall(function() return environment(fn).script end)
                        if found and scriptObject then path=R.Path(scriptObject) end
                    end
                    if path=="unavailable" or path=="none" or path=="" then row.unknown=row.unknown+1
                    elseif not seen[path] then
                        seen[path]=true
                        if #row.sources<8 then row.sources[#row.sources+1]=path else row.truncated=true end
                    end
                end
                table.sort(row.sources)
            end
        end
        return result
    end
    local function nativeDown(name)
        if name=="MouseButton1" then return Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
        return Input:IsKeyDown(Enum.KeyCode[name])
    end
    local function sample(record,name,phase)
        local ok,value=pcall(nativeDown,name)
        if not ok or type(value)~="boolean" then record.readback.unavailable=record.readback.unavailable+1;return end
        local key=phase..(value and "Down" or "Up")
        record.readback[key]=(record.readback[key] or 0)+1
    end
    function R.MouseSample()
        local mouse=R.mouse;if not mouse then return {available=false} end
        local result={available=true}
        pcall(function() result.target=R.Path(mouse.Target);result.filter=R.Path(mouse.TargetFilter) end)
        pcall(function()
            if finite(mouse.X) and finite(mouse.Y) then result.position={x=mouse.X,y=mouse.Y} end
            local position=mouse.Hit.Position
            if finite(position.X) and finite(position.Y) and finite(position.Z) then result.hit={x=position.X,y=position.Y,z=position.Z} end
        end)
        return result
    end
    local function collecting()
        local test=R.test
        return not R.destroyed and state.alive and test and test.active and os.clock()<test.expiresAt
            and not state.booting and not state.visible and not Input:GetFocusedTextBox()
    end
    function R.Query(key,caller,normalized)
        local test=R.test;if not test or not test.active or R.destroyed or not state.alive or os.clock()>=test.expiresAt then return end
        local data=test.routes;local row=R.callers[caller]
        if not row then
            if #data.queryCallers>=16 then data.callersTruncated=true;return end
            row={script=R.Path(caller),queries={},touchLastNormalized=0};R.callers[caller]=row;data.queryCallers[#data.queryCallers+1]=row
        end
        row.queries[key]=(row.queries[key] or 0)+1
        if normalized then row.touchLastNormalized=row.touchLastNormalized+1 end
    end
    function R.Observe(input,processed,phase)
        if not collecting() then return end
        local kind=input.UserInputType
        if phase=="Changed" then
            if kind==Enum.UserInputType.MouseMovement then
                for name in pairs(R.held) do sample(R.test.routes.states[name],name,"held") end
            end
            return
        end
        local name=kind==Enum.UserInputType.Keyboard and enum(input.KeyCode) or enum(kind)
        if not watched[name] then return end
        local record=R.test.routes.states[name];sample(record,name,phase=="Began" and "began" or "ended")
        if phase=="Began" then
            record.began=record.began+1;if processed then record.processed=record.processed+1 end
            if not R.held[name] then R.held[name]=os.clock() end
            if name=="MouseButton1" then R.test.routes.mouseAtPress=R.MouseSample() end
        else
            record.ended=record.ended+1
            if R.held[name] then record.maxHeldSeconds=math.max(record.maxHeldSeconds,os.clock()-R.held[name]);R.held[name]=nil end
        end
    end
    function R.End(test)
        if R.test~=test then return end
        for _,connection in ipairs(R.connections) do connection:Disconnect() end;R.connections={}
        local held=R.held or {};R.test=nil;R.mouse=nil;R.held={};R.callers={}
        if not test.routes then return end
        for name,started in pairs(held) do
            local row=test.routes.states[name];row.heldAtEnd=true;row.maxHeldSeconds=math.max(row.maxHeldSeconds,os.clock()-started)
        end
        test.routes.bindingsEnd=R.Bindings();test.routes.contextEnd=context()
    end
    function R.Begin(test)
        if R.destroyed then return end
        if R.test then R.End(R.test) end
        R.test=test;R.held={};R.callers={}
        local data={states={},queryCallers={},legacyMouse={available=false,began=0,ended=0},contextStart=context(),bindingsStart=R.Bindings()}
        test.routes=data
        for name in pairs(watched) do data.states[name]={began=0,ended=0,processed=0,maxHeldSeconds=0,readback={unavailable=0}} end
        local got,mouse=pcall(player.GetMouse,player)
        if got and mouse then
            R.mouse=mouse
            for _,event in ipairs({{"Button1Down","began"},{"Button1Up","ended"}}) do
                local ok,connection=pcall(function() return mouse[event[1]]:Connect(function()
                    if collecting() then data.legacyMouse[event[2]]=data.legacyMouse[event[2]]+1 end
                end) end)
                if ok and connection then R.connections[#R.connections+1]=connection end
            end
            data.legacyMouse.available=#R.connections==2
        end
        data.listeners=R.Listeners(R.mouse)
        data.meaning="Observed bindings and events do not prove a callback ran or an action succeeded. Readbacks are sampled during input callbacks."
    end
    function R.Export(test) return test and test.routes and clone(test.routes) or nil end
    function R.Destroy()
        if R.test then pcall(R.End,R.test) end
        for _,connection in ipairs(R.connections) do connection:Disconnect() end;R.connections={};R.destroyed=true
    end
end
-- End explicit input-route diagnostics.

-- Optional game-input detection compatibility; never produces input or restarts character controls.
do
    local I={active=false,connections={},retired={},queries={},lastPC=Enum.UserInputType.Keyboard}
    API.InputMode=I
    local propertyNames={KeyboardEnabled=true,MouseEnabled=true,TouchEnabled=true,PreferredInput=true}
    local function capabilities()
        return {getrawmetatable=getrawmetatable or env.getrawmetatable,isreadonly=isreadonly or env.isreadonly,
            setreadonly=setreadonly or env.setreadonly,newcclosure=newcclosure or env.newcclosure,
            checkcaller=checkcaller or env.checkcaller,getcallingscript=getcallingscript or env.getcallingscript,
            getnamecallmethod=getnamecallmethod or env.getnamecallmethod}
    end
    function I.Status(message)
        I.message=message
        local label=API.InputModeStatus;local value="Modo PC: "..message
        if label and label.Text~=value then label.Text=value end
    end
    function I.CanEnable()
        if I.destroyed or not state.alive then return false,"painel encerrado" end
        local a=capabilities()
        for _,name in ipairs({"getrawmetatable","isreadonly","setreadonly","newcclosure","checkcaller","getcallingscript","getnamecallmethod"}) do
            if type(a[name])~="function" then return false,"API indisponivel: "..name end
        end
        local ok,own=pcall(a.checkcaller)
        if not ok or own~=true then return false,"origem do executor nao confirmada" end
        local enumOK,preferred=pcall(function() return Enum.PreferredInput.KeyboardAndMouse end)
        if not enumOK or not preferred then return false,"PreferredInput indisponivel neste cliente" end
        return true
    end
    local function assign(b,key,value)
        local a=b.apis
        local ok,locked=pcall(a.isreadonly,b.mt);if not ok or type(locked)~="boolean" then return false end
        if not pcall(a.setreadonly,b.mt,false) then return false end
        local wrote=pcall(function() b.mt[key]=value;assert(b.mt[key]==value,"input shim readback") end)
        local restored=pcall(a.setreadonly,b.mt,locked)
        if not restored then restored=pcall(a.setreadonly,b.mt,locked) end
        return wrote and restored
    end
    local function restore(b)
        b.active=false
        for _,key in ipairs({"__index","__namecall"}) do
            if b.installed[key] and b.mt[key]==b.wrappers[key] and assign(b,key,b.previous[key]) then b.installed[key]=false end
        end
        return not b.installed.__index and not b.installed.__namecall
    end
    local function releaseRetired()
        for index=#I.retired,1,-1 do
            if restore(I.retired[index]) then table.remove(I.retired,index) end
        end
    end
    function I.Sweep()
        releaseRetired()
        local slot=env.HussValleyTraceBridge
        if type(slot)=="table" and slot.installed and slot.handler==nil and type(slot.release)=="function" then pcall(slot.release) end
        releaseRetired()
    end
    function I.Detach()
        I.active=false
        local b=I.bridge;I.bridge=nil
        if b and not restore(b) then I.retired[#I.retired+1]=b end
        I.Sweep()
    end
    local function eligible(b)
        if not b.active or I.destroyed or not state.alive then return false end
        local ok,own=pcall(b.apis.checkcaller);if not ok or own~=false then return false end
        local got,caller=pcall(b.apis.getcallingscript);if not got or not caller then return false end
        -- Use property reads only here; no nested namecall changes the pending method name.
        local valid,allowed=pcall(function()
            local object=caller
            for _=1,64 do
                if object==b.core then return false end
                if object==game then return true end
                if not object then return false end
                if object.Name=="PlayerModule" then
                    local parent=object.Parent
                    if parent and parent.Name=="PlayerScripts" and parent.Parent==player then return false end
                end
                object=object.Parent
            end
            return false
        end)
        return valid and allowed,valid and allowed and caller or nil
    end
    local function normalizedLast(value)
        if value==Enum.UserInputType.Touch then return I.lastPC end
        return value
    end
    local function countQuery(key,caller,normalized)
        I.queries[key]=(I.queries[key] or 0)+1
        if API.InputRoutes and API.InputRoutes.test then pcall(API.InputRoutes.Query,key,caller,normalized) end
    end
    local function pcType(kind)
        if kind==Enum.UserInputType.Keyboard or kind==Enum.UserInputType.MouseMovement then return true end
        return kind and (kind.Name=="MouseButton1" or kind.Name=="MouseButton2" or kind.Name=="MouseButton3" or kind.Name=="MouseWheel")
    end
    function I.Configure(value)
        I.Detach()
        if not value then I.RefreshListeners();I.Status(I.failure or "desligado");return end
        I.failure=nil
        local available,reason=I.CanEnable()
        if not available then I.failure=reason;I.Status(reason);error(reason) end
        local a=capabilities();local got,mt=pcall(a.getrawmetatable,Input)
        if not got or type(mt)~="table" or type(mt.__index)~="function" or type(mt.__namecall)~="function" then
            I.failure="metatable de entrada indisponivel";I.Status(I.failure);error(I.failure)
        end
        local coreOK,core=pcall(game.GetService,game,"CoreGui")
        if not coreOK or not core then I.failure="escopo nativo indisponivel";I.Status(I.failure);error(I.failure) end
        local b={active=false,apis=a,mt=mt,core=core,previous={__index=mt.__index,__namecall=mt.__namecall},wrappers={},installed={}}
        b.values={KeyboardEnabled=true,MouseEnabled=true,TouchEnabled=false,PreferredInput=Enum.PreferredInput.KeyboardAndMouse}
        local lastOK,lastMethod=pcall(b.previous.__index,Input,"GetLastInputType")
        if not lastOK or type(lastMethod)~="function" then I.failure="leitura nativa indisponivel";I.Status(I.failure);error(I.failure) end
        local lastWrapper=function(self,...)
            if self==Input then
                local allowed,caller=eligible(b)
                if allowed then local value=lastMethod(self,...);countQuery("GetLastInputType",caller,value==Enum.UserInputType.Touch);return normalizedLast(value) end
            end
            return lastMethod(self,...)
        end
        local wrapped=pcall(function()
            b.lastWrapper=a.newcclosure(lastWrapper)
            b.wrappers.__index=a.newcclosure(function(self,key)
                if self==Input and b.active and (propertyNames[key] or key=="GetLastInputType") then
                    local allowed,caller=eligible(b)
                    if allowed then
                        if key=="GetLastInputType" then return b.lastWrapper end
                        countQuery(key,caller);return b.values[key]
                    end
                end
                return b.previous.__index(self,key)
            end)
            b.wrappers.__namecall=a.newcclosure(function(self,...)
                if self==Input and b.active then
                    local method=b.apis.getnamecallmethod()
                    if method=="GetLastInputType" then
                        local allowed,caller=eligible(b)
                        if allowed then local value=b.previous.__namecall(self,...);countQuery("GetLastInputType",caller,value==Enum.UserInputType.Touch);return normalizedLast(value) end
                    end
                end
                return b.previous.__namecall(self,...)
            end)
            assert(type(b.lastWrapper)=="function" and type(b.wrappers.__index)=="function" and type(b.wrappers.__namecall)=="function","input closures")
        end)
        local function install(key)
            local ok=assign(b,key,b.wrappers[key])
            if b.mt[key]==b.wrappers[key] then b.installed[key]=true end
            return ok
        end
        if not wrapped or not install("__index") or not install("__namecall") then
            if not restore(b) then I.retired[#I.retired+1]=b end
            I.failure="executor nao permitiu aplicar o modo PC";I.Status(I.failure);error(I.failure)
        end
        I.queries={};I.bridge=b;b.active=true;I.active=true;I.RefreshListeners()
        I.Status("PC solicitado; use mouse e teclado reais fora do painel")
    end
    function I.EndTest(reason)
        local test=I.test;if not test or not test.active then return false end
        test.active=false;test.endedAt=os.clock();test.reason=reason or "manual"
        if API.InputRoutes then
            local ok=pcall(API.InputRoutes.End,test)
            if not ok then test.routeError="leitura final de rotas indisponivel" end
        end
        if I.testTimer and type(task.cancel)=="function" then pcall(task.cancel,I.testTimer) end;I.testTimer=nil
        I.RefreshListeners()
        I.Status("teste encerrado: "..test.keyboard.." teclas / "..test.mouse.." cliques; copie o diagnostico")
        return true
    end
    function I.CheckExpiry()
        local test=I.test
        if test and test.active and os.clock()>=test.expiresAt then I.EndTest("tempo") end
    end
    function I.Observe(input,processed,phase)
        if I.destroyed or not state.alive then return end
        I.CheckExpiry()
        local kind=input.UserInputType
        if pcType(kind) and phase~="Ended" then I.lastPC=kind end
        local test=I.test
        if not test or not test.active or state.booting or state.visible then return end
        if Input:GetFocusedTextBox() then test.ignoredText=true;return end
        if API.InputRoutes then pcall(API.InputRoutes.Observe,input,processed,phase) end
        if phase=="Changed" then
            if kind==Enum.UserInputType.MouseMovement then
                test.moves=test.moves+1
                local delta=input.Delta
                if delta and (delta.X~=0 or delta.Y~=0) then test.movingSamples=test.movingSamples+1 end
            elseif kind and kind.Name=="MouseWheel" then test.wheels=test.wheels+1 end
            return
        end
        if kind==Enum.UserInputType.Keyboard then
            local name=input.KeyCode.Name
            local record=test.keys[name]
            if not record then
                if test.keyKinds>=32 then test.truncated=true;return end
                record={began=0,ended=0,processed=0};test.keys[name]=record;test.keyKinds=test.keyKinds+1
            end
            if phase=="Began" then
                test.keyboard=test.keyboard+1;record.began=record.began+1
                if processed then record.processed=record.processed+1 end
            else record.ended=record.ended+1 end
        elseif pcType(kind) and kind~=Enum.UserInputType.MouseMovement then
            local name=kind.Name;local record=test.buttons[name]
            if not record then record={began=0,ended=0,processed=0};test.buttons[name]=record end
            if phase=="Began" then test.mouse=test.mouse+1;record.began=record.began+1;if processed then record.processed=record.processed+1 end
            else record.ended=record.ended+1 end
        elseif phase=="Began" then test.other=test.other+1 end
    end
    function I.RefreshListeners()
        if I.active or I.test and I.test.active then
            if #I.connections>0 then return end
            I.connections={Input.InputBegan:Connect(function(input,processed) I.Observe(input,processed,"Began") end),
                Input.InputEnded:Connect(function(input,processed) I.Observe(input,processed,"Ended") end),
                Input.InputChanged:Connect(function(input,processed) I.Observe(input,processed,"Changed") end)}
        else
            for _,connection in ipairs(I.connections) do connection:Disconnect() end;I.connections={}
        end
    end
    function I.BeginTest()
        if I.destroyed or not state.alive or state.booting then return false end
        I.EndTest("reiniciado")
        local now=os.clock()
        local test={active=true,startedAt=now,expiresAt=now+15,keyboard=0,mouse=0,moves=0,movingSamples=0,wheels=0,other=0,keyKinds=0,keys={},buttons={}}
        I.test=test;I.RefreshListeners()
        I.testTimer=task.delay(15,function() if I.test==test and test.active then I.testTimer=nil;I.EndTest("tempo") end end)
        I.Status("teste de 15s; tente as teclas e cliques que nao funcionam")
        show(false)
        if API.InputRoutes then
            local ok=pcall(API.InputRoutes.Begin,test)
            if not ok then pcall(API.InputRoutes.End,test);test.routeError="coleta de rotas indisponivel" end
        end
        return true
    end
    function I.Snapshot()
        I.CheckExpiry()
        local raw={}
        for _,key in ipairs({"KeyboardEnabled","MouseEnabled","TouchEnabled","PreferredInput"}) do
            local ok,value=pcall(function() return Input[key] end)
            if ok then
                if type(value)=="boolean" then raw[key]=value else raw[key]=value and value.Name or "unknown" end
            end
        end
        local got,last=pcall(Input.GetLastInputType,Input);raw.lastInput=got and last and last.Name or "unknown"
        local available,reason=I.CanEnable();local queries={};for key,value in pairs(I.queries) do queries[key]=value end
        local test=I.test;local result
        if test then
            result={active=test.active,seconds=math.max(0,(test.endedAt or os.clock())-test.startedAt),reason=test.reason,
                keyboard=test.keyboard,mouse=test.mouse,moves=test.moves,movingSamples=test.movingSamples,wheels=test.wheels,other=test.other,
                ignoredText=test.ignoredText==true,truncated=test.truncated==true,keys={},buttons={}}
            for name,record in pairs(test.keys) do result.keys[name]={began=record.began,ended=record.ended,processed=record.processed} end
            for name,record in pairs(test.buttons) do result.buttons[name]={began=record.began,ended=record.ended,processed=record.processed} end
            if API.InputRoutes then local ok,data=pcall(API.InputRoutes.Export,test);if ok then result.routes=data end end
            result.routeError=test.routeError
        end
        return {kind="InputModeDiagnostics",version=API.Version,placeId=game.PlaceId,gameId=game.GameId,requested=cfg.pcInputMode,
            active=I.active,available=available,unavailableReason=not available and reason or nil,message=I.message,
            nativeReadings=raw,requestedReadings=I.active and {KeyboardEnabled=true,MouseEnabled=true,TouchEnabled=false,PreferredInput="KeyboardAndMouse"} or nil,
            queriesServed=queries,lastPhysicalPCType=I.lastPC.Name,scope="game scripts; executor/CoreGui/PlayerModule excluded",test=result,
            inactiveHookLeases=#I.retired,
            limitation="Does not create bindings, replay input or change decisions already cached by the game."}
    end
    function I.Destroy()
        I.destroyed=true;I.EndTest("painel encerrado");I.Detach();I.RefreshListeners()
        if API.InputRoutes then pcall(API.InputRoutes.Destroy) end
        for _,connection in ipairs(I.connections) do connection:Disconnect() end;I.connections={}
    end
    actions.pcInputMode=I.Configure
end
-- End game-input detection compatibility.

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
-- FPS requests and rendered FPS are independent: never present the requested cap as measured performance.
do
    local F={running=false,changed=false,captured=false,attempts=0,lastWrite=-math.huge,message="Desligado",Stats={}}
    API.FPS=F
    local function validCap(value) return type(value)=="number" and value==value and value>=0 and value<math.huge end
    local function setter()
        if type(setfpscap)=="function" then return setfpscap end
        if type(env.setfpscap)=="function" then return env.setfpscap end
    end
    local function reader()
        if type(getfpscap)=="function" then return getfpscap end
        if type(env.getfpscap)=="function" then return env.getfpscap end
    end
    local function capText(value) return value==0 and "sem limite" or value and string.format("%.0f",value) or "sem leitura" end
    local function matches(a,b) return a~=nil and b~=nil and ((a==0 and b==0) or (a>0 and b>0 and math.abs(a-b)<0.5)) end
    function F.ReadCap()
        local fn=reader();if not fn then return end
        local ok,value=pcall(fn);if ok and validCap(value) then return value end
    end
    local function callSetter(value)
        local fn=setter();if not fn then return false,"setfpscap indisponivel" end
        local ok,result=pcall(fn,value)
        if not ok or result==false then return false,ok and "API recusou o pedido" or tostring(result) end
        return true
    end
    function F.Refresh()
        F.Stats.requested=F.running and F.desired or nil;F.Stats.reported=F.reported
        F.Stats.measured=F.measured;F.Stats.frameMs=F.frameMs;F.Stats.message=F.message
        F.Stats.attempts=F.attempts;F.Stats.blocked=F.blocked==true
        if not state.alive then return end
        local message=F.message
        if F.running then message=message.."\nPedido: "..capText(F.desired).." | API: "..capText(F.reported) end
        if API.FPSStatus.Text~=message then API.FPSStatus.Text=message end
        local measured=F.measured and string.format("Real: %.0f FPS | quadro: %.1f ms",F.measured,F.frameMs) or "Real: -- FPS | quadro: -- ms"
        if API.FPSReadout.Text~=measured then API.FPSReadout.Text=measured end
    end
    function F.Write(clearFirst)
        F.attempts=F.attempts+1;F.lastWrite=os.clock();F.stableSince=nil
        if not setter() then F.error="setfpscap indisponivel";F.message="Executor sem API de FPS";F.blocked=true;F.reported=F.ReadCap();F.Refresh();return false end
        if not F.captured then F.original=F.ReadCap();F.captured=true end
        F.changed=true;state.capChanged=true
        local cleared,beforeClear=false,nil
        if clearFirst and F.desired~=0 then beforeClear=F.ReadCap();cleared=callSetter(0) end
        local ok,reason=callSetter(F.desired)
        F.error=not ok and reason or nil
        if not ok and cleared then
            local previous=beforeClear~=nil and beforeClear or F.original
            if previous~=nil then callSetter(previous) end
        end
        F.reported=F.ReadCap()
        if not ok then F.message="Falha ao pedir FPS ao executor"
        elseif matches(F.reported,F.desired) then F.message="Limite informado pela API confirmado"
        elseif F.reported~=nil then F.message="API ainda informa outro limite"
        else F.message="Pedido enviado; API sem confirmacao de leitura" end
        F.Refresh();return ok
    end
    function F.Stop()
        F.running=false;F.blocked=false;F.stableSince=nil
        if F.changed then
            local current=F.ReadCap()
            if current~=nil and F.desired~=nil and not matches(current,F.desired) then
                F.message="Desligado; limite atual preservado"
            elseif F.original~=nil then
                local ok=callSetter(F.original)
                if not ok then F.message="Falha ao restaurar limite anterior";F.Refresh();return false end
                F.message="Desligado; limite anterior restaurado"
            else
                F.message="Desligado; limite anterior desconhecido"
                if state.alive then notify("Sem getfpscap valido: ajuste o limite anterior no Roblox/Delta.") end
            end
        else F.message="Desligado" end
        F.changed=false;F.captured=false;F.original=nil;F.reported=F.ReadCap();state.capChanged=false
        F.Refresh();return true
    end
    function F.Configure(force)
        if not state.alive then return false end
        if not cfg.unlockFPS then
            if F.running or F.changed then return F.Stop() end
            F.Refresh();return true
        end
        local desired=cfg.fpsUnlimited and 0 or math.floor(cfg.fpsCap+0.5)
        if not force and F.running and F.desired==desired then F.Refresh();return true end
        F.running=true;F.desired=desired;F.attempts=0;F.blocked=false;F.stableSince=nil
        return F.Write(false)
    end
    function F.ApplySelected()
        if not cfg.unlockFPS then
            if not set("unlockFPS",true) then F.message="Executor sem API de FPS";F.Refresh();return false end
            return F.error==nil and F.running
        end
        return F.Configure(true)
    end
    function F.Observe(frames,elapsed)
        if not state.alive then return end
        if frames>0 and elapsed>0 then F.measured=frames/elapsed;F.frameMs=elapsed*1000/frames end
        if F.running and cfg.unlockFPS then
            F.reported=F.ReadCap();local now=os.clock()
            if matches(F.reported,F.desired) then
                F.blocked=false
                F.message=F.desired>0 and F.measured and F.measured<F.desired*0.9 and "API confirma o limite; FPS real abaixo do alvo" or "Limite informado pela API confirmado"
                F.stableSince=F.stableSince or now
                if now-F.stableSince>=5 then F.attempts=0 end
            elseif F.reported~=nil then
                F.stableSince=nil
                if F.attempts>=3 then F.blocked=true;F.message="API continua em outro limite apos 3 tentativas"
                elseif now-F.lastWrite>=1.5 then F.Write(true) end
            else
                F.message=F.error and "Falha ao pedir FPS ao executor" or "Pedido enviado; API sem confirmacao de leitura"
            end
        end
        F.Refresh()
    end
    actions.unlockFPS=function() F.Configure(false) end
    actions.fpsCap=function() F.Configure(false) end
    actions.fpsUnlimited=function() F.Configure(false) end
    listen(Input.WindowFocused,function() if state.alive and cfg.unlockFPS then F.Configure(true) end end)
    F.Refresh()
end
-- End FPS controller.

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
-- Console-style combat camera: independent recreation from the supplied videos, not recovered game code.
do
    local K={Status="DESLIGADO",message="Desligado",classicPaused=false,losClock=0,
        manualYaw=0,manualPitch=0,stick=Vector2.new(0,0),lastLookAt=-math.huge}
    API.LockOn=K
    local white=Color3.fromRGB(255,255,255)
    local marker=create("CanvasGroup",{Name="ConsoleLockReticle",AnchorPoint=Vector2.new(0.5,0.5),
        Size=UDim2.fromOffset(84,84),BackgroundTransparency=1,GroupTransparency=1,Visible=false,ZIndex=15},gui)
    local sizing=create("UIScale",{Scale=1},marker)
    local borderShape=create("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=16},marker)
    -- Bevelled octagon, with a gap at the middle of each vertical side, and a small central cross.
    for _,edge in ipairs({{22,2,62,2},{62,2,82,22},{82,22,82,34},{82,50,82,62},
        {82,62,62,82},{62,82,22,82},{22,82,2,62},{2,62,2,50},{2,34,2,22},{2,22,22,2}}) do
        local segment=line(borderShape,edge[1],edge[2],edge[3],edge[4],white,1.7);segment.ZIndex=16
    end
    for _,edge in ipairs({{37,42,47,42},{42,37,42,47}}) do
        local segment=line(marker,edge[1],edge[2],edge[3],edge[4],white,1.6);segment.ZIndex=17
    end
    K.Reticle=marker
    local query=RaycastParams.new()
    query.FilterType=Enum.RaycastFilterType.Exclude;query.IgnoreWater=true;query.RespectCanCollide=true
    local function filters(char,targetChar)
        local excluded={visuals}
        if char then excluded[#excluded+1]=char end
        if targetChar and targetChar~=char then excluded[#excluded+1]=targetChar end
        -- Avatars crossing a fight are not walls, including players that respawn after acquisition.
        for _,p in ipairs(roster) do
            local model=p.Character
            if model and model~=char and model~=targetChar then excluded[#excluded+1]=model end
        end
        query.FilterDescendantsInstances=excluded
    end
    local function clearSight(origin,point)
        local delta=point-origin
        if delta.Magnitude<0.01 then return true end
        local hit=workspace:Raycast(origin,delta,query)
        return hit==nil,hit
    end
    local function bodyPart(char,name)
        local part=char and char:FindFirstChild(name)
        if part and part.Parent==char and part:IsA("BasePart") then return part end
    end
    local function torsoPart(char)
        return bodyPart(char,"UpperTorso") or bodyPart(char,"Torso") or bodyPart(char,"LowerTorso")
    end
    local function bodyPosition(char,hum,root)
        local torso=torsoPart(char)
        if torso then
            local mode=hum and hum:GetState()
            if (hum and hum.PlatformStand) or mode==Enum.HumanoidStateType.Ragdoll or mode==Enum.HumanoidStateType.FallingDown
                or mode==Enum.HumanoidStateType.Physics or mode==Enum.HumanoidStateType.GettingUp
                or (torso.Position-root.Position).Magnitude>4 then return torso.Position end
        end
        return root.Position
    end
    local function visibleBody(origin,char,point)
        local visible,firstHit=clearSight(origin,point)
        if visible then return true end
        -- A root can sink into the floor during ragdoll while the real body stays visible.
        for index=1,2 do
            local part
            if index==1 then part=bodyPart(char,"Head") else part=torsoPart(char) end
            if part then
                local sample=part.Position+Vector3.new(0,0.2,0)
                if (sample-point).Magnitude>0.1 and clearSight(origin,sample) then return true end
            end
        end
        return false,firstHit
    end
    local function combatVisible(localChar,localPosition,targetChar,point)
        local head=bodyPart(localChar,"Head")
        local origin=head and head.Position+Vector3.new(0,0.15,0) or localPosition+Vector3.new(0,1.5,0)
        local visible,hit=visibleBody(origin,targetChar,point)
        if visible then return true end
        local torso=torsoPart(localChar)
        if torso then
            local alternate=torso.Position+Vector3.new(0,0.35,0)
            if (alternate-origin).Magnitude>0.2 and visibleBody(alternate,targetChar,point) then return true end
        end
        return false,hit
    end
    local function status(value,message,short)
        K.Status=value;K.StatusText=short or value;K.message=message or value
        if API.LockStatusLabel and API.LockStatusLabel.Text~=K.message then API.LockStatusLabel.Text=K.message end
        if API.QuickActions then API.QuickActions.Refresh() end
    end
    local function normalCameraType(kind)
        return kind==Enum.CameraType.Custom or kind==Enum.CameraType.Track or kind==Enum.CameraType.Follow
            or kind==Enum.CameraType.Orbital or kind==Enum.CameraType.Attach
    end
    local function cameraSubjectIsLocal(cam,hum,root)
        local subject=cam.CameraSubject
        return subject==hum or subject==root
            or (subject and subject.Parent==player.Character and subject:IsA("BasePart"))
    end
    local function restoreCamera()
        local saved=K.saved;K.saved=nil
        if saved and not K.suspended and saved.camera.Parent and saved.camera.CameraType==Enum.CameraType.Scriptable then
            saved.camera.CameraType=saved.kind
        end
    end
    function K.ClearLook()
        K.manualYaw=0;K.manualPitch=0;K.stick=Vector2.new(0,0)
        K.lookTouch=nil;K.lastLookAt=-math.huge;K.gestureAt=-math.huge
    end
    local function canLook()
        return state.alive and not state.booting and cfg.lockOn and cfg.lockMode=="Console"
            and K.target~=nil and not K.suspended and not K.binding and not Input:GetFocusedTextBox()
    end
    function K.AddLook(x,y,sensitivity)
        -- Lateral freedom is independent of tracking strength and the vertical camera curve.
        if x==0 and y==0 then return end
        local limit=math.rad(cfg.lockCameraFreedom)
        K.manualYaw=math.clamp(K.manualYaw-math.clamp(x*sensitivity,-0.2,0.2),-limit,limit)
        K.manualPitch=math.clamp(K.manualPitch-math.clamp(y*sensitivity,-0.16,0.16),-math.rad(18),math.rad(18))
        K.lastLookAt=os.clock()
    end
    function K.LookBegan(input,processed)
        if not canLook() or processed or pointerSessions[input] then return end
        if input.UserInputType==Enum.UserInputType.Touch and not K.lookTouch then
            local cam=workspace.CurrentCamera;if not cam then return end
            local view=cam.ViewportSize
            -- Leave the lower-left movement area to the virtual thumbstick.
            if input.Position.X<view.X*0.4 and input.Position.Y>view.Y*0.35 then return end
            K.lookTouch=input;K.gestureAt=os.clock()
        elseif input.UserInputType==Enum.UserInputType.MouseButton2 then
            K.gestureAt=os.clock()
        end
    end
    function K.LookChanged(input,processed)
        if not canLook() then return end
        if input.KeyCode==Enum.KeyCode.Thumbstick2 then
            local stick=processed and Vector2.new(0,0) or Vector2.new(input.Position.X,input.Position.Y)
            if stick.Magnitude>0.16 and K.stick.Magnitude<=0.16 then K.gestureAt=os.clock() end
            K.stick=stick
        elseif input==K.lookTouch and not pointerSessions[input] then
            local cam=workspace.CurrentCamera;if not cam then return end
            local sensitivity=math.rad(150)/math.max(320,math.min(cam.ViewportSize.X,cam.ViewportSize.Y))
            K.AddLook(input.Delta.X,input.Delta.Y,sensitivity)
        elseif input.UserInputType==Enum.UserInputType.MouseMovement and not processed
            and (Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or Input.MouseBehavior~=Enum.MouseBehavior.Default) then
            K.AddLook(input.Delta.X,input.Delta.Y,0.0035)
        end
    end
    function K.LookEnded(input)
        if input==K.lookTouch then K.lookTouch=nil end
        if input.KeyCode==Enum.KeyCode.Thumbstick2 then K.stick=Vector2.new(0,0) end
    end
    function K.StepLook(dt)
        local step=math.clamp(dt,0,0.1)
        if not canLook() then K.ClearLook();return end
        local magnitude=K.stick.Magnitude
        if magnitude>0.16 then
            local stick=K.stick*((math.min(1,magnitude)-0.16)/(0.84*magnitude))
            K.AddLook(stick.X,-stick.Y,math.rad(105)*step)
        end
        -- A resting finger must not freeze an old offset away from the target.
        if os.clock()-K.lastLookAt>0.14 then
            local decay=math.exp(-3.8*step)
            K.manualYaw=K.manualYaw*decay;K.manualPitch=K.manualPitch*decay
        end
    end
    function K.Release(message,reason)
        local short
        if K.target then
            local char,hum,root=character();local cam=workspace.CurrentCamera
            reason=reason or "reset"
            K.LastRelease={message=message or "Alvo solto",reason=reason,at=os.clock(),
                cameraType=cam and cam.CameraType.Name or "none",
                nativeCameraType=K.saved and K.saved.kind.Name or nil,suspended=K.suspended,
                distance=root and (bodyPosition(K.target.char,K.target.hum,K.target.root)-bodyPosition(char,hum,root)).Magnitude or nil,
                captureRadius=cfg.radius,releaseRange=math.max(cfg.radius,cfg.lockReleaseRange),
                health=K.target.hum and K.target.hum.Health or nil,recoveries=K.CameraRecoveries or 0,
                occlusion=reason=="occluded" and K.LastOcclusion or nil}
            local labels={manual="SOLTO",camera="CAMERA",reset="REINICIADO",character="RESPAWN",parts="CORPO",dead="ALVO MORTO",left="SAIU",team="TIME",range="ALCANCE",occluded="PAREDE",localCharacter="PERSONAGEM",config="AJUSTE"}
            short=labels[reason] or "PRONTO"
            if reason=="range" and K.LastRelease.distance then short=string.format("ALCANCE %.1f/%.0f",K.LastRelease.distance,K.LastRelease.releaseRange) end
        end
        restoreCamera()
        K.ClearLook()
        K.target=nil;K.localCharacter=nil;K.heading=nil;K.rig=nil;K.occludedAt=nil;K.losClock=0;K.suspended=nil;state.aimTarget=nil
        if marker.Visible then K.fadeAt=os.clock() end
        status(cfg.lockOn and "PRONTO" or "DESLIGADO",cfg.lockOn and (message or "Aperte o botao ou "..cfg.lockKey.." para escolher um alvo") or "Desligado",cfg.lockOn and short or nil)
    end
    function K.Reset(message,reason)
        if K.CancelBind then K.CancelBind() end
        K.classicPaused=true
        K.Release(message,reason or "reset")
    end
    local function liveTarget(target,localPosition)
        if not target or target.player.Parent~=Players then return false,"left" end
        if target.player.Character~=target.char then return false,"character" end
        local a=actor(target.player)
        if not a.hum or not a.root or a.hum.Parent~=target.char or a.root.Parent~=target.char then return false,"parts" end
        if a.hum.Health<=0 then return false,"dead" end
        if cfg.teamCheck and sameTeam(target.player) then return false,"team" end
        -- A rebuilt root/humanoid inside the same character is still the same selected opponent.
        target.hum=a.hum;target.root=a.root;state.aimTarget=a.root
        target.position=bodyPosition(a.char,a.hum,a.root)
        return (target.position-localPosition).Magnitude<=math.max(cfg.radius,cfg.lockReleaseRange),"range"
    end
    function K.Pick(cam,localChar,localRoot)
        local best,bestScore,bestDistance
        local view=cam.ViewportSize
        if view.X<=0 or view.Y<=0 then return end
        local localPosition=bodyPosition(localChar,actor(player).hum,localRoot)
        filters(localChar)
        for _,p in ipairs(roster) do
            if p~=player and p.Parent==Players and not (cfg.teamCheck and sameTeam(p)) then
                local a=actor(p)
                if a.char and a.hum and a.hum.Health>0 and a.root and a.root.Parent==a.char then
                    local targetPosition=bodyPosition(a.char,a.hum,a.root)
                    local distance=(targetPosition-localPosition).Magnitude
                    if distance<=cfg.radius then
                        local aimPoint=targetPosition+Vector3.new(0,0.5,0)
                        local point,onScreen=cam:WorldToViewportPoint(aimPoint)
                        if onScreen and point.Z>0.1 then
                            if not cfg.lockWallCheck or visibleBody(cam.CFrame.Position,a.char,aimPoint) then
                                local x,y=(point.X-view.X*0.5)/view.X,(point.Y-view.Y*0.5)/view.Y
                                local score=x*x+y*y
                                if not bestScore or score<bestScore-0.000001 or (math.abs(score-bestScore)<=0.000001 and distance<bestDistance) then
                                    best={player=p,char=a.char,hum=a.hum,root=a.root};bestScore=score;bestDistance=distance
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end
    function K.Toggle()
        if not state.alive or state.booting or not cfg.lockOn or Input:GetFocusedTextBox() then return false end
        if cfg.lockMode=="Classico" then
            K.classicPaused=not K.classicPaused;K.Release(K.classicPaused and "Pausado; aperte novamente para retomar" or "Classico: procurando o jogador mais proximo")
            return true
        end
        if K.target then K.Release("Alvo solto; aperte novamente para escolher","manual");return true end
        local char,hum,root=character();local cam=workspace.CurrentCamera
        if not char or not hum or hum.Health<=0 or not root or not cam then status("SEM ALVO","Entre com um personagem vivo");return false end
        if not normalCameraType(cam.CameraType) or not cameraSubjectIsLocal(cam,hum,root) then
            status("INDISPONIVEL","Aguarde a camera voltar ao seu personagem");return false
        end
        local target=K.Pick(cam,char,root)
        if not target then status("SEM ALVO","Nenhum jogador visivel dentro do raio; mire nele e tente novamente");return false end
        K.target=target;K.localCharacter=char;state.aimTarget=target.root
        K.ClearLook()
        K.saved={camera=cam,kind=cam.CameraType,subject=cam.CameraSubject};K.acquiredAt=os.clock();K.fadeAt=nil
        K.CameraRecoveries=0;K.LastRecovery=nil;K.LastPause=nil;K.LastOcclusion=nil;K.rig=nil
        K.heading=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
        if K.heading.Magnitude<0.01 then K.heading=Vector3.new(0,0,-1) else K.heading=K.heading.Unit end
        filters(char,target.char);K.losClock=0;K.occludedAt=nil
        cam.CameraType=Enum.CameraType.Scriptable
        status("TRAVADO","Alvo: "..target.player.DisplayName.." | aperte para soltar")
        return true
    end
    local function hideMarker(dt,cam)
        if not marker.Visible then return end
        local t=math.clamp((os.clock()-(K.fadeAt or os.clock()))/0.15,0,1)
        marker.GroupTransparency=t
        sizing.Scale=(K.markerScale or 1)*(1+t*0.16)
        if t>=1 or not cam then marker.Visible=false;K.fadeAt=nil end
    end
    function K.Draw(cam,point,targetDistance)
        local screen,visible=cam:WorldToViewportPoint(point)
        if not visible or screen.Z<=0.1 or K.occludedAt then marker.Visible=false;return end
        local view=cam.ViewportSize
        -- The two-person camera changes its arm length near the target. Its depth
        -- must not reverse the reticle scale: near targets are larger, far ones smaller.
        local maxSize=math.min(112,math.min(view.X,view.Y)*0.2)
        local minSize=math.min(44,maxSize)
        local distance=math.max(0,targetDistance or screen.Z)
        local size=minSize+(maxSize-minSize)/(1+distance/18)
        local t=math.clamp((os.clock()-(K.acquiredAt or 0))/0.18,0,1)
        local ease=1-(1-t)^3
        K.markerScale=size/84
        sizing.Scale=K.markerScale*(1+(1-ease)*0.38)
        borderShape.Rotation=(1-ease)*12
        marker.Position=UDim2.fromOffset(screen.X,screen.Y)
        marker.GroupTransparency=1-ease;marker.Visible=true
    end
    local function inFrame(frame,point,tanX,tanY)
        local delta=point-frame.Position
        local depth=delta:Dot(frame.LookVector)
        return depth>0.05 and math.abs(delta:Dot(frame.RightVector))<=depth*tanX*0.84
            and math.abs(delta:Dot(frame.UpVector))<=depth*tanY*0.84
    end
    function K.Solve(localPoint,targetPoint,cam,dt)
        K.StepLook(dt)
        local delta=targetPoint-localPoint
        local flat=Vector3.new(delta.X,0,delta.Z);local distance=flat.Magnitude
        local alpha=1-math.exp(-math.max(6,cfg.aimSmooth*1.5+2)*math.min(dt,0.1))
        local rig=K.rig
        if not rig then
            local offset=cam.CFrame.Position-(localPoint+flat*0.62)
            local horizontal=Vector3.new(offset.X,0,offset.Z)
            if horizontal.Magnitude>0.1 then K.heading=-horizontal.Unit end
            rig={center=flat*0.62,arm=math.max(1,offset.Magnitude),
                pitch=math.asin(math.clamp(offset.Y/math.max(1,offset.Magnitude),-1,1)),yaw=0}
            K.rig=rig
        end
        if distance>1.5 then
            local desired=flat.Unit
            local current=K.heading or desired
            local a,b=math.atan2(current.X,current.Z),math.atan2(desired.X,desired.Z)
            local turn=math.atan2(math.sin(b-a),math.cos(b-a))
            a=a+turn*(1-math.exp(-math.max(10,cfg.aimSmooth*1.5+2)*math.min(dt,0.1)))
            K.heading=Vector3.new(math.sin(a),0,math.cos(a))
        end
        local heading=K.heading or Vector3.new(0,0,-1)
        local blend=math.clamp((distance-5)/17,0,1);blend=blend*blend*(3-2*blend)
        local pitch=math.rad(76-58*blend)
        local focus=targetPoint
        local halfVertical=math.rad(cam.FieldOfView)*0.5
        local aspect=cam.ViewportSize.X/math.max(1,cam.ViewportSize.Y)
        local halfAngle=math.min(halfVertical,math.atan(math.tan(halfVertical)*math.max(0.2,aspect)))
        -- Frame horizontal separation from the local player's height. An airborne
        -- target raises the look point, not the camera rig or its arm length.
        local extent=distance*0.62+3
        local arm=math.max(14,extent/math.max(0.1,math.sin(halfAngle))*1.08)
        -- Smooth the boom in polar coordinates. A fast turn follows an arc instead
        -- of cutting a chord through the fighters, and local translation has no drag.
        rig.center=rig.center:Lerp(flat*0.62,alpha)
        rig.arm=rig.arm+(arm-rig.arm)*alpha
        rig.pitch=rig.pitch+(math.clamp(pitch-K.manualPitch,math.rad(8),math.rad(84))-rig.pitch)*alpha
        rig.yaw=rig.yaw+(K.manualYaw-rig.yaw)*alpha
        local orbitYaw=math.atan2(heading.X,heading.Z)+rig.yaw
        local orbitHeading=Vector3.new(math.sin(orbitYaw),0,math.cos(orbitYaw))
        local position=localPoint+rig.center-orbitHeading*(math.cos(rig.pitch)*rig.arm)
            +Vector3.new(0,math.sin(rig.pitch)*rig.arm,0)
        -- Resolve obstruction after the orbit is solved, including manual look.
        local ray=position-localPoint
        if ray.Magnitude>0.01 then
            local hit=workspace:Raycast(localPoint,ray,query)
            if hit then position=hit.Position+hit.Normal*0.65 end
        end
        if (focus-position).Magnitude<0.1 then position=focus+Vector3.new(0,0.5,0) end
        local direction=(focus-position).Unit
        -- Most manual input orbits the rig; a small view offset keeps look input
        -- available while the live target remains the aim anchor throughout turns.
        local yaw=math.atan2(direction.X,direction.Z)+K.manualYaw*0.2
        local lookPitch=math.clamp(math.asin(math.clamp(direction.Y,-1,1))+K.manualPitch*0.2,-math.rad(85),math.rad(85))
        local look=Vector3.new(math.sin(yaw)*math.cos(lookPitch),math.sin(lookPitch),math.cos(yaw)*math.cos(lookPitch))
        local frame=CFrame.lookAt(position,position+look)
        local tanY=math.tan(halfVertical);local tanX=tanY*math.max(0.01,aspect)
        if not inFrame(frame,targetPoint,tanX,tanY) then
            local centered=CFrame.lookAt(position,focus)
            if inFrame(centered,targetPoint,tanX,tanY) then
                -- Limit only the portion of manual rotation that would hide the selected target.
                local low,high=0,1
                for _=1,5 do
                    local mid=(low+high)*0.5
                    if inFrame(centered:Lerp(frame,mid),targetPoint,tanX,tanY) then low=mid else high=mid end
                end
                frame=centered:Lerp(frame,low)
            elseif (targetPoint-position).Magnitude>0.1 then
                frame=CFrame.lookAt(position,targetPoint)
            end
        end
        return frame,focus,pitch
    end
    local function face(root,hum,point)
        if not cfg.faceTarget or root.Anchored or hum.Sit or hum.PlatformStand then return end
        local look=Vector3.new(point.X,root.Position.Y,point.Z)
        if (look-root.Position).Magnitude>0.1 then root.CFrame=CFrame.lookAt(root.Position,look) end
    end
    local function waitForCamera()
        if not K.suspended then
            K.suspended="missing";K.ClearLook();K.rig=nil
            K.LastPause={reason="missing",at=os.clock(),cameraType="none"}
            status("SEM CAMERA","Aguardando CurrentCamera; alvo mantido")
        end
        marker.Visible=false
    end
    function K.CameraChanged()
        if cfg.lockMode=="Classico" then K.Reset("Camera trocada; retome o acompanhamento","camera");return end
        if not K.target then K.ClearLook();return end
        restoreCamera()
        K.rig=nil;K.ClearLook()
        if not workspace.CurrentCamera then waitForCamera() end
    end
    function K.Step(dt,cam,hum,root)
        if not cfg.lockOn or state.booting or not root or not hum or hum.Health<=0 then
            if K.target or K.saved or state.aimTarget then K.Release("Personagem indisponivel; escolha o alvo novamente","localCharacter") end
            hideMarker(dt,cam);return
        end
        if cfg.lockMode=="Classico" then
            if not cam then hideMarker(dt,cam);return end
            if not K.classicPaused then
                local target=nearest(cfg.radius)
                if target~=state.aimTarget then
                    state.aimTarget=target;K.acquiredAt=os.clock();K.fadeAt=nil
                    if not target then K.fadeAt=os.clock() end
                    status(target and "TRAVADO" or "SEM ALVO",target and "Classico: jogador mais proximo" or "Classico: aguardando alvo no raio")
                end
                if target then
                    local point=target.Position+target.AssemblyLinearVelocity*cfg.prediction
                    if (point-cam.CFrame.Position).Magnitude>0.1 then
                        cam.CFrame=cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position,point),1-math.exp(-cfg.aimSmooth*dt))
                    end
                    face(root,hum,point);K.Draw(cam,target.Position+Vector3.new(0,0.5,0),(target.Position-root.Position).Magnitude);return
                end
            end
            hideMarker(dt,cam);return
        end
        local target=K.target
        if not target then hideMarker(dt,cam);return end
        if player.Character~=K.localCharacter then K.Release("Personagem trocado; escolha o alvo novamente","character");hideMarker(dt,cam);return end
        local localPosition=bodyPosition(K.localCharacter,hum,root)
        local validTarget,reason=liveTarget(target,localPosition)
        if not validTarget then K.Release("Alvo fora das condicoes; aperte para escolher outro",reason);hideMarker(dt,cam);return end
        if not cam then waitForCamera();return end
        if K.saved and cam~=K.saved.camera then restoreCamera();K.rig=nil end
        if not K.saved then
            -- An active explicit lock owns the view through combat camera/subject changes.
            K.saved={camera=cam,kind=cam.CameraType,subject=cam.CameraSubject}
        end
        if cam.CameraType~=Enum.CameraType.Scriptable then
            K.saved.kind=cam.CameraType
            K.LastRecovery={cameraType=cam.CameraType.Name,at=os.clock(),
                subjectIsLocal=not not cameraSubjectIsLocal(cam,hum,root)}
            cam.CameraType=Enum.CameraType.Scriptable
            K.CameraRecoveries=K.CameraRecoveries+1;K.lastRecoveryAt=os.clock()
        end
        if K.suspended then
            K.suspended=nil;K.acquiredAt=os.clock()
            status("TRAVADO","Alvo: "..target.player.DisplayName.." | aperte para soltar")
        end
        local point=target.position+Vector3.new(0,0.5,0)
        K.losClock=K.losClock+dt
        if K.losClock>=0.1 then
            K.losClock=0
            filters(K.localCharacter,target.char)
            if cfg.lockWallCheck then
                local visible,hit=combatVisible(K.localCharacter,localPosition,target.char,point)
                if not visible then
                    if not K.occludedAt then
                        K.LastOcclusion={at=os.clock(),blocker=hit and hit.Instance and hit.Instance.Name or "unknown",
                            blockerClass=hit and hit.Instance and hit.Instance.ClassName or "unknown",
                            normalY=hit and hit.Normal and hit.Normal.Y or nil}
                    end
                    K.occludedAt=K.occludedAt or os.clock()
                else K.occludedAt=nil end
            else K.occludedAt=nil end
        end
        if K.occludedAt and os.clock()-K.occludedAt>=0.65 then K.Release("Alvo encoberto; aperte para escolher outro","occluded");hideMarker(dt,cam);return end
        local frame,focus=K.Solve(localPosition+Vector3.new(0,1,0),point,cam,dt)
        cam.CFrame=frame;cam.Focus=CFrame.new(focus)
        face(root,hum,point);K.Draw(cam,point,(target.position-localPosition).Magnitude)
    end
    function K.CancelBind()
        K.binding=false
        if API.LockKeyButton then API.LockKeyButton.Text="Tecla: "..cfg.lockKey.." (toque para trocar)" end
    end
    function K.BeginBind()
        if not state.alive or state.booting then return end
        if API.Mobilador then API.Mobilador.CancelBind() end
        K.ClearLook()
        K.binding=true
        API.LockKeyButton.Text="Aperte uma tecla | Esc cancela"
    end
    function K.OnInput(input,processed)
        if not state.alive or state.booting then return end
        if API.Mobilador and API.Mobilador.bindKey then return end
        if input.UserInputType~=Enum.UserInputType.Keyboard or Input:GetFocusedTextBox() then return end
        if K.binding then
            if input.KeyCode==Enum.KeyCode.Escape then K.CancelBind();return end
            if processed then return end
            if set("lockKey",input.KeyCode.Name,true) then K.CancelBind()
            else notify("Escolha uma tecla de teclado diferente da tecla do menu.") end
            return
        end
        if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then return end
        if not processed and input.KeyCode==Enum.KeyCode[cfg.lockKey] then K.Toggle() end
    end
    function K.Configure()
        K.CancelBind();K.classicPaused=false;K.Release(nil,"config")
        API.QuickActions.Update()
    end
    function K.Stop()
        K.CancelBind();K.Reset();marker.Visible=false
    end
    actions.lockOn=K.Configure;actions.lockMode=K.Configure
    actions.lockKey=K.CancelBind
    actions.lockCameraFreedom=function(value)
        local limit=math.rad(value)
        K.manualYaw=math.clamp(K.manualYaw,-limit,limit)
    end
    listen(Input.InputBegan,K.OnInput)
    listen(Input.InputBegan,K.LookBegan)
    listen(Input.InputChanged,K.LookChanged)
    listen(Input.InputEnded,K.LookEnded)
    listen(Input.WindowFocusReleased,function() K.CancelBind();K.ClearLook() end)
    listen(Input.GamepadDisconnected,function() K.stick=Vector2.new(0,0) end)
    listen(workspace:GetPropertyChangedSignal("CurrentCamera"),K.CameraChanged)
end
-- RoChess suggestions use a checked native module interface; no move is submitted.
do
    local C={running=false,generation=0,message="Desligado",rows={},analyses=0,nextBind=0}
    API.Chess=C
    local arrowKeys={"HussChessHint1","HussChessHint2","HussChessHint3"}
    local colors={Color3.fromRGB(117,222,150),Color3.fromRGB(111,180,255),Color3.fromRGB(246,204,110)}
    function C.IsGame() return game.GameId==10768845402 or game.PlaceId==139717576471404 end
    function C.Status(message)
        C.message=message
        local labels={API.ChessStatus,C.statusLabel}
        for index=1,2 do local label=labels[index];if label and label.Text~=message then label.Text=message end end
    end
    function C.ClearBoard()
        local board=C.arrowBoard;C.arrowBoard=nil
        if type(board)=="table" and type(board.setArrow)=="function" then
            for _,key in ipairs(arrowKeys) do pcall(board.setArrow,board,key,nil) end
        end
    end
    function C.ClearRows()
        C.ClearBoard();C.rows={}
        for index,label in ipairs(C.rowLabels or {}) do label.Text=index.."  -" end
    end
    function C.EnsureHUD()
        if C.hud then C.hud.Visible=true;return end
        local cam=workspace.CurrentCamera
        local width=math.min(280,math.max(160,(cam and cam.ViewportSize.X or 300)-20))
        C.hud=themed(create("Frame",{Name="ChessSuggestions",Position=UDim2.new(1,-width-10,0,72),
            Size=UDim2.fromOffset(width,130),BackgroundTransparency=0.1,BorderSizePixel=0,ZIndex=22},gui),"BackgroundColor3","card")
        round(C.hud,9)
        accented(create("UIStroke",{Thickness=1,Transparency=0.5},C.hud),"Color")
        local handle=create("Frame",{Name="DragHeader",Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,Active=true,ZIndex=23},C.hud)
        text(handle,"ROCHESS / SUGESTOES",10,{Position=UDim2.fromOffset(10,2),Size=UDim2.new(1,-20,1,0),Font=Enum.Font.GothamBold,ZIndex=24})
        API.UI.Draggable(handle,C.hud)
        C.statusLabel=text(C.hud,C.message,9,{Position=UDim2.fromOffset(10,28),Size=UDim2.new(1,-20,0,24),TextWrapped=true,ZIndex=23})
        C.rowLabels={}
        for index=1,3 do C.rowLabels[index]=text(C.hud,index.."  -",11,{Position=UDim2.fromOffset(10,52+(index-1)*23),
            Size=UDim2.new(1,-20,0,22),TextColor3=colors[index],ZIndex=23}) end
    end
    function C.ValidFen(fen)
        if type(fen)~="string" or #fen>200 then return nil end
        local fields={};for field in fen:gmatch("%S+") do fields[#fields+1]=field end
        if #fields~=6 or (fields[2]~="w" and fields[2]~="b") then return nil end
        local ranks,whiteKing,blackKing=0,0,0
        for rank in fields[1]:gmatch("[^/]+") do
            local count=0;ranks=ranks+1
            for item in rank:gmatch(".") do
                if item:match("^[1-8]$") then count=count+tonumber(item)
                elseif item:match("^[prnbqkPRNBQK]$") then
                    count=count+1;if item=="K" then whiteKing=whiteKing+1 elseif item=="k" then blackKing=blackKing+1 end
                else return nil end
            end
            if count~=8 then return nil end
        end
        if ranks~=8 or whiteKing~=1 or blackKing~=1 or fields[1]:find("//",1,true)
            or fields[1]:sub(1,1)=="/" or fields[1]:sub(-1)=="/" then return nil end
        if fields[3]~="-" and (fields[3]=="" or not fields[3]:match("^K?Q?k?q?$")) then return nil end
        if fields[4]~="-" and not fields[4]:match("^[a-h][36]$") then return nil end
        if not fields[5]:match("^%d+$") or not fields[6]:match("^%d+$") then return nil end
        local half,full=tonumber(fields[5]),tonumber(fields[6])
        if not half or not full or half>1000000 or full<1 or full>1000000 then return nil end
        return fields[2]=="w" and 1 or -1
    end
    function C.Read()
        local native=C.native;if not native then return nil,"Aguardando modulos do RoChess" end
        local session=native.App.session
        if type(session)~="table" or session.kind=="idle" then return nil,"Entre em uma partida" end
        if session.over then return nil,"Partida encerrada" end
        if type(session.ucis)~="table" or #session.ucis>2048 or session.viewPly~=#session.ucis then return nil,"Volte ao lance atual da partida" end
        if session.myColor~=1 and session.myColor~=-1 then return nil,"Aguardando sua cor na partida" end
        if type(session.engine)~="table" or type(session.engine.getFen)~="function" then return nil,"Posicao nativa indisponivel" end
        local fen=session.engine:getFen();local turn=C.ValidFen(fen)
        if not turn then return nil,"Posicao nativa incompativel" end
        if turn~=session.myColor then return nil,"Vez do adversario" end
        if native.App.session~=session then return nil,"Atualizando partida" end
        return {session=session,fen=fen,color=turn,ply=#session.ucis,board=native.App.board}
    end
    function C.Same(a,b)
        return a and b and a.session==b.session and a.fen==b.fen and a.color==b.color and a.ply==b.ply and a.board==b.board
    end
    function C.Current(position,generation)
        if not state.alive or not C.running or not cfg.chessAssistant or generation~=C.generation or C.position~=position then return false end
        local ok,live=pcall(C.Read)
        return ok and C.Same(position,live) or false
    end
    function C.CancelJob()
        local job=C.job
        if job and not job.inNative and job.thread and type(task.cancel)=="function" and job.thread~=coroutine.running() then
            local ok=pcall(task.cancel,job.thread)
            if ok and C.job==job then C.job=nil end
        end
    end
    function C.Invalidate()
        C.generation=C.generation+1;C.CancelJob();C.position=nil;C.completed=nil;C.ClearRows()
    end
    function C.Launch(callback,position)
        if C.job then return false end
        local job={generation=C.generation,started=os.clock()};C.job=job
        job.thread=task.defer(function()
            if not C.running or job.generation~=C.generation then if C.job==job then C.job=nil end;return end
            local ok,err=pcall(callback,job.generation)
            if C.job==job then C.job=nil end
            if not ok and C.running and job.generation==C.generation then
                C.lastError=tostring(err):sub(1,220);C.nextBind=os.clock()+3
                if position then C.completed=position end
                C.ClearRows();C.Status("Motor incompativel; copie o diagnostico")
            end
        end)
        return true
    end
    function C.Bind()
        local chess=Replicated:FindFirstChild("Chess");local client=Replicated:FindFirstChild("ChessClient")
        local engine=chess and chess:FindFirstChild("Engine");local bot=chess and chess:FindFirstChild("Bot")
        local app=client and client:FindFirstChild("App")
        C.modules={Engine=engine~=nil,Bot=bot~=nil,App=app~=nil}
        C.nextBind=os.clock()+3
        if not engine or not bot or not app then C.Status("Aguardando modulos compativeis do RoChess");return end
        if not engine:IsA("ModuleScript") or not bot:IsA("ModuleScript") or not app:IsA("ModuleScript") then C.Status("Estrutura do RoChess incompativel");return end
        C.Launch(function(generation)
            local job=C.job;if job then job.inNative=true end
            local E,B,A=require(engine),require(bot),require(app)
            if job then job.inNative=false end
            if not C.running or C.generation~=generation then return end
            assert(type(E)=="table" and type(E.new)=="function" and type(E.algToIndex64)=="function","Engine indisponivel")
            assert(type(B)=="table" and type(B.analyse)=="function" and type(A)=="table","Bot/App indisponivel")
            C.native={Engine=E,Bot=B,App=A};C.Status("Lendo a partida")
        end)
    end
    function C.Legal(engine)
        local iterator,context,key=engine:legalMoves()
        local moves,seen={},{}
        local function add(move)
            local uci=engine:moveToUci(move)
            if type(uci)~="string" or not (uci:match("^[a-h][1-8][a-h][1-8]$") or uci:match("^[a-h][1-8][a-h][1-8][qrbn]$")) then return end
            if not seen[uci] then seen[uci]=true;moves[#moves+1]={uci=uci,move=move} end
        end
        if type(iterator)=="table" then for index,move in ipairs(iterator) do assert(index<=256,"Lances demais");add(move) end
        elseif type(iterator)=="function" then
            for index=1,257 do
                local nextKey,move=iterator(context,key);key=nextKey
                if key==nil then return moves end
                assert(index<=256,"Lances demais");add(move)
            end
        else error("Lista de lances indisponivel") end
        return moves
    end
    function C.Publish(position,generation,rows,message)
        if not C.Current(position,generation) then return false end
        C.ClearBoard();C.rows=rows
        for index,label in ipairs(C.rowLabels or {}) do
            local row=rows[index];local value=index.."  -"
            if row then value=index.."  "..row.san.."  ("..row.uci..")" end
            if label.Text~=value then label.Text=value end
        end
        local board=position.board;C.arrowsSupported=type(board)=="table" and type(board.setArrow)=="function"
        if C.arrowsSupported then
            C.arrowBoard=board
            for index,row in ipairs(rows) do
                local from=C.native.Engine.algToIndex64(row.uci:sub(1,2));local to=C.native.Engine.algToIndex64(row.uci:sub(3,4))
                if from and to then pcall(board.setArrow,board,arrowKeys[index],from,to,colors[index],0.12) end
            end
        end
        C.Status(message);return true
    end
    function C.Search(bot,fen,seconds,depth)
        local job=C.job;if job then job.inNative=true end
        local ok,result=pcall(bot.analyse,fen,{},seconds,depth)
        if job then job.inNative=false end
        if not ok then error(result) end
        return result
    end
    function C.Analyze(position,generation)
        local native=C.native;local E,B=native.Engine,native.Bot
        local engine=E.new(position.fen);local moves=C.Legal(engine)
        if not C.Current(position,generation) then return end
        C.analyses=C.analyses+1
        if #moves==0 then C.completed=position;C.Status("Sem lances legais nesta posicao");return end
        local byUci={};for _,move in ipairs(moves) do byUci[move.uci]=move end
        local result=C.Search(B,position.fen,0.12,12)
        if not C.Current(position,generation) then return end
        assert(type(result)=="table" and type(result.best)=="string" and byUci[result.best],"O motor retornou um lance invalido")
        local best=byUci[result.best]
        local function row(entry)
            local ok,san=pcall(engine.moveToSan,engine,entry.move)
            return {uci=entry.uci,san=ok and type(san)=="string" and san:sub(1,30) or entry.uci}
        end
        C.Publish(position,generation,{row(best)},"Melhor do motor; avaliando alternativas")
        local alternatives={};local began=os.clock();local examined=0
        for _,entry in ipairs(moves) do
            if entry~=best and examined<64 and os.clock()-began<0.75 then
                if not C.Current(position,generation) then return end
                -- Every branch starts from the current FEN, including castling and en-passant rights.
                local child=E.new(position.fen);local move=child:moveFromUci(entry.uci)
                assert(move~=nil,"Continuacao invalida");child:play(move)
                local ok,score=pcall(function()
                    local evaluation=C.Search(B,child:getFen(),0.01,6)
                    return evaluation and evaluation.score
                end)
                if not C.Current(position,generation) then return end
                examined=examined+1
                if ok and type(score)=="number" and score==score and math.abs(score)<math.huge then
                    alternatives[#alternatives+1]={entry=entry,order=score*position.color}
                end
                task.wait()
            end
        end
        if not C.Current(position,generation) then return end
        table.sort(alternatives,function(a,b) if a.order==b.order then return a.entry.uci<b.entry.uci end;return a.order>b.order end)
        local rows={row(best)}
        for index=1,math.min(2,#alternatives) do rows[#rows+1]=row(alternatives[index].entry) end
        C.examined=examined;C.partial=examined<#moves-1
        C.Publish(position,generation,rows,C.partial and "Melhor do motor + alternativas parciais" or "Melhor do motor + alternativas avaliadas")
        C.completed=position
    end
    function C.Poll()
        if not state.alive or state.booting or not C.running or not cfg.chessAssistant then return end
        if not C.native then if not C.job and os.clock()>=C.nextBind then C.Bind() end;return end
        local position,message=C.Read()
        if not position then
            if C.position then C.Invalidate() end
            C.Status(message);return
        end
        if not C.Same(C.position,position) then C.Invalidate();C.position=position;C.Status("Analisando sua posicao") end
        if not C.job and C.completed~=C.position then
            local current=C.position;C.Launch(function(generation) C.Analyze(current,generation) end,current)
        end
    end
    function C.Stop()
        C.running=false
        if C.connection then C.connection:Disconnect();C.connection=nil end
        C.Invalidate();C.native=nil
        if C.hud then C.hud.Visible=false end
        C.Status("Desligado")
    end
    function C.Start()
        C.Stop()
        if not C.IsGame() then C.Status("Disponivel somente no RoChess");return end
        C.running=true;C.nextBind=0;C.lastError=nil;C.EnsureHUD();C.Status("Aguardando partida do RoChess")
        local elapsed=0
        C.connection=Run.Heartbeat:Connect(function(dt)
            elapsed=elapsed+dt;if elapsed<0.15 then return end;elapsed=0
            local ok,err=pcall(C.Poll)
            if not ok then C.lastError=tostring(err):sub(1,220);C.Invalidate();C.native=nil;C.nextBind=os.clock()+3;C.Status("Leitura incompativel; copie o diagnostico") end
        end)
        C.Poll()
    end
    function C.Snapshot()
        return {kind="RoChessDiagnostics",version=API.Version,placeId=game.PlaceId,gameId=game.GameId,
            enabled=cfg.chessAssistant,running=C.running,message=C.message,modules=C.modules,
            nativeReady=C.native~=nil,busy=C.job~=nil,analyses=C.analyses,lastError=C.lastError,
            nativeBusy=C.job and C.job.inNative or false,busySeconds=C.job and os.clock()-C.job.started or 0,
            fen=C.position and C.position.fen,color=C.position and C.position.color,
            suggestions=C.rows,alternativesExamined=C.examined,partialAlternatives=C.partial,boardArrows=C.arrowsSupported}
    end
    actions.chessAssistant=function(enabled) if enabled then C.Start() else C.Stop() end end
end
-- End RoChess suggestions.
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
            freeze=packPosition(API.QuickActions.buttons.Freeze.host.Position),
            lockOn=packPosition(API.QuickActions.buttons.LockOn.host.Position),
            nativeButtons=API.TouchControls and API.TouchControls.ExportLayout() or nil}
    end
    local function restoreLayout(layout)
        if API.TouchControls then API.TouchControls.ImportLayout(type(layout)=="table" and layout.nativeButtons or nil) end
        if type(layout)~="table" then return end
        for _,entry in ipairs({{"window",window},{"launcher",API.UI.FloatingHost},
            {"autoJump",API.QuickActions.buttons.AutoJump.host},{"freeze",API.QuickActions.buttons.Freeze.host},
            {"lockOn",API.QuickActions.buttons.LockOn.host}}) do
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
            local ok,value=valid(key,candidate,{})
            if ok then values[key]=value else values[key]=initial end
        end
        if values.lockKey==values.toggleKey then values.lockKey=values.toggleKey=="L" and "K" or "L" end
        if values.mobilador then values.unlockMouse=false end
        for _,entry in ipairs({{"mobiladorShiftKey",{"V","LeftControl","CapsLock","RightControl"}},
            {"mobiladorRecoverKey",{"F8","F6","F7","Insert"}}}) do
            local key=entry[1]
            if not valid(key,values[key],values) then for _,candidate in ipairs(entry[2]) do
                if valid(key,candidate,values) then values[key]=candidate;break end
            end end
        end
        if API.Mobilador then API.Mobilador.Stop() end
        -- Stop transient presses and drags; selecting a row alone never enters this path.
        if API.TouchControls then API.TouchControls.EndEditor();API.TouchControls.CancelPicker() end
        for input,pointer in pairs(pointerSessions) do
            pointerSessions[input]=nil;if pointer.finish then pointer.finish(input) end
        end
        API.QuickActions.Reset()
        applying=true
        -- Parameters first, then disabled flags, then enabled flags.
        for key,initial in pairs(defaults) do
            if type(initial)~="boolean" and key~="opacity" then set(key,values[key],true,values) end
        end
        for _,enabled in ipairs({false,true}) do for key,initial in pairs(defaults) do
            if type(initial)=="boolean" and key~="autoLoad" and values[key]==enabled then set(key,enabled,true) end
        end end
        applying=false
        restoreLayout(data._layout)
        if API.Mobilador then API.Mobilador.Configure() end
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
function API.CopyMobiladorDiagnostics()
    return presentDiagnostic(Http:JSONEncode(API.Mobilador.Snapshot()),"Diagnostico do mobilador copiado.")
end
function API.CopyInputModeDiagnostics()
    return presentDiagnostic(Http:JSONEncode(API.InputMode.Snapshot()),"Diagnostico de entrada copiado.")
end
function API.CopyChessDiagnostics()
    return presentDiagnostic(Http:JSONEncode(API.Chess.Snapshot()),"Diagnostico do xadrez copiado.")
end

function API.CopyLockDiagnostics()
    local k=API.LockOn;local cam=workspace.CurrentCamera
    local report={kind="LockOnRelease",version=API.Version,placeId=game.PlaceId,gameId=game.GameId,
        mode=cfg.lockMode,status=k.Status,shortStatus=k.StatusText,message=k.message,
        captureRadius=cfg.radius,releaseRange=math.max(cfg.radius,cfg.lockReleaseRange),
        wallCheck=cfg.lockWallCheck,teamCheck=cfg.teamCheck,lastRelease=k.LastRelease,
        cameraRecoveries=k.CameraRecoveries or 0,suspended=k.suspended,
        cameraType=cam and cam.CameraType.Name or "none",
        cameraSubjectClass=cam and cam.CameraSubject and cam.CameraSubject.ClassName or "none",
        lastRecovery=k.LastRecovery,lastPause=k.LastPause,lastOcclusion=k.LastOcclusion}
    return presentDiagnostic(Http:JSONEncode(report),"Motivo do Lock On copiado.")
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
    if API.InputMode then API.InputMode.Sweep() end
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
    slot.release=ctx.detachOutbound
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
listen(Run.Heartbeat,function(dt)
    if not state.alive then return end
    API.QuickActions.Step(dt)
    local now=os.clock()
    elapsed=elapsed+dt;state.elapsed=elapsed;speedElapsed=speedElapsed+dt;hueElapsed=hueElapsed+dt
    local char,hum,root,cam
    if cfg.fly or cfg.noclip or cfg.tpWalk or cfg.spin or cfg.autoAttack or cfg.autoGears then
        char,hum,root=character()
        if cfg.fly then cam=workspace.CurrentCamera end
    end
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
    stepAdapters(dt)
    if hueElapsed>=0.15 then hueElapsed=0;if cfg.rainbow then refreshAccent() end end
end)
local renderBindingName="HussValleyPanelCamera_"..player.UserId
Run:BindToRenderStep(renderBindingName,Enum.RenderPriority.Camera.Value+1,function(dt)
    if not state.alive then return end
    state.frames=state.frames+1;state.time=state.time+dt
    if uiDirty and state.visible then applyAppearance() end
    if cfg.unlockMouse and not cfg.mobilador then patch("mouse",Input,"MouseBehavior",Enum.MouseBehavior.Default) end
    local hum,root
    if cfg.lockOn or cfg.mobilador then local ignored;ignored,hum,root=character() end
    local cam=workspace.CurrentCamera
    API.LockOn.Step(dt,cam,hum,root)
    if cfg.mobilador then
        local ok=pcall(API.Mobilador.Step,cam,hum,root)
        if not ok then set("mobilador",false,true);notify("Compatibilidade de mouse indisponivel neste cliente; opcao desligada.") end
    end
    local cursorOK=pcall(API.Mobilador.UpdateCursor)
    if not cursorOK then set("mobiladorReticle",false,true) end
    renderESP(dt) -- project current poses after all camera changes, without positional interpolation.
    if state.time>=0.75 then
        fpsLabel.Text=string.format("%d FPS",math.floor(state.frames/state.time+0.5))
        API.FPS.Observe(state.frames,state.time);state.frames=0;state.time=0
    end
end)
listen(player.CharacterAdded,function()
    stopFlight();restore("speed");restore("collision");restore("headless");restore("nameHider")
    task.spawn(function()
        local char=player.Character;if not char then return end
        char:WaitForChild("HumanoidRootPart",8)
        if not state.alive or player.Character~=char then return end
        updateFlight();applySpeed();actions.noclip(cfg.noclip);actions.headless(cfg.headless);actions.nameHider(cfg.nameHider)
        API.RefreshEmotes()
    end)
end)
function API.Destroy()
    if not state.alive then return end
    state.alive=false;perfToken=perfToken+1;xrayToken=xrayToken+1
    if API.Chess then API.Chess.Stop() end
    if API.UI then API.UI.Stop() end
    if API.InputMode then API.InputMode.Destroy() end
    if API.Loading then API.Loading.Stop() end
    if API.QuickActions then API.QuickActions.Stop() end
    if API.TouchControls then API.TouchControls.Destroy() end
    if API.LockOn then API.LockOn.Stop() end
    if API.Mobilador then API.Mobilador.Destroy() end
    if API.ConfigUI then API.ConfigUI.Stop() end
    for input in pairs(pointerSessions) do pointerSessions[input]=nil end
    if API.Shaders then API.Shaders.Stop() end
    if API.FPS then API.FPS.Stop() end
    endHitTrace("panelClosed",false)
    if API.Native and API.Native.ReleaseDashInput then API.Native.ReleaseDashInput() end
    for key,name in pairs(requiresAdapter) do if cfg[key] and type(adapters[name])=="function" then pcall(adapters[name],{Enabled=false,Player=player,Config=cfg}) end end
    for _,c in ipairs(connections) do c:Disconnect() end
    Run:UnbindFromRenderStep(renderBindingName)
    if cameraSizeConnection then cameraSizeConnection:Disconnect() end
    if collisionConnection then collisionConnection:Disconnect();collisionConnection=nil end
    stopFlight();API.StopEmote()
    for group in pairs(originals) do restore(group) end
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








