------------------------------------------------------------------------------
--                            IPSTACK COMPONENTS                            --
--             Copyright (C) 2010, Free Software Foundation, Inc.           --
------------------------------------------------------------------------------

with AIP.Buffers.Common;
with AIP.Buffers.Data;
with AIP.Buffers.No_Data;
with AIP.Support;

package body AIP.Buffers
--# own State is AIP.Buffers.Common.Buf_List,
--#              AIP.Buffers.Data.State, AIP.Buffers.Data.Free_List,
--#              AIP.Buffers.No_Data.State, AIP.Buffers.No_Data.Free_List;
is
   --------------------
   -- Is_Data_Buffer --
   --------------------

   function Is_Data_Buffer (Buf : Buffer_Id) return Boolean is
   begin
      return Buf <= Chunk_Num;
   end Is_Data_Buffer;

   -----------------
   -- Buffer_Init --
   -----------------

   procedure Buffer_Init
   --# global out Common.Buf_List,
   --#            Data.State, Data.Free_List,
   --#            No_Data.State, No_Data.Free_List;
   is
   begin
      --  First initialize all the memory for common buffers data structure
      --  to zero
      --# accept W, 169, Common.Buf_List,
      --#           "Direct update of own variable of a non-enclosing package";
      Common.Buf_List :=
        Common.Buffer_Array'
          (others =>
               Common.Buffer'(Next => 0, Len => 0, Tot_Len => 0, Ref => 0));

      --  Construct a singly linked chain of buffers
      for Buf in Buffer_Index range 1 .. Buffer_Index'Last - 1 loop
         Common.Buf_List (Buf).Next := Buf + 1;
      end loop;
      --# end accept;

      No_Data.Buffer_Init;  --  Data structures for no-data buffers
      Data.Buffer_Init;  --  Data structures for data buffers
   end Buffer_Init;

   ------------------
   -- Buffer_Alloc --
   ------------------

   procedure Buffer_Alloc
     (Offset :     Offset_Length;
      Size   :     Data_Length;
      Kind   :     Buffer_Kind;
      Buf    : out Buffer_Id)
   --# global in out Common.Buf_List,
   --#               Data.State, Data.Free_List,
   --#               No_Data.State, No_Data.Free_List;
   is
      No_Data_Buf : No_Data.Buffer_Id;
   begin
      if Kind in Data_Buffer_Kind then
         Data.Buffer_Alloc (Offset => Offset,
                            Size   => Size,
                            Kind   => Kind,
                            Buf    => Buf);
      else
         No_Data.Buffer_Alloc (Size => Size,
                               Buf  => No_Data_Buf);
         Buf := No_Data.Adjust_Back_Id (No_Data_Buf);
      end if;
   end Buffer_Alloc;

   ----------------
   -- Buffer_Len --
   ----------------

   function Buffer_Len (Buf : Buffer_Id) return AIP.U16_T
   --# global in Common.Buf_List;
   is
   begin
      return Common.Buf_List (Buf).Len;
   end Buffer_Len;

   -----------------
   -- Buffer_Tlen --
   -----------------

   function Buffer_Tlen (Buf : Buffer_Id) return AIP.U16_T
   --# global in Common.Buf_List;
   is
   begin
      return Common.Buf_List (Buf).Tot_Len;
   end Buffer_Tlen;

   -----------------
   -- Buffer_Next --
   -----------------

   function Buffer_Next (Buf : Buffer_Id) return Buffer_Id
   --# global in Common.Buf_List;
   is
   begin
      return Common.Buf_List (Buf).Next;
   end Buffer_Next;

   --------------------
   -- Buffer_Payload --
   --------------------

   function Buffer_Payload (Buf : Buffer_Id) return AIP.IPTR_T
   --# global in Data.State, No_Data.State;
   is
      Result : AIP.IPTR_T;
   begin
      if Is_Data_Buffer (Buf) then
         Result := Data.Buffer_Payload (Buf);
      else
         Result := No_Data.Buffer_Payload (No_Data.Adjust_Id (Buf));
      end if;
      return Result;
   end Buffer_Payload;

   ----------------
   -- Buffer_Ref --
   ----------------

   procedure Buffer_Ref (Buf : Buffer_Id)
   --# global in out Common.Buf_List;
   is
   begin
      --# accept W, 169, Common.Buf_List,
      --#           "Direct update of own variable of a non-enclosing package";
      Common.Buf_List (Buf).Ref := Common.Buf_List (Buf).Ref + 1;
      --# end accept;
   end Buffer_Ref;

   -----------------
   -- Buffer_Free --
   -----------------

   procedure Buffer_Free (Buf : Buffer_Id; N_Deallocs : out AIP.U8_T)
   --# global in out Common.Buf_List, Data.State,
   --#               Data.Free_List, No_Data.Free_List;
   is
      Cur_Buf, Next_Buf : Buffer_Id;
      Free_List         : Buffer_Index;
   begin
      Next_Buf   := Buf;
      N_Deallocs := 0;

      while Next_Buf /= NOBUF loop
         --  Update iterators
         Cur_Buf  := Next_Buf;
         Next_Buf := Common.Buf_List (Cur_Buf).Next;

         --  Store head of appropriate free-list in Free_List
         if Is_Data_Buffer (Cur_Buf) then
            Free_List := Data.Free_List;
         else
            Free_List := No_Data.Adjust_Back_Id (No_Data.Free_List);
         end if;

         --  Decrease reference count
         --# accept W, 169, Common.Buf_List,
         --#        "Direct update of own variable of a non-enclosing package";
         Common.Buf_List (Cur_Buf).Ref := Common.Buf_List (Cur_Buf).Ref - 1;
         --# end accept;

         --  If reference count reaches zero, deallocate buffer
         if Common.Buf_List (Cur_Buf).Ref = 0 then
            N_Deallocs                     := N_Deallocs + 1;

            --  Link to the head of the free-list
            --# accept W, 169, Common.Buf_List,
            --#     "Direct update of own variable of a non-enclosing package";
            Common.Buf_List (Cur_Buf).Next := Free_List;
            --# end accept;

            --  Perform link actions specific to data buffers
            if Is_Data_Buffer (Cur_Buf) then
               Data.Buffer_Link (Cur_Buf, Free_List);
            end if;

            --  Push to the head of the appropriate free-list
            if Is_Data_Buffer (Cur_Buf) then
               --# accept W, 169, Data.Free_List,
               --#  "Direct update of own variable of a non-enclosing package";
               Data.Free_List              := Cur_Buf;
               --# end accept;
            else
               --# accept W, 169, No_Data.Free_List,
               --#  "Direct update of own variable of a non-enclosing package";
               No_Data.Free_List           := No_Data.Adjust_Id (Cur_Buf);
               --# end accept;
            end if;
         else
            --  Stop the iteration
            Next_Buf                       := NOBUF;
         end if;
      end loop;
   end Buffer_Free;

   -----------------------
   -- Buffer_Blind_Free --
   -----------------------

   procedure Buffer_Blind_Free (Buf : Buffer_Id)
   --# global in out Common.Buf_List, Data.State,
   --#               Data.Free_List, No_Data.Free_List;
   is
      N_Deallocs : AIP.U8_T;
   begin
      --# accept F, 10, N_Deallocs, "Assignment is ineffective";
      Buffer_Free (Buf, N_Deallocs);
      --# end accept;
      --# accept F, 33, N_Deallocs,
      --#               "The variable is neither referenced nor exported";
   end Buffer_Blind_Free;

   --------------------
   -- Buffer_Release --
   --------------------

   procedure Buffer_Release (Buf : Buffer_Id)
   --# global in out Common.Buf_List, Data.State,
   --#               Data.Free_List, No_Data.Free_List;
   is
      N_Deallocs : AIP.U8_T := 0;
   begin
      --  Keep calling Buffer_Free until it deallocates
      while N_Deallocs = 0 loop
         Buffer_Free (Buf, N_Deallocs);
      end loop;
   end Buffer_Release;

   ----------------
   -- Buffer_Cat --
   ----------------

   procedure Buffer_Cat (Head : Buffer_Id; Tail : Buffer_Id)
   --# global in out Common.Buf_List;
   is
      Cur_Buf, Next_Buf : Buffer_Id;
      Tail_Len          : Data_Length;
   begin
      Cur_Buf  := Head;  --  Not useful as Head should not be NOBUF.
                         --  Cur_Buf initialized anyway to avoid flow error.
      Next_Buf := Head;
      Tail_Len := Common.Buf_List (Tail).Tot_Len;

      while Next_Buf /= NOBUF loop
         --  Update iterators
         Cur_Buf  := Next_Buf;
         Next_Buf := Common.Buf_List (Cur_Buf).Next;

         --  Add total length of second chain to all totals of first chain
         --# accept W, 169, Common.Buf_List,
         --#        "Direct update of own variable of a non-enclosing package";
         Common.Buf_List (Cur_Buf).Tot_Len :=
           Common.Buf_List (Cur_Buf).Tot_Len + Tail_Len;
         --# end accept;
      end loop;

      --  Chain last buffer of Head with first of Tail. Note that no specific
      --  action is done for data buffers, as Head and Tail represent here
      --  two different buffers in the packet chain.
      --# accept W, 169, Common.Buf_List,
      --#           "Direct update of own variable of a non-enclosing package";
      Common.Buf_List (Cur_Buf).Next := Tail;
      --# end accept;

      --  Head now points to Tail, but the caller will drop its reference to
      --  Tail, so netto there is no difference to the reference count of Tail.
   end Buffer_Cat;

   ------------------
   -- Buffer_Chain --
   ------------------

   procedure Buffer_Chain (Head : Buffer_Id; Tail : Buffer_Id)
   --# global in out Common.Buf_List;
   is
   begin
      Buffer_Cat (Head, Tail);
      --  Tail is now referenced by Head
      Buffer_Ref (Tail);
   end Buffer_Chain;

   -------------------
   -- Buffer_Header --
   -------------------

   --  Note: if this procedure is called on a buffer not in front of a chain,
   --        then if will result in a violation of the invariant for the total
   --        length of buffers that precede it in the chain.
   --        This means that we should probably change this functionality in
   --        our implementation of LWIP in SPARK.

   procedure Buffer_Header (Buf : Buffer_Id; Bump : AIP.S16_T)
   --# global in out Common.Buf_List, Data.State, No_Data.State;
   is
      Offset : AIP.U16_T;
   begin
      Offset := AIP.U16_T (abs (Bump));

      --  Check that we are not going to move off the end of the buffer
      if Bump <= 0 then
         Support.Verify (Common.Buf_List (Buf).Len >= Offset);
      end if;

      if Is_Data_Buffer (Buf) then
         Data.Buffer_Header (Buf, Bump);
      else
         No_Data.Buffer_Header (No_Data.Adjust_Id (Buf), Bump);
      end if;

      --  Modify length fields
      --# accept W, 169, Common.Buf_List,
      --#           "Direct update of own variable of a non-enclosing package";
      if Bump >= 0 then
         Common.Buf_List (Buf).Len     :=
           Common.Buf_List (Buf).Len + Offset;
         Common.Buf_List (Buf).Tot_Len :=
           Common.Buf_List (Buf).Tot_Len + Offset;
      else
         Common.Buf_List (Buf).Len     :=
           Common.Buf_List (Buf).Len - Offset;
         Common.Buf_List (Buf).Tot_Len :=
           Common.Buf_List (Buf).Tot_Len - Offset;
      end if;
      --# end accept;
   end Buffer_Header;

end AIP.Buffers;
