------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                        W H Y - G E N - D E C L                           --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                       Copyright (C) 2010-2011, AdaCore                   --
--                                                                          --
-- gnat2why is  free  software;  you can redistribute  it and/or  modify it --
-- under terms of the  GNU General Public License as published  by the Free --
-- Software  Foundation;  either version 3,  or (at your option)  any later --
-- version.  gnat2why is distributed  in the hope that  it will be  useful, --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public License  distributed with  gnat2why;  see file COPYING3. --
-- If not,  go to  http://www.gnu.org/licenses  for a complete  copy of the --
-- license.                                                                 --
--                                                                          --
-- gnat2why is maintained by AdaCore (http://www.adacore.com)               --
--                                                                          --
------------------------------------------------------------------------------

with Why.Conversions;     use Why.Conversions;
with Why.Atree.Accessors; use Why.Atree.Accessors;
with Why.Atree.Builders;  use Why.Atree.Builders;
with Why.Atree.Mutators;  use Why.Atree.Mutators;
with Why.Atree.Tables;    use Why.Atree.Tables;
with Why.Gen.Names;       use Why.Gen.Names;

package body Why.Gen.Decl is

   ----------
   -- Emit --
   ----------

   procedure Emit
      (File : W_File_Id;
       Decl : W_Logic_Declaration_Class_Id)
   is
      Item : constant W_Declaration_Id :=
               New_Logic_Declaration (Decl => Decl);
   begin
      File_Append_To_Declarations
        (Id => File,
         New_Item => Item);
   end Emit;

   procedure Emit
     (File : W_File_Id;
      Decl : W_Declaration_Id) is
   begin
      File_Append_To_Declarations
        (Id => File,
         New_Item => +Decl);
   end Emit;

   -----------------------
   -- Iter_Binder_Array --
   -----------------------

   procedure Iter_Binder_Array
      (Binders : W_Binder_Array;
       Rev : Boolean := False)
   is
      procedure Inner_Loop (Index : Integer);
      --  Extracting the inner loop to avoid duplication

      ----------------
      -- Inner_Loop --
      ----------------

      procedure Inner_Loop (Index : Integer) is
         use Node_Lists;

         Cur_Binder : constant W_Binder_Id := Binders (Index);
         Arg_Ty     : constant W_Simple_Value_Type_Id :=
            Binder_Get_Arg_Type (Cur_Binder);
         Names      : constant Node_Lists.List :=
            Get_List (+Binder_Get_Names (Cur_Binder));
         Cur        : Node_Lists.Cursor :=
            (if Rev then Last (Names) else First (Names));
      begin
         begin
            while Has_Element (Cur) loop
               Handle_Binder
                  (Name  => +Element (Cur),
                   Ty    => Arg_Ty);
               if Rev then
                  Node_Lists.Previous (Cur);
               else
                  Node_Lists.Next (Cur);
               end if;
            end loop;
         end;
      end Inner_Loop;

      --  beginning of processing for Iter_Binder_Array

   begin
      if Rev then
         for Index in reverse Binders'Range loop
            Inner_Loop (Index);
         end loop;
      else
         for Index in Binders'Range loop
            Inner_Loop (Index);
         end loop;
      end if;
   end Iter_Binder_Array;

   -----------------------
   -- New_Abstract_Type --
   -----------------------

   procedure New_Abstract_Type (File : W_File_Id; Name : String)
   is
   begin
      Emit
        (File,
         New_Type (Name => New_Identifier (Name)));
   end New_Abstract_Type;

   procedure New_Abstract_Type (File : W_File_Id; Name : W_Identifier_Id)
   is
   begin
      Emit
        (File,
         New_Type (Name => Name));
   end New_Abstract_Type;

   procedure New_Abstract_Type
      (File : W_File_Id;
       Name : W_Identifier_Id;
       Args : Natural)
   is
      C : Character := 'a';
      Type_Ar : W_Identifier_Array := (1 .. Args => <>);
   begin
      if Args = 0 then
         New_Abstract_Type (File, Name);
         return;
      end if;

      for I in 1 .. Args loop
         Type_Ar (I) := New_Identifier ((1 => C));
         C := Character'Succ (C);
      end loop;

      Emit
       (File,
        New_Type
          (Name            => Name,
           Type_Parameters => Type_Ar));
   end New_Abstract_Type;

   ------------------------
   -- New_Adt_Definition --
   ------------------------

   procedure New_Adt_Definition
     (File : W_File_Id;
      Name : W_Identifier_Id;
      Constructors : W_Constr_Decl_Array)
   is
   begin
      Emit
       (File,
        New_Type
          (Name => Name,
           Definition =>
             New_Adt_Definition (Constructors => Constructors)));
   end New_Adt_Definition;

   ---------------
   -- New_Axiom --
   ---------------

   procedure New_Axiom
      (File       : W_File_Id;
       Name       : W_Identifier_Id;
       Axiom_Body : W_Predicate_Id)
   is
   begin
      Emit
        (File,
         New_Axiom (Name => Name, Def => Axiom_Body));
   end New_Axiom;

   -------------------
   -- New_Exception --
   -------------------

   procedure New_Exception
      (File      : W_File_Id;
       Name      : W_Identifier_Id;
       Parameter : W_Primitive_Type_Id)
   is
   begin
      File_Append_To_Declarations
         (File,
          New_Exception_Declaration (Name => Name, Parameter => Parameter));
   end New_Exception;

   --------------------------------
   -- New_Global_Ref_Declaration --
   --------------------------------

   procedure New_Global_Ref_Declaration
      (File     : W_File_Id;
       Name     : W_Identifier_Id;
       Obj_Type : W_Primitive_Type_Id) is
   begin
      File_Append_To_Declarations
         (File,
            New_Global_Ref_Declaration
               (Name => Name, Parameter_Type => Obj_Type));
   end New_Global_Ref_Declaration;

   -----------------------------
   -- New_Include_Declaration --
   -----------------------------

   procedure New_Include_Declaration
     (File : W_File_Id;
      Name : W_Identifier_Id;
      Ada_Node : Node_Id := Empty)
   is
   begin
      File_Append_To_Declarations
        (Id => File,
         New_Item =>
           New_Include_Declaration
             (Ada_Node => Ada_Node,
              Name     => Name));
   end New_Include_Declaration;

   ---------------
   -- New_Logic --
   ---------------

   procedure New_Logic
     (File        : W_File_Id;
      Name        : W_Identifier_Id;
      Args        : W_Logic_Arg_Type_Array;
      Return_Type : W_Logic_Return_Type_Id)
   is
   begin
      Emit
        (File,
         New_Logic
           (Names => (1 => Name),
            Logic_Type =>
              New_Logic_Type
                (Arg_Types   => Args,
                 Return_Type => Return_Type)));
   end New_Logic;

   procedure New_Logic
     (File        : W_File_Id;
      Name        : W_Identifier_Id;
      Binders     : W_Binder_Array;
      Return_Type : W_Logic_Return_Type_Id)
   is
      Ar  : W_Logic_Arg_Type_Array := (1 .. Binders'Length => <>);
      Cnt : Integer := 1;

      procedure Handle_Binder
         (Name : W_Identifier_Id;
          Ty   : W_Simple_Value_Type_Id);

      -------------------
      -- Handle_Binder --
      -------------------

      procedure Handle_Binder
         (Name : W_Identifier_Id;
          Ty   : W_Simple_Value_Type_Id) is
      begin
         pragma Unreferenced (Name);
         Ar (Cnt) := +Ty;
         Cnt := Cnt + 1;
      end Handle_Binder;

      procedure Iter_Binders is new Iter_Binder_Array (Handle_Binder);
   begin
      Iter_Binders (Binders);
      New_Logic
         (File => File,
          Name => Name,
          Args => Ar,
          Return_Type => Return_Type);
   end New_Logic;

   ------------------------------
   -- New_Predicate_Definition --
   ------------------------------

   procedure New_Predicate_Definition
     (File     : W_File_Id;
      Name     : W_Identifier_Id;
      Binders  : W_Logic_Binder_Array;
      Def      : W_Predicate_Id)
   is
   begin
      Emit (File,
            New_Predicate_Definition
              (Name    => Name,
               Binders => Binders,
               Def     => Def));
   end New_Predicate_Definition;

end Why.Gen.Decl;
