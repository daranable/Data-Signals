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

-- Define global table
datasignals = { }

local p = datasignals
local private = { }
local public = { }
local listeners = { }

local valid_data = { 
"string" = true,
"Angle" = true,
"Entity" = true,
"number" = true,
"Player" = true,
"Vector" = true,
"boolean" = true,
"nil" = true,
"NPC" = true
}

--- Retrieves the registration table for a given group.
-- @param group_name the group name with possible scope
-- @param owner the owner or player who owns the chip getting saved
-- @return the set of members of a given group
local function getGroupTable( group_name, owner )
	local name, scope = string.match( group_name, "^([%w_]+)(:%l+)?$" )
	local scope_table
	local group_table
	
	if not name then 
		error( "Invalid data signal group name '" .. group_name .. "'" ) 
	end
	if not scope then scope = ":private" end
	
	if scope == ":private" then  
		scope_table = private[owner]
		if scope_table == nil then
			scope_table = { }
			private[owner] = scope_table
		end
		
		group_table = scope_table[group_name]
		if group_table == nil then
			group_table = { }
			scope_table[group_name] = group_table
		end
		
		return group_table
	elseif scope == ":public" then
		scope_table = public
		
		group_table = public[group_name]
		if group_table == nil then
			group_table = { }
			scope_table[group_name] = group_table
		end
		
		return group_table
	else
		error( "Invalid data signal scope name '" .. scope .. "'" )
	end
end

--- Verifies a signal name is legal.
-- @param signal the name of the signal
-- @return true if it is valid false if it is not
local function validSignal( signal )
	if string.match( signal, "^[%w_]+$" ) 
			and string.len(signal) <= 20 then
		return true
	else
		return false
	end
end

--- Adds the chip to the specified group.
-- @param group_name the group name with possible scope
-- @param chip the entity of the chip getting added
function p.join( group_name, chip )
	if type( chip ) ~= "Entity" or not chip:IsValid() then
		error( "Chip registered with data signal must be a valid entity" )
	end
	local group_table = getGroupTable( group_name, chip:GetOwner() )
	
	group_table[chip] = true
end

--- Removes the chip from the specified group.
-- @param group_name the group name with possible scope
-- @param chip the entity of the chip getting removed
function p.leave( group_name, chip )
	local group_table = getGroupTable( group_name, chip:GetOwner() )
	
	group_table[chip] = nil
end

--- Registers a function to listen for a specific signal.
-- Can take a special signal name '$default' that gets called
-- on every signal no matter what.
-- @param signal name of the signal
-- @param chip the entity of the chip registering a listener
-- @param callback the function that will be called
function p.listen( signal, chip, callback )
	if not validSignal( signal ) and signal ~= "$default" then 
		error( "Invalid data signal name '" .. signal .. "'" ) 
	end
	
	if type( chip ) ~= "Entity" or not chip:IsValid() then
		error( "Chip registered with data signal must be a valid entity" )
	end
	
	local chip_table = listeners[chip]
	if chip_table == nil then
		chip_table = { }
		listeners[chip] = chip_table
	end
	
	local set_list = chip_table[signal]
	if set_list == nil then
		set_list = { }
		chip_table[signal] = set_list
	end
	
	set_list[callback] = true
end

--- Unregisters a function from listening to a certain signal.
-- @param signal name of the signal
-- @param chip the entity of the chip registering a listener
-- @param callback the function that will be called
function p.ignore( signal, chip, callback )
	if not validSignal( signal ) and signal ~= "$default" then 
		error( "Invalid data signal name '" .. signal .. "'" ) 
	end
	
	local chip_table = listeners[chip]
	if not chip_table then
		return
	end
	
	local set_list = chip_table[signal]
	if not set_list then
		return
	end
	
	set_list[callback] = nil
end


local function send( target, signal, data, sender )
	local errors = 0
	if type( target ) == "Entity" then
		local current = listeners[target]
		
		for _,set in pairs( { current["$default"], current[signal] } ) do
			for callback,_ in pairs( set ) do
				local result = pcall( callback, signal, data, sender )
				
				if not result then errors = errors + 1 end
			end
		end
		
	elseif type( target ) == "string" then
		local group_table = getGroupTable( target, sender:GetOwner() )
		
		for chip,_ in pairs( group_table ) do
			errors = errors + send( chip, signal, data, sender )
		end
		
	elseif type( target ) == "table" then
		for _,value in pairs( target ) do
			errors = errors + send( value, signal, data, sender )
		end
	end
	
	return errors
end

--- Sends a data signal.  Can send it to a topic or an entity.
-- @param target an entity, a group name, or a heterogeneous array of same
-- @param signal name of the signal
-- @param data the data to be sent, can be any of the valid data types
-- @param sender the entity of the chip sending this signal
function p.send( target, signal, data, sender )
	if not validSignal( signal ) then
		error( "Invalid data signal name '" .. signal .. "'" ) 
	end
	
	if not valid_data[type(data)] then
		error( "Invalid data signal data type." )
	end
	
	if type( sender ) ~= "Entity" or not sender:IsValid() then
		error( "Sender of data signal must be a valid entity" )
	end
	
	return send( target, signal, data, sender )
end