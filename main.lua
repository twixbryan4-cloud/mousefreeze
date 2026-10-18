-- Huss Valley Panel 0.2.0
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
    firstPerson=false, unlockMouse=false, fov=70, customFov=false, fullbright=false, xray=false,
    lockOn=false, radius=30, prediction=0.12, aimSmooth=12, faceTarget=false, teamCheck=false,
    autoAttack=false, attackRange=12, attackDelay=0.4, autoGears=false, gearDelay=1,
    autoRevive=false, autoPick=false, promptDelay=0.6,
    autoDash=false, autoZone=false, autoDown=false, autoTackle=false, dashCooldown=false,
    autoAbility=false, runnerAI=false, catcherAI=false, autoWheel=false, autoJourney=false,
    autoVote=false, disableGameAFK=false, antiIdle=false, antiHit=false,
    esp=false, boxes=true, names=true, tracers=false, health=true, distance=true,
    skeleton=false, headDot=false, healthText=false, roleColors=true, teamFilter=false,
    espRange=1500, espRate=15, smoothESP=true, chams=false, viewTracer=false, nameHider=false, headless=false,
    hitbox=false, leaderboard=false, gems=false,
    fpsBoost=false, removeTextures=true, removeDecals=true, removeParticles=true,
    lowDetail=true, noShadows=true, noFog=true, removeAccessories=false,
    unlockFPS=false, fpsCap=120, lowQuality=false,
    uiScale=1, opacity=0.94, transparency=6, theme="Dark", accent="Peach", rainbow=false,
    sounds=false, notifications=true, floating=true, toggleKey="RightShift", autoLoad=false,
}
local cfg = {}
for key,value in pairs(defaults) do cfg[key]=value end
local connections, watchers, actions, pages, navs, accentRefreshers = {}, {}, {}, {}, {}, {}
local optionLabels,menuSurfaces,uiDirty={},{},false
local state = {alive=true, visible=true, page="Combat", up=false, down=false, pending={}, frames=0, time=0}
local adapters = env.HussValleyAdapters or {}
local API = {Version="0.2.0", Config=cfg, Adapters=adapters}
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
local boot=create("Frame",{Name="Welcome",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.46),
    Size=UDim2.fromOffset(280,104),BackgroundColor3=colors.card,BorderSizePixel=0,ZIndex=40},gui)
round(boot,9)
accented(create("UIStroke",{Thickness=0.8,Transparency=0.55},boot),"Color")
local bootAvatar=create("ImageLabel",{Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=100&h=100",
    Size=UDim2.fromOffset(36,36),Position=UDim2.fromOffset(14,14),BackgroundTransparency=1},boot);round(bootAvatar,99)
accented(text(boot,"Welcome,",10,{Position=UDim2.fromOffset(62,12),Size=UDim2.fromOffset(200,16)}),"TextColor3")
text(boot,player.DisplayName,14,{Position=UDim2.fromOffset(62,30),Size=UDim2.fromOffset(200,20),Font=Enum.Font.GothamBold})
local bootStatus=text(boot,"Building interface...",9,{Position=UDim2.fromOffset(14,66),Size=UDim2.fromOffset(250,16)})
local bootTrack=create("Frame",{Position=UDim2.fromOffset(14,88),Size=UDim2.fromOffset(252,3),BackgroundColor3=Color3.fromRGB(63,49,65),BorderSizePixel=0},boot)
local bootFill=accented(create("Frame",{Size=UDim2.fromScale(0.1,1),BorderSizePixel=0},bootTrack),"BackgroundColor3")
local function bootProgress(value,message) bootFill.Size=UDim2.fromScale(value,1);bootStatus.Text=message end
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
    promptDelay={0.25,3},espRange={50,3000},espRate={2,30},fpsCap={30,240},uiScale={0.45,1.6},opacity={0.15,1},transparency={0,85}}
local function valid(key,value)
    if defaults[key]==nil or type(value)~=type(defaults[key]) then return false end
    if type(value)=="number" then
        if value~=value or math.abs(value)==math.huge then return false end
        local r=ranges[key]; if r then value=math.clamp(value,r[1],r[2]) end
    elseif key=="theme" and value~="Dark" and value~="Black" then return false
    elseif key=="accent" and not palette[value] then return false
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
    Size=UDim2.fromOffset(730,438),BackgroundTransparency=1-cfg.opacity,BorderSizePixel=0,ClipsDescendants=true},gui),"BackgroundColor3","bg")
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
local footer=text(window,"HUSS VALLEY  /  v0.2.0",9,{Name="Footer",Position=UDim2.new(0,70,1,-23),Size=UDim2.new(1,-160,0,14)})
themed(footer,"TextColor3","muted")
local fpsLabel=text(window,"-- FPS",9,{Name="FPS",Position=UDim2.new(1,-90,1,-23),Size=UDim2.fromOffset(72,14),TextXAlignment=Enum.TextXAlignment.Right})
local floating=button(gui,"HV",13,{Name="FloatingButton",Position=UDim2.new(0,12,0.36,0),Size=UDim2.fromOffset(42,42),ZIndex=20,Font=Enum.Font.GothamBold})
accented(floating,"TextColor3"); accented(create("UIStroke",{Thickness=1,Transparency=0.4},floating),"Color")
local flightPad=create("Frame",{Name="FlightControls",Position=UDim2.new(1,-66,0.5,-45),Size=UDim2.fromOffset(50,96),BackgroundTransparency=1,Visible=false},gui)
local flyUp=button(flightPad,"+",22,{Name="FlyUp",Size=UDim2.fromOffset(44,42)})
local flyDown=button(flightPad,"-",22,{Name="FlyDown",Position=UDim2.fromOffset(0,48),Size=UDim2.fromOffset(44,42)})
fit=function()
    local cam=workspace.CurrentCamera
    local size=cam and cam.ViewportSize or Vector2.new(1280,720)
    scale.Scale=math.max(0.25,math.min((size.X-24)/730,(size.Y-32)/438,1.1)*cfg.uiScale)
    -- User scaling may not push the panel outside the screen.
    scale.Scale=math.min(scale.Scale,(size.X-16)/730,(size.Y-24)/438)
    local halfW,halfH=365*scale.Scale,219*scale.Scale
    window.Position=UDim2.fromOffset(math.clamp(window.Position.X.Scale*size.X+window.Position.X.Offset,halfW,size.X-halfW),
        math.clamp(window.Position.Y.Scale*size.Y+window.Position.Y.Offset,halfH,size.Y-halfH))
    toast.Size=UDim2.fromOffset(math.min(300,math.max(120,size.X-28)),58)
end
local function show(value)
    state.visible=value; window.Visible=value
    tooltip.Visible=false
    floating.Visible=cfg.floating or not value
    if value then if refreshAccent then refreshAccent() end;applyAppearance() end
end
listen(floating.Activated,function() show(not state.visible) end)
listen(brand.Activated,function() show(false) end)
listen(minimize.Activated,function() show(false) end)
local function draggable(handle,target,isFloating)
    listen(handle.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            local start,startPos=input.Position,target.Position
            beginPointer(input,function(current)
            local delta=current.Position-start
            local cam=workspace.CurrentCamera; if not cam then return end
            local view=cam.ViewportSize
            local x=startPos.X.Scale*view.X+startPos.X.Offset+delta.X
            local y=startPos.Y.Scale*view.Y+startPos.Y.Offset+delta.Y
            local halfW=isFloating and 0 or 365*scale.Scale
            local halfH=isFloating and 0 or 219*scale.Scale
            target.Position=UDim2.fromOffset(math.clamp(x,halfW,view.X-(isFloating and 42 or halfW)),
                math.clamp(y,halfH,view.Y-(isFloating and 42 or halfH)))
            end)
        end
    end)
end
draggable(dragbar,window,false)

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
local navOrder={"Combat","AI","ESP","World","Automation","Performance","Emotes","Config"}
for i,name in ipairs(navOrder) do
    local b=button(rail,"",10,{Name="Nav"..name,Position=UDim2.fromOffset(7,53+(i-1)*39),Size=UDim2.fromOffset(40,35),BackgroundTransparency=1})
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
pending(left,"Auto Zone","autoZone")
c=card(left,"Player Lock On","lockOn","Mira no jogador vivo mais proximo dentro do raio. A captura do jogo precisa de integracao separada.")
slider(c,"Radius","radius",5,150,1," studs");slider(c,"Prediction","prediction",0,0.5,0.01,"s")
slider(c,"Smoothness","aimSmooth",1,25,1);checkbox(c,"Auto Face Target","faceTarget");checkbox(c,"Ignorar mesmo time","teamCheck")
c=card(left,"Auto Use Gears","autoGears","Usa a ferramenta equipada. Nao compra nem inventa ferramentas.")
slider(c,"Intervalo","gearDelay",0.2,10,0.1,"s")
pending(left,"Auto Down","autoDown")
pending(right,"Auto Dash","autoDash")
c=card(right,"Auto Attack","autoAttack","Ativa a ferramenta equipada quando um jogador entra no alcance.")
slider(c,"Range","attackRange",2,50,1," studs");slider(c,"Delay","attackDelay",0.15,3,0.05,"s")
c=card(right,"Auto Pick","autoPick","Aciona prompts proximos de coleta (pick up, collect, coletar). Precisa de fireproximityprompt no executor.")
slider(c,"Intervalo","promptDelay",0.25,3,0.05,"s")
pending(right,"Auto Tackle","autoTackle");pending(right,"Dash Cooldown","dashCooldown");pending(right,"Auto Ability","autoAbility")
c=card(right,"Anti-Hit (pendente)","antiHit","Indisponivel: o diagnostico identifica os eventos, mas nao revela a validacao dos hits. Invulnerabilidade ainda nao foi implementada.")
text(c,"Status: nao validado",10)
left,right=page("AI",3)
pending(left,"Runner AI","runnerAI");pending(right,"Catcher AI","catcherAI")
local info=card(left,"Huss Valley / integracao",nil,"O caminho do mapa, zonas seguras, equipes e controles precisam ser identificados dentro do jogo. Use o diagnostico para a proxima etapa.")
actionButton(info,"Copiar diagnostico",function() API.ExportDiagnostics() end)

left,right=page("ESP",4)
c=card(left,"Players","esp","Marcadores locais. Atualizacao limitada para reduzir o custo no celular.")
for _,v in ipairs({{"Boxes","boxes"},{"Names","names"},{"Tracers","tracers"},{"Health","health"},{"Distance","distance"},
    {"Skeleton","skeleton"},{"Head Dot","headDot"},{"Health Text","healthText"}}) do checkbox(c,v[1],v[2]) end
c=card(left,"Roles & Threat",nil,"Cores por time quando o jogo publica equipes; sem deduzir papeis privados.")
checkbox(c,"Team colors","roleColors");checkbox(c,"Ignorar mesmo time","teamFilter")
c=card(left,"Appearance",nil);cycle(c,"Accent","accent",{"Peach","Purple","Blue","Pink","Green"})
card(left,"View Tracer","viewTracer","Mostra a direcao em que os outros jogadores olham.")
pending(left,"Leaderboard Visuals","leaderboard")
card(left,"Name Hider","nameHider","Oculta o nome padrao sobre seu personagem apenas neste cliente.")
c=card(right,"Settings",nil);slider(c,"Max distance","espRange",50,3000,50," studs");slider(c,"Update rate","espRate",2,30,1," Hz");checkbox(c,"ESP suave","smoothESP")
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

left,right=page("Automation",6)
pending(left,"Auto Spin Wheel","autoWheel");pending(left,"Auto Map Vote","autoVote")
c=card(left,"Utilities",nil);checkbox(c,"Anti-Idle","antiIdle")
actionButton(c,"Rejoin Server",function() API.Rejoin() end)
pending(right,"Auto Claim Journey","autoJourney");pending(right,"Disable Anti-AFK","disableGameAFK")
local _,expandUtility=card(right,"Sobre Anti-Idle",nil,"Anti-Idle so usa a API do cliente ao ficar ocioso. O sistema AFK proprio do jogo continua dependendo da integracao.")
expandUtility()

left,right=page("Performance",7)
local perfContent,perfExpand=card(left,"FPS Booster","fpsBoost","Reduz efeitos visuais localmente. Desligue uma opcao ou use Restore para recuperar os valores originais.")
local perfStatus=text(perfContent,"Status: off",9)
for _,v in ipairs({{"Remove Textures","removeTextures"},{"Remove Decals","removeDecals"},{"Remove Particles & Effects","removeParticles"},
    {"Low-Detail Materials","lowDetail"},{"Disable Shadows","noShadows"},{"No Fog & Atmosphere","noFog"},{"Remove Accessories","removeAccessories"}}) do checkbox(perfContent,v[1],v[2]) end
actionButton(perfContent,"Restore Graphics",function() set("fpsBoost",false);set("lowQuality",false) end);perfExpand()
c=card(right,"Display & Quality",nil,"FPS cap so aparece como ativo se o executor fornecer a API. O desempenho depende do aparelho e do jogo.")
checkbox(c,"Low render quality","lowQuality");checkbox(c,"Unlock FPS","unlockFPS");slider(c,"FPS Cap","fpsCap",30,240,10," fps")

left,right=page("Emotes",8)
local emoteContent,emoteExpand=card(left,"Avatar Emotes",nil,"Lista os emotes que ja estao equipados no seu avatar. A disponibilidade depende do rig e das animacoes carregadas.")
local emoteList=create("Frame",{Name="EmoteList",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},emoteContent)
create("UIListLayout",{Padding=UDim.new(0,4)},emoteList)
actionButton(emoteContent,"Refresh Emotes",function() API.RefreshEmotes() end);emoteExpand()
c=card(right,"Playback",nil);actionButton(c,"Stop Emote",function() API.StopEmote() end)

left,right=page("Config",9)
local customizeExpand
c,customizeExpand=card(left,"Customize UI",nil,"Cores, transparencia e escala. A interface se ajusta ao tamanho da tela.")
slider(c,"Escala do menu","uiScale",0.45,1.6,0.05,"x");cycle(c,"Theme","theme",{"Dark","Black"})
slider(c,"Transparencia","transparency",0,85,1,"%");checkbox(c,"Notificacoes","notifications");checkbox(c,"Sound Effects","sounds")
cycle(c,"Accent Color","accent",{"Peach","Purple","Blue","Pink","Green"});checkbox(c,"Rainbow Accent","rainbow")
customizeExpand()
c=card(left,"Interface",nil);cycle(c,"Toggle Menu Key","toggleKey",{"RightShift","LeftAlt","Insert","F4"});checkbox(c,"Floating Logo Button","floating")
actionButton(c,"Reset Position",function() window.Position=UDim2.fromScale(0.5,0.46);fit() end)
local configs,configExpand=card(right,"Configs",nil,"Salva no executor quando ha acesso a arquivos; caso contrario, guarda apenas nesta sessao.")
local configName=create("TextBox",{Name="ConfigName",Size=UDim2.new(1,0,0,27),Text="my-config",PlaceholderText="Config name",ClearTextOnFocus=false,
    BackgroundColor3=Color3.fromRGB(36,29,44),TextColor3=colors.text,TextSize=10,Font=Enum.Font.GothamMedium,BorderSizePixel=0},configs);round(configName,5)
surface(configName,0)
actionButton(configs,"Save Config",function() API.SaveConfig(configName.Text) end)
actionButton(configs,"Load Config",function() API.LoadConfig(configName.Text) end)
actionButton(configs,"Delete Config",function() API.DeleteConfig(configName.Text) end)
checkbox(configs,"Auto-Load This Config On Launch","autoLoad");configExpand()
local suite,suiteExpand=card(right,"Suite",nil,"HUSS VALLEY / 0.2.0")
actionButton(suite,"Rejoin Server",function() API.Rejoin() end)
actionButton(suite,"Destroy Menu",function() API.Destroy() end)
actionButton(suite,"Copiar diagnostico",function() API.ExportDiagnostics() end);suiteExpand()
bootProgress(0.7,"Interface ready / connecting controls...")

-- Rainbow updates only accent colors on visible pages, never the full theme.
refreshAccent=function()
    accent=cfg.rainbow and Color3.fromHSV((os.clock()*0.08)%1,0.45,1) or palette[cfg.accent]
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
actions.floating=function(v) floating.Visible=v or not state.visible end

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
actions.fpsBoost=function(v) if v then schedulePerformance() else refreshPerformance() end end
for _,key in ipairs({"removeTextures","removeDecals","removeParticles","lowDetail","noShadows","noFog","removeAccessories"}) do actions[key]=function() if cfg.fpsBoost then schedulePerformance() end end end
listen(Lighting.DescendantAdded,function(o) if cfg.fpsBoost then if perfCache then perfCache[o]=true end;optimize(o) end end)
actions.lowQuality=function(v)
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
local function sameTeam(p) return player.Team~=nil and p.Team==player.Team end
local function nearest(radius)
    local _,_,root=character();if not root then return end
    local target,best
    best=radius*radius
    for _,p in ipairs(roster) do
        if p~=player and not (cfg.teamCheck and sameTeam(p)) then
            local a=actor(p);local h,r=a.hum,a.root
            if h and r and h.Health>0 then local delta=r.Position-root.Position;local d=delta.X*delta.X+delta.Y*delta.Y+delta.Z*delta.Z;if d<best then best=d;target=r end end
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
    for prompt in pairs(prompts) do
        if prompt.Parent and prompt.Enabled then
            local label=string.lower(prompt.ActionText.." "..prompt.ObjectText.." "..prompt.Name)
            local wanted=(cfg.autoRevive and label:find("reviv",1,true)) or
                (cfg.autoPick and (label:find("pick",1,true) or label:find("collect",1,true) or label:find("colet",1,true)))
            local parent=prompt.Parent;local pos
            if parent:IsA("Attachment") then pos=parent.WorldPosition elseif parent:IsA("BasePart") then pos=parent.Position
            elseif parent:IsA("Model") then pos=parent:GetPivot().Position end
            if wanted and pos and (pos-root.Position).Magnitude<=prompt.MaxActivationDistance then
                local ok=pcall(fireproximityprompt,prompt)
                if not ok then set("autoPick",false);set("autoRevive",false);notify("O executor nao conseguiu acionar esse prompt.") end
                break
            end
        end
    end
end
local function checkPromptCapability(v)
    if v and type(fireproximityprompt)~="function" then error("fireproximityprompt indisponivel") end
    if v then preparePrompts() end
end
actions.autoPick=checkPromptCapability;actions.autoRevive=checkPromptCapability
local function triggerTool()
    local char=player.Character;local tool=char and char:FindFirstChildOfClass("Tool")
    if tool then tool:Activate() end
end
local adapterTimers,activeAdapters={},{}
local function stepAdapters(dt)
    for key,name in pairs(activeAdapters) do
        if cfg[key] and type(adapters[name])=="function" and not state.pending[key] then
            adapterTimers[key]=(adapterTimers[key] or 0)+dt
            if adapterTimers[key]>=0.25 then
                adapterTimers[key]=0;state.pending[key]=true
                task.spawn(function()
                    local ok,err=pcall(adapters[name],{Player=player,Config=cfg,Character=player.Character,Delta=0.25,Enabled=true,
                        IsActive=function() return state.alive and cfg[key] end})
                    state.pending[key]=nil
                    if not ok and state.alive then set(key,false,true);notify("Integracao interrompida: "..name);warn("[HV] "..tostring(err)) end
                end)
            end
        end
    end
end
for key,name in pairs(requiresAdapter) do actions[key]=function(v)
    activeAdapters[key]=v and name or nil
    if not v and type(adapters[name])=="function" then adapters[name]({Player=player,Config=cfg,Enabled=false}) end
end end
listen(player.Idled,function()
    if not cfg.antiIdle then return end
    local ok=pcall(function()
        local vu=game:GetService("VirtualUser");vu:CaptureController();vu:ClickButton2(Vector2.new(0,0))
    end)
    if not ok then set("antiIdle",false);notify("Anti-Idle indisponivel nesta versao do executor.") end
end)
function API.Rejoin()
    if game.JobId~="" then Teleport:TeleportToPlaceInstance(game.PlaceId,game.JobId,player) else Teleport:Teleport(game.PlaceId,player) end
end

-- ESP objects are created per player and reused. Nothing is drawn while disabled.
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
    local hp=create("Frame",{Name="Health",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(0,-4,1,0),Size=UDim2.new(0,2,1,0),BackgroundColor3=Color3.fromRGB(112,226,151),BorderSizePixel=0},f)
    local detail=text(f,"",9,{Name="Distance",Position=UDim2.new(0,-30,1,2),Size=UDim2.new(1,60,0,15),TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0.3},true)
    local tracer=line(f,0,0,0,0,accent,1)
    local view=line(f,0,0,0,0,accent,1)
    local dot=create("Frame",{Name="HeadDot",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundColor3=accent,BorderSizePixel=0},f);round(dot,6)
    local highlight=create("Highlight",{Name="HVChams",Enabled=false,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
        FillTransparency=0.7,OutlineTransparency=0.1,FillColor=accent,OutlineColor=accent},visuals)
    r={frame=f,box=box,stroke=stroke,name=name,hp=hp,detail=detail,tracer=tracer,view=view,dot=dot,highlight=highlight,joints={},bones={}}
    espRecords[p]=r;return r
end
local function moveLine(object,x1,y1,x2,y2)
    local dx,dy=x2-x1,y2-y1;object.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2)
    object.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),1);object.Rotation=math.deg(math.atan2(dy,dx))
end
local function setESPBounds(r,x,y,w,h)
    if r.desired and math.abs(r.desired[1]-x)<0.02 and math.abs(r.desired[2]-y)<0.02 and math.abs(r.desired[3]-w)<0.02 and math.abs(r.desired[4]-h)<0.02 then return end
    r.desired={x,y,w,h}
    if not r.draw or not cfg.smoothESP then
        r.draw={x,y,w,h};r.frame.Position=UDim2.fromOffset(x,y);r.frame.Size=UDim2.fromOffset(w,h)
    end
    r.moving=true
end
local function writeChanged(object,property,value) if object[property]~=value then object[property]=value end end
local function renderESP(dt)
    if not cfg.smoothESP or not (cfg.esp or cfg.viewTracer) then return end
    local alpha=1-math.exp(-24*dt)
    for _,r in pairs(espRecords) do
        if r.frame.Visible and r.moving and r.draw and r.desired then
            local largest=0
            for i=1,4 do local delta=r.desired[i]-r.draw[i];largest=math.max(largest,math.abs(delta));r.draw[i]=r.draw[i]+delta*alpha end
            if largest<0.05 then r.moving=false;for i=1,4 do r.draw[i]=r.desired[i] end end
            r.frame.Position=UDim2.fromOffset(r.draw[1],r.draw[2]);r.frame.Size=UDim2.fromOffset(r.draw[3],r.draw[4])
        end
    end
end
local function updateESP()
    local cam=workspace.CurrentCamera;local _,_,localRoot=character()
    if not cam or not localRoot then for p in pairs(espRecords) do clearRecord(p) end;return end
    if not (cfg.esp or cfg.chams or cfg.viewTracer) then for p in pairs(espRecords) do clearRecord(p) end;return end
    for _,p in ipairs(roster) do
        if p~=player then
            local a=actor(p);local ch,h,root=a.char,a.hum,a.root
            local dist=root and (root.Position-localRoot.Position).Magnitude or math.huge
            local eligible=root and h and h.Health>0 and dist<=cfg.espRange and not(cfg.teamFilter and sameTeam(p))
            if not eligible then clearRecord(p)
            else
                local r=recordFor(p);local color=cfg.roleColors and p.Team and p.TeamColor.Color or accent
                writeChanged(r.highlight,"Enabled",cfg.chams);writeChanged(r.highlight,"Adornee",ch);writeChanged(r.highlight,"FillColor",color);writeChanged(r.highlight,"OutlineColor",color)
                local center,on=cam:WorldToViewportPoint(root.Position)
                writeChanged(r.frame,"Visible",on and (cfg.esp or cfg.viewTracer))
                if on and (cfg.esp or cfg.viewTracer) then
                    if r.boundsCharacter~=ch or not r.nextBounds or (state.elapsed or 0)>=r.nextBounds then
                        local bounds,size=ch:GetBoundingBox();r.boundOffset=root.CFrame:ToObjectSpace(bounds);r.boundSize=size
                        r.boundsCharacter=ch;r.nextBounds=(state.elapsed or 0)+0.5
                    end
                    local cf,size=root.CFrame*r.boundOffset,r.boundSize
                    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
                    local validBox=true
                    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                        local v=cam:WorldToViewportPoint(cf*Vector3.new(size.X*x/2,size.Y*y/2,size.Z*z/2))
                        if v.Z<=0 then validBox=false end
                        minX=math.min(minX,v.X);minY=math.min(minY,v.Y);maxX=math.max(maxX,v.X);maxY=math.max(maxY,v.Y)
                    end end end
                    if validBox then
                        setESPBounds(r,minX,minY,maxX-minX,maxY-minY)
                        writeChanged(r.box,"Visible",cfg.esp and cfg.boxes);writeChanged(r.stroke,"Color",color)
                        writeChanged(r.name,"Visible",cfg.esp and cfg.names);writeChanged(r.name,"Text",p.DisplayName)
                        writeChanged(r.detail,"Visible",cfg.esp and (cfg.distance or cfg.healthText))
                        writeChanged(r.detail,"Text",(cfg.distance and string.format("%d studs",math.floor(dist)) or "")..(cfg.healthText and string.format("  %d HP",math.floor(h.Health)) or ""))
                        writeChanged(r.hp,"Visible",cfg.esp and cfg.health)
                        local healthRatio=math.clamp(h.Health/math.max(1,h.MaxHealth),0,1)
                        if r.healthRatio~=healthRatio then r.healthRatio=healthRatio;r.hp.Size=UDim2.new(0,2,healthRatio,0) end
                        writeChanged(r.tracer,"Visible",cfg.esp and cfg.tracers);writeChanged(r.tracer,"BackgroundColor3",color)
                        if r.tracer.Visible then moveLine(r.tracer,cam.ViewportSize.X/2-minX,cam.ViewportSize.Y-minY,center.X-minX,maxY-minY) end
                        if not a.head or not a.head.Parent then a.head=ch:FindFirstChild("Head") end
                        local head=a.head or root;local start=cam:WorldToViewportPoint(head.Position)
                        local finish=cam:WorldToViewportPoint(head.Position+head.CFrame.LookVector*5)
                        writeChanged(r.view,"Visible",cfg.viewTracer and finish.Z>0);writeChanged(r.view,"BackgroundColor3",color)
                        if r.view.Visible then moveLine(r.view,start.X-minX,start.Y-minY,finish.X-minX,finish.Y-minY) end
                        writeChanged(r.dot,"Visible",cfg.esp and cfg.headDot);writeChanged(r.dot,"BackgroundColor3",color)
                        if r.dot.Visible then r.dot.Position=UDim2.fromOffset(start.X-minX,start.Y-minY) end
                        if cfg.skeleton and cfg.esp then
                            if r.character~=ch then
                                for _,b in ipairs(r.bones) do b:Destroy() end;r.joints={};r.bones={};r.character=ch
                                for _,joint in ipairs(ch:GetDescendants()) do
                                    if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
                                        r.joints[#r.joints+1]=joint;r.bones[#r.bones+1]=line(r.frame,0,0,0,0,color,1)
                                    end
                                end
                            end
                            for i,joint in ipairs(r.joints) do
                                local b=r.bones[i];b.Visible=false
                                if joint.Part0 and joint.Part1 then
                                    local a=cam:WorldToViewportPoint(joint.Part0.Position);local v=cam:WorldToViewportPoint(joint.Part1.Position)
                                    b.Visible=a.Z>0 and v.Z>0;b.BackgroundColor3=color;moveLine(b,a.X-minX,a.Y-minY,v.X-minX,v.Y-minY)
                                end
                            end
                        else for _,b in ipairs(r.bones) do b.Visible=false end end
                    else r.frame.Visible=false end
                end
            end
        end
    end
end
listen(Players.PlayerRemoving,clearRecord)
for _,key in ipairs({"esp","chams","viewTracer"}) do actions[key]=updateESP end
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

-- Named configurations: strict keys and bounded values; no arbitrary file paths.
env.HussValleyConfigSession=env.HussValleyConfigSession or {}
local session=env.HussValleyConfigSession
local fileStore=type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function" and type(makefolder)=="function"
local function safeName(name)
    local result=tostring(name):gsub("[^%w_%-]",""):sub(1,40)
    assert(#result>0,"Escolha um nome com letras ou numeros.");return result
end
local function path(name) return "HussValleyPanel/"..safeName(name)..".json" end
local function configData() local data={};for k in pairs(defaults) do data[k]=cfg[k] end;return data end
local function saveRecord(name,data)
    session[name]=data
    if fileStore then
        local ok=pcall(function() if type(isfolder)~="function" or not isfolder("HussValleyPanel") then makefolder("HussValleyPanel") end;writefile(path(name),Http:JSONEncode(data)) end)
        if not ok then notify("Acesso a arquivos falhou; configuracao mantida so nesta sessao.");return false end
        return true
    end
    return false
end
local function loadRecord(name)
    if fileStore then
        local ok,result=pcall(function() if isfile(path(name)) then return Http:JSONDecode(readfile(path(name))) end end)
        if ok and type(result)=="table" then return result end
    end
    return session[name]
end
function API.SaveConfig(name)
    name=safeName(name);assert(name~="_autoload","Este nome e reservado.");configName.Text=name
    local persisted=saveRecord(name,configData())
    saveRecord("_autoload",{name=name,enabled=cfg.autoLoad})
    notify(persisted and "Config salva: "..name or "Config salva nesta sessao: "..name)
end
function API.LoadConfig(name,quiet)
    name=safeName(name);assert(name~="_autoload","Este nome e reservado.");local data=loadRecord(name)
    if not data then if not quiet then notify("Config nao encontrada: "..name) end;return false end
    configName.Text=name
    if data.transparency==nil and type(data.opacity)=="number" then data.transparency=math.clamp((1-data.opacity)*100,0,85) end
    -- Apply non-booleans first so enabled features receive their configured values.
    for _,booleans in ipairs({false,true}) do for key in pairs(defaults) do
        if key~="opacity" and data[key]~=nil and (type(defaults[key])=="boolean")==booleans then set(key,data[key],true) end
    end end
    if not quiet then notify("Config carregada: "..name) end;return true
end
function API.DeleteConfig(name)
    name=safeName(name);assert(name~="_autoload","Este nome e reservado.");session[name]=nil
    if fileStore and isfile(path(name)) then
        if type(delfile)~="function" then notify("Esta versao do executor nao permite apagar a config do disco.");return end
        delfile(path(name))
    end
    local auto=loadRecord("_autoload");if auto and auto.name==name then saveRecord("_autoload",{enabled=false}) end
    notify("Config removida: "..name)
end
actions.autoLoad=function(value)
    local name=safeName(configName.Text)
    assert(name~="_autoload","Este nome e reservado.")
    saveRecord("_autoload",{name=name,enabled=value})
end

-- Diagnostic data stays local: only paths/classes and selected game-state attributes.
local diagnosticBox
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
        for _,key in ipairs({"Role","Team","State","Downed","Caught","IsCatcher","IsRunner","InRound"}) do
            local v=p:GetAttribute(key);if type(v)=="string" or type(v)=="boolean" or type(v)=="number" then row.attributes[key]=v end
            local ch=p.Character;local cv=ch and ch:GetAttribute(key);if type(cv)=="string" or type(cv)=="boolean" or type(cv)=="number" then row.attributes["Character."..key]=cv end
        end
        report.roles[#report.roles+1]=row
    end
    local data=Http:JSONEncode(report)
    if type(setclipboard)=="function" and pcall(setclipboard,data) then notify("Diagnostico copiado. Envie o texto para mapear as automacoes.")
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

-- One heartbeat and one late camera update. Expensive work is rate-limited.
local elapsed,speedElapsed,promptElapsed,attackElapsed,gearElapsed,espElapsed,hueElapsed,aimElapsed=0,0,0,0,0,0,0,0
actions.lockOn=function() state.aimTarget=nil;aimElapsed=1 end
actions.radius=function() aimElapsed=1 end
actions.teamCheck=function() aimElapsed=1 end
listen(Run.Heartbeat,function(dt)
    if not state.alive then return end
    elapsed=elapsed+dt;state.elapsed=elapsed;speedElapsed=speedElapsed+dt;promptElapsed=promptElapsed+dt;attackElapsed=attackElapsed+dt;gearElapsed=gearElapsed+dt;espElapsed=espElapsed+dt;hueElapsed=hueElapsed+dt;aimElapsed=aimElapsed+dt
    local char,hum,root=character();local cam=workspace.CurrentCamera
    if speedElapsed>=0.1 then speedElapsed=0;applySpeed() end
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
        if cfg.autoAttack and attackElapsed>=cfg.attackDelay then attackElapsed=0;if nearest(cfg.attackRange) then triggerTool() end end
        if cfg.autoGears and gearElapsed>=cfg.gearDelay then gearElapsed=0;triggerTool() end
    end
    if promptElapsed>=cfg.promptDelay then promptElapsed=0;processPrompts() end
    if espElapsed>=1/cfg.espRate then espElapsed=0;updateESP() end
    if cfg.lockOn and aimElapsed>=0.1 then aimElapsed=0;state.aimTarget=nearest(cfg.radius) end
    stepAdapters(dt)
    if hueElapsed>=0.15 then hueElapsed=0;if cfg.rainbow then refreshAccent() end end
end)
local renderBindingName="HussValleyPanelCamera_"..player.UserId
Run:BindToRenderStep(renderBindingName,Enum.RenderPriority.Camera.Value+1,function(dt)
    if not state.alive then return end
    state.frames=state.frames+1;state.time=state.time+dt
    if uiDirty and state.visible then applyAppearance() end
    renderESP(dt)
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
listen(close.Activated,API.Destroy)
fit();refreshTheme();selectPage("Combat")
window.Visible=false
task.defer(function()
    if not state.alive then return end
    bootProgress(0.85,"Applying your settings...")
    API.RefreshEmotes();local auto=loadRecord("_autoload")
    if auto and auto.enabled and type(auto.name)=="string" then API.LoadConfig(auto.name,true) end
    bootProgress(1,"Ready")
    task.delay(0.18,function()
        if state.alive then boot:Destroy();show(true);notify("Huss Valley / painel carregado. Integracoes pendentes estao identificadas nas opcoes.") end
    end)
end)
return API
