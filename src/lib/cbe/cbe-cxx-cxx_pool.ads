--
-- Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
-- This file is part of the Consistent Block Encrypter project, which is
-- distributed under the terms of the GNU Affero General Public License
-- version 3.
--

pragma Ada_2012;

with CBE.CXX.CXX_Request;
with CBE.CXX.CXX_Primitive;
with CBE.Pool;

package CBE.CXX.CXX_Pool
with Spark_Mode
is
--	pragma Pure;

	--
	-- Object_Size
	--
	function Object_Size (Obj : Pool.Object_Type) return CXX_Object_Size_Type
		with Export,
		Convention    => C,
		External_Name => "_ZN3Cbe6Module11object_sizeERKNS0_12Request_poolE";

	--
	-- Initialize_Object
	--
	procedure Initialize_Object(
		Obj       :    out Pool.Object_Type;
		Req_Size  : in     CXX_Size_Type;
		Prim_Size : in     CXX_Size_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe6Module12Request_poolC1Emm";

	--
	-- Request_Acceptable
	--
	function Request_Acceptable(Obj : Pool.Object_Type)
	return CXX_Bool_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe6Module12Request_pool18request_acceptableEv";

	--
	-- Submit_Request
	--
	procedure Submit_Request(
		Obj         : in out Pool.Object_Type;
		Req         :        CXX_Request.Object_Type;
		Nr_Of_Prims :        CXX_Number_Of_Primitives_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe6Module12Request_pool14submit_requestERKNS_7RequestEm";

	--
	-- Peek_Pending_Request
	--
	function Peek_Pending_Request(Obj : Pool.Object_Type)
	return CXX_Request.Object_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe6Module12Request_pool20peek_pending_requestEv";

	--
	-- Drop_Pending_Request
	--
	procedure Drop_Pending_Request(
		Obj : in out Pool.Object_Type;
		Req :        CXX_Request.Object_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe6Module12Request_pool20drop_pending_requestERKNS_7RequestE";

	--
	-- Mark_Completed_Primitive
	--
	procedure Mark_Completed_Primitive(
		Obj  : in out Pool.Object_Type;
		Prim :        CXX_Primitive.Object_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe6Module12Request_pool24mark_completed_primitiveERKNS_9PrimitiveE";

	--
	-- Peek_Completed_Request
	--
	function Peek_Completed_Request(Obj : Pool.Object_Type)
	return CXX_Request.Object_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe6Module12Request_pool22peek_completed_requestEv";

	--
	-- Drop_Completed_Request
	--
	procedure Drop_Completed_Request(
		Obj : in out Pool.Object_Type;
		Req :        CXX_Request.Object_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe6Module12Request_pool22drop_completed_requestERKNS_7RequestE";

	--
	-- Request_For_Tag
	--
	function Request_For_Tag(
		Obj : Pool.Object_Type;
		Tag : CXX_Request.Tag_Type)
	return CXX_Request.Object_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe6Module12Request_pool15request_for_tagENS_3TagE";

end CBE.CXX.CXX_Pool;
