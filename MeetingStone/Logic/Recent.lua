--[[
Recent.lua
@Author  : DengSir (tdaddon@163.com)
@Link    : https://dengsir.github.io
]]

BuildEnv(...)

Recent = Addon:NewModule('Recent', 'AceTimer-3.0', 'AceBucket-3.0', 'AceEvent-3.0')
-- 'NetEaseSocket-2.0'

function Recent:OnInitialize()
    self.managers = {}
    -- 刚邀请过的人: 名字 -> {itemLevel, time}
    self.invitedItemLevels = {}
    -- 等着观察(inspect)补装等的队友
    self.inspectQueue = {}
    self.inspectQueued = {}

    self.groupManagers = setmetatable({}, {
        __index = function(t, k)
            t[k] = {}
            return t[k]
        end
    })

    -- 禁用网易插件服务
    self:InitRecentManagers()

    self:RegisterBucketEvent('GROUP_ROSTER_UPDATE', 1)
    self:RegisterEvent('LFG_LIST_ACTIVE_ENTRY_UPDATE')
    self:RegisterEvent('LFG_LIST_APPLICANT_UPDATED', 'RememberInvitedItemLevel')
    self:RegisterEvent('INSPECT_READY')

    self:RegisterMessage('MEETINGSTONE_DB_SHUTDOWN')
    self:RegisterMessage('MEETINGSTONE_GROUP_CLOSED')
    self:RegisterBucketMessage('MEETINGSTONE_MEMBER_UPDATE', 2, 'CacheRecent')
    self:RegisterBucketMessage('MEETINGSTONE_MEMBER_UPDATE', 10, 'BroadcastInfo')

    -- self:ListenSocket('NE_RECENT')
    -- self:RegisterSocket('RECENT_INFO')
end

function Recent:OnEnable()
    self:LFG_LIST_ACTIVE_ENTRY_UPDATE()
    self:GROUP_ROSTER_UPDATE()
end

function Recent:InitRecentManagers()
    for activityCode in Profile:IterateRecentDB() do
        self:NewRecentManager(activityCode)
    end
end

function Recent:NewRecentManager(activityCode)
    local manager                                          = RecentManager:New(activityCode)

    self.managers[activityCode]                            = manager
    self.groupManagers[manager:GetCategoryCode()][manager] = true
    self.groupManagers[manager:GetGroupCode()][manager]    = true
    self.groupManagers[manager:GetActivityCode()][manager] = true

    return manager
end

function Recent:GetRecentManager(activityCode)
    return self.managers[activityCode] or self:NewRecentManager(activityCode)
end

function Recent:BroadcastInfo()
    if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return
    end
    if not self:GetCurrentActivity() then
        return
    end

    -- self:SendSocket('@GROUP', 'RECENT_INFO',
    --     GetPlayerBattleTag(),
    --     GetPlayerItemLevel()
    -- )
end

function Recent:MEETINGSTONE_DB_SHUTDOWN()
    for activityCode, manager in pairs(self.managers) do
        Profile:SetRecentDB(activityCode, manager:ToDB())
    end
end

function Recent:RECENT_INFO(_, name, battleTag, itemLevel)
    local activity = self:GetCurrentActivity()
    if not activity then
        return
    end

    local player = self:GetRecentManager(activity:GetCode()):GetUnit(GetFullName(name))
    if not player then
        return
    end

    player:SetBattleTag(battleTag)
    player:SetItemLevel(itemLevel)
end

function Recent:GetCurrentActivity()
    return self.activity
end

-- 观察(inspect)补装等: 只给"记录里还没有装等"的人排一次, 一次一个慢慢来。
-- 这个数只是个记录, 没人盯着看, 所以间隔给得宽, 也不回头重复观察同一个人
local INSPECT_INTERVAL = 1    -- 两次观察之间隔多久
local INSPECT_CHECK = 0.3     -- 发出观察后隔多久看一次结果
local INSPECT_CHECKS = 5      -- 看几眼还没结果就算这一轮失败
local INSPECT_ATTEMPTS = 3    -- 一个人最多来几轮(观察槽只有一个, 被别的插件抢了就得重来)

-- 排队时存名字, 轮到他再找单位: 中间队伍可能已经变了
local function FindUnitByName(name)
    for _, unit in IterateGroupUnits() do
        local unitName = UnitFullName(unit)
        if not issecretvalue(unitName) and unitName == name then
            return unit
        end
    end
end

function Recent:QueueInspect(name, player)
    if not name then
        return
    end
    if not self.inspectQueued[name] then
        self.inspectQueued[name] = true
        tinsert(self.inspectQueue, { name = name, player = player })
    end

    -- 队列里可能还压着上一场没做完的, 顺手把泵打开
    if not self.inspecting and not self.inspectTimer then
        self:NextInspect()
    end
end

function Recent:NextInspect()
    if self.inspecting or self.inspectTimer then
        return
    end

    local entry
    while true do
        entry = tremove(self.inspectQueue, 1)
        if not entry then
            return
        end
        entry.unit = FindUnitByName(entry.name)
        if entry.unit then
            break
        end
        -- 人已经不在队里了, 看下一个
    end

    self.inspecting = entry
    entry.attempt = (entry.attempt or 0) + 1
    entry.checks = 0
    -- 先清掉上一个人的观察数据, 不清的话读到的可能还是他
    ClearInspectPlayer()
    NotifyInspect(entry.unit)
    self:CheckInspect()
end

-- 结果不是INSPECT_READY一响就齐的: 装等常常要晚一点才有, 所以隔一会儿再看几眼
function Recent:CheckInspect()
    local entry = self.inspecting
    if not entry then
        return
    end
    if entry.checkTimer then
        self:CancelTimer(entry.checkTimer)
        entry.checkTimer = nil
    end

    -- 事件回传的guid在12.x可能是secret值(不能比较), 所以不用它;
    -- 拿到的是不是这个单位的数据, 由unit自己兜着: 不是他只会返回0
    local itemLevel = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel and C_PaperDollInfo.GetInspectItemLevel(entry.unit)
    if issecretvalue(itemLevel) then
        itemLevel = nil
    end

    if type(itemLevel) == 'number' and itemLevel > 0 then
        self:FinishInspect(floor(itemLevel))
    elseif entry.checks < INSPECT_CHECKS then
        entry.checks = entry.checks + 1
        entry.checkTimer = self:ScheduleTimer('CheckInspect', INSPECT_CHECK)
    else
        self:FinishInspect()
    end
end

function Recent:INSPECT_READY()
    self:CheckInspect()
end

-- 出结果了或者看够次数了都走这儿
function Recent:FinishInspect(itemLevel)
    local entry = self.inspecting
    if not entry then
        return
    end

    self.inspecting = nil
    if entry.checkTimer then
        self:CancelTimer(entry.checkTimer)
        entry.checkTimer = nil
    end

    if itemLevel then
        if not entry.player:GetItemLevel() then
            entry.player:SetItemLevel(itemLevel)
        end
    elseif entry.attempt < INSPECT_ATTEMPTS then
        -- 可能被别的插件抢了观察槽、或者那一轮就是没回来: 放队尾再排一轮, 让别人先来
        tinsert(self.inspectQueue, entry)
    end

    -- 隔开点, 别挤着暴雪的观察
    self.inspectTimer = self:ScheduleTimer('OnInspectWait', INSPECT_INTERVAL)
end

function Recent:OnInspectWait()
    self.inspectTimer = nil
    self:NextInspect()
end

-- 最近玩友的装等只有一个来源了: 邀请的那一刻从申请列表抄一份记着。
-- 申请人从"被邀请"到"进组"要等对方点接受, 那会儿申请人记录早没了, 所以先存着。
-- 名字统一用 GetFullName 的"名字-服务器"写法, 跟 UnitFullName(单位) 对得上
local INVITED_KEEP = 1800

function Recent:RememberItemLevel(name, itemLevel)
    local key = GetFullName(name)
    if not key then
        return
    end

    local invited = self.invitedItemLevels
    invited[key] = { itemLevel = itemLevel, time = time() }

    -- 这表只为了"邀请到进组"这一小段, 攒多了顺手清清过期的
    local num = 0
    for _ in pairs(invited) do
        num = num + 1
    end
    if num > 50 then
        local now = time()
        for k, v in pairs(invited) do
            if now - v.time > INVITED_KEEP then
                invited[k] = nil
            end
        end
    end
end

function Recent:GetInvitedItemLevel(name)
    local entry = self.invitedItemLevels[GetFullName(name)]
    if entry and time() - entry.time <= INVITED_KEEP then
        return entry.itemLevel
    end
end

-- 申请人状态是'invited'就算数; 'inviteaccepted'也收, 因为对方秒接受时同一个事件里
-- 我们只会读到后一个状态, 漏掉'invited'那一步
function Recent:RememberInvitedItemLevel(_, applicantID)
    local info = C_LFGList.GetApplicantInfo(applicantID)
    if not info then
        return
    end

    local status = info.applicationStatus
    if issecretvalue(status) or (status ~= 'invited' and status ~= 'inviteaccepted') then
        return
    end

    local numMembers = info.numMembers
    if issecretvalue(numMembers) or type(numMembers) ~= 'number' then
        numMembers = 1
    end

    for i = 1, numMembers do
        local name, _, _, _, itemLevel = C_LFGList.GetApplicantMemberInfo(applicantID, i)
        if name and not issecretvalue(name) and not issecretvalue(itemLevel)
            and type(itemLevel) == 'number' and itemLevel > 0 then
            self:RememberItemLevel(name, floor(itemLevel))
        end
    end
end

function Recent:LFG_LIST_ACTIVE_ENTRY_UPDATE()
    if C_LFGList.HasActiveEntryInfo() then
        local activity = CreatePanel:GetCurrentActivity()
        if not activity:IsSoloActivity() then
            self.activity = CreatePanel:GetCurrentActivity()
        end
    else
        self:ScheduleTimer(function()
            self.activity = nil
        end, 300)
    end
end

function Recent:GROUP_ROSTER_UPDATE()
    if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return self:SendMessage('MEETINGSTONE_GROUP_CLOSED')
    end
    self:SendMessage('MEETINGSTONE_MEMBER_UPDATE')
end

function Recent:MEETINGSTONE_GROUP_CLOSED()
    self:CancelAllTimers()
    self.activity = nil
    -- 观察先停; 正在观察的那条塞回队头(队可能重组), 其余留着:
    -- 轮到时人不在队里会被跳过, 不会乱观察
    if self.inspecting then
        tinsert(self.inspectQueue, 1, self.inspecting)
        self.inspecting = nil
    end
    self.inspectTimer = nil
end

function Recent:CacheRecent()
    local activity = self:GetCurrentActivity()
    if not activity then
        return
    end

    local manager = self:GetRecentManager(activity:GetCode())

    for _, unit in IterateGroupUnits() do
        local _ue = UnitExists(unit)
        local _un = UnitName(unit)
        local _unn = UnitName('none')
        local _uiu = UnitIsUnit(unit, 'player')
        if issecretvalue(unit) or issecretvalue(_ue) or issecretvalue(_un) or issecretvalue(_unn) or issecretvalue(_uiu) then
            return
        end    
        if _ue and _un ~= _unn and not _uiu then
            local name = UnitFullName(unit)
            local player = manager:GetUnit(name) or RecentPlayer:New(manager)

            player:SetName(name)
            player:SetClass(select(3, UnitClass(unit)))
            player:SetRole(UnitGroupRolesAssigned(unit))
            player:SetIsLeader(UnitIsGroupLeader(unit, LE_PARTY_CATEGORY_HOME) or nil)
            player:SetTime(time())

            -- 邀请时抄下来的装等, 有就填上; 没有就不动(别把老记录里已有的值抹了)
            local itemLevel = self:GetInvitedItemLevel(name)
            if itemLevel then
                player:SetItemLevel(itemLevel)
            end

            -- 申请列表没给过装等的(好友/公会/手动拉进来的), 排个观察慢慢补
            if not player:GetItemLevel() then
                self:QueueInspect(name, player)
            end

            manager:AddUnit(player)
        end
    end
end

function Recent:GetRecentList(code)
    local list = {}
    for manager in pairs(self.groupManagers[code]) do
        for _, player in manager:IteratePlayers() do
            tinsert(list, player)
        end
    end
    return list
end
