
CombatMenu = { }
CombatMenu.__index = CombatMenu

-- Deprecated
CombatMenu.debug = false
function CombatMenu.SetDebugEnabled(enabled)
end
function CombatMenu.IsDebugEnabled()
	return false
end
---

local menus = { }
local keys = { down = 187, up = 188, left = 189, right = 190, select = 191, back = 194 }
local optionCount = 0

local currentKey = nil
local currentMenu = nil

local toolTipWidth = 0.153

local spriteWidth = 0.027
local spriteHeight = spriteWidth * GetAspectRatio()

local titleHeight = 0.10
local titleYOffset = 0.021
local titleFont = 4
local titleScale = 0.8

local buttonHeight = 0.038
local buttonFont = 0
local buttonScale = 0.345
local buttonTextXOffset = 0.005
local buttonTextYOffset = 0.005
local buttonSpriteXOffset = 0.002
local buttonSpriteYOffset = 0.005

local runtime = CreateRuntimeTxd("CombatMenu")
local image = CreateDui("https://cdn.discordapp.com/attachments/886113666133549077/917200741591040070/dddddddddddddddddddddddd.png", 400, 90)
local dui = GetDuiHandle(image)
local texture = CreateRuntimeTextureFromDuiHandle(runtime, "banner", dui)

local defaultStyle = {
	x = 0.375,
	y = 0.125,
	width = 0.23,
	maxOptionCountOnScreen = 15,
	titleColor = { 255, 255, 255, 255 },
	titleBackgroundColor = { 0, 0, 0, 200 },
	titleBackgroundSprite = nil,
	subTitleColor = { 255, 255, 255, 255 },
	textColor = { 255, 255, 255, 255 },
	subTextColor = { 189, 189, 189, 255 },
	focusTextColor = { 0, 0, 0, 255 },
	focusColor = { 245, 245, 245, 255 },
	backgroundColor = { 0, 0, 0, 160 },
	subTitleBackgroundColor = { 0, 0, 0, 200 },
	buttonPressedSound = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }, --https://pastebin.com/0neZdsZ5
}

local function setMenuProperty(id, property, value)
	if not id then
		return
	end

	local menu = menus[id]
	if menu then
		menu[property] = value
	end
end

local function setStyleProperty(id, property, value)
	if not id then
		return
	end

	local menu = menus[id]

	if menu then
		if not menu.overrideStyle then
			menu.overrideStyle = { }
		end

		menu.overrideStyle[property] = value
	end
end

local function getStyleProperty(property, menu)
	menu = menu or currentMenu

	if menu.overrideStyle then
		local value = menu.overrideStyle[property]
		if value then
			return value
		end
	end

	return menu.style and menu.style[property] or defaultStyle[property]
end

local function copyTable(t)
	if type(t) ~= 'table' then
		return t
	end

	local result = { }
	for k, v in pairs(t) do
		result[k] = copyTable(v)
	end

	return result
end

local function setMenuVisible(id, visible, holdCurrentOption)
	if currentMenu then
		if visible then
			if currentMenu.id == id then
				return
			end
		else
			if currentMenu.id ~= id then
				return
			end
		end
	end

	if visible then
		local menu = menus[id]

		if not currentMenu then
			menu.currentOption = 1
		else
			if not holdCurrentOption then
				menus[currentMenu.id].currentOption = 1
			end
		end

		currentMenu = menu
	else
		currentMenu = nil
	end
end

local function setTextParams(font, color, scale, center, shadow, alignRight, wrapFrom, wrapTo)
	SetTextFont(font)
	SetTextColour(color[1], color[2], color[3], color[4] or 255)
	SetTextScale(scale, scale)

	if shadow then
		SetTextDropShadow()
	end

	if center then
		SetTextCentre(true)
	elseif alignRight then
		SetTextRightJustify(true)
	end

	if not wrapFrom or not wrapTo then
		wrapFrom = wrapFrom or getStyleProperty('x')
		wrapTo = wrapTo or getStyleProperty('x') + getStyleProperty('width') - buttonTextXOffset
	end

	SetTextWrap(wrapFrom, wrapTo)
end

local function getLinesCount(text, x, y)
	BeginTextCommandLineCount('TWOSTRINGS')
	AddTextComponentString(tostring(text))
	return EndTextCommandGetLineCount(x, y)
end

local function drawText(text, x, y)
	BeginTextCommandDisplayText('TWOSTRINGS')
	AddTextComponentString(tostring(text))
	EndTextCommandDisplayText(x, y)
end

local function drawRect(x, y, width, height, color)
	DrawRect(x, y, width, height, color[1], color[2], color[3], color[4] or 255)
end

local function getCurrentIndex()
	if currentMenu.currentOption <= getStyleProperty('maxOptionCountOnScreen') and optionCount <= getStyleProperty('maxOptionCountOnScreen') then
		return optionCount
	elseif optionCount > currentMenu.currentOption - getStyleProperty('maxOptionCountOnScreen') and optionCount <= currentMenu.currentOption then
		return optionCount - (currentMenu.currentOption - getStyleProperty('maxOptionCountOnScreen'))
	end

	return nil
end

local function drawTitle()
	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight / 2

	if getStyleProperty('titleBackgroundSprite') then
		DrawSprite(getStyleProperty('titleBackgroundSprite').dict, getStyleProperty('titleBackgroundSprite').name, x, y, getStyleProperty('width'), titleHeight, 0., 255, 255, 255, 255)
	else
		drawRect(x, y, getStyleProperty('width'), titleHeight, getStyleProperty('titleBackgroundColor'))
	end

	if currentMenu.title then
		setTextParams(titleFont, getStyleProperty('titleColor'), titleScale, true)
		drawText(currentMenu.title, x, y - titleHeight / 2 + titleYOffset)
	end
end

local function drawSubTitle()
	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight + buttonHeight / 2

	drawRect(x, y, getStyleProperty('width'), buttonHeight, getStyleProperty('subTitleBackgroundColor'))

	setTextParams(buttonFont, getStyleProperty('subTitleColor'), buttonScale, false)
	drawText(currentMenu.subTitle, getStyleProperty('x') + buttonTextXOffset, y - buttonHeight / 2 + buttonTextYOffset)

	if optionCount > getStyleProperty('maxOptionCountOnScreen') then
		setTextParams(buttonFont, getStyleProperty('subTitleColor'), buttonScale, false, false, true)
		drawText(tostring(currentMenu.currentOption)..' / '..tostring(optionCount), getStyleProperty('x') + getStyleProperty('width'), y - buttonHeight / 2 + buttonTextYOffset)
	end
end

local function drawButton(text, subText)
	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	local backgroundColor = nil
	local textColor = nil
	local subTextColor = nil
	local shadow = false

	if currentMenu.currentOption == optionCount then
		backgroundColor = getStyleProperty('focusColor')
		textColor = getStyleProperty('focusTextColor')
		subTextColor = getStyleProperty('focusTextColor')
	else
		backgroundColor = getStyleProperty('backgroundColor')
		textColor = getStyleProperty('textColor')
		subTextColor = getStyleProperty('subTextColor')
		shadow = true
	end

	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight + buttonHeight + (buttonHeight * currentIndex) - buttonHeight / 2

	drawRect(x, y, getStyleProperty('width'), buttonHeight, backgroundColor)

	setTextParams(buttonFont, textColor, buttonScale, false, shadow)
	drawText(text, getStyleProperty('x') + buttonTextXOffset, y - (buttonHeight / 2) + buttonTextYOffset)

	if subText then
		setTextParams(buttonFont, subTextColor, buttonScale, false, shadow, true)
		drawText(subText, getStyleProperty('x') + buttonTextXOffset, y - buttonHeight / 2 + buttonTextYOffset)
	end
end

function CombatMenu.CreateMenu(id, title, subTitle, style)
	-- Default settings
	local menu = { }

	-- Members
	menu.id = id
	menu.previousMenu = nil
	menu.currentOption = 1
	menu.title = title
	menu.subTitle = subTitle and string.upper(subTitle) or 'INTERACTION MENU'

	-- Style
	if style then
		menu.style = style
	end

	menus[id] = menu
end

function CombatMenu.CreateSubMenu(id, parent, subTitle, style)
	local parentMenu = menus[parent]
	if not parentMenu then
		return
	end

	CombatMenu.CreateMenu(id, parentMenu.title, subTitle and string.upper(subTitle) or parentMenu.subTitle)

	local menu = menus[id]

	menu.previousMenu = parent

	if parentMenu.overrideStyle then
		menu.overrideStyle = copyTable(parentMenu.overrideStyle)
	end

	if style then
		menu.style = style
	elseif parentMenu.style then
		menu.style = copyTable(parentMenu.style)
	end
end

function CombatMenu.CurrentMenu()
	return currentMenu and currentMenu.id or nil
end

function CombatMenu.OpenMenu(id)
	if id and menus[id] then
		PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		setMenuVisible(id, true)
	end
end

function CombatMenu.IsMenuOpened(id)
	return currentMenu and currentMenu.id == id
end
CombatMenu.Begin = CombatMenu.IsMenuOpened

function CombatMenu.IsAnyMenuOpened()
	return currentMenu ~= nil
end

function CombatMenu.IsMenuAboutToBeClosed()
	return false
end

function CombatMenu.CloseMenu()
	if currentMenu then
		setMenuVisible(currentMenu.id, false)
		optionCount = 0
		currentKey = nil
		PlaySoundFrontend(-1, 'QUIT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
	end
end

function CombatMenu.ToolTip(text, width, flipHorizontal)
	if not currentMenu then
		return
	end

	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	width = width or toolTipWidth

	local x = nil
	if not flipHorizontal then
		x = getStyleProperty('x') + getStyleProperty('width') + width / 2 + buttonTextXOffset
	else
		x = getStyleProperty('x') - width / 2 - buttonTextXOffset
	end

	local textX = x - (width / 2) + buttonTextXOffset
	setTextParams(buttonFont, getStyleProperty('textColor'), buttonScale, false, true, false, textX, textX + width - (buttonTextYOffset * 2))
	local linesCount = getLinesCount(text, textX, getStyleProperty('y'))

	local height = GetTextScaleHeight(buttonScale, buttonFont) * (linesCount + 1) + buttonTextYOffset
	local y = getStyleProperty('y') + titleHeight + (buttonHeight * currentIndex) + height / 2

	drawRect(x, y, width, height, getStyleProperty('backgroundColor'))

	y = y - (height / 2) + buttonTextYOffset
	drawText(text, textX, y)
end

function CombatMenu.Button(text, subText)
	if not currentMenu then
		return
	end

	optionCount = optionCount + 1

	drawButton(text, subText)

	local pressed = false

	if currentMenu.currentOption == optionCount then
		if currentKey == keys.select then
			pressed = true
			PlaySoundFrontend(-1, getStyleProperty('buttonPressedSound').name, getStyleProperty('buttonPressedSound').set, true)
		elseif currentKey == keys.left or currentKey == keys.right then
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		end
	end

	return pressed
end

function CombatMenu.SpriteButton(text, dict, name, r, g, b, a)
	if not currentMenu then
		return
	end

	local pressed = CombatMenu.Button(text)

	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	if not HasStreamedTextureDictLoaded(dict) then
		RequestStreamedTextureDict(dict)
	end
	DrawSprite(dict, name, getStyleProperty('x') + getStyleProperty('width') - spriteWidth / 2 - buttonSpriteXOffset, getStyleProperty('y') + titleHeight + buttonHeight + (buttonHeight * currentIndex) - spriteHeight / 2 + buttonSpriteYOffset, spriteWidth, spriteHeight, 0., r or 255, g or 255, b or 255, a or 255)

	return pressed
end

function CombatMenu.InputButton(text, windowTitleEntry, defaultText, maxLength, subText)
	if not currentMenu then
		return
	end

	local pressed = CombatMenu.Button(text, subText)
	local inputText = nil

	if pressed then
		DisplayOnscreenKeyboard(1, windowTitleEntry or 'FMMC_MPM_NA', '', defaultText or '', '', '', '', maxLength or 255)

		while true do
			DisableAllControlActions(0)

			local status = UpdateOnscreenKeyboard()
			if status == 2 then
				break
			elseif status == 1 then
				inputText = GetOnscreenKeyboardResult()
				break
			end

			Citizen.Wait(0)
		end
	end

	return pressed, inputText
end

function CombatMenu.MenuButton(text, id, subText)
	if not currentMenu then
		return
	end

	local pressed = CombatMenu.Button(text, subText)

	if pressed then
		currentMenu.currentOption = optionCount
		setMenuVisible(currentMenu.id, false)
		setMenuVisible(id, true, true)
	end

	return pressed
end

function CombatMenu.CheckBox(text, checked, callback)
	if not currentMenu then
		return
	end

	local name = nil
	if currentMenu.currentOption == optionCount + 1 then
		name = checked and 'shop_box_tickb' or 'shop_box_blankb'
	else
		name = checked and 'shop_box_tick' or 'shop_box_blank'
	end

	local pressed = CombatMenu.SpriteButton(text, 'commonmenu', name)

	if pressed then
		checked = not checked
		if callback then callback(checked) end
	end

	return pressed
end

function CombatMenu.ComboBox(text, items, currentIndex, selectedIndex, callback)
	if not currentMenu then
		return
	end

	local itemsCount = #items
	local selectedItem = items[currentIndex]
	local isCurrent = currentMenu.currentOption == optionCount + 1
	selectedIndex = selectedIndex or currentIndex

	if itemsCount > 1 and isCurrent then
		selectedItem = '← '..tostring(selectedItem)..' →'
	end

	local pressed = CombatMenu.Button(text, selectedItem)

	if pressed then
		selectedIndex = currentIndex
	elseif isCurrent then
		if currentKey == keys.left then
			if currentIndex > 1 then currentIndex = currentIndex - 1 else currentIndex = itemsCount end
		elseif currentKey == keys.right then
			if currentIndex < itemsCount then currentIndex = currentIndex + 1 else currentIndex = 1 end
		end
	end

	if callback then callback(currentIndex, selectedIndex) end
	return pressed, currentIndex
end

function CombatMenu.Display()
	if currentMenu then
		DisableControlAction(0, keys.left, true)
		DisableControlAction(0, keys.up, true)
		DisableControlAction(0, keys.down, true)
		DisableControlAction(0, keys.right, true)
		DisableControlAction(0, keys.back, true)

		ClearAllHelpMessages()

		drawTitle()
		drawSubTitle()

		currentKey = nil

		if IsDisabledControlJustReleased(0, keys.down) then
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

			if currentMenu.currentOption < optionCount then
				currentMenu.currentOption = currentMenu.currentOption + 1
			else
				currentMenu.currentOption = 1
			end
		elseif IsDisabledControlJustReleased(0, keys.up) then
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

			if currentMenu.currentOption > 1 then
				currentMenu.currentOption = currentMenu.currentOption - 1
			else
				currentMenu.currentOption = optionCount
			end
		elseif IsDisabledControlJustReleased(0, keys.left) then
			currentKey = keys.left
		elseif IsDisabledControlJustReleased(0, keys.right) then
			currentKey = keys.right
		elseif IsControlJustReleased(0, keys.select) then
			currentKey = keys.select
		elseif IsDisabledControlJustReleased(0, keys.back) then
			if menus[currentMenu.previousMenu] then
				setMenuVisible(currentMenu.previousMenu, true)
				PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			else
				CombatMenu.CloseMenu()
			end
		end

		optionCount = 0
	end
end
CombatMenu.End = CombatMenu.Display

function CombatMenu.CurrentOption()
	if currentMenu and optionCount ~= 0 then
		return currentMenu.currentOption
	end

	return nil
end

function CombatMenu.IsItemHovered()
	if not currentMenu or optionCount == 0 then
		return false
	end

	return currentMenu.currentOption == optionCount
end

function CombatMenu.IsItemSelected()
	return currentKey == keys.select and CombatMenu.IsItemHovered()
end

function CombatMenu.SetTitle(id, title)
	setMenuProperty(id, 'title', title)
end
CombatMenu.SetMenuTitle = CombatMenu.SetTitle

function CombatMenu.SetSubTitle(id, text)
	setMenuProperty(id, 'subTitle', string.upper(text))
end
CombatMenu.SetMenuSubTitle = CombatMenu.SetSubTitle

function CombatMenu.SetMenuStyle(id, style)
	setMenuProperty(id, 'style', style)
end

function CombatMenu.SetMenuX(id, x)
	setStyleProperty(id, 'x', x)
end

function CombatMenu.SetMenuY(id, y)
	setStyleProperty(id, 'y', y)
end

function CombatMenu.SetMenuWidth(id, width)
	setStyleProperty(id, 'width', width)
end

function CombatMenu.SetMenuMaxOptionCountOnScreen(id, count)
	setStyleProperty(id, 'maxOptionCountOnScreen', count)
end

function CombatMenu.SetTitleColor(id, r, g, b, a)
	setStyleProperty(id, 'titleColor', { r, g, b, a })
end
CombatMenu.SetMenuTitleColor = CombatMenu.SetTitleColor

function CombatMenu.SetMenuSubTitleColor(id, r, g, b, a)
	setStyleProperty(id, 'subTitleColor', { r, g, b, a })
end

function CombatMenu.SetTitleBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'titleBackgroundColor', { r, g, b, a })
end
CombatMenu.SetMenuTitleBackgroundColor = CombatMenu.SetTitleBackgroundColor

function CombatMenu.SetTitleBackgroundSprite(id, dict, name)
	RequestStreamedTextureDict(dict)
	setStyleProperty(id, 'titleBackgroundSprite', { dict = dict, name = name })
end
CombatMenu.SetMenuTitleBackgroundSprite = CombatMenu.SetTitleBackgroundSprite

function CombatMenu.SetMenuBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'backgroundColor', { r, g, b, a })
end

function CombatMenu.SetMenuTextColor(id, r, g, b, a)
	setStyleProperty(id, 'textColor', { r, g, b, a })
end

function CombatMenu.SetMenuSubTextColor(id, r, g, b, a)
	setStyleProperty(id, 'subTextColor', { r, g, b, a })
end

function CombatMenu.SetMenuFocusColor(id, r, g, b, a)
	setStyleProperty(id, 'focusColor', { r, g, b, a })
end

function CombatMenu.SetMenuFocusTextColor(id, r, g, b, a)
	setStyleProperty(id, 'focusTextColor', { r, g, b, a })
end

function CombatMenu.SetMenuButtonPressedSound(id, name, set)
	setStyleProperty(id, 'buttonPressedSound', { name = name, set = set })
end



















zazarz = { }
zazarz.__index = zazarz





zazarz.current_hour = 12
zazarz.current_minute = 1

zazarz.current_weather = 'EXTRASUNNY'



Citizen.CreateThread(function()
    local weather = GetResourceKvpString("zazarz-weather")
    local hour = GetResourceKvpString("zazarz-hour")
    local minute = GetResourceKvpString("zazarz-minute")

    if weather ~= nil then
        zazarz.current_weather = weather
    end

    if hour ~= nil then
        zazarz.current_hour = tonumber(hour)
    end

    if minute ~= nil then
        zazarz.current_minute = tonumber(minute)
    end

    while true do
        update_weather(zazarz.current_weather)
        update_time(zazarz.current_hour, zazarz.current_minute)
        Citizen.Wait(15 * 1000) 
    end
end)

RegisterNetEvent('VRZ-Core:client:update_time')
AddEventHandler('VRZ-Core:client:update_time', function(h, m)
    zazarz.current_hour, zazarz.current_minute = h, m
    zazarz.update_time(h, m)
end)

RegisterNetEvent('VRZ-Core:client:update_weather')
AddEventHandler('VRZ-Core:client:update_weather', function(weather)
    zazarz.current_weather = weather
    zazarz.update_weather(weather)
end)

function update_weather(weather)
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
end

function update_time(h, m)
    NetworkOverrideClockTime(h, m, 0)
end




local weather_index = 1
local minute_index = 1
local hour_index = 1

zazarz.hours = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23}

zazarz.minutes = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 32, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59}

zazarz.weather_types = {
    'EXTRASUNNY', 
    'CLEAR', 
    'NEUTRAL', 
    'SMOG', 
    'FOGGY', 
    'OVERCAST', 
    'CLOUDS', 
    'CLEARING', 
    'RAIN', 
    'THUNDER', 
    'SNOW', 
    'BLIZZARD', 
    'SNOWLIGHT', 
    'XMAS', 
    'HALLOWEEN',
}


local currentMenuX = 1
local selectedMenuX = 1
local currentMenuY = 4
local selectedMenuY = 4
local menuX = { 0.015, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.75 }
local menuY = { 0.015, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5 }





function GetHomies()
    local players = {}
    for i = 0, 256 do
        if NetworkIsPlayerActive(i) then
            table.insert(players, i)
        end
    end
    table.sort(players, function(a,b)
    	return GetPlayerServerId(a) < GetPlayerServerId(b)
    end)
    return players
end


function Status(id)
	local ped = GetPlayerPed(id)
	local dead = IsEntityDead(ped)
	if dead then
		return '[~r~Dead~w~]'
	else
		return '[~g~Alive~w~]'
	end
end






tronix = {}
crosshair = {}

function Tronix_Crosshair_update(info)

    if info ~= nil and tronix.type(info) == 'table' then
        SendNUIMessage({data = info})
        SetResourceKvp("zaza-crosshair", tronix.json.encode(info))
    end
end

local crosshair = {
	url = "",
	size = 100,
	activated = true
}

Citizen.CreateThread(function()
	local crosshair_data = GetResourceKvpString("zaza-crosshair")
	if crosshair_data ~= nil and tronix.type(crosshair_data) == 'string' then
		local decoded = tronix.json.decode(crosshair_data)
		if decoded ~= nil and tronix.type(decoded) == 'table' then
			crosshair.url = decoded.url
			crosshair.size = decoded.size
			crosshair.activated = decoded.activated
			Citizen.Wait(2500)
			Tronix_Crosshair_update({url = crosshair.url, size = crosshair.size, activated = crosshair.activated})
		end
	end
end)


Citizen.CreateThread(function()

	-- function CombatMenu_NS100()

	CombatMenu.CreateMenu('combat', '')

	CombatMenu.SetTitleBackgroundSprite('combat', 'CombatMenu', 'banner')
	CombatMenu.SetSubTitle('combat', '~g~Zaza Redzone ~w~| ' ..GetPlayerName(PlayerId()).. ' | ID: ' ..GetPlayerServerId())
	CombatMenu.CreateSubMenu('arenas', 'combat', 'Teleport Menu')
	CombatMenu.CreateSubMenu('gang', 'combat', 'Gang Ramps')
	CombatMenu.CreateSubMenu('mm', 'combat', '~g~Zaza Match Making')
	CombatMenu.CreateSubMenu('util', 'combat', 'AP Pistol')
	CombatMenu.CreateSubMenu('player', 'combat', 'Player List')



CombatMenu.CreateSubMenu('crosshair', 'combat', 'Crosshair Settings')
CombatMenu.CreateSubMenu('change_time', 'combat', 'Time & Weather')

	while true do
		playerhealth = GetEntityHealth(GetPlayerPed(selectedPlayer))
		playerarmor = GetPedArmour(GetPlayerPed(selectedPlayer))
		local ped = PlayerPedId()
		if CombatMenu.IsMenuOpened('combat') then
			if CombatMenu.MenuButton('Teleport Menu', 'arenas', '→') then 
			elseif CombatMenu.MenuButton('Gang Ramps', 'gang', '→') then
			elseif CombatMenu.MenuButton('Match Making', 'mm', '→') then
			elseif CombatMenu.MenuButton('AP Pistol', 'util', '→') then
			elseif CombatMenu.MenuButton('Player List', 'player', '→') then 

		    elseif CombatMenu.MenuButton('Crosshair Settings', 'crosshair', '→')then

			elseif CombatMenu.MenuButton('Time & Weather', 'change_time', '→') then
			elseif CombatMenu.Button('~r~Close Menu') then CombatMenu.CloseMenu()
            end 

			if CombatMenu.IsItemHovered() then
				CombatMenu.ToolTip("~g~[CombatMenu]\n~r~By: ~w~NS100#0001 \n~r~Discord: ~w~discord.gg/nsdev")
			end

		elseif CombatMenu.Begin('arenas') then
			if CombatMenu.IsItemHovered then
				CombatMenu.ToolTip('~g~Select A Place To Teleport To.')
			end

			if CombatMenu.Button("Test") then
				SetEntityCoords(ped, -3604.422, -3581.449, 49.37505)
			end
 
			if CombatMenu.Button('~r~Redzone') then
				SetEntityCoords(ped, 908.6929, 1559.859, 437.161)
			end

			if CombatMenu.Button('Ramps 1') then
				SetEntityCoords(ped, -640.0733, 2035.135, 498.314)
			end
			
			if CombatMenu.Button('Ramps 2') then
				SetEntityCoords(ped, -611.1508, 2068.79, 498.314)
			end

			if CombatMenu.Button('Ramps 3') then
				SetEntityCoords(ped, -611.1742, 2001.097, 498.314)
			end

			if CombatMenu.Button('Ramps 4') then
				SetEntityCoords(ped, -611.1742, 2001.097, 498.314)
			end
			
			if CombatMenu.Button('~r~Back', '←') then
				CombatMenu.OpenMenu('combat')
			end
            
		elseif CombatMenu.IsMenuOpened('gang') then
			if CombatMenu.Button('Pain Ramps') then
				SetEntityCoords(ped, -2983.0, -3670.2, 100.0)
			end
			if CombatMenu.Button('40s Ramps') then
				SetEntityCoords(ped, -2983.0, -3670.2, 100.0)
			end
			if CombatMenu.Button('Death Angels') then
				SetEntityCoords(ped, -353.3356, 488.0893, 442.9539)
			end
			if CombatMenu.Button('SlipKnot') then
				SetEntityCoords(ped, -2114.7, -3162.06, 99.93)
			end
			if CombatMenu.Button('CHS') then
				SetEntityCoords(ped, -2996.00, -2613.78, 949.88)
			end
			if CombatMenu.Button('Asura') then
				SetEntityCoords(ped, -1204.612, 536.6347, 2181.925)
			end
			if CombatMenu.Button('Mob') then
				SetEntityCoords(ped, -39.17016, -0.1560792, 668.7634)
			end
			if CombatMenu.Button('Culture') then
				SetEntityCoords(ped, -2030.121, -1070.112, 28.351)
			end
			if CombatMenu.Button('Deathwish') then
				SetEntityCoords(ped, 2440.74, -2628.769, 142.5668)
			end
			if CombatMenu.Button('Broken Hearted') then
				SetEntityCoords(ped, -1.53, -605.57, 501.42)
			end
			if CombatMenu.Button('EBK') then
				SetEntityCoords(ped, 3097.54, -871.09, 318.54)
			end
			if CombatMenu.Button('Effortless') then
				SetEntityCoords(ped, 807.5366, 2765.998, 498.7623)
			end
			if CombatMenu.Button('MHS') then
				SetEntityCoords(ped, -17.22945, 38.81991, 104.7611)
			end
			if CombatMenu.Button('Secret') then
				SetEntityCoords(ped, -885.81, 1998.87, 499.43)
			end
			if CombatMenu.Button('Sinful') then
				SetEntityCoords(ped, 1247.798, 2764.307, 803.7081)
			end

			if CombatMenu.Button('~r~Back') then
				CombatMenu.OpenMenu('combat')
			end

		elseif CombatMenu.IsMenuOpened('mm') then
			if CombatMenu.Button('~g~Queue For Match Making') then
				TriggerServerEvent("addPlayerToQueue")
				print("In Queue")
				if CombatMenu.IsItemHovered() then
					CombatMenu.ToolTip("~g~Unranked 1v1 Match Making")
				end
			end
			if CombatMenu.Button('~r~Leave The Queue') then
				TriggerServerEvent("removePlayerFromQueue")
				print("Not In Queue")
			end


	



		elseif CombatMenu.IsMenuOpened('util') then
			if CombatMenu.Button('~r~AP Pistol') then
				GiveWeaponToPed(PlayerPedId(), "WEAPON_APPISTOL", 99999, false, true)
			end

			if CombatMenu.IsItemHovered() then
				CombatMenu.ToolTip("~g~Grab An Ap Pistol!")
			end


		elseif CombatMenu.IsMenuOpened('player') then
			print("players")
			CombatMenu.SetSubTitle('player', 'Players Online - ' ..#GetActivePlayers())
			local hom = GetHomies()
			for k, v in pairs(hom) do
				local currentPlayer = v
				if CombatMenu.MenuButton(GetPlayerName(currentPlayer).." (ID - "..GetPlayerServerId(currentPlayer)..")", 'selectedPlayerOptions') then
						selectedPlayer = currentPlayer 
					end
                    
                    if CombatMenu.IsItemHovered() then
                        CombatMenu.ToolTip("Status: "..Status(currentPlayer).. "\nHealth: ~g~"..GetEntityHealth(GetPlayerPed(currentPlayer)).."~w~\nArmour: ~g~"..GetPedArmour(GetPlayerPed(currentPlayer)).."")
                    end
				end

				if CombatMenu.Button('~r~Back', '←') then    
					CombatMenu.OpenMenu('combat')
				end






			elseif CombatMenu.Begin('crosshair') then
				if CombatMenu.CheckBox('Activate Crosshair', crosshair.activated) then
					print(crosshair.activated)
					crosshair.activated = not crosshair.activated
	
					Tronix_Crosshair_update({url = crosshair.url, size = crosshair.size, activated = crosshair.activated})
	
					if crosshair.activated then
						PlaySoundFrontend(-1, 'EVENT_START_TEXT', 'GTAO_FM_EVENTS_SOUNDSET', true)
						exports['t-notify']:Alert({
							style = 'info',
							duration = 2900,
							message = '**Crosshair Enabled**',
							custom = true
						})
					else
						PlaySoundFrontend(-1, 'EVENT_START_TEXT', 'GTAO_FM_EVENTS_SOUNDSET', true)
						exports['t-notify']:Alert({
							style = 'info',
							duration = 2900,
							message = '**Crosshair Disabled.**',
							custom = true
						})
					end
				end
	
				if CombatMenu.Button('Image URL', '→') then
					local keyboard = exports["zaza-input"]:KeyboardInput({
						header = "Crosshair Image URL", 
						rows = {
							{
								id = 0, 
								txt = "Enter the url/link of the image of your crosshair"
							}
						}
					})
	
					if keyboard ~= nil then
						if keyboard[1].input ~= nil then 
							crosshair.url = keyboard[1].input
	
							Tronix_Crosshair_update({url = crosshair.url, size = crosshair.size, activated = crosshair.activated})
	
							PlaySoundFrontend(-1, 'EVENT_START_TEXT', 'GTAO_FM_EVENTS_SOUNDSET', true)
						   exports['t-notify']:Alert({
							style = 'info',
							duration = 2900,
							message = '**Crosshair Image Updated.**',
							custom = true
						})
						end
					end
				end
				if CombatMenu.IsItemHovered() then
					CombatMenu.ToolTip(crosshair.url)
				end
	
				if CombatMenu.Button('Size', crosshair.size) then
					local keyboard = exports["zaza-input"]:KeyboardInput({
						header = "Crosshair Size", 
						rows = {
							{
								id = 0, 
								txt = ""
							}
						}
					})
	
					if keyboard ~= nil then
						if tonumber(keyboard[1].input) ~= nil then 
							crosshair.size = tonumber(keyboard[1].input)
	
							PlaySoundFrontend(-1, 'EVENT_START_TEXT', 'GTAO_FM_EVENTS_SOUNDSET', true)
							exports['t-notify']:Alert({
								style = 'info',
								duration = 2900,
								message = '**Crosshair Size Updated.**',
								custom = true
							})
							Tronix_Crosshair_update({url = crosshair.url, size = crosshair.size, activated = crosshair.activated})
						end
					end
				end

				if CombatMenu.Button('~r~Back', '←') then
					CombatMenu.OpenMenu('mainMenu')
				end


			elseif CombatMenu.Begin('change_time') then
				CombatMenu.SetSubTitle('change_time', '~o~Weather')
	
				local p1, i1 = CombatMenu.ComboBox('Hour', zazarz.hours, hour_index)
				if hour_index ~= i1 then
					hour_index = i1
				end
	
				if p1 then
					SetResourceKvp("zazarz-hour", zazarz.hours[hour_index])
					TriggerEvent('DoLongHudText', 'Saved current time: hour.', 1)
	
				end
	
				local p2, i2 = CombatMenu.ComboBox('Minute', zazarz.minutes, minute_index)
				if minute_index ~= i2 then
					minute_index = i2
				end
	
				if p2 then
					SetResourceKvp("zazarz-minute", zazarz.minutes[minute_index])
					TriggerEvent('DoLongHudText', 'Saved current time: minute.', 1)
	
				end
	
				local p3, i3 = CombatMenu.ComboBox('Weather', zazarz.weather_types, weather_index)
				if weather_index ~= i3 then
					weather_index = i3
				end
	
				if p3 then
					SetResourceKvp("zazarz-weather", zazarz.weather_types[weather_index])
					TriggerEvent('DoLongHudText', 'Saved Weather.', 1)
	
				end
	
				if CombatMenu.Button('~g~Confirm') then
					SetResourceKvp("zazarz-hour", zazarz.hours[hour_index])
					SetResourceKvp("zazarz-minute", zazarz.minutes[minute_index])
					SetResourceKvp("zazarz-weather", zazarz.weather_types[weather_index])
					zazarz.current_hour = zazarz.hours[hour_index]
					zazarz.current_minute = zazarz.minutes[minute_index]
					zazarz.current_weather = zazarz.weather_types[weather_index]
					zazarz.update_weather(zazarz.weather_types[weather_index])
					zazarz.update_time(zazarz.hours[hour_index], zazarz.minutes[minute_index])
				end
	
				if CombatMenu.Button('Back', '←') then
					CombatMenu.OpenMenu('settings')
				end



				
		elseif IsControlJustReleased(0, 311) then 
			CombatMenu.OpenMenu('combat')
		end

        CombatMenu.Display()


		Citizen.Wait(1)
	end
end)


-- RegisterCommand("combatm", function()
-- 	CombatMenu_NS100()
-- end)

-- RegisterKeyMapping("combatm", "Combat Menu", 'keyboard', 'K')

-- TriggerEvent('chat:addSuggestion', '/combatm', 'Combat Menu', {})

