------------------------------------------------------------------------------
--                                                                          --
--                            GNATPROVE COMPONENTS                          --
--                                                                          --
--                            S E M A P H O R E S                           --
--                                                                          --
--                                 S p e c                                  --
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

with System;

package Semaphores is

   type Semaphore is private;

   function Create_Semaphore
     (Name : String; Parallel : Natural) return Semaphore;
   function Open_Semaphore (Name : String) return Semaphore;
   procedure Close_Semaphore (S : Semaphore)
   with Import, Convention => C, External_Name => "close_semaphore";

   procedure Wait_Semaphore (S : Semaphore)
   with Import, Convention => C, External_Name => "wait_semaphore";

   procedure Release_Semaphore (S : Semaphore)
     with Import, Convention => C, External_Name => "release_semaphore";

   procedure Delete_Semaphore (Name : String);

private

   type Semaphore is new System.Address;

end Semaphores;
