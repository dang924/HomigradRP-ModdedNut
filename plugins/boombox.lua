PLUGIN.name = "BoomBox"
PLUGIN.author = "GitHub Copilot"
PLUGIN.desc = "Player-anchored boombox playback from the context menu."

nut.config.add(
	"boomboxRadius",
	700,
	"Radius for BoomBox out-loud playback.",
	nil,
	{
		form = "Int",
		data = {min = 128, max = 3000},
		category = PLUGIN.name
	}
)

if (SERVER) then
	util.AddNetworkString("nutBoomBoxPlay")
	util.AddNetworkString("nutBoomBoxPlayRequest")
	util.AddNetworkString("nutBoomBoxStop")
	util.AddNetworkString("nutBoomBoxState")

	local function sanitizeUrl(url)
		url = string.Trim(tostring(url or ""))
		if (url == "" or #url > 2048) then
			return nil
		end

		local lower = string.lower(url)
		if (not lower:find("http://", 1, true) and not lower:find("https://", 1, true)) then
			return nil
		end

		return url
	end

	local function setBroadcastState(client, state)
		if (not IsValid(client)) then
			return
		end

		client.nutBoomBoxBroadcasting = state and true or nil

		net.Start("nutBoomBoxState")
			net.WriteEntity(client)
			net.WriteBool(state == true)
		net.Broadcast()
	end

	local function stopBroadcast(client)
		if (not IsValid(client) or not client.nutBoomBoxBroadcasting) then
			return
		end

		client.nutBoomBoxBroadcasting = nil
		client.nutBoomBoxBroadcastUrl = nil

		net.Start("nutBoomBoxStop")
			net.WriteEntity(client)
			net.WriteBool(true)
		net.Broadcast()

		setBroadcastState(client, false)
	end

	net.Receive("nutBoomBoxPlayRequest", function(_, client)
		if (not IsValid(client) or not client:IsPlayer()) then
			return
		end

		local mode = net.ReadUInt(2)
		if (mode == 0) then
			stopBroadcast(client)
			return
		end

		if ((client.nutBoomBoxNextUse or 0) > CurTime()) then
			return
		end

		client.nutBoomBoxNextUse = CurTime() + 0.35

		local url = sanitizeUrl(net.ReadString())
		if (not url) then
			if (client.notify) then
				client:notify("Invalid URL.")
			end
			return
		end

		local outLoud = mode == 2

		if (outLoud) then
			stopBroadcast(client)
			local recipients = {}
			for _, target in ipairs(player.GetAll()) do
				if (target ~= client) then
					recipients[#recipients + 1] = target
				end
			end

			net.Start("nutBoomBoxPlay")
				net.WriteEntity(client)
				net.WriteString(url)
				net.WriteBool(true)
			net.Send(recipients)

			client.nutBoomBoxBroadcastUrl = url
			setBroadcastState(client, true)
		else
			client.nutBoomBoxBroadcastUrl = nil
			net.Start("nutBoomBoxPlay")
				net.WriteEntity(client)
				net.WriteString(url)
				net.WriteBool(false)
			net.Send(client)
		end
	end)

	function PLUGIN:PlayerInitialSpawn(client)
		timer.Simple(1, function()
			if (not IsValid(client)) then
				return
			end

			for _, source in ipairs(player.GetAll()) do
				if (not IsValid(source) or not source.nutBoomBoxBroadcasting) then
					continue
				end

				local url = sanitizeUrl(source.nutBoomBoxBroadcastUrl)
				if (not url) then
					continue
				end

				net.Start("nutBoomBoxPlay")
					net.WriteEntity(source)
					net.WriteString(url)
					net.WriteBool(true)
				net.Send(client)

				net.Start("nutBoomBoxState")
					net.WriteEntity(source)
					net.WriteBool(true)
				net.Send(client)
			end
		end)
	end

	function PLUGIN:PlayerDisconnected(client)
		stopBroadcast(client)
	end

	function PLUGIN:PlayerDeath(client)
		stopBroadcast(client)
	end

	return
end

local BOOMBOX_ICON = Material("icon16/sound.png", "smooth")
local activeChannels = activeChannels or {}
local activeBroadcasters = activeBroadcasters or {}
local youtubePanels = youtubePanels or {}
local boomBoxVolumeCvar = CreateClientConVar("nut_boombox_volume", "0.5", true, false, "Local BoomBox listener volume (0.0 - 1.0)")

local function getBoomBoxPlugin()
	return nut and nut.plugin and nut.plugin.list and nut.plugin.list.boombox
end

local function notifyLocal(text)
	local client = LocalPlayer()
	if (IsValid(client) and client.notify) then
		client:notify(text)
	else
		chat.AddText(Color(255, 180, 80), "[BoomBox] ", color_white, text)
	end
end

local function stopChannel(key)
	local data = activeChannels[key]
	if (not data) then
		return
	end

	if (data.media) then
		-- navigate the browser to blank first so CEF actually stops audio
		if (data.media.GetBrowser) then
			local browser = data.media:GetBrowser()
			if (IsValid(browser)) then
				browser:OpenURL("about:blank")
			end
		end
		if (data.media.Stop) then
			data.media:Stop()
		end
	end

	if (IsValid(data.channel)) then
		data.channel:Stop()
	end

	activeChannels[key] = nil

	local yt = youtubePanels[key]
	if (IsValid(yt)) then
		yt:SetHTML("")  -- clear content so CEF stops audio before GC
		yt:Remove()
	end
	youtubePanels[key] = nil
end

local function stopLocalOnly()
	stopChannel("local")
end

local function stopBroadcastChannel(source)
	if (IsValid(source)) then
		stopChannel("broadcast_" .. source:EntIndex())
	end
end

local function stopAllChannels()
	for key in pairs(activeChannels) do
		stopChannel(key)
	end

	table.Empty(activeBroadcasters)
end

local function getListenerVolume()
	if (not boomBoxVolumeCvar) then
		return 0.5
	end

	return math.Clamp(boomBoxVolumeCvar:GetFloat() or 0.5, 0, 1)
end

local function getEffectiveVolume(outLoud, source)
	local volume = getListenerVolume()

	if (outLoud and IsValid(source)) then
		local radius = nut.config.get("boomboxRadius", 700)
		local dist = LocalPlayer():GetPos():Distance(source:GetPos())
		local maxDistance = radius * 1.35
		local t = math.Clamp(dist / maxDistance, 0, 1)
		local fraction = 1 - (t * t * (3 - 2 * t))
		volume = volume * fraction
	end

	return math.Clamp(volume, 0, 1)
end

local function findPanelRecursive(root, predicate)
	if (not IsValid(root) or not root.GetChildren) then
		return nil
	end

	for _, child in ipairs(root:GetChildren()) do
		if (predicate(child)) then
			return child
		end

		local nested = findPanelRecursive(child, predicate)
		if (IsValid(nested)) then
			return nested
		end
	end

	return nil
end

local function isPlayerModelButton(panel)
	if (not IsValid(panel) or not panel.GetText) then
		return false
	end

	local text = string.lower(string.Trim(panel:GetText() or ""))
	if (text == "") then
		return false
	end

	return text:find("player model", 1, true) ~= nil
		or text:find("playermodel", 1, true) ~= nil
		or text:find("model select", 1, true) ~= nil
end

local function extractYouTubeVideoId(rawUrl)
	local url = string.lower(tostring(rawUrl or ""))
	if (url == "") then
		return nil
	end

	local watch = url:match("[?&]v=([%w_%-%+]+)")
	if (watch) then
		return watch
	end

	local short = url:match("youtu%.be/([%w_%-%+]+)")
	if (short) then
		return short
	end

	local embed = url:match("youtube%.com/embed/([%w_%-%+]+)")
	if (embed) then
		return embed
	end

	local legacy = url:match("youtube%.com/v/([%w_%-%+]+)")
	if (legacy) then
		return legacy
	end

	return nil
end

local function runYouTubeVolume(panel, volume)
	if (not IsValid(panel)) then
		return
	end

	volume = math.Clamp(math.floor(volume or 0), 0, 100)
	panel:RunJavascript(string.format("if(window.nutBoomBoxSetVolume){nutBoomBoxSetVolume(%d);} if(window.MediaPlayer&&MediaPlayer.setVolume){MediaPlayer.setVolume(%d);} ", volume, volume))
end

local function kickYouTubePlayback(panel)
	if (not IsValid(panel)) then
		return
	end

	panel:RunJavascript([[ 
		if(window.nutBoomBoxForcePlay){ nutBoomBoxForcePlay(); }
		if(window.player){
			if(player.unMute){ player.unMute(); }
			if(player.playVideo){ player.playVideo(); }
		}
		if(window.MediaPlayer && MediaPlayer.play){ MediaPlayer.play(); }
		var vids = document.getElementsByTagName('video');
		for(var i = 0; i < vids.length; i++){
			try {
				vids[i].muted = false;
				vids[i].volume = 1;
				var p = vids[i].play && vids[i].play();
				if(p && p.catch){ p.catch(function(){}); }
			} catch(e) {}
		}
	]])
end

local function createYouTubePanel(key, videoId, url, source, outLoud)
	if (youtubePanels[key] and IsValid(youtubePanels[key])) then
		youtubePanels[key]:Remove()
	end

	local panel = vgui.Create("DHTML")
	panel:SetSize(320, 180)  -- Proper size so iframe renders, not 2x2
	panel:SetPos(math.max(ScrW() - 320, 0), math.max(ScrH() - 180, 0))  -- Off-screen but real size
	panel:SetMouseInputEnabled(false)
	panel:SetKeyboardInputEnabled(false)
	panel:SetAlpha(0)  -- Start fully hidden
	panel.nutBoomBoxSource = source
	panel.nutBoomBoxOutLoud = outLoud == true
	panel.nutBoomBoxLastVolume = -1
	panel.nutBoomBoxNextKick = CurTime() + 0.2
	panel.nutBoomBoxKey = key
	panel.nutBoomBoxUrl = url or ("https://www.youtube.com/watch?v=" .. videoId)

	local mediaPlayerBaseUrl = nil
	if (MediaPlayer and MediaPlayer.GetConfigValue) then
		mediaPlayerBaseUrl = MediaPlayer.GetConfigValue("html.base_url")
	end

	if (isstring(mediaPlayerBaseUrl) and mediaPlayerBaseUrl ~= "") then
		panel:OpenURL(mediaPlayerBaseUrl .. "youtube.html?v=" .. videoId .. "&timed=0")
		panel.OnDocumentReady = function(this)
			kickYouTubePlayback(this)
		end
		youtubePanels[key] = panel
		return panel
	end

	local html = [[
<!doctype html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#000;overflow:hidden;width:100%;height:100%;">
<div id="player" style="width:100%;height:100%;"></div>
<script>
var tag = document.createElement('script');
tag.src = 'https://www.youtube.com/iframe_api';
document.head.appendChild(tag);
var player;
function onYouTubeIframeAPIReady(){
	player = new YT.Player('player', {
		height: '100%',
		width: '100%',
		videoId: ']] .. videoId .. [[',
		playerVars: {
			autoplay: 1,
			controls: 0,
			rel: 0,
			playsinline: 1,
			fs: 0,
			modestbranding: 1
		},
		 events: {
			'onReady': function(e){
				e.target.playVideo();
				e.target.setVolume(100);
			}
		 }
	});
}
function nutBoomBoxSetVolume(v){
	if(player && player.setVolume){player.setVolume(v|0);}
}
function nutBoomBoxForcePlay(){
	if(player){
		if(player.unMute){player.unMute();}
		if(player.playVideo){player.playVideo();}
	}
}
</script>
</body>
</html>
]]

	panel:SetHTML(html)
	panel.OnDocumentReady = function(this)
		kickYouTubePlayback(this)
	end
	youtubePanels[key] = panel

	return panel
end

local function hideYouTubePanel(panel)
	if (not IsValid(panel)) then
		return
	end

	panel:SetParent(nil)
	panel:SetSize(320, 180)  -- Keep at rendering size
	panel:SetPos(math.max(ScrW() - 320, 0), math.max(ScrH() - 180, 0))  -- Off-screen
	panel:SetMouseInputEnabled(false)
	panel:SetKeyboardInputEnabled(false)
	panel:SetAlpha(0)  -- Fully transparent
end

local function showYouTubePanelInMenu(panel, container)
	if (not IsValid(panel) or not IsValid(container)) then
		return
	end

	panel:SetParent(container)
	panel:Dock(FILL)
	panel:InvalidateLayout()
	panel:SetMouseInputEnabled(true)
	panel:SetKeyboardInputEnabled(true)
	panel:SetAlpha(255)
	panel:SetVisible(true)
	panel:MoveToFront()
end

local function getPreviewPanelCandidate()
	local localClient = LocalPlayer()

	if (IsValid(youtubePanels["local"])) then
		return youtubePanels["local"]
	end

	if (activeChannels["local"] and activeChannels["local"].isMediaPlayer) then
		local media = activeChannels["local"].media
		local browser = media and media.GetBrowser and media:GetBrowser() or nil
		if (IsValid(browser)) then
			return browser
		end
	end

	if (IsValid(localClient)) then
		local broadcastKey = "broadcast_" .. localClient:EntIndex()
		if (activeChannels[broadcastKey] and activeChannels[broadcastKey].isMediaPlayer) then
			local media = activeChannels[broadcastKey].media
			local browser = media and media.GetBrowser and media:GetBrowser() or nil
			if (IsValid(browser)) then
				return browser
			end
		end
	end

	for key, panel in pairs(youtubePanels) do
		if (IsValid(panel)) then
			return panel
		end
	end

	for key, data in pairs(activeChannels) do
		if (data and data.isMediaPlayer and data.media and data.media.GetBrowser) then
			local browser = data.media:GetBrowser()
			if (IsValid(browser)) then
				return browser
			end
		end
	end

	return nil
end

function PLUGIN:PlayBoomBoxUrl(source, url, outLoud)
	url = string.Trim(tostring(url or ""))
	if (url == "") then
		notifyLocal("Please enter a URL.")
		return
	end

	local key = outLoud and (IsValid(source) and "broadcast_" .. source:EntIndex() or nil) or "local"
	if (not key) then
		return
	end

	stopChannel(key)

	local ytId = extractYouTubeVideoId(url)
	if (ytId and MediaPlayer and MediaPlayer.GetMediaForUrl) then
		local media = MediaPlayer.GetMediaForUrl(url, true)
		if (media and media.Id == "yt" and media.Play) then
			local volume = 1
			if (outLoud and IsValid(source)) then
				volume = getEffectiveVolume(true, source)
				activeBroadcasters[source] = true
			end

			media:Volume(math.Clamp(volume, 0, 1))
			media:Play()

			activeChannels[key] = {
				media = media,
				source = source,
				outLoud = outLoud,
				isMediaPlayer = true,
				lastVolume = -1,
				nextKick = CurTime() + 0.2,
				url = url
			}

			return
		end
	end

	if (ytId) then
		local panel = createYouTubePanel(key, ytId, url, source, outLoud)
		if (IsValid(panel)) then
			if (outLoud and IsValid(source)) then
				runYouTubeVolume(panel, getEffectiveVolume(true, source) * 100)
				activeBroadcasters[source] = true
			else
				runYouTubeVolume(panel, getEffectiveVolume(false, source) * 100)
			end

			kickYouTubePlayback(panel)
			return
		end
	end

	local flags = "noplay"
	sound.PlayURL(url, flags, function(channel, errCode, errName)
		if (not IsValid(channel)) then
			local errText = tostring(errName or errCode or "Unknown error")
			local ytId = extractYouTubeVideoId(url)

			if (ytId and errText:find("BASS_ERROR_FILEFORM", 1, true)) then
				local panel = createYouTubePanel(key, ytId, url, source, outLoud)
				if (IsValid(panel)) then
					if (outLoud and IsValid(source)) then
						runYouTubeVolume(panel, getEffectiveVolume(true, source) * 100)
						activeBroadcasters[source] = true
					else
						runYouTubeVolume(panel, getEffectiveVolume(false, source) * 100)
					end
					return
				end
			end

			notifyLocal("Playback failed. " .. errText .. ".")
			return
		end

		if (outLoud and IsValid(source)) then
			activeBroadcasters[source] = true
		end

		channel:SetVolume(getEffectiveVolume(outLoud, source))
		channel:Play()
		activeChannels[key] = {
			channel = channel,
			source = source,
			outLoud = outLoud,
			url = url
		}
	end)
end

function PLUGIN:OpenBoomBoxMenu()
	if (IsValid(self.boomBoxFrame)) then
		self.boomBoxFrame:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(470, math.min(300, ScrH() - 80))
	frame:Center()
	frame:SetTitle("BoomBox")
	frame:MakePopup()
	self.boomBoxFrame = frame

	local content = frame:Add("DScrollPanel")
	content:Dock(FILL)
	content:DockMargin(0, 4, 0, 0)

	local info = content:Add("DLabel")
	info:Dock(TOP)
	info:DockMargin(8, 8, 8, 6)
	info:SetTall(18)
	info:SetText("Paste a YouTube or direct audio URL, then choose how to play it.")

	local urlEntry = content:Add("DTextEntry")
	urlEntry:Dock(TOP)
	urlEntry:DockMargin(8, 0, 8, 8)
	urlEntry:SetTall(26)
	urlEntry:SetPlaceholderText("https://www.youtube.com/watch?v=...")

	local volumeRow = content:Add("DPanel")
	volumeRow:Dock(TOP)
	volumeRow:DockMargin(8, 0, 8, 8)
	volumeRow:SetTall(32)
	volumeRow.Paint = nil

	local volumeSlider = volumeRow:Add("DNumSlider")
	volumeSlider:Dock(FILL)
	volumeSlider:SetText("Volume")
	volumeSlider:SetMin(0)
	volumeSlider:SetMax(100)
	volumeSlider:SetDecimals(0)
	volumeSlider:SetValue(math.floor(getListenerVolume() * 100 + 0.5))
	volumeSlider.Label:SetWide(56)
	volumeSlider.TextArea:SetWide(40)

	local applyVolume = volumeRow:Add("DButton")
	applyVolume:Dock(RIGHT)
	applyVolume:DockMargin(8, 0, 0, 0)
	applyVolume:SetWide(92)
	applyVolume:SetText("Set Volume")
	applyVolume.DoClick = function()
		local value = math.Clamp(math.floor((volumeSlider:GetValue() or 50) + 0.5), 0, 100)
		local listenerVol = value / 100
		RunConsoleCommand("nut_boombox_volume", tostring(listenerVol))

		-- Apply immediately without waiting for CVar to propagate
		for key, data in pairs(activeChannels) do
			if (data.isMediaPlayer and data.media) then
				data.lastVolume = -1
				data.nextKick = 0
			elseif (IsValid(data.channel)) then
				local radius = nut.config.get("boomboxRadius", 700)
				local vol
				if (data.outLoud and IsValid(data.source)) then
					local dist = LocalPlayer():GetPos():Distance(data.source:GetPos())
					local t = math.Clamp(dist / (radius * 1.35), 0, 1)
					vol = listenerVol * (1 - t * t * (3 - 2 * t))
				else
					vol = listenerVol
				end
				data.channel:SetVolume(math.Clamp(vol, 0, 1))
			end
		end

		for key, panel in pairs(youtubePanels) do
			if (IsValid(panel)) then
				runYouTubeVolume(panel, getEffectiveVolume(panel.nutBoomBoxOutLoud, panel.nutBoomBoxSource) * 100)
				kickYouTubePlayback(panel)
			end
		end

		notifyLocal("BoomBox volume set to " .. value .. "%.")
	end

	local playOutLoud = content:Add("DButton")
	playOutLoud:Dock(TOP)
	playOutLoud:DockMargin(8, 0, 8, 6)
	playOutLoud:SetTall(28)
	playOutLoud:SetText("Play Out Loud")
	playOutLoud.DoClick = function()
		local url = string.Trim(urlEntry:GetValue() or "")
		if (url == "") then
			notifyLocal("Please enter a URL.")
			return
		end

		self:PlayBoomBoxUrl(LocalPlayer(), url, true)

		net.Start("nutBoomBoxPlayRequest")
			net.WriteUInt(2, 2)
			net.WriteString(url)
		net.SendToServer()
	end

	local playLocal = content:Add("DButton")
	playLocal:Dock(TOP)
	playLocal:DockMargin(8, 0, 8, 6)
	playLocal:SetTall(28)
	playLocal:SetText("Play")
	playLocal.DoClick = function()
		local url = string.Trim(urlEntry:GetValue() or "")
		if (url == "") then
			notifyLocal("Please enter a URL.")
			return
		end

		self:PlayBoomBoxUrl(LocalPlayer(), url, false)
	end

	local stopButton = content:Add("DButton")
	stopButton:Dock(TOP)
	stopButton:DockMargin(8, 0, 8, 8)
	stopButton:SetTall(24)
	stopButton:SetText("Stop")
	stopButton.DoClick = function()
		stopAllChannels()
		net.Start("nutBoomBoxPlayRequest")
			net.WriteUInt(0, 2)
			net.WriteString("")
		net.SendToServer()
	end

	local previewLabel = content:Add("DLabel")
	previewLabel:Dock(TOP)
	previewLabel:DockMargin(8, 4, 8, 4)
	previewLabel:SetTall(18)
	previewLabel:SetText("YouTube Preview (click controls to skip ads)")

	local previewHost = content:Add("DPanel")
	previewHost:Dock(TOP)
	previewHost:DockMargin(8, 0, 8, 8)
	previewHost:SetTall(180)
	previewHost.Paint = function(this, w, h)
		surface.SetDrawColor(0, 0, 0, 220)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 20)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local previewHint = previewHost:Add("DLabel")
	previewHint:Dock(FILL)
	previewHint:SetContentAlignment(5)
	previewHint:SetText("No active YouTube stream.")

	local shownPreviewPanel = nil

	local function refreshPreviewPanel()
		if (not IsValid(previewHost)) then return end

		local panel = getPreviewPanelCandidate()
		if (IsValid(panel)) then
			previewHint:SetVisible(false)
			if (shownPreviewPanel ~= panel) then
				if (IsValid(shownPreviewPanel)) then
					hideYouTubePanel(shownPreviewPanel)
				end
				shownPreviewPanel = panel
				showYouTubePanelInMenu(panel, previewHost)
			end
		else
			previewHint:SetVisible(true)
			if (IsValid(shownPreviewPanel)) then
				hideYouTubePanel(shownPreviewPanel)
				shownPreviewPanel = nil
			end
		end
	end

	refreshPreviewPanel()
	frame.Think = function()
		refreshPreviewPanel()
	end

	frame.OnRemove = function()
		if (IsValid(shownPreviewPanel)) then
			hideYouTubePanel(shownPreviewPanel)
			shownPreviewPanel = nil
		end
	end
end

function PLUGIN:InjectContextMenuButton(contextMenu)
	if (not IsValid(contextMenu)) then
		return
	end

	if (IsValid(contextMenu.nutBoomBoxButton)) then
		contextMenu.nutBoomBoxButton:Remove()
	end

	local button = vgui.Create("DButton", contextMenu)
	button:SetText("BoomBox")
	button:SetTextColor(color_white)
	button:SetFont("DermaDefaultBold")
	button:SetContentAlignment(5)
	button.DoClick = function()
		self:OpenBoomBoxMenu()
	end
	button.Paint = function(this, width, height)
		local hovered = this:IsHovered()
		surface.SetDrawColor(hovered and 72 or 52, hovered and 72 or 52, hovered and 72 or 52, 235)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(255, 255, 255, 35)
		surface.DrawOutlinedRect(0, 0, width, height)
		surface.SetMaterial(BOOMBOX_ICON)
		surface.SetDrawColor(255, 255, 255, 255)

		local iconSize = math.min(26, height - 28)
		local iconX = (width - iconSize) * 0.5
		local iconY = 8
		surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)
	end

	button.Think = function(this)
		if (not IsValid(contextMenu)) then
			this:Remove()
			return
		end

		local target = findPanelRecursive(contextMenu, isPlayerModelButton)
		if (IsValid(target)) then
			local x, y = target:LocalToScreen(0, 0)
			local cx, cy = contextMenu:ScreenToLocal(x, y)
			this:SetSize(target:GetWide(), target:GetTall())
			this:SetPos(cx, cy + target:GetTall() + 2)
		else
			this:SetSize(84, 84)
			this:SetPos(10, 112)
		end

		this:SetZPos(32767)
	end

	contextMenu.nutBoomBoxButton = button
end

function PLUGIN:OnContextMenuOpen()
	timer.Simple(0, function()
		if (IsValid(g_ContextMenu)) then
			self:InjectContextMenuButton(g_ContextMenu)
		end
	end)
end

function PLUGIN:Think()
	for key, data in pairs(activeChannels) do
		if (data.isMediaPlayer and data.media) then
			local volume = getEffectiveVolume(data.outLoud, data.source)
			if (data.outLoud and not IsValid(data.source)) then
					if (data.media.Stop) then
						data.media:Stop()
					end
					activeChannels[key] = nil
					continue
			end

			if (data.lastVolume ~= volume and data.media.Volume) then
				data.lastVolume = volume
				data.media:Volume(volume)
			end

			if ((data.nextKick or 0) <= CurTime()) then
				data.nextKick = CurTime() + 0.6
				local browser = data.media.GetBrowser and data.media:GetBrowser() or nil
				if (IsValid(browser)) then
					browser:RunJavascript(string.format("if(window.MediaPlayer){MediaPlayer.setVolume(%d);MediaPlayer.play();}", math.floor(volume * 100)))
				end
			end
		elseif (not IsValid(data.channel)) then
			activeChannels[key] = nil
		elseif (data.outLoud) then
			if (IsValid(data.source)) then
				data.channel:SetVolume(getEffectiveVolume(true, data.source))
			else
				data.channel:Stop()
				activeChannels[key] = nil
			end
		else
			data.channel:SetVolume(getListenerVolume())
		end
	end

	for key, panel in pairs(youtubePanels) do
		if (not IsValid(panel)) then
			youtubePanels[key] = nil
		else
			if ((panel.nutBoomBoxNextKick or 0) <= CurTime()) then
				panel.nutBoomBoxNextKick = CurTime() + 0.75
				kickYouTubePlayback(panel)
			end

			if (panel.nutBoomBoxOutLoud) then
				local source = panel.nutBoomBoxSource
				if (IsValid(source)) then
					local vol = math.floor(getEffectiveVolume(true, source) * 100)
					if (panel.nutBoomBoxLastVolume ~= vol) then
						panel.nutBoomBoxLastVolume = vol
						runYouTubeVolume(panel, vol)
					end
				else
					panel:Remove()
					youtubePanels[key] = nil
				end
			else
				local vol = math.floor(getEffectiveVolume(false, panel.nutBoomBoxSource) * 100)
				if (panel.nutBoomBoxLastVolume ~= vol) then
					panel.nutBoomBoxLastVolume = vol
					runYouTubeVolume(panel, vol)
				end
			end
		end
	end

	for source in pairs(activeBroadcasters) do
		if (not IsValid(source)) then
			activeBroadcasters[source] = nil
		end
	end
end

function PLUGIN:PostPlayerDraw(client)
	if (not activeBroadcasters[client] or not client:Alive()) then
		return
	end

	local localPlayer = LocalPlayer()
	if (not IsValid(localPlayer)) then
		return
	end

	if (localPlayer:GetPos():DistToSqr(client:GetPos()) > (1200 * 1200)) then
		return
	end

	local angles = EyeAngles()
	local pos = client:GetPos() + Vector(0, 0, 86)
	angles:RotateAroundAxis(angles:Forward(), 90)
	angles:RotateAroundAxis(angles:Right(), 90)

	cam.Start3D2D(pos, Angle(0, angles.y, 90), 0.08)
		surface.SetDrawColor(20, 20, 20, 220)
		surface.DrawRect(-84, -18, 168, 36)
		surface.SetDrawColor(255, 255, 255, 20)
		surface.DrawOutlinedRect(-84, -18, 168, 36)
		surface.SetMaterial(BOOMBOX_ICON)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(-72, -10, 20, 20)
		draw.SimpleText("BoomBox", "DermaDefaultBold", -42, 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end

hook.Add("ContextMenuCreated", "nutBoomBoxInject", function(contextMenu)
	timer.Simple(0, function()
		local plugin = getBoomBoxPlugin()
		if (IsValid(contextMenu) and plugin) then
			plugin:InjectContextMenuButton(contextMenu)
		end
	end)
end)

net.Receive("nutBoomBoxPlay", function()
	local source = net.ReadEntity()
	local url = net.ReadString()
	local outLoud = net.ReadBool() == true

	local plugin = getBoomBoxPlugin()
	if (not plugin) then
		return
	end

	hook.Run("BoomBoxBeforePlay", source, url, outLoud)
	plugin:PlayBoomBoxUrl(source, url, outLoud)
end)

net.Receive("nutBoomBoxStop", function()
	local source = net.ReadEntity()
	local outLoud = net.ReadBool() == true

	if (outLoud and IsValid(source)) then
		activeBroadcasters[source] = nil
		stopBroadcastChannel(source)
	else
		stopLocalOnly()
	end
end)

net.Receive("nutBoomBoxState", function()
	local source = net.ReadEntity()
	local state = net.ReadBool() == true
	if (IsValid(source)) then
		activeBroadcasters[source] = state or nil
		if (not state) then
			stopBroadcastChannel(source)
		end
	end
end)

hook.Add("ShutDown", "nutBoomBoxStopAll", function()
	stopAllChannels()
end)
