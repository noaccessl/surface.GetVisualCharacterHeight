
--
-- Advanced settings
--
local VCH_OVERRIDE_DEFAULTS = true -- Should the script override default surface.CreateFont & surface.SetFont?

local g_pfnGetFont
--[[ Note
	If you set VCH_OVERRIDE_DEFAULTS to false,
	then assumingly you have your own surface.GetFont
	and in that case set g_pfnGetFont to it.

	Or.

	Just provide the font in use to surface.GetVisualCharacterHeight.
]]


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Prepare
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
--
-- Libraries, functions
--
local surface = surface
local render = render
local string = string

local ReadPixel = render.ReadPixel


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Purpose: Store the former functions.
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local CreateFontEx
local SetFontEx

if ( VCH_OVERRIDE_DEFAULTS ) then

	surface.CreateFontEx = surface.CreateFontEx or surface.CreateFont
	surface.SetFontEx = surface.SetFontEx or surface.SetFont

	CreateFontEx = surface.CreateFontEx
	SetFontEx = surface.SetFontEx

end

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	(Override) surface.CreateFont
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
if ( VCH_OVERRIDE_DEFAULTS ) then

	function surface.CreateFont( name, data )

		VisualCharacterHeight_Uncache( name )
		-- Clearing the font's cache that it gets remeasured later,
		-- just in case the size or weight got changed.

		return CreateFontEx( name, data )

	end

end

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	(Override) surface.SetFont

	Purpose: Store the current font for later access.
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local g_surface_FontUsed

if ( VCH_OVERRIDE_DEFAULTS ) then

	g_surface_FontUsed = 'DermaDefault'

	function surface.SetFont( font )

		g_surface_FontUsed = font

		return SetFontEx( font )

	end

end


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Cache
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local VCHCache = {}

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	VisualCharacterHeight_Uncache

	Purpose: Later fresh recache.

	Note: If VCH_OVERRIDE_DEFAULTS = false and your font's size &/ weight is «dynamic»,
		you might want to call it before that change. (This assumes that
		surface.GetVisualCharacterHeight is used.)
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
function VisualCharacterHeight_Uncache( specificfont )

	if ( specificfont ) then
		VCHCache[specificfont] = nil
	else
		for font in pairs( VCHCache ) do VCHCache[font] = nil end
	end

end

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	The common render target
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local g_texVCH = GetRenderTargetEx(
	'_rt_VisualCharacterHeight',
	ScrW(), ScrH(),
	RT_SIZE_FULL_FRAME_BUFFER, MATERIAL_RT_DEPTH_NONE,
	bit.bor( 2, 256 ), 0,
	8 -- IMAGE_FORMAT_A8
)

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	(Internal) CalculateVisualCharacterHeight

	Purpose: Works out the visual height of the provided characters.
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local function CalculateVisualCharacterHeight( chars )

	-- Work out the operating area
	local w, h = surface.GetTextSize( chars )

	local yTop = 0 -- The ordinate of the highest visible pixel
	local yBottom = h - 1 -- The ordinate of the lowest visible pixel

	render.PushRenderTarget( g_texVCH )
	render.SetScissorRect( 0, 0, w, h, true )

		render.Clear( 255, 255, 255, 0 )

		surface.SetAlphaMultiplier( 1 )
		-- Just in case the overall alpha right now is zero.
		-- E.g. <Panel>:Paint(); <Panel>:GetAlpha() => 0.

		cam.Start2D()

			surface.SetTextColor( 255, 255, 255, 255 )

			if ( string.find( chars, '\n' ) ) then

				-- Multi-line text

				local offsetY = 0
				local lineHeight = select( 2, surface.GetTextSize( '\n' ) )

				for line in string.gmatch( chars, '[^\n]*' ) do

					if ( line == '' ) then offsetY = offsetY + ( lineHeight * 0.5 ) continue end
					-- line = '' means that it's a '\n' itself.

					surface.SetTextPos( 0, offsetY )
					surface.DrawText( line )

				end

			else

				-- Simple text

				surface.SetTextPos( 0, 0 )
				surface.DrawText( chars )

			end

		cam.End2D()

		render.CapturePixels()

		-- yTop
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local _, _, _, a = ReadPixel( x, y )
				if ( a ~= 0 ) then yTop = y goto exit_1 end
			end
		end
		::exit_1::

		-- yBottom
		for y = h - 1, 0, -1 do
			for x = w - 1, 0, -1 do
				local _, _, _, a = ReadPixel( x, y )
				if ( a ~= 0 ) then yBottom = y goto exit_2 end
			end
		end
		::exit_2::

	render.SetScissorRect( 0, 0, 0, 0, false )
	render.PopRenderTarget()

	return yTop, yBottom

end

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	surface.GetVisualCharacterHeight

	Purpose: Gets the visual height of the provided characters.
	Returns:
		1 number visualheight
		2 number roofheight
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
function surface.GetVisualCharacterHeight( chars, font )

	if ( not isstring( chars ) ) then
		assert( false, Format( 'bad argument #1 to \'GetVisualCharacterHeight\' (string expected, got %s)', type( chars ) ) )
	end

	--
	-- Manage the font
	--
	if ( not VCH_OVERRIDE_DEFAULTS ) then

		if ( g_pfnGetFont ) then
			g_surface_FontUsed = g_pfnGetFont()
		end

		if ( not font and not g_surface_FontUsed ) then
			assert( false, 'font to \'GetVisualCharacterHeight\' is not provided or cannot be obtained' )
		end

		if ( font and ( g_surface_FontUsed and g_surface_FontUsed ~= font or true ) ) then
			surface.SetFont( font )
		elseif ( g_surface_FontUsed ) then
			font = g_surface_FontUsed
		end

	else

		if ( font and g_surface_FontUsed ~= font ) then
			surface.SetFont( font )
		else
			font = g_surface_FontUsed
		end

	end

	local vchcache_font = VCHCache[font]

	if ( not vchcache_font ) then

		-- Prepare a place in the cache

		vchcache_font = {}
		VCHCache[font] = vchcache_font

	else

		-- Return the stored

		local charsmeasurement = vchcache_font[chars]

		if ( charsmeasurement ) then
			return charsmeasurement.visualheight, charsmeasurement.roofheight
		end

	end

	local yTop, yBottom = CalculateVisualCharacterHeight( chars )

	local visualheight = ( ( yBottom - yTop ) + 1 )
	local roofheight = yTop

	if ( not vchcache_font[chars] ) then
		vchcache_font[chars] = { visualheight = visualheight; roofheight = roofheight }
	end

	return visualheight, roofheight

end
