-- @file pluginscript_class_metadata.lua  Helpers for Script/Class metadata (properties, methods, signals)
-- This file is part of Godot Lua PluginScript: https://github.com/gilzoide/godot-lua-pluginscript
--
-- Copyright (C) 2021 Gil Barbosa Reis.
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the “Software”), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.

--- Scripts metadata.
-- This includes properties, signals and methods.
-- @module script_metadata

-- Map names and types to godot_variant_type
local property_types = {
	bool = VariantType.Bool, [bool] = VariantType.Bool,
	int = VariantType.Int, [int] = VariantType.Int,
	float = VariantType.Float, [float] = VariantType.Float,
	String = VariantType.String, [String] = VariantType.String,
	string = VariantType.String, [string] = VariantType.String,

	Vector2 = VariantType.Vector2, [Vector2] = VariantType.Vector2,
	Rect2 = VariantType.Rect2, [Rect2] = VariantType.Rect2,
	Vector3 = VariantType.Vector3, [Vector3] = VariantType.Vector3,
	Transform2D = VariantType.Transform2D, [Transform2D] = VariantType.Transform2D,
	Plane = VariantType.Plane, [Plane] = VariantType.Plane,
	Quat = VariantType.Quat, [Quat] = VariantType.Quat,
	AABB = VariantType.AABB, [AABB] = VariantType.AABB,
	Basis = VariantType.Basis, [Basis] = VariantType.Basis,
	Transform = VariantType.Transform, [Transform] = VariantType.Transform,

	Color = VariantType.Color, [Color] = VariantType.Color,
	NodePath = VariantType.NodePath, [NodePath] = VariantType.NodePath,
	RID = VariantType.RID, [RID] = VariantType.RID,
	Object = VariantType.Object, [Object] = VariantType.Object,
	Dictionary = VariantType.Dictionary, [Dictionary] = VariantType.Dictionary,
	Array = VariantType.Array, [Array] = VariantType.Array,

	PoolByteArray = VariantType.PoolByteArray, [PoolByteArray] = VariantType.PoolByteArray,
	PoolIntArray = VariantType.PoolIntArray, [PoolIntArray] = VariantType.PoolIntArray,
	PoolRealArray = VariantType.PoolRealArray, [PoolRealArray] = VariantType.PoolRealArray,
	PoolStringArray = VariantType.PoolStringArray, [PoolStringArray] = VariantType.PoolStringArray,
	PoolVector2Array = VariantType.PoolVector2Array, [PoolVector2Array] = VariantType.PoolVector2Array,
	PoolVector3Array = VariantType.PoolVector3Array, [PoolVector3Array] = VariantType.PoolVector3Array,
	PoolColorArray = VariantType.PoolColorArray, [PoolColorArray] = VariantType.PoolColorArray,
}

local function get_property_type(value)
	local t = type(value)
	if t == 'boolean' then
		return VariantType.Bool
	elseif t == 'string' then
		return VariantType.String
	elseif ffi_istype(int, value) then
		return VariantType.Int
	elseif t == 'number' or tonumber(value) then
		return VariantType.Real
	elseif t == 'table' then
		return VariantType.Dictionary
	elseif t == 'cdata' and value.varianttype then
		return value.varianttype
	end
	return VariantType.Nil
end

local Property = {}

local function is_property(value)
	return getmetatable(value) == Property
end

local function property_to_dictionary(prop)
	local default_value = prop.default_value
	local dict = Dictionary {
		default_value = default_value,
		type = prop.type,
		usage = prop.usage,
		rset_mode = prop.rset_mode,
		hint = prop.hint,
		hint_string = prop.hint_string,
	}
	return dict, default_value
end

--- Adds `metadata` to a property.
-- If `metadata` is not a table, creates a table with this value as `default_value`.
-- The `metadata` table may include the following fields:
--
-- * `default_value` or `default` or `1`: default property value, returned when
--   Object has no other value set for it.
-- * (*optional*) `type` or `2`: property type. If absent, it is inferred from `default_value`.
--   May be a `Enumerations.VariantType` (`VariantType.Vector2`), the type directly (`Vector2`),
--   or a Resource class (`AudioStream`)
-- * (*optional*) `get` or `getter`: getter function. May be a string with the method name
--   to be called or any callable value, like functions and tables with a `__call`
--   metamethod.
-- * (*optional*) `set` or `setter`: setter function. May be a string with the method name
--   to be called or any callable value, like functions and tables with a `__call`
--   metamethod.
-- * (*optional*) `hint`: one of `Enumerations.PropertyHint`. Default to `PropertyHint.NONE`.
-- * (*optional*) `hint_string`: the hint text, required for some hints like `RANGE`.
-- * (*optional*) `usage`: one of `Enumerations.PropertyUsage`. Default to `PropertyUsage.DEFAULT`.
-- * (*optional*) `rset_mode`: one of `Enumerations.RPCMode`. Default to `RPCMode.DISABLED`.
--
-- TODO: accept hints directly (`range = '1,10'`; `enum = 'value1,value2,value3'`; `file = '*.png'`, etc...).
-- @usage
--     MyClass.some_prop = property(42)
--     MyClass.some_prop_with_metadata = property {
--         type = int,
--         set = function(self, value)
--             self.some_prop_with_metadata = value
--             self:emit('some_prop_with_metadata_changed', value)
--         end,
--         hint = PropertyHint.RANGE,
--         hint_text = '1,100',
--     }
-- @treturn table
-- @raise If neither default value, type or getter is passed.
-- @see lps_coroutine.lua
function property(metadata)
	local prop = setmetatable({}, Property)
	local default_value, property_type, getter
	if type(metadata) ~= 'table' then
		default_value = metadata
		property_type = get_property_type(metadata)
	else
		default_value = metadata.default_value or metadata.default or metadata[1]
		local explicit_type = metadata.type or metadata[2]
		if is_class_wrapper(explicit_type) then
			assert(explicit_type:inherits('Resource'), string_format("Only classes based on Resource are supported as property types, found %q", explicit_type.class_name))
			property_type = VariantType.Object
			prop.hint = PropertyHint.RESOURCE_TYPE
			prop.hint_string = explicit_type.class_name
		else
			property_type = property_types[explicit_type] or explicit_type or get_property_type(default_value)
			prop.hint = metadata.hint
			prop.hint_string = metadata.hint_string
		end
		prop.usage = metadata.usage
		prop.rset_mode = metadata.rset_mode
		getter = metadata.get or metadata.getter
		if is_a_string(getter) then
			getter = MethodBindByName:new(getter)
		end
		local setter = metadata.set or metadata.setter
		if is_a_string(setter) then
			setter = MethodBindByName:new(setter)
		end
		prop.setter = setter
	end
	assert(default_value ~= nil or property_type ~= VariantType.Nil or getter == nil, "Expected either default value, type or getter")
	prop.default_value = default_value
	prop.type = property_type
	prop.getter = getter
	return prop
end


local Signal = {}

local function is_signal(value)
	return getmetatable(value) == Signal
end

local function signal_to_dictionary(sig)
	local dict = Dictionary()
	dict.args = Array()
	for i = 1, #sig do
		dict.args:append(Dictionary{ name = String(sig[i]) })
	end
	return dict
end

--- Create a signal table.
-- This is only useful for declaring scripts' signals.
-- @usage
--     MyClass.something_happened = signal()
--     MyClass.something_happened_with_args = signal('arg1', 'arg2', 'etc')
-- @param ...  Signal argument names
-- @treturn table
-- @see lps_coroutine.lua
function signal(...)
	return setmetatable({ ... }, Signal)
end

local function method_to_dictionary(f)
	return Dictionary()
end
