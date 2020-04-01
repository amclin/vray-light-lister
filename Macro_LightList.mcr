-- VRay Extended Light Lister
-- Modified from the original 3DSMax Light Lister by Anthony McLin
-- http://www.anthonymclin.com
-- version 1.3
-- September 1, 2006
-- Condensed Layout for more efficiency
-- Add support for Subdivisions and Shadow Bias for VRay Lights


-- version 1.2
-- August 25, 2006
-- Added support for Units Type for VRay Lights

-- version 1.1
-- August 24, 2006
-- Added checkboxes for Affect Diffuse and Affect Specular for VRay Lights
-- Removed checkbox for Smooth Shadows for VRay Lights since that feature has been dropped

-- Version 1.0
-- August 23, 2006
-- Initial support added for VRay Lights and VRay Sun now that Vray 1.5 is out


-- MODIFIED BY MARC LORENZ, Jan 02 2004
-- plugins@angstraum.at, http://plugins.angstraum.at
--
-- ADDED VRAY LIGHTS AND SHADOWS
-- UNSUPPORTED, USE AT YOUR OWN RISK!!




-- MacroScript File
-- Created:       Jan 15 2002
-- Last Modified: June 27 2003
-- Light Lister Script 2.5
-- Version: 3ds max 5
-- Author: Alexander Esppeschit Bicalho [discreet]
--***********************************************************************************************
-- MODIFY THIS AT YOUR OWN RISK

/* History

- Added Support to Mental Ray Lights and Plugin Script lights - this uses 4 functions to manage Delegate properties
- Added Support to Blur_Adv. Shadows and mental Ray shadows
- Enabled Luminaire support
- Enabled Deletion Callback
- Removed Blur Adv. Shadows from the UI (they're still in the Engine) since PF's spec calls for that
- Fixed divide by 0 on adding mr lights to the list
- Fixed an incorrect try/catch loop that would crash the script when radiosity was present
- Fixed crash on Refresh after deleting light - LLister.UIControlList not reset, contained deleted node (LAM)

*/

/*

macros.run "Lights and Cameras" "Light_list"

This Light Lister supports all new lights in 3ds max 5:

- Photometric Lights
- Skylights
- IES Sun

It also supports the new shadows types:

- Area Shadows
- Adv. Raytraced shadows

*/

/* Expanding the Light Lister -- AB Jun 20, 2002

This Light Lister does not automatically support new light or shadow plugins.

For them to be supported, you need to make several changes in the script:

-- Class Definitions

Here the classes for each light types are defined. If you want to add a new light type, add a new class entry and list the
classes in the array
In the end of the script, each class definition is scanned and generates the UI entries.
You'll also need to change the script to parse and collect all instances of your class, as is done with the current code.

-- Properties

The function CreateControls generates the dynamic rollout containing all spinners, properties, etc. 
The controls are grouped by light type and handle special cases like different parameter names for MAX lights and Photometric
lights. The On/Off checkbox is an example of how to handle a control that is tied to a property in a scene light. 
In the example below, ControlName is the control name and Property is the property you want to expose/access.

	LLister.maxLightsRC.addControl #checkbox (("ControlName" + LLister.count as string) as name) "" \
		paramStr:("checked:" + (LLister.LightIndex[LLister.count][1].Property as string) + " offset:[8,-22] width:18")
	LLister.maxLightsRC.addHandler (("ControlName" + LLister.count as string) as name) #'changed state' filter:on \
		codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].Property = state")

Notice the controls are all aligned using Offset. If you add a new control, you need to reorganize the remaining controls.

-- Exposing Shadow Plugins

Shadow plugins are harder to expose because each shadow has a different set of parameters, or even different parameter
names. The framework to expose them is similar to the one to expose the properties, but you need to create special cases
for each shadowplugin or each property.
For instance, if your shadow plugin class is myShadow and it exposes a Bias Property called myShadowBias, you'll need to
change the Bias Control and the Shadow Dropdown. In the Bias Control, you need to read the Bias value, and change the  
event so it checks for the correct class and sets the property.
In the Shadow Dropdown event, you need to set the control state and value acording to the shadow class.

In any case, make sure you keep a copy of the original Light Lister so you can come back to it in case you have problems

*/

macroScript Light_List
category:"Lights and Cameras" 
internalcategory:"Lights and Cameras" 
ButtonText:"Light Lister..."
tooltip:"Light Lister Tool" 
Icon:#("Lights",7)
SilentErrors:(Debug != True)
(

struct LightListerStruct (GlobalLightParameters, LightInspectorSetup, LightInspectorFloater, LightInspectorListRollout, ShadowPlugins, \
							ShadowPluginsName, VRayLightsList, VRaySunsList, maxLightsList, LSLightsList, SkyLightsList, SunLightsList, enableUIElements, \
							LuminairesList, maxLightsRC, CreateLightRollout, UIControlList, DeleteCallback, disableUIElements,\
							LightInspectorListRollout, LLUndoStr, count, lbcount, lightIndex, decayStrings, VRayLightUnitStrings, totalLightCount, \
							miLightsList, getLightProp, setLightProp, setShdProp, getShdProp, fnShadowClass)

global LLister
if LLister == undefined or debug == true do LLister = LightListerStruct()

-- Strings for Localization

LLister.decayStrings = #("None","Inverse","Inv. Square")
LLister.VRayLightUnitStrings = #("Default (image)", "Luminous power (lm)", "Luminance (lm/m²/sr)", "Radiant power (W)", "Radiance (W/m²/sr)")
LLister.LLUndoStr = "LightLister"

-- End Strings

-- Useful Functions

fn subtractFromArray myArray mySub =
(
	tmpArray = #()
	for i in myArray do append tmpArray i
	for i in mySub do	(
		itemNo = finditem tmpArray i
		local newArray = #()
		if itemNo != 0 do
		(
			for j in 1 to (itemNo-1) do append newArray tmpArray[j]
			for j in (itemNo+1) to tmpArray.count do append newArray tmpArray[j]
			tmpArray = newArray
		)
	)
	tmpArray
)

fn SortNodeArrayByName myArray =
(
qsort myArray (fn myname v1 v2 = (if v1.name < v2.name then 0 else 1))
myArray
)

fn copyArray array1 = for i in array1 collect i

fn disableUIElements array1 = for i in array1 do execute ("maxLightsRollout." + i as string + ".enabled = false")
LLister.disableUIElements = disableUIElements

fn getLightProp obj prop =
(
	if (isProperty obj prop) and not (isProperty obj #delegate) then
		getProperty obj prop
	else 
		if isProperty obj #delegate then 
			if isProperty obj.delegate prop then
				getProperty obj.delegate prop
			else undefined
		else undefined
)
LLister.getLightProp = getLightProp

fn setLightProp obj prop val =
(
	if (isProperty obj prop) and not (isProperty obj #delegate) then
		setProperty obj prop val
	else
		if isProperty obj #delegate then 
			if isProperty obj.delegate prop then
				setProperty obj.delegate prop val
			else undefined
		else undefined
)
LLister.setLightProp = setLightProp

fn getShdProp obj prop =
(
	if (isProperty obj #shadowGenerator) and not (isProperty obj #delegate) then
		if (isProperty obj.ShadowGenerator prop) do getProperty obj.ShadowGenerator prop
	else 
		if isProperty obj #delegate then 
			if isProperty obj.delegate #ShadowGenerator then
				if (isProperty obj.delegate.ShadowGenerator prop) do getProperty obj.delegate.ShadowGenerator prop
			else undefined
		else undefined
)
LLister.getShdProp = getShdProp

fn setShdProp obj prop val =
(
	if (isProperty obj #shadowGenerator) and not (isProperty obj #delegate) then
		if (isProperty obj.ShadowGenerator prop) do setProperty obj.ShadowGenerator prop val
	else 
		if isProperty obj #delegate then 
			if isProperty obj.delegate #ShadowGenerator then
				if (isProperty obj.delegate.ShadowGenerator prop) do setProperty obj.delegate.ShadowGenerator prop val
			else undefined
		else undefined
)
LLister.setShdProp = setShdProp

fn fnShadowClass obj = classof (LLister.getLightProp obj #shadowGenerator)
LLister.fnShadowClass = fnShadowClass

-- Collect Shadow Plugins

/* -- Removed Automatic Shadow Plugin Collection

LLister.ShadowPlugins = (subtractFromArray shadow.classes #(Missing_Shadow_Type))
qSort LLister.ShadowPlugins (fn namesort v1 v2 = if ((v1 as string)as name) > ((v2 as string)as name) then 1 else 0)
LLister.ShadowPluginsName = for i in LLister.ShadowPlugins collect i as string

*/

-- Hardcoded shadow plugins to the ones available

LLister.ShadowPlugins = #(Adv__Ray_Traced, mental_ray_Shadow_Map, Area_Shadows, shadowMap, raytraceShadow, VRayShadow)
LLister.ShadowPluginsName = #("Adv. Ray Traced", "mental_ray_Shadow_Map", "Area Shadows", "Shadow Map", "Raytrace Shadow", "VRayShadow")

/* -- uncomment if you want the Blur Shadows
LLister.ShadowPlugins = #(Adv__Ray_Traced, mental_ray_Shadow_Map, Area_Shadows, Blur_Adv__Ray_Traced, shadowMap, raytraceShadow)
LLister.ShadowPluginsName = #("Adv. Ray Traced", "mental_ray_Shadow_Map", "Area Shadows", "Blur Adv. Ray Traced","Shadow Map", "Raytrace Shadow")
*/

-- Main Function

local CreateLightRollout

fn createLightRollout myCollection selectionOnly:false =
(
	LLister.LightInspectorSetup.pbar.visible = true

	-- Class Definitions
	
	maxLights = #(#TargetDirectionallight, #targetSpot, #Directionallight, #Omnilight, #freeSpot)
	SkyLights = #(#IES_Sky, #Texture_Sky, #Skylight)
	SunLights = #(#IES_Sun) -- AB: Jun 20, 2002
	LSLights = #(#Free_Area, #Target_Area, #Free_Linear, #Free_Point, #Target_Point, #Target_Linear)
	Luminaires = #(#Luminaire)
	mrLights = #(#miAreaLight, #miAreaLightomni)
	VRayLights = #(#VRayLight)
	VRaySuns = #(#VRaySun)
	
	-- Scene parser
	
	SceneLights = MyCollection as array
	sceneMaxLights = #()
	sceneLSLights = #()
	sceneSkyLights = #()
	sceneSunLights = #()
	sceneLuminaires = #()
	scenemiLights = #()
	sceneVRayLights = #()
	sceneVRaySuns = #()
	
	for i in SceneLights do
	(
		LightClass = ((classof i) as string) as name
		if findItem MaxLights LightClass != 0 do append sceneMaxLights i
		if findItem LSLights LightClass != 0 do append sceneLSLights i
		if findItem SkyLights LightClass != 0 do append sceneSkyLights i
		if findItem SunLights LightClass != 0 do append sceneSunLights i
		if findItem Luminaires LightClass != 0 do append sceneLuminaires i
		if findItem mrLights LightClass != 0 do append scenemiLights i
		if findItem VRayLights LightClass != 0 do append sceneVRayLights i
		if findItem VRaySuns LightClass != 0 do append sceneVRaySuns i
	)
	
	-- Collect Light Instances and build array to be displayed
	
	tmpParser = #( \
		tmpsceneMaxLights = copyArray sceneMaxLights, \
		tmpscenemiLights = copyArray scenemiLights, \
		tmpsceneLSLights = copyArray sceneLSLights, \
		tmpsceneSkyLights = copyArray sceneSkyLights, \
		tmpsceneSunLights = copyArray sceneSunLights, \
		tmpsceneLuminaires = copyArray sceneLuminaires, \
		tmpsceneVRayLights = copyArray sceneVRayLights, \
		tmpsceneVRaySuns = copyArray sceneVRaySuns
	)
	
	ListParser = #( \
		LLister.maxLightsList = #(), \
		LLister.miLightsList = #(), \
		LLister.LSLightsList = #(), \
		LLister.SkyLightsList = #(), \
		LLister.SunLightsList = #(), \
		LLister.LuminairesList = #(), \
		LLister.VRayLightsList = #(), \
		LLister.VRaySunsList = #()
	)
	
	for i in 1 to tmpParser.count do
	(
		while tmpParser[i].count > 0 do
		(
			tmpNode = tmpParser[i][1].baseObject
			depends = refs.dependents tmpNode
			discard = #()
			for k in depends do if (superclassof k != light and superclassof k != helper) do append discard k
			for k in depends do 
				try
				(
					if classof k == DaylightAssemblyHead or classof k == ParamBlock2ParamBlock2 then 
						append discard k 
					else
						if k.AssemblyMember and not k.AssemblyHead and classof k.parent != DaylightAssemblyHead do append discard k
				) 
				catch()
			depends2 = subtractFromArray depends discard
			depends = SortNodeArrayByName depends2
			if depends.count > 0 do append listParser[i] depends
			tmpParser[i] = subtractFromArray tmpParser[i] (discard + depends)
		)
	)
	
	LLister.totalLightCount = 	LLister.maxLightsList.count + \
								LLister.LSLightsList.count + \
								LLister.SkyLightsList.count + \
								LLister.SunLightsList.count + \
								LLister.LuminairesList.count + \
								LLister.VRayLightsList.count + \
								LLister.VRaySunsList.count + \
								LLister.miLightsList.count
	
	-- build controls and rollouts
	
	-- MAX Lights
	
	/*
		Rollout Creator Example...
		
		rci = rolloutCreator "myRollout" "My Rollout" 
		rci.begin()
			rci.addControl #button #myButton "My Button" paramStr:"Height:60 width:70"
			rci.addHandler #myButton #pressed filter:on codeStr:"MessageBox @Isn't this cool@ title:@Wow@"
		createDialog (rci.end())
	*/
	
	LLister.maxLightsRC = rolloutCreator "maxLightsRollout" "Lights" -- Localize the 2nd string only
	LLister.maxLightsRC.begin()
  	-- print LLister.maxLightsRC.str.count
	
	LLister.maxLightsRC.addText "fn clearCheckButtons = for i in LLister.LightInspectorListRollout.controls do if classof i == checkButtonControl do if i.checked do i.checked = false\n"
	
	LLister.count = 1
	LLister.lbCount = 1
	LLister.LightIndex = #()
	LLister.UIControlList = #(#(),#())

	fn WriteTitle hasShadow:true hasDecay:false hasSize:false hasColor:true isLuminaire:false Multip:"Multiplier" isVrayLight:false isVRaySun:false = -- Localize this string
	(
		-- Start Localization
		
		local lbName
		fn lbName = 
		(
			if LLister.lbCount == undefined do LLister.lbCount = 1
			LLister.lbCount += 1
			("LB" + LLister.lbCount as string) as name
		)
		
		if isLuminaire == false do LLister.maxLightsRC.addControl #label (lbname()) "On" paramStr:"align:#left offset:[8,-3]"
                local labeloffset = if isLuminaire == false then -18 else -3
		LLister.maxLightsRC.addControl #label (lbname()) "Name" paramStr:(" align:#left offset:[28," + labelOffset as string + "]")
		LLister.maxLightsRC.addControl #label (lbname()) Multip paramStr:(" align:#left offset:[102,-18]")
		
		if hasColor do
		(
			LLister.maxLightsRC.addControl #label (lbname()) "Color" paramStr:(" align:#left offset:[160,-18]")
		)

		if hasShadow do
		(
			LLister.maxLightsRC.addControl #label (lbname()) "Shadows" paramStr:" align:#left offset:[190,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Map Size" paramStr:" align:#left offset:[332,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Bias" paramStr:" align:#left offset:[390,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Sm.Range" paramStr:" align:#left offset:[443,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Transp." paramStr:" align:#left offset:[495,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Int." paramStr:" align:#left offset:[535,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Qual." paramStr:" align:#left offset:[570,-18]"
		)
		if hasDecay do
		(
			LLister.maxLightsRC.addControl #label (lbname()) "Decay" paramStr:" align:#left offset:[612,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Start" paramStr:" align:#left offset:[690,-18]"
		)
		if hasSize do
		(
			LLister.maxLightsRC.addControl #label (lbname()) "Length" paramStr:" align:#left offset:[612,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Width" paramStr:" align:#left offset:[671,-18]"
		)
		
		-- Added for VRaySun labels:
		if isVRaySun do
		(
			LLister.maxLightsRC.addControl #label (lbname()) "Turbidity" paramStr:" align:#left offset:[160,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Ozone" paramStr:" align:#left offset:[220,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Size Multiplier" paramStr:" align:#left offset:[280,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Shadow Subdivisions" paramStr:" align:#left offset:[360,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Shadow Bias" paramStr:" align:#left offset:[480,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Photon Emit Radius" paramStr:" align:#left offset:[560,-18]"
		)
		
		-- Added for VRayLight labels:
		if isVRayLight do
		(
			LLister.maxLightsRC.addControl #label (lbname()) "Invisible" paramStr:" align:#left offset:[190,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Double" paramStr:" align:#left offset:[240,-36]"
			LLister.maxLightsRC.addControl #label (lbname()) "Sided" paramStr:" align:#left offset:[243,0]"
			LLister.maxLightsRC.addControl #label (lbname()) "No" paramStr:" align:#left offset:[297,-36]"
			LLister.maxLightsRC.addControl #label (lbname()) "Decay" paramStr:" align:#left offset:[290,0]"
			LLister.maxLightsRC.addControl #label (lbname()) "Skylight" paramStr:" align:#left offset:[330,-36]"
			LLister.maxLightsRC.addControl #label (lbname()) "Portal" paramStr:" align:#left offset:[335,0]"
			LLister.maxLightsRC.addControl #label (lbname()) "Store w/" paramStr:" align:#left offset:[380,-36]"
			LLister.maxLightsRC.addControl #label (lbname()) "IRRMap" paramStr:" align:#left offset:[380,0]"
			LLister.maxLightsRC.addControl #label (lbname()) "Affect" paramStr:" align:#left offset:[440,-36]"
			LLister.maxLightsRC.addControl #label (lbname()) "Diffuse" paramStr:" align:#left offset:[438,0]"
			LLister.maxLightsRC.addControl #label (lbname()) "Affect" paramStr:" align:#left offset:[493,-36]"
			LLister.maxLightsRC.addControl #label (lbname()) "Specular" paramStr:" align:#left offset:[486,0]"
			LLister.maxLightsRC.addControl #label (lbname()) "Units" paramStr:" align:#left offset:[540,-18]"
			LLister.maxLightsRC.addControl #label (lbname()) "Sampling" paramStr:" align:#left offset:[660,-36]"
			LLister.maxLightsRC.addControl #label (lbname()) "Subdivs" paramStr:" align:#left offset:[630,0]"
			LLister.maxLightsRC.addControl #label (lbname()) "Shdw Bias" paramStr:" align:#left offset:[688,-18]"
		)

		-- End Localization
	)
	
	fn CreateControls hasShadow:true isVRayLight:false isVRaySun:false hasDecay:false hasSize:false Multiplier:#multiplier hasColor:true ColorType:#Color isLuminaire:false = -- AB: Jun 20, 2002
	(
	
		-- Selection Checkbox
		
		local isLightSelected = false
		
		for i in LLister.LightIndex[LLister.count] where (not isLightSelected) do isLightSelected = i.isSelected
		
		LLister.UIControlList[1][LLister.count] = LLister.LightIndex[LLister.count][1]
		LLister.UIControlList[2][LLister.Count] = #()
		
		LLister.maxLightsRC.addControl #checkbutton (("LightSel" + LLister.count as string) as name) "" \
			paramStr:("checked:" + (isLightSelected as string) + " offset:[-5,-2] align:#left" +\
					" width:10 height:20 ")
		LLister.maxLightsRC.addHandler (("LightSel" + LLister.count as string) as name) #'changed state' filter:on \
			codeStr: \
			(
			"clearCheckButtons();if state then (max modify mode;select LLister.LightIndex[" + LLister.count as string + "];LightSel" + (LLister.count as string) + ".checked = true); else max select none"
			)
		
		append LLister.UIControlList[2][LLister.Count] (("LightSel" + LLister.count as string) as name)
		
		-- On/Off
		
		if isLuminaire == false do
		(
		LLister.maxLightsRC.addControl #checkbox (("LightOn" + LLister.count as string) as name) "" \
			paramStr:("checked:" + ((LLister.GetlightProp LLister.LightIndex[LLister.count][1] #on) as string) + " offset:[8,-22] width:18")
		LLister.maxLightsRC.addHandler (("LightOn" + LLister.count as string) as name) #'changed state' filter:on \
			codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #on state")
		
		append LLister.UIControlList[2][LLister.Count] (("LightOn" + LLister.count as string) as name)

		)
		
		-- Light Name
		
		local isUsingEdittextOffset = 0
		
		if LLister.LightIndex[LLister.count].count == 1 then
		(
			LLister.maxLightsRC.addControl #edittext (("LightName" + LLister.count as string) as name) "" \
				paramStr:(" text:\"" + LLister.LightIndex[LLister.count][1].name + "\" width:75 height:16 offset:[23,-21] height:21")
			LLister.maxLightsRC.addHandler (("LightName" + LLister.count as string) as name) #'entered txt' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].name = txt")

			isUsingEdittextOffset = 4
		)
		else
		(
			theNames = for j in LLister.LightIndex[LLister.count] collect j.name
			sort theNames
			namelist = "#("
			for j in 1 to theNames.count do 
				(
				append namelist ("\"" + theNames[j] + "\"")
				if j != theNames.count do append namelist ","
				)
			append namelist ")"
			LLister.maxLightsRC.addControl #dropDownList (("LightName" + LLister.count as string) as name) "" filter:on\
				paramStr:(" items:" + NameList + " width:73 offset:[27,-22] ")
		)
		
		append LLister.UIControlList[2][LLister.Count] (("LightName" + LLister.count as string) as name)
		
		-- Light Multiplier

		-- AB: Jun 20, 2002
		-- Increased Limits for the spinners from 10,000 to 1,000,000
		
		if Multiplier == #multiplier then
		(
			
			LLister.maxLightsRC.addControl #spinner (("LightMult" + LLister.count as string) as name) "" \
				paramStr:("range:[-1000000,1000000," + (LLister.getLightProp LLister.LightIndex[LLister.count][1] #multiplier) as string + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[100," + (isUsingEdittextOffset-24) as string + "] enabled:" + \
				((if isProperty LLister.LightIndex[LLister.count][1] #multiplier then \
				if LLister.LightIndex[LLister.count][1].multiplier.controller != undefined then \
				LLister.LightIndex[LLister.count][1].multiplier.controller.keys.count >= 0 else true \
				else try(if isProperty LLister.LightIndex[LLister.count][1].delegate #multiplier then \
				if LLister.LightIndex[LLister.count][1].delegate.multiplier.controller != undefined then \
				LLister.LightIndex[LLister.count][1].delegate.multiplier.controller.keys.count >= 0 else true) catch(true)\
				) as string))
			LLister.maxLightsRC.addHandler (("LightMult" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #multiplier val")
		)
		else if Multiplier == #intensity then
		(
			LLister.maxLightsRC.addControl #spinner (("LightMult" + LLister.count as string) as name) "" \
				paramStr:("range:[-1000000,1000000," + (LLister.LightIndex[LLister.count][1].intensity as string) + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[100," + (isUsingEdittextOffset-24) as string + "] enabled:" + \
				((if isProperty LLister.LightIndex[LLister.count][1] #intensity then \
				if LLister.LightIndex[LLister.count][1].intensity.controller != undefined then \
				LLister.LightIndex[LLister.count][1].intensity.controller.keys.count >= 0 else true \
				else try(if isProperty LLister.LightIndex[LLister.count][1].delegate #intensity then \
				if LLister.LightIndex[LLister.count][1].delegate.intensity.controller != undefined then \
				LLister.LightIndex[LLister.count][1].delegate.intensity.controller.keys.count >= 0 else true) catch(true)\
				) as string))
			LLister.maxLightsRC.addHandler (("LightMult" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #intensity val")
		)
		else if Multiplier == #dimmer then
		(
			LLister.maxLightsRC.addControl #spinner (("LightMult" + LLister.count as string) as name) "" \
				paramStr:("range:[-1000000,1000000," + (LLister.LightIndex[LLister.count][1].dimmer as string) + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[100," + (isUsingEdittextOffset-24) as string + "]")
			LLister.maxLightsRC.addHandler (("LightMult" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].dimmer = val")
		)
		
		append LLister.UIControlList[2][LLister.Count] (("LightMult" + LLister.count as string) as name)
		
		
		-- AMc: Aug 24, 2006
		-- Extended ColorType to account for lights that don't have color settings, such as VRay Sun
		if hasColor do
		(
			-- Light Color
			
			-- AB: Jun 20, 2002
			-- Added ColorType parameter to the function, so I can call FilterColor for Photometric Lights
			
			if ColorType != #FilterColor then
			(
				LLister.maxLightsRC.addControl #colorpicker (("LightCol" + LLister.count as string) as name) "" \
					paramStr:("color:" + (LLister.getLightProp LLister.LightIndex[LLister.count][1] #color) as string + \
					" offset:[158,-23] width:25")
				LLister.maxLightsRC.addHandler (("LightCol" + LLister.count as string) as name) #'changed val' filter:on \
					codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #color val")
			)
			else
			(
				LLister.maxLightsRC.addControl #colorpicker (("LightCol" + LLister.count as string) as name) "" \
					paramStr:("color:" + (LLister.getLightProp LLister.LightIndex[LLister.count][1] #filterColor) as string + \
					" offset:[158,-23] width:25")
				LLister.maxLightsRC.addHandler (("LightCol" + LLister.count as string) as name) #'changed val' filter:on \
					codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #filterColor val")
			)
			
			append LLister.UIControlList[2][LLister.Count] (("LightCol" + LLister.count as string) as name)
		)
		
		if hasShadow do
		(
		
			-- Shadow On/Off
			
			LLister.maxLightsRC.addControl #checkbox (("LightShdOn" + LLister.count as string) as name) "" \
				paramStr:("checked:" + (LLister.getLightProp LLister.LightIndex[LLister.count][1].baseObject #castshadows as string)+ " offset:[190,-22] width:15")
			LLister.maxLightsRC.addHandler (("LightShdOn" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1].baseobject #castshadows state")
			
			append LLister.UIControlList[2][LLister.Count] (("LightShdOn" + LLister.count as string) as name)
			
			-- Shadow Plugin
			
			local LLshadowClass = LLister.fnShadowClass LLister.LightIndex[LLister.count][1]
			local LLshadowGen = (LLister.getLightProp LLister.LightIndex[LLister.count][1] #shadowGenerator)

			
			LLister.maxLightsRC.addControl #dropDownList (("LightShd" + LLister.count as string) as name) "" filter:on\
				paramStr:(" items:" + LLister.ShadowPluginsName as string + " width:120 offset:[210,-24]" + \
				"selection:(finditem LLister.ShadowPlugins (LLister.fnShadowClass LLister.LightIndex[" + LLister.count as string + "][1]))")
	
			append LLister.UIControlList[2][LLister.Count] (("LightShd" + LLister.count as string) as name)
	
			-- Light Map Size
			
			local mapSizeTmp = 512
			
			if LLshadowClass == shadowMap do 
				mapSizeTmp = LLshadowGen.mapSize
			
			LLister.maxLightsRC.addControl #spinner (("LightMapSiz" + LLister.count as string) as name) "" \
				paramStr:("range:[0,10000," + (mapSizeTmp as string) + "] type:#integer " + \
				"fieldwidth:45 align:#left offset:[330,-24] enabled:" \
				+ (LLshadowClass == shadowMap or LLShadowClass == mental_ray_shadow_map) as string)
			LLister.maxLightsRC.addHandler (("LightMapSiz" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.setShdProp LLister.LightIndex[" + LLister.count as string + "][1] #mapSize val")
	
			append LLister.UIControlList[2][LLister.Count] (("LightMapSiz" + LLister.count as string) as name)
			
			-- Light Bias
			
			local BiasTmp = \
				case classof LLshadowClass of
				(
					shadowMap:				LLShadowGen.mapBias
					raytraceShadow:			LLShadowGen.raytraceBias
					Area_Shadows:			LLShadowGen.ray_Bias
					Adv__Ray_Traced:		LLShadowGen.ray_Bias
					Blur_Adv__Ray_Traced:	LLShadowGen.ray_Bias
					VRayShadow:				LLShadowGen.bias
					default:			1.0
				)

			LLister.maxLightsRC.addControl #spinner (("LightBias" + LLister.count as string) as name) "" \
				paramStr:("range:[0,10000," + (BiasTmp as string) + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[388,-21] enabled:" \
				+ (LLShadowClass == shadowMap or LLShadowClass == raytraceShadow or LLShadowClass == Blur_Adv__Ray_Traced or\
				LLShadowClass == Area_Shadows or LLShadowClass == Adv__Ray_Traced or LLShadowClass == VRayShadow) as string)
			LLister.maxLightsRC.addHandler (("LightBias" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr: \
				(
				"local propname = case (LLister.fnShadowClass LLister.LightIndex[" + LLister.count as string + "][1]) of\n" + \
				"(VRayShadow:#bias; shadowMap:#mapbias; raytraceShadow:#raytraceBias; Area_Shadows:#ray_bias; Adv__Ray_Traced:#ray_bias; Blur_Adv__Ray_Traced:#ray_bias;default:0)\n" + \
				"if propname != 0 do LLister.SetShdProp LLister.LightIndex[" + LLister.count as string + "][1] propName val"
				)

			append LLister.UIControlList[2][LLister.Count] (("LightBias" + LLister.count as string) as name)
	
			-- Light Sample Range
			
			local smpRangeTmp = 4.0
			
			if LLShadowClass == shadowMap or LLShadowClass == mental_ray_Shadow_Map do 
				smpRangeTmp = LLShadowGen.samplerange
			
			LLister.maxLightsRC.addControl #spinner (("LightSmpRange" + LLister.count as string) as name) "" \
				paramStr:("range:[0,50," + (smpRangeTmp as string) + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[446,-21] enabled:" + (LLShadowClass == shadowMap or LLShadowClass == mental_ray_shadow_map) as string)
			LLister.maxLightsRC.addHandler (("LightSmpRange" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetShdProp LLister.LightIndex[" + LLister.count as string + "][1] #samplerange val")
	
			append LLister.UIControlList[2][LLister.Count] (("LightSmpRange" + LLister.count as string) as name)
	
			-- Transparency On/Off
			
			LLister.maxLightsRC.addControl #checkbox (("LightTrans" + LLister.count as string) as name) "" \
				paramStr:("checked:" + \
						((if LLShadowClass == Area_Shadows or LLShadowClass == Adv__Ray_Traced or LLShadowClass == Blur_Adv__Ray_Traced then \
						LLShadowGen.shadow_Transparent else false) as string) + \
						" offset:[508,-20] width:15 enabled:" + \
						((LLShadowClass == Area_Shadows or LLShadowClass == Adv__Ray_Traced or LLShadowClass == Blur_Adv__Ray_Traced) as string))
			LLister.maxLightsRC.addHandler (("LightTrans" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.setShdProp LLister.LightIndex[" + LLister.count as string + "][1] #shadow_Transparent state")
	
			append LLister.UIControlList[2][LLister.Count] (("LightTrans" + LLister.count as string) as name)
	
			-- Integrity
			
			LLister.maxLightsRC.addControl #spinner (("LightInteg" + LLister.count as string) as name) "" \
				paramStr:("type:#integer fieldwidth:30 align:#left range:[1,15," + \
						((if LLShadowClass == Area_Shadows or LLShadowClass == Blur_Adv__Ray_Traced or\
						LLShadowClass == Adv__Ray_Traced then \
						LLShadowGen.pass1 else 1) as string) + \
						"] offset:[525,-21] width:15 enabled:" + \
						((LLShadowClass == Area_Shadows or LLShadowClass == Blur_Adv__Ray_Traced or\
						LLShadowClass == Adv__Ray_Traced) as string))
			LLister.maxLightsRC.addHandler (("LightInteg" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.setShdProp LLister.LightIndex[" + LLister.count as string + "][1] #pass1 val")
	
			append LLister.UIControlList[2][LLister.Count] (("LightInteg" + LLister.count as string) as name)
	
			-- Quality
			
			LLister.maxLightsRC.addControl #spinner (("LightQual" + LLister.count as string) as name) "" \
				paramStr:("type:#integer fieldwidth:30 align:#left range:[1,15," + \
						((if LLShadowClass == Area_Shadows or LLShadowClass == Blur_Adv__Ray_Traced or \
						LLShadowClass == Adv__Ray_Traced then \
						LLShadowGen.pass2 else 2) as string) + \
						"] offset:[568,-21] width:15 enabled:" + \
						((LLShadowClass == Area_Shadows or LLShadowClass == Blur_Adv__Ray_Traced or \
						LLShadowClass == Adv__Ray_Traced) as string))
			LLister.maxLightsRC.addHandler (("LightQual" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.setShdProp LLister.LightIndex[" + LLister.count as string + "][1] #pass2 val")
			
			append LLister.UIControlList[2][LLister.Count] (("LightQual" + LLister.count as string) as name)
			
			-- Shadow Plugin dropdown handler
	
			LLister.maxLightsRC.addHandler (("LightShd" + LLister.count as string) as name) #'selected i' filter:on \
				codeStr:(\
					"LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #shadowGenerator (LLister.ShadowPlugins[i]());" + \
					"local shdClass = LLister.fnShadowClass LLister.LightIndex[" + LLister.count as string + "][1]\n" + \
					"LightMapSiz" + LLister.count as string + ".enabled = LightSmpRange" + LLister.count as string + ".enabled = (shdClass == shadowMap or shdClass == mental_ray_shadow_map)\n" + \
					"LightTrans" + LLister.count as string + ".enabled = LightInteg" + LLister.count as string + ".enabled = LightQual" + LLister.count as string + ".enabled = " + \
					"shdClass == Adv__Ray_Traced or shdClass == Blur_Adv__Ray_Traced or shdClass == Area_Shadows\n" + \
					"LightBias" + LLister.count as string + ".enabled = (shdClass == Area_Shadows or shdClass == shadowMap or " + \
					"shdClass == Blur_Adv__Ray_Traced or shdClass == VRayShadow or shdClass == raytraceShadow or shdClass ==  Adv__Ray_Traced)\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #mapSize) != undefined do LightMapSiz" + \
						LLister.count as string + ".value = val\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #sampleRange) != undefined do LightSmpRange" + \
						LLister.count as string + ".value = val\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #pass1) != undefined do LightInteg" + \
						LLister.count as string + ".value = val\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #pass2) != undefined do LightQual" + \
						LLister.count as string + ".value = val\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #mapBias) != undefined do LightBias" + \
						LLister.count as string + ".value = val\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #Bias) != undefined do LightBias" + \
						LLister.count as string + ".value = val\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #ray_Bias) != undefined do LightBias" + \
						LLister.count as string + ".value = val\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #raytraceBias) != undefined do LightBias" + \
						LLister.count as string + ".value = val\n" + \
					"if (val = LLister.getShdProp LLister.LightIndex[" + LLister.count as string + "][1] #shadow_Transparent) != undefined do LightTrans" + \
						LLister.count as string + ".checked = val"
					)
		) -- end has Shadow

		
		if isVRayLight do
		(
		
			-- Invisible checker
			LLister.maxLightsRC.addControl #checkbox (("Invisible" + LLister.count as string) as name) "" \
				paramStr:(" checked:" + (LLister.LightIndex[LLister.count][1].invisible as string) + " offset:[200,-21]")
				
			LLister.maxLightsRC.addHandler (("Invisible" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].invisible = state")

			--  Double-Sided checker
			LLister.maxLightsRC.addControl #checkbox (("DoubleSided" + LLister.count as string) as name) "" \
				paramStr:(" checked:" + (LLister.LightIndex[LLister.count][1].doubleSided as string) + " offset:[250,-20]")
				
			LLister.maxLightsRC.addHandler (("DoubleSided" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].doubleSided = state")
	
			-- No decay checker
			LLister.maxLightsRC.addControl #checkbox (("NoDecay" + LLister.count as string) as name) "" \
				paramStr:(" checked:" + (LLister.LightIndex[LLister.count][1].noDecay as string) + " offset:[298,-20]")
				
			LLister.maxLightsRC.addHandler (("NoDecay" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].noDecay = state")
				
			-- Skylight Portal checker
			LLister.maxLightsRC.addControl #checkbox (("SkylightPortal" + LLister.count as string) as name) "" \
				paramStr:(" checked:" + (LLister.LightIndex[LLister.count][1].SkylightPortal as string) + " offset:[343,-20]")
				
			LLister.maxLightsRC.addHandler (("SkylightPortal" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].SkylightPortal = state")

			-- Store with Irridiance Map checker
			LLister.maxLightsRC.addControl #checkbox (("storeWithIrradMap" + LLister.count as string) as name) "" \
				paramStr:(" checked:" + (LLister.LightIndex[LLister.count][1].storeWithIrradMap as string) + " offset:[392,-20]")
				
			LLister.maxLightsRC.addHandler (("storeWithIrradMap" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].storeWithIrradMap = state")
			
			-- Affect Diffuse checker
			LLister.maxLightsRC.addControl #checkbox (("affectDiffuse" + LLister.count as string) as name) "" \
				paramStr:(" checked:" + (LLister.LightIndex[LLister.count][1].affect_diffuse as string) + " offset:[447,-20]")
				
			LLister.maxLightsRC.addHandler (("affectDiffuse" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].affect_diffuse = state")
			
			-- Affect Specular checker
			LLister.maxLightsRC.addControl #checkbox (("affectSpecular" + LLister.count as string) as name) "" \
				paramStr:(" checked:" + (LLister.LightIndex[LLister.count][1].affect_specular as string) + " offset:[500,-20]")
				
			LLister.maxLightsRC.addHandler (("affectSpecular" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].affect_specular = state")
				
				
			
			-- Units Type Selecter
			LLister.maxLightsRC.addControl #dropDownList (("VRayLightUnitsType" + LLister.count as string) as name) "" filter:on\
				paramStr:(" items:" + LLister.VRayLightUnitStrings as string + "width:80 offset:[540,-21]" +\
				"selection:((LLister.getLightProp LLister.LightIndex[" + LLister.count as string + "][1] #normalizeColor) + 1)")
			LLister.maxLightsRC.addHandler (("VRayLightUnitsType" + LLister.count as string) as name) #'selected i' filter:on \
				codeStr:(\
					"LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #normalizeColor (i-1) \n" +\
					"if (val = LLister.getLightProp LLister.LightIndex[" + LLister.count as string + "][1] #multiplier) != undefined do LightMult" + \
						LLister.count as string + ".value = val\n")
				
			append LLister.UIControlList[2][LLister.Count] (("VRayLightUnitsType" + LLister.count as string) as name)
				

			-- Subdivisions Spinner
			LLister.maxLightsRC.addControl #spinner (("VRayLightSubdivisions" + LLister.count as string) as name) ""\
				paramStr:("range:[1,1000," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #subdivs) as string) + "] type:#integer " + \
				"fieldwidth:45 align:#left offset:[625,-25]")

			LLister.maxLightsRC.addHandler (("VRayLightSubdivisions" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetLightProp LLister.LightIndex[" + LLister.count as string + "][1] #subdivs val ")
			append LLister.UIControlList[2][LLister.Count] (("VRayLightSubdivisions" + LLister.count as string) as name)

			-- Shadow Bias Spinner
			LLister.maxLightsRC.addControl #spinner (("VRayLightShadowBias" + LLister.count as string) as name) ""\
				paramStr:("range:[-100000,100000," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #ShadowBias) as string) + "] type:#WorldUnits " + \
				"fieldwidth:45 align:#left offset:[685,-21]")

			LLister.maxLightsRC.addHandler (("VRayLightShadowBias" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetLightProp LLister.LightIndex[" + LLister.count as string + "][1] #ShadowBias val ")
			append LLister.UIControlList[2][LLister.Count] (("VRayLightShadowBias" + LLister.count as string) as name)






			

		)
		
		if isVRaySun do
		(
			-- On/Off checkbox, in VRay sun it's "enabled" instead of the usual "on"... so we mark it as a Luminare and generate the checkbox here
		
			LLister.maxLightsRC.addControl #checkbox (("LightOn" + LLister.count as string) as name) "" \
				paramStr:("checked:" + ((LLister.GetlightProp LLister.LightIndex[LLister.count][1] #enabled) as string) + " offset:[8,-22] width:18")
			LLister.maxLightsRC.addHandler (("LightOn" + LLister.count as string) as name) #'changed state' filter:on \
				codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #enabled state")
		
			append LLister.UIControlList[2][LLister.Count] (("LightOn" + LLister.count as string) as name)


			-- Intensity, again VRay sun uses "intensity_multiplier" instead of "intensity" or "multiplier"... so we handle it differently		
			LLister.maxLightsRC.addControl #spinner (("LightMult" + LLister.count as string) as name) "" \
				paramStr:("range:[0,1000000," + (LLister.getLightProp LLister.LightIndex[LLister.count][1] #intensity_multiplier) as string + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[100,-21] enabled:" + \
				((if isProperty LLister.LightIndex[LLister.count][1] #intensity_multiplier then \
				if LLister.LightIndex[LLister.count][1].intensity_multiplier.controller != undefined then \
				LLister.LightIndex[LLister.count][1].intensity_multiplier.controller.keys.count >= 0 else true \
				else try(if isProperty LLister.LightIndex[LLister.count][1].delegate #intensity_multiplier then \
				if LLister.LightIndex[LLister.count][1].delegate.intensity_multiplier.controller != undefined then \
				LLister.LightIndex[LLister.count][1].delegate.intensity_multiplier.controller.keys.count >= 0 else true) catch(true)\
				) as string))
			LLister.maxLightsRC.addHandler (("LightMult" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #intensity_multiplier val")




			-- Turbidity selection
			LLister.maxLightsRC.addControl #spinner (("SunTurbidity" + LLister.count as string) as name) ""\
				paramStr:("range:[2,20," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #turbidity) as string) + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[158,-21]")

			LLister.maxLightsRC.addHandler (("SunTurbidity" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetLightProp LLister.LightIndex[" + LLister.count as string + "][1] #turbidity val ")
			append LLister.UIControlList[2][LLister.Count] (("SunTurbidity" + LLister.count as string) as name)
			
			
			-- Ozone selection
			LLister.maxLightsRC.addControl #spinner (("SunOzone" + LLister.count as string) as name) ""\
				paramStr:("range:[0,1," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #ozone) as string) + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[218,-21]")

			LLister.maxLightsRC.addHandler (("SunOzone" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetLightProp LLister.LightIndex[" + LLister.count as string + "][1] #ozone val ")
			append LLister.UIControlList[2][LLister.Count] (("SunOzone" + LLister.count as string) as name)
			
			-- Size Multiplier selection
			LLister.maxLightsRC.addControl #spinner (("SunSize" + LLister.count as string) as name) ""\
				paramStr:("range:[0,100000," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #size_multiplier) as string) + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[280,-21]")

			LLister.maxLightsRC.addHandler (("SunSize" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetLightProp LLister.LightIndex[" + LLister.count as string + "][1] #size_multiplier val ")
			append LLister.UIControlList[2][LLister.Count] (("SunSize" + LLister.count as string) as name)
			
			-- Shadow Subdivisions Selection
			LLister.maxLightsRC.addControl #spinner (("SunShadowSubdivs" + LLister.count as string) as name) ""\
				paramStr:("range:[1,1000," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #shadow_subdivs) as string) + "] type:#integer " + \
				"fieldwidth:45 align:#left offset:[360,-21]")

			LLister.maxLightsRC.addHandler (("SunShadowSubdivs" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetLightProp LLister.LightIndex[" + LLister.count as string + "][1] #shadow_subdivs val ")
			append LLister.UIControlList[2][LLister.Count] (("SunShadowSubdivs" + LLister.count as string) as name)

			-- Shadow Bias Selection
			LLister.maxLightsRC.addControl #spinner (("SunShadowBias" + LLister.count as string) as name) ""\
				paramStr:("range:[-100000,100000," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #shadow_bias) as string) + "] type:#worldunits " + \
				"fieldwidth:45 align:#left offset:[480,-21]")

			LLister.maxLightsRC.addHandler (("SunShadowBias" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetLightProp LLister.LightIndex[" + LLister.count as string + "][1] #shadow_bias val ")
			append LLister.UIControlList[2][LLister.Count] (("SunShadowBias" + LLister.count as string) as name)
			
			-- Photon Emit Radius Selection
			LLister.maxLightsRC.addControl #spinner (("SunPhotonEmitRadius" + LLister.count as string) as name) ""\
				paramStr:("range:[0,100000," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #photon_emit_radius) as string) + "] type:#worldunits " + \
				"fieldwidth:45 align:#left offset:[560,-21]")

			LLister.maxLightsRC.addHandler (("SunPhotonEmitRadius" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.SetLightProp LLister.LightIndex[" + LLister.count as string + "][1] #photon_emit_radius val ")
			append LLister.UIControlList[2][LLister.Count] (("SunPhotonEmitRadius" + LLister.count as string) as name)
		)



		
		if hasDecay do
		(
	
			-- Decay selection
			
			LLister.maxLightsRC.addControl #dropDownList (("LightDecay" + LLister.count as string) as name) "" filter:on\
				paramStr:(" items:" + LLister.decayStrings as string + " width:80 offset:[612,-24]" + \
				"selection:(LLister.getLightProp LLister.LightIndex[" + LLister.count as string + "][1] #attenDecay)")
			LLister.maxLightsRC.addHandler (("LightDecay" + LLister.count as string) as name) #'selected i' filter:on \
				codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #attenDecay i")
	
			append LLister.UIControlList[2][LLister.Count] (("LightDecay" + LLister.count as string) as name)
			

			-- Decay Start
			
			LLister.maxLightsRC.addControl #spinner (("LightDecStart" + LLister.count as string) as name) "" \
				paramStr:("range:[0,10000," + ((LLister.getLightProp LLister.LightIndex[LLister.count][1] #decayRadius) as string) + "] type:#float " + \
				"fieldwidth:45 align:#left offset:[690,-24]")
			LLister.maxLightsRC.addHandler (("LightDecStart" + LLister.count as string) as name) #'changed val' filter:on \
				codeStr:("LLister.setLightProp LLister.LightIndex[" + LLister.count as string + "][1] #decayRadius val")
		
			append LLister.UIControlList[2][LLister.Count] (("LightDecStart" + LLister.count as string) as name)
		) -- end hasDecay
		
		if hasSize do
		(
				-- Light Length
				
				LLister.maxLightsRC.addControl #spinner (("LSLightLength" + LLister.count as string) as name) "" \
					paramStr:("range:[0,100000," + (LLister.LightIndex[LLister.count][1].light_length as string) + "] type:#float " + \
					"fieldwidth:45 align:#left offset:[610,-21] enabled:" \
					+ ((LLister.LightIndex[LLister.count][1].type != #free_point and LLister.LightIndex[LLister.count][1].type != #target_point) as string))
				LLister.maxLightsRC.addHandler (("LSLightLength" + LLister.count as string) as name) #'changed val' filter:on \
					codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].light_length = val")
	
				append LLister.UIControlList[2][LLister.Count] (("LSLightLength" + LLister.count as string) as name)
				
				-- Light Width
				
				LLister.maxLightsRC.addControl #spinner (("LSLightWidth" + LLister.count as string) as name) "" \
					paramStr:("range:[0,100000," + (LLister.LightIndex[LLister.count][1].light_Width as string) + "] type:#float " + \
					"fieldwidth:45 align:#left offset:[669,-21] enabled:" \
					+ ((LLister.LightIndex[LLister.count][1].type != #free_point and LLister.LightIndex[LLister.count][1].type != #target_point) as string))
				LLister.maxLightsRC.addHandler (("LSLightWidth" + LLister.count as string) as name) #'changed val' filter:on \
					codeStr:("LLister.LightIndex[" + LLister.count as string + "][1].light_Width = val")
	
				append LLister.UIControlList[2][LLister.Count] (("LSLightWidth" + LLister.count as string) as name)
	
		)
		
		if heapFree < 1000000 do heapsize += 1000000 -- AB Jun 20, 2002
		
	) -- end CreateControls
	
	local CanAddControls = true
	local LightCountLimit = 150 -- this sets the maximum number of lights displayed
	
	if LLister.VRayLightsList.count > 0 do
	(
		
		-- Start Localization
		
		LLister.MaxLightsRC.addControl #label #VRayLighttitle "VRay Lights" paramStr:" align:#left"

		WriteTitle hasShadow:false hasDecay:false hasSize:false Multip:"Multiplier" isVrayLight:true
		
		-- End Localization

		for x in 1 to LLister.VRayLightsList.count where (CanAddControls = LLister.count < LightCountLimit) do
		(
		append LLister.LightIndex LLister.VRayLightsList[x]
		createControls hasShadow:false hasDecay:false isVRayLight:true
		LLister.count += 1
		LLister.LightInspectorSetup.pbar.value = LLister.count*100/LLister.totalLightCount
		
		) -- end For i in VRayLights
		
	) -- end VRayLights

	if LLister.VRaySunsList.count > 0 do
	(
		
		-- Start Localization
		
		LLister.MaxLightsRC.addControl #label #VRaySuntitle "VRay Suns" paramStr:" align:#left"

		WriteTitle hasShadow:false hasDecay:false hasColor:false hasSize:false Multip:"Intensity" isVRaySun:true
		
		-- End Localization

		for x in 1 to LLister.VRaySunsList.count where (CanAddControls = LLister.count < LightCountLimit) do
		(
		append LLister.LightIndex LLister.VRaySunsList[x]
		createControls hasShadow:false isVRayLight:false isVRaySun:true hasDecay:false hasSize:false hasColor:false Multiplier:#intensity_multiplier isLuminaire:true
		LLister.count += 1
		LLister.LightInspectorSetup.pbar.value = LLister.count*100/LLister.totalLightCount
		
		) -- end For i in VRaySuns
		
	) -- end VRaySuns
	
	
	if LLister.maxLightsList.count > 0 do
	(
		
		-- Start Localization
		
		LLister.maxLightsRC.addControl #label #title "Standard Lights" paramStr:" align:#left"

		WriteTitle hasShadow:true hasDecay:true hasSize:false Multip:"Multiplier"
		
		-- End Localization

		for x in 1 to LLister.maxLightsList.count where (CanAddControls = LLister.count < LightCountLimit) do
		(
		
		append LLister.LightIndex LLister.maxLightsList[x]
		createControls hasShadow:true hasDecay:true
		LLister.count += 1
		LLister.LightInspectorSetup.pbar.value = LLister.count*100/LLister.totalLightCount

		) -- end For i in MAXLights
		
	) -- end MAXLights
	
	if LLister.LSLightsList.count > 0 and CanAddControls do -- AB: Jun 20, 2002
	(
		
		-- Start Localization
		
		LLister.maxLightsRC.addControl #label #LStitle "Photometric Lights" paramStr:" align:#left"

		WriteTitle hasShadow:true hasDecay:false hasSize:true Multip:"Intensity(cd)"
		
		-- End Localization

		for x in 1 to LLister.LSLightsList.count where (CanAddControls = LLister.count < LightCountLimit) do
		(
		append LLister.LightIndex LLister.LSLightsList[x]
		createControls hasShadow:true hasDecay:false hasSize:true Multiplier:#intensity colorType:#FilterColor
		LLister.count += 1
		LLister.LightInspectorSetup.pbar.value = LLister.count*100/LLister.totalLightCount
		) -- end For i in LS Lights

		
	) -- end if LS Lights

	if LLister.miLightsList.count > 0 and CanAddControls do -- AB: Jun 20, 2002
	(
		-- Start Localization
		
		LLister.maxLightsRC.addControl #label #miLightstitle "mental ray Area Lights" paramStr:" align:#left"
		WriteTitle hasShadow:true hasDecay:false hasSize:false Multip:"Multip." isLuminaire:false
		-- End Localization

		for x in 1 to LLister.miLightsList.count  where (CanAddControls = LLister.count < LightCountLimit) do
		(
		append LLister.LightIndex LLister.miLightsList[x]
		createControls hasShadow:true hasDecay:true hasSize:false
		LLister.count += 1
		LLister.LightInspectorSetup.pbar.value = LLister.count*100/LLister.totalLightCount
		) -- end For i in miLightsList
		
	) -- end miLightsList

	if LLister.LuminairesList.count > 0 and CanAddControls do -- AB: Jun 20, 2002
	(
		
		-- Start Localization
		
		LLister.maxLightsRC.addControl #label #Luminairetitle "Luminaires" paramStr:" align:#left"

		WriteTitle hasDecay:false hasSize:false Multip:"Dimmer" hasShadow:false isLuminaire:true
		
		-- End Localization

		for x in 1 to LLister.LuminairesList.count  where (CanAddControls = LLister.count < LightCountLimit) do
		(
		append LLister.LightIndex LLister.LuminairesList[x]
		createControls hasShadow:false hasDecay:false hasSize:false Multiplier:#dimmer colorType:#FilterColor isLuminaire:true
		LLister.count += 1
		LLister.LightInspectorSetup.pbar.value = LLister.count*100/LLister.totalLightCount
		) -- end For i in LS Lights
		
	) -- end Luminaires

	if LLister.SunLightsList.count > 0 and CanAddControls do
	(

		-- Start Localization
		
		LLister.maxLightsRC.addControl #label #Suntitle "Sun Lights" paramStr:" align:#left"

		WriteTitle hasShadow:true hasDecay:false hasSize:false Multip:"Intensity(lux)"

		-- End Localization

		for x in 1 to LLister.SunLightsList.count where (CanAddControls = LLister.count < LightCountLimit) do
		(
		append LLister.LightIndex LLister.SunLightsList[x]
		createControls hasShadow:true hasDecay:false hasSize:false
		LLister.count += 1
		LLister.LightInspectorSetup.pbar.value = LLister.count*100/LLister.totalLightCount
		) -- end For i in Sun Lights

		
	)


	if LLister.SkyLightsList.count > 0 and CanAddControls do
	(
		
		-- Start Localization
		
		LLister.maxLightsRC.addControl #label #Skytitle "Sky Lights" paramStr:" align:#left"

		WriteTitle hasShadow:false hasDecay:false hasSize:false Multip:"Multiplier"

		-- End Localization

		for x in 1 to LLister.SkyLightsList.count where (CanAddControls = LLister.count < LightCountLimit) do
		(
		append LLister.LightIndex LLister.SkyLightsList[x]
		createControls hasShadow:false hasDecay:false hasSize:false
		LLister.count += 1
		LLister.LightInspectorSetup.pbar.value = LLister.count*100/LLister.totalLightCount
		) -- end For i in Sky Lights
	)
	
	-- Callback Handlers

	LLister.maxLightsRC.addHandler "maxLightsRollout" #'open' filter:off \
		codeStr:("LLister.DeleteCallback = when LLister.UIControlList[1] deleted obj do" + \
		"\n(\nlocal foundMe = findItem LLister.UIControlList[1] obj\n" + \
		"if foundMe > 0 do\n(\n" + \
		"LLister.disableUIElements LLister.UIControlList[2][foundMe]\n)\n)")

	LLister.maxLightsRC.addHandler "maxLightsRollout" #'close' filter:off \
		codeStr:"DeleteChangeHandler LLister.DeleteCallback"
		
	-- Removing the Refresh/ProgressBar
	
	LLister.LightInspectorSetup.pbar.value = 0
	LLister.LightInspectorSetup.pbar.visible = false
	
	-- AB: Jun 20, 2002
	-- Add a new control that tells users to use the selection mode if they had too many lights in the list
	
	if not CanAddControls and LLister.maxLightsRC.str != "" do 
		LLister.maxLightsRC.addControl #label #lbLimitControls "The maximum number of Lights has been reached, please select fewer lights and use the Selected Lights option" \
			paramStr:" align:#center offset:[0,10]"
	
	if LLister.maxLightsRC.str != "" then LLister.maxLightsRC.end() else undefined
)

LLister.CreateLightRollout = CreateLightRollout

-- Loading rollout size and position, if available

local dialogPos, dialogSize

dialogPos = execute (getIniSetting "$plugCfg/LLister.cfg" "General" "DialogPos") -- Do not localize
dialogSize = execute (getIniSetting "$plugCfg/LLister.cfg" "General" "DialogSize") -- Do not localize

if classof DialogPos != Point2 do dialogPos = [200,300]
if classof DialogSize != Point2 do dialogSize = [800,300]

DialogSize.x = 800

try(closeRolloutFloater LLister.LightInspectorFloater) catch()
LLister.LightInspectorFloater = newRolloutFloater "Light Lister" dialogSize.x dialogSize.y dialogPos.x dialogPos.y

LLister.GlobalLightParameters =
(local GlobalLightParameters
rollout GlobalLightParameters "General Settings"
(
	
	-- Start Localization
	
	radioButtons rbtoggle labels:#("Selected Lights","All Lights")

	label lb01 "On" align:#left offset:[-6,-3]
	label lb03 "Multiplier"  align:#left offset:[12,-18]
	label lb04 "Color"  align:#left offset:[67,-18]
	label lb05 "Shadows"  align:#left offset:[96,-18]
	label lb06 "Map Size"  align:#left offset:[229,-18]
	label lb07 "Bias"  align:#left offset:[286,-18]
	label lb08 "Sm.Range"  align:#left offset:[337,-18]
	label lb09 "Trans."  align:#left offset:[390,-18]
	label lb10 "Int."  align:#left offset:[424,-18]
	label lb11 "Qual."  align:#left offset:[461,-18]
	label lb12 "Decay"  align:#left offset:[505,-18]
	label lb13 "Start"  align:#left offset:[586,-18]
	label lb14 "Length"  align:#left offset:[643,-18]
	label lb15 "Width"  align:#left offset:[699,-18]

	-- End Localization

	checkBox lightOn "" width:15 checked:true offset:[-4,0]
	spinner lightMult "" fieldWidth:45 type:#float range:[-10000,10000,1.0] align:#left offset:[10,-20]
	colorPicker lightCol "" width:25 color:white offset:[66,-23]
	checkBox shadowOn "" width:15 checked:true offset:[96,-22]
	dropDownList shadowType width:115 items:LLister.ShadowPluginsName offset:[113,-23]
	spinner ShadowMapSize "" fieldWidth:45 type:#integer range:[0,10000,512] align:#left offset:[227,-24]
	spinner ShadowBias "" fieldWidth:45 type:#float range:[0,10000,0.5] align:#left offset:[284,-21]
	spinner ShadowSmpRange "" fieldWidth:45 type:#float range:[0,50,4.0] align:#left offset:[341,-21]
	checkBox shadowTrans "" width:15 offset:[401,-20]
	spinner ShadowInteg "" fieldWidth:30 type:#integer range:[0,15,1] align:#left offset:[415,-21]
	spinner ShadowQual 	"" fieldWidth:30 type:#Integer range:[0,15,2] align:#left offset:[459,-21]
	dropDownList lightDecay width:80 items:LLister.decayStrings offset:[504,-23]
	spinner lightDecaySt "" fieldWidth:45 type:#float range:[0,10000,40] align:#left offset:[584,-24]
	spinner lightLength "" fieldWidth:45 type:#float range:[0,10000,40] align:#left offset:[641,-21]
	spinner lightWidth "" fieldWidth:45 type:#float range:[0,10000,40] align:#left offset:[697,-21]
	
	group ""
	(
	
	-- Start Localization
	
	colorpicker gTint "Global Tint:" color:lightTintColor offset:[180,0]
	spinner gLevel "Global Level:" range:[0,10000,lightLevel]  fieldWidth:45 align:#left offset:[290,-22]
	colorPicker cpAmbient "Ambient Color" color:ambientColor offset:[420,-24]
	
	-- End Localization
	
	)
	
	on gtint changed val do lightTintColor = val
	on glevel changed val do lightLevel = val
	on cpAmbient changed val do ambientColor = val
	
	fn setCollectionProperty prop val CreateUndo:true =
	(
		if createUndo then
		(
			undo "LightLister" on 
			(
				local myCollection = if rbToggle.state == 1 then Selection else Lights
				for i in myCollection do 
				(
					setLightProp i.baseobject prop val
					setShdProp i.baseObject prop val
				)
			)
		)
		else
		(
			local myCollection = if rbToggle.state == 1 then Selection else Lights
			for i in myCollection do
			(
				setLightProp i.baseobject prop val
				setShdProp i.baseObject prop val
			)
		)
	)
	
	on lightOn changed state do setCollectionProperty #enabled state
	on lightCol changed val do (setCollectionProperty #color val CreateUndo:false;setCollectionProperty #filter_Color val CreateUndo:false)
	on shadowOn changed state do setCollectionProperty #castShadows state
	on shadowTrans changed state do setCollectionProperty #shadow_transparent state
	on shadowInteg changed val do setCollectionProperty #pass1 val CreateUndo:false
	on shadowQual changed val do setCollectionProperty #pass2 val CreateUndo:false
	on lightWidth changed val do setCollectionProperty #light_Width val CreateUndo:false
	on lightLength changed val do setCollectionProperty #light_Length val CreateUndo:false
	on lightMult changed val do 
	(
		setCollectionProperty #multiplier val CreateUndo:false
		setCollectionProperty #intensity val CreateUndo:false
		setCollectionProperty #dimmer val CreateUndo:false
	)
	on ShadowMapSize changed val do setCollectionProperty #mapSize val CreateUndo:false
	on ShadowSmpRange changed val do setCollectionProperty #sampleRange val CreateUndo:false
	on lightDecaySt changed val do setCollectionProperty #decayRadius val CreateUndo:false
	on lightDecay selected d do setCollectionProperty #attenDecay d
	on shadowBias changed val do
	(
		setCollectionProperty #mapBias val CreateUndo:false
		setCollectionProperty #ray_Bias val CreateUndo:false
		setCollectionProperty #raytraceBias val CreateUndo:false
	)
	
	on shadowType selected j do
	(
		local myCollection = if rbToggle.state == 1 then Selection else Lights
		for i in myCollection do setLightProp i.baseobject #shadowGenerator (LLister.ShadowPlugins[j]())
	)

) -- end Rollout
) -- end structDef

LLister.LightInspectorSetup =
(local LightInspectorSetup
rollout LightInspectorSetup "Configuration" -- Localize
(
	radiobuttons rolloutSelector labels:#("All Lights","Selected Lights","General Settings") -- Localize
	button btnReload "Refresh" align:#right offset:[0,-20] height:16 -- Localize
	progressBar pbar width:120 pos:(btnReload.pos - [125,-1])
	
	on rolloutSelector changed state do
	(
		rolloutSelector.state = state
		case rolloutSelector.state of
		(
		1:	(
			btnReload.visible = false
			try(RemoveRollout LLister.GlobalLightParameters LLister.LightInspectorFloater) catch()
			try(RemoveRollout LLister.LightInspectorListRollout LLister.LightInspectorFloater) catch()
			LLister.LightInspectorListRollout = LLister.CreateLightRollout (Lights as array + helpers as array)
			if LLister.LightInspectorListRollout != undefined do
				addRollout LLister.LightInspectorListRollout LLister.LightInspectorFloater
			LLister.maxLightsRC = undefined
			gc light:true
			btnReload.visible = true
			)
		2:	(
			btnReload.visible = false
			try(RemoveRollout LLister.GlobalLightParameters LLister.LightInspectorFloater) catch()
			try(RemoveRollout LLister.LightInspectorListRollout LLister.LightInspectorFloater) catch()
			LLister.LightInspectorListRollout = LLister.CreateLightRollout Selection
			if LLister.LightInspectorListRollout != undefined do
				addRollout LLister.LightInspectorListRollout LLister.LightInspectorFloater
			LLister.maxLightsRC = undefined
			gc light:true
			btnReload.visible = true
			)
		3:	(
			try(RemoveRollout LLister.GlobalLightParameters LLister.LightInspectorFloater) catch()
			try(RemoveRollout LLister.LightInspectorListRollout LLister.LightInspectorFloater) catch()
			addRollout LLister.GlobalLightParameters LLister.LightInspectorFloater
			btnReload.visible = false
			)
		)
	)
	
	on btnReload pressed do rolloutSelector.changed rolloutSelector.state

	on LightInspectorSetup close do
	(
		callBacks.RemoveScripts id:#LListerRollout
		setIniSetting "$plugCfg/LLister.cfg" "General" "DialogPos" (LLister.LightInspectorFloater.Pos as string) -- do not localize
		setIniSetting "$plugCfg/LLister.cfg" "General" "DialogSize" (LLister.LightInspectorFloater.Size as string) -- do not localize
		setIniSetting "$plugCfg/LLister.cfg" "General" "LastState" (rolloutSelector.state as string) -- do not localize
	)
	
	on LightInspectorSetup open do
	(
		pbar.visible = false
		local lastState = (getIniSetting "$plugCfg/LLister.cfg" "General" "LastState") as integer  -- do not localize
		if lastState == 0 do lastState = 1
		if lastState < 4 do
			rolloutSelector.changed lastState
		LLister.maxLightsRC = undefined
		gc light:true

		-- Callbacks to remove Floater
		callBacks.AddScript #systemPreReset "CloseRolloutFloater LLister.LightInspectorFloater" id:#LListerRollout  -- do not localize
		callBacks.AddScript #systemPreNew "CloseRolloutFloater LLister.LightInspectorFloater" id:#LListerRollout -- do not localize
		callBacks.AddScript #filePreOpen "CloseRolloutFloater LLister.LightInspectorFloater" id:#LListerRollout -- do not localize
	)
) -- end Rollout
) -- end StructDef
 addRollout LLister.LightInspectorSetup LLister.LightInspectorFloater

)
