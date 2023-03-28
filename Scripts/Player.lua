---@class Player : PlayerClass
Player = class( nil )
Player.maxHp = 100

dofile "$CONTENT_DATA/Scripts/util.lua"

function Player:server_onCreate()
	self:sv_resetInv()

	self.hp = self.maxHp
	self.player.publicData = {
		weaponTier = 1,
		kills = 0
	}
end

function Player:sv_resetInv(item)
	sm.container.beginTransaction()
	local inv = self.player:getInventory()
	local uuid = item or uuid_nil
	for i = 1, inv:getSize() do
		inv:setItem(i-1, uuid, 1)
	end
	sm.container.endTransaction()
end

function Player:server_onExplosion(center, destructionLevel)
	self:sv_takeDamage(destructionLevel * 4, "explosive", "explosion")
end

function Player:server_onProjectile(position, airTime, velocity, projectileName, attacker, damage, customData, normal, uuid)
	self:sv_takeDamage(damage, projectileName, attacker)
end

function Player:server_onMelee(position, attacker, damage, power, direction, normal)
	self:sv_takeDamage(damage, "melee", attacker)
end

function Player:sv_takeDamage(damage, damageType, attacker)
	if not g_gameStarted or self.player ~= attacker and not g_gameSettings.friendlyFire and isOnSameTeam(self.player, attacker) then return end

	self.hp = math.max(self.hp - damage, 0)
	print(string.format("Player %s took %s damage, current health: %s / %s", self.player.id, damage, self.hp, self.maxHp))

	local dead = self.hp <= 0
	if dead then
		print(self.player, "KILLED BY", attacker)

		local character = self.player.character
		character:setTumbling(true)
		character:setDowned(true)
	end

	if type(attacker) == "Player" then
		local kills = attacker.publicData.kills + 1
		if kills >= g_gameSettings.killsToProgress then
			sm.event.sendToPlayer(attacker, "sv_progressWpTier")
			kills = 0
		end

		attacker.publicData.kills = kills
	end
	self.network:setClientData({ dead = dead, hp = self.hp })
end

function Player:sv_revive()
	local character = self.player.character
	character:setTumbling(false)
	character:setDowned(false)

	self.hp = self.maxHp
	self.network:setClientData({ dead = false, hp = self.hp })
end

function Player:sv_progressWpTier()
	local tier = sm.util.clamp(self.player.publicData.weaponTier + 1, 0, #g_weaponTiers)
    self.player.publicData.weaponTier = tier

	local weapon = g_weaponTiers[tier]
	self:sv_resetInv(weapon)
	self.network:sendToClient(
		self.player, "cl_displayMsg",
		{
			msg = "New weapon: #df7f00"..sm.shape.getShapeTitle(weapon),
			dur = 2.5
		}
	)
end



function Player:client_onCreate()
	self.player.clientPublicData = { isDead = false }

	self.isLocal = self.player == sm.localPlayer.getPlayer()
	if not self.isLocal then return end

	self.survivalHud = sm.gui.createSurvivalHudGui()
	self.survivalHud:setVisible("WaterBar", false)
	self.survivalHud:setVisible("FoodBar", false)
	self.survivalHud:open()

	local actions = sm.interactable.actions
	self.player.clientPublicData.spectating = false
	self.player.clientPublicData.input = {
		[actions.forward] = false,
		[actions.backward] = false,
		[actions.left] = false,
		[actions.right] = false,
		[actions.jump] = false,
		[actions.use] = false,
		[actions.item0] = false,
		[actions.item1] = false,
	}
end

function Player:client_onUpdate(dt)
	if not self.isLocal then return end

	local char = self.player.character
	local pub = self.player.clientPublicData
	if self.player.clientPublicData.spectating then
		local moveSpeed = dt * 10
		local fwd = 0
		local controls = pub.input

		if controls[3] then fwd = fwd + moveSpeed end
		if controls[4] then fwd = fwd - moveSpeed end

		local right = 0
		if controls[2] then right = right + moveSpeed end
		if controls[1] then right = right - moveSpeed end

		local up = 0
		if controls[5] then up = up + moveSpeed end
		if controls[6] then up = up - moveSpeed end

		local playerDir = char.direction
		self.camPos = self.camPos + playerDir * fwd + calculateRightVector(playerDir) * right + vec3_up * up

		local lerp = dt * 10
		sm.camera.setPosition(sm.vec3.lerp(sm.camera.getPosition(), self.camPos, lerp))
		sm.camera.setDirection(playerDir --[[sm.vec3.lerp(sm.camera.getDirection(), playerDir, lerp)]])
	elseif pub.isDead then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), "Enter spectate mode")
	end
end

function Player:client_onClientDataUpdate( data )
	self.player.clientPublicData.isDead = data.dead

	if not self.isLocal then return end

	if data.dead then
		sm.camera.setCameraState( 4 )
	elseif sm.camera.getCameraState() ~= 1 then
		sm.camera.setCameraState( 1 )
	end

	self.survivalHud:setSliderData( "Health", self.maxHp * 10 + 1, data.hp * 10 )
end

function Player:client_onInteract(char, state)
	if not state or not self.player.clientPublicData.isDead or self.player.clientPublicData.spectating then return end
	self:cl_setFreecam(true)
end

function Player:client_onReload()
	self.network:sendToServer("sv_revive")
	self:cl_setFreecam(false)
end

function Player:cl_setFreecam(state)
	if state == nil or state == true or state == 1 then
		self.camPos = sm.camera.getPosition()
		sm.camera.setCameraState(3)
		sm.camera.setPosition(self.camPos)
		sm.camera.setDirection(self.player.character.direction)
		sm.camera.setFov(sm.camera.getDefaultFov())
		self.player.clientPublicData.spectating = true
	else
		sm.camera.setCameraState(1)
		self.player.clientPublicData.spectating = false
	end
end

function Player:cl_displayMsg(args)
	sm.gui.displayAlertText(args.msg, args.dur)
end