---@class Game : GameClass
---@field sv table
Game = class( nil )
Game.defaultInventorySize = 10
Game.enableLimitedInventory = true
Game.enableAmmoConsumption = false

dofile "$CONTENT_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

local weapons = {
    sm.uuid.new("c5ea0c2f-185b-48d6-b4df-45c386a575cc"), --Rifle
    sm.uuid.new("f6250bf4-9726-406f-a29a-945c06e460e5"), --Shotgun
    sm.uuid.new("9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b"), --Minigun
    sm.uuid.new("bb641a4f-e391-441c-bc6d-0ae21a069476"), --Hammer

    sm.uuid.new("336a7328-4d50-432c-8698-2ed511187cc7"), --Tommy
    sm.uuid.new("96f3b45c-8729-4573-bc14-bbe1cc7fd2bb"), --Magnum
    sm.uuid.new("5a1ca305-513f-42db-ae71-52bd0a9247fc"), --Eoka
    sm.uuid.new("c0cb7836-075a-478a-af3d-0b7360721527"), --Mosin
    sm.uuid.new("b0c08b35-4b40-40fe-b933-ca123f99eef8"), --SShotgun
}

function Game.server_onCreate( self )
	print("Game.server_onCreate")

    g_gameStarted = false
    g_gameSettings = {
        gameMode = GameModes.solo,
        friendlyFire = false,
        killsToProgress = 2
    }
    g_team1 = {}
    g_team2 = {}

    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
		self.storage:save( self.sv.saved )
	end
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
    if isNewPlayer then
        if not sm.exists( self.sv.saved.world ) then
            sm.world.loadWorld( self.sv.saved.world )
        end
        self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
    end
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 32, 32, 5 ), 0, 0 )
	player:setCharacter( character )
end

function Game:sv_invToggle()
    sm.game.setLimitedInventory(not sm.game.getLimitedInventory())
end

function Game:sv_startGame()
    --if g_gameStarted then return end
    g_gameStarted = true
    g_weaponTiers = shuffle(shallowcopy(weapons))
    local startingWeapon = g_weaponTiers[1]

    --sort the players into teams
    local players = shuffle(sm.player.getAllPlayers())
    local half = math.floor(#players * 0.5)
    for i, player in pairs(players) do
        local name = player:getName()
        if i <= half then
            g_team1[name] = player
            print("TEAM1:", name)
        else
            g_team2[name] = player
            print("TEAM2:", name)
        end

        sm.event.sendToPlayer(player, "sv_resetInv", startingWeapon)
        player.publicData.weaponTier = 1
        player.publicData.kills = 0
    end

    --tp them to spots on the map
end

function Game:sv_die(data, caller)
    sm.event.sendToPlayer(caller, "sv_takeDamage", 69420)
end

function Game:sv_wpTier(data, caller)
    sm.event.sendToPlayer(caller, "sv_progressWpTier")
end



function Game:client_onCreate()
    self:bindCmds()
end

function Game:bindCmds()
    sm.game.bindChatCommand( "/inv", {}, "cl_invToggle", "Toggle unlimited inv" )
    sm.game.bindChatCommand( "/start", {}, "cl_startGame", "Starts game" )
    sm.game.bindChatCommand( "/die", {}, "cl_die", "Kill your character" )
    sm.game.bindChatCommand( "/freecam", { { "bool", "", false } }, "cl_freecam", "Set free cam" )
    sm.game.bindChatCommand( "/wptier", {}, "cl_wpTier", "Progress your weapon tier" )
end

function Game:cl_invToggle()
    self.network:sendToServer("sv_invToggle")
end

function Game:cl_startGame()
    self.network:sendToServer("sv_startGame")
end

function Game:cl_die()
    self.network:sendToServer("sv_die")
end

function Game:cl_freecam(args)
    sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setFreecam", args[2])
end

function Game:cl_wpTier()
    self.network:sendToServer("sv_wpTier")
end