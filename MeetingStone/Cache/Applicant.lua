
BuildEnv(...)

Applicant = Addon:NewClass('Applicant', Object)

local AceSerializer = LibStub('AceSerializer-3.0')

Applicant:InitAttr{
    'ID',
    'Status',
    'PendingStatus',
    'NumMembers',
    'IsNew',
    'Msg',
    'OrderID',
    'Index',
    'Name',
    'ShortName',
    'Class',
    'LocalizedClass',
    'Level',
    'ItemLevel',
    'HonorLevel',
    'IsTank',
    'IsHealer',
    'IsDamage',
    'IsAssignedRole',
    'Relationship',
    'IsMythicPlusActivity',
    'PvPRating',
    'Progression',
    'IsMeetingStone',
    'Source',
    'Result',
    'Touchy',
    'RoleID',
    'RoleName',
    'ActivityID',
	'DungeonScore',
    'BestDungeonScore',
    'FactionIndex',
    'SpecID',
}

local APPLICANT_HAD_RESULT = {
    failed = true,
    cancelled = true,
    declined = true,
    invitedeclined = true,
    timedout = true,
}

local APPLICANT_ALREADY_TOUGHT = {
    invited = true,
    inviteaccepted = true,
    invitedeclined = true,
}

function Applicant:Constructor(id, index, activityId, isMythicPlusActivity)
    -- 重读过一次就算变了: 面板靠它判断这行要不要重画
    self.revision = (self.revision or 0) + 1

    local info = C_LFGList.GetApplicantInfo(id)
    local status = info.applicationStatus
    local pendingStatus = info.pendingApplicationStatus
    local numMembers = info.numMembers
    local isNew = info.isNew
    local comment = info.comment
    local orderID = info.displayOrderID
	local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore, pvpItemLevel, factionGroup, raceID, specId = C_LFGList.GetApplicantMemberInfo(id, index)
	local userFactionIndex  = factionGroup
    local msg, isMeetingStone, progression, pvpRating, source  = DecodeDescriptionData(comment)

	local activityID = activityId
	if not activityID then
		local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
		activityID = activeEntryInfo and activeEntryInfo.activityIDs[1]
	end
	
	local bestDungeonScoreForEntry = C_LFGList.GetApplicantDungeonScoreForListing(id, index, activityID);
	local pvpRatingInfo = C_LFGList.GetApplicantPvpRatingInfoForListing(id, index, activityID);
	
	 -- local bestDungeonScoreForEntry = nil
	 -- local pvpRatingInfo = nil
	
    self:SetID(id)
    self:SetActivityID(activityId)
    self:SetStatus(status)
    self:SetPendingStatus(pendingStatus)
    self:SetNumMembers(numMembers)
    self:SetIsNew(isNew)
    self:SetMsg(msg)
    self:SetOrderID(orderID)

    self:SetIndex(index)
    self:SetName(name)
    self:SetShortName(Ambiguate(name, 'short'))
    self:SetClass(class)
    self:SetLocalizedClass(localizedClass)
    self:SetLevel(level)
    self:SetItemLevel(floor(itemLevel))
    self:SetHonorLevel(honorLevel)
    self:SetIsTank(tank)
    self:SetIsHealer(healer)
    self:SetIsDamage(damage)
    self:SetIsAssignedRole(assignedRole)
    self:SetRelationship(relationship)
    self:SetIsMythicPlusActivity(isMythicPlusActivity)
    self:SetDungeonScore(dungeonScore or 0)
    self:SetBestDungeonScore(bestDungeonScoreForEntry)
    self:SetFactionIndex(userFactionIndex)
    self:SetSpecID(specId)
    self:SetIsMeetingStone(isMeetingStone)
	if(pvpRatingInfo) then
		self:SetPvPRating(pvpRatingInfo.rating)
	end
    self:SetSource(source)
    if isMeetingStone then
        self:SetProgression(progression)
    end

    self:SetResult(pendingStatus or not APPLICANT_HAD_RESULT[status])
    self:SetTouchy(not APPLICANT_ALREADY_TOUGHT[status])
    self:SetRoleID(tank and '1' or healer and '2' or damage and '3' or assignedRole and '4')
end

-- [12.0/12.1 内存优化] 申请者对象复用：按 (id, index) 复用对象，避免每次刷新申请者列表都重建对象
Applicant._Objects = setmetatable({}, {__mode = 'v'})
function Applicant:Get(id, index, activityId, isMythicPlusActivity)
    local key = id * 1000 + index
    local obj = self._Objects[key]
    if not obj then
        obj = self:New(id, index, activityId, isMythicPlusActivity)
        self._Objects[key] = obj
    else
        obj:Constructor(id, index, activityId, isMythicPlusActivity)
    end
    return obj
end

-- 只看缓存里有没有, 不重读数据(没被改动过的行可以直接拿它)
function Applicant:Peek(id, index)
    return self._Objects[id * 1000 + index]
end

function Applicant:GetPvPText()
    local usePvPRating = IsUsePvPRating(self:GetActivityID())
    local useHonorLevel = IsUseHonorLevel(self:GetActivityID())
    if not usePvPRating and not useHonorLevel then
        return
    end

    local text = self:GetHonorLevel()
    if usePvPRating then
        text = text .. '/' .. self:GetPvPRating()
    end
    return text
end

function Applicant:IsUseHonorLevel()
    return IsUseHonorLevel(self:GetActivityID())
end
