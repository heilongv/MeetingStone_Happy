-- LfgService.lua
-- @Author : DengSir (tdaddon@163.com)
-- @Link   : https://dengsir.github.io/
-- @Date   : 2018-1-17 10:29:00

BuildEnv(...)

LfgService = Addon:NewModule('LfgService', 'AceEvent-3.0', 'AceBucket-3.0', 'AceTimer-3.0', 'AceHook-3.0')

-- 一帧最多处理多少条结果变化。攒批会把原来摊在多帧的开销挤进一帧, 所以攒完之后要摊开做,
-- 否则总工作量是降了, 单帧尖峰反而更高(实测踩过: 20秒里冒出3次>10ms)。
local UPDATES_PER_FRAME = 10

function LfgService:OnInitialize()
    self.activityHash = {}
    self.activityList = {}
    self.activityRemoved = {}
    -- 跨搜索复用的活动对象池(按 searchResultID): 搜索结果一轮一轮地来, 同一批队伍反复重建对象纯属浪费
    self.activityPool = {}
    self.activityPoolSeen = {}
    self.activityPoolGen = 0
    -- 攒下来还没处理的结果变化
    self.pendingUpdates = {}

    self:RegisterEvent('LFG_LIST_SEARCH_RESULTS_RECEIVED')
    self:RegisterEvent('LFG_LIST_SEARCH_FAILED', 'LFG_LIST_SEARCH_RESULTS_RECEIVED')
    -- 单个结果变化/申请状态变化都是逐条来的, 攒一个 bucket 再处理, 免得每条都全量刷列表
    self:RegisterBucketEvent('LFG_LIST_SEARCH_RESULT_UPDATED', 0.2, 'LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET')
    self:RegisterBucketEvent('LFG_LIST_APPLICATION_STATUS_UPDATED', 0.2, 'LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET')

    self:SecureHook(C_LFGList, 'Search', 'C_LFGList_Search')
end

function LfgService:C_LFGList_Search()
    self.inSearch = true
    self.dirty = true
end

function LfgService:GetActivity(id)
    return self.activityHash[id]
end

function LfgService:GetActivityCount()
    return #self.activityList
end

function LfgService:GetActivityList()
    return self.activityList
end

function LfgService:RemoveActivity(id)
    self.activityRemoved[id] = true

    local activity = self:GetActivity(id)
    if not activity then
        return
    end
    tDeleteItem(self.activityList, activity)
    self.activityHash[id] = nil
end

function LfgService:IsActivityRemoved(id)
    return self.activityRemoved[id]
end

function LfgService:UpdateActivity(id)
    if self:IsActivityRemoved(id) then
        return
    end

    local activity = self:GetActivity(id)
    if not activity then
        self:CacheActivity(id)
        self:SendMessage('MEETINGSTONE_ACTIVITIES_COUNT_UPDATED', #self.activityList)
    else
		--activity:Update() 
        --if activity:GetNumMembers() == 5 then
		if not activity:Update() then
            self:RemoveActivity(id)
        end
    end
end

function LfgService:IterateActivities()
    return pairs(self.activityList)
end

function LfgService:CacheActivity(id)
    if not self:_CacheActivity(id) then
        self:RemoveActivity(id)
    end
end

function LfgService:_CacheActivity(id)
    -- 复用前几轮的对象, 省掉每条队伍的建表开销; 每次 Update 会把状态刷成新的
    local activity = self.activityPool[id] or Activity:New(id)
    if not activity:Update() then
        self.activityPool[id] = nil
        self.activityPoolSeen[id] = nil
        return
    end
    self.activityPool[id] = activity
    self.activityPoolSeen[id] = self.activityPoolGen

    if self.activityId and activity:GetActivityID() ~= self.activityId then
        return
    end

    if activity:HasInvalidContent() then
        return
    end
    if not activity:IsValidCustomActivity() then
        return
    end

    tinsert(self.activityList, activity)
    self.activityHash[id] = activity

    return true
end

function LfgService:LFG_LIST_SEARCH_RESULTS_RECEIVED(event)
    table.wipe(self.activityList)
    table.wipe(self.activityHash)
    table.wipe(self.activityRemoved)
    -- 新一轮结果到了, 上一轮攒下的待更新项作废
    table.wipe(self.pendingUpdates)
    if self.drainFrame then
        self.drainFrame:Hide()
    end

    self.activityPoolGen = self.activityPoolGen + 1
    -- 连着两轮没露面的对象放掉, 对象池就维持在"最近两轮"的大小
    for id in pairs(self.activityPool) do
        local seen = self.activityPoolSeen[id]
        if not seen or seen < self.activityPoolGen - 1 then
            self.activityPool[id] = nil
            self.activityPoolSeen[id] = nil
        end
    end

    self.inSearch = false
    local applications = C_LFGList.GetApplications()

    self.activityApps = self.activityApps or {} --abyui 9.1.5 applications also in SearchResults
    table.wipe(self.activityApps)

    for _, id in ipairs(applications) do
        self.activityApps[id] = true
        self:CacheActivity(id)
    end

    local _, resultList = C_LFGList.GetSearchResults()
    for _, id in ipairs(resultList) do
        if not self.activityApps[id] then
            self:CacheActivity(id)
        end
    end

    self:SendMessage('MEETINGSTONE_ACTIVITIES_COUNT_UPDATED', self:GetActivityCount())
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_RECEIVED', event == 'LFG_LIST_SEARCH_FAILED')
end

function LfgService:LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET(results)
    -- 搜索进行中时不处理: 结果收完会整轮重建, 这时候逐条更新纯属白干
    if self.inSearch then
        return
    end

    local pending = self.pendingUpdates
    local added = false
    for id in pairs(results) do
        if not pending[id] then
            pending[id] = true
            added = true
        end
    end
    if added then
        self:StartUpdateDrain()
    end
end

function LfgService:StartUpdateDrain()
    local frame = self.drainFrame
    if not frame then
        frame = CreateFrame('Frame')
        frame:Hide()
        self.drainFrame = frame
        frame:SetScript('OnUpdate', function()
            local pending = self.pendingUpdates
            local done = 0
            for id in pairs(pending) do
                self:UpdateActivity(id)
                pending[id] = nil
                done = done + 1
                if done >= UPDATES_PER_FRAME then
                    break
                end
            end

            if next(pending) == nil then
                frame:Hide()
                -- 这一批处理完了才通知列表刷新
                self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_UPDATED')
            end
        end)
    end
    if not frame:IsShown() then
        frame:Show()
    end
end

function LfgService:LFG_LIST_SEARCH_RESULT_UPDATED(_, id)
    if self.inSearch then
        return
    end
    self:UpdateActivity(id)
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_UPDATED')
end

function LfgService:Search(categoryId, baseFilter, activityId)
    self.ourSearch = true
    self.activityId = activityId
    local filterVal = 0
    if categoryId == 2 then
        filterVal = 1
    end

    -- if activityId then
    --     local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
    --     print(activityInfo.fullName)
    --     print(activityInfo.shortName)
    --     print(activityInfo.groupFinderActivityGroupID)
    -- end

    local languages = C_LFGList.GetLanguageSearchFilter();
    C_LFGList.Search(categoryId, filterVal, baseFilter, languages)
    self.ourSearch = false
    self.dirty = false
end

function LfgService:IsDirty()
    return self.dirty
end

function LfgService:GetSearchResultMemberInfo(...)
    local info = C_LFGList.GetSearchResultPlayerInfo(...)
	if (info) then
		return info.assignedRole, info.classFilename, info.className, info.specName, info.isLeader;
	end
end    