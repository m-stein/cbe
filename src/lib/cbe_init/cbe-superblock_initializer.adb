--
--  Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
--  This file is part of the Consistent Block Encrypter project, which is
--  distributed under the terms of the GNU Affero General Public License
--  version 3.
--

pragma Ada_2012;

with CBE.Debug;
with SHA256_4K;

pragma Unreferenced (CBE.Debug);

package body CBE.Superblock_Initializer
with SPARK_Mode
is
   procedure CBE_Hash_From_SHA256_4K_Hash (
      CBE_Hash : out Hash_Type;
      SHA_Hash :     SHA256_4K.Hash_Type);

   procedure CBE_Hash_From_SHA256_4K_Hash (
      CBE_Hash : out Hash_Type;
      SHA_Hash :     SHA256_4K.Hash_Type)
   is
      SHA_Idx : SHA256_4K.Hash_Index_Type := SHA256_4K.Hash_Index_Type'First;
   begin
      for CBE_Idx in CBE_Hash'Range loop
         CBE_Hash (CBE_Idx) := Byte_Type (SHA_Hash (SHA_Idx));
         if CBE_Idx < CBE_Hash'Last then
            SHA_Idx := SHA_Idx + 1;
         end if;
      end loop;
   end CBE_Hash_From_SHA256_4K_Hash;

   procedure SHA256_4K_Data_From_CBE_Data (
      SHA_Data : out SHA256_4K.Data_Type;
      CBE_Data :     Block_Data_Type);

   procedure SHA256_4K_Data_From_CBE_Data (
      SHA_Data : out SHA256_4K.Data_Type;
      CBE_Data :     Block_Data_Type)
   is
      CBE_Idx : Block_Data_Index_Type := Block_Data_Index_Type'First;
   begin
      for SHA_Idx in SHA_Data'Range loop
         SHA_Data (SHA_Idx) := SHA256_4K.Byte (CBE_Data (CBE_Idx));
         if SHA_Idx < SHA_Data'Last then
            CBE_Idx := CBE_Idx + 1;
         end if;
      end loop;
   end SHA256_4K_Data_From_CBE_Data;

   function Hash_Of_Superblock (SB : Superblock_Ciphertext_Type)
   return Hash_Type;

   function Hash_Of_Superblock (SB : Superblock_Ciphertext_Type)
   return Hash_Type
   is
   begin
      Declare_Hash_Data :
      declare
         SHA_Hash : SHA256_4K.Hash_Type;
         SHA_Data : SHA256_4K.Data_Type;
         CBE_Data : Block_Data_Type;
         CBE_Hash : Hash_Type;
      begin
         Block_Data_From_Superblock_Ciphertext (CBE_Data, SB);
         SHA256_4K_Data_From_CBE_Data (SHA_Data, CBE_Data);
         SHA256_4K.Hash (SHA_Data, SHA_Hash);
         CBE_Hash_From_SHA256_4K_Hash (CBE_Hash, SHA_Hash);
         return CBE_Hash;
      end Declare_Hash_Data;

   end Hash_Of_Superblock;

   function Valid_Snap_Slot (Obj : Object_Type)
   return Snapshot_Type
   is
      Snap : Snapshot_Type;
   begin

      Snap.Hash        := Obj.VBD.Hash;
      Snap.PBA         := Obj.VBD.PBA;
      Snap.Gen         := 0;
      Snap.Nr_Of_Leafs := Obj.VBD_Nr_Of_Leafs;
      Snap.Max_Level   := Obj.VBD_Max_Lvl_Idx;
      Snap.Valid       := True;
      Snap.ID          := 0;
      Snap.Keep        := False;
      return Snap;

   end Valid_Snap_Slot;

   function Valid_SB_Slot (
      Obj        : Object_Type;
      First_PBA  : Physical_Block_Address_Type;
      Nr_Of_PBAs : Number_Of_Blocks_Type)
   return Superblock_Ciphertext_Type
   is
      SB : Superblock_Ciphertext_Type;
   begin
      For_Snapshots :
      for Idx in Snapshots_Index_Type loop
         if Idx = Snapshots_Index_Type'First then
            SB.Snapshots (Idx) := Valid_Snap_Slot (Obj);
         else
            SB.Snapshots (Idx) := Snapshot_Invalid;
         end if;
      end loop For_Snapshots;

      SB.State                   := Normal;
      SB.Rekeying_VBA            := 0;
      SB.Resizing_Nr_Of_PBAs     := 0;
      SB.Resizing_Nr_Of_Leaves   := 0;
      SB.Current_Key             := (
         Value => Obj.Key_Cipher,
         ID => 1);
      SB.Previous_Key            := Key_Ciphertext_Invalid;
      SB.Curr_Snap               := 0;
      SB.Degree                  := Obj.VBD_Degree;
      SB.First_PBA               := First_PBA;
      SB.Nr_Of_PBAs              := Nr_Of_PBAs;
      SB.Last_Secured_Generation := 0;
      SB.Free_Gen                := 0;
      SB.Free_Number             := Obj.FT.PBA;
      SB.Free_Hash               := Obj.FT.Hash;
      SB.Free_Max_Level          := Obj.FT_Max_Lvl_Idx;
      SB.Free_Degree             := Obj.FT_Degree;
      SB.Free_Leafs              := Obj.FT_Nr_Of_Leafs;
      SB.Meta_Gen                := 0;
      SB.Meta_Number             := Obj.MT.PBA;
      SB.Meta_Hash               := Obj.MT.Hash;
      SB.Meta_Max_Level          := Obj.MT_Max_Lvl_Idx;
      SB.Meta_Degree             := Obj.MT_Degree;
      SB.Meta_Leafs              := Obj.MT_Nr_Of_Leafs;
      return SB;

   end Valid_SB_Slot;

   procedure Initialize_Object (Obj : out Object_Type)
   is
   begin
      Obj.Submitted_Prim := Primitive.Invalid_Object;
      Obj.Execute_Progress := False;
      Obj.SB_Slot_State := Init;
      Obj.SB_Slot_Idx := Superblocks_Index_Type'First;
      Obj.SB_Slot := Superblock_Ciphertext_Invalid;
      Obj.Key_Plain := (others => Byte_Type'First);
      Obj.Key_Cipher := (others => Byte_Type'First);
      Obj.VBD := Type_1_Node_Invalid;
      Obj.VBD_Max_Lvl_Idx := Tree_Level_Index_Type'First;
      Obj.VBD_Degree := Tree_Degree_Type'First;
      Obj.VBD_Nr_Of_Leafs := Tree_Number_Of_Leafs_Type'First;
      Obj.FT := Type_1_Node_Invalid;
      Obj.FT_Max_Lvl_Idx := Tree_Level_Index_Type'First;
      Obj.FT_Degree := Tree_Degree_Type'First;
      Obj.FT_Nr_Of_Leafs := Tree_Number_Of_Leafs_Type'First;
      Obj.MT := Type_1_Node_Invalid;
      Obj.MT_Max_Lvl_Idx := Tree_Level_Index_Type'First;
      Obj.MT_Degree := Tree_Degree_Type'First;
      Obj.MT_Nr_Of_Leafs := Tree_Number_Of_Leafs_Type'First;
      Obj.Generated_Prim := Primitive.Invalid_Object;
   end Initialize_Object;

   function Primitive_Acceptable (Obj : Object_Type)
   return Boolean
   is (not Primitive.Valid (Obj.Submitted_Prim));

   procedure Submit_Primitive (
      Obj             : in out Object_Type;
      Prim            :        Primitive.Object_Type;
      VBD_Max_Lvl_Idx :        Tree_Level_Index_Type;
      VBD_Degree      :        Tree_Degree_Type;
      VBD_Nr_Of_Leafs :        Tree_Number_Of_Leafs_Type;
      FT_Max_Lvl_Idx  :        Tree_Level_Index_Type;
      FT_Degree       :        Tree_Degree_Type;
      FT_Nr_Of_Leafs  :        Tree_Number_Of_Leafs_Type;
      MT_Max_Lvl_Idx  :        Tree_Level_Index_Type;
      MT_Degree       :        Tree_Degree_Type;
      MT_Nr_Of_Leafs  :        Tree_Number_Of_Leafs_Type)
   is
   begin
      if Primitive.Valid (Obj.Submitted_Prim) then
         raise Program_Error;
      end if;
      Obj.Submitted_Prim := Prim;
      Obj.SB_Slot_State := Init;
      Obj.VBD_Max_Lvl_Idx := VBD_Max_Lvl_Idx;
      Obj.VBD_Degree := VBD_Degree;
      Obj.VBD_Nr_Of_Leafs := VBD_Nr_Of_Leafs;
      Obj.FT_Max_Lvl_Idx := FT_Max_Lvl_Idx;
      Obj.FT_Degree := FT_Degree;
      Obj.FT_Nr_Of_Leafs := FT_Nr_Of_Leafs;
      Obj.MT_Max_Lvl_Idx := MT_Max_Lvl_Idx;
      Obj.MT_Degree := MT_Degree;
      Obj.MT_Nr_Of_Leafs := MT_Nr_Of_Leafs;

      pragma Debug (
         Debug.Print_String (
            "[sb_init] slot " &
            Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
            ", init"));

   end Submit_Primitive;

   function Peek_Completed_Primitive (Obj : Object_Type)
   return Primitive.Object_Type
   is
   begin
      if not Primitive.Valid (Obj.Submitted_Prim) or else
         Obj.SB_Slot_Idx < Superblocks_Index_Type'Last or else
         Obj.SB_Slot_State /= Done
      then
         return Primitive.Invalid_Object;
      end if;
      return Obj.Submitted_Prim;
   end Peek_Completed_Primitive;

   procedure Drop_Completed_Primitive (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type)
   is
   begin
      if not Primitive.Valid (Obj.Submitted_Prim) or else
         not Primitive.Equal (Obj.Submitted_Prim, Prim) or else
         Obj.SB_Slot_Idx < Superblocks_Index_Type'Last or else
         Obj.SB_Slot_State /= Done
      then
         raise Program_Error;
      end if;
      Initialize_Object (Obj);

   end Drop_Completed_Primitive;

   procedure Execute (
      Obj        : in out Object_Type;
      First_PBA  :        Physical_Block_Address_Type;
      Nr_Of_PBAs :        Number_Of_Blocks_Type)
   is
   begin
      Obj.Execute_Progress := False;

      if not Primitive.Valid (Obj.Submitted_Prim) then
         return;
      end if;

      case Obj.SB_Slot_State is
      when Init =>

         if Obj.SB_Slot_Idx = Superblocks_Index_Type'First then

            Obj.SB_Slot_State := VBD_Request_Started;
            Obj.Generated_Prim :=
               Primitive.Valid_Object_No_Pool_Idx (
                  Read, False, Primitive.Tag_SB_Init_VBD_Init, 0, 0);

            Obj.Execute_Progress := True;

            pragma Debug (
               Debug.Print_String (
                  "[sb_init] slot " &
                  Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
                  ", vbd started"));

         else

            Obj.SB_Slot := Superblock_Ciphertext_Invalid;
            Obj.SB_Slot_State := Write_Request_Started;
            Obj.Generated_Prim :=
               Primitive.Valid_Object_No_Pool_Idx (
                  Write, False, Primitive.Tag_SB_Init_Blk_IO,
                  Block_Number_Type (Obj.SB_Slot_Idx), 0);

            Obj.Execute_Progress := True;

            pragma Debug (
               Debug.Print_String (
                  "[sb_init] slot " &
                  Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
                  ", write started"));

         end if;

      when VBD_Request_Done =>

         Obj.Generated_Prim :=
            Primitive.Valid_Object_No_Pool_Idx (
               Write, False, Primitive.Tag_SB_Init_FT_Init,
               Block_Number_Type (Obj.SB_Slot_Idx), 0);

         Obj.SB_Slot_State := FT_Request_Started;
         Obj.Execute_Progress := True;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ft started"));

      when FT_Request_Done =>

         Obj.Generated_Prim :=
            Primitive.Valid_Object_No_Pool_Idx (
               Write, False, Primitive.Tag_SB_Init_MT_Init,
               Block_Number_Type (Obj.SB_Slot_Idx), 0);

         Obj.SB_Slot_State := MT_Request_Started;
         Obj.Execute_Progress := True;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", mt started"));

      when MT_Request_Done =>

         Obj.Generated_Prim :=
            Primitive.Valid_Object_No_Pool_Idx (
               Primitive_Operation_Type'First, False,
               Primitive.Tag_SB_Init_TA_Create_Key,
               Block_Number_Type'First, 0);

         Obj.SB_Slot_State := TA_Request_Create_Key_Started;
         Obj.Execute_Progress := True;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta create key started started"));

      when TA_Request_Create_Key_Done =>

         Obj.Generated_Prim :=
            Primitive.Valid_Object_No_Pool_Idx (
               Primitive_Operation_Type'First, False,
               Primitive.Tag_SB_Init_TA_Encrypt_Key,
               Block_Number_Type'First, 0);

         Obj.SB_Slot_State := TA_Request_Encrypt_Key_Started;
         Obj.Execute_Progress := True;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta encrypt key started"));

      when TA_Request_Encrypt_Key_Done =>

         Obj.SB_Slot := Valid_SB_Slot (Obj, First_PBA, Nr_Of_PBAs);
         Obj.SB_Hash := Hash_Of_Superblock (Obj.SB_Slot);
         Obj.Generated_Prim :=
            Primitive.Valid_Object_No_Pool_Idx (
               Write, False, Primitive.Tag_SB_Init_Blk_IO,
               Block_Number_Type (Obj.SB_Slot_Idx), 0);

         Obj.SB_Slot_State := Write_Request_Started;
         Obj.Execute_Progress := True;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta encrypt key done"));

      when Write_Request_Done =>

         Obj.Generated_Prim :=
            Primitive.Valid_Object_No_Pool_Idx (
               Sync, False, Primitive.Tag_SB_Init_Blk_IO,
               Block_Number_Type (Obj.SB_Slot_Idx), 0);

         Obj.SB_Slot_State := Sync_Request_Started;
         Obj.Execute_Progress := True;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", write done"));

      when Sync_Request_Done =>

         if Obj.SB_Slot_Idx = Superblocks_Index_Type'First then

            Obj.Generated_Prim :=
               Primitive.Valid_Object_No_Pool_Idx (
                  Primitive_Operation_Type'First, False,
                  Primitive.Tag_SB_Init_TA_Secure_SB,
                  Block_Number_Type'First, 0);

            Obj.SB_Slot_State := TA_Request_Secure_SB_Started;

         else

            Obj.SB_Slot_State := Done;

         end if;

         Obj.Execute_Progress := True;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", sync done"));

      when TA_Request_Secure_SB_Done =>

         Obj.SB_Slot_State := Done;
         Obj.Execute_Progress := True;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta secure sb done"));

      when Done =>

         if Obj.SB_Slot_Idx < Superblocks_Index_Type'Last then

            Obj.SB_Slot_Idx := Obj.SB_Slot_Idx + 1;
            Obj.SB_Slot_State := Init;
            Obj.Execute_Progress := True;

            pragma Debug (
               Debug.Print_String (
                  "[sb_init] slot " &
                  Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
                  ", init"));

         end if;

      when others =>

         null;

      end case;

   end Execute;

   function Execute_Progress (Obj : Object_Type)
   return Boolean
   is (Obj.Execute_Progress);

   function Peek_Generated_Primitive (Obj : Object_Type)
   return Primitive.Object_Type
   is (
      case Obj.SB_Slot_State is
      when Sync_Request_Started => Obj.Generated_Prim,
      when Write_Request_Started => Obj.Generated_Prim,
      when VBD_Request_Started => Obj.Generated_Prim,
      when FT_Request_Started => Obj.Generated_Prim,
      when MT_Request_Started => Obj.Generated_Prim,
      when TA_Request_Create_Key_Started => Obj.Generated_Prim,
      when TA_Request_Encrypt_Key_Started => Obj.Generated_Prim,
      when TA_Request_Secure_SB_Started => Obj.Generated_Prim,
      when others => Primitive.Invalid_Object);

   function Peek_Generated_Data (
      Obj  : Object_Type;
      Prim : Primitive.Object_Type)
   return Block_Data_Type
   is
      Data : Block_Data_Type;
   begin
      case Obj.SB_Slot_State is
      when Write_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Block_Data_From_Superblock_Ciphertext (Data, Obj.SB_Slot);
         return Data;

      when others =>

         raise Program_Error;

      end case;
   end Peek_Generated_Data;

   function Peek_Generated_Max_Lvl_Idx (
      Obj  : Object_Type;
      Prim : Primitive.Object_Type)
   return Tree_Level_Index_Type
   is
   begin
      case Obj.SB_Slot_State is
      when VBD_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Obj.VBD_Max_Lvl_Idx;

      when FT_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Obj.FT_Max_Lvl_Idx;

      when MT_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Obj.MT_Max_Lvl_Idx;

      when others =>

         raise Program_Error;

      end case;
   end Peek_Generated_Max_Lvl_Idx;

   function Peek_Generated_Max_Child_Idx (
      Obj  : Object_Type;
      Prim : Primitive.Object_Type)
   return Tree_Child_Index_Type
   is
   begin
      case Obj.SB_Slot_State is
      when VBD_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Tree_Child_Index_Type (Obj.VBD_Degree - 1);

      when FT_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Tree_Child_Index_Type (Obj.FT_Degree - 1);

      when MT_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Tree_Child_Index_Type (Obj.MT_Degree - 1);

      when others =>

         raise Program_Error;

      end case;
   end Peek_Generated_Max_Child_Idx;

   function Peek_Generated_Nr_Of_Leafs (
      Obj  : Object_Type;
      Prim : Primitive.Object_Type)
   return Tree_Number_Of_Leafs_Type
   is
   begin
      case Obj.SB_Slot_State is
      when VBD_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Obj.VBD_Nr_Of_Leafs;

      when FT_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Obj.FT_Nr_Of_Leafs;

      when MT_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         return Obj.MT_Nr_Of_Leafs;

      when others =>

         raise Program_Error;

      end case;
   end Peek_Generated_Nr_Of_Leafs;

   function Peek_Generated_Key_Value_Plaintext (
      Obj  : Object_Type;
      Prim : Primitive.Object_Type)
   return Key_Value_Plaintext_Type
   is
   begin
      case Obj.SB_Slot_State is
      when TA_Request_Encrypt_Key_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;

         return Obj.Key_Plain;

      when others =>

         raise Program_Error;

      end case;
   end Peek_Generated_Key_Value_Plaintext;

   function Peek_Generated_SB_Hash (
      Obj  : Object_Type;
      Prim : Primitive.Object_Type)
   return Hash_Type
   is
   begin
      case Obj.SB_Slot_State is
      when TA_Request_Secure_SB_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;

         return Obj.SB_Hash;

      when others =>

         raise Program_Error;

      end case;
   end Peek_Generated_SB_Hash;

   procedure Drop_Generated_Primitive (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type)
   is
   begin
      case Obj.SB_Slot_State is
      when Sync_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := Sync_Request_Dropped;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", sync dropped"));

      when Write_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := Write_Request_Dropped;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", write dropped"));

      when FT_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := FT_Request_Dropped;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ft dropped"));

      when MT_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := MT_Request_Dropped;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", mt dropped"));

      when VBD_Request_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := VBD_Request_Dropped;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", vbd dropped"));

      when TA_Request_Create_Key_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := TA_Request_Create_Key_Dropped;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta create key dropped"));

      when TA_Request_Encrypt_Key_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := TA_Request_Encrypt_Key_Dropped;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta encrypt key dropped"));

      when TA_Request_Secure_SB_Started =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := TA_Request_Secure_SB_Dropped;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta secure sb dropped"));

      when others =>

         raise Program_Error;

      end case;
   end Drop_Generated_Primitive;

   procedure Mark_Generated_Blk_IO_Primitive_Complete (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type)
   is
   begin
      case Obj.SB_Slot_State is
      when Sync_Request_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := Sync_Request_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", sync done"));

      when Write_Request_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := Write_Request_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", write done"));

      when others =>

         raise Program_Error;

      end case;
   end Mark_Generated_Blk_IO_Primitive_Complete;

   procedure Mark_Generated_VBD_Init_Primitive_Complete (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type;
      VBD  :        Type_1_Node_Type)
   is
   begin
      case Obj.SB_Slot_State is
      when VBD_Request_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.VBD := VBD;
         Obj.SB_Slot_State := VBD_Request_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", vbd done"));

      when others =>

         raise Program_Error;

      end case;
   end Mark_Generated_VBD_Init_Primitive_Complete;

   procedure Mark_Generated_FT_Init_Primitive_Complete (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type;
      FT   :        Type_1_Node_Type)
   is
   begin
      case Obj.SB_Slot_State is
      when FT_Request_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.FT := FT;
         Obj.SB_Slot_State := FT_Request_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ft done"));

      when MT_Request_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.MT := FT;
         Obj.SB_Slot_State := MT_Request_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", mt done"));

      when others =>

         raise Program_Error;

      end case;
   end Mark_Generated_FT_Init_Primitive_Complete;

   procedure Mark_Generated_MT_Init_Primitive_Complete (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type;
      MT   :        Type_1_Node_Type)
   is
   begin
      case Obj.SB_Slot_State is
      when MT_Request_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.MT := MT;
         Obj.SB_Slot_State := MT_Request_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", mt done"));

      when others =>

         raise Program_Error;

      end case;
   end Mark_Generated_MT_Init_Primitive_Complete;

   procedure Mark_Generated_TA_CK_Primitive_Complete (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type;
      Key  :        Key_Value_Plaintext_Type)
   is
   begin
      case Obj.SB_Slot_State is
      when TA_Request_Create_Key_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.Key_Plain     := Key;
         Obj.SB_Slot_State := TA_Request_Create_Key_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta create key done"));

      when others =>

         raise Program_Error;

      end case;
   end Mark_Generated_TA_CK_Primitive_Complete;

   procedure Mark_Generated_TA_EK_Primitive_Complete (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type;
      Key  :        Key_Value_Ciphertext_Type)
   is
   begin
      case Obj.SB_Slot_State is
      when TA_Request_Encrypt_Key_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.Key_Cipher    := Key;
         Obj.SB_Slot_State := TA_Request_Encrypt_Key_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta encrypt key done"));

      when others =>

         raise Program_Error;

      end case;
   end Mark_Generated_TA_EK_Primitive_Complete;

   procedure Mark_Generated_TA_Secure_SB_Primitive_Complete (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type)
   is
   begin
      case Obj.SB_Slot_State is
      when TA_Request_Secure_SB_Dropped =>

         if not Primitive.Equal (Obj.Generated_Prim, Prim) then
            raise Program_Error;
         end if;
         Obj.SB_Slot_State := TA_Request_Secure_SB_Done;

         pragma Debug (
            Debug.Print_String (
               "[sb_init] slot " &
               Debug.To_String (Debug.Uint64_Type (Obj.SB_Slot_Idx)) &
               ", ta secure sb done"));

      when others =>

         raise Program_Error;

      end case;
   end Mark_Generated_TA_Secure_SB_Primitive_Complete;

end CBE.Superblock_Initializer;
