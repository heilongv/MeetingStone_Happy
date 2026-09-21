BuildEnv(...)

ApplicantPanel = Addon:NewModule(CreateFrame('Frame', nil, ManagerPanel), 'ApplicantPanel', 'AceEvent-3.0', 'AceTimer-3.0',
    'AceBucket-3.0')

local AllMythicChallengeMaps = {691,695,699,703,705,709,713,717}

-- 自己的服务器名(跟163UI名单里的写法对齐: 去掉[CN]这类后缀)
local function MyRealmName()
    local realm = GetRealmName and GetRealmName()
    if type(realm) ~= 'string' then return nil end
    return (realm:gsub('%[.-%]', ''))
end

local function _PartySortHandler(applicant)
    local numMembers = applicant:GetNumMembers()
    if issecretvalue(numMembers) then numMembers = 1 end
    return numMembers > 1 and format('%08x', applicant:GetID()) or nil
end

local APPLICANT_LIST_HEADER = {
    {
        key = 'Icon',
        text = '@',
        style = 'ICON:20:20',
        width = 30,
        iconHandler = function(applicant)
            local rel = applicant:GetRelationship()
            if issecretvalue(rel) then rel = nil end
            if rel then
                return [[Interface\AddOns\MeetingStone\Media\Icons]], 0, 0.125, 0, 1
            end
            -- 老农粉丝图标
            if type(U1Donators) == "table" and type(U1Donators.players) == "table" then
                local playerName = applicant:GetName()
                if not issecretvalue(playerName) and playerName and playerName ~= "" then
                    local found = false
                    local donators = U1Donators.players
                    if playerName:find("-", 1, true) then
                        found = donators[playerName] ~= nil
                    else
                        -- 名字没带服务器(同服申请人): 按自己的服务器精确查
                        local realm = MyRealmName()
                        found = realm and donators[playerName .. "-" .. realm] ~= nil or false
                    end
                    if found then
                        return [[Interface\AddOns\MeetingStoneEX\Media\Laonong]], 0, 1, 0, 1
                    end
                end
            end
        end
    },
    {
        key = 'Name',
        text = L['角色名'],
        width = 95,
        style = 'LEFT',
        showHandler = function(applicant)
            local result = applicant:GetResult()
            if issecretvalue(result) then result = false end
            local class = applicant:GetClass()
            if issecretvalue(class) then class = "WARRIOR" end
            local color = result and RAID_CLASS_COLORS[class] or GRAY_FONT_COLOR
            return applicant:GetShortName(), color.r, color.g, color.b
        end
    },
    {
        key = 'Role',
        text = L['职责'],
        width = 40,
        class = Addon:GetClass('RoleItem'),
        formatHandler = function(grid, applicant)
            grid:SetMember(applicant)
        end,
        sortHandler = function(applicant)
            local roleID = applicant:GetRoleID()
            if issecretvalue(roleID) then roleID = 0 end
            return _PartySortHandler(applicant) or roleID
        end
    },
    {
        key = 'Class',
        text = L['职业'],
        width = 40,
        style = 'ICON:18:18',
        iconHandler = function(applicant)
            local flagCheckShowSpecIcon = Profile:GetShowSpecIco()
            local class = applicant:GetClass()
            if issecretvalue(class) then class = "WARRIOR" end
            local icon = "Interface/AddOns/MeetingStone/Media/ClassIcon/" .. string.lower(class) .. "_flatborder2"

            local specID = applicant:GetSpecID()
            if issecretvalue(specID) then specID = nil end

            if specID and flagCheckShowSpecIcon then
                icon = "Interface/AddOns/MeetingStone/Media/SpellIcon/circular_" .. string.lower(specID)
            end
            return icon
        end,
        sortHandler = function(applicant)
            local class = applicant:GetClass()
            if issecretvalue(class) then class = "" end
            return _PartySortHandler(applicant) or class
        end
    },
    {
        key = 'FactionGroup',
        text = L['阵营'],
        width = 40,
        style = 'ICON:18:18',		
        iconHandler = function(applicant)
            local factionIndex = applicant:GetFactionIndex()
            if issecretvalue(factionIndex) then factionIndex = 1 end
            if factionIndex == 0 then
                return "|TInterface/FriendsFrame/PlusManz-horde:18:18:0:0|t"
            else
                return "|TInterface/FriendsFrame/PlusManz-alliance:18:18:0:0|t"
            end
        end,
        sortHandler = function(applicant)
            local factionIndex = applicant:GetFactionIndex()
            if issecretvalue(factionIndex) then factionIndex = 0 end
            return _PartySortHandler(applicant) or factionIndex
        end
    },
    {
        key = 'Level',
        text = L['等级或分数'],
        width = 40 + 50 + 50,
        showHandler = function(applicant)
            local score = applicant:GetDungeonScore()
            if issecretvalue(score) then score = 0 end
            local isMythicPlus = applicant:IsMythicPlusActivity()
            if issecretvalue(isMythicPlus) then isMythicPlus = false end

            if isMythicPlus or score > 0 then
                local result = applicant:GetResult()
                if issecretvalue(result) then result = false end

                if result and score > 0 then
                    local colorAll = GetDungeonScoreRarityColor(score)
                    local scoreText
                    local info = applicant:GetBestDungeonScore()

                    local mapScore = info and info.mapScore
                    if issecretvalue(mapScore) then mapScore = 0 end
                    local finishedSuccess = info and info.finishedSuccess
                    if issecretvalue(finishedSuccess) then finishedSuccess = false end
                    local bestRunLevel = info and info.bestRunLevel
                    if issecretvalue(bestRunLevel) then bestRunLevel = 0 end

                    if info and mapScore > 0 then
                        local color = GetSpecificDungeonOverallScoreRarityColor(mapScore)
                        local levelText = format(finishedSuccess and "|cff00ff00%d层|r" or "|cff7f7f7f%d层|r", bestRunLevel or 0)
                        scoreText = format("%s / %s / %s ", colorAll:WrapTextInColorCode(score), color:WrapTextInColorCode(mapScore), color:WrapTextInColorCode(levelText))
                    else
                        scoreText = format("%s / %s", colorAll:WrapTextInColorCode(score), "|cff7f7f7f无|r")
                    end
                    return scoreText
                else
                    return NONE, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b
                end
                return
            end
          
            local pvPRating = applicant:GetPvPRating()
            if issecretvalue(pvPRating) then pvPRating = nil end
            return pvPRating or '-'
        end,
        sortHandler = function(applicant)
            local score = applicant:GetDungeonScore()
            if issecretvalue(score) then score = 0 end
            local pvPRating = applicant:GetPvPRating()
            if issecretvalue(pvPRating) then pvPRating = 0 end
            local isMythicPlus = applicant:IsMythicPlusActivity()
            if issecretvalue(isMythicPlus) then isMythicPlus = false end

            if isMythicPlus or score > 0 then
                return _PartySortHandler(applicant) or tostring(9999 - score)
            else
                return _PartySortHandler(applicant) or tostring(999 - pvPRating)
            end
        end
    },
    {
        key = 'ItemLevel',
        text = L['装等'],
        width = 52,
        showHandler = function(applicant)
            local result = applicant:GetResult()
            if issecretvalue(result) then result = false end
            local itemLevel = applicant:GetItemLevel()
            if issecretvalue(itemLevel) then itemLevel = 0 end

            if result then
                return itemLevel
            else
                return itemLevel, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b
            end
        end,
        sortHandler = function(applicant)
            local itemLevel = applicant:GetItemLevel()
            if issecretvalue(itemLevel) then itemLevel = 0 end
            return _PartySortHandler(applicant) or tostring(9999 - itemLevel)
        end
    },
    -- {
    --     key = 'PvPRating',
    --     text = L['PvP'],
    --     width = 52,
    --     showHandler = function(applicant)
    --         local activity = CreatePanel:GetCurrentActivity()
    --         if not activity then
    --             return
    --         end
    --         local pvp = applicant:GetPvPText()
    --         if not pvp then
    --             return
    --         end

    --         if applicant:GetResult() then
    --             if applicant:GetPvPRating() < activity:GetPvPRating() then
    --                 return pvp, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b
    --             else
    --                 return pvp
    --             end
    --         else
    --             return pvp, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b
    --         end
    --     end,
    --     sortHandler = function(applicant)
    --         return _PartySortHandler(applicant) or tostring(9999 - applicant:GetPvPRating())
    --     end
    -- },
    {
        key = 'Msg',
        text = L['描述'],
        width = 102+44+50-40+13,
        style = 'LEFT',
        showHandler = function(applicant)
            local result = applicant:GetResult()
            if issecretvalue(result) then result = false end
            if result then
                return applicant:GetMsg()
            else
                return applicant:GetMsg(), GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b
            end
        end,
    },
    {
        key = 'Option',
        text = L['操作'],
        width = 130,
        class = Addon:GetClass('OperationGrid'),
        formatHandler = function(grid, applicant)
            grid:SetMember(applicant, CreatePanel:GetCurrentActivity():GetActivityID())
        end
    }
}

function ApplicantPanel:OnInitialize()
    self:SetPoint('TOPRIGHT')
    self:SetPoint('BOTTOMRIGHT')
    self:SetPoint('TOPLEFT', CreatePanel, 'TOPRIGHT', 8, 0)

    local ApplicantList = GUI:GetClass('DataGridView'):New(self) do
        ApplicantList:SetAllPoints(true)
        ApplicantList:InitHeader(APPLICANT_LIST_HEADER)
        ApplicantList:SetItemHeight(32)
        ApplicantList:SetItemClass(Addon:GetClass('ApplicantItem'))
        ApplicantList:SetItemSpacing(0)
        ApplicantList:SetHeaderPoint('BOTTOMLEFT', ApplicantList, 'TOPLEFT', -2, 2)
        ApplicantList:SetSingularAdapter(true)
        ApplicantList:SetGroupHandle(function(applicant)
            return applicant:GetID()
        end)
        ApplicantList:SetCallback('OnRoleClick', function(_, _, applicant, role)
            C_LFGList.SetApplicantMemberRole(applicant:GetID(), applicant:GetIndex(), role)
        end)
        ApplicantList:SetCallback('OnInviteClick', function(_, _, applicant)
            self:Invite(applicant:GetID(), applicant:GetNumMembers())
        end)
        ApplicantList:SetCallback('OnDeclineClick', function(_, _, applicant)
            self:Decline(applicant:GetID(), applicant:GetStatus())
        end)
        ApplicantList:SetCallback('OnItemEnter', function(_, _, applicant)
            MainPanel:OpenApplicantTooltip(applicant)
        end)
        ApplicantList:SetCallback('OnItemLeave', function()
            MainPanel:CloseTooltip()
        end)
        -- 老农粉丝图标悬浮提示
        ApplicantList:SetCallback('OnGridEnter_Icon', function(_, button, applicant)
            local rel = applicant:GetRelationship()
            if issecretvalue(rel) then rel = nil end
            if rel then return end -- 好友图标有自己的tooltip逻辑
            if type(U1Donators) == "table" and type(U1Donators.players) == "table" then
                local playerName = applicant:GetName()
                if not issecretvalue(playerName) and playerName and playerName ~= "" then
                    local found = false
                    local donators = U1Donators.players
                    if playerName:find("-", 1, true) then
                        found = donators[playerName] ~= nil
                    else
                        -- 名字没带服务器(同服申请人): 按自己的服务器精确查
                        local realm = MyRealmName()
                        found = realm and donators[playerName .. "-" .. realm] ~= nil or false
                    end
                    if found then
                        GameTooltip:SetOwner(button.Icon, 'ANCHOR_RIGHT')
                        GameTooltip:SetText('老农粉丝', 1, 0.82, 0)
                        GameTooltip:Show()
                    end
                end
            end
        end)
        ApplicantList:SetCallback('OnGridLeave_Icon', GameTooltip_Hide)
        ApplicantList:SetCallback('OnItemMenu', function(_, button, applicant)
            self:ToggleEventMenu(button, applicant)
        end)
        ApplicantList:SetCallback('OnItemGrouped', function(_, button, applicant, isSingularLine, endButton, startButton)
            if not endButton then
                button:SetBackground(startButton == button)
            else
                button:SetAlpha(isSingularLine and 0.1 or 0.05, endButton)
            end
        end)
    end

    -- local AutoInvite = GUI:GetClass('CheckBox'):New(self)
    -- do
        -- AutoInvite:SetPoint('BOTTOMRIGHT', self, 'TOPLEFT', -150, 7)
        -- AutoInvite:SetText(L['自动邀请(需开语言过滤)'])
        -- AutoInvite:SetChecked(not not Profile:GetSetting('AUTO_INVITE_JOIN'))
        -- AutoInvite:SetScript('OnClick', function()
            -- Profile:SetSetting('AUTO_INVITE_JOIN', AutoInvite:GetChecked())
            -- self:UpdateAutoInvite()
        -- end)
    -- end

    self.ApplicantList = ApplicantList
    self.AutoInvite = AutoInvite

    -- 申请者列表: 逐条事件攒一个窗口再刷, 并且只重读被改动过的那个申请人
    self.applicantList = {}
    self.dirtyApplicants = {}
    self.allDirty = true

    self:RegisterBucketEvent('LFG_LIST_APPLICANT_UPDATED', 0.2, 'LFG_LIST_APPLICANT_UPDATED_BUCKET')
    self:RegisterEvent('LFG_LIST_APPLICANT_LIST_UPDATED')
    self:RegisterEvent('LFG_LIST_ACTIVE_ENTRY_UPDATE', function()
        self:MarkAllApplicantsDirty()
        self:UpdateApplicantsList()
    end)

    self:SetScript('OnShow', self.OnShow)
end

function ApplicantPanel:MarkAllApplicantsDirty()
    self.allDirty = true
    wipe(self.dirtyApplicants)
end

function ApplicantPanel:LFG_LIST_APPLICANT_UPDATED_BUCKET(ids)
    if type(ids) == 'table' then
        for id in pairs(ids) do
            self.dirtyApplicants[id] = true
        end
    else
        -- 拿不到id就整表重读, 顶多费点, 不能漏刷新
        self.allDirty = true
    end
    self:UpdateApplicantsList()
end

function ApplicantPanel:LFG_LIST_APPLICANT_LIST_UPDATED(_, hasNewPending, hasNewPendingWithData)
    self.hasNewPending = hasNewPending and hasNewPendingWithData and IsActivityManager()
    if self.hasNewPending and Profile:GetSetting("sound") then
        PlaySound(47615, "Master", false)
    end
    self:MarkAllApplicantsDirty()
    self:UpdateApplicantsList()
    self:SendMessage('MEETINGSTONE_NEW_APPLICANT_STATUS_UPDATE')
    self:UpdateAutoInvite()
end

function ApplicantPanel:OnShow()
    self:ClearNewPending()
    -- 面板关着的时候只记账不重建, 打开时补一次
    if self.rebuildOnShow then
        self:MarkAllApplicantsDirty()
        self:UpdateApplicantsList()
    end
end

function ApplicantPanel:HasNewPending()
    return self.hasNewPending
end

function ApplicantPanel:ClearNewPending()
    self.hasNewPending = false
    self:SendMessage('MEETINGSTONE_NEW_APPLICANT_STATUS_UPDATE')
end

local function _SortApplicants(applicant1, applicant2)
    local new1 = applicant1:IsNew()
    local new2 = applicant2:IsNew()
    if issecretvalue(new1) then new1 = false end
    if issecretvalue(new2) then new2 = false end

    if new1 ~= new2 then
        return new2
    end

    local order1 = applicant1:GetOrderID()
    local order2 = applicant2:GetOrderID()
    if issecretvalue(order1) then order1 = 0 end
    if issecretvalue(order2) then order2 = 0 end
    return order1 < order2
end
  
-- secret值不能比较/拼接, 签名里统一换成普通值
local function SafeValue(value, fallback)
    if value == nil or issecretvalue(value) then
        return fallback
    end
    return value
end

function ApplicantPanel:UpdateApplicantsList()
    if not self:IsVisible() then
        -- 面板没开着就只记个账, 等打开时补
        self.rebuildOnShow = true
        return
    end
    self.rebuildOnShow = nil

    local list = wipe(self.applicantList)
    local dirty = self.dirtyApplicants
    local allDirty = self.allDirty
    local activityID, isMythicPlusActivity
    local count = 0

    local applicants = C_LFGList.GetApplicants()

    if applicants and C_LFGList.HasActiveEntryInfo() then
        local info = C_LFGList.GetActiveEntryInfo()
        isMythicPlusActivity = SafeValue(info.isMythicPlusActivity, false)
        activityID = info.activityIDs[1]

        for i = 1, #applicants do
            local id = applicants[i]
            local applicantInfo = C_LFGList.GetApplicantInfo(id)
            local numMembers = SafeValue(applicantInfo.numMembers, 1)
            local reread = allDirty or dirty[id]
            for j = 1, numMembers do
                -- 没被改动过的行直接用原对象, 省掉那串C调用和描述解码
                local applicant = not reread and Applicant:Peek(id, j) or nil
                if not applicant then
                    applicant = Applicant:Get(id, j, activityID, isMythicPlusActivity)
                end
                count = count + 1
                list[count] = applicant
            end
        end

        table.sort(list, _SortApplicants)
    end

    self.allDirty = nil
    wipe(dirty)

    -- 内容没变就只换数据不重画; 组队人数/已邀请人数也算进签名, 操作列显示跟它们有关
    local signature = {
        GetNumGroupMembers(LE_PARTY_CATEGORY_HOME),
        SafeValue(C_LFGList.GetNumInvitedApplicantMembers(), 0),
    }
    for i = 1, count do
        local applicant = list[i]
        signature[#signature + 1] = format('%s/%s/%s/%s/%s/%s/%s',
            SafeValue(applicant:GetID(), 0), SafeValue(applicant:GetIndex(), 0),
            SafeValue(applicant:GetStatus(), ''), tostring(SafeValue(applicant:GetPendingStatus(), false)),
            tostring(SafeValue(applicant:IsNew(), false)), SafeValue(applicant:GetOrderID(), 0),
            applicant.revision or 0)
    end

    local newSignature = table.concat(signature, '|')
    if newSignature ~= self.listSignature then
        self.listSignature = newSignature
        self.ApplicantList:SetItemList(list)
        self.ApplicantList:Refresh()
    end
end

function ApplicantPanel:Invite(id, numMembers)
    if issecretvalue(numMembers) then numMembers = 1 end
    local numInvited = C_LFGList.GetNumInvitedApplicantMembers()
    if issecretvalue(numInvited) then numInvited = 0 end

    if not IsInRaid(LE_PARTY_CATEGORY_HOME) and
        GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) + numMembers + numInvited > MAX_PARTY_MEMBERS + 1 then
        local dialog = StaticPopup_Show('LFG_LIST_INVITING_CONVERT_TO_RAID')
        if dialog then
            dialog.data = id
        end
    else
        C_LFGList.InviteApplicant(id)
        return true
    end
end

function ApplicantPanel:Decline(id, status)
    if issecretvalue(status) then status = "" end
    if status ~= 'applied' and status ~= 'invited' then
        C_LFGList.RemoveApplicant(id)
    else
        C_LFGList.DeclineApplicant(id)
    end
end

function ApplicantPanel:ToggleEventMenu(button, applicant)
    local name = applicant:GetName()
    if issecretvalue(name) then name = "" end
    local result = applicant:GetResult()
    if issecretvalue(result) then result = false end

    GUI:ToggleMenu(button, {
        {
            text = name,
            isTitle = true,
        },
        {
            text = WHISPER,
            func = function()
                ChatFrame_SendTell(name)
            end,
            disabled = not name or not result,
        },
        {
            text = LFG_LIST_REPORT_PLAYER,
            func = function()
                local reportID = applicant:GetID()
                if issecretvalue(reportID) then reportID = 0 end
                local reportName = applicant:GetName()
                if issecretvalue(reportName) then reportName = "" end
                LFGList_ReportApplicant(reportID, reportName)
            end;
        },
        {
            text = IGNORE_PLAYER,
            func = function()
                AddIgnore(name)
                C_LFGList.DeclineApplicant(applicant:GetID())
            end,
            disabled = not name,
        },
        {
            text = '复制申请者名字',
            func = function()
                local copyName = applicant:GetName()
                if issecretvalue(copyName) then copyName = "" end
                print(copyName)
                GUI:CallUrlDialog(copyName)
            end,
        },
        {
            text = CANCEL,
        },
    }, 'cursor')
end

function ApplicantPanel:UpdateAutoInvite()
    if Profile:GetSetting('AUTO_INVITE_JOIN') and UnitIsGroupLeader('player') then
        ConsoleExec("profanityFilter 1")
        local applicants = C_LFGList.GetApplicants() or {}
        for k, v in pairs(applicants) do
            if self:CheckCanInvite(v) then
                C_LFGList.InviteApplicant(v)
            end
        end
    end
end

function ApplicantPanel:CheckCanInvite(id)
    local applicantInfo = C_LFGList.GetApplicantInfo(id)
    local status = applicantInfo.applicationStatus
    local numMembers = applicantInfo.numMembers
    if issecretvalue(numMembers) then numMembers = 1 end
    if issecretvalue(status) then status = "" end
    
    local activityInfo = GetActivityInfo(CreatePanel:GetCurrentActivity():GetActivityID());
    local numAllowed = activityInfo.maxNumPlayers;
    if issecretvalue(numAllowed) then numAllowed = 0 end
    
    if numAllowed == 0 then
        numAllowed = MAX_RAID_MEMBERS
    end

    local currentCount = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
    local numInvited = C_LFGList.GetNumInvitedApplicantMembers()
    if issecretvalue(numInvited) then numInvited = 0 end

    if numMembers + currentCount + numInvited > numAllowed then
        return
    elseif status == 'applied' then
        return true
    end
end

function ApplicantPanel:CanInvite(applicant)
    local status = applicant:GetStatus()
    if issecretvalue(status) then status = "" end
    local numMembers = applicant:GetNumMembers()
    if issecretvalue(numMembers) then numMembers = 1 end

    local activityInfo = GetActivityInfo(CreatePanel:GetCurrentActivity():GetActivityID());
    local numAllowed = activityInfo.maxNumPlayers;
    if issecretvalue(numAllowed) then numAllowed = 0 end
    
    if numAllowed == 0 then
        numAllowed = MAX_RAID_MEMBERS
    end

    local currentCount = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
    local numInvited = C_LFGList.GetNumInvitedApplicantMembers()
    if issecretvalue(numInvited) then numInvited = 0 end

    if numMembers + currentCount > numAllowed then
        return
    elseif numMembers + currentCount + numInvited > numAllowed then
        return
    elseif status == 'applied' then
        return true
    end
end

function ApplicantPanel:StartInvite()
    local list = self.ApplicantList:GetItemList()
    for i, v in ipairs(list) do
        if self:CanInvite(v) then
            local id = v:GetID()
            local numMembers = v:GetNumMembers()
            if issecretvalue(numMembers) then numMembers = 1 end
            if self:Invite(id, numMembers) then
                local name = v:GetName()
                if issecretvalue(name) then name = "?" end
                local localizedClass = v:GetLocalizedClass()
                if issecretvalue(localizedClass) then localizedClass = "?" end
                debug('invite: ' .. name .. ' ' .. localizedClass)
            end
            break
        end
    end
end

