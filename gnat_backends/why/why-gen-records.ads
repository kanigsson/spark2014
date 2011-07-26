------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                      W H Y - G E N - R E C O R D S                       --
--                                                                          --
--                                 S p e c                                  --
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

with String_Utils; use String_Utils;
with Why.Ids;      use Why.Ids;

package Why.Gen.Records is
   --  This package encapsulates the encoding of Ada records into Why.

   --  We are limited to read-only operations on record types for now;
   --  so these are modeled by an abstract type in Why, with one getter
   --  function per field, plus a builder.

   procedure Start_Ada_Record_Declaration
     (File    : W_File_Id;
      Name    : String;
      Builder : out W_Logic_Type_Id);
   --  Create the declaration of a null record; return its builder logic
   --  function, of the form make___<name> : unit -> <name>.

   procedure Add_Component
     (File    : W_File_Id;
      C_Name  : String;
      C_Type  : W_Primitive_Type_Id;
      Builder : W_Logic_Type_Id);
   --  Add a component to the record type whose name is given in parameter;
   --  and update the builder accordingly (adding a parameter to it).

   procedure Freeze_Ada_Record
     (File    : W_File_Id;
      Name    : String;
      C_Names : String_Lists.List;
      Builder : W_Logic_Type_Id);
   --  Finalize the definition of an Ada record by generating its axioms;
   --  one per field, saying that applying a projection on a builder
   --  returns the appropriate result. e.g.
   --
   --  axiom make_get___t_a :
   --   forall (a : t1) (b : t2) (c : t3).
   --    get___t_a (make___t (a,b,c)) = a

end Why.Gen.Records;
