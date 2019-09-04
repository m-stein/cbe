--
-- Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
-- This file is part of the Consistent Block Encrypter project, which is
-- distributed under the terms of the GNU Affero General Public License
-- version 3.
--

pragma Ada_2012;

package body CBE.Virtual_Block_Device
with Spark_Mode
is
	--
	-- Initialize_Object
	--
	procedure Initialize_Object (
		Obj    : out Object_Type;
		Height :     Tree_Level_Type;
		Degree :     Tree_Degree_Type;
		Leafs  :     Tree_Number_Of_Leafs_Type)
	is
		Trans_Helpr : constant Tree_Helper.Object_Type :=
			Tree_Helper.Initialized_Object (Degree, Height, Leafs);
	begin
		Obj := (
			Trans_Helper => Trans_Helpr,
			Trans => Translation.Initialized_Object (Trans_Helpr, False),
			Execute_Progress => False);
	end Initialize_Object;

	--
	-- Trans_Inhibit_Translation
	--
	procedure Trans_Inhibit_Translation (Obj : in out Object_Type)
	is
	begin
		Translation.Suspend (Obj.Trans);
	end Trans_Inhibit_Translation;

	--
	-- Trans_Resume_Translation
	--
	procedure Trans_Resume_Translation (Obj : in out Object_Type)
	is
	begin
		Translation.Resume (Obj.Trans);
	end Trans_Resume_Translation;

	--
	-- Trans_Get_Virtual_Block_Address
	--
	function Trans_Get_Virtual_Block_Address (
		Obj  : Object_Type;
		Prim : Primitive.Object_Type)
	return Request.Block_Number_Type
	is
	begin
		if
			Request."/=" (
				Primitive.Block_Number (Prim),
				Request.Block_Number_Type (Translation.Data_PBA (Obj.Trans)))
		then
			raise Program_Error;
		end if;

		return Translation.Get_Virtual_Block_Address (Obj.Trans);
	end Trans_Get_Virtual_Block_Address;

	--
	-- Trans_Can_Get_Type_1_Info
	--
	function Trans_Can_Get_Type_1_Info (
		Obj   : Object_Type;
		Prim  : Primitive.Object_Type;
		Infos : Address_Type)
	return Boolean
	is (Translation.Can_Get_Type_1_Info (Obj.Trans, Prim, Infos));

	--
	-- Trans_Get_Type_1_Info
	--
	procedure Trans_Get_Type_1_Info (
		Obj   :        Object_Type;
		Infos : in out Type_1_Node_Infos_Type)
	is
	begin
		Translation.Get_Type_1_Info (Obj.Trans, Infos);
	end Trans_Get_Type_1_Info;

	--
	-- Tree_Height
	--
	function Tree_Height (Obj : Object_Type)
	return Tree_Level_Type
	is (Tree_Helper.Height (Obj.Trans_Helper));

	--
	-- Index_For_Level
	--
	function Index_For_Level (
		Obj   : Object_Type;
		VBA   : Virtual_Block_Address_Type;
		Level : Tree_Level_Type)
	return Tree_Child_Index_Type
	is (Tree_Helper.Index (Obj.Trans_Helper, VBA, Level));

	--
	-- Get_Tree_Helper
	--
	function Get_Tree_Helper (Obj : Object_Type)
	return Tree_Helper.Object_Type
	is (Obj.Trans_Helper);

	--
	-- Primitive_Acceptable
	--
	function Primitive_Acceptable (Obj : Object_Type)
	return Boolean
	is (Translation.Acceptable (Obj.Trans));

	--
	-- Submit_Primitive
	--
	procedure Submit_Primitive (
		Obj  : in out Object_Type;
		PBA  :        Physical_Block_Address_Type;
		Gen  :        Generation_Type;
		Hash :        Hash_Type;
		Prim :        Primitive.Object_Type)
	is
	begin
		-- Print_String ("VBD.SubmPrim: PBA: ");
		-- Print_Word_Hex (PBA);
		-- Print_String ("Gen: ");
		-- Print_Word_Dec (Gen);
		-- Print_String ("Prim: ");
		-- Print_Primitive (Prim);
		-- Print_Line_Break;
		Translation.Submit_Primitive (Obj.Trans, PBA, Gen, Hash, Prim);
	end Submit_Primitive;

	--
	-- Peek_Completed_Primitive
	--
	function Peek_Completed_Primitive (Obj : Object_Type)
	return Primitive.Object_Type
	is (Translation.Peek_Completed_Primitive (Obj.Trans));

	--
	-- Drop_Completed_Primitive
	--
	procedure Drop_Completed_Primitive (Obj : in out Object_Type)
	is
	begin
		Translation.Drop_Completed_Primitive (Obj.Trans);
	end Drop_Completed_Primitive;

	--
	-- Execute
	--
	procedure Execute (
		Obj        : in out Object_Type;
		Trans_Data : in out Translation_Data_Type;
		Cach       : in out Cache.Object_Type;
		Cach_Data  :        Cache.Cache_Data_Type;
		Timestamp  :        Timestamp_Type)
	is
	begin
		Obj.Execute_Progress := False;

		--------------------------
		-- Translation handling --
		--------------------------

		Translation.Execute (Obj.Trans, Trans_Data);
		Declare_Trans_Progress:
		declare
			Trans_Progress : constant Boolean :=
				Translation.Execute_Progress (Obj.Trans);
		begin
			Obj.Execute_Progress :=
				Obj.Execute_Progress or Trans_Progress;
		end Declare_Trans_Progress;

		-- FIXME prevent module from checking the cache again and again

		Endless_Loop:
		loop
			Declare_Primitive:
			declare
				Prim : constant Primitive.Object_Type :=
					Translation.Peek_Generated_Primitive (Obj.Trans);
			begin
				if not Primitive.Valid (Prim) then
					exit Endless_Loop;
				end if;

				Declare_PBA:
				declare
					PBA : constant Physical_Block_Address_Type :=
						Physical_Block_Address_Type (Primitive.Block_Number (Prim));
				begin

					if not Cache.Data_Available (Cach, PBA) then

						-- Print_String ("VBD.Exe: data not available: pba: ");
						-- Print_Word_Hex (PBA);
						-- Print_Line_Break;

						if Cache.Request_Acceptable_Logged (Cach, PBA) then
							Cache.Submit_Request_Logged (Cach, PBA);

							-- Print_String ("VBD.Exe: submit cache request: pba: ");
							-- Print_Word_Hex (PBA);
							-- Print_Line_Break;

							--
							-- Only report progress on the initial request, all
							-- other data available checks do not denote progress.
							-- Otherwise we will end up with an endless loop.
							--
							Obj.Execute_Progress :=
								Obj.Execute_Progress or True;
						end if;
						exit Endless_Loop;
					else
						Declare_Data:
						declare
							Data_Index : constant Cache.Cache_Index_Type :=
								Cache.Data_Index (Cach, PBA, Timestamp);

							Data : constant Block_Data_Type :=
								Cach_Data(Data_Index);
						begin
							Translation.Mark_Generated_Primitive_Complete (
								Obj.Trans, Data, Trans_Data);

						end Declare_Data;

						Translation.Discard_Generated_Primitive (
							Obj.Trans);

						-- Print_String ("VBD.Exe: mark gen prim complete: pba: ");
						-- Print_Word_Hex (PBA);
						-- Print_Line_Break;

					end if;
				end Declare_PBA;
			end Declare_Primitive;

			Obj.Execute_Progress := Obj.Execute_Progress or True;

		end loop Endless_Loop;
	end Execute;

	---------------
	-- Accessors --
	---------------

	function Execute_Progress(Obj : Object_Type) return Boolean is (Obj.Execute_Progress);

end CBE.Virtual_Block_Device;