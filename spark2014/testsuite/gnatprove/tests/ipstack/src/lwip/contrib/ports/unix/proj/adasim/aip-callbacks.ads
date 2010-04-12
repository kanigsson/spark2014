------------------------------------------------------------------------------
--                            IPSTACK COMPONENTS                            --
--             Copyright (C) 2010, Free Software Foundation, Inc.           --
------------------------------------------------------------------------------

--# inherit AIP;

package AIP.Callbacks is

   --  Eventually, callbacks will be identified by integer values and the user
   --  data argument will be an integer index as well, designating a state
   --  array entry.

   --  As long as we rely on the original LWIP implementation, callbacks
   --  are expected to be pointers to subprograms and the user data argument
   --  is passed around as an opaque pointer.

   --  We pass bare subprogram addresses as callback points and pass the
   --  integer values as the user data argument already, using an integer type
   --  sized as an address (Ctypes.SI_T). This is handled the same as a
   --  pointer through LWIP and allows array indexing the way we'll need it in
   --  the end.

   subtype Callback_Id is AIP.IPTR_T;
   NOCB : constant Callback_Id := AIP.NULIPTR;

end AIP.Callbacks;
