dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$CONTENT_DATA/Scripts/tools/BaseGun.lua" )

---@classs Rifle : BaseGun
Rifle = class(BaseGun)
Rifle.gunData = {
	damage = 28,
	cooldown = 0.2,
	magSize = 15,
	projectile = projectile_potato,
	canAim = true,
	autoFire = false,
	effectTp = "SpudgunBasic - BasicMuzzel",
	effectFp = "SpudgunBasic - FPBasicMuzzel",
	renderables = {
		models = {
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
			"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
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
			spreadIncrement = 2.6,
			spreadMinAngle = 0.25,
			spreadMaxAngle = 8,
			fireVelocity = 130.0,
			minDispersionStanding = 0.1,
			minDispersionCrouching = 0.04,
			maxMovementDispersion = 0.4,
			jumpDispersionMultiplier = 2
		},
		aim = {
			spreadCooldown = 0.18,
			spreadIncrement = 1.3,
			spreadMinAngle = 0,
			spreadMaxAngle = 8,
			fireVelocity =  130.0,
			minDispersionStanding = 0.01,
			minDispersionCrouching = 0.01,
			maxMovementDispersion = 0.4,
			jumpDispersionMultiplier = 2
		}
	}
}

function Rifle:client_onCreate()
	self:cl_create()
end

function Rifle:client_onUpdate(dt)
	self:cl_update(dt)
end

function Rifle:client_onEquip(animate)
	self:cl_equip(animate)
end

function Rifle:client_onUnequip(animate)
	self:cl_unequip(animate)
end