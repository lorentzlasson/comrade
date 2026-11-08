local lastFired = {}
local lastMoney
local category

local lines = {
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

local function pick(list)
  return list[math.random(#list)]
end

local function send(trigger, chatType, target)
  if not ComradeDB.enabled or not ComradeDB.triggers[trigger] then return end
  local now = GetTime()
  if lastFired[trigger] and now - lastFired[trigger] < ComradeDB.cooldown * 60 then return end
  lastFired[trigger] = now
  C_ChatInfo.SendChatMessage(pick(lines[trigger]), chatType, nil, target)
end

local function scheduleRandom()
  local low = math.min(ComradeDB.randomMin, ComradeDB.randomMax)
  local high = math.max(ComradeDB.randomMin, ComradeDB.randomMax)
  C_Timer.After(math.random(low * 60, high * 60), function()
    if not InCombatLockdown() then send("random", "EMOTE") end
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

local function registerSettings()
  local layout
  category, layout = Settings.RegisterVerticalLayoutCategory("Comrade")
  checkbox("Comrade_Enabled", ComradeDB, "enabled", "Enabled", true, "Send anything at all")
  slider("Comrade_Cooldown", "cooldown", "Cooldown", 5, 1, 60, 1, minutes, "Least time between two messages from the same trigger")

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Triggers"))
  checkbox("Comrade_LevelUp", ComradeDB.triggers, "levelUp", "Level up", true, "Emote when you level up")
  checkbox("Comrade_Trade", ComradeDB.triggers, "trade", "Trade", true, "Whisper your trade partner when a trade opens")
  checkbox("Comrade_Group", ComradeDB.triggers, "group", "Group", true, "Greet the party or raid when you join")
  checkbox("Comrade_Money", ComradeDB.triggers, "money", "Money", true, "Emote when you gain a lot of money at once")
  slider("Comrade_MoneyThreshold", "moneyThreshold", "Money threshold", 100, 5, 500, 5, coins, "How much money counts as a lot")
  checkbox("Comrade_Random", ComradeDB.triggers, "random", "Random", true, "Emote now and then, out of combat")
  slider("Comrade_RandomMin", "randomMin", "Random at least every", 15, 1, 120, 1, minutes, "Shortest wait between random emotes")
  slider("Comrade_RandomMax", "randomMax", "Random at most every", 30, 1, 120, 1, minutes, "Longest wait between random emotes")

  Settings.RegisterAddOnCategory(category)
end

local events = {
  ADDON_LOADED = function(name)
    if name ~= "Comrade" then return end
    ComradeDB = ComradeDB or {}
    ComradeDB.triggers = ComradeDB.triggers or {}
    registerSettings()
  end,
  PLAYER_LOGIN = function()
    lastMoney = GetMoney()
    scheduleRandom()
  end,
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
    C_ChatInfo.SendChatMessage(pick(lines.random), "EMOTE")
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
