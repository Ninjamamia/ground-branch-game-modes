local AdminTools = {
	Admins = { "Bus", "NotSoLoneWolf" },
	ShowDebugGameMessages = true
}

AdminTools.__index = AdminTools

function AdminTools:NotifyKIA(KilledPlayer)
	local Players = gamemode.GetPlayerList(1, false)
	if #Players > 0 then
        for _, playerController in ipairs(Players) do
			local Name = player.GetName(playerController)
			for _, CurrAdmin in ipairs(self.Admins) do
				if Name == CurrAdmin then
					player.ShowGameMessage(
						playerController,
						player.GetName(KilledPlayer) .. " got KIA",
						'Engine', 
						5.0
					)
				end
			end
        end
    end
end

function AdminTools:ShowDebug(Message)
	print(Message)
	if not self.ShowDebugGameMessages then
		return
	end
	local Players = gamemode.GetPlayerList(1, false)
	if #Players > 0 then
        for _, playerController in ipairs(Players) do
			local Name = player.GetName(playerController)
			for _, CurrAdmin in ipairs(self.Admins) do
				if Name == CurrAdmin then
					player.ShowGameMessage(
						playerController,
						Message,
						'Engine', 
						5.0
					)
				end
			end
        end
    end
end

return AdminTools