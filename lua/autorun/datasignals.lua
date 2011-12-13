-- Autorun file

if SERVER then
	-- this file
	AddCSLuaFile("autorun/datasignals.lua")
	
	include( "datasignals.lua" )
end