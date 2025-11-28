local behaviorsByTableType = {} :: { [string]: TableTypeBehavior }

type TableTypeBehaviorParams = {
	IsType: (task: any) -> boolean,
	OnGive: ((maid: any, task: any) -> ())?,
	OnRemove: ((maid: any, task: any) -> ())?,
	OnDestroy: (maid: any, task: any) -> (),
	Mode: "k"?,
}

export type TableTypeBehavior = {
	Name: string,
	Index: number,
	IsType: (task: any) -> boolean,
	OnGive: ((maid: any, task: any) -> ())?,
	OnRemove: ((maid: any, task: any) -> ())?,
	OnDestroy: (maid: any, task: any) -> (),
	Mode: "k"?,
}

local createTableTypeBehavior
do
	local i = 0
	function createTableTypeBehavior(name: string, params: TableTypeBehaviorParams)
		i += 1

		local tableTypeBehavior = {
			Name = name,
			Index = i,
			Mode = params.Mode,
			IsType = params.IsType,
			OnGive = params.OnGive,
			OnRemove = params.OnRemove,
			OnDestroy = params.OnDestroy,
		}

		behaviorsByTableType[name] = tableTypeBehavior
	end
end

createTableTypeBehavior("Destroy", {
	IsType = function(task)
		local suc, isExist = pcall(function()
			return task.Destroy ~= nil
		end)
		return suc and isExist
	end,
	OnDestroy = function(maid, task)
		task:Destroy()
	end,
})

createTableTypeBehavior("destroy", {
	IsType = function(task)
		local suc, isExist = pcall(function()
			return task.destroy ~= nil
		end)
		return suc and isExist
	end,
	OnDestroy = function(maid, task)
		task:destroy()
	end,
})

createTableTypeBehavior("Maid", {
	IsType = function(task)
		local suc, isMaid = pcall(function()
			return task.__type == "Bam/Packages/Maid"
		end)
		return suc and isMaid
	end,
	OnGive = function(maid, task)
		task.ParentMaids[maid] = true
	end,
	OnRemove = function(maid, task)
		task.ParentMaids[maid] = nil
	end,
	OnDestroy = function(maid, task)
		task:Destroy()
	end,
})

createTableTypeBehavior("Disconenct", {
	IsType = function(task)
		local suc, isExist = pcall(function()
			return task.Disconnect ~= nil
		end)
		return suc and isExist
	end,
	OnDestroy = function(maid, task)
		task:Disconnect()
	end,
})

createTableTypeBehavior("disconnect", {
	IsType = function(task)
		local suc, isExist = pcall(function()
			return task.disconnect ~= nil
		end)
		return suc and isExist
	end,
	OnDestroy = function(maid, task)
		task:disconnect()
	end,
})

createTableTypeBehavior("DisconnectAll", {
	IsType = function(task)
		local suc, isExist = pcall(function()
			return task.DisconnectAll ~= nil
		end)
		return suc and isExist
	end,
	OnDestroy = function(maid, task)
		task:DisconnectAll()
	end,
})

createTableTypeBehavior("disconnectAll", {
	IsType = function(task)
		local suc, isExist = pcall(function()
			return task.disconnectAll ~= nil
		end)
		return suc and isExist
	end,
	OnDestroy = function(maid, task)
		task:disconnectAll()
	end,
})

createTableTypeBehavior("Cancel", {
	IsType = function(task)
		local suc, isExist = pcall(function()
			return task.Cancel ~= nil
		end)
		return suc and isExist
	end,
	OnDestroy = function(maid, task)
		task:Cancel()
	end,
})

createTableTypeBehavior("cancel", {
	IsType = function(task)
		local suc, isExist = pcall(function()
			return task.cancel ~= nil
		end)
		return suc and isExist
	end,
	OnDestroy = function(maid, task)
		task:cancel()
	end,
})

return behaviorsByTableType
