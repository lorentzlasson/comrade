local cooldown = 300
local lastFired = {}
local lastMoney

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
  if not ComradeDB.enabled then return end
  local now = GetTime()
  if lastFired[trigger] and now - lastFired[trigger] < cooldown then return end
  lastFired[trigger] = now
  C_ChatInfo.SendChatMessage(pick(lines[trigger]), chatType, nil, target)
end

local function scheduleRandom()
  C_Timer.After(math.random(900, 1800), function()
    if not InCombatLockdown() then send("random", "EMOTE") end
    scheduleRandom()
  end)
end

local events = {
  ADDON_LOADED = function(name)
    if name ~= "Comrade" then return end
    ComradeDB = ComradeDB or { enabled = true }
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
    if money - lastMoney >= 10000 then send("money", "EMOTE") end
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
    say((ComradeDB.enabled and "on" or "off") .. "  |  /comrade on  |  /comrade off  |  /comrade now")
  end
end
