--[=[
	@class Maid

	메이드 클래스입니다.
	
	예시 코드:
	```
	local Maid = require("../roblox_packages/Maid")
	
	local part = workspace.Part
	local maid = Maid.new()
	
	maid:GiveTask(part:GetPropertyChangedSignal("Name"):Connect(function()
		print("Part Name Changed!")
	end)
	
	local sizeChangedConnection = part:GetPropertyChangedSignal("Size"):Connect(function()
		print("Part Size Changed!")
	end)
	maid:GiveTask(function()
		sizeChangedConnection:Disconnect()
		print("SizeChangedConnection is disconnected.")
	end)
	
	part.Name = "ChangedPart" --> "Part Name Changed!"
	part.Size = Vector3.new(2,2,2) --> "Part Size Changed!"
	
	maid:DoCleaning() --> "SizeChangedConnection is disconnected."
	
	part.Name = "ChangedPartAgain" -- No prints occur because the connection to the 'Name Changed' signal was disconnected by the maid.
	
	part.Destroying:Once(function()
		print("Part is destroyed by Maid.")
	end)
	maid:GiveTask(part)
	
	maid:Destroy() --> Part is destroyed by Maid.
	
	local function someFunction()
		-- ...
	end
	maid:GiveTask(someFunction) --> Error: Attempt to give tasks to a destroyed Maid.
	```
]=]

local Signal = require("../roblox_packages/Signal")

local taskSpawn = task.spawn

local Maid = {}
Maid.__index = Maid
Maid.__type = "Bam/Packages/Maid"

-- Defines behaviors for different types of tasks that can be managed by Maid.
local behaviorsByType = {
	Instance = {
		--[[
		Mode = "k",
		OnGive = function(maid, task)
			local conn
			conn = task.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					conn:Disconnect()
					parent = task -- ref to infinity leak
				end
			end)
			
		end,
		]]
		Name = "Instance",
		OnDestroy = function(maid, task)
			task:Destroy()
		end,
	},

	RBXScriptConnection = {
		-- Mode = "k",
		Name = "RBXScriptConnection",
		OnDestroy = function(maid, task)
			task:Disconnect()
		end,
	},

	["function"] = {
		Name = "function",
		OnDestroy = function(maid, task)
			taskSpawn(task)
		end,
	},
}

local behaviorsByTableType = require("./behaviorsByTableType")

type TableTypeBehavior = behaviorsByTableType.TableTypeBehavior

local tableTypeBehaviors = {}
for i, tableTypeBehavior in behaviorsByTableType do
	tableTypeBehaviors[tableTypeBehavior.Index] = tableTypeBehavior
end

local function findTableTypeOfTask(task: any)
	for i, behavior in ipairs(tableTypeBehaviors) do
		if behavior.IsType(task) then
			return behavior
		end
	end

	return nil
end

--#region Constructors



export type Maid = setmetatable<{
	IsDestroyed: boolean,
	Destroying: Signal.Signal<>,
}, typeof(Maid)>

--[=[
	비어 있는 Maid 를 생성합니다.
]=]
function Maid.new(): Maid
	local self = setmetatable({}, Maid)

	self.IsDestroyed = false
	self.Destroying = Signal.Immediate.new()
	self.Cleaning = Signal.Immediate.new()

	local tasks = {}
	self.Tasks = tasks

	local function addTaskTypeTable(type: string, behavior)
		tasks[type] = {}

		if behavior.Mode then
			setmetatable(tasks[type], { __mode = behavior.Mode })
		end
	end

	for type, behavior in behaviorsByType do
		addTaskTypeTable(type, behavior)
	end
	for type, behavior in behaviorsByTableType do
		addTaskTypeTable(type, behavior)
	end

	self.ParentMaids = {}

	return self
end

--#endregion Constructors
--#region Methods

local function getTaskBehaviorAndtype(task: any): (any, string)
	local taskType = typeof(task)
	local taskBehavior = behaviorsByType[taskType]

	if taskBehavior then
		return taskBehavior, taskType
	end

	taskBehavior = findTableTypeOfTask(task)
	return taskBehavior, taskBehavior.Name
end

local function errorGiveOnInvalidTask(task, taskType)
	local errMsg = `Attempt to give an invalid task to the maid: ` .. `"{taskType or "table"}", "{task}".`

	error(errMsg)
end

local function cleanTaskImmediately(maid: Maid, task: any)
	local taskBehavior, taskType = getTaskBehaviorAndtype(task)
	if taskBehavior == nil and taskBehavior.Name == "table" then
		taskBehavior = findTableTypeOfTask(task)
	end

	if not taskBehavior then
		errorGiveOnInvalidTask(task, taskType)
	end

	taskBehavior.OnDestroy(maid, task)
end

--[=[
	정리 대상 작업을 Maid 에 등록합니다.
	@param ... any -- 등록할 작업(인스턴스, 연결, 함수 등)
]=]
function Maid:GiveTask(...)
	if self.IsDestroyed then
		warn("Attempt to give tasks to a destroyed Maid.")

		for _, task in ipairs({ ... }) do
			cleanTaskImmediately(self, task)
		end

		return
	end

	for _, task in ipairs({ ... }) do
		local taskType = typeof(task)
		local taskBehavior = behaviorsByType[taskType]
		if taskBehavior == nil and taskType == "table" then
			taskBehavior = findTableTypeOfTask(task)
			taskType = taskBehavior.Name
		end

		if not taskBehavior then
			errorGiveOnInvalidTask(task, taskType)
		end

		self.Tasks[taskType][task] = true
		if taskBehavior.OnGive then
			taskBehavior.OnGive(self, task)
		end
	end
end

--[=[
	Maid 에 등록된 특정 작업을 제거합니다.
	@param ... ...any -- 제거할 작업
]=]
function Maid:RemoveTask(...)
	if self.IsDestroyed then
		warn("Attempt to remove tasks from a destroyed Maid.")
		return
	end

	for _, task in ipairs({ ... }) do
		local taskType = typeof(task)
		local taskBehavior = behaviorsByType[taskType]
		if taskBehavior == nil and taskType == "table" then
			taskBehavior = findTableTypeOfTask(task)
			taskType = taskBehavior.Name
		end

		if taskBehavior then
			self.Tasks[taskType][task] = nil
			if taskBehavior.OnRemove then
				taskBehavior.OnRemove(self, task)
			end
			continue
		end

		warn(`Attempt to remove an invalid task to the maid: "{taskType or "table"}", "{task}".`)
	end
end

--[=[
	Maid 자체와 모든 등록된 작업을 정리합니다.
]=]
function Maid:Destroy()
	if self.IsDestroyed then
		return
	end

	self.Destroying:Fire()
	self.IsDestroyed = true

	self:DoCleaning(true) -- 완전히 제거되는 것임으로 부모 메이드로부터도 삭제합니다

	table.freeze(self)
	table.freeze(self.Tasks)
end

--[=[
	등록된 작업을 즉시 정리합니다.
	@param removesFromParentMaids? boolean -- true 이면 상위 Maid 의 참조도 제거합니다.
]=]
function Maid:DoCleaning(removesFromParentMaids: boolean?)
	if self.IsDestroyed then
		return
	end

	self.Cleaning:Fire()

	for taskType, tasks in self.Tasks do
		local taskBehavior = behaviorsByType[taskType] or behaviorsByTableType[taskType]
		for task in tasks do
			taskBehavior.OnDestroy(self, task)
		end
		table.clear(tasks)
	end

	if removesFromParentMaids then
		for parentMaid, _ in self.ParentMaids do
			parentMaid.Tasks.Maid[self] = nil
		end
		table.clear(self.ParentMaids)
	end
end
--#endregion Methods

return Maid
