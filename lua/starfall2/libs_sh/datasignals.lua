--- Data signals are a way for wire entities to communicate with 
-- each other.  This is based off of the library in Expression 2 by the
-- same name.  The system is interoperable across all wire entities 
-- including gLua, Expression 2, and Starfall.
-- 
-- A data signal is a message with a name and a single value.  A
-- signal name can be up to twenty characters, made of upper and
-- lower case letters, digits, and underbar.  The value can be any of
-- the following types: Angle, boolean, Entity, nil, NPC, number, 
-- Player, string, or Vector.
-- 
-- A function may be assigned to a signal name as a listener.  When a 
-- signal of that name gets sent to the chip, this function will be
-- called and passed the signal's name and value. Additionally, 
-- listeners registerd to the special name '$default' will receive all
-- signals sent to the chip regardless of name.
-- 
-- Wired entities can be organized into groups to simplify delivery to
-- multiple entities.  A signal sent to a group will be delivered as if
-- it had been sent to each member of that group individually.  A 
-- group name is a combination of the group name and a scope identifier.
-- The scope delimiter is ':'. After this delimiter you can have either 
-- public or private. If you do not put a scope delimiter and identifer 
-- it defaults to private.
-- 
-- Scope is what sets which entities a group can contain. A private 
-- group will only contain chips owned by the same player.  Public
-- groups are shared by all players.
--
-- @author Daranable
local data_signal, _ = SF.Libraries.RegisterLocal("data_signal")

local P = data_signal
local GP = datasignals
local CBFunctions = { }

--- Joins the named data signal group. To change what scope
-- you are joing add ':public' or ':private' to the end of the group 
-- name. If you leave a scope off it defaults to private.
-- @param group_name a string containing the group name and optionally
-- scope.
function P.join( group_name )
	assert( 
		type( group_name ) == "string", 
		"Data signal group name must be a string" 
	)
	
	GP.join( group_name, SF.instance.data.entity )
end

--- Leaves the named data signal group. Note that group name
-- is a combination of the name and scope, so to leave a public group
-- you must append the public scope delineator.  Scope defaults to 
-- private.
-- @param group_name a string containing the group name and optionally
-- scope.
function P.leave( group_name )
	assert( 
		type( group_name ) == "string", 
		"Data signal group name must be a string" 
	)
	
	GP.leave( group_name, SF.instance.data.entity )
end

--- Registers the given function as a listener to the signal.
-- When a signal is received whith the listed name,  the function will
-- be called and passed signal name, the value, and the sender.
-- @param signal name of the signal
-- @param callback the function that will be called
function P.listen( signal, callback )
	assert( 
		type( signal ) == "string",
		"Data signal name must be a string"
	)
	assert(
		type( callback ) == "function",
		"Data signal callback must be a function"
	)
	
	local cb = CBFunctions[ callback ]
	local instance = SF.instance
	
	if not cb then
		cb = function( signal, data, sender )
			assert( 
				type( signal ) == "string", 
				"Received data signal name was not a string" 
			)
			assert( 
				type( sender ) == "Entity", 
				"Received sender was not an entity" 
			)
			
			local dtype = type( data )
			
			if dtype == "Entity" or dtype == "NPC" or dtype == "Player" then
				data = SF.Entities.Wrap( data )
			end
			
			instance:runFunction( 
				callback, 
				signal, 
				data, 
				SF.Entities.Wrap( sender ) 
			)
		end
		
		CBFunctions[ callback ] = cb
	end
	
	GP.listen( signal, SF.instance.data.entity, cb )
end

--- Unregisters a function from the given signal name.
-- @param signal name of the signal
-- @param callback the function that will be called
function P.ignore( signal, callback )
	assert( 
		type( signal ) == "string",
		"Data signal name must be a string"
	)
	assert(
		type( callback ) == "function",
		"Data signal callback must be a function"
	)
	
	local cb = CBFunctions[ callback ]
	if not cb then
		return
	end
	
	GP.ignore( signal, SF.instance.data.entity, cb )
end

local function unwrap_array( array )
	local new
	
	for key,value in pairs( array ) do
		if type( value ) == "table" then
			if getmetatable( value ) == "Entity" then
				value = SF.Entities.Unwrap( value )
			else
				value = unwrap_array( value )
			end
		end
		
		new[key] = value
	end
	
	return new
end

--- Sends a data signal.
-- @param target an entity, a group name, or an array containing any or
-- all of the possible options.
-- @param signal name of the signal
-- @param data can be any of the following types: Angle, boolean, Entity, 
-- nil, NPC, number, Player, string, or Vector.
function P.send( target, signal, data )
	if getmetatable( target ) == "Entity" then
		target = SF.Entities.Unwrap( target )
	elseif type( target ) == "table" then
		target = unwrap_array( target )
	elseif type( target ) ~= "string" then 
		error( "Invalid data signal target" )
	end
	
	assert( 
		type( signal ) == "string",
		"Data signal name must be a string"
	)
	
	if getmetatable( data ) == "Entity" then
		data = SF.Entities.Unwrap( data )
	end
	
	GP.send( target, signal, data, SF.instance.data.entity )
end