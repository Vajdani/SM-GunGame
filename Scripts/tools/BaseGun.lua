dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$CONTENT_DATA/Scripts/util.lua"

---@class BaseGun : ToolClass
---@field isLocal boolean
---@field aiming boolean
---@field cl_aiming boolean
---@field shooting boolean
---@field cl_shooting boolean
---@field cl_reloading boolean
---@field damage boolean
---@field ammo number
---@field fireCooldown number
---@field shootEffect Effect
---@field shootEffectFP Effect
---@field aimBlendSpeed number
---@field blendTime number
---@field movementDispersion number
---@field sprintCooldownTimer number
---@field sprintCooldown number
---@field fpAnimations table
---@field tpAnimations table
---@field cl_create function
---@field sv_create function
---@field cl_equip function
---@field cl_unequip function
---@field cl_update function
---@field calculateFirePosition function
---@field calculateTpMuzzlePos function
---@field calculateFpMuzzlePos function

BaseGun = class()

function BaseGun:sv_updateShooting(shooting)
    self.network:sendToClients("cl_updateShooting", shooting)
end

function BaseGun:cl_shoot()
    local data = self.gunData
    local delayVar = self[data.fireDelayVar]
    if not self.cl_shooting or self.fireCooldown > 0 or (delayVar and delayVar < 1) then return end

    self.network:sendToServer("sv_onShoot", self.ammo)
	self.fireCooldown = self.gunData.cooldown
	if self.ammo > 0 then
        local firstPerson = self.tool:isInFirstPersonView()
        local dir = sm.localPlayer.getDirection()
        local firePos = self:calculateFirePosition()
        local fakePosition = self:calculateTpMuzzlePos()
        local fakePositionSelf = fakePosition
        if firstPerson then
            fakePositionSelf = self:calculateFpMuzzlePos()
        end

        if not firstPerson then
            local raycastPos = sm.camera.getPosition() + sm.camera.getDirection() * sm.camera.getDirection():dot( GetOwnerPosition( self.tool ) - sm.camera.getPosition() )
            local hit, result = sm.localPlayer.getRaycast( 250, raycastPos, sm.camera.getDirection() )
            if hit then
                local norDir = sm.vec3.normalize( result.pointWorld - firePos )
                local dirDot = norDir:dot( dir )

                if dirDot > 0.96592583 then
                    dir = norDir
                else
                    local radsOff = math.asin( dirDot )
                    dir = sm.vec3.lerp( dir, norDir, math.tan( radsOff ) / 3.7320508 )
                end
            end
        end
        dir = dir:rotate( math.rad( 0.955 ), sm.camera.getRight() )

		local fireMode = data.fireModes.normal
		local recoilDispersion = 1.0 - ( math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding ) + fireMode.maxMovementDispersion )
		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0
		spreadFactor = clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 )
		local spreadDeg =  fireMode.spreadMinAngle + ( fireMode.spreadMaxAngle - fireMode.spreadMinAngle ) * spreadFactor
        sm.projectile.projectileAttack(
            data.projectile,
            data.damage,
            firePos,
            sm.noise.gunSpread( dir, spreadDeg ) * fireMode.fireVelocity,
            self.tool:getOwner(),
            fakePosition,
            fakePositionSelf
        )

        self.ammo = self.ammo - 1
	end
end

function BaseGun:sv_onShoot(ammo)
	self.network:sendToClients( "cl_onShoot", ammo )
end

function BaseGun:sv_onAim( aiming )
    self.aiming = aiming
	self.network:sendToClients( "cl_onAim", aiming )
end

function BaseGun:sv_onReload()
    self.network:sendToClients("cl_onReload")
end



function BaseGun:cl_create()
    self.isLocal = self.tool:isLocal()

    local data = self.gunData
    self.damage = data.dmg
    self.ammo = data.magSize
    self.fireCooldown = 0
    self.cl_shooting = false
    self.cl_aiming = false
    self.cl_reloading = false

    self.shootEffect = sm.effect.createEffect( data.effectTp )
	self.shootEffectFP = sm.effect.createEffect( data.effectFp )

    self.aimBlendSpeed = 3.0
	self.blendTime = 0.2
    self.movementDispersion = 0.0
	self.sprintCooldownTimer = 0.0
	self.sprintCooldown = 0.3
	self.spreadCooldownTimer = 0.0
	self.jointWeight = 0.0
	self.spineWeight = 0.0

	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
end

function BaseGun:cl_updateShooting(shooting)
    self.cl_shooting = shooting
end

function BaseGun:loadAnimations()
	local anims = self.gunData.animations
	self.tpAnimations = _createTpAnimations(self.tool, anims.tp)
	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	for name, animation in pairs( anims.movement ) do
		self.tool:setMovementAnimation( name, animation )
	end

	if self.isLocal then
		self.fpAnimations = createFpAnimations(self.tool, anims.fp)
	end
end

function BaseGun:cl_equip(animate)
    if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	self.cl_aiming = false
	self.cl_shooting = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

    local currentRenderablesTp = {}
	local currentRenderablesFp = {}

    local renderables = self.gunData.renderables
	for k,v in pairs( renderables.animTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables.animFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables.models ) do
		currentRenderablesTp[#currentRenderablesTp+1] = v
		currentRenderablesFp[#currentRenderablesFp+1] = v
	end

	self.tool:setTpRenderables( currentRenderablesTp )
	if self.isLocal then
		self.tool:setFpRenderables( currentRenderablesFp )
	end

	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.isLocal then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function BaseGun:cl_unequip(animate)
    self.wantEquipped = false
	self.equipped = false
	self.cl_aiming = false
	self.cl_shooting = false

	if sm.exists( self.tool ) then
		if animate then
			sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
		end
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.isLocal then
			self.tool:setMovementSlowDown( false )
			self.tool:setBlockSprint( false )
			self.tool:setCrossHairAlpha( 1.0 )
			self.tool:setInteractionTextSuppressed( false )
			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
			end

            self.network:sendToServer("sv_updateShooting", false)
		end
	end
end

local aimAnims = {
    aimInto = true,
    aimIdle = true,
    aimShoot = true
}

local reloadAnims = {
    reload = true
}

---@return Vec3?
function BaseGun:cl_update(dt)
    local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()

    if self.isLocal then
		if self.equipped then
            local current = self.fpAnimations.currentAnimation
            if isSprinting and current ~= "sprintInto" and current ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( current == "sprintIdle" or current == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end

			if self.cl_aiming and not aimAnims[current] == true then
				swapFpAnimation( self.fpAnimations, "aimExit", "aimInto", 0.0 )
			end
			if not self.cl_aiming and aimAnims[current] == true then
				swapFpAnimation( self.fpAnimations, "aimInto", "aimExit", 0.0 )
			end

            local data = self.fpAnimations.animations[current]
            if data and reloadAnims[current] == true then
                if data.time + data.playRate * dt >= data.info.duration then
                    self.ammo = self.gunData.magSize
                    self.cl_reloading = false
                end
            end
        end

		updateFpAnimations( self.fpAnimations, self.equipped, dt )
	end

    if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

    if self.isLocal then
        self:updateFp(dt, isCrouching)
        self:updateCam(dt)

        self.fireCooldown = math.max(self.fireCooldown - dt, 0)
    end
    self:updateTp(dt, isSprinting, isCrouching)

    return self:updateFx()
end

function BaseGun:updateFp(dt, isCrouching)
    self.spreadCooldownTimer = math.max( self.spreadCooldownTimer - dt, 0.0 )
	self.sprintCooldownTimer = math.max( self.sprintCooldownTimer - dt, 0.0 )

	if self.isLocal then
		local dispersion = 0.0
		local fireMode = self.gunData.fireModes.normal
		local recoilDispersion = 1.0 - ( math.max( fireMode.minDispersionCrouching, fireMode.minDispersionStanding ) + fireMode.maxMovementDispersion )

		if isCrouching then
			dispersion = fireMode.minDispersionCrouching
		else
			dispersion = fireMode.minDispersionStanding
		end

		if self.tool:getRelativeMoveDirection():length() > 0 then
			dispersion = dispersion + fireMode.maxMovementDispersion * self.tool:getMovementSpeedFraction()
		end

		if not self.tool:isOnGround() then
			dispersion = dispersion * fireMode.jumpDispersionMultiplier
		end

		self.movementDispersion = dispersion

		self.spreadCooldownTimer = clamp( self.spreadCooldownTimer, 0.0, fireMode.spreadCooldown )
		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0

		self.tool:setDispersionFraction( clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 ) )

		if self.cl_aiming then
			if self.tool:isInFirstPersonView() then
				self.tool:setCrossHairAlpha( 0.0 )
			else
				self.tool:setCrossHairAlpha( 1.0 )
			end
			self.tool:setInteractionTextSuppressed( true )
		else
			self.tool:setCrossHairAlpha( 1.0 )
			self.tool:setInteractionTextSuppressed( false )
		end
	end

	local blockSprint = self.cl_aiming or self.sprintCooldownTimer > 0.0
	self.tool:setBlockSprint( blockSprint )
end

function BaseGun:updateCam(dt)
    local bobbing = 1
	if self.cl_aiming then
		local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, dt * 60 )
		self.aimWeight = sm.util.lerp( self.aimWeight, 1.0, blend )
		bobbing = 0.12
	else
		local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, dt * 60 )
		self.aimWeight = sm.util.lerp( self.aimWeight, 0.0, blend )
		bobbing = 1
	end

	self.tool:updateCamera( 2.8, 30.0, sm.vec3.new( 0.65, 0.0, 0.05 ), self.aimWeight )
	self.tool:updateFpCamera( 30.0, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, bobbing )
end

function BaseGun:updateTp(dt, isSprinting, isCrouching)
    local playerDir = self.tool:getSmoothDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

	local totalWeight = 0.0
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "shoot" or name == "aimShoot" ) then
					setTpAnimation( self.tpAnimations, self.cl_aiming and "aim" or "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, self.cl_aiming and "aim" or "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end

	local relativeMoveDirection = self.tool:getRelativeMoveDirection()
	if ( ( ( isAnyOf( self.tpAnimations.currentAnimation, { "aimInto", "aim", "shoot" } ) and ( relativeMoveDirection:length() > 0 or isCrouching) ) or ( self.cl_aiming and ( relativeMoveDirection:length() > 0 or isCrouching) ) ) and not isSprinting ) then
		self.jointWeight = math.min( self.jointWeight + ( 10.0 * dt ), 1.0 )
	else
		self.jointWeight = math.max( self.jointWeight - ( 6.0 * dt ), 0.0 )
	end

	if ( not isSprinting ) then
		self.spineWeight = math.min( self.spineWeight + ( 10.0 * dt ), 1.0 )
	else
		self.spineWeight = math.max( self.spineWeight - ( 10.0 * dt ), 0.0 )
	end

	local finalAngle = ( 0.5 + angle * 0.5 )
	self.tool:updateAnimation( "spudgun_spine_bend", finalAngle, self.spineWeight )

	local totalOffsetZ = lerp( -22.0, -26.0, crouchWeight )
	local totalOffsetY = lerp( 6.0, 12.0, crouchWeight )
	local crouchTotalOffsetX = clamp( ( angle * 60.0 ) -15.0, -60.0, 40.0 )
	local normalTotalOffsetX = clamp( ( angle * 50.0 ), -45.0, 50.0 )
	local totalOffsetX = lerp( normalTotalOffsetX, crouchTotalOffsetX , crouchWeight )
	local finalJointWeight = ( self.jointWeight )
	self.tool:updateJoint( "jnt_hips", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.35 * finalJointWeight * ( normalWeight ) )

	local crouchSpineWeight = ( 0.35 / 3 ) * crouchWeight
	self.tool:updateJoint( "jnt_spine1", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight )  * finalJointWeight )
	self.tool:updateJoint( "jnt_spine2", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_spine3", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.45 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_head", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.3 * finalJointWeight )
end

function BaseGun:updateFx()
	if self.isLocal then
		local dir = sm.localPlayer.getDirection()
		local firePos = self.tool:getFpBonePos( "pejnt_barrel" )

		if not self.cl_aiming then
			firePos = firePos + dir * 0.2
		else
			firePos = firePos + dir * 0.45
		end

		self.shootEffectFP:setPosition( firePos )
		self.shootEffectFP:setVelocity( self.tool:getMovementVelocity() )
		self.shootEffectFP:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir ) )
	end

	local dir = self.tool:getTpBoneDir( "pejnt_barrel" )
    local pos = self.tool:getTpBonePos( "pejnt_barrel" ) + dir * 0.2
	self.shootEffect:setPosition( pos )
	self.shootEffect:setVelocity( self.tool:getMovementVelocity() )
	self.shootEffect:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir ) )

    return pos
end

function BaseGun:client_onReload()
    if self.ammo < self.gunData.magSize and not self.cl_reloading then
        self.cl_reloading = true
        self.network:sendToServer("sv_onReload")
    end

    return true
end

function BaseGun:client_onEquippedUpdate( lmb, rmb, f )
	local shooting = (lmb == 1 or lmb == 2) and not self.cl_reloading
	if self.cl_shooting ~= shooting then
		self.cl_shooting = shooting
		self.network:sendToServer("sv_updateShooting", shooting)
	end
    self:cl_shoot()

    local aiming = rmb == 1 or rmb == 2
    if self.gunData.canAim and aiming ~= self.cl_aiming then
		self.cl_aiming = aiming
        self.tpAnimations.animations.idle.time = 0

        self.tool:setMovementSlowDown( aiming )
        self.network:sendToServer( "sv_onAim", aiming )
	end

	return true, true
end

function BaseGun:cl_onShoot(ammo)
    if ammo > 0 then
        self.tpAnimations.animations.idle.time = 0
        self.tpAnimations.animations.shoot.time = 0
        self.tpAnimations.animations.aimShoot.time = 0

        setTpAnimation( self.tpAnimations, self.cl_aiming and "aimShoot" or "shoot", 10.0 )
        if self.isLocal then
            setFpAnimation( self.fpAnimations, self.cl_aiming and "aimShoot" or "shoot", 0.05 )

            local fireMode = self.cl_aiming and self.gunData.fireModes.aim or self.gunData.fireModes.normal
            self.spreadCooldownTimer = math.min( self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown )
            self.sprintCooldownTimer = self.sprintCooldown
        end

        if self.tool:isInFirstPersonView() then
            self.shootEffectFP:start()
        else
            self.shootEffect:start()
        end
    else
        sm.audio.play("PotatoRifle - NoAmmo", self.tool:getPosition())
    end
end

function BaseGun:cl_onAim( aiming )
    self.cl_aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.cl_aiming then
		setTpAnimation( self.tpAnimations, self.cl_aiming and "aim" or "idle", 5.0 )
	end
end

function BaseGun:cl_onReload()
    self:cl_onAim(false)

    setTpAnimation( self.tpAnimations, "reload", 10.0 )
    if self.isLocal then
	    setFpAnimation( self.fpAnimations, "reload", 0.05 )
    end
end



function BaseGun:calculateFirePosition()
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.localPlayer.getRight()

	local fireOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	if crouching then
		fireOffset.z = 0.15
	else
		fireOffset.z = 0.45
	end

	if firstPerson then
		if not self.cl_aiming then
			fireOffset = fireOffset + right * 0.05
		end
	else
		fireOffset = fireOffset + right * 0.25
		fireOffset = fireOffset:rotate( math.rad( pitch ), right )
	end
	local firePosition = GetOwnerPosition( self.tool ) + fireOffset
	return firePosition
end

function BaseGun:calculateTpMuzzlePos()
	local crouching = self.tool:isCrouching()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.localPlayer.getRight()
	local up = right:cross(dir)

	local fakeOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	--General offset
	fakeOffset = fakeOffset + right * 0.25
	fakeOffset = fakeOffset + dir * 0.5
	fakeOffset = fakeOffset + up * 0.25

	--Action offset
	local pitchFraction = pitch / ( math.pi * 0.5 )
	if crouching then
		fakeOffset = fakeOffset + dir * 0.2
		fakeOffset = fakeOffset + up * 0.1
		fakeOffset = fakeOffset - right * 0.05

		if pitchFraction > 0.0 then
			fakeOffset = fakeOffset - up * 0.2 * pitchFraction
		else
			fakeOffset = fakeOffset + up * 0.1 * math.abs( pitchFraction )
		end
	else
		fakeOffset = fakeOffset + up * 0.1 *  math.abs( pitchFraction )
	end

	local fakePosition = fakeOffset + GetOwnerPosition( self.tool )
	return fakePosition
end

function BaseGun:calculateFpMuzzlePos()
	local fovScale = ( sm.camera.getFov() - 45 ) / 45

	local up = sm.localPlayer.getUp()
	local dir = sm.localPlayer.getDirection()
	local right = sm.localPlayer.getRight()

	local muzzlePos45 = sm.vec3.new( 0.0, 0.0, 0.0 )
	local muzzlePos90 = sm.vec3.new( 0.0, 0.0, 0.0 )

	if self.cl_aiming then
		muzzlePos45 = muzzlePos45 - up * 0.2
		muzzlePos45 = muzzlePos45 + dir * 0.5

		muzzlePos90 = muzzlePos90 - up * 0.5
		muzzlePos90 = muzzlePos90 - dir * 0.6
	else
		muzzlePos45 = muzzlePos45 - up * 0.15
		muzzlePos45 = muzzlePos45 + right * 0.2
		muzzlePos45 = muzzlePos45 + dir * 1.25

		muzzlePos90 = muzzlePos90 - up * 0.15
		muzzlePos90 = muzzlePos90 + right * 0.2
		muzzlePos90 = muzzlePos90 + dir * 0.25
	end

	return self.tool:getFpBonePos( "pejnt_barrel" ) + sm.vec3.lerp( muzzlePos45, muzzlePos90, fovScale )
end