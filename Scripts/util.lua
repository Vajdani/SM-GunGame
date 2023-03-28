uuid_nil = sm.uuid.getNil()
vec3_up = sm.vec3.new(0,0,1)
GameModes = {
	team = 1,
	solo = 2
}


function calculateRightVector(vector)
    local yaw = math.atan2(vector.y, vector.x) - math.pi / 2
    return sm.vec3.new(math.cos(yaw), math.sin(yaw), 0)
end

function _createTpAnimations( tool, animationMap )
	local data = {}
	data.tool = tool
	data.animations = {}

	for name, pair in pairs(animationMap) do
		local animation = {
			info = tool:getAnimationInfo(pair[1]),
			time = 0.0,
			weight = 0.0,
			playRate = pair[2] and pair[2].playRate or 1.0,
			looping =  pair[2] and pair[2].looping or false,
			nextAnimation = pair[2] and pair[2].nextAnimation or nil,
			blendNext = pair[2] and pair[2].blendNext or 0.0
		}

		if pair[2] and pair[2].dirs then
			animation.dirs = {
				up = tool:getAnimationInfo(pair[2].dirs.up),
				fwd = tool:getAnimationInfo(pair[2].dirs.fwd),
				down = tool:getAnimationInfo(pair[2].dirs.down)
			}
		end

		if pair[2] and pair[2].crouch then
			animation.crouch = tool:getAnimationInfo(pair[2].crouch)
		end

		if animation.info == nil then
			print("Error: failed to get third person animation info for: ", pair[1])
			animation.info = { name = name, duration = 1.0, looping = false }
		end

		data.animations[name] = animation;
	end

	data.blendSpeed = 0.0
	data.currentAnimation = ""
	return data
end

function isOnSameTeam(player, attacker)
	return type(player) == type(attacker) and g_team1[player:getName()] ~= nil == g_team1[attacker:getName()] ~= nil
end