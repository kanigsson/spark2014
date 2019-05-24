------------------------------------------------------------------------------
--                                                                          --
--                            GNATPROVE COMPONENTS                          --
--                                                                          --
--                            S E M A P H O R E S                           --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                     Copyright (C) 2019, AdaCore                     --
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

with Interfaces.C; use Interfaces.C;

package body Semaphores is

   function Create_Semaphore_C
     (Name : char_array; Parallel : int) return Semaphore
     with Import, Convention => C, External_Name => "create_semaphore";

   function Open_Semaphore_C (Name : char_array) return Semaphore
     with Import, Convention => C, External_Name => "open_semaphore";

   procedure Delete_Semaphore_C (Name : char_array)
   with Import, Convention => C, External_Name => "delete_semaphore";

   ----------------------
   -- Create_Semaphore --
   ----------------------

   function Create_Semaphore (Name : String; Parallel : Natural)
                              return Semaphore
   is
   begin
      return Create_Semaphore_C (To_C (Name), int (Parallel));
   end Create_Semaphore;

   ----------------------
   -- Delete_Semaphore --
   ----------------------

   procedure Delete_Semaphore (Name : String) is
   begin
      Delete_Semaphore_C (To_C (Name));
   end Delete_Semaphore;

   --------------------
   -- Open_Semaphore --
   --------------------

   function Open_Semaphore (Name : String) return Semaphore is
   begin
      return Open_Semaphore_C (To_C (Name));
   end Open_Semaphore;

end Semaphores;
