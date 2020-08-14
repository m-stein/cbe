--
--  Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
--  This file is part of the Consistent Block Encrypter project, which is
--  distributed under the terms of the GNU Affero General Public License
--  version 3.
--

pragma Ada_2012;

with CBE.Primitive;

package CBE.FT_Resizing
with SPARK_Mode
is
   pragma Pure;

   type Resizing_Type is private;

   --
   --  Initialize_Resizing
   --
   procedure Initialize_Resizing (Rszg : out Resizing_Type);

   --
   --  Primitive_Acceptable
   --
   function Primitive_Acceptable (Rszg : Resizing_Type)
   return Boolean;

   --
   --  Submit_Primitive
   --
   procedure Submit_Primitive (
      Rszg             : in out Resizing_Type;
      Prim             :        Primitive.Object_Type;
      Curr_Gen         :        Generation_Type;
      FT_Root          :        Type_1_Node_Type;
      FT_Max_Lvl_Idx   :        Tree_Level_Index_Type;
      FT_Nr_Of_Leaves  :        Tree_Number_Of_Leafs_Type;
      FT_Degree        :        Tree_Degree_Type;
      First_PBA        :        Physical_Block_Address_Type;
      Nr_Of_PBAs       :        Number_Of_Blocks_Type);

   --
   --  Submit_Primitive_Alloc
   --
   procedure Submit_Primitive_Alloc_PBAs (
      Rszg                : in out Resizing_Type;
      Prim                :        Primitive.Object_Type;
      Curr_Gen            :        Generation_Type;
      Free_Gen            :        Generation_Type;
      FT_Root             :        Type_1_Node_Type;
      FT_Max_Lvl_Idx      :        Tree_Level_Index_Type;
      FT_Nr_Of_Leaves     :        Tree_Number_Of_Leafs_Type;
      FT_Degree           :        Tree_Degree_Type;
      VBD_Max_Lvl_Idx     :        Tree_Level_Index_Type;
      VBD_Degree          :        Tree_Degree_Type;
      VBD_Highest_VBA     :        Virtual_Block_Address_Type;
      Nr_Of_Required_Blks :        Number_Of_Blocks_Type;
      New_PBAs            :        Tree_Walk_PBAs_Type;
      Old_T1_Nodes        :        Type_1_Node_Walk_Type;
      Rekeying            :        Boolean;
      Previous_Key_ID     :        Key_ID_Type;
      Current_Key_ID      :        Key_ID_Type;
      Rekeying_VBA        :        Virtual_Block_Address_Type);

   --
   --  Peek_Completed_Primitive
   --
   function Peek_Completed_Primitive (Rszg : Resizing_Type)
   return Primitive.Object_Type;

   --
   --  Peek_Completed_FT_Root
   --
   function Peek_Completed_FT_Root (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Type_1_Node_Type;

   --
   --  Peek_Completed_FT_Max_Lvl_Idx
   --
   function Peek_Completed_FT_Max_Lvl_Idx (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Tree_Level_Index_Type;

   --
   --  Peek_Completed_FT_Nr_Of_Leaves
   --
   function Peek_Completed_FT_Nr_Of_Leaves (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Tree_Number_Of_Leafs_Type;

   --
   --  Peek_Completed_Nr_Of_Leaves
   --
   function Peek_Completed_Nr_Of_Leaves (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Tree_Number_Of_Leafs_Type;

   --
   --  Peek_Completed_PBA
   --
   function Peek_Completed_PBA (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Physical_Block_Address_Type;

   --
   --  Peek_Completed_Nr_Of_PBAs
   --
   function Peek_Completed_Nr_Of_PBAs (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Number_Of_Blocks_Type;

   --
   --  Drop_Completed_Primitive
   --
   procedure Drop_Completed_Primitive (
      Rszg : in out Resizing_Type;
      Prim :        Primitive.Object_Type);

   --
   --  Execute
   --
   procedure Execute (
      Rszg     : in out Resizing_Type;
      Progress : in out Boolean);

   --
   --  Peek_Generated_Cache_Primitive
   --
   function Peek_Generated_Cache_Primitive (Rszg : Resizing_Type)
   return Primitive.Object_Type;

   --
   --  Peek_Generated_MT_Primitive
   --
   function Peek_Generated_MT_Primitive (Rszg : Resizing_Type)
   return Primitive.Object_Type;

   --
   --  Peek_Generated_MT_Rszg_Primitive
   --
   function Peek_Generated_MT_Rszg_Primitive (Rszg : Resizing_Type)
   return Primitive.Object_Type;

   --
   --  Peek_Generated_PBA
   --
   function Peek_Generated_PBA (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Physical_Block_Address_Type;

   --
   --  Peek_Generated_Nr_Of_PBAs
   --
   function Peek_Generated_Nr_Of_PBAs (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Number_Of_Blocks_Type;

   --
   --  Peek_Generated_Curr_Gen
   --
   function Peek_Generated_Curr_Gen (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Generation_Type;

   --
   --  Peek_Generated_Old_PBA
   --
   function Peek_Generated_Old_PBA (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Physical_Block_Address_Type;

   --
   --  Peek_Generated_Blk_Data
   --
   function Peek_Generated_Blk_Data (
      Rszg : Resizing_Type;
      Prim : Primitive.Object_Type)
   return Block_Data_Type;

   --
   --  Drop_Generated_Primitive
   --
   procedure Drop_Generated_Primitive (
      Rszg : in out Resizing_Type;
      Prim :        Primitive.Object_Type);

   --
   --  Mark_Generated_Prim_Completed_Blk_Data
   --
   procedure Mark_Generated_Prim_Completed_Blk_Data (
      Rszg     : in out Resizing_Type;
      Prim     :        Primitive.Object_Type;
      Blk_Data :        Block_Data_Type);

   --
   --  Mark_Generated_Prim_Completed
   --
   procedure Mark_Generated_Prim_Completed (
      Rszg : in out Resizing_Type;
      Prim :        Primitive.Object_Type);

   --
   --  Mark_Generated_Prim_Completed_New_PBA
   --
   procedure Mark_Generated_Prim_Completed_New_PBA (
      Rszg    : in out Resizing_Type;
      Prim    :        Primitive.Object_Type;
      New_PBA :        Physical_Block_Address_Type);

   --
   --  Mark_Generated_Prim_Completed_MT_Ext
   --
   procedure Mark_Generated_Prim_Completed_MT_Ext (
      Rszg         : in out Resizing_Type;
      Prim         :        Primitive.Object_Type;
      First_PBA    :        Physical_Block_Address_Type;
      Nr_Of_PBAs   :        Number_Of_Blocks_Type;
      Nr_Of_Leaves :        Tree_Number_Of_Leafs_Type);

private

   Nr_Of_Jobs : constant := 1;

   type Job_Operation_Type is (
      Invalid,
      FT_Extension_Step,
      Allocate_PBAs
   );

   type Job_State_Type is (
      Submitted,

      Read_Root_Node_Pending,
      Read_Root_Node_In_Progress,
      Read_Root_Node_Completed,

      Read_Inner_Node_Pending,
      Read_Inner_Node_In_Progress,
      Read_Inner_Node_Completed,

      Alloc_PBA_Pending,
      Alloc_PBA_In_Progress,
      Alloc_PBA_Completed,

      Extend_MT_By_One_Leaf_Pending,
      Extend_MT_By_One_Leaf_In_Progress,
      Extend_MT_By_One_Leaf_Completed,

      Write_Inner_Node_Pending,
      Write_Inner_Node_In_Progress,
      Write_Inner_Node_Completed,

      Write_Root_Node_Pending,
      Write_Root_Node_In_Progress,
      Write_Root_Node_Completed,

      Completed
   );

   subtype Type_1_Node_Blocks_Index_Type is
      Tree_Level_Index_Type range 2 .. Tree_Level_Index_Type'Last;

   type Type_1_Node_Blocks_Type
   is array (Type_1_Node_Blocks_Index_Type) of Type_1_Node_Block_Type;

   type Tree_Level_PBAs_Type
   is array (Tree_Level_Index_Type) of Physical_Block_Address_Type;

   type Tree_Level_Generations_Type
   is array (Tree_Level_Index_Type) of Generation_Type;

   type Job_Type is record
      Operation           : Job_Operation_Type;
      State               : Job_State_Type;
      Submitted_Prim      : Primitive.Object_Type;
      Generated_Prim      : Primitive.Object_Type;
      FT_Root             : Type_1_Node_Type;
      FT_Max_Lvl_Idx      : Tree_Level_Index_Type;
      FT_Nr_Of_Leaves     : Tree_Number_Of_Leafs_Type;
      FT_Degree           : Tree_Degree_Type;
      T1_Blks             : Type_1_Node_Blocks_Type;
      T2_Blk              : Type_2_Node_Block_Type;
      Lvl_Idx             : Tree_Level_Index_Type;
      Alloc_Lvl_Idx       : Tree_Level_Index_Type;
      VBA                 : Virtual_Block_Address_Type;
      Old_PBAs            : Tree_Level_PBAs_Type;
      Old_Generations     : Tree_Level_Generations_Type;
      New_PBAs            : Tree_Level_PBAs_Type;
      PBA                 : Physical_Block_Address_Type;
      Nr_Of_PBAs          : Number_Of_Blocks_Type;
      Nr_Of_Leaves        : Tree_Number_Of_Leafs_Type;
      MT_Nr_Of_Leaves     : Tree_Number_Of_Leafs_Type;
      Curr_Gen            : Generation_Type;
      Free_Gen            : Generation_Type;
      VBD_Max_Lvl_Idx     : Tree_Level_Index_Type;
      VBD_Degree          : Tree_Degree_Type;
      VBD_Highest_VBA     : Virtual_Block_Address_Type;
      VBD_New_PBAs        : Tree_Walk_PBAs_Type;
      VBD_Old_T1_Nodes    : Type_1_Node_Walk_Type;
      Rekeying            : Boolean;
      Previous_Key_ID     : Key_ID_Type;
      Current_Key_ID      : Key_ID_Type;
   end record;

   type Jobs_Index_Type is range 0 .. Nr_Of_Jobs - 1;

   type Jobs_Type is array (Jobs_Index_Type) of Job_Type;

   type Resizing_Type is record
      Jobs : Jobs_Type;
      VBA  : Virtual_Block_Address_Type;
   end record;

   --
   --  Execute_FT_Extension_Step
   --
   procedure Execute_FT_Extension_Step (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress : in out Boolean);

   --
   --  T1_Child_Idx_For_VBA
   --
   function T1_Child_Idx_For_VBA (
      VBA  : Virtual_Block_Address_Type;
      Lvl  : Type_1_Node_Blocks_Index_Type;
      Degr : Tree_Degree_Type)
   return Type_1_Node_Block_Index_Type;

   --
   --  T2_Child_Idx_For_VBA
   --
   function T2_Child_Idx_For_VBA (
      VBA  : Virtual_Block_Address_Type;
      Degr : Tree_Degree_Type)
   return Type_2_Node_Block_Index_Type;

   --
   --  Alloc_PBA_From_Resizing_Contingent
   --
   procedure Alloc_PBA_From_Resizing_Contingent (
      First_PBA     : in out Physical_Block_Address_Type;
      Nr_Of_PBAs    : in out Number_Of_Blocks_Type;
      Allocated_PBA :    out Physical_Block_Address_Type);

   --
   --  Add_New_Root_Lvl_To_FT_Using_PBA_Contingent
   --
   procedure Add_New_Root_Lvl_To_FT_Using_PBA_Contingent (
      FT_Root          : in out Type_1_Node_Type;
      FT_Max_Lvl_Idx   : in out Tree_Level_Index_Type;
      FT_Nr_Of_Leaves  :        Tree_Number_Of_Leafs_Type;
      Curr_Gen         :        Generation_Type;
      T1_Blks          : in out Type_1_Node_Blocks_Type;
      New_PBAs         : in out Tree_Level_PBAs_Type;
      First_PBA        : in out Physical_Block_Address_Type;
      Nr_Of_PBAs       : in out Number_Of_Blocks_Type);

   --
   --  Add_New_Branch_To_FT_Using_PBA_Contingent
   --
   procedure Add_New_Branch_To_FT_Using_PBA_Contingent (
      Mount_Point_Lvl_Idx   :        Tree_Level_Index_Type;
      Mount_Point_Child_Idx :        Tree_Child_Index_Type;
      FT_Degree             :        Tree_Degree_Type;
      Curr_Gen              :        Generation_Type;
      First_PBA             : in out Physical_Block_Address_Type;
      Nr_Of_PBAs            : in out Number_Of_Blocks_Type;
      T1_Blks               : in out Type_1_Node_Blocks_Type;
      T2_Blk                : in out Type_2_Node_Block_Type;
      New_PBAs              : in out Tree_Level_PBAs_Type;
      Stopped_At_Lvl_Idx    :    out Tree_Level_Index_Type;
      Nr_Of_Leaves          :    out Tree_Number_Of_Leafs_Type);

   --
   --  Execute_FT_Ext_Step_Read_Inner_Node_Completed
   --
   procedure Execute_FT_Ext_Step_Read_Inner_Node_Completed (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      Progress :    out Boolean);

   --
   --  Execute_Allocate_PBAs
   --
   procedure Execute_Allocate_PBAs (
      Job      : in out Job_Type;
      Job_Idx  :        Jobs_Index_Type;
      VBA      :        Virtual_Block_Address_Type;
      Progress : in out Boolean);

   --
   --  Check_That_Primitive_Was_Successful
   --
   procedure Check_That_Primitive_Was_Successful (
      Prim : Primitive.Object_Type);

   --
   --  Tree_Max_Max_VBA
   --
   function Tree_Max_Max_VBA (
      Degree      : Tree_Degree_Type;
      Max_Lvl_Idx : Tree_Level_Index_Type)
   return Virtual_Block_Address_Type;

   --
   --  Set_Args_For_Write_Back_Of_Inner_Lvl
   --
   procedure Set_Args_For_Write_Back_Of_Inner_Lvl (
      Max_Lvl_Idx :     Tree_Level_Index_Type;
      Lvl_Idx     :     Tree_Level_Index_Type;
      PBA         :     Physical_Block_Address_Type;
      Prim_Idx    :     Primitive.Index_Type;
      Job_State   : out Job_State_Type;
      Progress    : out Boolean;
      Prim        : out Primitive.Object_Type);

   --
   --  Initialize_Args_Of_Operation_Allocate_PBAs
   --
   procedure Initialize_Args_Of_Operation_Allocate_PBAs (
      FT_Max_Lvl_Idx  :     Tree_Level_Index_Type;
      Old_PBAs        : out Tree_Level_PBAs_Type;
      Old_Generations : out Tree_Level_Generations_Type;
      New_PBAs        : out Tree_Level_PBAs_Type;
      Lvl_Idx         : out Tree_Level_Index_Type);

   --
   --  Set_Args_In_Order_To_Read_Inner_Node
   --
   procedure Set_Args_In_Order_To_Read_Inner_Node (
      FT_Root         :        Type_1_Node_Type;
      FT_Max_Lvl_Idx  :        Tree_Level_Index_Type;
      FT_Degree       :        Tree_Degree_Type;
      T1_Blks         :        Type_1_Node_Blocks_Type;
      Lvl_Idx         :        Tree_Level_Index_Type;
      VBA             :        Virtual_Block_Address_Type;
      Job_Idx         :        Jobs_Index_Type;
      Old_PBAs        : in out Tree_Level_PBAs_Type;
      Old_Generations : in out Tree_Level_Generations_Type;
      State           :    out Job_State_Type;
      Generated_Prim  :    out Primitive.Object_Type;
      Progress        :    out Boolean);

   --
   --  Check_Hash_Of_Read_Node
   --
   procedure Check_Hash_Of_Read_Node (
      FT_Root        : Type_1_Node_Type;
      FT_Max_Lvl_Idx : Tree_Level_Index_Type;
      FT_Degree      : Tree_Degree_Type;
      T1_Blks        : Type_1_Node_Blocks_Type;
      T2_Blk         : Type_2_Node_Block_Type;
      Lvl_Idx        : Tree_Level_Index_Type;
      VBA            : Virtual_Block_Address_Type);

end CBE.FT_Resizing;
