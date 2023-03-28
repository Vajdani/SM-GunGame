dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$CONTENT_DATA/Scripts/tools/BaseGun.lua" )

---@classs Minigun : BaseGun
Minigun = class(BaseGun)
Minigun.gunData = {
	damage = 20,
	cooldown = 0.1,
	magSize = 50,
	projectile = projectile_smallpotato,
	canAim = false,
	autoFire = true,
	fireDelayVar = "gatlingWeight",
	effectTp = "SpudgunSpinner - SpinnerMuzzel",
	effectFp = "SpudgunSpinner - FPSpinnerMuzzel",
	renderables = {
		models = {
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_spinner/char_spudgun_barrel_spinner.rend",
			--"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_spinner/char_spudgun_sight_spinner.rend",
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
		},
		animTp = {
			"$CONTENT_DATA/Tools/Spudgun/char_male_tp.rend",
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
		},
		animFp = {
			"$CONTENT_DATA/Tools/Spudgun/char_male_fp.rend",
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
		}
	},
	animations = {
		movement = {
			idle = "spudgun_idle",
			idleRelaxed = "spudgun_relax",

			sprint = "spudgun_sprint",
			runFwd = "spudgun_run_fwd",
			runBwd = "spudgun_run_bwd",

			jump = "spudgun_jump",
			jumpUp = "spudgun_jump_up",
			jumpDown = "spudgun_jump_down",

			land = "spudgun_jump_land",
			landFwd = "spudgun_jump_land_fwd",
			landBwd = "spudgun_jump_land_bwd",

			crouchIdle = "spudgun_crouch_idle",
			crouchFwd = "spudgun_crouch_fwd",
			crouchBwd = "spudgun_crouch_bwd"
		},
		tp = {
			shoot = { "spudgun_shoot", { crouch = "spudgun_crouch_shoot" } },
			aim = { "spudgun_aim", { crouch = "spudgun_crouch_aim" } },
			aimShoot = { "spudgun_aim_shoot", { crouch = "spudgun_crouch_aim_shoot" } },
			idle = { "spudgun_idle" },
			pickup = { "spudgun_pickup", { nextAnimation = "idle" } },
			putdown = { "spudgun_putdown" },
			reload = { "spudgun_reload", { nextAnimation = "idle" } }
		},
		fp = {
			equip = { "spudgun_pickup", { nextAnimation = "idle" } },
			unequip = { "spudgun_putdown" },
			idle = { "spudgun_idle", { looping = true } },
			shoot = { "spudgun_shoot", { nextAnimation = "idle" } },
			aimInto = { "spudgun_aim_into", { nextAnimation = "aimIdle" } },
			aimExit = { "spudgun_aim_exit", { nextAnimation = "idle", blendNext = 0 } },
			aimIdle = { "spudgun_aim_idle", { looping = true} },
			aimShoot = { "spudgun_aim_shoot", { nextAnimation = "aimIdle"} },
			sprintInto = { "spudgun_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
			sprintExit = { "spudgun_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
			sprintIdle = { "spudgun_sprint_idle", { looping = true } },
			reload = { "spudgun_reload", { nextAnimation = "idle" } }
		}
	},
	fireModes = {
		normal = {
			spreadCooldown = 0.18,
			spreadIncrement = 3.9,
			spreadMinAngle = 0.25,
			spreadMaxAngle = 32,
			fireVelocity = 130.0,
			minDispersionStanding = 0.1,
			minDispersionCrouching = 0.04,
			maxMovementDispersion = 0.4,
			jumpDispersionMultiplier = 2
		}
	}
}

function Minigun:client_onCreate()
	self:cl_create()

	self.windupEffect = sm.effect.createEffect( "SpudgunSpinner - Windup" )

	self.gatlingBlendSpeedIn = 1.5
	self.gatlingBlendSpeedOut = 0.375
	self.gatlingWeight = 0.0
	self.gatlingTurnSpeed = ( 1 / self.gunData.cooldown ) / 3
	self.gatlingTurnFraction = 0.0
end


function Minigun:client_onUpdate(dt)
	if not sm.exists(self.tool) then return end

	local pos = self:cl_update(dt)
	if pos then self.windupEffect:setPosition( pos ) end

	if self.equipped then self:cl_updateGatling(dt) end
end

function Minigun:cl_updateGatling(dt)
	self.gatlingWeight = self.cl_shooting and ( self.gatlingWeight + self.gatlingBlendSpeedIn * dt ) or ( self.gatlingWeight - self.gatlingBlendSpeedOut * dt )
	self.gatlingWeight = math.min( math.max( self.gatlingWeight, 0.0 ), 1.0 )
	local frac
	frac, self.gatlingTurnFraction = math.modf( self.gatlingTurnFraction + self.gatlingTurnSpeed * self.gatlingWeight * dt )

	self.windupEffect:setParameter( "velocity", self.gatlingWeight )
	if self.equipped and not self.windupEffect:isPlaying() then
		self.windupEffect:start()
	elseif not self.equipped and self.windupEffect:isPlaying() then
		self.windupEffect:stop()
	end

	if self.tool:isLocal() then
		self.tool:updateFpAnimation( "spudgun_spinner_shoot_fp", self.gatlingTurnFraction, 1.0, true )
	end
	self.tool:updateAnimation( "spudgun_spinner_shoot_tp", self.gatlingTurnFraction, 1.0 )
end

function Minigun:client_onEquip(animate)
	self.gatlingWeight = 0.0
	self:cl_equip(animate)
end

function Minigun:client_onUnequip(animate)
	self.gatlingWeight = 0.0
	self.windupEffect:stop()
	self:cl_unequip(animate)
end