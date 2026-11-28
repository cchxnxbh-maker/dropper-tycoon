--!strict
-- DevAccess: who may use the dev panel on a real server (plan section 4.10). Studio playtests always may.
-- Server-only, so exploiters cannot read the list (plan section 5.1).
--
-- State owned: none. Read-only data.
--
-- Usage:
--     if table.find(DevAccess.userIds, player.UserId) then ... end

export type DevAccess = {
	-- The account that owns the experience may use the panel. Covers Daniel without writing his user ID here.
	experienceOwner: boolean,
	-- Further Roblox user IDs allowed to use the panel, such as a tester's account.
	userIds: { number },
}

local DevAccess: DevAccess = table.freeze({
	experienceOwner = true,
	userIds = table.freeze({}),
})

return DevAccess
