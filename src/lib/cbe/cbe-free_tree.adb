--
-- Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
-- This file is part of the Consistent Block Encrypter project, which is
-- distributed under the terms of the GNU Affero General Public License
-- version 3.
--

pragma Ada_2012;

with SHA256_4K;
with CBE.Request;

package body CBE.Free_Tree
with Spark_Mode
is
	procedure Initialize_Object (
		Obj     : out Object_Type;
		Rt_PBA  :     Physical_Block_Address_Type;
		Rt_Gen  :     Generation_Type;
		Rt_Hash :     Hash_Type;
		Hght    :     Tree_Level_Type;
		Degr    :     Tree_Degree_Type;
		Lfs     :     Tree_Number_Of_Leafs_Type)
	is
		Tr_Helper : constant Tree_Helper.Object_Type :=
			Tree_Helper.Initialized_Object (Degr, Hght, Lfs);
	begin
		Obj := (
			Trans_Helper       => Tr_Helper,
			Trans              => Translation.Initialized_Object (Tr_Helper, True),
			Execute_Progress   => False,
			Do_Update          => False,
			Do_WB              => False,
			WB_Done            => False,
			Nr_Of_Blocks       => 0,
			Nr_Of_Found_Blocks => 0,
			Query_Branches     => (others => Query_Branch_Invalid),
			Curr_Query_Branch  => 0,
			Found_PBAs         => (others => PBA_Invalid),
			Free_PBAs          => (others => PBA_Invalid),
			Root_PBA           => Rt_PBA,
			Root_Hash          => Rt_Hash,
			Root_Gen           => Rt_Gen,
			Curr_Query_Prim    => Primitive.Invalid_Object,
			Curr_Type_2        => IO_Entry_Invalid,
			WB_IOs             => (others => IO_Entry_Invalid),
			WB_Data            => Write_Back_Data_Invalid);
	end Initialize_Object;

	procedure Retry_Allocation (Obj : in out Object_Type)
	is
	begin
		-- Print_String ("FRTR Retry_Allocation");
		-- Print_Line_Break;

		Reset_Query_Prim (Obj);
		Obj.Do_Update        := False;
		Obj.Do_WB            := False;
		Obj.WB_Done          := False;
		Obj.WB_Data.Finished := False;

	end Retry_Allocation;

	procedure Reset_Query_Prim (Obj : in out Object_Type)
	is
	begin
		Obj.Nr_Of_Found_Blocks := 0;
		Obj.Curr_Query_Prim    := Primitive.Invalid_Object;

		--
		-- Reset query branches
		--
		Obj.Curr_Query_Branch  := 0;
		For_Query_Branches:
		for Branch_ID in Obj.Query_Branches'Range loop

			--
			-- FIXME may this be replaced by Query_Branch_Invalid
			--       or at least something like Reset_Query_Branch?
			--
			Obj.Query_Branches (Branch_ID).VBA := VBA_Invalid;
			Obj.Query_Branches (Branch_ID).Nr_Of_Free_Blocks := 0;

			For_Query_Branch_PBAs:
			for PBA_ID in Obj.Query_Branches (Branch_ID).PBAs'Range loop
				Obj.Query_Branches (Branch_ID).PBAs (PBA_ID) := PBA_Invalid;
			end loop For_Query_Branch_PBAs;

		end loop For_Query_Branches;

		-- Print_String ("FRTR Reset_Query_Prim");
		-- Print_Primitive (Obj.Curr_Query_Prim);
		-- Print_Line_Break;

	end Reset_Query_Prim;

	function Request_Acceptable (Obj : Object_Type)
	return Boolean
	is (Obj.Nr_Of_Blocks = 0);

	procedure Submit_Request (
		Obj             : in out Object_Type;
		Curr_Gen        :        Generation_Type;
		Nr_of_Blks      :        Number_Of_Blocks_Type;
		New_PBAs        :        WB_Data_New_PBAs_Type;
		Old_PBAs        :        Type_1_Node_Infos_Type;
		Tree_Height     :        Tree_Level_Type;
		Fr_PBAs         :        Free_PBAs_Type;
		-- Nr_Of_Free_Blks :        Number_Of_Blocks_Type;
		Req_Prim        :        Primitive.Object_Type;
		VBA             :        Virtual_Block_Address_Type)
	is
	begin
		if Obj.Nr_Of_Blocks /= 0 then
			return;
		end if;

		Obj.Do_Update   := False;
		Obj.Do_WB       := False;
		Obj.WB_Done     := False;
		Obj.Curr_Type_2 := IO_Entry_Invalid;

		For_WB_IOs:
		for WB_IO_ID in Obj.WB_IOs'Range loop
			Obj.WB_IOs (WB_IO_ID).State := Invalid;
		end loop For_WB_IOs;

		Obj.Nr_Of_Blocks       := Nr_Of_Blks;
		Obj.Nr_Of_Found_Blocks := 0;

		-- FIXME assert sizeof (_free_pba) == sizeof (free_pba)
		Obj.Free_PBAs := Fr_PBAs;
		-- For_Free_PBAs:
		-- for Free_PBA_ID in Obj.Free_PBAs'Range loop
		-- 	if Obj.Free_PBAs (Free_PBA_ID) /= 0 then
		-- 		Print_String ("FRTR Submit_Request free[");
		-- 		Print_Word_Dec (Free_PBA_ID);
		-- 		Print_String ("]: ");
		-- 		Print_Word_Hex (Obj.Free_PBAs (Free_PBA_ID));
		-- 		Print_Line_Break;
		-- 	end if;
		-- end loop For_Free_PBAs;

		Obj.WB_Data.Finished    := False;
		Obj.WB_Data.Prim        := Req_Prim;
		Obj.WB_Data.Gen         := Curr_Gen;
		Obj.WB_Data.VBA         := VBA;
		Obj.WB_Data.Tree_Height := Tree_Height;

		-- FIXME assert sizeof (_wb_data.new_pba) == sizeof (new_pba)
		Obj.WB_Data.New_PBAs := New_PBAs;
		-- For_New_PBAs:
		-- for New_PBA_ID in Obj.New_PBAs'Range loop
		-- 	if Obj.New_PBAs (New_PBA_ID) /= 0 then
		-- 		Print_String ("FRTR Submit_Request free[");
		-- 		Print_Word_Dec (New_PBA_ID);
		-- 		Print_String ("]: ");
		-- 		Print_Word_Hex (Obj.WB_Data.New_PBAs (New_PBA_ID));
		-- 		Print_Line_Break;
		-- 	end if;
		-- end loop For_Free_PBAs;

		-- FIXME assert sizeof (_wb_data.old_pba) == sizeof (old_pba)
		Obj.WB_Data.Old_PBAs := Old_PBAs;
		-- For_Old_PBAs:
		-- for Old_PBA_ID in Obj.Old_PBAs'Range loop
		-- 	if Obj.Old_PBAs (Old_PBA_ID).PBA /= 0 then
		-- 		Print_String ("FRTR Submit_Request free[");
		-- 		Print_Word_Dec (Old_PBA_ID);
		-- 		Print_String ("]: ");
		-- 		Print_Word_Hex (Obj.WB_Data.Old_PBAs (Old_PBA_ID).PBA);
		-- 		Print_Line_Break;
		-- 	end if;
		-- end loop For_Free_PBAs;

		Reset_Query_Prim (Obj);

	end Submit_Request;

	function Leaf_Usable (
		Active_Snaps     : Snapshots_Type;
		Last_Secured_Gen : Generation_Type;
		Node             : Type_II_Node_Type)
	return Boolean
	is
		Free   : Boolean := False;
		In_Use : Boolean := False;
	begin
		-- FIXME check could be done outside
		if  not Node.Reserved then
			return True;
		end if;

		Declare_Generations:
		declare
			F_Gen : constant Generation_Type := Node.Free_Gen;
			A_Gen : constant Generation_Type := Node.Alloc_Gen;
			S_Gen : constant Generation_Type := Last_Secured_Gen;
		begin
			--
			-- If the node was freed before the last secured generation,
			-- check if there is a active snapshot that might be using the node,
			-- i.e., its generation is after the allocation generation and before
			-- the free generation.
			--
			if F_Gen <= S_Gen then
				For_Active_Snaps:
				for Snap of Active_Snaps loop
					if Snapshot_Valid (Snap) then
						-- Print_String ("FRTR Leaf_Usable snap:");
						-- Print_Snapshot (Active_Snaps (Snap_ID));
						-- Print_Line_Break;
						Declare_B_Generation:
						declare
							B_Gen   : constant Generation_Type := Snap.Gen;
							Is_Free : constant Boolean :=
								(F_Gen <= B_Gen or A_Gen >= (B_Gen + 1));
						begin
							In_Use := In_Use or not Is_Free;
							exit For_Active_Snaps when In_Use;
						end Declare_B_Generation;
					end if;
				end loop For_Active_Snaps;
				Free := not In_Use;
			end if;
			-- Print_String ("FRTR Leaf_Usable ");
			-- if Free then
			-- 	Print_String ("REUSE");
			-- else
			-- 	Print_String ("RESERVE");
			-- end if;
			-- Print_String (" PBA: ");
			-- Print_Word_Hex (Node.PBA);
			-- Print_String (" f: ");
			-- Print_Word_Dec (F_Gen);
			-- Print_String (" a: ");
			-- Print_Word_Dec (A_Gen);
			-- Print_Line_Break;
		end Declare_Generations;
		return Free;

	end Leaf_Usable;

	procedure Execute (
		Obj              : in out Object_Type;
		Active_Snaps     :        Snapshots_Type;
		Last_Secured_Gen :        Generation_Type;
		Trans_Data       : in out Translation_Data_Type;
		Cach             : in out Cache.Object_Type;
		Cach_Data        : in out Cache.Cache_Data_Type;
		Query_Data       :        Query_Data_Type;
		Timestamp        :        Timestamp_Type)
	is
	begin
		Obj.Execute_Progress := False;

		-- nothing to do, return early
		if Obj.Nr_Of_Blocks = 0 then
			return;
		end if;

		--------------------------
		-- Translation handling --
		--------------------------

		--
		-- Submit new request for querying a branch in the FT
		--
		Loop_Query_FT_Branch:
		loop
			exit Loop_Query_FT_Branch when not Translation.Acceptable (Obj.Trans);
			exit Loop_Query_FT_Branch when not Primitive.Valid (Obj.Curr_Query_Prim);

			-- Print_String ("FRTR Execute trans submit: ");
			-- Print_Primitive (Obj.Curr_Query_Prim);
			-- Print_Line_Break;

			Translation.Submit_Primitive (
				Obj.Trans, Obj.Root_PBA, Obj.Root_Gen, Obj.Root_Hash,
				Obj.Curr_Query_Prim);

			--
			-- Make the query primitive invalid after we successfully submitted
			-- the request to trigger the break above. It will be made valid again
			-- for next query.
			--
			Obj.Curr_Query_Prim := Primitive.Invalid_Object;
			Obj.Execute_Progress := True;

		end loop Loop_Query_FT_Branch;

		--
		-- Execute the Translation module and depending on the result
		-- invoke the Cache module.
		--
		Translation.Execute (Obj.Trans, Trans_Data);
		Obj.Execute_Progress :=
			Obj.Execute_Progress or Translation.Execute_Progress (Obj.Trans);

		Loop_Handle_Trans_Generated_Prim:
		loop
			Declare_Generated_Prim:
			declare
				Prim : constant Primitive.Object_Type :=
					Translation.Peek_Generated_Primitive (Obj.Trans);
			begin
				exit Loop_Handle_Trans_Generated_Prim when not Primitive.Valid (Prim);

				-- Print_String ("FRTR Execute trans peek generated: ");
				-- Print_Primitive (Prim);
				-- Print_Line_Break;

				Declare_PBA:
				declare
					PBA : constant Physical_Block_Address_Type :=
						Physical_Block_Address_Type (
							Primitive.Block_Number (Prim));
				begin
					if not Cache.Data_Available (Cach, PBA) then
						-- Print_String ("FRTR Execute cache data not available: ");
						-- Print_Word_Hex (PBA);
						-- Print_Line_Break;
						if Cache.Request_Acceptable_Logged (Cach, PBA) then
							Cache.Submit_Request_Logged (Cach, PBA);

							-- FIXME it stands to reason if we have to set
							-- progress |= true;
							--     in this case to prevent the CBE from
							--     stalling
						end if;
						exit Loop_Handle_Trans_Generated_Prim;
					else
						-- Print_String ("FRTR Execute cache data available: ");
						-- Print_Word_Hex (PBA);
						-- Print_Line_Break;
						Declare_Data_Index_1:
						declare
							Data_Index : constant Cache.Cache_Index_Type :=
								Cache.Data_Index (Cach, PBA, Timestamp);
						begin
							Translation.Mark_Generated_Primitive_Complete (
								Obj.Trans, Cach_Data (Data_Index), Trans_Data);

							Translation.Discard_Generated_Primitive (
								Obj.Trans);

						end Declare_Data_Index_1;
					end if;
				end Declare_PBA;
			end Declare_Generated_Prim;
			Obj.Execute_Progress := True;
		end loop Loop_Handle_Trans_Generated_Prim;

		Loop_Handle_Trans_Completed_Prim:
		loop
			Declare_Completed_Prim:
			declare
				Prim : constant Primitive.Object_Type :=
					Translation.Peek_Completed_Primitive (Obj.Trans);
			begin
				exit Loop_Handle_Trans_Completed_Prim when not Primitive.Valid (Prim);

				--
				-- Translation has finished, we have the PBA of the type 2
				-- node, request nodes data.
				--
				Obj.Curr_Type_2 := (
					PBA   => Physical_Block_Address_Type (Primitive.Block_Number (Prim)),
					State => Pending,
					Index => 0);

				-- Print_String ("FRTR Execute trans completed: ");
				-- Print_Primitive (Prim);
				-- Print_Line_Break;

				--
				-- To later update the free-tree, store the inner type 1 nodes
				-- of the branch.
				--
				-- (Currently not implemented.)
				--
				if not
					Translation.Can_Get_Type_1_Info_Spark (
						Obj.Trans, Prim)
				then
					-- Print_String ("FRTR Execute could not get type 1 info");
					-- Print_Line_Break;
					raise Program_Error;
				end if;
				Translation.Get_Type_1_Info (
					Obj.Trans,
					Obj.Query_Branches (Obj.Curr_Query_Branch).Trans_Infos);

				Translation.Drop_Completed_Primitive (Obj.Trans);
				Obj.Execute_Progress := True;

			end Declare_Completed_Prim;
		end loop Loop_Handle_Trans_Completed_Prim;

		---------------------------
		-- Query free leaf nodes --
		---------------------------

		--
		-- The type 2 node's data was read successfully, now look
		-- up potentially free blocks.
		--
		if Obj.Curr_Type_2.State = Complete then

			--
			-- (Invalidating the primitive here should not be necessary b/c it
			--  was already done by the Translation module, not sure why its still
			--  there.)
			--
			Obj.Curr_Query_Prim := Primitive.Invalid_Object;

			-- MOD_DBG("Obj.Curr_Type_2 complete");

			--
			-- Check each entry in the type 2 node
			--
			Declare_Nodes_1:
			declare
				Nodes : Type_II_Node_Block_Type with Address => Query_Data (0)'Address;
			begin

				For_Type_2_Nodes:
				for Node_Index in Nodes'Range loop

					--
					-- Ignore invalid entries.
					--
					-- (It stands to reason if pba == 0 or pba == INVALID_PBA should
					--  be used - unfortunately its done inconsistently throughout the
					--  CBE. The reasons is that the 'cbe_Block' uses a RAM dataspace
					--  as backing store which is zeroed out initiall which made the
					--  this cheap and pba 0 normally contains a superblock anyway.)
					--
					Declare_PBA_1:
					declare
						PBA : constant Physical_Block_Address_Type :=
							Nodes (Node_Index).PBA;
					begin
						if PBA /= 0 then
							Declare_Usable:
							declare
								Usable : constant Boolean :=
									Leaf_Usable(Active_Snaps, Last_Secured_Gen, Nodes (Node_Index));
							begin
								if Usable then

									--  set VBA on the first Usable entry, NOP for remaining entries
									if Obj.Query_Branches (Obj.Curr_Query_Branch).VBA = VBA_Invalid then
										Obj.Query_Branches (Obj.Curr_Query_Branch).VBA :=
											Virtual_Block_Address_Type (
												Primitive.Block_Number (Obj.Curr_Query_Prim));
									end if;

									Declare_Free_Blocks:
									declare
										Free_Blocks : constant Number_Of_Blocks_Type :=
											Obj.Query_Branches (Obj.Curr_Query_Branch).Nr_Of_Free_Blocks;
									begin
										Obj.Query_Branches (Obj.Curr_Query_Branch).PBAs (Natural (Free_Blocks)) := PBA;
										Obj.Query_Branches (Obj.Curr_Query_Branch).Nr_Of_Free_Blocks := Free_Blocks + 1;
										Obj.Nr_Of_Found_Blocks := Obj.Nr_Of_Found_Blocks + 1;

										-- MOD_DBG("found free PBA: ", PBA);
									end Declare_Free_Blocks;
								end if;
							end Declare_Usable;
						end if;
					end Declare_PBA_1;

					--  break off early
					exit For_Type_2_Nodes when
						Obj.Nr_Of_Blocks = Obj.Nr_Of_Found_Blocks;

				end loop For_Type_2_Nodes;

			end Declare_Nodes_1;

			--
			-- (Rather than always increasing the current query branch,
			--  only do that when we actually found free blocks.
			--  Somehow or other, querying only 8 branches is not enough
			--  for large trees and we have to change the implementation
			--  later.)
			--
			Obj.Curr_Query_Branch := Obj.Curr_Query_Branch + 1;

			--
			-- Reset I/O helper to disarm complete check above.
			--
			-- (Again, the module is in desperate need for proper state
			--  handling.)
			--
			Obj.Curr_Type_2.state := Invalid;

			Declare_End_Of_Tree:
			declare
				use Request;
				End_Of_Tree : constant Boolean :=
					Primitive.Block_Number (Obj.Curr_Query_Prim) +
					Block_Number_Type (Tree_Helper.Degree (Obj.Trans_Helper)) >=
					Block_Number_Type (Tree_Helper.Leafs (Obj.Trans_Helper));
			begin

				if Obj.Nr_Of_Found_Blocks < Obj.Nr_Of_Blocks then

					--
					-- In case we did not find enough free blocks, set the write-back
					-- data. The arbiter will call 'peek_Completed_Primitive()' and will
					-- try to discard snapshots.
					--
					if End_Of_Tree then

						-- Genode::warning("could not find enough usable leafs: ", Obj.Nr_Of_Blocks - Obj.Nr_Of_Found_Blocks, " missing");
						Obj.Wb_Data.Finished := True;
						Primitive.Success (Obj.Wb_Data.Prim, False);

					else

						-- arm query primitive and check next type 2 node
						Primitive.Block_Number (Obj.Curr_Query_Prim,
							Primitive.Block_Number (Obj.Curr_Query_Prim) +
							Block_Number_Type (Tree_Helper.Degree (Obj.Trans_Helper)));

						Primitive.Operation (Obj.Curr_Query_Prim, Request.Read);
					end if;
				elsif Obj.Nr_Of_Blocks = Obj.Nr_Of_Found_Blocks then

					--
					-- Here we iterate over all query branches and will fill in all newly
					-- allocated blocks consecutively in the new PBA list.
					--
					Declare_Last_New_PBA_Index:
					declare
						Last_New_PBA_Index : Tree_Level_Index_Type := 0;
					begin
						For_Query_Branches_Less_Than_Curr_1:
						for Branch_Index in 0 .. Obj.Curr_Query_Branch - 1 loop

							For_PBAs_Of_Free_Blocks:
							for PBA_Index in 0 .. Obj.Query_Branches (Branch_Index).Nr_Of_Free_Blocks - 1 loop

								For_Unhandled_New_PBAs:
								for New_PBA_Index in Last_New_PBA_Index .. Tree_Level_Index_Type'Last loop

									--  store iterator out-side so we start from the last set entry
									Last_New_PBA_Index := New_PBA_Index;

									--
									-- Same convention as during the invalid entries check,
									-- PBA = 0 means we have to fill in a new block.
									--
									if Obj.WB_Data.New_PBAs (New_PBA_Index) = 0 then

										Obj.Wb_Data.New_PBAs (New_PBA_Index) :=
											Obj.Query_Branches (Branch_Index).PBAs (Natural (PBA_Index));

										--MOD_DBG("use free branch: ", Branch_Index, " n: ", PBA_Index, " PBA: ", PBA);
										exit For_Unhandled_New_PBAs;

									end if;
								end loop For_Unhandled_New_PBAs;
							end loop For_PBAs_Of_Free_Blocks;
						end loop For_Query_Branches_Less_Than_Curr_1;
					end Declare_Last_New_PBA_Index;

					Obj.Do_Update := True;
				end if;
			end Declare_End_Of_Tree;

			Obj.Execute_Progress := True;
		end if;

		-----------------------------------
		-- Update meta-data in free-tree --
		-----------------------------------

		if Obj.Do_Update then

			Declare_Data_Available:
			declare
				Data_Available : Boolean := True;
			begin

				--
				-- Make sure all needed inner nodes are in the cache.
				--
				-- (Since there is only cache used throughout the CBE,
				--  VBD as well as FT changes will lead to flushing in case
				--  the generation gets sealed.)
				--
				For_Query_Branches_Less_Than_Curr_2:
				for Branch_Index in 0 .. Obj.Curr_Query_Branch - 1 loop

					--
					-- Start at 1 as the FT translation only cares about the inner
					-- nodes.
					--
					For_Tree_Levels_Greater_Zero_1:
					for Tree_Level in 1 .. Tree_Helper.Height (Obj.Trans_Helper) loop

						Declare_PBA_2:
						declare
							PBA : constant Physical_Block_Address_Type :=
								Obj.Query_Branches (Branch_Index).Trans_Infos (Natural (Tree_Level)).PBA;
						begin

							if not Cache.Data_Available(Cach, PBA) then

								if Cache.Request_Acceptable_Logged (Cach, PBA) then

									Cache.Submit_Request_Logged (Cach, PBA);
									Obj.Execute_Progress := True;
								end if;
								Data_Available := False;

								exit For_Tree_Levels_Greater_Zero_1;

							end if;
						end Declare_PBA_2;
					end loop For_Tree_Levels_Greater_Zero_1;
				end loop For_Query_Branches_Less_Than_Curr_2;

				if Data_Available then

					--------------------------------------
					-- FIXME CHANGE HOW THE WB LIST IS POPULATED:
					--     1. add type2 for each branch
					--     2. add type1 for each branch
					--    (3. add root  for each branch)
					--
					--    (Rather than brute-forcing its way through,
					--     implement post-fix tree traversel, which
					--     would omit the unnecessary hashing - it
					--     gets computational expensive quickly.)
					--------------------------------------

					Declare_WB_Count:
					declare
						WB_Count : WB_IO_Entries_Index_Type := 0;
					begin
						For_Query_Branches_Before_Curr:
						for Branch_Index in 0 .. Obj.Curr_Query_Branch - 1 loop

							For_Tree_Levels_Greater_Zero_2:
							for Tree_Level_1 in 1 .. Tree_Helper.Height (Obj.Trans_Helper) loop

								Declare_Data_Index_2:
								declare
									PBA : constant Physical_Block_Address_Type :=
										Obj.Query_Branches (Branch_Index).Trans_Infos (Natural (Tree_Level_1)).PBA;

									Data_Index : constant Cache.Cache_Index_Type :=
										Cache.Data_Index (Cach, PBA, Timestamp);

									Type_2_Node : constant Boolean := (Tree_Level_1 = 1);
								begin

									if Type_2_Node then

										--
										-- Exchange the PBA in the type 2 node entries
										--

										Declare_Nodes_2:
										declare
											Nodes : Type_II_Node_Block_Type with Address => Cach_Data (Data_Index)'Address;
										begin

											For_Nodes_1:
											for Node_Index in 0 .. Tree_Helper.Degree (Obj.Trans_Helper) - 1 loop

												--
												-- The old and new PBA array contains Data and inner node,
												-- therefor we have to check tree height + 1.
												--
												For_Tree_Levels_2:
												for Tree_Level_2 in 0 .. Tree_Helper.Height (Obj.Trans_Helper) loop

													if Nodes (Natural (Node_Index)).PBA = Obj.WB_Data.New_PBAs (Tree_Level_Index_Type (Tree_Level_2)) then
														Nodes (Natural (Node_Index)).PBA       := Obj.WB_Data.Old_PBAs (Natural (Tree_Level_2)).PBA;
														Nodes (Natural (Node_Index)).Alloc_Gen := Obj.WB_Data.Old_PBAs (Natural (Tree_Level_2)).Gen;
														Nodes (Natural (Node_Index)).Free_Gen  := Obj.WB_Data.Gen;
														Nodes (Natural (Node_Index)).Reserved  := True;
													end if;
												end loop For_Tree_Levels_2;
											end loop For_Nodes_1;
										end Declare_Nodes_2;
									else

										--
										-- Update the inner type 1 nodes
										--

										Declare_Pre_Data:
										declare
											Pre_Level : constant Tree_Level_Type := Tree_Level_1 - 1;
											Pre_PBA   : constant Physical_Block_Address_Type :=
												Obj.Query_Branches (Branch_Index).Trans_Infos (Natural (Pre_Level)).PBA;

											Pre_Data_Index : constant Cache.Cache_Index_Type := Cache.Data_Index(Cach, Pre_PBA, Timestamp);

											Hash : SHA256_4K.Hash_Type;

											Pre_Hash_Data : SHA256_4K.Data_Type with Address => Cach_Data (Pre_Data_Index)'Address;
											Nodes : Type_I_Node_Block_Type with Address => Cach_Data (Data_Index)'Address;
										begin

											SHA256_4K.Hash (Pre_Hash_Data, Hash);

											For_Nodes_2:
											for Node_Index in 0 .. Tree_Helper.Degree (Obj.Trans_Helper) - 1 loop
												if Nodes (Natural (Node_Index)).PBA = Pre_PBA then
													Nodes (Natural (Node_Index)).Hash := Hash_Type (Hash);
												end if;
											end loop For_Nodes_2;

											--  for now the root node is a special case
											if Tree_Level_1 = Tree_Helper.Height (Obj.Trans_Helper) then

												Declare_Hash_Data:
												declare
													Hash_Data : SHA256_4K.Data_Type with Address =>
														Cach_Data (Data_Index)'Address;
												begin
													SHA256_4K.Hash (Hash_Data, Hash);
													Obj.Root_Hash := Hash_Type (Hash);
												end Declare_Hash_Data;
											end if;
										end Declare_Pre_Data;
									end if;

									--
									-- Only add blocks once, which is a crude way to merge
									-- the same inner nodes in all branches.
									--
									Declare_Already_Pending:
									declare
										Already_Pending : Boolean := False;
									begin
										For_WB_IO_Entries:
										for WB_IO_Index in 0 .. WB_Count - 1 loop
											if Obj.WB_IOs (WB_IO_Index).PBA = PBA then
												Already_Pending := True;
												exit For_WB_IO_Entries;
											end if;
										end loop For_WB_IO_Entries;

										if not Already_Pending then
											--
											-- Add block to write-back I/O list
											--
											Obj.WB_IOs (WB_Count).PBA := PBA;
											Obj.WB_IOs (WB_Count).State := Pending;
											Obj.WB_IOs (WB_Count).Index := Data_Index;

											WB_Count := WB_Count + 1;
										end if;
									end Declare_Already_Pending;

								end Declare_Data_Index_2;
							end loop For_Tree_Levels_Greater_Zero_2;
						end loop For_Query_Branches_Before_Curr;
					end Declare_WB_Count;

					Obj.Do_Wb := True;
					Obj.Do_Update := False;
					Obj.Execute_Progress := True;
				end if;
			end Declare_Data_Available;
		end if;

		----------------------------------
		-- Write-back of changed branch --
		----------------------------------

		if Obj.Do_WB and not Obj.WB_Done then

			Declare_WB_Ongoing:
			declare
				WB_Ongoing : Boolean := False;
			begin
				For_WB_IOs:
				for WB_IO_Index in Tree_Level_Index_Type'Range loop

					WB_Ongoing :=
						WB_Ongoing or (
							Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).State = Pending or
							Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).State = In_Progress);

					exit For_WB_IOs when WB_Ongoing;

				end loop For_WB_IOs;

				-- FIXME why check here for not Obj.WB_Done? should be guarded by
				--     the previous check
				if not WB_Ongoing and not Obj.WB_Done then
					Obj.Do_WB := False;
					Obj.WB_Done := True;
					Obj.WB_Data.Finished := True;
					Primitive.Success(Obj.WB_Data.Prim, Request.True);
					Obj.Execute_Progress := True;
				end if;
			end Declare_WB_Ongoing;
		end if;

		-- MOD_DBG("progress: ", progress);
	end Execute;


	function Peek_Generated_Primitive (Obj : Object_Type)
	return Primitive.Object_Type
	is
	begin
		-- current type 2 node
		if Obj.Curr_Type_2.State = Pending then
			-- MOD_DBG(Prim);
			return Primitive.Valid_Object (
				Tg     => Request.Tag_Type (Tag_IO),
				Op     => Request.Read,
				Succ   => Request.False,
				Blk_Nr => Request.Block_Number_Type (Obj.Curr_Type_2.PBA),
				Idx    => 0);
		end if;

		--  write-back I/O
		if Obj.Do_WB then
			For_WB_IOs:
			for WB_IO_Index in 0 .. Tree_Level_Index_Type'Last loop

				if Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).State = Pending then

					--MOD_DBG(p);
					return Primitive.Valid_Object (
						Tg     => Request.Tag_Type (Tag_Write_Back),
						Op     => Request.Write,
						Succ   => Request.False,
						Blk_Nr => Request.Block_Number_Type (Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).PBA),
						Idx    => 0);
				end if;

			end loop For_WB_IOs;
		end if;

		return Primitive.Invalid_Object;
	end Peek_Generated_Primitive;


	function Peek_Generated_Data_Index (
		Obj  : Object_Type;
		Prim : Primitive.Object_Type)
	return Index_Type
	is
		Index : Index_Type := Index_Invalid;
	begin

		if Tag_Type (Primitive.Tag (Prim)) = Tag_IO then
			Index := 0;
		elsif Tag_Type (Primitive.Tag (Prim)) = Tag_Write_Back then
			For_WB_IOs:
			for WB_IO_Index in Tree_Level_Index_Type'Range loop
				if
					Physical_Block_Address_Type (Primitive.Block_Number (Prim)) =
					Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).PBA
				then

					if Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).State /= Pending then
						-- Genode::warning(__Func__, ": ignore invalid WRITE_BACK_TAG primitive");
						exit For_WB_IOs;
					end if;

					Index := Index_Type (Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).Index);
					exit For_WB_IOs;
				end if;
			end loop For_WB_IOs;
		end if;

		if Index = Index_Invalid then
			-- FIXME error handling
			raise Program_Error;
		end if;

		return Index;
	end Peek_Generated_Data_Index;


	procedure Drop_Generated_Primitive (
		Obj  : in out Object_Type;
		Prim :        Primitive.Object_Type)
	is
	begin
		if Tag_Type (Primitive.Tag (Prim)) = Tag_IO then
			Obj.Curr_Type_2.State := In_Progress;
		elsif Tag_Type (Primitive.Tag (Prim)) = Tag_Write_Back then
			For_WB_IOs:
			for WB_IO_Index in Tree_Level_Index_Type'Range loop
				if
					Physical_Block_Address_Type (Primitive.Block_Number (Prim)) =
					Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).PBA
				then
					if Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).State = Pending then
						Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).State := In_Progress;
					else
						null;
						-- MOD_DBG("ignore invalid WRITE_BACK_TAG primitive: ", prim);
					end if;
				end if;
			end loop For_WB_IOs;
		else
			-- MOD_ERR("invalid primitive: ", prim);
			raise Program_Error;
		end if;
	end Drop_Generated_Primitive;


	procedure Mark_Generated_Primitive_Complete(
		Obj  : in out Object_Type;
		Prim :        Primitive.Object_Type)
	is
	begin
		if Tag_Type (Primitive.Tag (Prim)) = Tag_IO then
			if Obj.Curr_Type_2.State = In_Progress then
				Obj.Curr_Type_2.State := Complete;
			else
				null;
				-- MOD_DBG("ignore invalid I/O primitive: ", prim);
			end if;
		elsif Tag_Type (Primitive.Tag (Prim)) = Tag_Write_Back then
			For_WB_IOs:
			for WB_IO_Index in Tree_Level_Index_Type'Range loop
				if Physical_Block_Address_Type (Primitive.Block_Number (prim)) = Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).PBA then
					if Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).State = In_Progress then
						Obj.WB_IOs (WB_IO_Entries_Index_Type (WB_IO_Index)).State := Complete;

						if Request."=" (Primitive.Success (Prim), Request.False) then
							-- FIXME propagate failure
							null;
							-- MOD_ERR("failed primitive: ", prim);
						end if;
					else
						null;
						-- MOD_DBG("ignore invalid WRITE_BACK_TAG primitive: ", prim,
						--        " entry: ", i, " state: ", (uint32_T)_WB_IOs (WB_IO_Index).State);
					end if;
				end if;
			end loop For_WB_IOs;
		else
			-- FIXME handle error
			--MOD_ERR("invalid primitive: ", prim);
			raise program_error;
		end if;
	end Mark_Generated_Primitive_Complete;

--	--
--	-- Check for any completed primitive
--	--
--	-- The method will always a return a primitive and the caller
--	-- always has to check if the returned primitive is in fact a
--	-- valid one.
--	--
--	-- \return a valid Primitive will be returned if there is an
--	--         completed primitive, otherwise an invalid one
--	--
--	Primitive.Object_Typepeek_Completed_Primitive()
--	{
--		if Obj.WB_Data.Valid() then
--			return Obj.WB_Data.Prim;
--		}
--		return Primitive.Object_Type{ };
--	}
--
--	--
--	-- Get write-back Data belonging to a completed primitive
--	--
--	-- This method must only be called after 'peek_Completed_Primitive'
--	-- returned a valid primitive.
--	--
--	-- \param p   reference to the completed primitive
--	--
--	-- \return write-back Data
--	--
--	constant Write_Back_Data &peek_CompletedObj.WB_Data(constant Primitive &prim) const
--	{
--		if not prim.Equal(Obj.WB_Data.Prim) then
--			MOD_ERR("invalid primitive: ", prim);
--			throw -1;
--		}
--
--		MOD_DBG(prim);
--		return Obj.WB_Data;
--	}
--
--	--
--	-- Discard given completed primitive
--	--
--	-- This method must only be called after 'peek_Completed_Primitive'
--	-- returned a valid primitive.
--	--
--	-- \param  p  reference to primitive
--	--
--	void drop_Completed_Primitive(constant Primitive &prim)
--	{
--		if not prim.Equal(Obj.WB_Data.Prim) then
--			MOD_ERR("invalid primitive: ", prim);
--			throw -1;
--		}
--
--		MOD_DBG(prim);
--
--		--  reset state
--		Obj.WB_Data.Finished := False;
--
--		--  request finished, ready for a new one
--		Obj.Num_Blocks := 0;
--	}


end CBE.Free_Tree;