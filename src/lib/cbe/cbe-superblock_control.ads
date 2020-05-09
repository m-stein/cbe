--
--  Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
--  This file is part of the Consistent Block Encrypter project, which is
--  distributed under the terms of the GNU Affero General Public License
--  version 3.
--

pragma Ada_2012;

with CBE.Primitive;

package CBE.Superblock_Control
with SPARK_Mode
is
   pragma Pure;

   Nr_Of_Jobs : constant := 2;

   type Control_Type is private;

   type Jobs_Index_Type is range 0 .. Nr_Of_Jobs - 1;

   --
   --  Initialize_Control
   --
   procedure Initialize_Control (Ctrl : out Control_Type);

   --
   --  Primitive_Acceptable
   --
   function Primitive_Acceptable (Ctrl : Control_Type)
   return Boolean;

   --
   --  Submit_Primitive
   --
   procedure Submit_Primitive (
      Ctrl : in out Control_Type;
      Prim :        Primitive.Object_Type);

   --
   --  Peek_Completed_Primitive
   --
   function Peek_Completed_Primitive (Ctrl : Control_Type)
   return Primitive.Object_Type;

   --
   --  Drop_Completed_Primitive
   --
   procedure Drop_Completed_Primitive (
      Ctrl : in out Control_Type;
      Prim :        Primitive.Object_Type);

   --
   --  Execute
   --
   procedure Execute (
      Ctrl          : in out Control_Type;
      SB            : in out Superblock_Type;
      SB_Idx        : in out Superblocks_Index_Type;
      Curr_Gen      : in out Generation_Type;
      Progress      : in out Boolean);

   --
   --  Peek_Generated_VBD_Rkg_Primitive
   --
   function Peek_Generated_VBD_Rkg_Primitive (Ctrl : Control_Type)
   return Primitive.Object_Type;

   --
   --  Peek_Generated_TA_Primitive
   --
   function Peek_Generated_TA_Primitive (Ctrl : Control_Type)
   return Primitive.Object_Type;

   --
   --  Peek_Generated_Hash
   --
   function Peek_Generated_Hash (
      Ctrl : Control_Type;
      Prim : Primitive.Object_Type)
   return Hash_Type;

   --
   --  Peek_Generated_Plain_Key
   --
   function Peek_Generated_Key_Plaintext (
      Ctrl : Control_Type;
      Prim : Primitive.Object_Type)
   return Key_Plaintext_Type;

   --
   --  Peek_Generated_Cache_Primitive
   --
   function Peek_Generated_Cache_Primitive (Ctrl : Control_Type)
   return Primitive.Object_Type;

   --
   --  Peek_Generated_Blk_IO_Primitive
   --
   function Peek_Generated_Blk_IO_Primitive (Ctrl : Control_Type)
   return Primitive.Object_Type;

   --
   --  Peek_Generated_VBA
   --
   function Peek_Generated_VBA (
      Ctrl : Control_Type;
      Prim : Primitive.Object_Type;
      SB   : Superblock_Type)
   return Virtual_Block_Address_Type;

   --
   --  Peek_Generated_Last_Secured_Gen
   --
   function Peek_Generated_Last_Secured_Gen (
      Ctrl : Control_Type;
      Prim : Primitive.Object_Type;
      SB   : Superblock_Type)
   return Generation_Type;

   --
   --  Peek_Generated_Snapshots
   --
   function Peek_Generated_Snapshots (
      Ctrl : Control_Type;
      Prim : Primitive.Object_Type;
      SB   : Superblock_Type)
   return Snapshots_Type;

   --
   --  Peek_Generated_Snapshots_Degree
   --
   function Peek_Generated_Snapshots_Degree (
      Ctrl : Control_Type;
      Prim : Primitive.Object_Type;
      SB   : Superblock_Type)
   return Tree_Degree_Type;

   --
   --  Peek_Generated_Old_Key_ID
   --
   function Peek_Generated_Old_Key_ID (
      Ctrl : Control_Type;
      Prim : Primitive.Object_Type;
      SB   : Superblock_Type)
   return Key_ID_Type;

   --
   --  Peek_Generated_New_Key_ID
   --
   function Peek_Generated_New_Key_ID (
      Ctrl : Control_Type;
      Prim : Primitive.Object_Type;
      SB   : Superblock_Type)
   return Key_ID_Type;

   --
   --  Drop_Generated_Primitive
   --
   procedure Drop_Generated_Primitive (
      Ctrl : in out Control_Type;
      Prim :        Primitive.Object_Type);

   --
   --  Mark_Generated_Prim_Complete_Key_Plaintext
   --
   procedure Mark_Generated_Prim_Complete_Key_Plaintext (
      Ctrl : in out Control_Type;
      Prim :        Primitive.Object_Type;
      Key  :        Key_Plaintext_Type);

   --
   --  Mark_Generated_Prim_Complete_Key_Ciphertext
   --
   procedure Mark_Generated_Prim_Complete_Key_Ciphertext (
      Ctrl : in out Control_Type;
      Prim :        Primitive.Object_Type;
      Key  :        Key_Ciphertext_Type);

   --
   --  Mark_Generated_Prim_Complete_Snapshots
   --
   procedure Mark_Generated_Prim_Complete_Snapshots (
      Ctrl      : in out Control_Type;
      Prim      :        Primitive.Object_Type;
      Snapshots :        Snapshots_Type);

   --
   --  Mark_Generated_Prim_Complete
   --
   procedure Mark_Generated_Prim_Complete (
      Ctrl : in out Control_Type;
      Prim :        Primitive.Object_Type);

private

   type Job_Operation_Type is (
      Invalid,
      Initialize_Rekeying,
      Rekey_VBA);

   type Job_State_Type is (
      Submitted,
      Rekey_VBA_In_VBD_Pending,
      Rekey_VBA_In_VBD_In_Progress,
      Rekey_VBA_In_VBD_Completed,
      Create_Key_Pending,
      Create_Key_In_Progress,
      Create_Key_Completed,
      Encrypt_Key_Pending,
      Encrypt_Key_In_Progress,
      Encrypt_Key_Completed,
      Sync_Cache_Pending,
      Sync_Cache_In_Progress,
      Sync_Cache_Completed,
      Write_SB_Pending,
      Write_SB_In_Progress,
      Write_SB_Completed,
      Sync_Blk_IO_Pending,
      Sync_Blk_IO_In_Progress,
      Sync_Blk_IO_Completed,
      Secure_SB_Pending,
      Secure_SB_In_Progress,
      Secure_SB_Completed,
      Completed);

   type Job_Type is record
      Operation : Job_Operation_Type;
      State : Job_State_Type;
      Submitted_Prim : Primitive.Object_Type;
      Generated_Prim : Primitive.Object_Type;
      Key_Plaintext : Key_Plaintext_Type;
      Key_Ciphertext : Key_Ciphertext_Type;
      Generation : Generation_Type;
      Hash : Hash_Type;
      Snapshots : Snapshots_Type;
   end record;

   type Jobs_Type is array (Jobs_Index_Type) of Job_Type;

   type Control_Type is record
      Jobs : Jobs_Type;
   end record;

   --
   --  Execute_Initialize_Rekeying
   --
   procedure Execute_Initialize_Rekeying (
      Job           : in out Job_Type;
      Job_Idx       :        Jobs_Index_Type;
      SB            : in out Superblock_Type;
      SB_Idx        : in out Superblocks_Index_Type;
      Curr_Gen      : in out Generation_Type;
      Progress      : in out Boolean);

   --
   --  Execute_Rekey_VBA
   --
   procedure Execute_Rekey_VBA (
      Job           : in out Job_Type;
      Job_Idx       :        Jobs_Index_Type;
      SB            : in out Superblock_Type;
      SB_Idx        : in out Superblocks_Index_Type;
      Curr_Gen      : in out Generation_Type;
      Progress      : in out Boolean);

   --
   --  Superblock_Enter_Rekeying_State
   --
   procedure Superblock_Enter_Rekeying_State (
      SB            : in out Superblock_Type;
      Key_Plaintext :        Key_Plaintext_Type);

end CBE.Superblock_Control;
