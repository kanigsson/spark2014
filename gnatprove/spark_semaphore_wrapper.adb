------------------------------------------------------------------------------
--                                                                          --
--                            GNATPROVE COMPONENTS                          --
--                                                                          --
--              S P A R K _ S E M A P H O R E _ W R A P P E R               --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                     Copyright (C) 2017-2019, AdaCore                     --
--                                                                          --
-- gnatprove is  free  software;  you can redistribute it and/or  modify it --
-- under terms of the  GNU General Public License as published  by the Free --
-- Software  Foundation;  either version 3,  or (at your option)  any later --
-- version.  gnatprove is distributed  in the hope that  it will be useful, --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General Public License  distributed with  gnatprove;  see file COPYING3. --
-- If not,  go to  http://www.gnu.org/licenses  for a complete  copy of the --
-- license.                                                                 --
--                                                                          --
-- gnatprove is maintained by AdaCore (http://www.adacore.com)              --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;
with GNAT.OS_Lib;      use GNAT.OS_Lib;
with Semaphores;       use Semaphores;

procedure SPARK_Semaphore_Wrapper
is
   Ret : Integer;
   Args : String_List (1 .. Argument_Count - 2);
begin
   if Argument_Count < 2 then
      Ada.Text_IO.Put_Line ("spark_semaphore_wrapper: not enough arguments");
      OS_Exit (1);
   end if;
   for I in Args'Range loop
      Args (I) := new String'(Argument (I + 2));
   end loop;
   Wait_Semaphore (Argument (1));
   Ret := Spawn (Argument (2), Args);
   Release_Semaphore (Argument (1));
   OS_Exit (Ret);
end SPARK_Semaphore_Wrapper;
