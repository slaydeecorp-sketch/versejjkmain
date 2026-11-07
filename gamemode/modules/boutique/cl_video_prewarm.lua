local BT = VERSE.Boutique

BT._videoPrewarm = BT._videoPrewarm or {
    warmed = {},
    failed = {},
    queue = {},
    active = nil,
    startedAt = 0,
    frame = nil,
    html = nil,
    ready = false,
}

local PW = BT._videoPrewarm
local MAX_WAIT = 180
local TICK = 0.5

local function isHttp(url)
    if type(url) ~= "string" or url == "" then return false end
    return url:find("^https?://") ~= nil
end

local function collectUrls()
    local seen = {}
    local list = {}

    local function push(url)
        if not isHttp(url) then return end
        if seen[url] then return end
        seen[url] = true
        if PW.warmed[url] or PW.failed[url] then return end
        list[#list + 1] = url
    end

    for _, p in pairs(BT.Products or {}) do
        if istable(p) then push(p.video_url) end
    end

    local pools = BT.RerollPool or {}
    for _, pool in pairs(pools) do
        if istable(pool) then
            for _, entry in pairs(pool) do
                if istable(entry) then push(entry.video_url) end
            end
        end
    end

    return list
end

local function ensureFrame()
    if IsValid(PW.frame) and IsValid(PW.html) and PW.ready then return end

    if IsValid(PW.frame) then PW.frame:Remove() end

    local frame = vgui.Create("DFrame")
    frame:SetSize(4, 4)
    frame:SetPos(-50, -50)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetMouseInputEnabled(false)
    frame:SetKeyboardInputEnabled(false)
    frame:SetAlpha(0)
    frame.Paint = function() end

    local html = vgui.Create("DHTML", frame)
    html:SetSize(4, 4)
    html:SetPos(0, 0)
    html:SetMouseInputEnabled(false)
    html:SetKeyboardInputEnabled(false)

    html:AddFunction("", "warmReady", function()
        PW.ready = true
    end)

    html:AddFunction("", "warmDone", function(url)
        if type(url) ~= "string" then return end
        PW.warmed[url] = true
        if PW.active == url then
            PW.active = nil
        end
    end)

    html:AddFunction("", "warmFail", function(url)
        if type(url) ~= "string" then return end
        PW.failed[url] = true
        if PW.active == url then
            PW.active = nil
        end
    end)

    html:SetHTML([[<!DOCTYPE html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:#000;width:100%;height:100%;overflow:hidden}</style></head><body><script>
(function(){
    window.__warmActive = {};
    function finish(url, ok){
        try { delete window.__warmActive[url]; } catch(e){}
        try { (ok ? window.warmDone : window.warmFail)(url); } catch(e){}
    }
    window.startWarm = function(url){
        if (window.__warmActive[url]) return;
        window.__warmActive[url] = true;
        try {
            fetch(url, { method: 'GET', mode: 'no-cors', credentials: 'omit', cache: 'force-cache' })
                .then(function(r){
                    if (!r) { finish(url, false); return; }
                    return r.blob().then(function(b){
                        if (!b || b.size < 1024) { finish(url, false); return; }
                        finish(url, true);
                    }).catch(function(){ finish(url, false); });
                })
                .catch(function(){ finish(url, false); });
        } catch(e) {
            finish(url, false);
        }
    };
    try { window.warmReady(); } catch(e){}
})();
</script></body></html>]])

    PW.frame = frame
    PW.html = html
end

local function escJs(url)
    return (url:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

local function kickNext()
    if not IsValid(PW.html) then return end
    if not PW.ready then return end
    if PW.active then return end

    local url
    while true do
        url = table.remove(PW.queue, 1)
        if not url then return end
        if not PW.warmed[url] and not PW.failed[url] then break end
    end

    PW.active = url
    PW.startedAt = SysTime()
    PW.html:RunJavascript('startWarm("' .. escJs(url) .. '");')
end

function BT:PrewarmRollVideos()
    local urls = collectUrls()
    if #urls == 0 then return end
    ensureFrame()
    for _, u in ipairs(urls) do
        PW.queue[#PW.queue + 1] = u
    end
end

function BT:IsVideoPrewarmed(url)
    return PW.warmed[url] == true
end

function BT:ClearRollVideoWarmCache()
    PW.warmed = {}
    PW.failed = {}
    PW.queue = {}
    PW.active = nil
    if IsValid(PW.frame) then PW.frame:Remove() end
    PW.frame = nil
    PW.html = nil
    PW.ready = false
end

timer.Create("VERSE::Boutique::VideoPrewarmTick", TICK, 0, function()
    if not IsValid(PW.html) then return end
    if not PW.ready then return end

    if PW.active then
        if (SysTime() - PW.startedAt) > MAX_WAIT then
            PW.failed[PW.active] = true
            PW.active = nil
        end
        return
    end

    kickNext()
end)

-- ── Pré-création du panneau vidéo ────────────────────────────────────────────
BT._preVideo = BT._preVideo or { frame = nil, html = nil, url = "" }

local function buildPreVideoHtml(rawUrl)
    local url = BT:GetVideoUrl(rawUrl)
    return [[<!DOCTYPE html><html><head><style>*{margin:0;padding:0;overflow:hidden;background:#000}html,body{width:100%;height:100%}video{display:block;width:100%;height:100%;object-fit:cover;background:#000}</style></head><body><video id="v" src="]] .. url .. [[" autoplay muted playsinline preload="auto"></video><script>
var v=document.getElementById("v"),started=false,done=false,lastTime=-1,lastProgressAt=0,bornAt=Date.now();
window.__preVideoStarted=false;window.__preVideoDuration=0;
function callLua(n,a){try{if(window.verseVideo&&typeof window.verseVideo[n]==="function"){if(a===undefined)window.verseVideo[n]();else window.verseVideo[n](a);}}catch(e){}}
function doStart(){
    if(started)return;started=true;
    lastTime=v.currentTime||0;lastProgressAt=Date.now();
    var dur=isFinite(v.duration)?v.duration:0;
    window.__preVideoStarted=true;window.__preVideoDuration=dur;
    callLua("started",dur);
}
function doEnded(){if(done)return;done=true;callLua("done");}
v.addEventListener("playing",function(){doStart();});
v.addEventListener("ended",function(){doEnded();});
v.addEventListener("timeupdate",function(){
    if(!started&&v.currentTime>0){doStart();}
    if(!started)return;
    if(v.currentTime!==lastTime){lastTime=v.currentTime;lastProgressAt=Date.now();}
    if(isFinite(v.duration)&&v.duration>0&&v.currentTime>=v.duration-0.15){doEnded();}
});
setInterval(function(){
    var now=Date.now();
    if(!started){if(now-bornAt>15000){doEnded();}return;}
    if(v.ended){doEnded();return;}
    if(isFinite(v.duration)&&v.duration>0&&v.currentTime>=v.duration-0.15){doEnded();return;}
    if(now-lastProgressAt>6000){doEnded();return;}
},250);
v.addEventListener("error",function(){if(!started){callLua("err");}});
v.play().catch(function(){if(!started){callLua("err");}});
</script></body></html>]]
end

BT.BuildPreVideoHtml = buildPreVideoHtml

function BT.BuildVideoHtml(rawUrl)
    local url = BT:GetVideoUrl(rawUrl)
    return [[<!DOCTYPE html><html><head><style>*{margin:0;padding:0;overflow:hidden;background:#000}html,body{width:100%;height:100%}video{display:block;width:100%;height:100%;object-fit:cover;background:#000}</style></head><body><video id="v" src="]] .. url .. [[" autoplay muted playsinline preload="auto"></video><script>
var v=document.getElementById("v"),started=false,done=false,lastTime=-1,lastProgressAt=0,bornAt=Date.now();
function callLua(n,a){try{if(window.verseVideo&&typeof window.verseVideo[n]==="function"){if(a===undefined)window.verseVideo[n]();else window.verseVideo[n](a);}}catch(e){}}
function doStart(){
    if(started)return;started=true;
    try{v.muted=false;v.volume=1;}catch(e){}
    lastTime=v.currentTime||0;lastProgressAt=Date.now();
    var dur=isFinite(v.duration)?v.duration:0;
    callLua("started",dur);
}
function doEnded(){if(done)return;done=true;callLua("done");}
v.addEventListener("playing",function(){doStart();});
v.addEventListener("ended",function(){doEnded();});
v.addEventListener("timeupdate",function(){
    if(!started&&v.currentTime>0){doStart();}
    if(!started)return;
    if(v.currentTime!==lastTime){lastTime=v.currentTime;lastProgressAt=Date.now();}
    if(isFinite(v.duration)&&v.duration>0&&v.currentTime>=v.duration-0.15){doEnded();}
});
setInterval(function(){
    var now=Date.now();
    if(!started){if(now-bornAt>15000){doEnded();}return;}
    if(v.ended){doEnded();return;}
    if(isFinite(v.duration)&&v.duration>0&&v.currentTime>=v.duration-0.15){doEnded();return;}
    if(now-lastProgressAt>6000){doEnded();return;}
},250);
v.addEventListener("error",function(){if(!started){callLua("err");}});
v.play().catch(function(){if(!started){callLua("err");}});
</script></body></html>]]
end

function BT:PrecreateVideoPanel(url)
    if type(url) ~= "string" or url == "" then return end
    local pv = BT._preVideo
    if IsValid(pv.frame) and pv.url == url then return end
    if IsValid(pv.frame) then pv.frame:Remove() end

    local frame = vgui.Create("DFrame")
    frame:SetSize(1, 1)
    frame:SetPos(-500, -500)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetMouseInputEnabled(false)
    frame:SetKeyboardInputEnabled(false)
    frame:SetAlpha(0)
    frame.Paint = function() end

    local html = vgui.Create("DHTML", frame)
    html:SetSize(1, 1)
    html:SetMouseInputEnabled(false)
    html:SetKeyboardInputEnabled(false)
    html:AddFunction("verseVideo", "started", function() end)
    html:AddFunction("verseVideo", "done",    function() end)
    html:AddFunction("verseVideo", "err",     function() end)
    html:SetHTML(buildPreVideoHtml(url))

    pv.frame = frame
    pv.html  = html
    pv.url   = url
end

function BT:ConsumePrecreatedVideoPanel(url)
    local pv = BT._preVideo
    if not IsValid(pv.html) or pv.url ~= url then return nil, nil end
    local h, f = pv.html, pv.frame
    pv.frame = nil
    pv.html  = nil
    pv.url   = ""
    return h, f
end

VERSE.Hook.AddNS("Boutique", "InitPostEntity", "VERSE::InitPostEntity::VideoPrewarm", function()
    timer.Simple(5, function() BT:PrewarmRollVideos() end)
end)

if not BT._videoPrewarm._hookedSync then
    BT._videoPrewarm._hookedSync = true
    local oldSetState = BT.SetStateFromSync
    function BT:SetStateFromSync(sync)
        oldSetState(self, sync)
        timer.Simple(0.5, function() if IsValid(LocalPlayer()) then BT:PrewarmRollVideos() end end)
    end
end

-- ── Téléchargement local des vidéos héritage ────────────────────────────────
local _DL_DIR = "verse/videos/"
BT._localVideos   = BT._localVideos   or {}
BT._dlQueue       = BT._dlQueue       or {}
BT._dlActive      = BT._dlActive      or false

local function _videoLocalPath(url)
    return _DL_DIR .. util.CRC(url) .. ".mp4"
end

local function _collectHeritageUrls()
    local seen, list = {}, {}
    local pools = BT.RerollPool or {}
    for _, pool in pairs(pools) do
        if istable(pool) then
            for _, entry in pairs(pool) do
                local u = istable(entry) and entry.video_url or nil
                if isstring(u) and u ~= "" and u:find("^https?://") and not seen[u] then
                    seen[u] = true
                    list[#list + 1] = u
                end
            end
        end
    end
    return list
end

local function _processQueue()
    if BT._dlActive then return end
    local url = table.remove(BT._dlQueue, 1)
    if not url then return end
    BT._dlActive = true
    http.Fetch(url, function(body, size, headers, code)
        BT._dlActive = false
        if code >= 200 and code < 300 and body and #body > 1024 then
            file.Write(_videoLocalPath(url), body)
            BT._localVideos[url] = _videoLocalPath(url)
        end
        _processQueue()
    end, function()
        BT._dlActive = false
        _processQueue()
    end)
end

function BT:DownloadHeritageVideos()
    if not file.IsDir(_DL_DIR, "DATA") then file.CreateDir(_DL_DIR) end
    local urls = _collectHeritageUrls()
    for _, url in ipairs(urls) do
        local localPath = _videoLocalPath(url)
        if file.Exists(localPath, "DATA") then
            BT._localVideos[url] = localPath
        else
            local alreadyQueued = false
            for _, q in ipairs(BT._dlQueue) do if q == url then alreadyQueued = true break end end
            if not alreadyQueued then
                BT._dlQueue[#BT._dlQueue + 1] = url
            end
        end
    end
    _processQueue()
end

function BT:GetVideoUrl(url)
    if type(url) ~= "string" or url == "" then return url end
    local localPath = BT._localVideos[url]
    if localPath and file.Exists(localPath, "DATA") then
        local full = file.FullPath(localPath, "DATA")
        if full and full ~= "" then
            full = full:gsub("\\", "/")
            if not full:find("^/") then full = "/" .. full end
            return "file://" .. full
        end
    end
    return url
end

if not BT._videoPrewarm._hookedDL then
    BT._videoPrewarm._hookedDL = true
    local oldSetState2 = BT.SetStateFromSync
    function BT:SetStateFromSync(sync)
        oldSetState2(self, sync)
        local delay = 5 + math.random(0, 20)
        timer.Simple(delay, function() if IsValid(LocalPlayer()) then BT:DownloadHeritageVideos() end end)
    end
end

VERSE.Hook.AddNS("Boutique", "InitPostEntity", "VERSE::InitPostEntity::VideoDownload", function()
    local delay = 15 + math.random(0, 30)
    timer.Simple(delay, function() if IsValid(LocalPlayer()) then BT:DownloadHeritageVideos() end end)
end)
