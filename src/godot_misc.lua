local node_path_methods = {
	tovariant = ffi.C.hgdn_new_node_path_variant,
	varianttype = GD.TYPE_NODE_PATH,
}
NodePath = ffi.metatype('godot_node_path', {
	__new = function(mt, text_or_nodepath)
		local self = ffi.new(mt)
		if ffi.istype(mt, text_or_nodepath) then
			api.godot_node_path_new_copy(self, text_or_nodepath)
		elseif ffi.istype(String, text_or_nodepath) then
			api.godot_node_path_new(self, text_or_nodepath)
		else
			api.godot_node_path_new(self, String(text_or_nodepath))
		end
		return self
	end,
	__gc = api.godot_node_path_destroy,
	__tostring = function(self)
		return tostring(api.godot_node_path_as_string(self))
	end,
	__index = node_path_methods,
	__concat = concat_gdvalues,
})

RID = ffi.metatype('godot_rid', {
	__new = function(mt, resource)
		local self = ffi.new(mt)
		if resource then
			api.godot_rid_new_with_resource(self, resource)
		else
			api.godot_rid_new(self)
		end
		return self
	end,
	__tostring = GD.tostring,
	__index = {
		tovariant = ffi.C.hgdn_new_rid_variant,
		varianttype = GD.TYPE_RID,
		get_id = api.godot_rid_get_id,
	},
	__concat = concat_gdvalues,
	__eq = api.godot_rid_operator_equal,
	__lt = api.godot_rid_operator_less,
})

local object_methods = {
	tovariant = ffi.C.hgdn_new_object_variant,
	varianttype = GD.TYPE_OBJECT,
	pcall = function(self, method, ...)
		local has_method = ffi.C.hgdn_object_callv(self, 'has_method', Array(method)):unbox()
		if has_method then
			return true, ffi.C.hgdn_object_callv(self, method, Array(...)):unbox()
		else
			return false
		end
	end,
	call = function(self, method, ...)
		return select(2, self:pcall(method, ...))
	end,
}
Object = ffi.metatype('godot_object', {
	__tostring = GD.tostring,
	__index = function(self, key)
		local method = object_methods[key]
		if method then
			return method
		end
		if self:call('has_method', key) then
			return MethodBind:new(key)
		else
			self:call('get', key)
		end
	end,
	__concat = concat_gdvalues,
})
