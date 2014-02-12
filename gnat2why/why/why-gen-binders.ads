------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                      W H Y - G E N - B I N D E R S                       --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--                       Copyright (C) 2010-2014, AdaCore                   --
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

with Namet;                  use Namet;
with Types;                  use Types;

with Common_Containers;      use Common_Containers;

with SPARK_Definition;       use SPARK_Definition;

pragma Warnings (Off);
--  ??? Why.Types" is directly visible as "Types", as it has "Why" as a
--  common ancestor with the current package. So it hides compilation unit
--  with the same name ("Types"). Maybe we should think of renaming it to
--  "Why.W_Types".
with Why.Types;              use Why.Types;
pragma Warnings (On);
with Why.Sinfo;              use Why.Sinfo;
with Why.Ids;                use Why.Ids;
with Why.Atree.Builders;     use Why.Atree.Builders;
with Why.Gen.Preds;          use Why.Gen.Preds;

package Why.Gen.Binders is
   --  This package provides operations to build binders in program space
   --  and in logic space.

   type Modifier_Type is (Array_Modifier, Ref_Modifier, None);

   type Binder_Type is record
      Ada_Node : Node_Id := Empty;
      B_Name   : W_Identifier_Id;
      B_Ent    : Entity_Name;
      Mutable  : Boolean := False;
   end record;
   --  This record represents a variable binding B_Name of type B_Type. In some
   --  cases, extra information is stored concerning the Ada entity that is
   --  represented by this binder. The Ada_Node may be used for that, or the
   --  B_Ent field if no entity node is available for the entity.

   type Binder_Array is array (Positive range <>) of Binder_Type;

   type Item_Enum is (Regular, UCArray);

   type Item_Bounds is record
      First : W_Identifier_Id;
      Last  : W_Identifier_Id;
   end record;

   type Array_Bounds is array (1 .. Max_Array_Dimensions) of Item_Bounds;

   type Item_Type (Kind : Item_Enum := Regular) is record
      Main : Binder_Type;
      case Kind is
         when Regular => null;
         when UCArray =>
            Dim    : Positive;
            Bounds : Array_Bounds;
      end case;
   end record;
   --  An item is like a generalized binder. It is used to represent the
   --  mapping
   --    Ada object  -> Why variables
   --  which is not always 1 to 1. In the common case where it is 1 to 1, the
   --  Kind "Regular" is used. The only other case for now is unconstrained
   --  arrays, where extra objects are created to represent the bounds.

   type Item_Array is array (Positive range <>) of Item_Type;

   function Item_Array_Length (Arr : Item_Array) return Natural;
   --  Return the number of variables that is introduced by the given
   --  item_array (counting items plus e.g. array bounds)

   function To_Binder_Array (A : Item_Array) return Binder_Array;
   --  "Flatten" the Item_Array to a binder_array, transforming e.g. array
   --  bounds to binders

   function New_Binders
     (Anonymous_Binders : W_Type_Array)
     return Binder_Array;

   function New_Universal_Quantif
     (Ada_Node : Node_Id := Empty;
      Binders  : Binder_Array;
      Triggers : W_Triggers_OId := Why_Empty;
      Pred     : W_Pred_Id)
     return W_Pred_Id;

   function New_Existential_Quantif
     (Ada_Node : Node_Id := Empty;
      Binders  : Binder_Array;
      Pred     : W_Pred_Id)
     return W_Pred_Id;

   function New_Call
     (Ada_Node : Node_Id := Empty;
      Domain   : EW_Domain;
      Name     : W_Identifier_Id;
      Binders  : Binder_Array)
     return W_Expr_Id;
   --  Create a call to an operation in the given domain with parameters
   --  taken from Binders. Typically, from:
   --
   --     (x1 : type1) (x2 : type2)
   --
   --  ...it produces:
   --
   --     operation_name (x1, x2)

   --  Top-level entities

   function New_Function_Decl
     (Ada_Node    : Node_Id := Empty;
      Domain      : EW_Domain;
      Name        : W_Identifier_Id;
      Binders     : Binder_Array;
      Return_Type : W_Type_Id := Why_Empty;
      Labels      : Name_Id_Set;
      Effects     : W_Effects_Id := New_Effects;
      Def         : W_Expr_Id := Why_Empty;
      Pre         : W_Pred_Id := True_Pred;
      Post        : W_Pred_Id := True_Pred)
     return W_Declaration_Id;

   function New_Record_Definition
      (Ada_Node : Node_Id := Empty;
       Name     : W_Identifier_Id;
       Binders  : Binder_Array) return W_Declaration_Id;

   function New_Guarded_Axiom
     (Ada_Node : Node_Id := Empty;
      Name     : Name_Id;
      Binders  : Binder_Array;
      Triggers : W_Triggers_OId := Why_Empty;
      Pre      : W_Pred_OId := Why_Empty;
      Def      : W_Pred_Id)
     return W_Declaration_Id;
   --  generate an axiom of the form:
   --
   --   axiom <name>:
   --    forall x1 ... xn.
   --       pre -> <def>

   function New_Defining_Axiom
     (Ada_Node    : Node_Id := Empty;
      Name        : W_Identifier_Id;
      Binders     : Binder_Array;
      Return_Type : EW_Type;
      Pre         : W_Pred_OId := Why_Empty;
      Def         : W_Term_Id)
     return W_Declaration_Id;
   --  generate an axiom of the form:
   --
   --   axiom <name>___def:
   --    forall x1 ... xn.
   --       pre -> (<name> (x1 .. xn) = <def>)

   function New_Defining_Bool_Axiom
     (Ada_Node : Node_Id := Empty;
      Name     : W_Identifier_Id;
      Binders  : Binder_Array;
      Pre      : W_Pred_Id := Why_Empty;
      Def      : W_Pred_Id)
     return W_Declaration_Id;
   --  Same as new_defining_axiom, but for functions returning booleans.
   --  (for those, predicates are generated instead of logics).

   function Unit_Param return Binder_Type;
   --  return a dummy binder for a single argument of type unit

end Why.Gen.Binders;
