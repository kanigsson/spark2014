package Stacks is
   --  A stack package that holds integers

   Default_Value : constant := -1;
   --  value used to initialize not used stack elements;

   Default_Size  : constant := 1_000;

   type Content_Type is array (Integer range <>) of Integer;
   --  the array that holds the elements

   type Stack (Size : Positive) is record
      Content : Content_Type (1 .. Size);
      Index   : Integer;
      --  points to the first empty cell
   end record;

   function Create (I : Positive := Default_Size) return Stack;
   --  Create stack with I elements

   function Is_Empty (S : Stack) return Boolean;

   function Is_Full (S : Stack) return Boolean;

   procedure Push (S : in out Stack; X : Integer) with
     Pre  => not Is_Full (S),
     Post => not Is_Empty (S)
               and then Peek (S) = X;   --  from 8
   --  push a new element on the stack

   procedure Pop (S : in out Stack; X : out Integer) with
     Pre  => not Is_Empty (S),
     Post => not Is_Full (S)
               and then X = Peek (S)'Old;
   --  remove the topmost element from the stack, and return it in X

   function Pop (S : in out Stack) return Integer with
     Pre  => not Is_Empty (S),
     Post => not Is_Full (S)
               and then Pop'Result = Peek (S)'Old;
   --  same as the above procedure, but return the topmost element,
   --  instead of having an out parameter
   --  note that only in Ada 2012 functions can have in out parameters.

   function Peek (S : Stack) return Integer with
     Pre => not Is_Empty (S);
   --  returns  the topmost element of the stack without removing it

   function Push (S : Stack; X : Integer) return Stack with
     Pre  => not Is_Full (S),
     Post => not Is_Empty (Push'Result)
               and then Peek (Push'Result) = X;   --  from
   --  leave the current stack alone and
   --  returns  a new stack with the new element on top
   --  Note that "S" is an "in" parameter and is not modified. So Push
   --  make a copy of S, modify the copy, and then return that modified copy.

end Stacks;
