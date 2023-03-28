World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -2
World.cellMaxX = 1
World.cellMinY = -2
World.cellMaxY = 1
World.worldBorder = true

function World.server_onCreate( self )
    print("World.server_onCreate")

    local manager = sm.storage.load( "INPUTMANAGER" )
    if manager == nil then
        manager = sm.shape.createPart( sm.uuid.new("8d3c62be-852d-475e-a8d1-f9cacf88cbf9"), sm.vec3.new(0,0,-10), sm.quat.identity(), false, true ):getInteractable()
        sm.storage.save( "INPUTMANAGER", manager )
    end

    g_inputManager = manager
end