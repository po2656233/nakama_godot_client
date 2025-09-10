#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && varint[8] == 0xFF:
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		var value = 0
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_float()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_double()
		else:
			for i in range(index + count - 1, index - 1, -1):
				value |= (bytes[i] & 0xFF)
				if i != index:
					value <<= 8
		return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		for i in range(varint_bytes.size() - 1, -1, -1):
			value |= varint_bytes[i] & 0x7F
			if i != 0:
				value <<= 7
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var result : PackedByteArray = PackedByteArray()
		for i in range(index, bytes.size()):
			result.append(bytes[i])
			if !(bytes[i] & 0x80):
				break
		return result

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								str_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								val_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class EnterGameReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
		__score = PBField.new("score", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __score
		data[__score.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	var __score: PBField
	func get_score() -> int:
		return __score.value
	func clear_score() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_score(value : int) -> void:
		__score.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EnterGameResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
		__chairID = PBField.new("chairID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __chairID
		data[__chairID.tag] = service
		
		__userInfo = PBField.new("userInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __userInfo
		service.func_ref = Callable(self, "new_userInfo")
		data[__userInfo.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	var __chairID: PBField
	func get_chairID() -> int:
		return __chairID.value
	func clear_chairID() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__chairID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_chairID(value : int) -> void:
		__chairID.value = value
	
	var __userInfo: PBField
	func get_userInfo() -> PlayerSimpleInfo:
		return __userInfo.value
	func clear_userInfo() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__userInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_userInfo() -> PlayerSimpleInfo:
		__userInfo.value = PlayerSimpleInfo.new()
		return __userInfo.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class JoinAllReadyQueueReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class JoinGameReadyQueueReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class JoinGameReadyQueueResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
		var __playerList_default: Array[PlayerSimpleInfo] = []
		__playerList = PBField.new("playerList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 3, true, __playerList_default)
		service = PBServiceField.new()
		service.field = __playerList
		service.func_ref = Callable(self, "add_playerList")
		data[__playerList.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	var __playerList: PBField
	func get_playerList() -> Array[PlayerSimpleInfo]:
		return __playerList.value
	func clear_playerList() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__playerList.value = []
	func add_playerList() -> PlayerSimpleInfo:
		var element = PlayerSimpleInfo.new()
		__playerList.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class WaitGameStartResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__waitTimeOut = PBField.new("waitTimeOut", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __waitTimeOut
		data[__waitTimeOut.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __waitTimeOut: PBField
	func get_waitTimeOut() -> int:
		return __waitTimeOut.value
	func clear_waitTimeOut() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__waitTimeOut.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_waitTimeOut(value : int) -> void:
		__waitTimeOut.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ExitGameReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ExitGameResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DisbandedTableReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DisbandedTableResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DisbandedGameReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DisbandedGameResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		var __tableIDs_default: Array[int] = []
		__tableIDs = PBField.new("tableIDs", PB_DATA_TYPE.INT64, PB_RULE.REPEATED, 3, true, __tableIDs_default)
		service = PBServiceField.new()
		service.field = __tableIDs
		data[__tableIDs.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __tableIDs: PBField
	func get_tableIDs() -> Array[int]:
		return __tableIDs.value
	func clear_tableIDs() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__tableIDs.value = []
	func add_tableIDs(value : int) -> void:
		__tableIDs.value.append(value)
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ChangeTableReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ChangeTableResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
		__chairID = PBField.new("chairID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __chairID
		data[__chairID.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	var __chairID: PBField
	func get_chairID() -> int:
		return __chairID.value
	func clear_chairID() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__chairID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_chairID(value : int) -> void:
		__chairID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetBackPasswordReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetBackPasswordResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__roomID = PBField.new("roomID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomID
		data[__roomID.tag] = service
		
		__hostID = PBField.new("hostID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __hostID
		data[__hostID.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
	var data = {}
	
	var __roomID: PBField
	func get_roomID() -> int:
		return __roomID.value
	func clear_roomID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__roomID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomID(value : int) -> void:
		__roomID.value = value
	
	var __hostID: PBField
	func get_hostID() -> int:
		return __hostID.value
	func clear_hostID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__hostID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_hostID(value : int) -> void:
		__hostID.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RankingListReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__kindId = PBField.new("kindId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __kindId
		data[__kindId.tag] = service
		
		__topCount = PBField.new("topCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __topCount
		data[__topCount.tag] = service
		
	var data = {}
	
	var __kindId: PBField
	func get_kindId() -> int:
		return __kindId.value
	func clear_kindId() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__kindId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_kindId(value : int) -> void:
		__kindId.value = value
	
	var __topCount: PBField
	func get_topCount() -> int:
		return __topCount.value
	func clear_topCount() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__topCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_topCount(value : int) -> void:
		__topCount.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RankingListResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __persons_default: Array[PlayerSimpleInfo] = []
		__persons = PBField.new("persons", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __persons_default)
		service = PBServiceField.new()
		service.field = __persons
		service.func_ref = Callable(self, "add_persons")
		data[__persons.tag] = service
		
	var data = {}
	
	var __persons: PBField
	func get_persons() -> Array[PlayerSimpleInfo]:
		return __persons.value
	func clear_persons() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__persons.value = []
	func add_persons() -> PlayerSimpleInfo:
		var element = PlayerSimpleInfo.new()
		__persons.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TrusteeReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__isTrustee = PBField.new("isTrustee", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isTrustee
		data[__isTrustee.tag] = service
		
	var data = {}
	
	var __isTrustee: PBField
	func get_isTrustee() -> bool:
		return __isTrustee.value
	func clear_isTrustee() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__isTrustee.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isTrustee(value : bool) -> void:
		__isTrustee.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TrusteeResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__isTrustee = PBField.new("isTrustee", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isTrustee
		data[__isTrustee.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __isTrustee: PBField
	func get_isTrustee() -> bool:
		return __isTrustee.value
	func clear_isTrustee() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__isTrustee.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isTrustee(value : bool) -> void:
		__isTrustee.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RollDiceReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__diceCount = PBField.new("diceCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __diceCount
		data[__diceCount.tag] = service
		
	var data = {}
	
	var __diceCount: PBField
	func get_diceCount() -> int:
		return __diceCount.value
	func clear_diceCount() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__diceCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_diceCount(value : int) -> void:
		__diceCount.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RollDiceResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__diceCount = PBField.new("diceCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __diceCount
		data[__diceCount.tag] = service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__dice = PBField.new("dice", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __dice
		data[__dice.tag] = service
		
	var data = {}
	
	var __diceCount: PBField
	func get_diceCount() -> int:
		return __diceCount.value
	func clear_diceCount() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__diceCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_diceCount(value : int) -> void:
		__diceCount.value = value
	
	var __uid: PBField
	func get_uid() -> int:
		return __uid.value
	func clear_uid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_uid(value : int) -> void:
		__uid.value = value
	
	var __dice: PBField
	func get_dice() -> PackedByteArray:
		return __dice.value
	func clear_dice() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__dice.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_dice(value : PackedByteArray) -> void:
		__dice.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameOverReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__gid = PBField.new("gid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gid
		data[__gid.tag] = service
		
	var data = {}
	
	var __gid: PBField
	func get_gid() -> int:
		return __gid.value
	func clear_gid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gid(value : int) -> void:
		__gid.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameOverResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__gid = PBField.new("gid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gid
		data[__gid.tag] = service
		
		__innings = PBField.new("innings", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __innings
		service.func_ref = Callable(self, "new_innings")
		data[__innings.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __gid: PBField
	func get_gid() -> int:
		return __gid.value
	func clear_gid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gid(value : int) -> void:
		__gid.value = value
	
	var __innings: PBField
	func get_innings() -> InningList:
		return __innings.value
	func clear_innings() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__innings.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_innings() -> InningList:
		__innings.value = InningList.new()
		return __innings.value
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pageNum(value : int) -> void:
		__pageNum.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class UpdateGoldReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class UpdateGoldResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__gold = PBField.new("gold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gold
		data[__gold.tag] = service
		
	var data = {}
	
	var __uid: PBField
	func get_uid() -> int:
		return __uid.value
	func clear_uid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_uid(value : int) -> void:
		__uid.value = value
	
	var __gold: PBField
	func get_gold() -> int:
		return __gold.value
	func clear_gold() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gold(value : int) -> void:
		__gold.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AddRecordReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__tid = PBField.new("tid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tid
		data[__tid.tag] = service
		
		__payment = PBField.new("payment", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __payment
		data[__payment.tag] = service
		
		__code = PBField.new("code", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __code
		data[__code.tag] = service
		
		__order = PBField.new("order", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __order
		data[__order.tag] = service
		
		__result = PBField.new("result", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __result
		data[__result.tag] = service
		
		__remark = PBField.new("remark", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __remark
		data[__remark.tag] = service
		
	var data = {}
	
	var __uid: PBField
	func get_uid() -> int:
		return __uid.value
	func clear_uid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_uid(value : int) -> void:
		__uid.value = value
	
	var __tid: PBField
	func get_tid() -> int:
		return __tid.value
	func clear_tid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tid(value : int) -> void:
		__tid.value = value
	
	var __payment: PBField
	func get_payment() -> int:
		return __payment.value
	func clear_payment() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__payment.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_payment(value : int) -> void:
		__payment.value = value
	
	var __code: PBField
	func get_code() -> int:
		return __code.value
	func clear_code() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__code.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_code(value : int) -> void:
		__code.value = value
	
	var __order: PBField
	func get_order() -> String:
		return __order.value
	func clear_order() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__order.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_order(value : String) -> void:
		__order.value = value
	
	var __result: PBField
	func get_result() -> String:
		return __result.value
	func clear_result() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__result.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_result(value : String) -> void:
		__result.value = value
	
	var __remark: PBField
	func get_remark() -> String:
		return __remark.value
	func clear_remark() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__remark.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_remark(value : String) -> void:
		__remark.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AddRecordResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__tid = PBField.new("tid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tid
		data[__tid.tag] = service
		
		__perGold = PBField.new("perGold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __perGold
		data[__perGold.tag] = service
		
		__payment = PBField.new("payment", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __payment
		data[__payment.tag] = service
		
		__gold = PBField.new("gold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gold
		data[__gold.tag] = service
		
		__code = PBField.new("code", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __code
		data[__code.tag] = service
		
		__order = PBField.new("order", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __order
		data[__order.tag] = service
		
		__result = PBField.new("result", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __result
		data[__result.tag] = service
		
		__remark = PBField.new("remark", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __remark
		data[__remark.tag] = service
		
	var data = {}
	
	var __uid: PBField
	func get_uid() -> int:
		return __uid.value
	func clear_uid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_uid(value : int) -> void:
		__uid.value = value
	
	var __tid: PBField
	func get_tid() -> int:
		return __tid.value
	func clear_tid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tid(value : int) -> void:
		__tid.value = value
	
	var __perGold: PBField
	func get_perGold() -> int:
		return __perGold.value
	func clear_perGold() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__perGold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_perGold(value : int) -> void:
		__perGold.value = value
	
	var __payment: PBField
	func get_payment() -> int:
		return __payment.value
	func clear_payment() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__payment.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_payment(value : int) -> void:
		__payment.value = value
	
	var __gold: PBField
	func get_gold() -> int:
		return __gold.value
	func clear_gold() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__gold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gold(value : int) -> void:
		__gold.value = value
	
	var __code: PBField
	func get_code() -> int:
		return __code.value
	func clear_code() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__code.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_code(value : int) -> void:
		__code.value = value
	
	var __order: PBField
	func get_order() -> String:
		return __order.value
	func clear_order() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__order.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_order(value : String) -> void:
		__order.value = value
	
	var __result: PBField
	func get_result() -> String:
		return __result.value
	func clear_result() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__result.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_result(value : String) -> void:
		__result.value = value
	
	var __remark: PBField
	func get_remark() -> String:
		return __remark.value
	func clear_remark() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__remark.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_remark(value : String) -> void:
		__remark.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DecreaseGameRunReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__tid = PBField.new("tid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tid
		data[__tid.tag] = service
		
		__amount = PBField.new("amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service
		
	var data = {}
	
	var __tid: PBField
	func get_tid() -> int:
		return __tid.value
	func clear_tid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tid(value : int) -> void:
		__tid.value = value
	
	var __amount: PBField
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_amount(value : int) -> void:
		__amount.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DecreaseGameRunResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__tid = PBField.new("tid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tid
		data[__tid.tag] = service
		
		__remain = PBField.new("remain", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __remain
		data[__remain.tag] = service
		
	var data = {}
	
	var __tid: PBField
	func get_tid() -> int:
		return __tid.value
	func clear_tid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tid(value : int) -> void:
		__tid.value = value
	
	var __remain: PBField
	func get_remain() -> int:
		return __remain.value
	func clear_remain() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__remain.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_remain(value : int) -> void:
		__remain.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetRecordResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__tid = PBField.new("tid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tid
		data[__tid.tag] = service
		
		__startTimeStamp = PBField.new("startTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __startTimeStamp
		data[__startTimeStamp.tag] = service
		
		__endTimeStamp = PBField.new("endTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __endTimeStamp
		data[__endTimeStamp.tag] = service
		
		var __innings_default: Array[InningInfo] = []
		__innings = PBField.new("innings", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 5, true, __innings_default)
		service = PBServiceField.new()
		service.field = __innings
		service.func_ref = Callable(self, "add_innings")
		data[__innings.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __uid: PBField
	func get_uid() -> int:
		return __uid.value
	func clear_uid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_uid(value : int) -> void:
		__uid.value = value
	
	var __tid: PBField
	func get_tid() -> int:
		return __tid.value
	func clear_tid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tid(value : int) -> void:
		__tid.value = value
	
	var __startTimeStamp: PBField
	func get_startTimeStamp() -> int:
		return __startTimeStamp.value
	func clear_startTimeStamp() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__startTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_startTimeStamp(value : int) -> void:
		__startTimeStamp.value = value
	
	var __endTimeStamp: PBField
	func get_endTimeStamp() -> int:
		return __endTimeStamp.value
	func clear_endTimeStamp() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__endTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_endTimeStamp(value : int) -> void:
		__endTimeStamp.value = value
	
	var __innings: PBField
	func get_innings() -> Array[InningInfo]:
		return __innings.value
	func clear_innings() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__innings.value = []
	func add_innings() -> InningInfo:
		var element = InningInfo.new()
		__innings.value.append(element)
		return element
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__pageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pageNum(value : int) -> void:
		__pageNum.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetInningsInfoReq:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetInningsInfoResp:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		var __innings_default: Array[InningInfo] = []
		__innings = PBField.new("innings", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __innings_default)
		service = PBServiceField.new()
		service.field = __innings
		service.func_ref = Callable(self, "add_innings")
		data[__innings.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __innings: PBField
	func get_innings() -> Array[InningInfo]:
		return __innings.value
	func clear_innings() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__innings.value = []
	func add_innings() -> InningInfo:
		var element = InningInfo.new()
		__innings.value.append(element)
		return element
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pageNum(value : int) -> void:
		__pageNum.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
enum NodeState {
	Open = 0,
	Maintain = 1,
	Closed = 2
}

enum NTFLevel {
	GeneralNTF = 0,
	UrgencyNTF = 1,
	NTMaintainNTF = 2,
	ServeStopNTF = 3,
	PraiseNTF = 4,
	STrumpetNTF = 5,
	MTrumpetNTF = 6,
	BTrumpetNTF = 7
}

enum RoomLevel {
	GeneralRoom = 0,
	MiddleRoom = 1,
	HighRoom = 2,
	TopRoom = 3,
	SuperRoom = 4,
	SystemRoom = 5
}

enum PlayerState {
	PlayerLookOn = 0,
	PlayerSitDown = 1,
	PlayerReady = 2,
	PlayerSetTime = 3,
	PlayerAgree = 4,
	PlayerWaiting = 5,
	PlayerPlaying = 6,
	PlayerPickUp = 7,
	PlayerCall = 8,
	PlayerFollow = 9,
	PlayerRaise = 10,
	PlayerLook = 11,
	PlayerCompare = 12,
	PlayerCompareLose = 13,
	PlayerOutCard = 14,
	PlayerMingPai = 15,
	PlayerPass = 16,
	PlayerChi = 17,
	PlayerPong = 18,
	PlayerMingGang = 19,
	PlayerAnGang = 20,
	PlayerTing = 21,
	PlayerHu = 22,
	PlayerZiMo = 23,
	PlayerTrustee = 24,
	PlayerGiveUp = 25,
	PlayerStandUp = 26
}

enum GameState {
	InitTB = 0,
	OpenTB = 1,
	RepairTB = 2,
	CloseTB = 3,
	ClearTB = 4,
	StopTB = 5
}

enum GameScene {
	Free = 0,
	Ready = 1,
	Setting = 2,
	Confirm = 3,
	Start = 4,
	Call = 5,
	Decide = 6,
	SitDirect = 7,
	RollDice = 8,
	ChangeThree = 9,
	DingQue = 10,
	Playing = 11,
	WaitOperate = 12,
	CheckTing = 13,
	CheckHuaZHu = 14,
	Opening = 15,
	Over = 16,
	Closing = 17
}

enum Direct {
	Centre = 0,
	EAST = 1,
	South = 2,
	West = 3,
	North = 4,
	EASTSouth = 5,
	WestSouth = 6,
	EASTNorth = 7,
	WestNorth = 8
}

enum MJOperate {
	MjNull = 0,
	MjPass = 1,
	MjChi = 2,
	MjPong = 3,
	MjGang = 4,
	MjMingGang = 5,
	MjAnGang = 6,
	MjBuHua = 7,
	MjTing = 8,
	MjHu = 9,
	MjZiMo = 10
}

enum PHZOperate {
	PhzNull = 0,
	PhzTi = 1,
	PhzWei = 2,
	PhzHe = 3,
	PhzPao = 4,
	PhzPong = 5,
	PhzChi = 6
}

class UserFullInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
		__faceID = PBField.new("faceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __faceID
		data[__faceID.tag] = service
		
		__gender = PBField.new("gender", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __gender
		data[__gender.tag] = service
		
		__age = PBField.new("age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __age
		data[__age.tag] = service
		
		__empiric = PBField.new("empiric", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __empiric
		data[__empiric.tag] = service
		
		__vip = PBField.new("vip", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __vip
		data[__vip.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__yuanBao = PBField.new("yuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __yuanBao
		data[__yuanBao.tag] = service
		
		__coin = PBField.new("coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __coin
		data[__coin.tag] = service
		
		__money = PBField.new("money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __money
		data[__money.tag] = service
		
		__passPortID = PBField.new("passPortID", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __passPortID
		data[__passPortID.tag] = service
		
		__realName = PBField.new("realName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __realName
		data[__realName.tag] = service
		
		__phoneNum = PBField.new("phoneNum", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __phoneNum
		data[__phoneNum.tag] = service
		
		__email = PBField.new("email", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __email
		data[__email.tag] = service
		
		__address = PBField.new("address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __address
		data[__address.tag] = service
		
		__identity = PBField.new("identity", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 19, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __identity
		data[__identity.tag] = service
		
		__agentID = PBField.new("agentID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __agentID
		data[__agentID.tag] = service
		
		__referralCode = PBField.new("referralCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __referralCode
		data[__referralCode.tag] = service
		
		__clientAddr = PBField.new("clientAddr", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 22, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __clientAddr
		data[__clientAddr.tag] = service
		
		__serverAddr = PBField.new("serverAddr", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 23, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __serverAddr
		data[__serverAddr.tag] = service
		
		__machineCode = PBField.new("machineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 24, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __machineCode
		data[__machineCode.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __account: PBField
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	var __faceID: PBField
	func get_faceID() -> int:
		return __faceID.value
	func clear_faceID() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__faceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_faceID(value : int) -> void:
		__faceID.value = value
	
	var __gender: PBField
	func get_gender() -> int:
		return __gender.value
	func clear_gender() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__gender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_gender(value : int) -> void:
		__gender.value = value
	
	var __age: PBField
	func get_age() -> int:
		return __age.value
	func clear_age() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_age(value : int) -> void:
		__age.value = value
	
	var __empiric: PBField
	func get_empiric() -> int:
		return __empiric.value
	func clear_empiric() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__empiric.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_empiric(value : int) -> void:
		__empiric.value = value
	
	var __vip: PBField
	func get_vip() -> int:
		return __vip.value
	func clear_vip() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__vip.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_vip(value : int) -> void:
		__vip.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __yuanBao: PBField
	func get_yuanBao() -> int:
		return __yuanBao.value
	func clear_yuanBao() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__yuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_yuanBao(value : int) -> void:
		__yuanBao.value = value
	
	var __coin: PBField
	func get_coin() -> int:
		return __coin.value
	func clear_coin() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_coin(value : int) -> void:
		__coin.value = value
	
	var __money: PBField
	func get_money() -> int:
		return __money.value
	func clear_money() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_money(value : int) -> void:
		__money.value = value
	
	var __passPortID: PBField
	func get_passPortID() -> String:
		return __passPortID.value
	func clear_passPortID() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__passPortID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_passPortID(value : String) -> void:
		__passPortID.value = value
	
	var __realName: PBField
	func get_realName() -> String:
		return __realName.value
	func clear_realName() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__realName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_realName(value : String) -> void:
		__realName.value = value
	
	var __phoneNum: PBField
	func get_phoneNum() -> String:
		return __phoneNum.value
	func clear_phoneNum() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__phoneNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_phoneNum(value : String) -> void:
		__phoneNum.value = value
	
	var __email: PBField
	func get_email() -> String:
		return __email.value
	func clear_email() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__email.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_email(value : String) -> void:
		__email.value = value
	
	var __address: PBField
	func get_address() -> String:
		return __address.value
	func clear_address() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_address(value : String) -> void:
		__address.value = value
	
	var __identity: PBField
	func get_identity() -> String:
		return __identity.value
	func clear_identity() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__identity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_identity(value : String) -> void:
		__identity.value = value
	
	var __agentID: PBField
	func get_agentID() -> int:
		return __agentID.value
	func clear_agentID() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__agentID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_agentID(value : int) -> void:
		__agentID.value = value
	
	var __referralCode: PBField
	func get_referralCode() -> String:
		return __referralCode.value
	func clear_referralCode() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__referralCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_referralCode(value : String) -> void:
		__referralCode.value = value
	
	var __clientAddr: PBField
	func get_clientAddr() -> String:
		return __clientAddr.value
	func clear_clientAddr() -> void:
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__clientAddr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_clientAddr(value : String) -> void:
		__clientAddr.value = value
	
	var __serverAddr: PBField
	func get_serverAddr() -> String:
		return __serverAddr.value
	func clear_serverAddr() -> void:
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__serverAddr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_serverAddr(value : String) -> void:
		__serverAddr.value = value
	
	var __machineCode: PBField
	func get_machineCode() -> String:
		return __machineCode.value
	func clear_machineCode() -> void:
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__machineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_machineCode(value : String) -> void:
		__machineCode.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class UserInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__faceID = PBField.new("faceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __faceID
		data[__faceID.tag] = service
		
		__gender = PBField.new("gender", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __gender
		data[__gender.tag] = service
		
		__age = PBField.new("age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __age
		data[__age.tag] = service
		
		__empirice = PBField.new("empirice", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __empirice
		data[__empirice.tag] = service
		
		__vip = PBField.new("vip", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __vip
		data[__vip.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__yuanBao = PBField.new("yuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __yuanBao
		data[__yuanBao.tag] = service
		
		__coin = PBField.new("coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __coin
		data[__coin.tag] = service
		
		__money = PBField.new("money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __money
		data[__money.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __account: PBField
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __faceID: PBField
	func get_faceID() -> int:
		return __faceID.value
	func clear_faceID() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__faceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_faceID(value : int) -> void:
		__faceID.value = value
	
	var __gender: PBField
	func get_gender() -> int:
		return __gender.value
	func clear_gender() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__gender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_gender(value : int) -> void:
		__gender.value = value
	
	var __age: PBField
	func get_age() -> int:
		return __age.value
	func clear_age() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_age(value : int) -> void:
		__age.value = value
	
	var __empirice: PBField
	func get_empirice() -> int:
		return __empirice.value
	func clear_empirice() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__empirice.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_empirice(value : int) -> void:
		__empirice.value = value
	
	var __vip: PBField
	func get_vip() -> int:
		return __vip.value
	func clear_vip() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__vip.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_vip(value : int) -> void:
		__vip.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __yuanBao: PBField
	func get_yuanBao() -> int:
		return __yuanBao.value
	func clear_yuanBao() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__yuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_yuanBao(value : int) -> void:
		__yuanBao.value = value
	
	var __coin: PBField
	func get_coin() -> int:
		return __coin.value
	func clear_coin() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_coin(value : int) -> void:
		__coin.value = value
	
	var __money: PBField
	func get_money() -> int:
		return __money.value
	func clear_money() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_money(value : int) -> void:
		__money.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__faceID = PBField.new("faceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __faceID
		data[__faceID.tag] = service
		
		__age = PBField.new("age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __age
		data[__age.tag] = service
		
		__sex = PBField.new("sex", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __sex
		data[__sex.tag] = service
		
		__yuanBao = PBField.new("yuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __yuanBao
		data[__yuanBao.tag] = service
		
		__coin = PBField.new("coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __coin
		data[__coin.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__ranking = PBField.new("ranking", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __ranking
		data[__ranking.tag] = service
		
		__state = PBField.new("state", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __state
		data[__state.tag] = service
		
		__gold = PBField.new("gold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gold
		data[__gold.tag] = service
		
		__money = PBField.new("money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __money
		data[__money.tag] = service
		
		__loginTime = PBField.new("loginTime", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __loginTime
		data[__loginTime.tag] = service
		
		__leaveTime = PBField.new("leaveTime", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __leaveTime
		data[__leaveTime.tag] = service
		
		__inRooId = PBField.new("inRooId", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __inRooId
		data[__inRooId.tag] = service
		
		__inTableId = PBField.new("inTableId", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __inTableId
		data[__inTableId.tag] = service
		
		__inChairId = PBField.new("inChairId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __inChairId
		data[__inChairId.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __account: PBField
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __faceID: PBField
	func get_faceID() -> int:
		return __faceID.value
	func clear_faceID() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__faceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_faceID(value : int) -> void:
		__faceID.value = value
	
	var __age: PBField
	func get_age() -> int:
		return __age.value
	func clear_age() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_age(value : int) -> void:
		__age.value = value
	
	var __sex: PBField
	func get_sex() -> int:
		return __sex.value
	func clear_sex() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__sex.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sex(value : int) -> void:
		__sex.value = value
	
	var __yuanBao: PBField
	func get_yuanBao() -> int:
		return __yuanBao.value
	func clear_yuanBao() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__yuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_yuanBao(value : int) -> void:
		__yuanBao.value = value
	
	var __coin: PBField
	func get_coin() -> int:
		return __coin.value
	func clear_coin() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_coin(value : int) -> void:
		__coin.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __ranking: PBField
	func get_ranking() -> int:
		return __ranking.value
	func clear_ranking() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ranking.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_ranking(value : int) -> void:
		__ranking.value = value
	
	var __state: PBField
	func get_state():
		return __state.value
	func clear_state() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_state(value) -> void:
		__state.value = value
	
	var __gold: PBField
	func get_gold() -> int:
		return __gold.value
	func clear_gold() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__gold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gold(value : int) -> void:
		__gold.value = value
	
	var __money: PBField
	func get_money() -> int:
		return __money.value
	func clear_money() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_money(value : int) -> void:
		__money.value = value
	
	var __loginTime: PBField
	func get_loginTime() -> int:
		return __loginTime.value
	func clear_loginTime() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__loginTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_loginTime(value : int) -> void:
		__loginTime.value = value
	
	var __leaveTime: PBField
	func get_leaveTime() -> int:
		return __leaveTime.value
	func clear_leaveTime() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__leaveTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_leaveTime(value : int) -> void:
		__leaveTime.value = value
	
	var __inRooId: PBField
	func get_inRooId() -> int:
		return __inRooId.value
	func clear_inRooId() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__inRooId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_inRooId(value : int) -> void:
		__inRooId.value = value
	
	var __inTableId: PBField
	func get_inTableId() -> int:
		return __inTableId.value
	func clear_inTableId() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__inTableId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_inTableId(value : int) -> void:
		__inTableId.value = value
	
	var __inChairId: PBField
	func get_inChairId() -> int:
		return __inChairId.value
	func clear_inChairId() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__inChairId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_inChairId(value : int) -> void:
		__inChairId.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerSimpleInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__headId = PBField.new("headId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __headId
		data[__headId.tag] = service
		
		__chairId = PBField.new("chairId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __chairId
		data[__chairId.tag] = service
		
		__score = PBField.new("score", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __score
		data[__score.tag] = service
		
		__rankNo = PBField.new("rankNo", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __rankNo
		data[__rankNo.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
	var data = {}
	
	var __uid: PBField
	func get_uid() -> int:
		return __uid.value
	func clear_uid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_uid(value : int) -> void:
		__uid.value = value
	
	var __headId: PBField
	func get_headId() -> int:
		return __headId.value
	func clear_headId() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__headId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_headId(value : int) -> void:
		__headId.value = value
	
	var __chairId: PBField
	func get_chairId() -> int:
		return __chairId.value
	func clear_chairId() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__chairId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_chairId(value : int) -> void:
		__chairId.value = value
	
	var __score: PBField
	func get_score() -> int:
		return __score.value
	func clear_score() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_score(value : int) -> void:
		__score.value = value
	
	var __rankNo: PBField
	func get_rankNo() -> int:
		return __rankNo.value
	func clear_rankNo() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__rankNo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_rankNo(value : int) -> void:
		__rankNo.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class HeroInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__headId = PBField.new("headId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __headId
		data[__headId.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__sex = PBField.new("sex", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __sex
		data[__sex.tag] = service
		
		__rarity = PBField.new("rarity", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __rarity
		data[__rarity.tag] = service
		
		__faction = PBField.new("faction", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __faction
		data[__faction.tag] = service
		
		__healthPoint = PBField.new("healthPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __healthPoint
		data[__healthPoint.tag] = service
		
		__healthPointFull = PBField.new("healthPointFull", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __healthPointFull
		data[__healthPointFull.tag] = service
		
		__strength = PBField.new("strength", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __strength
		data[__strength.tag] = service
		
		__agility = PBField.new("agility", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __agility
		data[__agility.tag] = service
		
		__intelligence = PBField.new("intelligence", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __intelligence
		data[__intelligence.tag] = service
		
		__attackPoint = PBField.new("attackPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __attackPoint
		data[__attackPoint.tag] = service
		
		__armorPoint = PBField.new("armorPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __armorPoint
		data[__armorPoint.tag] = service
		
		__spellPower = PBField.new("spellPower", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __spellPower
		data[__spellPower.tag] = service
		
		var __skills_default: Array[int] = []
		__skills = PBField.new("skills", PB_DATA_TYPE.INT64, PB_RULE.REPEATED, 15, true, __skills_default)
		service = PBServiceField.new()
		service.field = __skills
		data[__skills.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __headId: PBField
	func get_headId() -> int:
		return __headId.value
	func clear_headId() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__headId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_headId(value : int) -> void:
		__headId.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __sex: PBField
	func get_sex() -> int:
		return __sex.value
	func clear_sex() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__sex.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sex(value : int) -> void:
		__sex.value = value
	
	var __rarity: PBField
	func get_rarity() -> int:
		return __rarity.value
	func clear_rarity() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__rarity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_rarity(value : int) -> void:
		__rarity.value = value
	
	var __faction: PBField
	func get_faction() -> int:
		return __faction.value
	func clear_faction() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__faction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_faction(value : int) -> void:
		__faction.value = value
	
	var __healthPoint: PBField
	func get_healthPoint() -> int:
		return __healthPoint.value
	func clear_healthPoint() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__healthPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_healthPoint(value : int) -> void:
		__healthPoint.value = value
	
	var __healthPointFull: PBField
	func get_healthPointFull() -> int:
		return __healthPointFull.value
	func clear_healthPointFull() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__healthPointFull.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_healthPointFull(value : int) -> void:
		__healthPointFull.value = value
	
	var __strength: PBField
	func get_strength() -> int:
		return __strength.value
	func clear_strength() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__strength.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_strength(value : int) -> void:
		__strength.value = value
	
	var __agility: PBField
	func get_agility() -> int:
		return __agility.value
	func clear_agility() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__agility.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_agility(value : int) -> void:
		__agility.value = value
	
	var __intelligence: PBField
	func get_intelligence() -> int:
		return __intelligence.value
	func clear_intelligence() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__intelligence.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_intelligence(value : int) -> void:
		__intelligence.value = value
	
	var __attackPoint: PBField
	func get_attackPoint() -> int:
		return __attackPoint.value
	func clear_attackPoint() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__attackPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_attackPoint(value : int) -> void:
		__attackPoint.value = value
	
	var __armorPoint: PBField
	func get_armorPoint() -> int:
		return __armorPoint.value
	func clear_armorPoint() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__armorPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_armorPoint(value : int) -> void:
		__armorPoint.value = value
	
	var __spellPower: PBField
	func get_spellPower() -> int:
		return __spellPower.value
	func clear_spellPower() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__spellPower.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_spellPower(value : int) -> void:
		__spellPower.value = value
	
	var __skills: PBField
	func get_skills() -> Array[int]:
		return __skills.value
	func clear_skills() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__skills.value = []
	func add_skills(value : int) -> void:
		__skills.value.append(value)
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class WeaponInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__type = PBField.new("type", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __type
		data[__type.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__damage = PBField.new("damage", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __damage
		data[__damage.tag] = service
		
		__prob = PBField.new("prob", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __prob
		data[__prob.tag] = service
		
		__count = PBField.new("count", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __count
		data[__count.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __type: PBField
	func get_type() -> int:
		return __type.value
	func clear_type() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_type(value : int) -> void:
		__type.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __damage: PBField
	func get_damage() -> int:
		return __damage.value
	func clear_damage() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_damage(value : int) -> void:
		__damage.value = value
	
	var __prob: PBField
	func get_prob() -> int:
		return __prob.value
	func clear_prob() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__prob.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_prob(value : int) -> void:
		__prob.value = value
	
	var __count: PBField
	func get_count() -> int:
		return __count.value
	func clear_count() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__count.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_count(value : int) -> void:
		__count.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GoodsInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__kind = PBField.new("kind", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __kind
		data[__kind.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__price = PBField.new("price", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __price
		data[__price.tag] = service
		
		__store = PBField.new("store", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __store
		data[__store.tag] = service
		
		__sold = PBField.new("sold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __sold
		data[__sold.tag] = service
		
		__amount = PBField.new("amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __kind: PBField
	func get_kind() -> int:
		return __kind.value
	func clear_kind() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__kind.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_kind(value : int) -> void:
		__kind.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __price: PBField
	func get_price() -> int:
		return __price.value
	func clear_price() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__price.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_price(value : int) -> void:
		__price.value = value
	
	var __store: PBField
	func get_store() -> int:
		return __store.value
	func clear_store() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__store.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_store(value : int) -> void:
		__store.value = value
	
	var __sold: PBField
	func get_sold() -> int:
		return __sold.value
	func clear_sold() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__sold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_sold(value : int) -> void:
		__sold.value = value
	
	var __amount: PBField
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_amount(value : int) -> void:
		__amount.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class KnapsackInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		var __weaponryList_default: Array[WeaponInfo] = []
		__weaponryList = PBField.new("weaponryList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 4, true, __weaponryList_default)
		service = PBServiceField.new()
		service.field = __weaponryList
		service.func_ref = Callable(self, "add_weaponryList")
		data[__weaponryList.tag] = service
		
		var __goodsList_default: Array[GoodsInfo] = []
		__goodsList = PBField.new("goodsList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 5, true, __goodsList_default)
		service = PBServiceField.new()
		service.field = __goodsList
		service.func_ref = Callable(self, "add_goodsList")
		data[__goodsList.tag] = service
		
		var __heroList_default: Array[HeroInfo] = []
		__heroList = PBField.new("heroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 6, true, __heroList_default)
		service = PBServiceField.new()
		service.field = __heroList
		service.func_ref = Callable(self, "add_heroList")
		data[__heroList.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __uid: PBField
	func get_uid() -> int:
		return __uid.value
	func clear_uid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_uid(value : int) -> void:
		__uid.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __weaponryList: PBField
	func get_weaponryList() -> Array[WeaponInfo]:
		return __weaponryList.value
	func clear_weaponryList() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__weaponryList.value = []
	func add_weaponryList() -> WeaponInfo:
		var element = WeaponInfo.new()
		__weaponryList.value.append(element)
		return element
	
	var __goodsList: PBField
	func get_goodsList() -> Array[GoodsInfo]:
		return __goodsList.value
	func clear_goodsList() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__goodsList.value = []
	func add_goodsList() -> GoodsInfo:
		var element = GoodsInfo.new()
		__goodsList.value.append(element)
		return element
	
	var __heroList: PBField
	func get_heroList() -> Array[HeroInfo]:
		return __heroList.value
	func clear_heroList() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__heroList.value = []
	func add_heroList() -> HeroInfo:
		var element = HeroInfo.new()
		__heroList.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EmailInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__emailID = PBField.new("emailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __emailID
		data[__emailID.tag] = service
		
		__acceptName = PBField.new("acceptName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __acceptName
		data[__acceptName.tag] = service
		
		__sender = PBField.new("sender", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __sender
		data[__sender.tag] = service
		
		__cc = PBField.new("cc", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __cc
		data[__cc.tag] = service
		
		__topic = PBField.new("topic", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __topic
		data[__topic.tag] = service
		
		__content = PBField.new("content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __content
		data[__content.tag] = service
		
		__isRead = PBField.new("isRead", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isRead
		data[__isRead.tag] = service
		
		__awardList = PBField.new("awardList", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __awardList
		service.func_ref = Callable(self, "new_awardList")
		data[__awardList.tag] = service
		
		__timeStamp = PBField.new("timeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __timeStamp
		data[__timeStamp.tag] = service
		
	var data = {}
	
	var __emailID: PBField
	func get_emailID() -> int:
		return __emailID.value
	func clear_emailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__emailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_emailID(value : int) -> void:
		__emailID.value = value
	
	var __acceptName: PBField
	func get_acceptName() -> String:
		return __acceptName.value
	func clear_acceptName() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__acceptName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_acceptName(value : String) -> void:
		__acceptName.value = value
	
	var __sender: PBField
	func get_sender() -> String:
		return __sender.value
	func clear_sender() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__sender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_sender(value : String) -> void:
		__sender.value = value
	
	var __cc: PBField
	func get_cc() -> String:
		return __cc.value
	func clear_cc() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__cc.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_cc(value : String) -> void:
		__cc.value = value
	
	var __topic: PBField
	func get_topic() -> String:
		return __topic.value
	func clear_topic() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__topic.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_topic(value : String) -> void:
		__topic.value = value
	
	var __content: PBField
	func get_content() -> String:
		return __content.value
	func clear_content() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__content.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_content(value : String) -> void:
		__content.value = value
	
	var __isRead: PBField
	func get_isRead() -> bool:
		return __isRead.value
	func clear_isRead() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__isRead.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isRead(value : bool) -> void:
		__isRead.value = value
	
	var __awardList: PBField
	func get_awardList() -> GoodsList:
		return __awardList.value
	func clear_awardList() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__awardList.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_awardList() -> GoodsList:
		__awardList.value = GoodsList.new()
		return __awardList.value
	
	var __timeStamp: PBField
	func get_timeStamp() -> int:
		return __timeStamp.value
	func clear_timeStamp() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__timeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_timeStamp(value : int) -> void:
		__timeStamp.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RoomInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__hostId = PBField.new("hostId", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __hostId
		data[__hostId.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__roomKey = PBField.new("roomKey", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __roomKey
		data[__roomKey.tag] = service
		
		__enterScore = PBField.new("enterScore", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __enterScore
		data[__enterScore.tag] = service
		
		__taxation = PBField.new("taxation", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __taxation
		data[__taxation.tag] = service
		
		__maxPerson = PBField.new("maxPerson", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __maxPerson
		data[__maxPerson.tag] = service
		
		__tableCount = PBField.new("tableCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __tableCount
		data[__tableCount.tag] = service
		
		__maxTable = PBField.new("maxTable", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __maxTable
		data[__maxTable.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __hostId: PBField
	func get_hostId() -> int:
		return __hostId.value
	func clear_hostId() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__hostId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_hostId(value : int) -> void:
		__hostId.value = value
	
	var __level: PBField
	func get_level():
		return __level.value
	func clear_level() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_level(value) -> void:
		__level.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __roomKey: PBField
	func get_roomKey() -> String:
		return __roomKey.value
	func clear_roomKey() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__roomKey.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_roomKey(value : String) -> void:
		__roomKey.value = value
	
	var __enterScore: PBField
	func get_enterScore() -> int:
		return __enterScore.value
	func clear_enterScore() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__enterScore.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_enterScore(value : int) -> void:
		__enterScore.value = value
	
	var __taxation: PBField
	func get_taxation() -> int:
		return __taxation.value
	func clear_taxation() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__taxation.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_taxation(value : int) -> void:
		__taxation.value = value
	
	var __maxPerson: PBField
	func get_maxPerson() -> int:
		return __maxPerson.value
	func clear_maxPerson() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__maxPerson.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_maxPerson(value : int) -> void:
		__maxPerson.value = value
	
	var __tableCount: PBField
	func get_tableCount() -> int:
		return __tableCount.value
	func clear_tableCount() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__tableCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_tableCount(value : int) -> void:
		__tableCount.value = value
	
	var __maxTable: PBField
	func get_maxTable() -> int:
		return __maxTable.value
	func clear_maxTable() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__maxTable.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_maxTable(value : int) -> void:
		__maxTable.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TableInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__isLock = PBField.new("isLock", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isLock
		data[__isLock.tag] = service
		
		__isLookOn = PBField.new("isLookOn", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isLookOn
		data[__isLookOn.tag] = service
		
		__rid = PBField.new("rid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __rid
		data[__rid.tag] = service
		
		__gid = PBField.new("gid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gid
		data[__gid.tag] = service
		
		__commission = PBField.new("commission", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __commission
		data[__commission.tag] = service
		
		__maxRound = PBField.new("maxRound", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __maxRound
		data[__maxRound.tag] = service
		
		__remain = PBField.new("remain", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __remain
		data[__remain.tag] = service
		
		__state = PBField.new("state", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __state
		data[__state.tag] = service
		
		__mode = PBField.new("mode", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __mode
		data[__mode.tag] = service
		
		__section = PBField.new("section", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __section
		data[__section.tag] = service
		
		__sitCount = PBField.new("sitCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __sitCount
		data[__sitCount.tag] = service
		
		__maxSitter = PBField.new("maxSitter", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __maxSitter
		data[__maxSitter.tag] = service
		
		__enterScore = PBField.new("enterScore", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __enterScore
		data[__enterScore.tag] = service
		
		__baseScore = PBField.new("baseScore", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __baseScore
		data[__baseScore.tag] = service
		
		__openTime = PBField.new("openTime", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __openTime
		data[__openTime.tag] = service
		
		__closeTime = PBField.new("closeTime", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __closeTime
		data[__closeTime.tag] = service
		
		__creatorId = PBField.new("creatorId", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __creatorId
		data[__creatorId.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 19, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__creator = PBField.new("creator", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __creator
		data[__creator.tag] = service
		
		__description = PBField.new("description", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __description
		data[__description.tag] = service
		
		__mid = PBField.new("mid", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 22, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __mid
		data[__mid.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __isLock: PBField
	func get_isLock() -> bool:
		return __isLock.value
	func clear_isLock() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__isLock.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isLock(value : bool) -> void:
		__isLock.value = value
	
	var __isLookOn: PBField
	func get_isLookOn() -> bool:
		return __isLookOn.value
	func clear_isLookOn() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__isLookOn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isLookOn(value : bool) -> void:
		__isLookOn.value = value
	
	var __rid: PBField
	func get_rid() -> int:
		return __rid.value
	func clear_rid() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__rid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_rid(value : int) -> void:
		__rid.value = value
	
	var __gid: PBField
	func get_gid() -> int:
		return __gid.value
	func clear_gid() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__gid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gid(value : int) -> void:
		__gid.value = value
	
	var __commission: PBField
	func get_commission() -> int:
		return __commission.value
	func clear_commission() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__commission.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_commission(value : int) -> void:
		__commission.value = value
	
	var __maxRound: PBField
	func get_maxRound() -> int:
		return __maxRound.value
	func clear_maxRound() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__maxRound.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_maxRound(value : int) -> void:
		__maxRound.value = value
	
	var __remain: PBField
	func get_remain() -> int:
		return __remain.value
	func clear_remain() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__remain.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_remain(value : int) -> void:
		__remain.value = value
	
	var __state: PBField
	func get_state() -> int:
		return __state.value
	func clear_state() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_state(value : int) -> void:
		__state.value = value
	
	var __mode: PBField
	func get_mode() -> int:
		return __mode.value
	func clear_mode() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_mode(value : int) -> void:
		__mode.value = value
	
	var __section: PBField
	func get_section() -> int:
		return __section.value
	func clear_section() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__section.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_section(value : int) -> void:
		__section.value = value
	
	var __sitCount: PBField
	func get_sitCount() -> int:
		return __sitCount.value
	func clear_sitCount() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__sitCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sitCount(value : int) -> void:
		__sitCount.value = value
	
	var __maxSitter: PBField
	func get_maxSitter() -> int:
		return __maxSitter.value
	func clear_maxSitter() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__maxSitter.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_maxSitter(value : int) -> void:
		__maxSitter.value = value
	
	var __enterScore: PBField
	func get_enterScore() -> int:
		return __enterScore.value
	func clear_enterScore() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__enterScore.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_enterScore(value : int) -> void:
		__enterScore.value = value
	
	var __baseScore: PBField
	func get_baseScore() -> int:
		return __baseScore.value
	func clear_baseScore() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__baseScore.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_baseScore(value : int) -> void:
		__baseScore.value = value
	
	var __openTime: PBField
	func get_openTime() -> int:
		return __openTime.value
	func clear_openTime() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__openTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_openTime(value : int) -> void:
		__openTime.value = value
	
	var __closeTime: PBField
	func get_closeTime() -> int:
		return __closeTime.value
	func clear_closeTime() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__closeTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_closeTime(value : int) -> void:
		__closeTime.value = value
	
	var __creatorId: PBField
	func get_creatorId() -> String:
		return __creatorId.value
	func clear_creatorId() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__creatorId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_creatorId(value : String) -> void:
		__creatorId.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __creator: PBField
	func get_creator() -> String:
		return __creator.value
	func clear_creator() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__creator.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_creator(value : String) -> void:
		__creator.value = value
	
	var __description: PBField
	func get_description() -> String:
		return __description.value
	func clear_description() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__description.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_description(value : String) -> void:
		__description.value = value
	
	var __mid: PBField
	func get_mid() -> String:
		return __mid.value
	func clear_mid() -> void:
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__mid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_mid(value : String) -> void:
		__mid.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MatchInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__mid = PBField.new("mid", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __mid
		data[__mid.tag] = service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__username = PBField.new("username", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __username
		data[__username.tag] = service
		
		__headicon = PBField.new("headicon", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __headicon
		data[__headicon.tag] = service
		
	var data = {}
	
	var __mid: PBField
	func get_mid() -> String:
		return __mid.value
	func clear_mid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__mid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_mid(value : String) -> void:
		__mid.value = value
	
	var __uid: PBField
	func get_uid() -> String:
		return __uid.value
	func clear_uid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_uid(value : String) -> void:
		__uid.value = value
	
	var __username: PBField
	func get_username() -> String:
		return __username.value
	func clear_username() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__username.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_username(value : String) -> void:
		__username.value = value
	
	var __headicon: PBField
	func get_headicon() -> String:
		return __headicon.value
	func clear_headicon() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__headicon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_headicon(value : String) -> void:
		__headicon.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClubApplyInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__status = PBField.new("status", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __status
		data[__status.tag] = service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __status: PBField
	func get_status() -> int:
		return __status.value
	func clear_status() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_status(value : int) -> void:
		__status.value = value
	
	var __info: PBField
	func get_info() -> UserInfo:
		return __info.value
	func clear_info() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> UserInfo:
		__info.value = UserInfo.new()
		return __info.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TimeInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__timeStamp = PBField.new("timeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __timeStamp
		data[__timeStamp.tag] = service
		
		__waitTime = PBField.new("waitTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __waitTime
		data[__waitTime.tag] = service
		
		__outTime = PBField.new("outTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __outTime
		data[__outTime.tag] = service
		
		__totalTime = PBField.new("totalTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __totalTime
		data[__totalTime.tag] = service
		
	var data = {}
	
	var __timeStamp: PBField
	func get_timeStamp() -> int:
		return __timeStamp.value
	func clear_timeStamp() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__timeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_timeStamp(value : int) -> void:
		__timeStamp.value = value
	
	var __waitTime: PBField
	func get_waitTime() -> int:
		return __waitTime.value
	func clear_waitTime() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__waitTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_waitTime(value : int) -> void:
		__waitTime.value = value
	
	var __outTime: PBField
	func get_outTime() -> int:
		return __outTime.value
	func clear_outTime() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__outTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_outTime(value : int) -> void:
		__outTime.value = value
	
	var __totalTime: PBField
	func get_totalTime() -> int:
		return __totalTime.value
	func clear_totalTime() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__totalTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_totalTime(value : int) -> void:
		__totalTime.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class InningInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__gameName = PBField.new("gameName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __gameName
		data[__gameName.tag] = service
		
		__number = PBField.new("number", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __number
		data[__number.tag] = service
		
		__winnerID = PBField.new("winnerID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __winnerID
		data[__winnerID.tag] = service
		
		__loserID = PBField.new("loserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __loserID
		data[__loserID.tag] = service
		
		__payoff = PBField.new("payoff", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __payoff
		data[__payoff.tag] = service
		
		__timeStamp = PBField.new("timeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __timeStamp
		data[__timeStamp.tag] = service
		
		__result = PBField.new("result", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __result
		data[__result.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __gameName: PBField
	func get_gameName() -> String:
		return __gameName.value
	func clear_gameName() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_gameName(value : String) -> void:
		__gameName.value = value
	
	var __number: PBField
	func get_number() -> String:
		return __number.value
	func clear_number() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__number.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_number(value : String) -> void:
		__number.value = value
	
	var __winnerID: PBField
	func get_winnerID() -> int:
		return __winnerID.value
	func clear_winnerID() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__winnerID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_winnerID(value : int) -> void:
		__winnerID.value = value
	
	var __loserID: PBField
	func get_loserID() -> int:
		return __loserID.value
	func clear_loserID() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__loserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_loserID(value : int) -> void:
		__loserID.value = value
	
	var __payoff: PBField
	func get_payoff() -> int:
		return __payoff.value
	func clear_payoff() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__payoff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_payoff(value : int) -> void:
		__payoff.value = value
	
	var __timeStamp: PBField
	func get_timeStamp() -> int:
		return __timeStamp.value
	func clear_timeStamp() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__timeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_timeStamp(value : int) -> void:
		__timeStamp.value = value
	
	var __result: PBField
	func get_result() -> String:
		return __result.value
	func clear_result() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__result.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_result(value : String) -> void:
		__result.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CardInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__cards = PBField.new("cards", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __cards
		data[__cards.tag] = service
		
		__cardType = PBField.new("cardType", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __cardType
		data[__cardType.tag] = service
		
		__cardValue = PBField.new("cardValue", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __cardValue
		data[__cardValue.tag] = service
		
	var data = {}
	
	var __cards: PBField
	func get_cards() -> PackedByteArray:
		return __cards.value
	func clear_cards() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__cards.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_cards(value : PackedByteArray) -> void:
		__cards.value = value
	
	var __cardType: PBField
	func get_cardType() -> int:
		return __cardType.value
	func clear_cardType() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__cardType.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_cardType(value : int) -> void:
		__cardType.value = value
	
	var __cardValue: PBField
	func get_cardValue() -> int:
		return __cardValue.value
	func clear_cardValue() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__cardValue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_cardValue(value : int) -> void:
		__cardValue.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AreaInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__myGold = PBField.new("myGold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __myGold
		data[__myGold.tag] = service
		
		__totalGold = PBField.new("totalGold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __totalGold
		data[__totalGold.tag] = service
		
		__awardGold = PBField.new("awardGold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __awardGold
		data[__awardGold.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __myGold: PBField
	func get_myGold() -> int:
		return __myGold.value
	func clear_myGold() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__myGold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_myGold(value : int) -> void:
		__myGold.value = value
	
	var __totalGold: PBField
	func get_totalGold() -> int:
		return __totalGold.value
	func clear_totalGold() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__totalGold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_totalGold(value : int) -> void:
		__totalGold.value = value
	
	var __awardGold: PBField
	func get_awardGold() -> int:
		return __awardGold.value
	func clear_awardGold() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__awardGold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_awardGold(value : int) -> void:
		__awardGold.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__kid = PBField.new("kid", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __kid
		data[__kid.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__lessscore = PBField.new("lessscore", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __lessscore
		data[__lessscore.tag] = service
		
		__scene = PBField.new("scene", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __scene
		data[__scene.tag] = service
		
		__state = PBField.new("state", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __state
		data[__state.tag] = service
		
		__maxPlayer = PBField.new("maxPlayer", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __maxPlayer
		data[__maxPlayer.tag] = service
		
		__howToPlay = PBField.new("howToPlay", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __howToPlay
		data[__howToPlay.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __kid: PBField
	func get_kid() -> int:
		return __kid.value
	func clear_kid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__kid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_kid(value : int) -> void:
		__kid.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __lessscore: PBField
	func get_lessscore() -> int:
		return __lessscore.value
	func clear_lessscore() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__lessscore.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_lessscore(value : int) -> void:
		__lessscore.value = value
	
	var __scene: PBField
	func get_scene():
		return __scene.value
	func clear_scene() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__scene.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_scene(value) -> void:
		__scene.value = value
	
	var __state: PBField
	func get_state():
		return __state.value
	func clear_state() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_state(value) -> void:
		__state.value = value
	
	var __maxPlayer: PBField
	func get_maxPlayer() -> int:
		return __maxPlayer.value
	func clear_maxPlayer() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__maxPlayer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_maxPlayer(value : int) -> void:
		__maxPlayer.value = value
	
	var __howToPlay: PBField
	func get_howToPlay() -> String:
		return __howToPlay.value
	func clear_howToPlay() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__howToPlay.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_howToPlay(value : String) -> void:
		__howToPlay.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameRecord:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__gameInfo = PBField.new("gameInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __gameInfo
		service.func_ref = Callable(self, "new_gameInfo")
		data[__gameInfo.tag] = service
		
		__cardInfo = PBField.new("cardInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __cardInfo
		service.func_ref = Callable(self, "new_cardInfo")
		data[__cardInfo.tag] = service
		
	var data = {}
	
	var __gameInfo: PBField
	func get_gameInfo() -> GameInfo:
		return __gameInfo.value
	func clear_gameInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_gameInfo() -> GameInfo:
		__gameInfo.value = GameInfo.new()
		return __gameInfo.value
	
	var __cardInfo: PBField
	func get_cardInfo() -> CardInfo:
		return __cardInfo.value
	func clear_cardInfo() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__cardInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_cardInfo() -> CardInfo:
		__cardInfo.value = CardInfo.new()
		return __cardInfo.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameRecordList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __list_default: Array[GameRecord] = []
		__list = PBField.new("list", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __list_default)
		service = PBServiceField.new()
		service.field = __list
		service.func_ref = Callable(self, "add_list")
		data[__list.tag] = service
		
	var data = {}
	
	var __list: PBField
	func get_list() -> Array[GameRecord]:
		return __list.value
	func clear_list() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__list.value = []
	func add_list() -> GameRecord:
		var element = GameRecord.new()
		__list.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MasterInfo:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__userInfo = PBField.new("userInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __userInfo
		service.func_ref = Callable(self, "new_userInfo")
		data[__userInfo.tag] = service
		
		__classes = PBField.new("classes", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __classes
		service.func_ref = Callable(self, "new_classes")
		data[__classes.tag] = service
		
		__tasks = PBField.new("tasks", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __tasks
		service.func_ref = Callable(self, "new_tasks")
		data[__tasks.tag] = service
		
	var data = {}
	
	var __userInfo: PBField
	func get_userInfo() -> UserInfo:
		return __userInfo.value
	func clear_userInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_userInfo() -> UserInfo:
		__userInfo.value = UserInfo.new()
		return __userInfo.value
	
	var __classes: PBField
	func get_classes() -> ClassList:
		return __classes.value
	func clear_classes() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__classes.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_classes() -> ClassList:
		__classes.value = ClassList.new()
		return __classes.value
	
	var __tasks: PBField
	func get_tasks() -> TaskList:
		return __tasks.value
	func clear_tasks() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__tasks.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_tasks() -> TaskList:
		__tasks.value = TaskList.new()
		return __tasks.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TaskItem:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__twice = PBField.new("twice", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __twice
		data[__twice.tag] = service
		
		__hints = PBField.new("hints", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __hints
		data[__hints.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __twice: PBField
	func get_twice() -> int:
		return __twice.value
	func clear_twice() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__twice.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_twice(value : int) -> void:
		__twice.value = value
	
	var __hints: PBField
	func get_hints() -> String:
		return __hints.value
	func clear_hints() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__hints.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_hints(value : String) -> void:
		__hints.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClassItem:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__enName = PBField.new("enName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __enName
		data[__enName.tag] = service
		
	var data = {}
	
	var __id: PBField
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __enName: PBField
	func get_enName() -> String:
		return __enName.value
	func clear_enName() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__enName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_enName(value : String) -> void:
		__enName.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TaskList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __task_default: Array[TaskItem] = []
		__task = PBField.new("task", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __task_default)
		service = PBServiceField.new()
		service.field = __task
		service.func_ref = Callable(self, "add_task")
		data[__task.tag] = service
		
	var data = {}
	
	var __task: PBField
	func get_task() -> Array[TaskItem]:
		return __task.value
	func clear_task() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__task.value = []
	func add_task() -> TaskItem:
		var element = TaskItem.new()
		__task.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClassList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __classify_default: Array[ClassItem] = []
		__classify = PBField.new("classify", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __classify_default)
		service = PBServiceField.new()
		service.field = __classify
		service.func_ref = Callable(self, "add_classify")
		data[__classify.tag] = service
		
	var data = {}
	
	var __classify: PBField
	func get_classify() -> Array[ClassItem]:
		return __classify.value
	func clear_classify() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__classify.value = []
	func add_classify() -> ClassItem:
		var element = ClassItem.new()
		__classify.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __items_default: Array[PlayerInfo] = []
		__items = PBField.new("items", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __items_default)
		service = PBServiceField.new()
		service.field = __items
		service.func_ref = Callable(self, "add_items")
		data[__items.tag] = service
		
	var data = {}
	
	var __items: PBField
	func get_items() -> Array[PlayerInfo]:
		return __items.value
	func clear_items() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__items.value = []
	func add_items() -> PlayerInfo:
		var element = PlayerInfo.new()
		__items.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GoodsList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __items_default: Array[GoodsInfo] = []
		__items = PBField.new("items", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __items_default)
		service = PBServiceField.new()
		service.field = __items
		service.func_ref = Callable(self, "add_items")
		data[__items.tag] = service
		
	var data = {}
	
	var __items: PBField
	func get_items() -> Array[GoodsInfo]:
		return __items.value
	func clear_items() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__items.value = []
	func add_items() -> GoodsInfo:
		var element = GoodsInfo.new()
		__items.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RoomList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __items_default: Array[RoomInfo] = []
		__items = PBField.new("items", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __items_default)
		service = PBServiceField.new()
		service.field = __items
		service.func_ref = Callable(self, "add_items")
		data[__items.tag] = service
		
	var data = {}
	
	var __items: PBField
	func get_items() -> Array[RoomInfo]:
		return __items.value
	func clear_items() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__items.value = []
	func add_items() -> RoomInfo:
		var element = RoomInfo.new()
		__items.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TableList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __items_default: Array[TableInfo] = []
		__items = PBField.new("items", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __items_default)
		service = PBServiceField.new()
		service.field = __items
		service.func_ref = Callable(self, "add_items")
		data[__items.tag] = service
		
	var data = {}
	
	var __items: PBField
	func get_items() -> Array[TableInfo]:
		return __items.value
	func clear_items() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__items.value = []
	func add_items() -> TableInfo:
		var element = TableInfo.new()
		__items.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __items_default: Array[GameInfo] = []
		__items = PBField.new("items", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __items_default)
		service = PBServiceField.new()
		service.field = __items
		service.func_ref = Callable(self, "add_items")
		data[__items.tag] = service
		
	var data = {}
	
	var __items: PBField
	func get_items() -> Array[GameInfo]:
		return __items.value
	func clear_items() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__items.value = []
	func add_items() -> GameInfo:
		var element = GameInfo.new()
		__items.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class InningList:
	func _init():
		@warning_ignore("unused_variable")
		var service
		
		var __items_default: Array[InningInfo] = []
		__items = PBField.new("items", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __items_default)
		service = PBServiceField.new()
		service.field = __items
		service.func_ref = Callable(self, "add_items")
		data[__items.tag] = service
		
	var data = {}
	
	var __items: PBField
	func get_items() -> Array[InningInfo]:
		return __items.value
	func clear_items() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__items.value = []
	func add_items() -> InningInfo:
		var element = InningInfo.new()
		__items.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
