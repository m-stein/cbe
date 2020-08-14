--
--  Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
--  This file is part of the Consistent Block Encrypter project, which is
--  distributed under the terms of the GNU Affero General Public License
--  version 3.
--

pragma Ada_2012;

with SHA256_4K;
with Interfaces;
with CBE.Debug;

pragma Unreferenced (CBE.Debug);

use Interfaces;

package body CBE.VBD_Rekeying
with SPARK_Mode
is
   --
   --  CBE_Hash_From_SHA256_4K_Hash
   --
   procedure CBE_Hash_From_SHA256_4K_Hash (
      CBE_Hash : out Hash_Type;
      SHA_Hash :     SHA256_4K.Hash_Type);

   --
   --  SHA256_4K_Data_From_CBE_Data
   --
   procedure SHA256_4K_Data_From_CBE_Data (
      SHA_Data : out SHA256_4K.Data_Type;
      CBE_Data :     Block_Data_Type);

   --
   --  Hash_Of_T1_Node_Blk
   --
   function Hash_Of_T1_Node_Blk (T1_Blk : Type_1_Node_Block_Type)
   return Hash_Type;

   --
   --  Hash_Of_Data_Blk
   --
   function Hash_Of_Data_Blk (CBE_Data : Block_Data_Type)
   return Hash_Type;

   --
   --  CBE_Hash_From_SHA256_4K_Hash
   --
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

   --
   --  SHA256_4K_Data_From_CBE_Data
   --
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

   --
   --  Hash_Of_T1_Node_Blk
   --
   function Hash_Of_T1_Node_Blk (T1_Blk : Type_1_Node_Block_Type)
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
         Block_Data_From_Type_1_Node_Block (CBE_Data, T1_Blk);
         SHA256_4K_Data_From_CBE_Data (SHA_Data, CBE_Data);
         SHA256_4K.Hash (SHA_Data, SHA_Hash);
         CBE_Hash_From_SHA256_4K_Hash (CBE_Hash, SHA_Hash);
         return CBE_Hash;
      end Declare_Hash_Data;

   end Hash_Of_T1_Node_Blk;

   --
   --  Hash_Of_Data_Blk
   --
   function Hash_Of_Data_Blk (CBE_Data : Block_Data_Type)
   return Hash_Type
   is
      SHA_Hash : SHA256_4K.Hash_Type;
      SHA_Data : SHA256_4K.Data_Type;
      CBE_Hash : Hash_Type;
   begin
      SHA256_4K_Data_From_CBE_Data (SHA_Data, CBE_Data);
      SHA256_4K.Hash (SHA_Data, SHA_Hash);
      CBE_Hash_From_SHA256_4K_Hash (CBE_Hash, SHA_Hash);
      return CBE_Hash;
   end Hash_Of_Data_Blk;

   --
   --  Log_2
   --
   function  Log_2 (Value : Unsigned_32)
   return Unsigned_32
   is
      type Bit_Index_Type is range 0 .. 31;
   begin
      if Value = 0 then
         raise Program_Error;
      end if;
      for Bit_Index in reverse Bit_Index_Type'Range loop
         if (
            Value and
            Shift_Left (Unsigned_32 (1), Natural (Bit_Index))) /= 0
         then
            return Unsigned_32 (Bit_Index);
         end if;
      end loop;
      raise Program_Error;
   end Log_2;

   --
   --  Initialize_Rekeying
   --
   procedure Initialize_Rekeying (Rkg : out Rekeying_Type)
   is
   begin
      Initialize_Each_Job :
      for Idx in Rkg.Jobs'Range loop
         Rkg.Jobs (Idx) := (
            Operation => Invalid,
            State => Job_State_Type'First,
            Submitted_Prim => Primitive.Invalid_Object,
            Generated_Prim => Primitive.Invalid_Object,
            Snapshots => (others => Snapshot_Invalid),
            Snapshots_Degree => Tree_Degree_Type'First,
            Snapshot_Idx => Snapshots_Index_Type'First,
            First_Snapshot => Boolean'First,
            Old_Key_ID => Key_ID_Type'First,
            New_Key_ID => Key_ID_Type'First,
            T1_Blks => (others => (others => Type_1_Node_Invalid)),
            T1_Blks_Old_PBAs => (others => Physical_Block_Address_Type'First),
            T1_Blk_Idx => Type_1_Node_Blocks_Index_Type'First,
            Data_Blk => (others => Byte_Type'First),
            Data_Blk_Old_PBA => Physical_Block_Address_Type'First,
            VBA => Virtual_Block_Address_Type'First,
            T1_Node_Walk => (others => Type_1_Node_Invalid),
            New_PBAs => (others => Physical_Block_Address_Type'First),
            PBA => Physical_Block_Address_Type'First,
            Req => Request.Invalid_Object,
            Nr_Of_PBAs => Number_Of_Blocks_Type'First,
            Nr_Of_Blks => Number_Of_Blocks_Type'First,
            Nr_Of_Leaves => Tree_Number_Of_Leafs_Type'First,
            Curr_Gen => Generation_Type'First,
            Last_Secured_Gen => Generation_Type'First,
            Hash => (others => Byte_Type'First),
            Free_Gen => Generation_Type'First);
      end loop Initialize_Each_Job;
   end Initialize_Rekeying;

   --
   --  Primitive_Acceptable
   --
   function Primitive_Acceptable (Rkg : Rekeying_Type)
   return Boolean
   is (for some Job of Rkg.Jobs => Job.Operation = Invalid);

   --
   --  Submit_Primitive_Resizing
   --
   procedure Submit_Primitive_Resizing (
      Rkg              : in out Rekeying_Type;
      Prim             :        Primitive.Object_Type;
      Curr_Gen         :        Generation_Type;
      Last_Secured_Gen :        Generation_Type;
      Snapshots        :        Snapshots_Type;
      Snapshots_Degree :        Tree_Degree_Type;
      First_PBA        :        Physical_Block_Address_Type;
      Nr_Of_PBAs       :        Number_Of_Blocks_Type)
   is
   begin

      Find_Invalid_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation = Invalid then

            case Primitive.Tag (Prim) is
            when Primitive.Tag_SB_Ctrl_VBD_Rkg_VBD_Ext_Step =>

               Rkg.Jobs (Idx).Operation        := VBD_Extension_Step;
               Rkg.Jobs (Idx).Submitted_Prim   := Prim;
               Rkg.Jobs (Idx).Curr_Gen         := Curr_Gen;
               Rkg.Jobs (Idx).Last_Secured_Gen := Last_Secured_Gen;
               Rkg.Jobs (Idx).Snapshots        := Snapshots;
               Rkg.Jobs (Idx).Snapshots_Degree := Snapshots_Degree;
               Rkg.Jobs (Idx).PBA              := First_PBA;
               Rkg.Jobs (Idx).Nr_Of_PBAs       := Nr_Of_PBAs;
               Rkg.Jobs (Idx).State            := Submitted;
               return;

            when others =>

               raise Program_Error;

            end case;

         end if;

      end loop Find_Invalid_Job;
      raise Program_Error;

   end Submit_Primitive_Resizing;

   --
   --  Submit_Primitive_Rekeying
   --
   procedure Submit_Primitive_Rekeying (
      Rkg              : in out Rekeying_Type;
      Prim             :        Primitive.Object_Type;
      Curr_Gen         :        Generation_Type;
      Last_Secured_Gen :        Generation_Type;
      VBA              :        Virtual_Block_Address_Type;
      Snapshots        :        Snapshots_Type;
      Snapshots_Degree :        Tree_Degree_Type;
      Old_Key_ID       :        Key_ID_Type;
      New_Key_ID       :        Key_ID_Type)
   is
   begin

      Find_Invalid_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation = Invalid then

            case Primitive.Tag (Prim) is
            when Primitive.Tag_SB_Ctrl_VBD_Rkg_Rekey_VBA =>

               Rkg.Jobs (Idx).Operation        := Rekey_VBA;
               Rkg.Jobs (Idx).Submitted_Prim   := Prim;
               Rkg.Jobs (Idx).Curr_Gen         := Curr_Gen;
               Rkg.Jobs (Idx).Last_Secured_Gen := Last_Secured_Gen;
               Rkg.Jobs (Idx).VBA              := VBA;
               Rkg.Jobs (Idx).Snapshots        := Snapshots;
               Rkg.Jobs (Idx).Snapshots_Degree := Snapshots_Degree;
               Rkg.Jobs (Idx).Old_Key_ID       := Old_Key_ID;
               Rkg.Jobs (Idx).New_Key_ID       := New_Key_ID;
               Rkg.Jobs (Idx).State            := Submitted;
               return;

            when others =>

               raise Program_Error;

            end case;

         end if;

      end loop Find_Invalid_Job;
      raise Program_Error;

   end Submit_Primitive_Rekeying;

   --
   --  Submit_Primitive_Read_VBA
   --
   procedure Submit_Primitive_Read_VBA (
      Rkg              : in out Rekeying_Type;
      Prim             :        Primitive.Object_Type;
      Req              :        Request.Object_Type;
      Snapshot         :        Snapshot_Type;
      Snapshots_Degree :        Tree_Degree_Type;
      Key_ID           :        Key_ID_Type)
   is
   begin

      Find_Invalid_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation = Invalid then

            case Primitive.Tag (Prim) is
            when Primitive.Tag_SB_Ctrl_VBD_Rkg_Read_VBA =>

               Rkg.Jobs (Idx).Operation        := Read_VBA;
               Rkg.Jobs (Idx).Submitted_Prim   := Prim;
               Rkg.Jobs (Idx).Snapshots (0)    := Snapshot;
               Rkg.Jobs (Idx).Snapshots_Degree := Snapshots_Degree;
               Rkg.Jobs (Idx).Req              := Req;
               Rkg.Jobs (Idx).State            := Submitted;
               Rkg.Jobs (Idx).New_Key_ID       := Key_ID;
               return;

            when others =>

               raise Program_Error;

            end case;

         end if;

      end loop Find_Invalid_Job;
      raise Program_Error;

   end Submit_Primitive_Read_VBA;

   --
   --  Submit_Primitive_Write_VBA
   --
   procedure Submit_Primitive_Write_VBA (
      Rkg              : in out Rekeying_Type;
      Prim             :        Primitive.Object_Type;
      Curr_Gen         :        Generation_Type;
      Req              :        Request.Object_Type;
      Snapshot         :        Snapshot_Type;
      Snapshots_Degree :        Tree_Degree_Type;
      Key_ID           :        Key_ID_Type)
   is
   begin

      Find_Invalid_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation = Invalid then

            case Primitive.Tag (Prim) is
            when Primitive.Tag_SB_Ctrl_VBD_Rkg_Write_VBA =>

               Rkg.Jobs (Idx).Operation        := Write_VBA;
               Rkg.Jobs (Idx).Submitted_Prim   := Prim;
               Rkg.Jobs (Idx).Curr_Gen         := Curr_Gen;
               Rkg.Jobs (Idx).Snapshots (0)    := Snapshot;
               Rkg.Jobs (Idx).Snapshots_Degree := Snapshots_Degree;
               Rkg.Jobs (Idx).Req              := Req;
               Rkg.Jobs (Idx).State            := Submitted;
               Rkg.Jobs (Idx).New_Key_ID       := Key_ID;
               return;

            when others =>

               raise Program_Error;

            end case;

         end if;

      end loop Find_Invalid_Job;
      raise Program_Error;

   end Submit_Primitive_Write_VBA;

   --
   --  Peek_Completed_Primitive
   --
   function Peek_Completed_Primitive (Rkg : Rekeying_Type)
   return Primitive.Object_Type
   is
   begin
      Find_Completed_Job :
      for Idx in Rkg.Jobs'Range loop
         if Rkg.Jobs (Idx).Operation /= Invalid and then
            Rkg.Jobs (Idx).State = Completed
         then
            return Rkg.Jobs (Idx).Submitted_Prim;
         end if;
      end loop Find_Completed_Job;
      return Primitive.Invalid_Object;
   end Peek_Completed_Primitive;

   --
   --  Peek_Completed_Snapshots
   --
   function Peek_Completed_Snapshots (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Snapshots_Type
   is
   begin

      Find_Corresponding_Job :
      for Idx in Rkg.Jobs'Range loop

         case Rkg.Jobs (Idx).Operation is
         when Rekey_VBA | VBD_Extension_Step =>

            if Rkg.Jobs (Idx).State = Completed and then
               Primitive.Equal (Prim, Rkg.Jobs (Idx).Submitted_Prim)
            then
               return Rkg.Jobs (Idx).Snapshots;
            end if;

         when others =>

            null;

         end case;

      end loop Find_Corresponding_Job;
      raise Program_Error;

   end Peek_Completed_Snapshots;

   --
   --  Peek_Completed_Snap
   --
   function Peek_Completed_Snap (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Snapshot_Type
   is
   begin

      Find_Corresponding_Job :
      for Idx in Rkg.Jobs'Range loop

         case Rkg.Jobs (Idx).Operation is
         when Write_VBA =>

            if Rkg.Jobs (Idx).State = Completed and then
               Primitive.Equal (Prim, Rkg.Jobs (Idx).Submitted_Prim)
            then
               return Rkg.Jobs (Idx).Snapshots (0);
            end if;

         when others =>

            null;

         end case;

      end loop Find_Corresponding_Job;
      raise Program_Error;

   end Peek_Completed_Snap;

   --
   --  Peek_Completed_Nr_Of_Leaves
   --
   function Peek_Completed_Nr_Of_Leaves (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Tree_Number_Of_Leafs_Type
   is
   begin

      Find_Corresponding_Job :
      for Idx in Rkg.Jobs'Range loop

         case Rkg.Jobs (Idx).Operation is
         when VBD_Extension_Step =>

            if Rkg.Jobs (Idx).State = Completed and then
               Primitive.Equal (Prim, Rkg.Jobs (Idx).Submitted_Prim)
            then
               return Rkg.Jobs (Idx).Nr_Of_Leaves;
            end if;

         when others =>

            null;

         end case;

      end loop Find_Corresponding_Job;
      raise Program_Error;

   end Peek_Completed_Nr_Of_Leaves;

   --
   --  Peek_Completed_PBA
   --
   function Peek_Completed_PBA (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Physical_Block_Address_Type
   is
   begin

      Find_Corresponding_Job :
      for Idx in Rkg.Jobs'Range loop

         case Rkg.Jobs (Idx).Operation is
         when VBD_Extension_Step =>

            if Rkg.Jobs (Idx).State = Completed and then
               Primitive.Equal (Prim, Rkg.Jobs (Idx).Submitted_Prim)
            then
               return Rkg.Jobs (Idx).PBA;
            end if;

         when others =>

            null;

         end case;

      end loop Find_Corresponding_Job;
      raise Program_Error;

   end Peek_Completed_PBA;

   --
   --  Peek_Completed_Nr_Of_PBAs
   --
   function Peek_Completed_Nr_Of_PBAs (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Number_Of_Blocks_Type
   is
   begin

      Find_Corresponding_Job :
      for Idx in Rkg.Jobs'Range loop

         case Rkg.Jobs (Idx).Operation is
         when VBD_Extension_Step =>

            if Rkg.Jobs (Idx).State = Completed and then
               Primitive.Equal (Prim, Rkg.Jobs (Idx).Submitted_Prim)
            then
               return Rkg.Jobs (Idx).Nr_Of_PBAs;
            end if;

         when others =>

            null;

         end case;

      end loop Find_Corresponding_Job;
      raise Program_Error;

   end Peek_Completed_Nr_Of_PBAs;

   --
   --  Drop_Completed_Primitive
   --
   procedure Drop_Completed_Primitive (
      Rkg  : in out Rekeying_Type;
      Prim :        Primitive.Object_Type)
   is
   begin

      Find_Corresponding_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation /= Invalid and then
            Rkg.Jobs (Idx).State = Completed and then
            Primitive.Equal (Prim, Rkg.Jobs (Idx).Submitted_Prim)
         then
            Rkg.Jobs (Idx).Operation := Invalid;
            return;
         end if;

      end loop Find_Corresponding_Job;
      raise Program_Error;

   end Drop_Completed_Primitive;

   --
   --  Child_Idx_For_VBA
   --
   function Child_Idx_For_VBA (
      VBA  : Virtual_Block_Address_Type;
      Lvl  : Type_1_Node_Blocks_Index_Type;
      Degr : Tree_Degree_Type)
   return Type_1_Node_Block_Index_Type
   is
      Degree_Log_2 : constant Tree_Degree_Log_2_Type :=
         Tree_Degree_Log_2_Type (Log_2 (Unsigned_32 (Degr)));

      Degree_Mask : constant Tree_Degree_Mask_Type :=
         Tree_Degree_Mask_Type (
            Shift_Left (Unsigned_32 (1), Natural (Degree_Log_2)) - 1);
   begin
      return
         Type_1_Node_Block_Index_Type (
            Shift_Right (
               Unsigned_64 (VBA),
               Natural (Unsigned_32 (Degree_Log_2) * (Unsigned_32 (Lvl) - 1)))
            and
            Unsigned_64 (Degree_Mask));
   end Child_Idx_For_VBA;

   --
   --  Alloc_PBA_From_Resizing_Contingent
   --
   procedure Alloc_PBA_From_Resizing_Contingent (
      First_PBA     : in out Physical_Block_Address_Type;
      Nr_Of_PBAs    : in out Number_Of_Blocks_Type;
      Allocated_PBA :    out Physical_Block_Address_Type)
   is
   begin

      if Nr_Of_PBAs = 0 then
         raise Program_Error;
      end if;

      Allocated_PBA := First_PBA;
      First_PBA := First_PBA + 1;
      Nr_Of_PBAs := Nr_Of_PBAs - 1;

   end Alloc_PBA_From_Resizing_Contingent;

   --
   --  Add_New_Root_Lvl_To_Snap_Using_PBA_Contingent
   --
   procedure Add_New_Root_Lvl_To_Snap_Using_PBA_Contingent (
      Snapshots        : in out Snapshots_Type;
      Snap_Idx         : in out Snapshots_Index_Type;
      Curr_Gen         :        Generation_Type;
      Last_Secured_Gen :        Generation_Type;
      T1_Blks          : in out Type_1_Node_Blocks_Type;
      First_PBA        : in out Physical_Block_Address_Type;
      Nr_Of_PBAs       : in out Number_Of_Blocks_Type)
   is
      Old_Snap_Idx : constant Snapshots_Index_Type := Snap_Idx;
      New_Snap_PBA : Physical_Block_Address_Type;
   begin

      if Snapshots (Snap_Idx).Max_Level = Tree_Level_Index_Type'Last then
         raise Program_Error;
      end if;

      T1_Blks (Snapshots (Snap_Idx).Max_Level + 1) := (
         0 => (
            PBA  => Snapshots (Snap_Idx).PBA,
            Gen  => Snapshots (Snap_Idx).Gen,
            Hash => Snapshots (Snap_Idx).Hash),

         others => Type_1_Node_Invalid);

      if Snapshots (Snap_Idx).Gen < Curr_Gen then
         Snap_Idx :=
            Idx_Of_Invalid_Or_Lowest_Gen_Evictable_Snap (
               Snapshots, Curr_Gen, Last_Secured_Gen);

         pragma Debug (Debug.Print_String (
            "   NEW SNAP " &
            Debug.To_String (Debug.Uint64_Type (
               Snap_Idx))));
      end if;

      Alloc_PBA_From_Resizing_Contingent (First_PBA, Nr_Of_PBAs, New_Snap_PBA);

      Snapshots (Snap_Idx) := (
         PBA => New_Snap_PBA,
         Gen => Curr_Gen,
         Hash => (others => 0),
         Nr_Of_Leafs => Snapshots (Old_Snap_Idx).Nr_Of_Leafs,
         Max_Level => Snapshots (Old_Snap_Idx).Max_Level + 1,
         Valid => True,
         ID => 0,
         Keep => False);

      pragma Debug (Debug.Print_String (
         "   UPDATE SNAP " &
         Debug.To_String (Debug.Uint64_Type (
            Snap_Idx)) &
         " PBA " &
         Debug.To_String (Debug.Uint64_Type (Snapshots (Snap_Idx).PBA)) &
         " GEN " &
         Debug.To_String (Debug.Uint64_Type (Snapshots (Snap_Idx).Gen)) &
         " LEAVES " &
         Debug.To_String (Debug.Uint64_Type (
            Snapshots (Snap_Idx).Nr_Of_Leafs)) &
         " MAX_LVL " &
         Debug.To_String (Debug.Uint64_Type (Snapshots (Snap_Idx).Max_Level)) &
         " "));

      pragma Debug (Debug.Print_String (
         "   UPDATE LVL " &
         Debug.To_String (Debug.Uint64_Type (Snapshots (Snap_Idx).Max_Level)) &
         " CHILD 0 PBA " &
         Debug.To_String (Debug.Uint64_Type (
            T1_Blks (Snapshots (Snap_Idx).Max_Level) (0).PBA)) &
         " GEN " &
         Debug.To_String (Debug.Uint64_Type (
            T1_Blks (Snapshots (Snap_Idx).Max_Level) (0).Gen)) &
         " "));

   end Add_New_Root_Lvl_To_Snap_Using_PBA_Contingent;

   --
   --  Add_New_Branch_To_Snap_Using_PBA_Contingent
   --
   procedure Add_New_Branch_To_Snap_Using_PBA_Contingent (
      Mount_Point_Lvl_Idx   :        Type_1_Node_Blocks_Index_Type;
      Mount_Point_Child_Idx :        Type_1_Node_Block_Index_Type;
      Snapshots_Degree      :        Tree_Degree_Type;
      First_PBA             : in out Physical_Block_Address_Type;
      Nr_Of_PBAs            : in out Number_Of_Blocks_Type;
      T1_Blks               : in out Type_1_Node_Blocks_Type;
      Stopped_At_Lvl_Idx    :    out Type_1_Node_Blocks_Index_Type;
      Nr_Of_Leaves          :    out Tree_Number_Of_Leafs_Type)
   is
   begin

      Nr_Of_Leaves := 0;
      Stopped_At_Lvl_Idx := Mount_Point_Lvl_Idx;

      if Mount_Point_Lvl_Idx > 1 then

         Reset_All_Lvls_Below_Mount_Point :
         for Lvl_Idx in 1 .. Mount_Point_Lvl_Idx - 1 loop

            T1_Blks (Lvl_Idx) := (others => Type_1_Node_Invalid);

         end loop Reset_All_Lvls_Below_Mount_Point;

      end if;

      if Nr_Of_PBAs > 0 then

         Set_Child_PBAs_In_New_Branch :
         for Lvl_Idx in reverse 1 .. Mount_Point_Lvl_Idx loop

            Stopped_At_Lvl_Idx := Lvl_Idx;

            if Lvl_Idx > 1 then

               exit Set_Child_PBAs_In_New_Branch when Nr_Of_PBAs = 0;

               Declare_Child_Args :
               declare
                  Child_Idx : constant Type_1_Node_Block_Index_Type := (
                     if Lvl_Idx = Mount_Point_Lvl_Idx
                     then Mount_Point_Child_Idx
                     else 0);

                  Child_PBA : Physical_Block_Address_Type;
               begin

                  Alloc_PBA_From_Resizing_Contingent (
                     First_PBA, Nr_Of_PBAs, Child_PBA);

                  T1_Blks (Lvl_Idx) (Child_Idx) := (
                     PBA => Child_PBA,
                     Gen => Initial_Generation,
                     Hash => (others => 0));

                  pragma Debug (Debug.Print_String (
                     "   UPDATE LVL " &
                     Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                     " CHILD " &
                     Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                     " PBA " &
                     Debug.To_String (Debug.Uint64_Type (
                        T1_Blks (Lvl_Idx) (Child_Idx).PBA)) &
                     " GEN " &
                     Debug.To_String (Debug.Uint64_Type (
                        T1_Blks (Lvl_Idx) (Child_Idx).Gen)) &
                     " " &
                     Debug.To_String (
                        T1_Blks (Lvl_Idx) (Child_Idx).Hash) &
                     " "));

               end Declare_Child_Args;

            else

               Declare_First_Child_Idx :
               declare
                  First_Child_Idx :
                     constant Type_1_Node_Block_Index_Type := (
                        if Lvl_Idx = Mount_Point_Lvl_Idx
                        then Mount_Point_Child_Idx
                        else 0);

                  Child_PBA : Physical_Block_Address_Type;
               begin

                  for Child_Idx in First_Child_Idx ..
                         Type_1_Node_Block_Index_Type (Snapshots_Degree - 1)
                  loop

                     exit Set_Child_PBAs_In_New_Branch when Nr_Of_PBAs = 0;

                     Alloc_PBA_From_Resizing_Contingent (
                        First_PBA, Nr_Of_PBAs, Child_PBA);

                     T1_Blks (Lvl_Idx) (Child_Idx) := (
                        PBA => Child_PBA,
                        Gen => Initial_Generation,
                        Hash => (others => 0));

                     pragma Debug (Debug.Print_String (
                        "   UPDATE LVL " &
                        Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                        " CHILD " &
                        Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                        " PBA " &
                        Debug.To_String (Debug.Uint64_Type (
                           T1_Blks (Lvl_Idx) (Child_Idx).PBA)) &
                        " GEN " &
                        Debug.To_String (Debug.Uint64_Type (
                           T1_Blks (Lvl_Idx) (Child_Idx).Gen)) &
                        " " &
                        Debug.To_String (
                           T1_Blks (Lvl_Idx) (Child_Idx).Hash) &
                        " "));

                     Nr_Of_Leaves := Nr_Of_Leaves + 1;

                  end loop;

               end Declare_First_Child_Idx;

            end if;

         end loop Set_Child_PBAs_In_New_Branch;

      end if;

   end Add_New_Branch_To_Snap_Using_PBA_Contingent;

   --
   --  Execute_VBD_Ext_Step_Read_Inner_Node_Completed
   --
   procedure Execute_VBD_Ext_Step_Read_Inner_Node_Completed (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress :    out Boolean)
   is
   begin

      if not Primitive.Success (Job.Generated_Prim) then
         raise Program_Error;
      end if;

      if Job.T1_Blk_Idx = Job.Snapshots (Job.Snapshot_Idx).Max_Level then

         if Hash_Of_T1_Node_Blk (Job.T1_Blks (Job.T1_Blk_Idx)) /=
               Job.Snapshots (Job.Snapshot_Idx).Hash
         then
            raise Program_Error;
         end if;

      else

         Declare_Child_Idx_1 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx + 1;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);
         begin
            if Hash_Of_T1_Node_Blk (Job.T1_Blks (Job.T1_Blk_Idx)) /=
                  Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).Hash
            then
               raise Program_Error;
            end if;
         end Declare_Child_Idx_1;

      end if;

      if Job.T1_Blk_Idx > 1 then

         Declare_Child_1 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx;

            Child_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx - 1;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child : constant Type_1_Node_Type :=
               Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx);
         begin

            if Type_1_Node_Valid (Child) then

               Job.T1_Blk_Idx := Child_Lvl_Idx;
               Job.T1_Blks_Old_PBAs (Child_Lvl_Idx) := Child.PBA;
               Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
                  Op     => Read,
                  Succ   => False,
                  Tg     => Primitive.Tag_VBD_Rkg_Cache,
                  Blk_Nr => Block_Number_Type (Child.PBA),
                  Idx    => Primitive.Index_Type (Job_Idx));

               Job.State := Read_Inner_Node_Pending;
               Progress := True;

               pragma Debug (Debug.Print_String (
                  "   READ LVL " &
                  Debug.To_String (Debug.Uint64_Type (Child_Lvl_Idx)) &
                  " PARENT LVL " &
                  Debug.To_String (Debug.Uint64_Type (Parent_Lvl_Idx)) &
                  " CHILD " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  " PBA " &
                  Debug.To_String (Debug.Uint64_Type (Child.PBA)) &
                  " GEN " &
                  Debug.To_String (Debug.Uint64_Type (Child.Gen)) &
                  " " &
                  Debug.To_String (Child.Hash) &
                  " "));

            else

               Add_New_Branch_To_Snap_Using_PBA_Contingent (
                  Mount_Point_Lvl_Idx   => Parent_Lvl_Idx,
                  Mount_Point_Child_Idx => Child_Idx,
                  Snapshots_Degree      => Job.Snapshots_Degree,
                  First_PBA             => Job.PBA,
                  Nr_Of_PBAs            => Job.Nr_Of_PBAs,
                  T1_Blks               => Job.T1_Blks,
                  Stopped_At_Lvl_Idx    => Job.T1_Blk_Idx,
                  Nr_Of_Leaves          => Job.Nr_Of_Leaves);

               Set_Args_For_Alloc_Of_New_PBAs_For_Resizing (
                  Curr_Gen        => Job.Curr_Gen,
                  Snapshot        => Job.Snapshots (Job.Snapshot_Idx),
                  Snapshot_Degree => Job.Snapshots_Degree,
                  VBA             => Job.VBA,
                  Min_Lvl_Idx     => Parent_Lvl_Idx,
                  Prim_Idx        => Primitive.Index_Type (Job_Idx),
                  T1_Blks         => Job.T1_Blks,
                  T1_Walk         => Job.T1_Node_Walk,
                  New_PBAs        => Job.New_PBAs,
                  Nr_Of_Blks      => Job.Nr_Of_Blks,
                  Free_Gen        => Job.Free_Gen,
                  Prim            => Job.Generated_Prim);

               Job.State := Alloc_PBAs_At_Lowest_Inner_Lvl_Pending;
               Progress := True;

            end if;

         end Declare_Child_1;

      else

         Declare_Child_3 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child : constant Type_1_Node_Type :=
               Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx);
         begin

            if Type_1_Node_Valid (Child) then
               raise Program_Error;
            end if;

            Add_New_Branch_To_Snap_Using_PBA_Contingent (
               Mount_Point_Lvl_Idx   => Parent_Lvl_Idx,
               Mount_Point_Child_Idx => Child_Idx,
               Snapshots_Degree      => Job.Snapshots_Degree,
               First_PBA             => Job.PBA,
               Nr_Of_PBAs            => Job.Nr_Of_PBAs,
               T1_Blks               => Job.T1_Blks,
               Stopped_At_Lvl_Idx    => Job.T1_Blk_Idx,
               Nr_Of_Leaves          => Job.Nr_Of_Leaves);

            Set_Args_For_Alloc_Of_New_PBAs_For_Resizing (
               Curr_Gen          => Job.Curr_Gen,
               Snapshot          => Job.Snapshots (Job.Snapshot_Idx),
               Snapshot_Degree   => Job.Snapshots_Degree,
               VBA               => Job.VBA,
               Min_Lvl_Idx       => Parent_Lvl_Idx,
               Prim_Idx          => Primitive.Index_Type (Job_Idx),
               T1_Blks           => Job.T1_Blks,
               T1_Walk           => Job.T1_Node_Walk,
               New_PBAs          => Job.New_PBAs,
               Nr_Of_Blks        => Job.Nr_Of_Blks,
               Free_Gen          => Job.Free_Gen,
               Prim              => Job.Generated_Prim);

            Job.State := Alloc_PBAs_At_Lowest_Inner_Lvl_Pending;
            Progress := True;

         end Declare_Child_3;

      end if;

   end Execute_VBD_Ext_Step_Read_Inner_Node_Completed;

   --
   --  Check_Hash_Of_Read_Type_1_Node
   --
   procedure Check_Hash_Of_Read_Type_1_Node (
      Snapshot         : Snapshot_Type;
      Snapshots_Degree : Tree_Degree_Type;
      T1_Blk_Idx       : Type_1_Node_Blocks_Index_Type;
      T1_Blks          : Type_1_Node_Blocks_Type;
      VBA              : Virtual_Block_Address_Type)
   is
   begin

      if T1_Blk_Idx = Snapshot.Max_Level then

         if Hash_Of_T1_Node_Blk (T1_Blks (T1_Blk_Idx)) /= Snapshot.Hash then
            raise Program_Error;
         end if;

      else

         Declare_Child_Idx :
         declare
            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (VBA, T1_Blk_Idx + 1, Snapshots_Degree);
         begin

            if Hash_Of_T1_Node_Blk (T1_Blks (T1_Blk_Idx)) /=
                  T1_Blks (T1_Blk_Idx + 1) (Child_Idx).Hash
            then
               raise Program_Error;
            end if;

         end Declare_Child_Idx;

      end if;

   end Check_Hash_Of_Read_Type_1_Node;

   --
   --  Set_Args_In_Order_To_Read_Type_1_Node
   --
   procedure Set_Args_In_Order_To_Read_Type_1_Node (
      Snapshot         :     Snapshot_Type;
      Snapshots_Degree :     Tree_Degree_Type;
      T1_Blks          :     Type_1_Node_Blocks_Type;
      T1_Blk_Idx       :     Type_1_Node_Blocks_Index_Type;
      VBA              :     Virtual_Block_Address_Type;
      Job_Idx          :     Jobs_Index_Type;
      State            : out Job_State_Type;
      Generated_Prim   : out Primitive.Object_Type;
      Progress         : out Boolean)
   is
   begin

      if T1_Blk_Idx = Snapshot.Max_Level then

         Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
            Op     => Read,
            Succ   => False,
            Tg     => Primitive.Tag_VBD_Rkg_Cache,
            Blk_Nr => Block_Number_Type (Snapshot.PBA),
            Idx    => Primitive.Index_Type (Job_Idx));

      else

         Declare_Child :
         declare
            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (VBA, T1_Blk_Idx + 1, Snapshots_Degree);

            Child : constant Type_1_Node_Type :=
               T1_Blks (T1_Blk_Idx + 1) (Child_Idx);
         begin

            Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
               Op     => Read,
               Succ   => False,
               Tg     => Primitive.Tag_VBD_Rkg_Cache,
               Blk_Nr => Block_Number_Type (Child.PBA),
               Idx    => Primitive.Index_Type (Job_Idx));

         end Declare_Child;

      end if;

      State := Read_Inner_Node_Pending;
      Progress := True;

   end Set_Args_In_Order_To_Read_Type_1_Node;

   --
   --  Execute_Read_VBA_Read_Inner_Node_Completed
   --
   procedure Execute_Read_VBA_Read_Inner_Node_Completed (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress :    out Boolean)
   is
   begin
      if not Primitive.Success (Job.Generated_Prim) then
         raise Program_Error;
      end if;

      if Job.T1_Blk_Idx = Job.Snapshots (Job.Snapshot_Idx).Max_Level then

         if Hash_Of_T1_Node_Blk (Job.T1_Blks (Job.T1_Blk_Idx)) /=
               Job.Snapshots (Job.Snapshot_Idx).Hash
         then
            raise Program_Error;
         end if;

      else

         Declare_Child_Idx_1 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx + 1;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);
         begin
            if Hash_Of_T1_Node_Blk (Job.T1_Blks (Job.T1_Blk_Idx)) /=
                  Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).Hash
            then
               raise Program_Error;
            end if;
         end Declare_Child_Idx_1;

      end if;

      if Job.T1_Blk_Idx > 1 then

         Declare_Child_1 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx;

            Child_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx - 1;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child : constant Type_1_Node_Type :=
               Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx);
         begin

            Job.T1_Blk_Idx := Child_Lvl_Idx;
            Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
               Op     => Read,
               Succ   => False,
               Tg     => Primitive.Tag_VBD_Rkg_Cache,
               Blk_Nr => Block_Number_Type (Child.PBA),
               Idx    => Primitive.Index_Type (Job_Idx));

            Job.State := Read_Inner_Node_Pending;
            Progress := True;

         end Declare_Child_1;

      else

         Declare_Child_2 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child : constant Type_1_Node_Type :=
               Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx);
         begin

            Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
               Op     => Read,
               Succ   => False,
               Tg     => Primitive.Tag_VBD_Rkg_Blk_IO_Read_Client_Data,
               Blk_Nr => Block_Number_Type (Child.PBA),
               Idx    => Primitive.Index_Type (Job_Idx));

            Job.State := Read_Client_Data_From_Leaf_Node_Pending;
            Progress := True;

         end Declare_Child_2;

      end if;

   end Execute_Read_VBA_Read_Inner_Node_Completed;

   --
   --  Execute_Rekey_VBA_Read_Inner_Node_Completed
   --
   procedure Execute_Rekey_VBA_Read_Inner_Node_Completed (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress :    out Boolean)
   is
   begin
      if not Primitive.Success (Job.Generated_Prim) then
         raise Program_Error;
      end if;

      if Job.T1_Blk_Idx = Job.Snapshots (Job.Snapshot_Idx).Max_Level then

         if Hash_Of_T1_Node_Blk (Job.T1_Blks (Job.T1_Blk_Idx)) /=
               Job.Snapshots (Job.Snapshot_Idx).Hash
         then
            raise Program_Error;
         end if;

      else

         Declare_Child_Idx_1 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx + 1;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);
         begin
            if Hash_Of_T1_Node_Blk (Job.T1_Blks (Job.T1_Blk_Idx)) /=
                  Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).Hash
            then
               raise Program_Error;
            end if;
         end Declare_Child_Idx_1;

      end if;

      if Job.T1_Blk_Idx > 1 then

         Declare_Child_1 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx;

            Child_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx - 1;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child : constant Type_1_Node_Type :=
               Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx);
         begin

            if not Job.First_Snapshot and then
               Job.T1_Blks_Old_PBAs (Child_Lvl_Idx) = Child.PBA
            then

               Job.T1_Blk_Idx := Child_Lvl_Idx;

               Set_Args_For_Alloc_Of_New_PBAs_For_Rekeying (
                  For_Curr_Gen_Blks => Job.First_Snapshot,
                  Curr_Gen          => Job.Curr_Gen,
                  Snapshot          => Job.Snapshots (Job.Snapshot_Idx),
                  Snapshot_Degree   => Job.Snapshots_Degree,
                  VBA               => Job.VBA,
                  Min_Lvl_Idx       => Parent_Lvl_Idx,
                  Prim_Idx          => Primitive.Index_Type (Job_Idx),
                  T1_Blks           => Job.T1_Blks,
                  T1_Walk           => Job.T1_Node_Walk,
                  New_PBAs          => Job.New_PBAs,
                  Nr_Of_Blks        => Job.Nr_Of_Blks,
                  Free_Gen          => Job.Free_Gen,
                  Prim              => Job.Generated_Prim);

               Job.State := Alloc_PBAs_At_Higher_Inner_Lvl_Pending;
               Progress := True;

            else

               Job.T1_Blk_Idx := Child_Lvl_Idx;
               Job.T1_Blks_Old_PBAs (Child_Lvl_Idx) := Child.PBA;
               Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
                  Op     => Read,
                  Succ   => False,
                  Tg     => Primitive.Tag_VBD_Rkg_Cache,
                  Blk_Nr => Block_Number_Type (Child.PBA),
                  Idx    => Primitive.Index_Type (Job_Idx));

               Job.State := Read_Inner_Node_Pending;
               Progress := True;

            end if;

         end Declare_Child_1;

      else

         Declare_Child_2 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child : constant Type_1_Node_Type :=
               Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx);
         begin

            if not Job.First_Snapshot and then
               Job.Data_Blk_Old_PBA = Child.PBA
            then

               Set_Args_For_Alloc_Of_New_PBAs_For_Rekeying (
                  For_Curr_Gen_Blks => Job.First_Snapshot,
                  Curr_Gen          => Job.Curr_Gen,
                  Snapshot          => Job.Snapshots (Job.Snapshot_Idx),
                  Snapshot_Degree   => Job.Snapshots_Degree,
                  VBA               => Job.VBA,
                  Min_Lvl_Idx       => Parent_Lvl_Idx,
                  Prim_Idx          => Primitive.Index_Type (Job_Idx),
                  T1_Blks           => Job.T1_Blks,
                  T1_Walk           => Job.T1_Node_Walk,
                  New_PBAs          => Job.New_PBAs,
                  Nr_Of_Blks        => Job.Nr_Of_Blks,
                  Free_Gen          => Job.Free_Gen,
                  Prim              => Job.Generated_Prim);

               Job.State := Alloc_PBAs_At_Lowest_Inner_Lvl_Pending;
               Progress := True;

            elsif Child.Gen = Initial_Generation then

               Set_Args_For_Alloc_Of_New_PBAs_For_Rekeying (
                  For_Curr_Gen_Blks => Job.First_Snapshot,
                  Curr_Gen          => Job.Curr_Gen,
                  Snapshot          => Job.Snapshots (Job.Snapshot_Idx),
                  Snapshot_Degree   => Job.Snapshots_Degree,
                  VBA               => Job.VBA,
                  Min_Lvl_Idx       => 0,
                  Prim_Idx          => Primitive.Index_Type (Job_Idx),
                  T1_Blks           => Job.T1_Blks,
                  T1_Walk           => Job.T1_Node_Walk,
                  New_PBAs          => Job.New_PBAs,
                  Nr_Of_Blks        => Job.Nr_Of_Blks,
                  Free_Gen          => Job.Free_Gen,
                  Prim              => Job.Generated_Prim);

               Job.State := Alloc_PBAs_At_Lowest_Inner_Lvl_Pending;
               Progress := True;

            else

               Job.Data_Blk_Old_PBA := Child.PBA;

               Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
                  Op     => Read,
                  Succ   => False,
                  Tg     => Primitive.Tag_VBD_Rkg_Blk_IO,
                  Blk_Nr => Block_Number_Type (Child.PBA),
                  Idx    => Primitive.Index_Type (Job_Idx));

               Job.State := Read_Leaf_Node_Pending;
               Progress := True;

            end if;

         end Declare_Child_2;

      end if;

   end Execute_Rekey_VBA_Read_Inner_Node_Completed;

   --
   --  Set_New_PBAs_Identical_To_Current_PBAs
   --
   procedure Set_New_PBAs_Identical_To_Current_PBAs (
      Snapshot          :     Snapshot_Type;
      Snapshot_Degree   :     Tree_Degree_Type;
      VBA               :     Virtual_Block_Address_Type;
      T1_Blks           :     Type_1_Node_Blocks_Type;
      New_PBAs          : out Tree_Level_PBAs_Type)
   is
   begin

      For_Each_Lvl :
      for Lvl_Idx in Tree_Level_Index_Type loop

         if Lvl_Idx > Snapshot.Max_Level then

            New_PBAs (Lvl_Idx) := Physical_Block_Address_Type'First;

         elsif Lvl_Idx = Snapshot.Max_Level then

            New_PBAs (Lvl_Idx) := Snapshot.PBA;

         else

            Declare_Child_Idx :
            declare
               Child_Idx : constant Type_1_Node_Block_Index_Type :=
                  Child_Idx_For_VBA (VBA, Lvl_Idx + 1, Snapshot_Degree);
            begin

               New_PBAs (Lvl_Idx) := T1_Blks (Lvl_Idx + 1) (Child_Idx).PBA;

            end Declare_Child_Idx;

         end if;

      end loop For_Each_Lvl;

   end Set_New_PBAs_Identical_To_Current_PBAs;

   --
   --  Set_Args_For_Alloc_Of_New_PBAs_For_Resizing
   --
   procedure Set_Args_For_Alloc_Of_New_PBAs_For_Resizing (
      Curr_Gen          :     Generation_Type;
      Snapshot          :     Snapshot_Type;
      Snapshot_Degree   :     Tree_Degree_Type;
      VBA               :     Virtual_Block_Address_Type;
      Min_Lvl_Idx       :     Tree_Level_Index_Type;
      Prim_Idx          :     Primitive.Index_Type;
      T1_Blks           :     Type_1_Node_Blocks_Type;
      T1_Walk           : out Type_1_Node_Walk_Type;
      New_PBAs          : out Tree_Level_PBAs_Type;
      Nr_Of_Blks        : out Number_Of_Blocks_Type;
      Free_Gen          : out Generation_Type;
      Prim              : out Primitive.Object_Type)
   is
   begin

      if Min_Lvl_Idx > Snapshot.Max_Level then
         raise Program_Error;
      end if;

      Nr_Of_Blks := 0;
      Free_Gen := Curr_Gen;

      For_Each_Lvl :
      for Lvl_Idx in Tree_Level_Index_Type loop

         if Lvl_Idx > Snapshot.Max_Level then

            T1_Walk (Lvl_Idx) := Type_1_Node_Invalid;
            New_PBAs (Lvl_Idx) := Physical_Block_Address_Type'First;

         elsif Lvl_Idx = Snapshot.Max_Level then

            Nr_Of_Blks := Nr_Of_Blks + 1;
            New_PBAs (Lvl_Idx) := 0;
            T1_Walk (Lvl_Idx) := (
               PBA => Snapshot.PBA,
               Gen => Snapshot.Gen,
               Hash => Snapshot.Hash);

         else

            Declare_Child_Idx :
            declare
               Child_Idx : constant Type_1_Node_Block_Index_Type :=
                  Child_Idx_For_VBA (VBA, Lvl_Idx + 1, Snapshot_Degree);

               Child : constant Type_1_Node_Type :=
                  T1_Blks (Lvl_Idx + 1) (Child_Idx);
            begin

               if Lvl_Idx >= Min_Lvl_Idx then

                  T1_Walk (Lvl_Idx) := Child;
                  Nr_Of_Blks := Nr_Of_Blks + 1;
                  New_PBAs (Lvl_Idx) := 0;

               else

                  --
                  --  FIXME
                  --
                  --  This is done only because the Free Tree module would
                  --  otherwise get stuck. It is normal that the lowest
                  --  levels have PBA 0 when creating the new branch
                  --  stopped at an inner node because of a depleted PBA
                  --  contingent. As soon as the strange behavior in the Free
                  --  Tree module has been fixed, the whole 'if' statement can
                  --  be removed.
                  --
                  if Child.PBA = 0 then

                     New_PBAs (Lvl_Idx) := PBA_Invalid;
                     T1_Walk (Lvl_Idx) := (
                        PBA => PBA_Invalid,
                        Gen => Child.Gen,
                        Hash => Child.Hash);

                  else

                     New_PBAs (Lvl_Idx) := Child.PBA;
                     T1_Walk (Lvl_Idx) := Child;

                  end if;

               end if;

            end Declare_Child_Idx;

         end if;

      end loop For_Each_Lvl;

      Prim := Primitive.Valid_Object_No_Pool_Idx (
         Op     => Primitive_Operation_Type'First,
         Succ   => False,
         Tg     => Primitive.Tag_VBD_Rkg_FT_Rszg_Alloc_For_Non_Rkg,
         Blk_Nr => Block_Number_Type'First,
         Idx    => Prim_Idx);

   end Set_Args_For_Alloc_Of_New_PBAs_For_Resizing;

   --
   --  Set_Args_For_Alloc_Of_New_PBAs_For_Rekeying
   --
   procedure Set_Args_For_Alloc_Of_New_PBAs_For_Rekeying (
      For_Curr_Gen_Blks :        Boolean;
      Curr_Gen          :        Generation_Type;
      Snapshot          :        Snapshot_Type;
      Snapshot_Degree   :        Tree_Degree_Type;
      VBA               :        Virtual_Block_Address_Type;
      Min_Lvl_Idx       :        Tree_Level_Index_Type;
      Prim_Idx          :        Primitive.Index_Type;
      T1_Blks           :        Type_1_Node_Blocks_Type;
      T1_Walk           :    out Type_1_Node_Walk_Type;
      New_PBAs          : in out Tree_Level_PBAs_Type;
      Nr_Of_Blks        :    out Number_Of_Blocks_Type;
      Free_Gen          :    out Generation_Type;
      Prim              :    out Primitive.Object_Type)
   is
   begin

      if Min_Lvl_Idx > Snapshot.Max_Level then
         raise Program_Error;
      end if;

      Nr_Of_Blks := 0;

      if For_Curr_Gen_Blks then
         Free_Gen := Curr_Gen;
      else
         Free_Gen := Snapshot.Gen + 1;
      end if;

      For_Each_Lvl :
      for Lvl_Idx in Tree_Level_Index_Type loop

         if Lvl_Idx > Snapshot.Max_Level then

            T1_Walk (Lvl_Idx) := Type_1_Node_Invalid;
            New_PBAs (Lvl_Idx) := Physical_Block_Address_Type'First;

         elsif Lvl_Idx = Snapshot.Max_Level then

            Nr_Of_Blks := Nr_Of_Blks + 1;
            New_PBAs (Lvl_Idx) := 0;
            T1_Walk (Lvl_Idx) := (
               PBA => Snapshot.PBA,
               Gen => Snapshot.Gen,
               Hash => Snapshot.Hash);

         elsif Lvl_Idx >= Min_Lvl_Idx then

            Nr_Of_Blks := Nr_Of_Blks + 1;
            New_PBAs (Lvl_Idx) := 0;

            Declare_Child_Idx :
            declare
               Child_Idx : constant Type_1_Node_Block_Index_Type :=
                  Child_Idx_For_VBA (VBA, Lvl_Idx + 1, Snapshot_Degree);
            begin

               T1_Walk (Lvl_Idx) := T1_Blks (Lvl_Idx + 1) (Child_Idx);

            end Declare_Child_Idx;

         else

            Declare_Child_Idx_2 :
            declare
               Child_Idx : constant Type_1_Node_Block_Index_Type :=
                  Child_Idx_For_VBA (VBA, Lvl_Idx + 1, Snapshot_Degree);
            begin

               T1_Walk (Lvl_Idx) := (
                  PBA => New_PBAs (Lvl_Idx),
                  Gen => T1_Blks (Lvl_Idx + 1) (Child_Idx).Gen,
                  Hash => T1_Blks (Lvl_Idx + 1) (Child_Idx).Hash);

            end Declare_Child_Idx_2;

         end if;

      end loop For_Each_Lvl;

      if For_Curr_Gen_Blks then

         Prim := Primitive.Valid_Object_No_Pool_Idx (
            Op     => Primitive_Operation_Type'First,
            Succ   => False,
            Tg     =>
               Primitive.Tag_VBD_Rkg_FT_Rszg_Alloc_For_Rkg_Curr_Gen_Blks,
            Blk_Nr => Block_Number_Type'First,
            Idx    => Prim_Idx);

      else

         Prim := Primitive.Valid_Object_No_Pool_Idx (
            Op     => Primitive_Operation_Type'First,
            Succ   => False,
            Tg     => Primitive.Tag_VBD_Rkg_FT_Rszg_Alloc_For_Rkg_Old_Gen_Blks,
            Blk_Nr => Block_Number_Type'First,
            Idx    => Prim_Idx);

      end if;

   end Set_Args_For_Alloc_Of_New_PBAs_For_Rekeying;

   --
   --  Initialize_New_PBAs_And_Determine_Nr_Of_PBAs_To_Allocate
   --
   procedure Initialize_New_PBAs_And_Determine_Nr_Of_PBAs_To_Allocate (
      Curr_Gen         :     Generation_Type;
      Snapshot         :     Snapshot_Type;
      Snapshot_Degree  :     Tree_Degree_Type;
      VBA              :     Virtual_Block_Address_Type;
      T1_Blks          :     Type_1_Node_Blocks_Type;
      New_PBAs         : out Tree_Level_PBAs_Type;
      Nr_Of_Blks       : out Number_Of_Blocks_Type)
   is
   begin
      Nr_Of_Blks := 0;

      For_Each_Tree_Lvl :
      for Lvl_Idx in New_PBAs'Range loop

         if Lvl_Idx > Snapshot.Max_Level then

            New_PBAs (Lvl_Idx) := Physical_Block_Address_Type'First;

         elsif Lvl_Idx = Snapshot.Max_Level then

            if Snapshot.Gen < Curr_Gen then

               Nr_Of_Blks := Nr_Of_Blks + 1;
               New_PBAs (Lvl_Idx) := 0;

            elsif Snapshot.Gen = Curr_Gen then

               New_PBAs (Lvl_Idx) := Snapshot.PBA;

            else

               New_PBAs (Lvl_Idx) := Physical_Block_Address_Type'First;
               raise Program_Error;

            end if;

         else

            Declare_Child_Idx :
            declare
               Child_Idx : constant Type_1_Node_Block_Index_Type :=
                  Child_Idx_For_VBA (VBA, Lvl_Idx + 1, Snapshot_Degree);

               Child : constant Type_1_Node_Type :=
                  T1_Blks (Lvl_Idx + 1) (Child_Idx);
            begin

               if Child.Gen < Curr_Gen then

                  if Lvl_Idx = 0 and then
                     Child.Gen = Initial_Generation
                  then
                     New_PBAs (Lvl_Idx) := Child.PBA;
                  else
                     Nr_Of_Blks := Nr_Of_Blks + 1;
                     New_PBAs (Lvl_Idx) := 0;
                  end if;

               elsif Child.Gen = Curr_Gen then

                  New_PBAs (Lvl_Idx) := Child.PBA;

               else

                  New_PBAs (Lvl_Idx) := Physical_Block_Address_Type'First;
                  raise Program_Error;

               end if;

            end Declare_Child_Idx;

         end if;

      end loop For_Each_Tree_Lvl;

   end Initialize_New_PBAs_And_Determine_Nr_Of_PBAs_To_Allocate;

   --
   --  Set_Args_For_Alloc_Of_New_PBAs_For_Branch_Of_Written_VBA
   --
   procedure Set_Args_For_Alloc_Of_New_PBAs_For_Branch_Of_Written_VBA (
      Curr_Gen         :     Generation_Type;
      Snapshot         :     Snapshot_Type;
      Snapshot_Degree  :     Tree_Degree_Type;
      VBA              :     Virtual_Block_Address_Type;
      T1_Blks          :     Type_1_Node_Blocks_Type;
      Prim_Idx         :     Primitive.Index_Type;
      Free_Gen         : out Generation_Type;
      T1_Walk          : out Type_1_Node_Walk_Type;
      State            : out Job_State_Type;
      Generated_Prim   : out Primitive.Object_Type;
      Progress         : out Boolean)
   is
   begin

      For_Each_Tree_Lvl :
      for Lvl_Idx in Tree_Level_Index_Type loop

         if Lvl_Idx > Snapshot.Max_Level then

            T1_Walk (Lvl_Idx) := Type_1_Node_Invalid;

         elsif Lvl_Idx = Snapshot.Max_Level then

            T1_Walk (Lvl_Idx) := (
               PBA => Snapshot.PBA,
               Gen => Snapshot.Gen,
               Hash => Snapshot.Hash);

         else

            Declare_Child_Idx :
            declare
               Child_Idx : constant Type_1_Node_Block_Index_Type :=
                  Child_Idx_For_VBA (VBA, Lvl_Idx + 1, Snapshot_Degree);
            begin

               T1_Walk (Lvl_Idx) := T1_Blks (Lvl_Idx + 1) (Child_Idx);

            end Declare_Child_Idx;

         end if;

      end loop For_Each_Tree_Lvl;

      Free_Gen := Curr_Gen;
      Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
         Op     => Primitive_Operation_Type'First,
         Succ   => False,
         Tg     => Primitive.Tag_VBD_Rkg_FT_Rszg_Alloc_For_Non_Rkg,
         Blk_Nr => Block_Number_Type'First,
         Idx    => Prim_Idx);

      State := Alloc_PBAs_At_Leaf_Lvl_Pending;
      Progress := True;

   end Set_Args_For_Alloc_Of_New_PBAs_For_Branch_Of_Written_VBA;

   --
   --  Discard_Disposable_Snapshots
   --
   procedure Discard_Disposable_Snapshots (
      Snapshots        : in out Snapshots_Type;
      Curr_Gen         :        Generation_Type;
      Last_Secured_Gen :        Generation_Type)
   is
   begin

      For_Each_Snap :
      for Idx in Snapshots'Range loop

         if Snapshots (Idx).Valid and then
            not Snapshots (Idx).Keep and then
            Snapshots (Idx).Gen /= Curr_Gen and then
            Snapshots (Idx).Gen /= Last_Secured_Gen
         then
            Snapshots (Idx).Valid := False;
         end if;

      end loop For_Each_Snap;

   end Discard_Disposable_Snapshots;

   --
   --  Tree_Max_Max_VBA
   --
   function Tree_Max_Max_VBA (
      Degree      : Tree_Degree_Type;
      Max_Lvl_Idx : Tree_Level_Index_Type)
   return Virtual_Block_Address_Type
   is (
      (Virtual_Block_Address_Type (Degree) ** Natural (Max_Lvl_Idx)) - 1);

   --
   --  Set_Args_For_Write_Back_Of_T1_Lvl
   --
   procedure Set_Args_For_Write_Back_Of_T1_Lvl (
      Max_Lvl_Idx :     Tree_Level_Index_Type;
      T1_Lvl_Idx  :     Type_1_Node_Blocks_Index_Type;
      PBA         :     Physical_Block_Address_Type;
      Prim_Idx    :     Primitive.Index_Type;
      Job_State   : out Job_State_Type;
      Progress    : out Boolean;
      Prim        : out Primitive.Object_Type)
   is
   begin

      Prim := Primitive.Valid_Object_No_Pool_Idx (
         Op     => Write,
         Succ   => False,
         Tg     => Primitive.Tag_VBD_Rkg_Cache,
         Blk_Nr => Block_Number_Type (PBA),
         Idx    => Prim_Idx);

      pragma Debug (Debug.Print_String (
         "   WRITE LVL " &
         Debug.To_String (Debug.Uint64_Type (T1_Lvl_Idx)) &
         " PBA " &
         Debug.To_String (Debug.Uint64_Type (PBA)) &
         " "));

      if T1_Lvl_Idx < Max_Lvl_Idx then

         Job_State := Write_Inner_Node_Pending;
         Progress := True;

      else

         Job_State := Write_Root_Node_Pending;
         Progress := True;

      end if;

   end Set_Args_For_Write_Back_Of_T1_Lvl;

   --
   --  Execute_VBD_Extension_Step
   --
   procedure Execute_VBD_Extension_Step (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress : in out Boolean)
   is
   begin

      case Job.State is
      when Submitted =>

         Discard_Disposable_Snapshots (
            Job.Snapshots, Job.Curr_Gen, Job.Last_Secured_Gen);

         Job.Nr_Of_Leaves := 0;
         Job.Snapshot_Idx := Newest_Snapshot_Idx (Job.Snapshots);
         Job.VBA :=
            Virtual_Block_Address_Type (
               Job.Snapshots (Job.Snapshot_Idx).Nr_Of_Leafs);

         Job.T1_Blk_Idx :=
            Type_1_Node_Blocks_Index_Type (
               Job.Snapshots (Job.Snapshot_Idx).Max_Level);

         Job.T1_Blks_Old_PBAs (Job.T1_Blk_Idx) :=
            Job.Snapshots (Job.Snapshot_Idx).PBA;

         if Job.VBA <=
               Tree_Max_Max_VBA (
                  Job.Snapshots_Degree,
                  Job.Snapshots (Job.Snapshot_Idx).Max_Level)
         then

            Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
               Op     => Read,
               Succ   => False,
               Tg     => Primitive.Tag_VBD_Rkg_Cache,
               Blk_Nr =>
                  Block_Number_Type (Job.Snapshots (Job.Snapshot_Idx).PBA),
               Idx    => Primitive.Index_Type (Job_Idx));

            pragma Debug (Debug.Print_String (
               "   READ LVL " &
               Debug.To_String (Debug.Uint64_Type (Job.T1_Blk_Idx)) &
               " PARENT SNAP " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshot_Idx)) &
               " PBA " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshots (Job.Snapshot_Idx).PBA)) &
               " GEN " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshots (Job.Snapshot_Idx).Gen)) &
               " LEAVES " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshots (Job.Snapshot_Idx).Nr_Of_Leafs)) &
               " MAX_LVL " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshots (Job.Snapshot_Idx).Max_Level)) &
               " "));

            Job.State := Read_Root_Node_Pending;
            Progress := True;

         else

            Add_New_Root_Lvl_To_Snap_Using_PBA_Contingent (
               Snapshots        => Job.Snapshots,
               Snap_Idx         => Job.Snapshot_Idx,
               Curr_Gen         => Job.Curr_Gen,
               Last_Secured_Gen => Job.Last_Secured_Gen,
               T1_Blks          => Job.T1_Blks,
               First_PBA        => Job.PBA,
               Nr_Of_PBAs       => Job.Nr_Of_PBAs);

            Add_New_Branch_To_Snap_Using_PBA_Contingent (
               Mount_Point_Lvl_Idx   => Job.Snapshots (Job.Snapshot_Idx)
                                           .Max_Level,
               Mount_Point_Child_Idx => 1,
               Snapshots_Degree      => Job.Snapshots_Degree,
               First_PBA             => Job.PBA,
               Nr_Of_PBAs            => Job.Nr_Of_PBAs,
               T1_Blks               => Job.T1_Blks,
               Stopped_At_Lvl_Idx    => Job.T1_Blk_Idx,
               Nr_Of_Leaves          => Job.Nr_Of_Leaves);

            Set_New_PBAs_Identical_To_Current_PBAs (
               Snapshot        => Job.Snapshots (Job.Snapshot_Idx),
               Snapshot_Degree => Job.Snapshots_Degree,
               VBA             => Job.VBA,
               T1_Blks         => Job.T1_Blks,
               New_PBAs        => Job.New_PBAs);

            Set_Args_For_Write_Back_Of_T1_Lvl (
               Max_Lvl_Idx => Job.Snapshots (Job.Snapshot_Idx).Max_Level,
               T1_Lvl_Idx  => Job.T1_Blk_Idx,
               PBA         => Job.New_PBAs (Job.T1_Blk_Idx),
               Prim_Idx    => Primitive.Index_Type (Job_Idx),
               Job_State   => Job.State,
               Progress    => Progress,
               Prim        => Job.Generated_Prim);

         end if;

      when Read_Root_Node_Completed =>

         Execute_VBD_Ext_Step_Read_Inner_Node_Completed (
            Job, Job_Idx, Progress);

      when Read_Inner_Node_Completed =>

         Execute_VBD_Ext_Step_Read_Inner_Node_Completed (
            Job, Job_Idx, Progress);

      when Alloc_PBAs_At_Lowest_Inner_Lvl_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         pragma Debug (Debug.Print_String (
            "   PBAS ALLOCATED" &
            " "));

         pragma Debug (Debug.Print_String (
            "   WRITE LVL " &
            Debug.To_String (Debug.Uint64_Type (Job.T1_Blk_Idx)) &
            " PBA " &
            Debug.To_String (Debug.Uint64_Type (
               Job.New_PBAs (Job.T1_Blk_Idx))) &
            " "));

         Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
            Op     => Write,
            Succ   => False,
            Tg     => Primitive.Tag_VBD_Rkg_Cache,
            Blk_Nr => Block_Number_Type (Job.New_PBAs (Job.T1_Blk_Idx)),
            Idx    => Primitive.Index_Type (Job_Idx));

         if Job.T1_Blk_Idx < Job.Snapshots (Job.Snapshot_Idx).Max_Level then

            Job.State := Write_Inner_Node_Pending;
            Progress := True;

         else

            Job.State := Write_Root_Node_Pending;
            Progress := True;

         end if;

      when Write_Inner_Node_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Declare_Child_Idx_14 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx + 1;

            Child_Lvl_Idx : constant Tree_Level_Index_Type :=
               Job.T1_Blk_Idx;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Child_Lvl_Idx);

            Parent_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Parent_Lvl_Idx);
         begin

            Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).Hash :=
               Hash_Of_T1_Node_Blk (Job.T1_Blks (Child_Lvl_Idx));

            Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).PBA := Child_PBA;

            pragma Debug (Debug.Print_String (
               "   UPDATE LVL " &
               Debug.To_String (Debug.Uint64_Type (
                  Parent_Lvl_Idx)) &
               " CHILD " &
               Debug.To_String (Debug.Uint64_Type (
                  Child_Idx)) &
               " PBA " &
               Debug.To_String (Debug.Uint64_Type (
                  Child_PBA)) &
               " " &
               Debug.To_String (
                  Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).Hash) &
               " "));

            pragma Debug (Debug.Print_String (
               "   WRITE LVL " &
               Debug.To_String (Debug.Uint64_Type (Parent_Lvl_Idx)) &
               " PBA " &
               Debug.To_String (Debug.Uint64_Type (
                  Parent_PBA)) &
               " "));

            Job.T1_Blk_Idx := Job.T1_Blk_Idx + 1;
            Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
               Op     => Write,
               Succ   => False,
               Tg     => Primitive.Tag_VBD_Rkg_Cache,
               Blk_Nr => Block_Number_Type (Parent_PBA),
               Idx    => Primitive.Index_Type (Job_Idx));

            if Job.T1_Blk_Idx < Job.Snapshots (Job.Snapshot_Idx).Max_Level
            then

               Job.State := Write_Inner_Node_Pending;
               Progress := True;

            else

               Job.State := Write_Root_Node_Pending;
               Progress := True;

            end if;

         end Declare_Child_Idx_14;

      when Write_Root_Node_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         --
         --  Update parent
         --
         Declare_Child_Idx_7 :
         declare
            Child_Lvl_Idx : constant Tree_Level_Index_Type :=
               Job.T1_Blk_Idx;

            Child_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Child_Lvl_Idx);

            Old_Snap_Idx : constant Snapshots_Index_Type := Job.Snapshot_Idx;
         begin

            if Job.Snapshots (Job.Snapshot_Idx).Gen < Job.Curr_Gen then
               Job.Snapshot_Idx :=
                  Idx_Of_Invalid_Or_Lowest_Gen_Evictable_Snap (
                     Job.Snapshots, Job.Curr_Gen, Job.Last_Secured_Gen);

               pragma Debug (Debug.Print_String (
                  "   NEW SNAP " &
                  Debug.To_String (Debug.Uint64_Type (
                     Job.Snapshot_Idx))));
            end if;

            Job.Snapshots (Job.Snapshot_Idx) := (
               PBA => Child_PBA,
               Gen => Job.Curr_Gen,
               Hash => Hash_Of_T1_Node_Blk (Job.T1_Blks (Child_Lvl_Idx)),
               Nr_Of_Leafs =>
                  Job.Snapshots (Old_Snap_Idx).Nr_Of_Leafs + Job.Nr_Of_Leaves,
               Max_Level => Job.Snapshots (Old_Snap_Idx).Max_Level,
               Valid => True,
               ID => 0,
               Keep => False);

            pragma Debug (Debug.Print_String (
               "   UPDATE SNAP " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshot_Idx)) &
               " PBA " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshots (Job.Snapshot_Idx).PBA)) &
               " GEN " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshots (Job.Snapshot_Idx).Gen)) &
               " LEAVES " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshots (Job.Snapshot_Idx).Nr_Of_Leafs)) &
               " MAX_LVL " &
               Debug.To_String (Debug.Uint64_Type (
                  Job.Snapshots (Job.Snapshot_Idx).Max_Level)) &
               " " &
               Debug.To_String (
                  Job.Snapshots (Job.Snapshot_Idx).Hash) &
               " "));

         end Declare_Child_Idx_7;

         Primitive.Success (Job.Submitted_Prim, True);
         Job.State := Completed;
         Progress := True;

      when others =>

         null;

      end case;

   end Execute_VBD_Extension_Step;

   --
   --  Snapshot_Contains_VBA
   --
   function Snapshot_Contains_VBA (
      Snapshot : Snapshot_Type;
      VBA      : Virtual_Block_Address_Type)
   return Boolean
   is (
      VBA <= Virtual_Block_Address_Type (Snapshot.Nr_Of_Leafs - 1));

   --
   --  Execute_Read_VBA
   --
   procedure Execute_Read_VBA (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress : in out Boolean)
   is
   begin

      case Job.State is
      when Submitted =>

         Job.Snapshot_Idx := 0;
         Job.VBA :=
            Virtual_Block_Address_Type (
               Primitive.Block_Number (Job.Submitted_Prim));

         Job.T1_Blk_Idx :=
            Type_1_Node_Blocks_Index_Type (
               Job.Snapshots (Job.Snapshot_Idx).Max_Level);

         Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
            Op     => Read,
            Succ   => False,
            Tg     => Primitive.Tag_VBD_Rkg_Cache,
            Blk_Nr => Block_Number_Type (Job.Snapshots (Job.Snapshot_Idx).PBA),
            Idx    => Primitive.Index_Type (Job_Idx));

         Job.State := Read_Root_Node_Pending;
         Progress := True;

      when Read_Root_Node_Completed =>

         Execute_Read_VBA_Read_Inner_Node_Completed (
            Job, Job_Idx, Progress);

      when Read_Inner_Node_Completed =>

         Execute_Read_VBA_Read_Inner_Node_Completed (
            Job, Job_Idx, Progress);

      when Read_Client_Data_From_Leaf_Node_Completed =>

         Primitive.Success (
            Job.Submitted_Prim,
            Primitive.Success (Job.Generated_Prim));

         Job.State := Completed;
         Progress := True;

      when others =>

         null;

      end case;

   end Execute_Read_VBA;

   --
   --  Update_Nodes_Of_Branch_Of_Written_VBA
   --
   procedure Update_Nodes_Of_Branch_Of_Written_VBA (
      Snapshot        : in out Snapshot_Type;
      Snapshot_Degree :        Tree_Degree_Type;
      VBA             :        Virtual_Block_Address_Type;
      New_PBAs        :        Tree_Level_PBAs_Type;
      Leaf_Hash       :        Hash_Type;
      Curr_Gen        :        Generation_Type;
      T1_Blks         : in out Type_1_Node_Blocks_Type)
   is
   begin

      For_Each_Branch_Level :
      for Lvl_Idx in 0 .. Snapshot.Max_Level loop

         if Lvl_Idx = 0 then

            Declare_Leaf_Child :
            declare
               Child_Idx : constant Type_1_Node_Block_Index_Type :=
                  Child_Idx_For_VBA (VBA, Lvl_Idx + 1, Snapshot_Degree);
            begin

               T1_Blks (Lvl_Idx + 1) (Child_Idx).PBA := New_PBAs (Lvl_Idx);
               T1_Blks (Lvl_Idx + 1) (Child_Idx).Gen := Curr_Gen;
               T1_Blks (Lvl_Idx + 1) (Child_Idx).Hash := Leaf_Hash;

            end Declare_Leaf_Child;

         elsif Lvl_Idx < Snapshot.Max_Level then

            Declare_Inner_Child :
            declare
               Child_Idx : constant Type_1_Node_Block_Index_Type :=
                  Child_Idx_For_VBA (VBA, Lvl_Idx + 1, Snapshot_Degree);
            begin

               T1_Blks (Lvl_Idx + 1) (Child_Idx).PBA := New_PBAs (Lvl_Idx);
               T1_Blks (Lvl_Idx + 1) (Child_Idx).Gen := Curr_Gen;
               T1_Blks (Lvl_Idx + 1) (Child_Idx).Hash :=
                  Hash_Of_T1_Node_Blk (T1_Blks (Lvl_Idx));

            end Declare_Inner_Child;

         else

            Snapshot.PBA := New_PBAs (Lvl_Idx);
            Snapshot.Gen := Curr_Gen;
            Snapshot.Hash := Hash_Of_T1_Node_Blk (T1_Blks (Lvl_Idx));

         end if;

      end loop For_Each_Branch_Level;

   end Update_Nodes_Of_Branch_Of_Written_VBA;

   --
   --  Set_Args_In_Order_To_Write_Client_Data_To_Leaf_Node
   --
   procedure Set_Args_In_Order_To_Write_Client_Data_To_Leaf_Node (
      New_PBAs         :     Tree_Level_PBAs_Type;
      Job_Idx          :     Jobs_Index_Type;
      State            : out Job_State_Type;
      Generated_Prim   : out Primitive.Object_Type;
      Progress         : out Boolean)
   is
   begin

      Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
         Op     => Write,
         Succ   => False,
         Tg     => Primitive.Tag_VBD_Rkg_Blk_IO_Write_Client_Data,
         Blk_Nr => Block_Number_Type (New_PBAs (0)),
         Idx    => Primitive.Index_Type (Job_Idx));

      State := Write_Client_Data_To_Leaf_Node_Pending;
      Progress := True;

   end Set_Args_In_Order_To_Write_Client_Data_To_Leaf_Node;

   --
   --  Initialize_Args_Of_Operation_Write_VBA
   --
   procedure Initialize_Args_Of_Operation_Write_VBA (
      Submitted_Prim :     Primitive.Object_Type;
      Snapshots      :     Snapshots_Type;
      Snapshot_Idx   : out Snapshots_Index_Type;
      VBA            : out Virtual_Block_Address_Type;
      T1_Blk_Idx     : out Type_1_Node_Blocks_Index_Type)
   is
   begin
      Snapshot_Idx := 0;
      VBA :=
         Virtual_Block_Address_Type (Primitive.Block_Number (Submitted_Prim));

      T1_Blk_Idx :=
         Type_1_Node_Blocks_Index_Type (Snapshots (Snapshot_Idx).Max_Level);

   end Initialize_Args_Of_Operation_Write_VBA;

   --
   --  Check_That_Primitive_Was_Successful
   --
   procedure Check_That_Primitive_Was_Successful (
      Prim : Primitive.Object_Type)
   is
   begin

      if not Primitive.Success (Prim) then
         raise Program_Error;
      end if;

   end Check_That_Primitive_Was_Successful;

   --
   --  Mark_Job_Successfully_Completed
   --
   procedure Mark_Job_Successfully_Completed (
      State            :    out Job_State_Type;
      Submitted_Prim   : in out Primitive.Object_Type;
      Progress         :    out Boolean)
   is
   begin

      Primitive.Success (Submitted_Prim, True);
      State := Completed;
      Progress := True;

   end Mark_Job_Successfully_Completed;

   --
   --  Execute_Write_VBA
   --
   procedure Execute_Write_VBA (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress : in out Boolean)
   is
   begin

      case Job.State is
      when Submitted =>

         Initialize_Args_Of_Operation_Write_VBA (
            Submitted_Prim => Job.Submitted_Prim,
            Snapshots      => Job.Snapshots,
            Snapshot_Idx   => Job.Snapshot_Idx,
            VBA            => Job.VBA,
            T1_Blk_Idx     => Job.T1_Blk_Idx);

         Set_Args_In_Order_To_Read_Type_1_Node (
            Snapshot         => Job.Snapshots (Job.Snapshot_Idx),
            Snapshots_Degree => Job.Snapshots_Degree,
            T1_Blk_Idx       => Job.T1_Blk_Idx,
            T1_Blks          => Job.T1_Blks,
            VBA              => Job.VBA,
            Job_Idx          => Job_Idx,
            State            => Job.State,
            Generated_Prim   => Job.Generated_Prim,
            Progress         => Progress);

      when Read_Inner_Node_Completed =>

         Check_That_Primitive_Was_Successful (Job.Generated_Prim);

         Check_Hash_Of_Read_Type_1_Node (
            Snapshot         => Job.Snapshots (Job.Snapshot_Idx),
            Snapshots_Degree => Job.Snapshots_Degree,
            T1_Blks          => Job.T1_Blks,
            T1_Blk_Idx       => Job.T1_Blk_Idx,
            VBA              => Job.VBA);

         if Job.T1_Blk_Idx > 1 then

            Job.T1_Blk_Idx := Job.T1_Blk_Idx - 1;
            Set_Args_In_Order_To_Read_Type_1_Node (
               Snapshot         => Job.Snapshots (Job.Snapshot_Idx),
               Snapshots_Degree => Job.Snapshots_Degree,
               T1_Blk_Idx       => Job.T1_Blk_Idx,
               T1_Blks          => Job.T1_Blks,
               VBA              => Job.VBA,
               Job_Idx          => Job_Idx,
               State            => Job.State,
               Generated_Prim   => Job.Generated_Prim,
               Progress         => Progress);

         else

            Initialize_New_PBAs_And_Determine_Nr_Of_PBAs_To_Allocate (
               Curr_Gen        => Job.Curr_Gen,
               Snapshot        => Job.Snapshots (Job.Snapshot_Idx),
               Snapshot_Degree => Job.Snapshots_Degree,
               VBA             => Job.VBA,
               T1_Blks         => Job.T1_Blks,
               New_PBAs        => Job.New_PBAs,
               Nr_Of_Blks      => Job.Nr_Of_Blks);

            if Job.Nr_Of_Blks > 0 then

               Set_Args_For_Alloc_Of_New_PBAs_For_Branch_Of_Written_VBA (
                  Curr_Gen        => Job.Curr_Gen,
                  Snapshot        => Job.Snapshots (Job.Snapshot_Idx),
                  Snapshot_Degree => Job.Snapshots_Degree,
                  VBA             => Job.VBA,
                  T1_Blks         => Job.T1_Blks,
                  Prim_Idx        => Primitive.Index_Type (Job_Idx),
                  Free_Gen        => Job.Free_Gen,
                  T1_Walk         => Job.T1_Node_Walk,
                  State           => Job.State,
                  Generated_Prim  => Job.Generated_Prim,
                  Progress        => Progress);

            else

               Set_Args_In_Order_To_Write_Client_Data_To_Leaf_Node (
                  New_PBAs         => Job.New_PBAs,
                  Job_Idx          => Job_Idx,
                  State            => Job.State,
                  Generated_Prim   => Job.Generated_Prim,
                  Progress         => Progress);

            end if;

         end if;

      when Alloc_PBAs_At_Leaf_Lvl_Completed =>

         Check_That_Primitive_Was_Successful (Job.Generated_Prim);

         Set_Args_In_Order_To_Write_Client_Data_To_Leaf_Node (
            New_PBAs         => Job.New_PBAs,
            Job_Idx          => Job_Idx,
            State            => Job.State,
            Generated_Prim   => Job.Generated_Prim,
            Progress         => Progress);

      when Write_Client_Data_To_Leaf_Node_Completed =>

         Check_That_Primitive_Was_Successful (Job.Generated_Prim);

         Update_Nodes_Of_Branch_Of_Written_VBA (
            Snapshot        => Job.Snapshots (Job.Snapshot_Idx),
            Snapshot_Degree => Job.Snapshots_Degree,
            VBA             => Job.VBA,
            Leaf_Hash       => Job.Hash,
            New_PBAs        => Job.New_PBAs,
            Curr_Gen        => Job.Curr_Gen,
            T1_Blks         => Job.T1_Blks);

         Set_Args_For_Write_Back_Of_T1_Lvl (
            Max_Lvl_Idx => Job.Snapshots (Job.Snapshot_Idx).Max_Level,
            T1_Lvl_Idx  => Job.T1_Blk_Idx,
            PBA         => Job.New_PBAs (Job.T1_Blk_Idx),
            Prim_Idx    => Primitive.Index_Type (Job_Idx),
            Job_State   => Job.State,
            Progress    => Progress,
            Prim        => Job.Generated_Prim);

      when Write_Inner_Node_Completed =>

         Check_That_Primitive_Was_Successful (Job.Generated_Prim);

         Job.T1_Blk_Idx := Job.T1_Blk_Idx + 1;
         Set_Args_For_Write_Back_Of_T1_Lvl (
            Max_Lvl_Idx => Job.Snapshots (Job.Snapshot_Idx).Max_Level,
            T1_Lvl_Idx  => Job.T1_Blk_Idx,
            PBA         => Job.New_PBAs (Job.T1_Blk_Idx),
            Prim_Idx    => Primitive.Index_Type (Job_Idx),
            Job_State   => Job.State,
            Progress    => Progress,
            Prim        => Job.Generated_Prim);

      when Write_Root_Node_Completed =>

         Check_That_Primitive_Was_Successful (Job.Generated_Prim);

         Mark_Job_Successfully_Completed (
            State          => Job.State,
            Submitted_Prim => Job.Submitted_Prim,
            Progress       => Progress);

      when others =>

         null;

      end case;

   end Execute_Write_VBA;

   --
   --  Execute_Rekey_VBA
   --
   procedure Execute_Rekey_VBA (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress : in out Boolean)
   is
   begin

      case Job.State is
      when Submitted =>

         Discard_Disposable_Snapshots (
            Job.Snapshots, Job.Curr_Gen, Job.Last_Secured_Gen);

         Declare_First_Snap_Idx :
         declare
            First_Snap_Idx : Snapshots_Index_Type :=
               Snapshots_Index_Type'First;

            First_Snap_Idx_Found : Boolean := False;
         begin

            Find_First_Snapshot :
            for Snap_Idx in Job.Snapshots'Range loop

               if Job.Snapshots (Snap_Idx).Valid and then
                  (not First_Snap_Idx_Found or else
                   Job.Snapshots (Snap_Idx).Gen >
                      Job.Snapshots (First_Snap_Idx).Gen)
               then
                  First_Snap_Idx := Snap_Idx;
                  First_Snap_Idx_Found := True;
               end if;

            end loop Find_First_Snapshot;

            if First_Snap_Idx_Found then

               Job.Snapshot_Idx := First_Snap_Idx;
               Job.First_Snapshot := True;
               Job.T1_Blk_Idx :=
                  Type_1_Node_Blocks_Index_Type (
                     Job.Snapshots (Job.Snapshot_Idx).Max_Level);

               Job.T1_Blks_Old_PBAs (Job.T1_Blk_Idx) :=
                  Job.Snapshots (Job.Snapshot_Idx).PBA;

               Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
                  Op     => Read,
                  Succ   => False,
                  Tg     => Primitive.Tag_VBD_Rkg_Cache,
                  Blk_Nr => Block_Number_Type (Job.Snapshots (
                               Job.Snapshot_Idx).PBA),
                  Idx    => Primitive.Index_Type (Job_Idx));

               Job.State := Read_Root_Node_Pending;
               Progress := True;

            else

               raise Program_Error;

            end if;

         end Declare_First_Snap_Idx;

      when Read_Root_Node_Completed =>

         Execute_Rekey_VBA_Read_Inner_Node_Completed (
            Job, Job_Idx, Progress);

      when Read_Inner_Node_Completed =>

         Execute_Rekey_VBA_Read_Inner_Node_Completed (
            Job, Job_Idx, Progress);

      when Read_Leaf_Node_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Declare_Child_Idx_2 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Type_1_Node_Blocks_Index_Type'First;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);
         begin

            if Hash_Of_Data_Blk (Job.Data_Blk) /=
                  Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).Hash
            then
               raise Program_Error;
            end if;

         end Declare_Child_Idx_2;

         Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
            Op     => Read,
            Succ   => False,
            Tg     => Primitive.Tag_VBD_Rkg_Crypto_Decrypt,
            Blk_Nr => Block_Number_Type (Job.Data_Blk_Old_PBA),
            Idx    => Primitive.Index_Type (Job_Idx));

         Job.State := Decrypt_Leaf_Node_Pending;
         Progress := True;

      when Decrypt_Leaf_Node_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Set_Args_For_Alloc_Of_New_PBAs_For_Rekeying (
            For_Curr_Gen_Blks => Job.First_Snapshot,
            Curr_Gen          => Job.Curr_Gen,
            Snapshot          => Job.Snapshots (Job.Snapshot_Idx),
            Snapshot_Degree   => Job.Snapshots_Degree,
            VBA               => Job.VBA,
            Min_Lvl_Idx       => 0,
            Prim_Idx          => Primitive.Index_Type (Job_Idx),
            T1_Blks           => Job.T1_Blks,
            T1_Walk           => Job.T1_Node_Walk,
            New_PBAs          => Job.New_PBAs,
            Nr_Of_Blks        => Job.Nr_Of_Blks,
            Free_Gen          => Job.Free_Gen,
            Prim              => Job.Generated_Prim);

         Job.State := Alloc_PBAs_At_Leaf_Lvl_Pending;
         Progress := True;

      when Alloc_PBAs_At_Lowest_Inner_Lvl_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Job.State := Write_Leaf_Node_Completed;
         Progress := True;

      when Alloc_PBAs_At_Leaf_Lvl_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
            Op     => Write,
            Succ   => False,
            Tg     => Primitive.Tag_VBD_Rkg_Crypto_Encrypt,
            Blk_Nr => Block_Number_Type (Job.New_PBAs (0)),
            Idx    => Primitive.Index_Type (Job_Idx));

         Job.State := Encrypt_Leaf_Node_Pending;
         Progress := True;

      when Encrypt_Leaf_Node_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Declare_Child_Idx_3 :
         declare
            Child_Lvl_Idx : constant Tree_Level_Index_Type := 0;
            Child_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Child_Lvl_Idx);
         begin

            Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
               Op     => Write,
               Succ   => False,
               Tg     => Primitive.Tag_VBD_Rkg_Blk_IO,
               Blk_Nr => Block_Number_Type (Child_PBA),
               Idx    => Primitive.Index_Type (Job_Idx));

         end Declare_Child_Idx_3;

         Job.State := Write_Leaf_Node_Pending;
         Progress := True;

      when Write_Leaf_Node_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Declare_Child_Idx_13 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type := 1;
            Child_Lvl_Idx : constant Tree_Level_Index_Type := 0;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Child_Lvl_Idx);

            Parent_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Parent_Lvl_Idx);
         begin

            Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).PBA := Child_PBA;
            Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).Hash :=
               Hash_Of_Data_Blk (Job.Data_Blk);

            Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
               Op     => Write,
               Succ   => False,
               Tg     => Primitive.Tag_VBD_Rkg_Cache,
               Blk_Nr => Block_Number_Type (Parent_PBA),
               Idx    => Primitive.Index_Type (Job_Idx));

            Job.State := Write_Inner_Node_Pending;
            Progress := True;

         end Declare_Child_Idx_13;

      when Write_Inner_Node_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Declare_Child_Idx_14 :
         declare
            Parent_Lvl_Idx : constant Type_1_Node_Blocks_Index_Type :=
               Job.T1_Blk_Idx + 1;

            Child_Lvl_Idx : constant Tree_Level_Index_Type :=
               Job.T1_Blk_Idx;

            Child_Idx : constant Type_1_Node_Block_Index_Type :=
               Child_Idx_For_VBA (
                  Job.VBA, Parent_Lvl_Idx, Job.Snapshots_Degree);

            Child_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Child_Lvl_Idx);

            Parent_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Parent_Lvl_Idx);
         begin

            Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).PBA := Child_PBA;
            Job.T1_Blks (Parent_Lvl_Idx) (Child_Idx).Hash :=
               Hash_Of_T1_Node_Blk (Job.T1_Blks (Child_Lvl_Idx));

            Job.T1_Blk_Idx := Job.T1_Blk_Idx + 1;

            Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
               Op     => Write,
               Succ   => False,
               Tg     => Primitive.Tag_VBD_Rkg_Cache,
               Blk_Nr => Block_Number_Type (Parent_PBA),
               Idx    => Primitive.Index_Type (Job_Idx));

            if Job.T1_Blk_Idx < Job.Snapshots (Job.Snapshot_Idx).Max_Level
            then

               Job.State := Write_Inner_Node_Pending;
               Progress := True;

            else

               Job.State := Write_Root_Node_Pending;
               Progress := True;

            end if;

         end Declare_Child_Idx_14;

      when Write_Root_Node_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         --
         --  Update parent
         --
         Declare_Child_Idx_7 :
         declare
            Child_Lvl_Idx : constant Tree_Level_Index_Type :=
               Job.T1_Blk_Idx;

            Child_PBA : constant Physical_Block_Address_Type :=
               Job.New_PBAs (Child_Lvl_Idx);
         begin

            Job.Snapshots (Job.Snapshot_Idx).PBA := Child_PBA;
            Job.Snapshots (Job.Snapshot_Idx).Hash :=
               Hash_Of_T1_Node_Blk (Job.T1_Blks (Child_Lvl_Idx));

         end Declare_Child_Idx_7;

         Declare_Next_Snap_Idx :
         declare
            Next_Snap_Idx : Snapshots_Index_Type :=
               Snapshots_Index_Type'First;
            Next_Snap_Idx_Valid : Boolean := False;
            Old_Snap_Idx : constant Snapshots_Index_Type := Job.Snapshot_Idx;
         begin

            Find_Next_Snapshot :
            for Snap_Idx in Job.Snapshots'Range loop

               if Job.Snapshots (Snap_Idx).Valid and then
                  Snapshot_Contains_VBA (Job.Snapshots (Snap_Idx), Job.VBA)
               then

                  if Next_Snap_Idx_Valid then

                     if Job.Snapshots (Snap_Idx).Gen >
                           Job.Snapshots (Next_Snap_Idx).Gen and then
                        Job.Snapshots (Snap_Idx).Gen <
                           Job.Snapshots (Old_Snap_Idx).Gen
                     then
                        Next_Snap_Idx := Snap_Idx;
                        Next_Snap_Idx_Valid := True;
                     end if;

                  else

                     if Job.Snapshots (Snap_Idx).Gen <
                           Job.Snapshots (Old_Snap_Idx).Gen
                     then
                        Next_Snap_Idx := Snap_Idx;
                        Next_Snap_Idx_Valid := True;
                     end if;

                  end if;

               end if;

            end loop Find_Next_Snapshot;

            if Next_Snap_Idx_Valid then

               --
               --  Start rekeying VBA in next snapshot
               --

               Job.Snapshot_Idx := Next_Snap_Idx;
               Job.First_Snapshot := False;
               Job.T1_Blk_Idx :=
                  Type_1_Node_Blocks_Index_Type (
                     Job.Snapshots (Job.Snapshot_Idx).Max_Level);

               if not Job.First_Snapshot and then
                  Job.T1_Blks_Old_PBAs (Job.T1_Blk_Idx) =
                     Job.Snapshots (Job.Snapshot_Idx).PBA
               then

                  Progress := True;

               else

                  Job.T1_Blks_Old_PBAs (Job.T1_Blk_Idx) :=
                     Job.Snapshots (Job.Snapshot_Idx).PBA;

                  Job.Generated_Prim := Primitive.Valid_Object_No_Pool_Idx (
                     Op     => Read,
                     Succ   => False,
                     Tg     => Primitive.Tag_VBD_Rkg_Cache,
                     Blk_Nr =>
                        Block_Number_Type (
                           Job.Snapshots (Job.Snapshot_Idx).PBA),
                     Idx    => Primitive.Index_Type (Job_Idx));

                  Job.State := Read_Root_Node_Pending;
                  Progress := True;

               end if;

            else

               Primitive.Success (Job.Submitted_Prim, True);
               Job.State := Completed;
               Progress := True;

            end if;

         end Declare_Next_Snap_Idx;

      when Alloc_PBAs_At_Higher_Inner_Lvl_Completed =>

         if not Primitive.Success (Job.Generated_Prim) then
            raise Program_Error;
         end if;

         Job.State := Write_Inner_Node_Completed;
         Progress := True;

      when others =>

         null;

      end case;

   end Execute_Rekey_VBA;

   --
   --  Execute
   --
   procedure Execute (
      Rkg      : in out Rekeying_Type;
      Progress : in out Boolean)
   is
   begin

      Execute_Each_Valid_Job :
      for Idx in Rkg.Jobs'Range loop

         case Rkg.Jobs (Idx).Operation is
         when Read_VBA =>

            Execute_Read_VBA (Rkg.Jobs (Idx), Idx, Progress);

         when Write_VBA =>

            Execute_Write_VBA (Rkg.Jobs (Idx), Idx, Progress);

         when Rekey_VBA =>

            Execute_Rekey_VBA (Rkg.Jobs (Idx), Idx, Progress);

         when VBD_Extension_Step =>

            Execute_VBD_Extension_Step (Rkg.Jobs (Idx), Idx, Progress);

         when Invalid =>

            null;

         end case;

      end loop Execute_Each_Valid_Job;

   end Execute;

   --
   --  Peek_Generated_Blk_IO_Primitive
   --
   function Peek_Generated_Blk_IO_Primitive (Rkg : Rekeying_Type)
   return Primitive.Object_Type
   is
   begin

      Inspect_Each_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation /= Invalid then

            case Rkg.Jobs (Idx).State is
            when
               Read_Client_Data_From_Leaf_Node_Pending |
               Write_Client_Data_To_Leaf_Node_Pending |
               Read_Leaf_Node_Pending |
               Write_Leaf_Node_Pending
            =>

               return Rkg.Jobs (Idx).Generated_Prim;

            when others =>

               null;

            end case;

         end if;

      end loop Inspect_Each_Job;
      return Primitive.Invalid_Object;

   end Peek_Generated_Blk_IO_Primitive;

   --
   --  Peek_Generated_Cache_Primitive
   --
   function Peek_Generated_Cache_Primitive (Rkg : Rekeying_Type)
   return Primitive.Object_Type
   is
   begin

      Inspect_Each_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation /= Invalid then

            case Rkg.Jobs (Idx).State is
            when
               Read_Root_Node_Pending |
               Read_Inner_Node_Pending |
               Write_Inner_Node_Pending |
               Write_Root_Node_Pending
            =>

               return Rkg.Jobs (Idx).Generated_Prim;

            when others =>

               null;

            end case;

         end if;

      end loop Inspect_Each_Job;
      return Primitive.Invalid_Object;

   end Peek_Generated_Cache_Primitive;

   --
   --  Peek_Generated_FT_Rszg_Primitive
   --
   function Peek_Generated_FT_Rszg_Primitive (Rkg : Rekeying_Type)
   return Primitive.Object_Type
   is
   begin

      Inspect_Each_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation /= Invalid then

            case Rkg.Jobs (Idx).State is
            when
               Alloc_PBAs_At_Leaf_Lvl_Pending |
               Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
               Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
            =>

               return Rkg.Jobs (Idx).Generated_Prim;

            when others =>

               null;

            end case;

         end if;

      end loop Inspect_Each_Job;
      return Primitive.Invalid_Object;

   end Peek_Generated_FT_Rszg_Primitive;

   --
   --  Peek_Generated_Crypto_Primitive
   --
   function Peek_Generated_Crypto_Primitive (Rkg : Rekeying_Type)
   return Primitive.Object_Type
   is
   begin

      Inspect_Each_Job :
      for Idx in Rkg.Jobs'Range loop

         if Rkg.Jobs (Idx).Operation /= Invalid then

            case Rkg.Jobs (Idx).State is
            when Encrypt_Leaf_Node_Pending | Decrypt_Leaf_Node_Pending =>

               return Rkg.Jobs (Idx).Generated_Prim;

            when others =>

               null;

            end case;

         end if;

      end loop Inspect_Each_Job;
      return Primitive.Invalid_Object;

   end Peek_Generated_Crypto_Primitive;

   --
   --  Peek_Generated_Req
   --
   function Peek_Generated_Req (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Request.Object_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Read_Client_Data_From_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Req;

         when Write_Client_Data_To_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Req;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Req;

   --
   --  Peek_Generated_New_PBAs
   --
   function Peek_Generated_New_PBAs (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Tree_Level_PBAs_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).New_PBAs;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_New_PBAs;

   --
   --  Peek_Generated_Snapshots
   --
   function Peek_Generated_Snapshots (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Snapshots_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Snapshots;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Snapshots;

   --
   --  Peek_Generated_Last_Secured_Gen
   --
   function Peek_Generated_Last_Secured_Gen (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Generation_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Last_Secured_Gen;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Last_Secured_Gen;

   --
   --  Peek_Generated_Free_Gen
   --
   function Peek_Generated_Free_Gen (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Generation_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Free_Gen;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Free_Gen;

   --
   --  Peek_Generated_Old_Key_ID
   --
   function Peek_Generated_Old_Key_ID (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Key_ID_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Old_Key_ID;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Old_Key_ID;

   --
   --  Peek_Generated_New_Key_ID
   --
   function Peek_Generated_New_Key_ID (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Key_ID_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).New_Key_ID;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_New_Key_ID;

   --
   --  Peek_Generated_VBA
   --
   function Peek_Generated_VBA (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Virtual_Block_Address_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Read_Client_Data_From_Leaf_Node_Pending |
            Write_Client_Data_To_Leaf_Node_Pending |
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).VBA;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_VBA;

   --
   --  Peek_Generated_Max_Level
   --
   function Peek_Generated_Max_Level (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Tree_Level_Index_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return
               Rkg.Jobs (Idx)
                  .Snapshots (Rkg.Jobs (Idx).Snapshot_Idx).Max_Level;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Max_Level;

   --
   --  Peek_Generated_T1_Node_Walk
   --
   function Peek_Generated_T1_Node_Walk (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Type_1_Node_Walk_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).T1_Node_Walk;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_T1_Node_Walk;

   --
   --  Peek_Generated_Nr_Of_Blks
   --
   function Peek_Generated_Nr_Of_Blks (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Number_Of_Blocks_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Alloc_PBAs_At_Leaf_Lvl_Pending |
            Alloc_PBAs_At_Higher_Inner_Lvl_Pending |
            Alloc_PBAs_At_Lowest_Inner_Lvl_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Nr_Of_Blks;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Nr_Of_Blks;

   --
   --  Peek_Generated_Blk_Data
   --
   function Peek_Generated_Blk_Data (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Block_Data_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin
      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when
            Write_Inner_Node_Pending |
            Write_Root_Node_Pending
         =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Declare_Blk_Data :
            declare
               Blk_Data : Block_Data_Type;
            begin

               Block_Data_From_Type_1_Node_Block (
                  Blk_Data,
                  Rkg.Jobs (Idx).T1_Blks (Rkg.Jobs (Idx).T1_Blk_Idx));

               return Blk_Data;

            end Declare_Blk_Data;

         when Write_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Data_Blk;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Blk_Data;

   --
   --  Peek_Generated_Cipher_Data
   --
   function Peek_Generated_Cipher_Data (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Block_Data_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Decrypt_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Data_Blk;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Cipher_Data;

   --
   --  Peek_Generated_Plain_Data
   --
   function Peek_Generated_Plain_Data (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Block_Data_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Encrypt_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Data_Blk;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Plain_Data;

   --
   --  Peek_Generated_Crypto_Key_ID
   --
   function Peek_Generated_Crypto_Key_ID (
      Rkg  : Rekeying_Type;
      Prim : Primitive.Object_Type)
   return Key_ID_Type
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Encrypt_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).New_Key_ID;

         when Decrypt_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).Old_Key_ID;

         when Read_Client_Data_From_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).New_Key_ID;

         when Write_Client_Data_To_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim)
            then
               raise Program_Error;
            end if;

            return Rkg.Jobs (Idx).New_Key_ID;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Peek_Generated_Crypto_Key_ID;

   --
   --  Drop_Generated_Primitive
   --
   procedure Drop_Generated_Primitive (
      Rkg  : in out Rekeying_Type;
      Prim :        Primitive.Object_Type)
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin
      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Read_Root_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Read_Root_Node_In_Progress;
            return;

         when Read_Inner_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Read_Inner_Node_In_Progress;
            return;

         when Read_Client_Data_From_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State :=
               Read_Client_Data_From_Leaf_Node_In_Progress;
            return;

         when Write_Client_Data_To_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Write_Client_Data_To_Leaf_Node_In_Progress;
            return;

         when Read_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Read_Leaf_Node_In_Progress;
            return;

         when Write_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Write_Leaf_Node_In_Progress;
            return;

         when Write_Inner_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Write_Inner_Node_In_Progress;
            return;

         when Write_Root_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Write_Root_Node_In_Progress;
            return;

         when Decrypt_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Decrypt_Leaf_Node_In_Progress;
            return;

         when Alloc_PBAs_At_Leaf_Lvl_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Alloc_PBAs_At_Leaf_Lvl_In_Progress;
            return;

         when Alloc_PBAs_At_Higher_Inner_Lvl_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Alloc_PBAs_At_Higher_Inner_Lvl_In_Progress;
            return;

         when Alloc_PBAs_At_Lowest_Inner_Lvl_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State :=
               Alloc_PBAs_At_Lowest_Inner_Lvl_In_Progress;

            return;

         when Encrypt_Leaf_Node_Pending =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Encrypt_Leaf_Node_In_Progress;
            return;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Drop_Generated_Primitive;

   --
   --  Mark_Generated_Prim_Completed_Plain_Data
   --
   procedure Mark_Generated_Prim_Completed_Plain_Data (
      Rkg        : in out Rekeying_Type;
      Prim       :        Primitive.Object_Type;
      Plain_Data :        Block_Data_Type)
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Decrypt_Leaf_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Decrypt_Leaf_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Rkg.Jobs (Idx).Data_Blk := Plain_Data;
            return;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Mark_Generated_Prim_Completed_Plain_Data;

   --
   --  Mark_Generated_Prim_Completed_Hash
   --
   procedure Mark_Generated_Prim_Completed_Hash (
      Rkg  : in out Rekeying_Type;
      Prim :        Primitive.Object_Type;
      Hash :        Hash_Type)
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Write_Client_Data_To_Leaf_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Write_Client_Data_To_Leaf_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Rkg.Jobs (Idx).Hash := Hash;
            return;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Mark_Generated_Prim_Completed_Hash;

   --
   --  Mark_Generated_Prim_Completed_Cipher_Data
   --
   procedure Mark_Generated_Prim_Completed_Cipher_Data (
      Rkg         : in out Rekeying_Type;
      Prim        :        Primitive.Object_Type;
      Cipher_Data :        Block_Data_Type)
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Encrypt_Leaf_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Encrypt_Leaf_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Rkg.Jobs (Idx).Data_Blk := Cipher_Data;
            return;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Mark_Generated_Prim_Completed_Cipher_Data;

   --
   --  Mark_Generated_Prim_Completed_Blk_Data
   --
   procedure Mark_Generated_Prim_Completed_Blk_Data (
      Rkg      : in out Rekeying_Type;
      Prim     :        Primitive.Object_Type;
      Blk_Data :        Block_Data_Type)
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin

      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Read_Root_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Read_Root_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Type_1_Node_Block_From_Block_Data (
               Rkg.Jobs (Idx).T1_Blks (Rkg.Jobs (Idx).T1_Blk_Idx), Blk_Data);

            return;

         when Read_Inner_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Read_Inner_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Type_1_Node_Block_From_Block_Data (
               Rkg.Jobs (Idx).T1_Blks (Rkg.Jobs (Idx).T1_Blk_Idx), Blk_Data);

            return;

         when Read_Leaf_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Read_Leaf_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Rkg.Jobs (Idx).Data_Blk := Blk_Data;
            return;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Mark_Generated_Prim_Completed_Blk_Data;

   --
   --  Mark_Generated_Prim_Completed
   --
   procedure Mark_Generated_Prim_Completed (
      Rkg  : in out Rekeying_Type;
      Prim :        Primitive.Object_Type)
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin
      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Write_Leaf_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Write_Leaf_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            return;

         when Write_Inner_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Write_Inner_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            return;

         when Write_Root_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Write_Root_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            return;

         when Read_Client_Data_From_Leaf_Node_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Read_Client_Data_From_Leaf_Node_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            return;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Mark_Generated_Prim_Completed;

   --
   --  Mark_Generated_Prim_Completed
   --
   procedure Mark_Generated_Prim_Completed_New_PBAs (
      Rkg      : in out Rekeying_Type;
      Prim     :        Primitive.Object_Type;
      New_PBAs :        Tree_Level_PBAs_Type)
   is
      Idx : constant Jobs_Index_Type :=
         Jobs_Index_Type (Primitive.Index (Prim));
   begin
      if Rkg.Jobs (Idx).Operation /= Invalid then

         case Rkg.Jobs (Idx).State is
         when Alloc_PBAs_At_Leaf_Lvl_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Alloc_PBAs_At_Leaf_Lvl_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Rkg.Jobs (Idx).New_PBAs := New_PBAs;
            return;

         when Alloc_PBAs_At_Higher_Inner_Lvl_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Alloc_PBAs_At_Higher_Inner_Lvl_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Rkg.Jobs (Idx).New_PBAs := New_PBAs;
            return;

         when Alloc_PBAs_At_Lowest_Inner_Lvl_In_Progress =>

            if not Primitive.Equal (Prim, Rkg.Jobs (Idx).Generated_Prim) then
               raise Program_Error;
            end if;

            Rkg.Jobs (Idx).State := Alloc_PBAs_At_Lowest_Inner_Lvl_Completed;
            Rkg.Jobs (Idx).Generated_Prim := Prim;
            Rkg.Jobs (Idx).New_PBAs := New_PBAs;
            return;

         when others =>

            raise Program_Error;

         end case;

      end if;
      raise Program_Error;

   end Mark_Generated_Prim_Completed_New_PBAs;

end CBE.VBD_Rekeying;
