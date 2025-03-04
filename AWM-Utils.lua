--[[===========================================================================
                      AccurateWorldMap Utility Functions
===============================================================================

                Utility functions that help the main addon work.

---------------------------------------------------------------------------]]--

-------------------------------------------------------------------------------
-- Get base addon object, callbacks, and dependencies
-------------------------------------------------------------------------------

AWM = AWM or {}
local LocalCallbackManager = ZO_CallbackObject:Subclass()
local GPS = LibGPS3
local LZ = LibZone 
local LMP = LibMapPing2

-------------------------------------------------------------------------------
-- Get addon info from addon manifest
-------------------------------------------------------------------------------

function getAddonInfo(addonName)

  local AddOnManager = GetAddOnManager()
  local numAddons = AddOnManager:GetNumAddOns()

  for i = 1, numAddons do -- loop through all currently installed addon

    -- get addon info from manifest
    local name, title, author, description = AddOnManager:GetAddOnInfo(i)

    if (name == addonName) then -- we've found our addon!

      local addonTable = {}

      -- set addon data to metatable
      addonTable.title = title
      addonTable.name = name
      addonTable.author = author
      addonTable.description = description
      addonTable.options = {}

      return addonTable
    end
  end
end

-------------------------------------------------------------------------------
-- Merge multiple tables into one
-------------------------------------------------------------------------------

local mergedTable = {}

function join(extra, newWorldspace)

  if (newWorldspace) then
    mergedTable = {}
  end

  table.insert(mergedTable, extra)
  return mergedTable
end

-------------------------------------------------------------------------------
-- Get if can reposition icons function
-------------------------------------------------------------------------------

function getIfCanRepositionIcons()
  return (GPS["GetMapMeasurementByMapId"] ~= nil)
end

-------------------------------------------------------------------------------
-- Is icon repositioning enabled function
-------------------------------------------------------------------------------

function isIconRepositioningEnabled()
  return (GPS["GetMapMeasurementByMapId"] ~= nil and AWM.options.iconRepositioning) 
end

-------------------------------------------------------------------------------
-- Is GeoParent enabled
-------------------------------------------------------------------------------

function isGeoParentEnabled()
  return (LZ ~= nil and LZ["GetGeographicalParentMapId"] ~= nil) 
end

-------------------------------------------------------------------------------
-- Print text to chat
-------------------------------------------------------------------------------

function print(message, isForced, ...)
  if (AWM.options.isDebug or isForced) then
    df("[%s] %s", AWM.name, tostring(message):format(...))
  end
end

-------------------------------------------------------------------------------
-- Check if mouse is inside of the map window
-------------------------------------------------------------------------------

function isMouseWithinMapWindow()
  local mouseOverControl = WINDOW_MANAGER:GetMouseOverControl()
  return (not ZO_WorldMapContainer:IsHidden() and (mouseOverControl == ZO_WorldMapContainer or mouseOverControl:GetParent() == ZO_WorldMapContainer))
end

-------------------------------------------------------------------------------
-- Check if world map window is being shown
-------------------------------------------------------------------------------

local canFireCallback = false

function isWorldMapShown()

  local isMapShown = ( ((not ZO_WorldMapContainer:IsHidden() and ZO_WorldMapContainer:GetAlpha() == 1) or ZO_WorldMap_IsWorldMapShowing()))

  if (isMapShown and canFireCallback) then

    zo_callLater(function()
  
      CALLBACK_MANAGER:FireCallbacks("OnWorldMapShown", nil)

    end, 300 )

    canFireCallback = false

  end

  if (not isMapShown and not canFireCallback) then

    canFireCallback = true

  end

  return isMapShown
end

-------------------------------------------------------------------------------
-- Check if world map window is active
-------------------------------------------------------------------------------

function isWorldMapActive()
  return ( isWorldMapShown() and isMouseWithinMapWindow() )
end

-------------------------------------------------------------------------------
-- Check if champion point window is being shown
-------------------------------------------------------------------------------

function isChampionPointWindowShown()
  return ( not ZO_ChampionPerksCanvas:IsHidden() and ZO_ChampionPerksCanvas:GetAlpha() == 1 )
end
  
  
-------------------------------------------------------------------------------
-- Get world map offsets from the sides of the screen
-------------------------------------------------------------------------------

function getWorldMapOffsets()
  return math.floor(ZO_WorldMapContainer:GetLeft()), math.floor(ZO_WorldMapContainer:GetTop())
end

-------------------------------------------------------------------------------
-- Determine whether a variable X is numeric or not
-------------------------------------------------------------------------------

function isNumeric(x)
  if tonumber(x) ~= nil then
      return true
  end
  return false
end

-------------------------------------------------------------------------------
-- Check if table has a certain value
-------------------------------------------------------------------------------

function hasValue (tab, val)
  for index, value in ipairs(tab) do
      if value == val then
          return true
      end
  end
  return false
end

-------------------------------------------------------------------------------
-- Simpler function to check if user is in gamepad mode
-------------------------------------------------------------------------------

local lastGamepadPreference

function isInGamepadMode()

  if (lastGamepadPreference ~= IsInGamepadPreferredMode()) then
    lastGamepadPreference = IsInGamepadPreferredMode()
    AWM.canRedrawMap = true
  end

  return (IsInGamepadPreferredMode() and not ZO_WorldMapCenterPoint:IsHidden())
end

-------------------------------------------------------------------------------
-- Get current cursor's position in screenspace
-------------------------------------------------------------------------------

function getMouseCoordinates()

  if (isInGamepadMode()) then
    return ZO_WorldMapScroll:GetCenter()
  else
    return GetUIMousePosition()
  end
end

-------------------------------------------------------------------------------
-- Return a number to set significant figure
-------------------------------------------------------------------------------

function sigFig(num, figures)
  local x = figures - math.ceil(math.log10(math.abs(num)))
  return(math.floor(num*10^x+0.5)/10^x)
end

-------------------------------------------------------------------------------
-- Get normalised cursor coordinates relative to worldmap
-------------------------------------------------------------------------------

function getNormalisedMouseCoordinates()

  local mouseX, mouseY = getMouseCoordinates()

  local currentOffsetX = ZO_WorldMapContainer:GetLeft()
  local currentOffsetY = ZO_WorldMapContainer:GetTop()
  local parentOffsetX = ZO_WorldMap:GetLeft()
  local parentOffsetY = ZO_WorldMap:GetTop()
  local mapWidth, mapHeight = ZO_WorldMapContainer:GetDimensions()
  local parentWidth, parentHeight = ZO_WorldMap:GetDimensions()

  local normalisedMouseX = math.floor((((mouseX - currentOffsetX) / mapWidth) * 1000) + 0.5)/1000
  local normalisedMouseY = math.floor((((mouseY - currentOffsetY) / mapHeight) * 1000) + 0.5)/1000

  return normalisedMouseX, normalisedMouseY

end

-------------------------------------------------------------------------------
-- Get the mapID of the current zone
-------------------------------------------------------------------------------

function getCurrentMapID()

  local zoneID = GetCurrentMapId()

  if (zoneID == nil) then
    zoneID = 0
  end

  return zoneID

end

-------------------------------------------------------------------------------
-- Get zoneInfo object by ID
-------------------------------------------------------------------------------

function getZoneInfoByID(zoneID, optionalIsDuplicate)

  if (mapData ~= nil) then
    for mapID, mapInfo in pairs(mapData) do
      if (mapInfo.zoneData ~= nil) then
        local zoneInfo = mapInfo.zoneData
          for zoneIndex, zoneInfo in pairs(zoneInfo) do
            if (optionalIsDuplicate ~= nil and optionalIsDuplicate) then
              if (zoneInfo.zoneID == zoneID and zoneInfo.isDuplicate ~= nil) then
                return zoneInfo
              end
            else
            if (zoneInfo.zoneID == zoneID and zoneInfo.isDuplicate == nil) then
              return zoneInfo
            end
          end
        end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Get map name from ID
-------------------------------------------------------------------------------

function getZoneNameFromID(zoneID, getDuplicateName)

  local zoneInfo

  if (getDuplicateName) then

    zoneInfo = getZoneInfoByID(zoneID, true)

  else

    zoneInfo = getZoneInfoByID(zoneID)

  end
  

  -- does this map have a custom name / are custom names enabled? 
  if ((zoneInfo ~= nil and zoneInfo.overrideLoreRenames ~= nil) or AWM.options.loreRenames) then

    if (zoneInfo ~= nil) then

      return zoneInfo.zoneName

    else

      return GetMapNameById(zoneID)

    end

  else
    -- else return vanilla name
    return GetMapNameById(zoneID)

  end

end

-------------------------------------------------------------------------------
-- Get map id from zone hitbox polygon name
-------------------------------------------------------------------------------

function getMapIDFromPolygonName(polygonName)
  return tonumber(string.match (polygonName, "%d+"))
end


-------------------------------------------------------------------------------
-- Is developer function
-------------------------------------------------------------------------------

function isDeveloper()
  return GetDisplayName() == "@Thal-J"
end

-------------------------------------------------------------------------------
-- Strip unneeded characters away from zone names
-------------------------------------------------------------------------------

function processZoneName(name)

  -- example: transform "Stros M'Kai" to "strosmkai"
  name = name:gsub("'", "")
  name = name:gsub(" ", "")
  name = name:gsub("-", "") 
  name = name:lower()

  return name
end

-------------------------------------------------------------------------------
-- Get blob file directory from map name
-------------------------------------------------------------------------------

function getFileDirectoryFromMapName(providedZoneName)
  local providedZoneName = providedZoneName

  providedZoneName = processZoneName(providedZoneName)
  
  local blobFileDirectory = ("AccurateWorldMap/blobs/blob-"..providedZoneName..".dds")
  return blobFileDirectory
end

-------------------------------------------------------------------------------
-- Get debug blob file directory from map name
-------------------------------------------------------------------------------

function getDebugFileDirectoryFromMapName(providedZoneName)
  local providedZoneName = providedZoneName

  providedZoneName = processZoneName(providedZoneName)
  
  local blobFileDirectory = ("AccurateWorldMap/blobs/blob-"..providedZoneName.."-debug.dds")
  return blobFileDirectory
end

-------------------------------------------------------------------------------
-- Hide all zone blobs (hitboxes) on the map
-------------------------------------------------------------------------------

function hideAllZoneBlobs()

  for i = 1, ZO_WorldMapContainer:GetNumChildren() do

    local childControl = ZO_WorldMapContainer:GetChild(i)
    local controlName = childControl:GetName()

    if (string.match(controlName, "blobHitbox-")) then
      childControl:SetHidden(true)
      childControl:SetMouseEnabled(false)

    end
  end
end

-------------------------------------------------------------------------------
-- Navigate map to provided map via map data object or ID
-------------------------------------------------------------------------------

local GPS = LibGPS3

function navigateToMap(mapInfo)

  local mapID

  -- mapInfo can be either an int or a zoneData object, need to determine which it is
  -- if it's a zoneData object, then it will have an id

  if (mapInfo ~= nil) then

    if (isNumeric(mapInfo)) then -- it is an int

      mapID = tonumber(mapInfo)

    else -- it is not an int

      if (mapInfo.zoneID ~= nil) then -- it is a zoneData object

        mapID = mapInfo.zoneID
  
      end

    end

    SetMapToMapId(mapID)
    GPS:SetPlayerChoseCurrentMap()
    hideAllZoneBlobs()
    CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")

    -- force map to zoom out
    local mapPanAndZoom = ZO_WorldMap_GetPanAndZoom()
    mapPanAndZoom:SetCurrentNormalizedZoom(0)
      
  end

end

-------------------------------------------------------------------------------
-- Get current zone info table if it exists
-------------------------------------------------------------------------------

function getCurrentZoneInfo()

  return getZoneInfoByID(getCurrentMapID())

end

-------------------------------------------------------------------------------
-- Update location info on the side bar
-------------------------------------------------------------------------------

function updateLocationsInfo()

  -- recalculate normalised info, as will be based on
  -- vanilla values by the time this is done
  GPS:ClearMapMeasurements()
  GPS:CalculateMapMeasurement()

  if (VOTANS_IMPROVED_LOCATIONS) then
    VOTANS_IMPROVED_LOCATIONS.mapData = nil
    WORLD_MAP_LOCATIONS:BuildLocationList()
  else
    local locations = WORLD_MAP_LOCATIONS
    locations.data.mapData = nil

    ZO_ScrollList_Clear(locations.list)
    local scrollData = ZO_ScrollList_GetDataList(locations.list)

    local mapData = locations.data:GetLocationList()

    for i,entry in ipairs(mapData) do
      scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(1, entry)
    end

    ZO_ScrollList_Commit(locations.list)

  end
end

-------------------------------------------------------------------------------
-- Get whether the current map is exclusive or not
-------------------------------------------------------------------------------

function getIsCurrentMapExclusive()

  local currentZoneInfo = getCurrentZoneInfo()

  return (currentZoneInfo ~= nil and (currentZoneInfo.isExclusive ~= nil and currentZoneInfo.isExclusive)) 

end

-------------------------------------------------------------------------------
-- Get whether the provided map has custom zone data or not
-------------------------------------------------------------------------------

function doesMapHaveCustomZoneData(mapID)

  return ((mapData[mapID] ~= nil and mapData[mapID].zoneData ~= nil) or getZoneInfoByID(mapID) ~= nil)

end

-------------------------------------------------------------------------------
-- Get whether the current map has custom zone data or not
-------------------------------------------------------------------------------

function doesCurrentMapHaveCustomZoneData()
  
  return doesMapHaveCustomZoneData(getCurrentMapID())

end

-------------------------------------------------------------------------------
-- Creates zone hitbox on the map given some coordinates
-------------------------------------------------------------------------------

function createZoneHitbox(polygonData, zoneInfo)

  local polygonID
  local isDebug


  if (zoneInfo ~= nil) then

    if (zoneInfo.isDuplicate ~= nil and zoneInfo.isDuplicate) then
      polygonID = "blobHitbox-"..zoneInfo.zoneID.."-"..zoneInfo.zoneName.."duplicate"
    else
      polygonID = "blobHitbox-"..zoneInfo.zoneID.."-"..zoneInfo.zoneName
    end

  else

    isDebug = true
    polygonID = "debugPolygon"

  end

  -- check if polygon by this name exists
  if (WINDOW_MANAGER:GetControlByName(polygonID) == nil) then


    local polygon = ZO_WorldMapContainer:CreateControl(polygonID, CT_POLYGON)
    polygon:SetAnchorFill(ZO_WorldMapContainer)

    local polygonCode = ""

    if (isDebug) then
      AWM_EditTextWindow:SetHidden(false)
    end

    for key, data in pairs(polygonData) do

      if (isDebug) then

        d(AWM.polygonData)

        polygonCode = polygonCode .. ("{ xN = "..string.format("%.03f", data.xN)..", yN = "..string.format("%.03f", data.yN).." },\n")  

      end

      polygon:AddPoint(data.xN, data.yN)
  
    end

    if (isDebug) then
      AWM_EditTextTextBox:SetText(polygonCode)
    end

  
    if (isDebug) then
      polygon:SetCenterColor(0, 1, 0, 0.5)
    else
      polygon:SetCenterColor(0, 0, 0, 0)
    end

    polygon:SetMouseEnabled(true)
    polygon:SetHandler("OnMouseDown", function(control, button, ctrl, alt, shift, command)

      if (waitForRelease == false) then
        currentMapOffsetX, currentMapOffsetY = getWorldMapOffsets()
        waitForRelease = true
      end

      AWM.currentlySelectedPolygon = polygon
      ZO_WorldMap_MouseDown(button, ctrl, alt, shift)    
    end)

    polygon:SetHandler("OnMouseUp", function(control, button, upInside, ctrl, alt, shift, command)

      ZO_WorldMap_MouseUp(control, button, upInside)


      if (AWM.blobZoneInfo ~= nil and upInside and button == MOUSE_BUTTON_INDEX_LEFT) then

        if (waitForRelease) then

          local mapOffsetX, mapOffsetY = getWorldMapOffsets()

          local deltaX, deltaY


          if (mapOffsetX >= currentMapOffsetX) then
            deltaX = mapOffsetX - currentMapOffsetX
          else 
            deltaX = currentMapOffsetX - mapOffsetX
          end

          if (mapOffsetY >= currentMapOffsetY) then
            deltaY = mapOffsetY - currentMapOffsetY
          else 
            deltaY = currentMapOffsetY - mapOffsetY
          end

          print(tostring(deltaX))

          if ( (deltaX <= 10 and deltaX <= 10) and not (shift or ctrl or alt or command) ) then

            navigateToMap(AWM.blobZoneInfo)

          end
        end
      end

      waitForRelease = false

    end)
    polygon:SetHandler("OnMouseEnter", function()

      if (not isInGamepadMode()) then
        updateCurrentPolygon(polygon)
      end
    end)
  
  else 
    -- it already exists, we just need to show it again
    WINDOW_MANAGER:GetControlByName(polygonID):SetHidden(false)
    WINDOW_MANAGER:GetControlByName(polygonID):SetMouseEnabled(true)
  end
end

-------------------------------------------------------------------------------
-- Compile map textures
-------------------------------------------------------------------------------

function compileMapTextures()

  AWM_TextureControl:SetAlpha(0)
  
  local hasError = false

  -- iterate through all of mapData
  for mapID, zoneData in pairs(mapData) do


    if (zoneData.zoneData ~= nil) then

      --print("got to here!")

      local zoneInfo = zoneData.zoneData

      for zoneIndex, zoneInfo in pairs(zoneInfo) do

        --print("checking zone info!")

        if (zoneInfo.zoneName ~= nil) then

          local hasDebugTexture = (zoneInfo.debugXN ~= nil or zoneInfo.debugBlobTexture ~= nil)

          --print("there is a zone name!")

          if ( (zoneInfo.blobTexture == nil or zoneInfo.debugBlobTexture == nil) or (zoneInfo.nBlobTextureWidth == nil or zoneInfo.nDebugBlobTextureWidth == nil) ) then

            local mapResolution = 8704

            -- load in textures

            local textureDirectory
            
            if (zoneInfo.blobTexture ~= nil) then
              textureDirectory = zoneInfo.blobTexture
            else
              textureDirectory = getFileDirectoryFromMapName(zoneInfo.zoneName)
            end

            -- load texture into control from name
            AWM_TextureControl:SetTexture(textureDirectory)

            -- check if texture exists before doing stuff
            if (AWM_TextureControl:IsTextureLoaded()) then

              -- get the dimensions
              local textureHeight, textureWidth = AWM_TextureControl:GetTextureFileDimensions()

              -- save texture name and dimensions
              mapData[mapID].zoneData[zoneIndex].blobTexture = textureDirectory
              mapData[mapID].zoneData[zoneIndex].nBlobTextureHeight = textureHeight * 2 / mapResolution
              mapData[mapID].zoneData[zoneIndex].nBlobTextureWidth = textureWidth * 2 / mapResolution

            else

              print("The following texture failed to load: "..textureDirectory)
              hasError = true

            end

            if (hasDebugTexture) then

              -- load in textures
              local debugTextureDirectory
              
              if (zoneInfo.debugBlobTexture ~= nil) then
                debugTextureDirectory = zoneInfo.debugBlobTexture
              else
                debugTextureDirectory = getDebugFileDirectoryFromMapName(zoneInfo.zoneName)
              end

              -- load texture into control from name
              AWM_TextureControl:SetTexture(debugTextureDirectory)

              -- check if texture exists before doing stuff
              if (AWM_TextureControl:IsTextureLoaded()) then

                -- get the dimensions
                local debugTextureHeight, debugTextureWidth = AWM_TextureControl:GetTextureFileDimensions()

                -- save texture name and dimensions
                mapData[mapID].zoneData[zoneIndex].debugBlobTexture = debugTextureDirectory
                mapData[mapID].zoneData[zoneIndex].nDebugBlobTextureWidth = debugTextureWidth * 2/ mapResolution
                mapData[mapID].zoneData[zoneIndex].nDebugBlobTextureHeight = debugTextureHeight * 2 / mapResolution

              else

                print("The following debug texture failed to load: "..debugTextureDirectory)
                hasError = true

              end
            end
          end
        end
      end
    end
  end

  -- if texture compilation has had no issues, then go ahead
  if (hasError == false and not AWM.areTexturesCompiled) then

    print("Finished loading.", true)
    AWM.areTexturesCompiled = true

    -- recalculate normalised info, as will be based on
    -- vanilla values by the time this is done
    GPS:ClearMapMeasurements()
    GPS:CalculateMapMeasurement()

    -- force reload map in case user has opened it
    navigateToMap(getCurrentMapID())

  end
end

function parseMapData(mapID)

  if (mapID ~= nil) then


    print("Current map id: ".. mapID)


    -- Check if the current zone/map has any custom map data set to it
    if (mapData[mapID] ~= nil) then
      
      --print("This map has custom data!")


      if (mapData[mapID].isExclusive ~= nil) then
        isExclusive = mapData[mapID].isExclusive
      else
        isExclusive = false
      end


      if (mapData[mapID].zoneData ~= nil) then
        --print("This map has custom zone data!")
        local zoneData = mapData[mapID].zoneData

        for zoneAttribute, zoneInfo in pairs(zoneData) do


          if (zoneInfo.zoneName ~= nil) then

            print(zoneInfo.zoneName)

            print(tostring(zoneAttribute))
            print(tostring(zoneInfo))

            if (zoneInfo.xN ~= nil and zoneInfo.yN ~= nil) then
              if (zoneInfo.blobTexture ~= nil and zoneInfo.nBlobTextureHeight ~= nil and zoneInfo.nBlobTextureHeight ~= nil ) then
                if (zoneInfo.zonePolygonData ~= nil) then

                  createZoneHitbox(zoneInfo.zonePolygonData, zoneInfo)

                  -- add polygons, make zone data

                else 
                  print("Warning: Custom Zone "..zoneInfo.zoneName.." ".."is missing its hitbox polygon!")
                end
              else
                print("Warning: Custom Zone "..zoneInfo.zoneName.." ".."is missing its texture details!")

                -- rerun texture details for this zone
                -- getTextureDetails() --getTextureDetails(nil)

              end
            else
              print("Warning: Custom Zone "..zoneInfo.zoneName.." ".." has invalid zone coordinates!")
            end
          else
            print("Warning: Custom Zone ID #"..tostring(zoneInfo.zoneID).." has no name!")
          end
        end
      end

    else
      isExclusive = false
    end
  end
  print("isExclusive: "..tostring(isExclusive))

end

-------------------------------------------------------------------------------
-- Get zoneInfo object by name function
-------------------------------------------------------------------------------

function getZoneInfoByName(name)

  if (mapData ~= nil) then

    for mapID, mapInfo in pairs(mapData) do

      if (mapInfo.zoneName ~= nil) then

        local zoneInfo = mapInfo.zoneData

          for zoneIndex, zoneInfo in pairs(zoneInfo) do
        
            if (zoneInfo.zoneName == name) then
              return zoneInfo
            end
          end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Is Tamriel Map function
-------------------------------------------------------------------------------

function isMapTamriel(mapID)

  if (mapID == nil) then
    mapID = getCurrentMapID()
  end

  local zoneInfo = getZoneInfoByID(mapID)

  return (zoneInfo ~= nil and zoneInfo.zoneName == "Tamriel")

end

-------------------------------------------------------------------------------
-- Is Map Artaeum function
-------------------------------------------------------------------------------

function isMapArtaeum(mapID)

  local zoneInfo = getZoneInfoByID(mapID)

  return (zoneInfo ~= nil and zoneInfo.zoneName == "Artaeum")

end

-------------------------------------------------------------------------------
-- Is Map Aurbis function
-------------------------------------------------------------------------------

function isMapAurbis(mapID)

  local zoneInfo = getZoneInfoByID(mapID)

  return (zoneInfo ~= nil and zoneInfo.zoneName == "The Aurbis")

end

-------------------------------------------------------------------------------
-- Get Aurbis map ID function
-------------------------------------------------------------------------------

function getAurbisMapID()
  return 439
end

-------------------------------------------------------------------------------
-- Get Tamriel map ID function
-------------------------------------------------------------------------------

function getTamrielMapID()
  return 27
end

-------------------------------------------------------------------------------
-- Get parent mapID function
-------------------------------------------------------------------------------

function getParentMapID(mapID)

  if (mapID == nil) then
    mapID = getCurrentMapID()
  end

  local parentMapID

  if (isGeoParentEnabled() and AWM.isLoaded) then    
    parentMapID = LZ:GetGeographicalParentMapId(mapID)
  else
    local _, _, _, zoneIndex, _ = GetMapInfoById(mapID)
    parentMapID = GetParentZoneId(GetZoneId(zoneIndex))
  end


  if (parentMapID ~= nil) then

    -- if parentMapId is zero, then return itself
    if (parentMapID == 0) then

      return mapID

    end

      -- if we have overwritten this map's parent ID, then return itself
    if (mapData[mapID] ~= nil and mapData[mapID].parentMapID ~= nil) then

      return mapID

    end

  end

  return parentMapID
end

-------------------------------------------------------------------------------
-- Check if map is inside the Aurbis map
-------------------------------------------------------------------------------

function isMapInAurbis(mapID)

  if (mapID == nil) then
    mapID = getCurrentMapID()
  end

  local parentMapID = getParentMapID(mapID)
  local isInAurbis = false

  if (isMapTamriel(parentMapID) or isMapAurbis(parentMapID)) then
    return isInAurbis
  end

  -- does this map have custom defined data
  if (doesMapHaveCustomZoneData(parentMapID)) then

    local aurbisMapData = mapData[getAurbisMapID()].zoneData

    -- then check if it's in the aurbis
    for zoneIndex, data in pairs(aurbisMapData) do

      local zoneData = mapData[getAurbisMapID()].zoneData[zoneIndex]

      if (zoneData.zoneID == parentMapID) then

        isInAurbis = true

      end
    end
  end

  return isInAurbis
end

-------------------------------------------------------------------------------
-- Get zone bounding box function
-------------------------------------------------------------------------------

function getMapBoundingBoxByID(mapID)

  mapInfo = getZoneInfoByID(mapID)

  if (mapInfo ~= nil) then

    -- does a debug anchor texture exist for this map?
    if (mapInfo.nDebugBlobTextureWidth ~= nil) then

      return mapInfo.debugXN, mapInfo.debugYN, mapInfo.nDebugBlobTextureWidth, mapInfo.nDebugBlobTextureHeight

    else

      -- else return the normal blob texture
      return mapInfo.xN, mapInfo.yN, mapInfo.nBlobTextureWidth, mapInfo.nBlobTextureHeight

    end

  end
end

-------------------------------------------------------------------------------
-- Get parent zoneID
-------------------------------------------------------------------------------

function getParentZoneID(zoneID)

  local parentZoneID
  
  if (isGeoParentEnabled()) then

    if (LZ:GetGeographicalParentMapId(mapID) ~= nil) then
      parentZoneID = LZ:GetGeographicalParentMapId(mapID)
    end

  else
    parentZoneID = GetParentZoneId(zoneID)
  end
  
  if (parentZoneID == nil or parentZoneID == 0) then
    parentZoneID = GetParentZoneId(zoneID)
  end

  return parentZoneID

end

-------------------------------------------------------------------------------
-- Get vanilla local coordinates given global ones from a certain map
-------------------------------------------------------------------------------

local TAMRIEL_VERTICAL_OFFSET = 0.14000000059605

function vanillaGlobalToLocal(mapID, globalNX, globalNY)

  -- get vanilla blob offsets and position for the provided map
  local nOffsetX, nOffsetY, nWidth, nHeight = zos_GetUniversallyNormalizedMapInfo(mapID)
  local vanillaLocalNX = (globalNX - nOffsetX) / nWidth --nWidth = scale
  local vanillaLocalNY = (globalNY - (nOffsetY + TAMRIEL_VERTICAL_OFFSET)) / nHeight -- nHeight = scale

  return vanillaLocalNX, vanillaLocalNY

end

-------------------------------------------------------------------------------
-- Get vanilla global coordinates given local ones on a certain map
-------------------------------------------------------------------------------

function vanillaLocalToGlobal(mapID, vanillaLocalNX, vanillaLocalNY)

  local nOffsetX, nOffsetY, nWidth, nHeight = zos_GetUniversallyNormalizedMapInfo(mapID)
  local globalNX = vanillaLocalNX * nWidth + nOffsetX
  local globalNY = vanillaLocalNY * nHeight + (nOffsetY + TAMRIEL_VERTICAL_OFFSET)

  return globalNX, globalNY

end

-------------------------------------------------------------------------------
-- Helper function to determine if there is a waypoint on current map
-------------------------------------------------------------------------------

function isWaypointPlaced()
  return LMP:HasMapPing(MAP_PIN_TYPE_PLAYER_WAYPOINT, "waypoint")
end

-------------------------------------------------------------------------------
-- Get modded Global to Local coordinates
-------------------------------------------------------------------------------

function getFixedLocalCoordinates(mapID, vanillaLocalNX, vanillaLocalNY)


  if (AWM.lastGlobalXN ~= nil and AWM.lastGlobalYN ~= nil) then

    -- d("last globals:")
    -- d(AWM.lastGlobalXN, AWM.lastGlobalYN)

    local measurement = GPS:GetMapMeasurementByMapId(mapID)
    if (measurement ~= nil) then

      local moddedLocalNX, moddedLocalNY = measurement:ToLocal(AWM.lastGlobalXN, AWM.lastGlobalYN)

      if (LMP:IsPositionOnMap(moddedLocalNX, moddedLocalNY)) then

        ---d(moddedLocalNX, moddedLocalNY)
        return moddedLocalNX, moddedLocalNY

      else

        return vanillaLocalNX, vanillaLocalNY

      end
    end
  end

  --d(vanillaLocalNX, vanillaLocalNY)

  -- if the incoming position is not on the map, then it is either
  -- from a modded position on the global map, or far away.
  -- either way, calcuate the modded global based on modded offsets
  if (not LMP:IsPositionOnMap(vanillaLocalNX, vanillaLocalNY)) then

    -- get vanilla global from local position
    local globalNX, globalNY = vanillaLocalToGlobal(mapID, vanillaLocalNX, vanillaLocalNY)

    -- transform that vanilla global position to modded local
    local measurement = GPS:GetMapMeasurementByMapId(mapID)
    if (measurement ~= nil) then

      local moddedLocalNX, moddedLocalNY = measurement:ToLocal(globalNX, globalNY)

      --d(moddedLocalNX, moddedLocalNY)
      return moddedLocalNX, moddedLocalNY
    end

  else

    -- we have been given local coordinates that are inside our current map, 
    -- but we can't be sure if these are modded or vanilla or not. we need
    -- to calcuate to determine which

    local unknownLocalNX = vanillaLocalNX
    local unknownLocalNY = vanillaLocalNY

    -- convert these two local ones into vanilla global and then back to
    -- vanilla local again, are they the same? then they're vanilla, and 
    -- should be changed

    -- get vanilla global from local position
    local globalNX, globalNY = vanillaLocalToGlobal(mapID, unknownLocalNX, unknownLocalNY)

    -- get vanilla local from global position

    local localNX, localNY = vanillaGlobalToLocal(mapID, globalNX, globalNY)

    if (localNX == unknownLocalNX and localNY == unknownLocalNY) then

      --d("these are vanilla coordinates")

      -- these are confirmed vanilla coordinates, so we should instead return modded ones
      -- by converting the previous global coordinates to modded local ones


      -- transform that vanilla global position to modded local
      local measurement = GPS:GetMapMeasurementByMapId(mapID)
      if (measurement ~= nil) then

        local moddedLocalNX, moddedLocalNY = measurement:ToLocal(globalNX, globalNY)

        if (LMP:IsPositionOnMap(moddedLocalNX, moddedLocalNY)) then

          --d(moddedLocalNX, moddedLocalNY)
          return moddedLocalNX, moddedLocalNY

        else

          return vanillaLocalNX, vanillaLocalNY

        end        
      end
    end

    return vanillaLocalNX, vanillaLocalNY
  end
end


-------------------------------------------------------------------------------
-- Reposition global coordinates function
-------------------------------------------------------------------------------

function getFixedGlobalCoordinates(mapID, vanillaGlobalNX, vanillaGlobalNY)

  -- get vanilla blob offsets and position for the provided map
  local nOffsetX, nOffsetY, nWidth, nHeight = zos_GetUniversallyNormalizedMapInfo(mapID)

  -- use that to get local position of marker in that map
  local vanillaLocalNX = (vanillaGlobalNX - nOffsetX) / nWidth --nWidth = scale
  local vanillaLocalNY = (vanillaGlobalNY - (nOffsetY + TAMRIEL_VERTICAL_OFFSET)) / nHeight -- nHeight = scale

  local measurement = GPS:GetMapMeasurementByMapId(mapID)
  if (measurement ~= nil) then
    -- then transform marker position inside AWM's fixed blob bounds
    local moddedGlobalNX, moddedGlobalNY = measurement:ToGlobal(vanillaLocalNX, vanillaLocalNY)

    return moddedGlobalNX, moddedGlobalNY

  end
end

-------------------------------------------------------------------------------
-- Can remove waypoint function
-------------------------------------------------------------------------------

function canRemoveWaypoint(currentXN, currentYN, lastXN, lastYN, mapID)

  if (currentXN == nil or currentYN == nil or lastXN == nil or lastYN == nil) then
    return false
  end

  if (mapID ~= getCurrentMapID()) then
    return false
  end
  
  if (lastXN >= currentXN) then
    deltaX = lastXN - currentXN
  else 
    deltaX = currentXN - lastXN
  end

  if (lastYN >= currentYN) then
    deltaY = lastYN - currentYN
  else 
    deltaY = currentYN - lastYN
  end

  local allowed_delta_amount = 0.005

  return ( ((currentXN == lastXN and currentYN == lastYN)) or ((deltaX <= allowed_delta_amount) and (deltaX <= allowed_delta_amount)) )
end