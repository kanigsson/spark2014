package T1Q2
  with SPARK_Mode
is

   procedure Increment2 (X, Y : in out Integer)
     with Pre => (X /= Integer'Last)
                   and then (Y /= Integer'Last),
          Post => (X = X'Old + 1)
                    and then (Y = Y'Old + 1);

end T1Q2;
