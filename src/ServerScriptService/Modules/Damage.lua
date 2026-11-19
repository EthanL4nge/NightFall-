local Damage = {}

-- Fortnite-style: shield soaks damage first, then health.
function Damage.player(player, amount)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local shield = player:GetAttribute("Shield") or 0
	local absorbed = math.min(shield, amount)
	if absorbed > 0 then
		player:SetAttribute("Shield", shield - absorbed)
	end
	local rest = amount - absorbed
	if rest > 0 then
		hum:TakeDamage(rest)
	end
end

return Damage
