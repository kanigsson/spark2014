--  This proof was originally done by Claude March� in Why3 and can be found
--  in the repository of Why3: examples/in_progres/isqrt_von_neumann

with Interfaces; use Interfaces;

package body P32
  with SPARK_Mode => On
is

   -- Auxiliary bitvectors functions for 32 bits
   function Pow2 (X : U32) return U32
   is
     (Shift_Left (1, Integer (X)))
   with Pre => X <= 32;

--   function Sqr (X : U32) return U32 is
--     (X * X);

   procedure Lemma_Bv (X, Y : U32) is
   begin
      null;
   end Lemma_Bv;

   ----------------------
   -- Sqrt_Von_Neumann --
   ----------------------

--  Algorithm from Warren'a "Hacker's Delight" Figure 11.4
--  int isqrt4(unsigned x) {
--     unsigned m, y, b;
--     m = 0x40000000;
--     y = 0;
--     while(m != 0) {              // Do 16 times.
--        b = y | m;
--        y = y >> 1;
--        if (x >= b) {
--           x = x - b;
--           y = y | m;
--        }
--        m = m >> 2;
--     }
--     return y;
--  }
   function Sqrt_Von_Neumann_Aux32
     (X : in U32)
      return U32
   is
      Num, Bits, Res, B : U32;

     --  Ghost entities:

      I : U32 := 0 with Ghost;
      M, Bits_G, Res_G : U32 with Ghost;

   begin
      Num := X;
      pragma Assert (Num <= 2 ** 32 - 1);
      Bits  := 16#4000_0000#;
      Res  := 0;

      M := 16;
      Bits_G := 16#8000#;
      Res_G := 0;

      while (Bits /= 0) loop
         pragma Assert (Bits /= 0);
         Lemma_Bv (Res_G, Bits_G);

         pragma Loop_Variant (Decreases => Bits);
         pragma Loop_Invariant (Bits /= 0);

         pragma Loop_Invariant (M <= 16);
         -- Bits_G = 2^{M-1} or 0 if M=0
         pragma Loop_Invariant (Bits_G = (if M = 0 then 0 else Pow2 (M - 1)));
         --  Bits = Bits_G ** 2
         pragma Loop_Invariant (Bits = Sqr(Bits_G));
         --  Res_G is divided by 2 ** m
         pragma Loop_Invariant ( (Res_G and (Pow2 (M) - 1)) = 0);
         --  Res_G smaller than 2^8
         pragma Loop_Invariant (Res_G < 16#1_0000#);
         --  Res = Res_G * 2^M
         pragma Loop_Invariant (Res = Res_G * Pow2 (M));
         -- Num <= X
         pragma Loop_Invariant (Num <= X);

         pragma Loop_Invariant (M /= 0);
         pragma Loop_Invariant (Sqr (Res_G + Bits_G) = Sqr (Res_G) + Bits_G * (2 * Res_G + Bits_G));
         pragma Loop_Invariant ((Res or Bits) = ((2 * Res_G) + Bits_G) * Pow2 (M - 1));
         pragma Loop_Invariant (Bits_G = Pow2 (M - 1));
         -- (X - Num) is the square of (Res / 2^M)
         pragma Loop_Invariant (X - Num = Sqr(Res_G));
         --  X < (Res_G + 2^M)^2
         pragma Loop_Invariant (X <= (Sqr (Res_G + (Pow2 (M)))) - 1);


         pragma Assert (Bits /= 0);
         pragma Assert (Bits_G /= 0);
         pragma Assert (M /= 0);
         I := I + 1;
         M := M - 1;
         pragma Assert (Res = Res_G * (pow2 (M + 1)));
         pragma Assert (Bits_G = Pow2(M));
         B := Res or Bits;
         pragma Assert (B = Res + Bits);
         pragma Assert (B = ((2 * Res_G) + Bits_G) * Pow2(M));
         Res := Shift_Right (Res, 1);
         pragma Assert (Res = Res_G * Pow2 (M));

         if (Num >= B) then
            Num := Num - B;
            Res  := Res or Bits;

            pragma Assert (Res = (Res_G + Bits_G) * Pow2 (M));
            Res_G := Res_G + Bits_G;
         end if;

         Bits := Bits / 4;
         Bits_G := Shift_Right (Bits_G, 1);
      end loop;

      pragma Assert (M = 0);
      pragma Assert (X <= (Sqr (Res_G + (Pow2 (M)))) - 1);
      pragma Assert (X <= (Sqr (Res_G + 1)) - 1);
      Lemma_Bv (Bits_G, Res_G);
      return Res;
   end Sqrt_Von_Neumann_Aux32;

   function Sqrt_Von_Neumann32 (X : in Sqrt_Domain32) return Sqrt_Range32
   is
   begin
      return (Sqrt_Range32 (Sqrt_Von_Neumann_Aux32 (U32(X))));
   end Sqrt_Von_Neumann32;



end P32;