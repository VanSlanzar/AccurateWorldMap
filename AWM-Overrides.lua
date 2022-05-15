--[[===========================================================================
                        AccurateWorldMap Overrides
===============================================================================

            Vanilla/ZOS functions that AccurateWorldMap needs to override
                              in order to function.

---------------------------------------------------------------------------]]--

-------------------------------------------------------------------------------
-- ZOS WorldMap Get Map Title
-------------------------------------------------------------------------------

-- Override ESO's zone names with AccurateWorldMap's custom ones.

-------------------------------------------------------------------------------

local zos_GetMapTitle = ZO_WorldMap_GetMapTitle
ZO_WorldMap_GetMapTitle = function()
  return getZoneNameFromID(getCurrentMapID())
end

-------------------------------------------------------------------------------
-- ZOS WorldMap Zoom controller
-------------------------------------------------------------------------------

-- Override ESO's zone zoom levels with any custom defined ones.

-------------------------------------------------------------------------------

local zos_GetMapCustomMaxZoom = GetMapCustomMaxZoom
GetMapCustomMaxZoom = function()
  if (getCurrentZoneInfo() ~= nil and getCurrentZoneInfo().zoomLevel ~= nil ) then
    return getCurrentZoneInfo().zoomLevel
  else
    return zos_GetMapCustomMaxZoom()
  end
end

-------------------------------------------------------------------------------
-- ZOS WorldMap POI Icon controller
-------------------------------------------------------------------------------

-- Override ESO's zone map POI icon info with AccurateWorldMap custom data.

-------------------------------------------------------------------------------

local zos_GetPOIMapInfo = GetPOIMapInfo
GetPOIMapInfo = function(zoneIndex, poiIndex)

  local normalisedX, normalisedZ, poiPinType, icon, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered, isNearby = zos_GetPOIMapInfo(zoneIndex, poiIndex)

  if (getCurrentMapID() == 1719) then -- if we are in Western Skyrim

    if (string.match(icon, "poi_raiddungeon_")) then -- and the icon is a Trial, then remove
      isShownInCurrentMap = false
      isNearby = false
      icon = nil
    end

  end
  return normalisedX, normalisedZ, poiPinType, icon, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered, isNearby
end

-------------------------------------------------------------------------------
-- ZOS get fast travel node info function
-------------------------------------------------------------------------------

-- Controls placement, display, and location of wayshrine/dungeon/house icons.

-------------------------------------------------------------------------------

local zos_GetFastTravelNodeInfo = GetFastTravelNodeInfo    
GetFastTravelNodeInfo = function(nodeIndex)
  local known, name, normalizedX, normalizedY, icon, glowIcon, poiType, isLocatedInCurrentMap, linkedCollectibleIsLocked, disabled = zos_GetFastTravelNodeInfo(nodeIndex)

  if AccurateWorldMap.options.isDebug == true then
        d("Current Node: "..nodeIndex)
        d("Name: "..name)
        d(" ")
  end

  local mapIndex = getCurrentMapID()

  if (AccurateWorldMap.options.hideIconGlow) then
    glowIcon = nil
  end

  if (mapData[mapIndex] ~= nil and mapData[mapIndex][nodeIndex] ~= nil) then

    local zoneData = mapData[mapIndex]

    if (zoneData[nodeIndex] ~= nil) then 
      if zoneData[nodeIndex].xN ~= nil then
        normalizedX = zoneData[nodeIndex].xN
      end

      if zoneData[nodeIndex].yN ~= nil then
        normalizedY = zoneData[nodeIndex].yN
      end

      if (zoneData[nodeIndex].name ~= nil and AccurateWorldMap.options.loreRenames) then
        name = zoneData[nodeIndex].name
      end

      if zoneData[nodeIndex].disabled ~= nil then

        if (zoneData[nodeIndex].disabled) then

          isLocatedInCurrentMap = false
          disabled = true

        else

          isLocatedInCurrentMap = true
          disabled = false

        end
      end
    end

  end

  if (getCurrentZoneInfo() ~= nil and getCurrentZoneInfo().isWorldMap) then

    if (AccurateWorldMap.options.worldMapWayshrines == "None" or AccurateWorldMap.options.worldMapWayshrines == "Only Major Settlements") then

      isLocatedInCurrentMap = false
      disabled = true

    end

    if (mapData[mapIndex] ~= nil and mapData[mapIndex][nodeIndex] ~= nil) then

      if (mapData[mapIndex][nodeIndex].majorSettlement ~= nil and AccurateWorldMap.options.worldMapWayshrines == "Only Major Settlements") then

        isLocatedInCurrentMap = true
        disabled = false

      end

    end

  end

  return known, name, normalizedX, normalizedY, icon, glowIcon, poiType, isLocatedInCurrentMap, linkedCollectibleIsLocked, disabled
end

-------------------------------------------------------------------------------
-- ZOS WorldMap MouseUp event
-------------------------------------------------------------------------------

-- Override the function called when user releases a mouse button on the worldmap
-- so that we can intercept and redirect the user to a custom parent map if available

-------------------------------------------------------------------------------

ZO_PreHook("ZO_WorldMap_MouseUp", function(mapControl, mouseButton, upInside)

  if (mouseButton == MOUSE_BUTTON_INDEX_RIGHT and upInside) then
    if (mapData[getCurrentMapID()] ~= nil and mapData[getCurrentMapID()].parentMapID ~= nil) then

        navigateToMap(mapData[getCurrentMapID()].parentMapID)
        return true
        
    end
  end
end)

-------------------------------------------------------------------------------
-- ZOS Pin Tooltip Controller
-------------------------------------------------------------------------------

-- Borrowed from GuildShrines addon. Overrides default tooltip handler to adds 
-- custom tooltips to Eyevea and Earth Forge wayshrines in both gamepad and 
-- keyboard & mouse mode.

-------------------------------------------------------------------------------

ZO_MapPin.TOOLTIP_CREATORS[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE].creator = function(pin)
  local nodeIndex = pin:GetFastTravelNodeIndex()
  local _, name, _, _, _, _, _, _, _, disabled = GetFastTravelNodeInfo(nodeIndex)
  local info_tooltip

  if not isInGamepadMode() then 
    if not disabled then
      if nodeIndex ~= 215 and nodeIndex ~= 221 or ZO_Map_GetFastTravelNode() then -- Eyevea and the Earth Forge cannot be "jumped" to so we'll add "This area is not accessible via jumping." when they're not using a wayshrine
        InformationTooltip:AppendWayshrineTooltip(pin)																			-- Normal Wayshrine tooltip data
      else
        InformationTooltip:AddLine(zo_strformat(SI_WORLD_MAP_LOCATION_NAME, name), "", ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())	-- Wayshrine Name
        InformationTooltip:AddLine("This location can only be accessed via other Wayshrines.", "", 1, 0, 0)				-- "This area is not accessible via jumping."
      end	
    else
      InformationTooltip:AddLine(zo_strformat(SI_WORLD_MAP_LOCATION_NAME, name), "", ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())		-- Wayshrine Name Only (unknown wayshrine)
    end		
  else
    if not disabled then 
      if nodeIndex ~= 215 and nodeIndex ~= 221 or ZO_Map_GetFastTravelNode() then -- Eyevea and the Earth Forge cannot be "jumped" to so we'll add "This area is not accessible via jumping." when they're not using a wayshrine 
        ZO_MapLocationTooltip_Gamepad:AppendWayshrineTooltip(pin)
      else
        local lineSection = ZO_MapLocationTooltip_Gamepad.tooltip:AcquireSection(ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("mapMoreQuestsContentSection"))
        lineSection:AddLine(name, ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("mapLocationTooltipContentLabel"), ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("gamepadElderScrollTooltipContent"))									-- Wayshrine Name
        lineSection:AddLine(GetString("This location can only be accessed via other Wayshrines."), ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("mapLocationTooltipContentLabel"), ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("gamepadElderScrollTooltipContent"))	-- "This area is not accessible via jumping."
        ZO_MapLocationTooltip_Gamepad.tooltip:AddSection(lineSection)
      end
    else
      local lineSection = ZO_MapLocationTooltip_Gamepad.tooltip:AcquireSection(ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("mapMoreQuestsContentSection"))
      lineSection:AddLine(name, ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("mapLocationTooltipContentLabel"), ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("gamepadElderScrollTooltipContent")) -- Wayshrine Name Only (unknown wayshrine)
      ZO_MapLocationTooltip_Gamepad.tooltip:AddSection(lineSection)
    end
  end
end
   
