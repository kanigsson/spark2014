package X is
   type T is private;
   procedure P (x : T);
private
   pragma SPARK_Mode (Off);
   type Ptr is access integer;
   type T is record
      A : Ptr;
   end record;
end X;
