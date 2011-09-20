------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                           W H Y - I M A G E S                            --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                       Copyright (C) 2011, AdaCore                        --
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

with Types; use Types;

package body Why.Images is

   ---------
   -- Img --
   ---------

   function Img (Name : Name_Id) return String is
   begin
      if Name = No_Name then
         return "[no name]";
      else
         return Get_Name_String (Name);
      end if;
   end Img;

   function Img (Node : Why_Node_Id) return String is
      Result : constant String := Why_Node_Id'Image (Node);
      First  : constant Positive := Result'First + 1;
   begin
      return Result (First .. Result'Last);
   end Img;

   -------
   -- P --
   -------

   procedure P (O : Output_Id; Name : Name_Id) is
   begin
      P (O, Img (Name));
   end P;

   procedure P (O : Output_Id; Node : Why_Node_Id) is
   begin
      P (O, Img (Node));
   end P;

   procedure P (O : Output_Id; Value : Boolean) is
   begin
      P (O, Boolean'Image (Value));
   end P;

   procedure P (O : Output_Id; Value : Uint) is
      H         : constant array (Int range 0 .. 15) of Character :=
                    "0123456789ABCDEF";
      Base      : constant := 10;
      Abs_Value : Uint;
   begin
      --  ??? The Why Reference does not give any detail about
      --  the syntax of integer constants. We shall suppose that
      --  it is similar to Ocaml's integer litterals:
      --
      --  IntegerLiteral ::=
      --     [-]  UnprefixedIntegerLiteral
      --
      --  UnprefixedIntegerLiteral ::=
      --      DecimalLiteral
      --      HexadecimalLiteral
      --      OctalLiteral
      --      BinaryLiteral
      --
      --  DecimalLiteral ::=
      --      DecimalLiteral  Digit
      --      DecimalLiteral  _
      --      Digit
      --
      --  HexadecimalLiteral ::=
      --      HexadecimalLiteral  HexadecimalDigit
      --      HexadecimalLiteral  _
      --      0x  HexadecimalDigit
      --      0X  HexadecimalDigit
      --
      --  OctalLiteral ::=
      --      OctalLiteral  OctalDigit
      --      OctalLiteral  _
      --      0o  OctalDigit
      --      0O  OctalDigit
      --
      --  BinaryLiteral ::=
      --      BinaryLiteral  BinaryDigit
      --      BinaryLiteral  _
      --      0b  BinaryDigit
      --      0B  BinaryDigit
      --
      --  Digit ::=
      --      DecimalDigit
      --
      --  HexadecimalDigit ::=  { 0123456789abcdefABCDEF }
      --
      --  DecimalDigit ::=  { 0123456789 }
      --
      --  OctalDigit ::=  { 01234567 }
      --
      --  BinaryDigit ::=  { 01 }

      if Value = No_Uint then
         P (O, "?");
         return;
      end if;

      if Value < Uint_0 then
         P (O, "-");
         Abs_Value := -Value;
      else
         Abs_Value := Value;
      end if;

      if Abs_Value >= Base then
         P (O, Abs_Value / Base);
      end if;

      P (O, "" & H (UI_To_Int (Abs_Value rem Base)));
   end P;

   procedure P (O : Output_Id; Value : Ureal) is
      Num    : constant Uint := Numerator (Value);
      Den    : constant Uint := Denominator (Value);
      Base   : constant Nat := Rbase (Value);
   begin
      --  ??? Same remark as in the case of integer constants:
      --  I suppose that Why's real constants follows the same syntax
      --  as Ocaml's floating-point literals:
      --
      --      FloatingPointLiteral ::=
      --        [-]  UnprefixedFloatingPointLiteral
      --
      --      UnprefixedFloatingPointLiteral ::=
      --        DecimalLiteral  FractionalPart  ExponentPart
      --        DecimalLiteral  FractionalPart
      --        DecimalLiteral  ExponentPart
      --
      --      FractionalPart ::=
      --        FractionalPart  Digit
      --        FractionalPart  _
      --        .
      --
      --      ExponentPart ::=
      --        ExponentLetter  +  DecimalLiteral
      --        ExponentLetter  -  DecimalLiteral
      --        ExponentLetter     DecimalLiteral
      --
      --       ExponentLetter ::=  { eE }

      if UR_Is_Negative (Value) then
         P (O, EW_Substract, EW_Real);
      end if;

      if Base = 0 then
         P (O, Num);
         P (O, ".0");
         P (O, EW_Divide, EW_Real);
         P (O, Den);
         P (O, ".0");

      elsif Base = 10 then
         P (O, Num);
         P (O, "E");

         if Den > Uint_0 then
            P (O, "-");
            P (O, Den);
         else
            P (O, -Den);
         end if;

      else
         P (O, Num);
         P (O, ".0");

         if Den > Uint_0 then
            P (O, EW_Divide, EW_Real);
            P (O, UI_Expon (Den, Base));
            P (O, ".0");

         else
            P (O, EW_Multiply, EW_Real);
            P (O, UI_Expon (UI_Negate (Den), Base));
            P (O, ".0");
         end if;
      end if;
   end P;

   procedure P (O : Output_Id; Value : EW_Type) is
   begin
      case Value is
         when EW_Unit =>
            P (O, "unit");
         when EW_Prop =>
            P (O, "prop");
         when EW_Real =>
            P (O, "real");
         when EW_Int =>
            P (O, "int");
         when EW_Bool =>
            P (O, "bool");
         when EW_Abstract =>
            P (O, "[from Ada node]");
      end case;
   end P;

   procedure P
     (O      : Output_Id;
      Value  : EW_Literal;
      Domain : EW_Domain := EW_Prog)
   is
   begin
      case Value is
         when EW_True =>
            if Domain in EW_Prog | EW_Term then
               P (O, "True");
            else
               P (O, "true");
            end if;
         when EW_False =>
            if Domain in EW_Prog | EW_Term then
               P (O, "False");
            else
               P (O, "false");
            end if;
      end case;
   end P;

   procedure P
     (O       : Output_Id;
      Value   : EW_Binary_Op;
      Op_Type : EW_Scalar := EW_Int) is
   begin
      case Value is
         when EW_Add =>
            P (O, "+");
         when EW_Substract =>
            P (O, "-");
         when EW_Multiply =>
            P (O, "*");
         when EW_Divide =>
            P (O, "/");
         when EW_Mod =>
            P (O, "%");
      end case;

      if Op_Type = EW_Real then
         P (O, ".");
      end if;
   end P;

   procedure P
     (O       : Output_Id;
      Value   : EW_Relation;
      Op_Type : EW_Type := EW_Int) is
   begin
      case Value is
         when EW_None =>
            pragma Assert (False);
            null;
         when EW_Eq =>
            P (O, "=");
         when EW_Ne =>
            P (O, "<>");
         when EW_Lt =>
            P (O, "<");
         when EW_Le =>
            P (O, "<=");
         when EW_Gt =>
            P (O, ">");
         when EW_Ge =>
            P (O, ">=");
      end case;

      if Op_Type = EW_Real and then
         not (Value in EW_Eq .. EW_Ne) then
         P (O, ".");
      end if;
   end P;

   procedure P (O : Output_Id; Value : EW_Connector) is
   begin
      case Value is
         when EW_Or_Else =>
            P (O, "||");

         when EW_And_Then =>
            P (O, "&&");

         when EW_Imply =>
            P (O, "->");

         when EW_Equivalent =>
            P (O, "<->");

         when EW_Or =>
            P (O, "\/");

         when EW_And =>
            P (O, "/\");
      end case;
   end P;

   procedure P (O       : Output_Id;
                Value   : EW_Unary_Op;
                Op_Type : EW_Scalar := EW_Int) is
   begin
      case Value is
         when EW_Minus =>
            P (O, EW_Substract, Op_Type);
         when EW_Deref =>
            P (O, "!");
      end case;
   end P;

   procedure P (O : Output_Id; Value : EW_Domain) is
   begin
      case Value is
         when EW_Term =>
            P (O, "[term]");
         when EW_Pred =>
            P (O, "[predicate]");
         when EW_Prog =>
            P (O, "[program]");
      end case;
   end P;

end Why.Images;
