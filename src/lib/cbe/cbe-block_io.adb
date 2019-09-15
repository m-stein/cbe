--
-- Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
-- This file is part of the Consistent Block Encrypter project, which is
-- distributed under the terms of the GNU Affero General Public License
-- version 3.
--

pragma Ada_2012;

package body CBE.Block_IO
with Spark_Mode
is
	function Invalid_Entry return Entry_Type
	is (Orig_Tag => Tag_Invalid,
	    Prim     => Primitive.Invalid_Object,
	    State    => Unused);

	procedure Initialize_Object(Obj : out Object_Type)
	is
	begin
		Obj := Initialized_Object;
	end Initialize_Object;

	--
	-- Initialized_Object
	--
	function Initialized_Object
	return Object_Type
	is (
		Entries => (others => Invalid_Entry),
		Used_Entries => 0);

	function Primitive_Acceptable(Obj : Object_Type) return Boolean
	is (Obj.Used_Entries < Num_Entries_Type'Last);

	procedure Submit_Primitive(
		Obj     : in out Object_Type;
		Tag     :        Tag_Type;
		Prim    :        Primitive.Object_Type;
		IO_Data : in out Data_Type;
		Data    : in     Block_Data_Type)
	is
	begin
		for I in Obj.Entries'Range loop

			if (Obj.Entries(I).State = Unused) then

				Obj.Entries(I) := (
					Orig_Tag => Primitive.Tag(Prim),
					Prim     => Primitive.Valid_Object (
						Op     => Primitive.Operation(Prim),
						Succ   => Primitive.Success(Prim),
						Tg     => Tag,
						Blk_Nr => Primitive.Block_Number(Prim),
						Idx    => Primitive.Index(Prim)),
					State    => Pending);

				if Primitive.Operation(Prim) = Write then
					IO_Data(I) := Data;
				end if;

				Obj.Used_Entries := Obj.Used_Entries + 1;
				return;
			end if;
		end loop;
	end Submit_Primitive;

	function Peek_Completed_Primitive (Obj : Object_Type)
	return Primitive.Object_Type
	is
	begin
		for I in Obj.Entries'Range loop
			if Obj.Entries(I).State = Complete then
				return Obj.Entries(I).Prim;
			end if;
		end loop;

		return Primitive.Invalid_Object;
	end Peek_Completed_Primitive;

	function Peek_Completed_Data_Index (Obj : Object_Type)
	return Data_Index_Type
	is
	begin
		for I in Obj.Entries'Range loop
			if Obj.Entries(I).State = Complete then
				return I;
			end if;
		end loop;

		-- XXX precondition
		raise Program_Error;
	end Peek_Completed_Data_Index;

	function Peek_Completed_Tag (
		Obj  : Object_Type;
		Prim : Primitive.Object_Type)
	return CBE.Tag_Type
	is
	begin
		for I in Obj.Entries'Range loop
			if
				Obj.Entries(I).State = Complete and
				Primitive.Equal(Prim, Obj.Entries(I).Prim)
			then
				return Obj.Entries(I).Orig_Tag;
			end if;
		end loop;

		-- XXX precondition
		raise Program_Error;
	end Peek_Completed_Tag;

	procedure Drop_Completed_Primitive (
		Obj  : in out Object_Type;
		Prim :        Primitive.Object_Type)
	is
	begin
		for I in Obj.Entries'Range loop
			if
				Obj.Entries(I).State = Complete and
				Primitive.Equal(Prim, Obj.Entries(I).Prim)
			then
				Obj.Entries(I) := Invalid_Entry;
				Obj.Used_Entries := Obj.Used_Entries - 1;
				return;
			end if;
		end loop;
	end Drop_Completed_Primitive;

	function Peek_Generated_Primitive (Obj : Object_Type)
	return Primitive.Object_Type
	is
	begin
		for I in Obj.Entries'Range loop
			if Obj.Entries(I).State = Pending then
				return Obj.Entries(I).Prim;
			end if;
		end loop;

		return Primitive.Invalid_Object;
	end Peek_Generated_Primitive;

	function Peek_Generated_Data_Index (
		Obj  : Object_Type;
		Prim : CBE.Primitive.Object_Type)
	return Data_Index_Type
	is
	begin
		for I in Obj.Entries'Range loop
			-- XXX why is the condition different from
			--     'Peek_Generated_Primitive' and 'Drop_Completed_Primitive'?
			if
				Obj.Entries(I).State = Pending or
				Obj.Entries(I).State = In_Progress
			then
				if Primitive.Equal(Prim, Obj.Entries(I).Prim) then
					return I;
				end if;
			end if;
		end loop;

		-- XXX precondition
		raise Program_Error;
	end Peek_Generated_Data_Index;

	procedure Drop_Generated_Primitive (
		Obj  : in out Object_Type;
		Prim :        Primitive.Object_Type)
	is
	begin
		for I in Obj.Entries'Range loop
			if
				Obj.Entries(I).State = Pending and
				Primitive.Equal(Prim, Obj.Entries(I).Prim)
			then
				Obj.Entries(I).State := In_Progress;
				return;
			end if;
		end loop;
	end Drop_Generated_Primitive;

	procedure Mark_Generated_Primitive_Complete (
		Obj  : in out Object_Type;
		Prim :        Primitive.Object_Type)
	is
	begin
		for I in Obj.Entries'Range loop
			if
				Obj.Entries(I).State = In_Progress and
				Primitive.Equal(Prim, Obj.Entries(I).Prim)
			then
				Primitive.Success(Obj.Entries(I).Prim, Primitive.Success(Prim));
				Obj.Entries(I).State := Complete;
				return;
			end if;
		end loop;

		-- XXX precondition
		raise Program_Error;
	end Mark_Generated_Primitive_Complete;

end CBE.Block_IO;
