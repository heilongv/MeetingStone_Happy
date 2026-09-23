BuildEnv(...)

Profile = Addon:NewModule('Profile', 'AceEvent-3.0')

local DEFAULT_CHATGROUP_LISTENING = {
    APP_WHISPER = {
        [1] = true,
    }
}

local DEFAULT_CHATGROUP_COLOR = {
    APP_WHISPER = {
        r = 0.7, g = 1, b = 0,
    }
}

function Profile:OnInitialize()
    local gdb = {
        global = {
            ActivityProfiles  = {
                Voice     = nil,
                VoiceSoft = nil,
            },
            annData           = {},
            serverDatas       = {},
            ignoreHash        = {},
            spamWord          = {},
            searchProfiles    = {},
            enableIgnoreTitle = true,
            globalPanelPos    = false,
            showclassico      = true,
			showspecico       = true, --LNui
			showSmRoleIco     = true, --LNui
            classIcoMsOnly    = true,
            showWindClassIco  = false,
            useWindSkin       = true,
            useNDuiSkin       = true,
            enableRaiderIO    = true,
            enableLeaderColor = true,
            filters           = {},
        },
    }

    local cdb = {
        profile = {
            settings           = {
                storage           = { point = 'TOP', x = 0, y = 0 },  --LNui
                panel             = true,
                panelLock         = false,
                sound             = true,
                ignore            = true,
                spamWord          = true,
                packedPvp         = true,
                spamLengthEnabled = true,
                spamLength        = 20,
            },
            minimap            = {
                minimapPos = 192.68,
            },
            searchHistoryList  = {},
            createHistoryList  = {},
            searchInputHistory = {},
            followMemberList   = {},
            chatGroupListening = DEFAULT_CHATGROUP_LISTENING,
            chatGroupColor     = DEFAULT_CHATGROUP_COLOR,
            recent             = {},
            combatData         = {
                dd = 0, dt = 0, hd = 0, dead = 0, time = 0,
            }
        }
    }

    self.chatGroupListeningTemp = { APP_WHISPER = {} }
    self.ignoreCache = {}

    self.gdb = LibStub('AceDB-3.0'):New('MEETINGSTONE_UI_DB', gdb, true)
    self.cdb = LibStub('AceDB-3.0'):New('MEETINGSTONE_CHARACTER_DB', cdb)

    self:NormBlockList()

    local settingVersion = self:GetLastCharacterVersion()
    if settingVersion < 70300.12 then
        self.cdb.profile.settings.onlyms = nil

        for _, v in pairs(self.cdb.profile.followMemberList) do
            if not v.status then
                if v.bitfollow then
                    v.status = FOLLOW_STATUS_FRIEND
                else
                    v.status = FOLLOW_STATUS_STARED
                end
                v.bitfollow = nil
            end
        end

        self.cdb.profile.lastSearchCode = self.cdb.profile.lastSearchValue or self.cdb.profile.lastSearchCode
        self.cdb.profile.lastSearchValue = nil
    end
    --if settingVersion < 80000.03 then
    --    wipe(self.cdb.profile.searchHistoryList)
    --end
    self.cdb.profile.version = ADDON_VERSION

    self.cdb.RegisterCallback(self, 'OnDatabaseShutdown')
end

function Profile:OnEnable()
    local settings = {
        'panel',
        'panelLock',
        'sound',
        'ignore',
        'spamWord',
        'packedPvp',
        'spamLengthEnabled',
        'spamLength',
    }

    for _, key in ipairs(settings) do
        self:SetSetting(key, self:GetSetting(key), true)
    end

    self:RefreshIgnoreCache()
    self:ImportDefaultSpamWord()
end

function Profile:GetSetting(key)
    return self.cdb.profile.settings[key]
end

function Profile:SetSetting(key, value, force)
    if force or self.cdb.profile.settings[key] ~= value then
        self.cdb.profile.settings[key] = value
        self:SendMessage('MEETINGSTONE_SETTING_CHANGED', key, value, true)
        self:SendMessage('MEETINGSTONE_SETTING_CHANGED_' .. key, value, true)
    end
end

function Profile:SaveActivityProfile(activity)
    self.gdb.global.ActivityProfiles.Voice = activity:GetVoiceChat()

    self.gdb.global.ActivityProfiles[activity:GetName()] = {
        ItemLevel  = activity:GetItemLevel(),
        Summary    = activity:GetSummary(),
        MinLevel   = activity:GetMinLevel(),
        MaxLevel   = activity:GetMaxLevel(),
        PvPRating  = activity:GetPvPRating(),
        HonorLevel = activity:GetHonorLevel(),
    }
end

function Profile:GetActivityProfile(activityType)
    return self.gdb.global.ActivityProfiles[activityType], self.gdb.global.ActivityProfiles.Voice
end

function Profile:GetGlobalDB()
    return self.gdb
end

function Profile:GetGlobalOption(key)
    return self.gdb.global[key]
end

function Profile:GetEnableIgnoreTitle()
    return self:GetGlobalOption('enableIgnoreTitle')
end

-- 屏蔽名单在 MEETINGSTONE_UI_DB.IGNORE_LIST 里, 就三条平行数组, 同下标的三个值属于同一个人:
-- n=名字, tm=屏蔽时间, kd=为什么被屏蔽。这么存比"一条一个表"省掉三分之二的存档
local BLOCK_TITLE  = 1
local BLOCK_LEADER = 2
local BLOCK_RECENT = 3
local BLOCK_LEGACY = 0   -- 更老的filters表转过来的, 只在列表里显示

-- 外面(EX的过滤器/最近玩友/屏蔽列表面板)按这几个值认条目该进哪个屏蔽map, 数字含义只在这儿定义
Profile.BLOCK_TITLE, Profile.BLOCK_LEADER = BLOCK_TITLE, BLOCK_LEADER
Profile.BLOCK_RECENT, Profile.BLOCK_LEGACY = BLOCK_RECENT, BLOCK_LEGACY

local BLOCK_DEP = {
    [BLOCK_TITLE]  = '由指定标题传染屏蔽',
    [BLOCK_LEADER] = '由指定队长名屏蔽',
    [BLOCK_RECENT] = '从最近玩友屏蔽',
    [BLOCK_LEGACY] = '旧数据结构转化',
}

local BLOCK_DEP_KIND = {}
for kind, text in pairs(BLOCK_DEP) do
    BLOCK_DEP_KIND[text] = kind
end

-- 时间记到分钟就够了, 压成'yymmddhhmm'十位, 面板上原来那串能拼回来。
-- 不存epoch是因为老存档那串是本地时间, 反推epoch得按当时那个日期的时区/DST算, 算错就整体偏一小时
local function packBlockTime(t)
    if type(t) ~= 'string' then
        return ''
    end
    local y, mo, d, h, mi = t:match('^(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d)$')
    if not y then
        return ''
    end
    return y:sub(3) .. mo .. d .. h .. mi
end

-- 世纪那两位丢掉了, 20xx够用
local function unpackBlockTime(t)
    if type(t) ~= 'string' or #t ~= 10 then
        return ''
    end
    return '20' .. t:sub(1, 2) .. '-' .. t:sub(3, 4) .. '-' .. t:sub(5, 6) .. ' ' .. t:sub(7, 8) .. ':' .. t:sub(9, 10)
end

-- 老存档里 t=2 的备注有两种(点名队长/最近玩友), 只能照文案认
local function blockKind(t, dep)
    local kind = dep and BLOCK_DEP_KIND[dep]
    if kind then
        return kind
    end
    if t == BLOCK_TITLE then
        return BLOCK_TITLE
    end
    if t == BLOCK_LEADER then
        return BLOCK_LEADER
    end
    return BLOCK_LEGACY
end

local function plainKind(kind)
    if kind == BLOCK_TITLE or kind == BLOCK_LEADER or kind == BLOCK_RECENT then
        return kind
    end
    return BLOCK_LEGACY
end

-- 老存档是数组套表(leader/time/dep/t), 更老的是 db.filters 那张map, 都在这儿归一成三条平行数组。
-- 每次开档都过一遍(已经是对的就空转), 半路降级回老版本再升上来的也能自己长回来
function Profile:NormBlockList()
    local db = MEETINGSTONE_UI_DB
    local list = db.IGNORE_LIST
    if type(list) ~= 'table' then
        list = {}
        db.IGNORE_LIST = list
    end

    self.blockMap = {}
    self.blockRevision = 0

    local names, times, kinds = list.n, list.tm, list.kd
    local len = type(names) == 'table' and #names or 0
    if len > 0 and type(times) == 'table' and #times == len and type(kinds) == 'table' and #kinds == len
        and list[1] == nil and db.filters == nil then
        for i = 1, len do
            self.blockMap[names[i]] = plainKind(kinds[i])
        end
        return
    end

    -- 三种来源按 新格式 / 数组套表 / 老filters 的顺序收, 重名只留先收进来的
    local outN, outT, outK, num = {}, {}, {}, 0
    local function take(name, t, kind)
        if type(name) ~= 'string' or name == '' or self.blockMap[name] then
            return
        end
        self.blockMap[name] = kind
        num = num + 1
        outN[num], outT[num], outK[num] = name, t, kind
    end

    if len > 0 then
        for i = 1, len do
            take(names[i], type(times) == 'table' and times[i] or '', plainKind(type(kinds) == 'table' and kinds[i] or nil))
        end
    end
    for i = 1, #list do
        local entry = list[i]
        if type(entry) == 'table' then
            take(entry.leader, packBlockTime(entry.time), blockKind(entry.t, entry.dep))
        end
    end
    if db.filters then
        for name, t in pairs(db.filters) do
            take(name, packBlockTime(t), BLOCK_LEGACY)
        end
        db.filters = nil
    end

    -- 列表是"新的在上面", 时间认不出来的排最后
    local order = {}
    for i = 1, num do
        order[i] = i
    end
    table.sort(order, function(a, b)
        if outT[a] == outT[b] then
            return outN[a] < outN[b]
        end
        return outT[a] > outT[b]
    end)

    wipe(list)
    list.n, list.tm, list.kd = {}, {}, {}
    for i = 1, num do
        local j = order[i]
        list.n[i], list.tm[i], list.kd[i] = outN[j], outT[j], outK[j]
    end
end

function Profile:GetBlockNum()
    return #MEETINGSTONE_UI_DB.IGNORE_LIST.n
end

function Profile:GetBlockLeader(index)
    return MEETINGSTONE_UI_DB.IGNORE_LIST.n[index]
end

function Profile:GetBlockTimeText(index)
    return unpackBlockTime(MEETINGSTONE_UI_DB.IGNORE_LIST.tm[index])
end

function Profile:GetBlockKind(index)
    return MEETINGSTONE_UI_DB.IGNORE_LIST.kd[index]
end

function Profile:GetBlockDep(index)
    return BLOCK_DEP[MEETINGSTONE_UI_DB.IGNORE_LIST.kd[index]] or BLOCK_DEP[BLOCK_LEGACY]
end

-- 面板靠这个认名单变没变, 没变就不用重造行(勾上的东西还能留着)
function Profile:GetBlockRevision()
    return self.blockRevision
end

-- 新条目插最前面: 列表本来就是新的在上, 这样读档时不用整表再排一遍
local function addBlock(self, name, kind)
    local list = MEETINGSTONE_UI_DB.IGNORE_LIST
    if type(name) ~= 'string' or name == '' or self.blockMap[name] then
        return false
    end
    self.blockMap[name] = kind
    tinsert(list.n, 1, name)
    tinsert(list.tm, 1, date('%y%m%d%H%M'))
    tinsert(list.kd, 1, kind)
    self.blockRevision = self.blockRevision + 1
    return true
end

function Profile:AddBlockTitle(name)
    return addBlock(self, name, BLOCK_TITLE)
end

function Profile:AddBlockLeader(name)
    return addBlock(self, name, BLOCK_LEADER)
end

function Profile:AddBlockRecent(name)
    return addBlock(self, name, BLOCK_RECENT)
end

-- 面板一次可能勾掉一大片, 三条数组扫一遍就够了; set = {名字 = true}
function Profile:DelBlocks(set)
    local list = MEETINGSTONE_UI_DB.IGNORE_LIST
    local keep, removed = 0, 0
    for i = 1, #list.n do
        local name = list.n[i]
        if set[name] then
            self.blockMap[name] = nil
            removed = removed + 1
        else
            keep = keep + 1
            list.n[keep], list.tm[keep], list.kd[keep] = name, list.tm[i], list.kd[i]
        end
    end
    for i = #list.n, keep + 1, -1 do
        list.n[i], list.tm[i], list.kd[i] = nil, nil, nil
    end
    if removed > 0 then
        self.blockRevision = self.blockRevision + 1
    end
    return removed
end

function Profile:GetGlobalPanelPos()
    return self:GetGlobalOption('globalPanelPos')
end

function Profile:GetGlobalDataBrokerStorage()
    if not self.gdb.global.dataBrokerStorage then
        self.gdb.global.dataBrokerStorage = self.cdb.profile.settings.storage
    end

    return self.gdb.global.dataBrokerStorage
end

function Profile:GetProfileDataBrokerStorage()
    return self.cdb.profile.settings.storage
end

function Profile:GetShowClassIco()
    return self:GetGlobalOption('showclassico')
end

function Profile:GetClassIcoMsOnly()
    return self:GetGlobalOption('classIcoMsOnly')
end

function Profile:GetShowSpecIco()
    return self:GetGlobalOption('showspecico')
end

function Profile:GetShowSmRoleIco()
    return self:GetGlobalOption('showSmRoleIco')
end

function Profile:GetShowWindClassIco()
    return self:GetGlobalOption('showWindClassIco')
end

function Profile:GetUseWindSkin()
    return self:GetGlobalOption('useWindSkin')
end
function Profile:GetUseNDuiSkin()
    return self:GetGlobalOption('useNDuiSkin')
end

function Profile:GetEnableRaiderIO()
    local region = GetPlayerRegion()
    return self:GetGlobalOption('enableRaiderIO') and region ~= "CN"
end

function Profile:GetEnableLeaderColor()
    return self:GetGlobalOption('enableLeaderColor')
end

function Profile:SaveGlobalOption(key, value)
    local needReload = {
        ['showclassico']     = true,
        ['classIcoMsOnly']   = true,
        ['showWindClassIco'] = true,
        ['useWindSkin']      = true,
        ['useNDuiSkin']      = true,
        ['globalPanelPos']    = true
    }

    self.gdb.global[key] = value
    if key == 'globalPanelPos' then
        if value == true then
            self.gdb.global.dataBrokerStorage = { point = 'CENTER', x = 0, y = 0 }
        else
            self.cdb.profile.settings.storage = self.gdb.global.dataBrokerStorage
        end
    end
    return needReload[key] == true
end

function Profile:GetCharacterDB()
    return self.cdb
end

function Profile:GetLastSearchCode()
    return self.cdb.profile.lastSearchCode or '6-0-0-0'
end

function Profile:SetLastSearchCode(searchValue)
    self.cdb.profile.lastSearchCode = searchValue

    self:SaveSearchHistory(searchValue)
end

function Profile:SaveVersion()
    self.gdb.global.version = ADDON_VERSION
end

function Profile:IsNewVersion()
    local pVersion = tonumber(self.gdb.global.version) or 0
    local cVersion = tonumber(ADDON_VERSION) or 0

    return pVersion < cVersion
end

function Profile:SaveSearchHistory(searchValue)
    local list = self.cdb.profile.searchHistoryList

    tDeleteItem(list, searchValue)
    tinsert(list, 1, searchValue)

    RefreshHistoryMenuTable(ACTIVITY_FILTER_BROWSE)
end

function Profile:SaveCreateHistory(searchValue)
    local list = self.cdb.profile.createHistoryList

    tDeleteItem(list, searchValue)
    tinsert(list, 1, searchValue)

    RefreshHistoryMenuTable(ACTIVITY_FILTER_CREATE)
end

function Profile:GetHistoryList(isCreator)
    if isCreator then
        return self.cdb.profile.createHistoryList
    else
        return self.cdb.profile.searchHistoryList
    end
end

function Profile:ClearHistory()
    wipe(self.cdb.profile.createHistoryList)
    wipe(self.cdb.profile.searchHistoryList)
    wipe(self.cdb.profile.searchInputHistory)

    RefreshHistoryMenuTable(ACTIVITY_FILTER_BROWSE)
    RefreshHistoryMenuTable(ACTIVITY_FILTER_CREATE)
end

function Profile:GetSearchInputHistory(searchValue)
    return self.cdb.profile.searchInputHistory[searchValue]
end

function Profile:SaveSearchInputHistory(searchValue, text)
    self.cdb.profile.searchInputHistory[searchValue] = self.cdb.profile.searchInputHistory[searchValue] or {}

    tDeleteItem(self.cdb.profile.searchInputHistory[searchValue], text)
    tinsert(self.cdb.profile.searchInputHistory[searchValue], 1, text)

    if #self.cdb.profile.searchInputHistory[searchValue] > MAX_SEARCHBOX_HISTORY_LINES then
        tremove(self.cdb.profile.searchInputHistory[searchValue])
    end

    return self.cdb.profile.searchInputHistory[searchValue]
end

function Profile:IsIgnored(name)
    return self.gdb.global.ignoreHash[Ambiguate(name, 'none')]
end

function Profile:AddIgnore(name)
    self.gdb.global.ignoreHash[Ambiguate(name, 'none')] = time()
    self:RefreshIgnoreCache()
end

function Profile:DelIgnore(name)
    self.gdb.global.ignoreHash[Ambiguate(name, 'none')] = nil
    self:RefreshIgnoreCache()
end

function Profile:GetNumIgnores()
    return #self.ignoreCache
end

function Profile:RefreshIgnoreCache()
    wipe(self.ignoreCache)

    for k, v in pairs(self.gdb.global.ignoreHash) do
        tinsert(self.ignoreCache, k)
    end

    sort(self.ignoreCache)
end

function Profile:GetIgnoreName(index)
    return self.ignoreCache[index]
end

function Profile:GetSpamWordIndex(word)
    for i, v in ipairs(self.gdb.global.spamWord) do
        if v.text == word.text and v.pain == word.pain then
            return i
        end
    end
end

local function sortSpamWord(a, b)
    return a.text < b.text
end

function Profile:SortSpamWord()
    sort(self.gdb.global.spamWord, sortSpamWord)
end

function Profile:AddSpamWord(word, delay, silence)
    if type(word) ~= 'table' then
        System:Log(L['添加失败，未输入关键字。'])
        return
    end

    if word.pain then
        word.text = word.text:lower():trim()
    end

    if self:GetSpamWordIndex(word) then
        if not silence then System:Logf(L['添加失败，关键字“%s”已存在。'], word.text) end
    else
        tinsert(self.gdb.global.spamWord, word)
        if not silence then System:Logf(L['添加成功，关键字“%s”已添加。'], word.text) end
        if not delay then
            ClearSpamWordCache()
            self:SortSpamWord()
            self:SendMessage('MEETINGSTONE_SPAMWORD_UPDATE', word)
        end
    end
end

function Profile:DelSpamWord(word)
    if type(word) ~= 'table' then
        System:Log(L['删除失败，未输入关键字。'])
        return
    end

    local index = self:GetSpamWordIndex(word, pain)
    if index then
        ClearSpamWordCache()
        tremove(self.gdb.global.spamWord, index)
        System:Logf(L['删除成功，关键字“%s”已删除。'], word.text)
        self:SendMessage('MEETINGSTONE_SPAMWORD_UPDATE')
    else
        System:Logf(L['删除失败，关键字“%s”不存在。'], word.text)
    end
end

function Profile:GetSpamWords()
    return self.gdb.global.spamWord
end

function Profile:SaveImportSpamWord(text, silence)
    if type(text) ~= 'string' then
        return
    end

    local list = { ('\n'):split(text) }

    if #list == 0 then
        return
    end

    for i, v in ipairs(list) do
        local enable, text = v:match('^([!]*)(.+)$')
        if text then
            enable = enable == '' and true or nil
            local word = { text = text, pain = enable }
            self:AddSpamWord(word, true, silence)
        end
    end

    ClearSpamWordCache()
    self:SortSpamWord()
end

function Profile:ImportDefaultSpamWord()
    if self.gdb.global.spamWord.default then
        return
    end
    self.gdb.global.spamWord.default = true
    self:SaveImportSpamWord(DEFAULT_SPAMWORD, true)
    self:SendMessage('MEETINGSTONE_SPAMWORD_UPDATE')
end

function Profile:ResetSpamWord()
    wipe(self.gdb.global.spamWord)
    self:ImportDefaultSpamWord()
    System:Log(L['关键字列表已恢复默认'])
end

function Profile:ExportSpamWord()
    local text = {}
    for i, v in ipairs(self.gdb.global.spamWord) do
        if not v.pain then
            tinsert(text, '!' .. v.text)
        else
            tinsert(text, v.text)
        end
    end

    return table.concat(text, '\n')
end

function Profile:ImportSpamWord(text)
    self:SaveImportSpamWord(text)
    self:SendMessage('MEETINGSTONE_SPAMWORD_UPDATE')
    System:Log(L['导入关键字完成'])
end

function Profile:AddSearchProfile(name, profile)
    self.gdb.global.searchProfiles[name] = profile
    self:SendMessage('MEETINGSTONE_SEARCH_PROFILE_UPDATE')
end

function Profile:DeleteSearchProfile(name)
    self.gdb.global.searchProfiles[name] = nil
    self:SendMessage('MEETINGSTONE_SEARCH_PROFILE_UPDATE')
end

function Profile:IterateSearchProfiles()
    return pairs(self.gdb.global.searchProfiles)
end

function Profile:GetSearchProfile(name)
    return self.gdb.global.searchProfiles[name]
end

function Profile:IsProfileKeyNew(key, version)
    local value = self.cdb.profile[key]
    return not value or (version and value < tostring(version))
end

function Profile:ClearProfileKeyNew(key)
    self.cdb.profile[key] = ADDON_VERSION
end

---- Follow

function Profile:AddFollow(target, guid, status)
    for i, v in ipairs(self.cdb.profile.followMemberList) do
        if v.name == target then
            v.guid = guid
            v.status = status
            self:SendMessage('MEETINGSTONE_FOLLOWMEMBERLIST_UPDATE')
            return
        end
    end

    tinsert(self.cdb.profile.followMemberList, 1, {
        name = target,
        guid = guid,
        time = time(),
        isNew = true,
        status = status
    })
    self:SendMessage('MEETINGSTONE_FOLLOWMEMBERLIST_UPDATE')
end

function Profile:IsFollowed(target)
    for i, v in ipairs(self.cdb.profile.followMemberList) do
        if v.name == target then
            return (v.status == FOLLOW_STATUS_STARED or v.status == FOLLOW_STATUS_FRIEND), i
        end
    end
end

function Profile:GetFollowGuid(target)
    for i, v in ipairs(self.cdb.profile.followMemberList) do
        if v.name == target then
            return v.guid
        end
    end
end

function Profile:GetFollowList()
    return self.cdb.profile.followMemberList
end

---- Whisper

function Profile:GetChatGroupListeningDB(id, group)
    return id > 10 and self.chatGroupListeningTemp[group] or self.cdb.profile.chatGroupListening[group]
end

function Profile:IsChatGroupListening(id, group)
    return self:GetChatGroupListeningDB(id, group)[id]
end

function Profile:ToggleChatGroupListening(id, group, checked)
    self:GetChatGroupListeningDB(id, group)[id] = not not checked
end

function Profile:SetChatGroupColor(group, r, g, b)
    self.cdb.profile.chatGroupColor[group] = { r = r, g = g, b = b }
end

function Profile:GetChatGroupColor(group)
    local color = self.cdb.profile.chatGroupColor[group]
    return color.r, color.g, color.b
end

function Profile:ResetChatWindows()
    self.chatGroupListeningTemp = {}
    self.cdb.profile.chatGroupListening = CopyTable(DEFAULT_CHATGROUP_LISTENING)
    self.cdb.profile.chatGroupColor = CopyTable(DEFAULT_CHATGROUP_COLOR)
end

function Profile:NeedWorldQuestHelp()
    return not self.cdb.profile.worldQuestHelp
end

function Profile:ClearWorldQuestHelp()
    self.cdb.profile.worldQuestHelp = true
end

function Profile:GetRecentDB(activityCode)
    if not self.cdb.profile.recent[activityCode] then
        self.cdb.profile.recent[activityCode] = {}
    end
    return self.cdb.profile.recent[activityCode]
end

function Profile:SetRecentDB(activityCode, db)
    self.cdb.profile.recent[activityCode] = db
end

function Profile:IterateRecentDB()
    return pairs(self.cdb.profile.recent)
end

function Profile:OnDatabaseShutdown()
    self:SendMessage('MEETINGSTONE_DB_SHUTDOWN')
end

function Profile:GetLastVersion()
    return tonumber(self.gdb.global.version) or 0
end

function Profile:GetLastCharacterVersion()
    return tonumber(self.cdb.profile.version) or 0
end

function Profile:SaveLastVersion()
    self.gdb.global.version = ADDON_VERSION
    self.cdb.profile.version = ADDON_VERSION
end

function Profile:GetCombatData()
    return self.cdb.profile.combatData
end

function Profile:ResetCombatData()
    self.cdb.profile.combatData = {
        dd = 0, dt = 0, hd = 0, dead = 0, time = 0,
    }
    return self.cdb.profile.combatData
end

function Profile:GetFilters(categoryId)
    return self.gdb.global.filters[categoryId] or {}
end

function Profile:SetFilters(categoryId, filters)
    self.gdb.global.filters[categoryId] = filters
    self:SendMessage('MEETINGSTONE_FILTERS_UPDATE')
end
