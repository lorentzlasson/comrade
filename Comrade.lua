local lastFired = {}
local lastMoney
local pendingEmote
local category

local defaultLines = {
  levelUp = {
    "has seized more of the means of production.",
    "levels up, but insists the credit belongs to the workers.",
    "grows stronger. The proletariat grows stronger.",
  },
  trade = {
    "Property is theft, comrade. But let's trade.",
    "From each according to their ability, to each according to their needs. What are you offering?",
    "A fair exchange between workers. No middlemen, no auction house.",
  },
  group = {
    "Workers of Azeroth, unite!",
    "A collective has formed. Loot will be distributed according to need.",
    "Greetings, comrades. We have nothing to lose but our hearthstones.",
  },
  money = {
    "redistributes the wealth. Mostly into the nearest pocket.",
    "counts the coins guiltily, then counts them again.",
    "accepts the gold on behalf of the people.",
  },
  random = {
    "ponders the alienation of the herbalist from the herbs.",
    "glares at the auction house.",
    "mutters something about the labor theory of value.",
    "wonders who really owns all this land.",
    "notes that quest givers never do their own quests.",
    "hums The Internationale.",
  },
}

local function say(msg)
  print("|cffcc0000Comrade|r: " .. msg)
end

local emoteHint = "Emotes. Your name goes in front, so start each line with a verb."

local editorTabs = {
  { trigger = "levelUp", label = "Level up", hint = emoteHint },
  { trigger = "trade", label = "Trade", hint = "Whispers to your trade partner." },
  { trigger = "group", label = "Group", hint = "Sent to party or raid chat." },
  { trigger = "money", label = "Money", hint = emoteHint },
  { trigger = "random", label = "Random", hint = emoteHint },
}

local emoteChoices = {
  { token = "", label = "None" },
  { token = "APPLAUD", label = "Applaud" },
  { token = "BOW", label = "Bow" },
  { token = "CHEER", label = "Cheer" },
  { token = "DANCE", label = "Dance" },
  { token = "FLEX", label = "Flex" },
  { token = "KNEEL", label = "Kneel" },
  { token = "LAUGH", label = "Laugh" },
  { token = "POINT", label = "Point" },
  { token = "ROAR", label = "Roar" },
  { token = "RUDE", label = "Rude" },
  { token = "SALUTE", label = "Salute" },
  { token = "SHY", label = "Shy" },
  { token = "TALK", label = "Talk" },
  { token = "WAVE", label = "Wave" },
}

local function linesFor(trigger)
  return ComradeDB.lines[trigger] or defaultLines[trigger]
end

local function pick(trigger)
  local list = linesFor(trigger)
  if #list == 0 then return end
  return list[math.random(#list)]
end

local sendButton = CreateFrame("Button", "ComradeSendButton", UIParent, "SecureActionButtonTemplate")
sendButton:RegisterForClicks("AnyDown")
sendButton:SetAttribute("*type*", "macro")
sendButton:SetAttribute("useOnKeyDown", true)

local indicator = CreateFrame("Frame", nil, UIParent)
indicator:SetSize(28, 28)
indicator:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 28)
indicator:Hide()

local indicatorIcon = indicator:CreateTexture(nil, "ARTWORK")
indicatorIcon:SetAllPoints()
indicatorIcon:SetTexture("Interface\\Icons\\INV_Hammer_01")

local indicatorText = indicator:CreateFontString(nil, "OVERLAY", "GameFontNormal")
indicatorText:SetPoint("LEFT", indicatorIcon, "RIGHT", 8, 0)
indicatorText:SetWidth(ChatFrame1:GetWidth() - 36)
indicatorText:SetJustifyH("LEFT")

local function actionButtons()
  local buttons = {}
  for _, bar in ipairs({ MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7 }) do
    for _, button in ipairs(bar.actionButtons) do
      table.insert(buttons, button)
    end
  end
  return buttons
end

local function disarm()
  ClearOverrideBindings(sendButton)
end

local function armPending()
  if InCombatLockdown() then return end
  disarm()
  if not pendingEmote then return end
  for _, button in ipairs(actionButtons()) do
    local name = button:GetName()
    sendButton:SetAttribute("*macrotext-" .. name, "/e " .. pendingEmote .. "\n/click " .. name)
    for _, key in ipairs({ GetBindingKey(button.commandName) }) do
      SetOverrideBindingClick(sendButton, true, key, "ComradeSendButton", name)
    end
  end
end

local function queueEmote(line)
  pendingEmote = line
  indicatorText:SetText("Next ability sends: |cffffffff" .. line .. "|r")
  indicator:Show()
  armPending()
end

sendButton:SetScript("PostClick", function()
  pendingEmote = nil
  indicator:Hide()
  armPending()
end)

local function perform(trigger, chatType, target)
  local emote = ComradeDB.emotes[trigger]
  local line = pick(trigger)
  if emote ~= "" then C_ChatInfo.PerformEmote(emote) end
  if not line then return end
  if chatType == "EMOTE" then
    queueEmote(line)
  else
    C_ChatInfo.SendChatMessage(line, chatType, nil, target)
  end
end

local function send(trigger, chatType, target)
  if not ComradeDB.enabled or not ComradeDB.triggers[trigger] then return end
  local now = GetTime()
  if lastFired[trigger] and now - lastFired[trigger] < ComradeDB.cooldown * 60 then return end
  lastFired[trigger] = now
  perform(trigger, chatType, target)
end

local function scheduleRandom()
  local low = math.min(ComradeDB.randomMin, ComradeDB.randomMax)
  local high = math.max(ComradeDB.randomMin, ComradeDB.randomMax)
  C_Timer.After(math.random(low * 60, high * 60), function()
    if not InCombatLockdown() and not UnitIsAFK("player") then send("random", "EMOTE") end
    scheduleRandom()
  end)
end

local function minutes(value)
  return value .. " min"
end

local function coins(value)
  return C_CurrencyInfo.GetCoinTextureString(value * 100)
end

local function checkbox(variable, tbl, key, name, default, tooltip)
  local setting = Settings.RegisterAddOnSetting(category, variable, key, tbl, Settings.VarType.Boolean, name, default)
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function slider(variable, key, name, default, min, max, step, formatter, tooltip)
  local setting = Settings.RegisterAddOnSetting(category, variable, key, ComradeDB, Settings.VarType.Number, name, default)
  local options = Settings.CreateSliderOptions(min, max, step)
  options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
  Settings.CreateSlider(category, setting, options, tooltip)
end

local function createLinesEditor()
  local panel = CreateFrame("Frame")
  local selected = editorTabs[1].trigger
  local tabButtons = {}

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Comrade lines")

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  hint:SetPoint("TOPLEFT", 16, -84)

  local scroll = CreateFrame("ScrollFrame", nil, panel, "InputScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 6, -12)
  scroll:SetSize(560, 240)
  scroll.EditBox:SetWidth(542)
  scroll.EditBox:SetFontObject("ChatFontNormal")
  scroll.CharCount:Hide()

  local function show(trigger)
    selected = trigger
    for _, tab in ipairs(editorTabs) do
      tabButtons[tab.trigger]:SetEnabled(tab.trigger ~= trigger)
      if tab.trigger == trigger then hint:SetText(tab.hint .. " One message per line.") end
    end
    scroll.EditBox:SetText(table.concat(linesFor(trigger), "\n"))
  end

  for i, tab in ipairs(editorTabs) do
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetPoint("TOPLEFT", 16 + (i - 1) * 104, -48)
    button:SetText(tab.label)
    button:SetScript("OnClick", function() show(tab.trigger) end)
    tabButtons[tab.trigger] = button
  end

  scroll.EditBox:HookScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    local parsed = {}
    for line in self:GetText():gmatch("[^\n]+") do
      local trimmed = strtrim(line)
      if trimmed ~= "" then table.insert(parsed, trimmed) end
    end
    ComradeDB.lines[selected] = parsed
  end)

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(140, 22)
  reset:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", -6, -12)
  reset:SetText("Reset to default")
  reset:SetScript("OnClick", function()
    ComradeDB.lines[selected] = nil
    show(selected)
  end)

  panel:SetScript("OnShow", function() show(selected) end)
  return panel
end

local function emoteOptions()
  local container = Settings.CreateControlTextContainer()
  for _, choice in ipairs(emoteChoices) do
    container:Add(choice.token, choice.label)
  end
  return container:GetData()
end

local function emoteDropdown(variable, key, default)
  local setting = Settings.RegisterAddOnSetting(category, variable, key, ComradeDB.emotes, Settings.VarType.String, "Built-in emote", default)
  Settings.CreateDropdown(category, setting, emoteOptions, "Animated emote played together with the message")
end

local function registerSettings()
  local layout
  category, layout = Settings.RegisterVerticalLayoutCategory("Comrade")
  checkbox("Comrade_Enabled", ComradeDB, "enabled", "Enabled", true, "Send anything at all")
  slider("Comrade_Cooldown", "cooldown", "Cooldown", 5, 1, 60, 1, minutes, "Least time between two messages from the same trigger")

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Triggers"))
  checkbox("Comrade_LevelUp", ComradeDB.triggers, "levelUp", "Level up", true, "Emote when you level up")
  emoteDropdown("Comrade_LevelUpEmote", "levelUp", "FLEX")
  checkbox("Comrade_Trade", ComradeDB.triggers, "trade", "Trade", true, "Whisper your trade partner when a trade opens")
  emoteDropdown("Comrade_TradeEmote", "trade", "BOW")
  checkbox("Comrade_Group", ComradeDB.triggers, "group", "Group", true, "Greet the party or raid when you join")
  emoteDropdown("Comrade_GroupEmote", "group", "SALUTE")
  checkbox("Comrade_Money", ComradeDB.triggers, "money", "Money", true, "Emote when you gain a lot of money at once")
  emoteDropdown("Comrade_MoneyEmote", "money", "SHY")
  slider("Comrade_MoneyThreshold", "moneyThreshold", "Money threshold", 100, 5, 500, 5, coins, "How much money counts as a lot")
  checkbox("Comrade_Random", ComradeDB.triggers, "random", "Random", true, "Emote now and then, out of combat")
  emoteDropdown("Comrade_RandomEmote", "random", "")
  slider("Comrade_RandomMin", "randomMin", "Random at least every", 15, 1, 120, 1, minutes, "Shortest wait between random emotes")
  slider("Comrade_RandomMax", "randomMax", "Random at most every", 30, 1, 120, 1, minutes, "Longest wait between random emotes")

  Settings.RegisterCanvasLayoutSubcategory(category, createLinesEditor(), "Lines")
  Settings.RegisterAddOnCategory(category)
end

local events = {
  ADDON_LOADED = function(name)
    if name ~= "Comrade" then return end
    ComradeDB = ComradeDB or {}
    ComradeDB.triggers = ComradeDB.triggers or {}
    ComradeDB.lines = ComradeDB.lines or {}
    ComradeDB.emotes = ComradeDB.emotes or {}
    if not ComradeDB.version then
      if ComradeDB.emotes.random == "ROAR" then ComradeDB.emotes.random = "" end
      ComradeDB.version = 1
    end
    registerSettings()
  end,
  PLAYER_LOGIN = function()
    lastMoney = GetMoney()
    scheduleRandom()
  end,
  PLAYER_REGEN_DISABLED = disarm,
  PLAYER_REGEN_ENABLED = armPending,
  PLAYER_LEVEL_UP = function()
    send("levelUp", "EMOTE")
  end,
  TRADE_SHOW = function()
    send("trade", "WHISPER", GetUnitName("NPC", true))
  end,
  GROUP_JOINED = function()
    C_Timer.After(2, function()
      if IsInGroup(LE_PARTY_CATEGORY_HOME) then send("group", IsInRaid() and "RAID" or "PARTY") end
    end)
  end,
  PLAYER_MONEY = function()
    local money = GetMoney()
    if money - lastMoney >= ComradeDB.moneyThreshold * 100 then send("money", "EMOTE") end
    lastMoney = money
  end,
}

local listener = CreateFrame("Frame")
for event in pairs(events) do
  listener:RegisterEvent(event)
end
listener:SetScript("OnEvent", function(_, event, ...)
  events[event](...)
end)

local commands = {
  [""] = function()
    Settings.OpenToCategory(category:GetID())
  end,
  on = function()
    ComradeDB.enabled = true
    say("The revolution continues.")
  end,
  off = function()
    ComradeDB.enabled = false
    say("The revolution is on hold.")
  end,
  now = function()
    perform("random", "EMOTE")
  end,
}

SLASH_COMRADE1 = "/comrade"
SlashCmdList.COMRADE = function(input)
  local command = commands[strtrim(input):lower()]
  if command then
    command()
  else
    say((ComradeDB.enabled and "on" or "off") .. "  |  /comrade  |  /comrade on  |  /comrade off  |  /comrade now")
  end
end
