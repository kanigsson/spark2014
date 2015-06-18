------------------------------------------------------------------------------
--                                                                          --
--                           GNAT2WHY COMPONENTS                            --
--                                                                          --
--               F L O W . C O M P U T E D _ G L O B A L S                  --
--                                                                          --
--                                B o d y                                   --
--                                                                          --
--               Copyright (C) 2014-2015, Altran UK Limited                 --
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
------------------------------------------------------------------------------

with AA_Util;                    use AA_Util;
with Ada.Text_IO;                use Ada.Text_IO;
with Ada.Text_IO.Unbounded_IO;   use Ada.Text_IO.Unbounded_IO;
with Ada.Strings.Unbounded;      use Ada.Strings.Unbounded;
with Ada.Containers.Hashed_Sets;
with ALI;                        use ALI;
with Atree;                      use Atree;
with Einfo;                      use Einfo;
with Flow_Utility;               use Flow_Utility;
with Gnat2Why_Args;
with Graph;
with Lib.Util;                   use Lib.Util;
with Namet;                      use Namet;
with Osint;                      use Osint;
with Osint.C;                    use Osint.C;
with Output;                     use Output;
with Sem_Util;                   use Sem_Util;
with SPARK_Frame_Conditions;     use SPARK_Frame_Conditions;
with SPARK_Util;                 use SPARK_Util;

package body Flow_Computed_Globals is

   --  Debug flags

   Debug_Print_Info_Sets_Read : constant Boolean := False;
   --  Enables printing of Info_Sets as read from ALI files

   Debug_Print_Global_Graph   : constant Boolean := True;
   --  Enables printing of the Global_Graph

   ----------------------------------------------------------------------

   use type Flow_Id_Sets.Set;
   use type Name_Set.Set;

   ----------------------------------------------------------------------

   type State_Phase_1_Info is record
      State        : Entity_Name;
      Constituents : Name_Set.Set;
   end record;

   function Preceeds (A, B : State_Phase_1_Info) return Boolean is
     (A.State.Id < B.State.Id);

   package State_Info_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => State_Phase_1_Info,
      "<"          => Preceeds,
      "="          => "=");

   State_Info_Set : State_Info_Sets.Set;

   ----------------------------------------------------------------------
   --  Volatile information
   ----------------------------------------------------------------------

   All_Volatile_Vars     : Name_Set.Set;
   Async_Writers_Vars    : Name_Set.Set;
   Async_Readers_Vars    : Name_Set.Set;
   Effective_Reads_Vars  : Name_Set.Set;
   Effective_Writes_Vars : Name_Set.Set;

   ----------------------------------------------------------------------
   --  Global_Id
   ----------------------------------------------------------------------

   type Global_Id_Kind is (Null_Kind,
                           --  Does not represent anything yet

                           Ins_Kind,
                           --  Represents subprogram's Ins

                           Outs_Kind,
                           --  Represents subprogram's Outs

                           Proof_Ins_Kind,
                           --  Represents subprogram's Proof_Ins

                           Variable_Kind
                           --  Represents a global variable
                          );

   type Global_Id is record
      Kind : Global_Id_Kind;
      Name : Entity_Name;
   end record;

   function "=" (Left, Right : Global_Id) return Boolean is
     (Left.Kind = Right.Kind and then Left.Name.Id = Right.Name.Id);
   --  Equality for Global_Id

   Null_Global_Id : constant Global_Id :=
     Global_Id'(Kind => Null_Kind,
                Name => Null_Entity_Name);

   -------------------
   -- Global_Graphs --
   -------------------

   package Global_Graphs is new Graph (Vertex_Key   => Global_Id,
                                       Edge_Colours => Edge_Colours,
                                       Null_Key     => Null_Global_Id,
                                       Test_Key     => "=");

   package Vertex_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Global_Graphs.Vertex_Id,
      Hash                => Global_Graphs.Vertex_Hash,
      Equivalent_Elements => Global_Graphs."=",
      "="                 => Global_Graphs."=");

   Global_Graph : Global_Graphs.T;

   use Global_Graphs;

   -----------------------
   -- Local subprograms --
   -----------------------

   procedure Print_Subprogram_Phase_1_Info (Info : Subprogram_Phase_1_Info);
   --  Prints all info related to a subprogram

   procedure Print_Global_Graph (Filename : String;
                                 G        : T);
   --  Writes dot and pdf files for the Global_Graph

   -----------------
   -- To_Name_Set --
   -----------------

   function To_Name_Set (S : Node_Sets.Set) return Name_Set.Set is
      Rv : Name_Set.Set := Name_Set.Empty_Set;
   begin
      for E of S loop
         Rv.Insert (To_Entity_Name (E));
      end loop;
      return Rv;
   end To_Name_Set;

   -----------------------------------
   -- Print_Subprogram_Phase_1_Info --
   -----------------------------------

   procedure Print_Subprogram_Phase_1_Info (Info : Subprogram_Phase_1_Info) is
   begin
      case Info.Kind is
         when S_Kind =>
            Write_Line ("Subprogram " & Info.Name.S.all);
         when T_Kind =>
            Write_Line ("Task " & Info.Name.S.all);
         when E_Kind =>
            Write_Line ("Entry " & Info.Name.S.all);
         when others =>
            raise Program_Error;
      end case;

      Write_Line ("Proof_Ins        :");
      for Name of Info.Inputs_Proof loop
         Write_Line ("   " & Name.S.all);
      end loop;

      Write_Line ("Inputs           :");
      for Name of Info.Inputs loop
         Write_Line ("   " & Name.S.all);
      end loop;

      Write_Line ("Outputs          :");
      for Name of Info.Outputs loop
         Write_Line ("   " & Name.S.all);
      end loop;

      Write_Line ("Proof calls      :");
      for Name of Info.Proof_Calls loop
         Write_Line ("   " & Name.S.all);
      end loop;

      Write_Line ("Definite calls   :");
      for Name of Info.Definite_Calls loop
         Write_Line ("   " & Name.S.all);
      end loop;

      Write_Line ("Conditional calls:");
      for Name of Info.Conditional_Calls loop
         Write_Line ("   " & Name.S.all);
      end loop;

      Write_Line ("Local variables  :");
      for Name of Info.Local_Variables loop
         Write_Line ("   " & Name.S.all);
      end loop;
   end Print_Subprogram_Phase_1_Info;

   ------------------------
   -- Print_Global_Graph --
   ------------------------

   procedure Print_Global_Graph (Filename : String;
                                 G        : T)
   is
      function NDI
        (G : T'Class;
         V : Vertex_Id) return Node_Display_Info;
      --  Pretty-printing for each vertex in the dot output

      function EDI
        (G      : T'Class;
         A      : Vertex_Id;
         B      : Vertex_Id;
         Marked : Boolean;
         Colour : Edge_Colours) return Edge_Display_Info;
      --  Pretty-printing for each edge in the dot output

      ---------
      -- NDI --
      ---------

      function NDI
        (G : T'Class;
         V : Vertex_Id) return Node_Display_Info
      is
         G_Id  : constant Global_Id := G.Get_Key (V);

         Shape : constant Node_Shape_T := (if G_Id.Kind = Variable_Kind
                                           then Shape_Oval
                                           else Shape_Box);

         Label : constant String :=
           (case G_Id.Kind is
              when Proof_Ins_Kind => G_Id.Name.S.all & "'Proof_Ins",
              when Ins_Kind       => G_Id.Name.S.all & "'Ins",
              when Outs_Kind      => G_Id.Name.S.all & "'Outs",
              when Variable_Kind  => G_Id.Name.S.all,
              when Null_Kind      => "");

         Rv : constant Node_Display_Info := Node_Display_Info'
           (Show        => True,
            Shape       => Shape,
            Colour      => Null_Unbounded_String,
            Fill_Colour => Null_Unbounded_String,
            Label       => To_Unbounded_String (Label));
      begin
         return Rv;
      end NDI;

      ---------
      -- EDI --
      ---------

      function EDI
        (G      : T'Class;
         A      : Vertex_Id;
         B      : Vertex_Id;
         Marked : Boolean;
         Colour : Edge_Colours) return Edge_Display_Info
      is
         pragma Unreferenced (G, A, B, Marked, Colour);

         Rv : constant Edge_Display_Info :=
           Edge_Display_Info'(Show   => True,
                              Shape  => Edge_Normal,
                              Colour => Null_Unbounded_String,
                              Label  => Null_Unbounded_String);
      begin
         return Rv;
      end EDI;

   begin
      if Gnat2Why_Args.Debug_Mode then
         if Gnat2Why_Args.Flow_Advanced_Debug then
            G.Write_Pdf_File
              (Filename  => Filename,
               Node_Info => NDI'Access,
               Edge_Info => EDI'Access);
         else
            G.Write_Dot_File
              (Filename  => Filename,
               Node_Info => NDI'Access,
               Edge_Info => EDI'Access);
         end if;
      end if;
   end Print_Global_Graph;

   -------------------------
   -- GG_Write_Initialize --
   -------------------------

   procedure GG_Write_Initialize is
   begin
      Open_Output_Library_Info;

      --  Initialze subprogram info
      Info_Set              := Info_Sets.Empty_Set;

      --  Initialize state info
      State_Info_Set        := State_Info_Sets.Empty_Set;

      --  Initialize volatile info
      All_Volatile_Vars     := Name_Set.Empty_Set;
      Async_Writers_Vars    := Name_Set.Empty_Set;
      Async_Readers_Vars    := Name_Set.Empty_Set;
      Effective_Reads_Vars  := Name_Set.Empty_Set;
      Effective_Writes_Vars := Name_Set.Empty_Set;

      --  Set mode to writing mode
      Current_Mode := GG_Write_Mode;
   end GG_Write_Initialize;

   ---------------------------
   -- GG_Write_Package_Info --
   ---------------------------

   procedure GG_Write_Package_Info (DM : Dependency_Maps.Map) is
   begin
      for S in DM.Iterate loop
         declare
            State_F      : constant Flow_Id := Dependency_Maps.Key (S);

            State_N      : constant Entity_Name :=
              To_Entity_Name (Get_Direct_Mapping_Id (State_F));

            Constituents : constant Name_Set.Set :=
              To_Name_Set (To_Node_Set (Dependency_Maps.Element (S)));

            State_Info   : constant State_Phase_1_Info :=
              State_Phase_1_Info'(State        => State_N,
                                  Constituents => Constituents);
         begin
            --  Insert new state info into State_Info_Set
            State_Info_Set.Insert (State_Info);

            --  Check if State_F if volatile and if it is then add it on the
            --  appropriate sets depending on its properties.
            if Is_Volatile (State_F) then
               All_Volatile_Vars.Insert (State_N);

               if Has_Async_Readers (State_F) then
                  --  Add to Async_Readers_Vars set
                  Async_Readers_Vars.Insert (State_N);
               end if;

               if Has_Async_Writers (State_F) then
                  --  Add to Async_Writers_Vars set
                  Async_Writers_Vars.Insert (State_N);
               end if;

               if Has_Effective_Writes (State_F) then
                  --  Add to Effective_Writes_Vars set
                  Effective_Writes_Vars.Insert (State_N);
               end if;

               if Has_Effective_Reads (State_F) then
                  --  Add to Effective_Reads_Vars set
                  Effective_Reads_Vars.Insert (State_N);
               end if;
            end if;
         end;
      end loop;
   end GG_Write_Package_Info;

   ------------------------------
   -- GG_Write_Subprogram_Info --
   ------------------------------

   procedure GG_Write_Subprogram_Info (SI : Subprogram_Phase_1_Info) is
      procedure Process_Volatiles (S : Name_Set.Set);
      --  Goes through S, finds volatiles and saves them on the appropriate
      --  sets based on their properties.

      ------------------------
      -- Processs_Volatiles --
      ------------------------

      procedure Process_Volatiles (S : Name_Set.Set) is
         E : Entity_Id;
         F : Flow_Id;
      begin
         for Name of S loop
            E := Find_Entity (Name);

            if Present (E) then
               F := Direct_Mapping_Id (E);

               if Is_Volatile (F) then
                  All_Volatile_Vars.Include (Name);

                  if Has_Async_Readers (F) then
                     --  Add to Async_Readers_Vars set
                     Async_Readers_Vars.Include (Name);
                  end if;

                  if Has_Async_Writers (F) then
                     --  Add to Async_Writers_Vars set
                     Async_Writers_Vars.Include (Name);
                  end if;

                  if Has_Effective_Writes (F) then
                     --  Add to Effective_Writes_Vars set
                     Effective_Writes_Vars.Include (Name);
                  end if;

                  if Has_Effective_Reads (F) then
                     --  Add to Effective_Reads_Vars set
                     Effective_Reads_Vars.Include (Name);
                  end if;
               end if;
            end if;
         end loop;
      end Process_Volatiles;

   begin
      Info_Set.Insert (SI);

      --  Gather and save volatile variables
      Process_Volatiles (SI.Inputs_Proof);
      Process_Volatiles (SI.Inputs);
      Process_Volatiles (SI.Outputs);
      Process_Volatiles (SI.Local_Variables);
   end GG_Write_Subprogram_Info;

   -----------------------
   -- GG_Write_Finalize --
   -----------------------

   procedure GG_Write_Finalize is
      procedure Write_Name_Set (S : Name_Set.Set);

      --------------------
      -- Write_Name_Set --
      --------------------

      procedure Write_Name_Set (S : Name_Set.Set)
      is
      begin
         for N of S loop
            Write_Info_Char (' ');
            Write_Info_Str (N.S.all);
         end loop;
      end Write_Name_Set;
   begin
      --  Write State info
      for State_Info of State_Info_Set loop
         Write_Info_Str ("GG AS ");
         Write_Info_Str (State_Info.State.S.all);
         Write_Name_Set (State_Info.Constituents);
         Write_Info_Terminate;
      end loop;

      --  Write Subprogram/Task/Entry info
      for Info of Info_Set loop
         case Info.Kind is
            when S_Kind =>
               Write_Info_Str ("GG S ");
            when T_Kind =>
               Write_Info_Str ("GG T ");
            when E_Kind =>
               Write_Info_Str ("GG E ");
            when others =>
               raise Program_Error;
         end case;

         case Info.Globals_Origin is
            when UG =>
               Write_Info_Str ("UG ");
            when FA =>
               Write_Info_Str ("FA ");
            when XR =>
               Write_Info_Str ("XR ");
            when others =>
               raise Program_Error;
         end case;
         Write_Info_Str (Info.Name.S.all);
         Write_Info_Terminate;

         Write_Info_Str ("GG VP");
         Write_Name_Set (Info.Inputs_Proof);
         Write_Info_Terminate;

         Write_Info_Str ("GG VI");
         Write_Name_Set (Info.Inputs);
         Write_Info_Terminate;

         Write_Info_Str ("GG VO");
         Write_Name_Set (Info.Outputs);
         Write_Info_Terminate;

         Write_Info_Str ("GG CP");
         Write_Name_Set (Info.Proof_Calls);
         Write_Info_Terminate;

         Write_Info_Str ("GG CD");
         Write_Name_Set (Info.Definite_Calls);
         Write_Info_Terminate;

         Write_Info_Str ("GG CC");
         Write_Name_Set (Info.Conditional_Calls);
         Write_Info_Terminate;

         Write_Info_Str ("GG LV");
         Write_Name_Set (Info.Local_Variables);
         Write_Info_Terminate;

         Write_Info_Str ("GG LS");
         Write_Name_Set (Info.Local_Subprograms);
         Write_Info_Terminate;
      end loop;

      --  Write Volatile info

      --  Write Async_Writers
      if not Async_Writers_Vars.Is_Empty then
         Write_Info_Str ("GG AW");
         Write_Name_Set (Async_Writers_Vars);
         Write_Info_Terminate;
      end if;

      --  Write Async_Readers
      if not Async_Readers_Vars.Is_Empty then
         Write_Info_Str ("GG AR");
         Write_Name_Set (Async_Readers_Vars);
         Write_Info_Terminate;
      end if;

      --  Write Effective_Reads
      if not Effective_Reads_Vars.Is_Empty then
         Write_Info_Str ("GG ER");
         Write_Name_Set (Effective_Reads_Vars);
         Write_Info_Terminate;
      end if;

      --  Write Effective_Writes
      if not Effective_Writes_Vars.Is_Empty then
         Write_Info_Str ("GG EW");
         Write_Name_Set (Effective_Writes_Vars);
         Write_Info_Terminate;
      end if;

      Close_Output_Library_Info;
      Current_Mode := GG_No_Mode;
   end GG_Write_Finalize;

   -------------
   -- GG_Read --
   -------------

   procedure GG_Read (GNAT_Root : Node_Id) is
      All_Globals           : Name_Set.Set := Name_Set.Empty_Set;
      --  Contains all global variables

      GG_Subprograms        : Name_Set.Set := Name_Set.Empty_Set;
      --  Contains all subprograms for which a GG entry exists

      All_Subprograms       : Name_Set.Set := Name_Set.Empty_Set;
      --  Contains all subprograms that we know of, even if a
      --  GG entry does not exist for them.

      All_Other_Subprograms : Name_Set.Set := Name_Set.Empty_Set;
      --  Contains all subprograms for which a GG entry does not
      --  exist.

      procedure Add_All_Edges;
      --  Reads the populated Info_Set and generates all the edges of
      --  the Global_Graph.

      procedure Create_All_Vertices;
      --  Creates all the vertices of the Global_Graph

      procedure Edit_Proof_Ins;
      --  A variable cannot be simultaneously a Proof_In and an Input
      --  of a subprogram. In this case we need to remove the Proof_In
      --  edge. Furthermore, a variable cannot be simultaneously a
      --  Proof_In and an Output (but not an input). In this case we
      --  need to change the Proof_In variable into an Input.

      procedure Load_GG_Info_From_ALI (ALI_File_Name : File_Name_Type);
      --  Loads the GG info from an ALI file and stores them in the
      --  Info_Set, State_Info_Set and volatile info sets.
      --
      --  The info that we read look as follows:
      --
      --  GG AS test__state test__g
      --  GG S FA test__proc
      --  GG VP test__proof_var
      --  GG VI test__g test__g2
      --  GG VO test__g
      --  GG CP test__ghost_func_a test__ghost_func_b
      --  GG CD test__proc_2 test__proc__nested_proc
      --  GG CC test__proc_3
      --  GG LV test__proc__nested_proc__v
      --  GG LS test__proc__nested_proc
      --  GG AW test__fully_vol test__vol_er2 test__ext_state
      --  GG AR test__fully_vol test__vol_ew3
      --  GG ER test__fully_vol test__vol_er2
      --  GG EW test__fully_vol test__vol_ew3

      procedure Remove_Edges_To_Local_Variables;
      --  Removes edges between subprograms and their local variables

      procedure Remove_Constants_Without_Variable_Input;
      --  Removes edges leading to constants without variable input

      -------------------
      -- Add_All_Edges --
      -------------------

      procedure Add_All_Edges is
         G_Ins, G_Outs, G_Proof_Ins : Global_Id;

         procedure Add_Edge (G1, G2 : Global_Id);
         --  Adds an edge between the vertices V1 and V2 that
         --  correspond to G1 and G2 (V1 --> V2). The edge has the
         --  default colour.

         --------------
         -- Add_Edge --
         --------------

         procedure Add_Edge (G1, G2 : Global_Id) is
         begin
            Global_Graph.Add_Edge (G1, G2, EC_Default);
         end Add_Edge;

      --  Start of Add_All_Edges

      begin
         --  Go through everything in Info_Set and add edges
         for Info of Info_Set loop
            G_Ins       := Global_Id'(Kind => Ins_Kind,
                                      Name => Info.Name);

            G_Outs      := Global_Id'(Kind => Outs_Kind,
                                      Name => Info.Name);

            G_Proof_Ins := Global_Id'(Kind => Proof_Ins_Kind,
                                      Name => Info.Name);

            --  Connecting the subprogram's Proof_In variables to the
            --  subprogram's Proof_Ins vertex.
            for Input_Proof of Info.Inputs_Proof loop
               Add_Edge (G_Proof_Ins,
                         Global_Id'(Kind => Variable_Kind,
                                    Name => Input_Proof));
            end loop;

            --  Connecting the subprogram's Input variables to the
            --  subprogram's Ins vertex.
            for Input of Info.Inputs loop
               Add_Edge (G_Ins,
                         Global_Id'(Kind => Variable_Kind,
                                    Name => Input));
            end loop;

            --  Connecting the subprogram's Output variables to the
            --  subprogram's Outputs vertex.
            for Output of Info.Outputs loop
               Add_Edge (G_Outs,
                         Global_Id'(Kind => Variable_Kind,
                                    Name => Output));
            end loop;

            --  Connecting the subprogram's Proof_Ins vertex to the
            --  callee's Ins and Proof_Ins vertices.
            for Proof_Call of Info.Proof_Calls loop
               Add_Edge (G_Proof_Ins,
                         Global_Id'(Kind => Proof_Ins_Kind,
                                    Name => Proof_Call));

               Add_Edge (G_Proof_Ins,
                         Global_Id'(Kind => Ins_Kind,
                                    Name => Proof_Call));
            end loop;

            --  Connecting the subprogram's Proof_Ins, Ins and Outs
            --  vertices respectively to the callee's Proof_Ins, Ins
            --  and Outs vertices.
            for Definite_Call of Info.Definite_Calls loop
               Add_Edge (G_Proof_Ins,
                         Global_Id'(Kind => Proof_Ins_Kind,
                                    Name => Definite_Call));

               Add_Edge (G_Ins,
                         Global_Id'(Kind => Ins_Kind,
                                    Name => Definite_Call));

               Add_Edge (G_Outs,
                         Global_Id'(Kind => Outs_Kind,
                                    Name => Definite_Call));
            end loop;

            --  As above but we also add an edge from the subprogram's
            --  Ins vertex to the callee's Outs vertex.
            for Conditional_Call of Info.Conditional_Calls loop
               Add_Edge (G_Proof_Ins,
                         Global_Id'(Kind => Proof_Ins_Kind,
                                    Name => Conditional_Call));

               Add_Edge (G_Ins,
                         Global_Id'(Kind => Ins_Kind,
                                    Name => Conditional_Call));

               Add_Edge (G_Ins,
                         Global_Id'(Kind => Outs_Kind,
                                    Name => Conditional_Call));

               Add_Edge (G_Outs,
                         Global_Id'(Kind => Outs_Kind,
                                    Name => Conditional_Call));
            end loop;
         end loop;

         --  Add edges between subprograms and variables coming from
         --  the Get_Globals function.
         for N of All_Other_Subprograms loop
            declare
               Subprogram   : constant Entity_Id := Find_Entity (N);
               G_Proof_Ins  : Global_Id;
               G_Ins        : Global_Id;
               G_Outs       : Global_Id;
               FS_Proof_Ins : Flow_Id_Sets.Set;
               FS_Reads     : Flow_Id_Sets.Set;
               FS_Writes    : Flow_Id_Sets.Set;

               procedure Add_Edges_For_FS
                 (FS   : Flow_Id_Sets.Set;
                  From : Global_Id);
               --  Adds an edge from From to every Flow_Id in FS

               ----------------------
               -- Add_Edges_For_FS --
               ----------------------

               procedure Add_Edges_For_FS
                 (FS   : Flow_Id_Sets.Set;
                  From : Global_Id)
               is
                  G   : Global_Id;
                  Nam : Entity_Name;
               begin
                  for F of FS loop
                     Nam := (if F.Kind in Direct_Mapping |
                                          Record_Field
                             then
                                To_Entity_Name (Get_Direct_Mapping_Id (F))
                             elsif F.Kind = Magic_String then
                                F.Name
                             else
                                raise Program_Error);
                     G   := Global_Id'(Kind => Variable_Kind,
                                       Name => Nam);

                     if not Global_Graph.Edge_Exists (From, G) then
                        Add_Edge (From, G);
                     end if;
                  end loop;
               end Add_Edges_For_FS;

            begin
               G_Proof_Ins := Global_Id'(Kind => Proof_Ins_Kind,
                                         Name => N);

               G_Ins       := Global_Id'(Kind => Ins_Kind,
                                         Name => N);

               G_Outs      := Global_Id'(Kind => Outs_Kind,
                                         Name => N);

               if Subprogram /= Empty then
                  Get_Globals (Subprogram => Subprogram,
                               Scope      => Get_Flow_Scope (Subprogram),
                               Classwide  => False,
                               Proof_Ins  => FS_Proof_Ins,
                               Reads      => FS_Reads,
                               Writes     => FS_Writes);

                  Add_Edges_For_FS (FS_Proof_Ins, G_Proof_Ins);
                  Add_Edges_For_FS (FS_Reads, G_Ins);
                  Add_Edges_For_FS (FS_Writes, G_Outs);
               end if;
            end;
         end loop;

         --  Close graph
         Global_Graph.Close;
      end Add_All_Edges;

      -------------------------
      -- Create_All_Vertices --
      -------------------------

      procedure Create_All_Vertices is
      begin
         --  Create vertices for all global variables
         for N of All_Globals loop
            Global_Graph.Add_Vertex (Global_Id'(Kind => Variable_Kind,
                                                Name => N));
         end loop;

         --  Create Ins, Outs and Proof_Ins vertices for all subprograms
         for N of All_Subprograms loop
            declare
               G_Ins       : constant Global_Id :=
                 Global_Id'(Kind => Ins_Kind,
                            Name => N);

               G_Outs      : constant Global_Id :=
                 Global_Id'(Kind => Outs_Kind,
                            Name => N);

               G_Proof_Ins : constant Global_Id :=
                 Global_Id'(Kind => Proof_Ins_Kind,
                            Name => N);
            begin
               Global_Graph.Add_Vertex (G_Ins);
               Global_Graph.Add_Vertex (G_Outs);
               Global_Graph.Add_Vertex (G_Proof_Ins);
            end;
         end loop;

         --  Lastly, create vertices for variables that come from the
         --  Get_Globals function.
         for N of All_Other_Subprograms loop
            declare
               Subprogram   : constant Entity_Id := Find_Entity (N);
               FS_Proof_Ins : Flow_Id_Sets.Set;
               FS_Reads     : Flow_Id_Sets.Set;
               FS_Writes    : Flow_Id_Sets.Set;

               procedure Create_Vertices_For_FS (FS : Flow_Id_Sets.Set);
               --  Creates a vertex for every Flow_Id in FS that
               --  does not already have one.

               ----------------------------
               -- Create_Vertices_For_FS --
               ----------------------------

               procedure Create_Vertices_For_FS (FS : Flow_Id_Sets.Set) is
                  G   : Global_Id;
                  Nam : Entity_Name;
               begin
                  for F of FS loop
                     Nam := (if F.Kind in Direct_Mapping | Record_Field then
                                To_Entity_Name (Get_Direct_Mapping_Id (F))
                             elsif F.Kind = Magic_String then
                                F.Name
                             else
                                raise Program_Error);
                     G   := Global_Id'(Kind => Variable_Kind,
                                       Name => Nam);

                     if Global_Graph.Get_Vertex (G) = Null_Vertex then
                        Global_Graph.Add_Vertex (G);
                     end if;
                  end loop;
               end Create_Vertices_For_FS;

            begin
               if Subprogram /= Empty then
                  Get_Globals (Subprogram => Subprogram,
                               Scope      => Get_Flow_Scope (Subprogram),
                               Classwide  => False,
                               Proof_Ins  => FS_Proof_Ins,
                               Reads      => FS_Reads,
                               Writes     => FS_Writes);

                  Create_Vertices_For_FS (FS_Proof_Ins);
                  Create_Vertices_For_FS (FS_Reads);
                  Create_Vertices_For_FS (FS_Writes);
               end if;
            end;
         end loop;
      end Create_All_Vertices;

      --------------------
      -- Edit_Proof_Ins --
      --------------------

      procedure Edit_Proof_Ins is
         function Get_Variable_Neighbours
           (Start : Vertex_Id)
            return Vertex_Sets.Set;
         --  Returns a set of all Neighbours of Start that correspond
         --  to variables.

         function Get_Variable_Neighbours
           (Start : Vertex_Id)
            return Vertex_Sets.Set
         is
            VS : Vertex_Sets.Set := Vertex_Sets.Empty_Set;
         begin
            for V of Global_Graph.Get_Collection (Start,
                                                  Out_Neighbours)
            loop
               if Global_Graph.Get_Key (V).Kind = Variable_Kind then
                  VS.Include (V);
               end if;
            end loop;

            return VS;
         end Get_Variable_Neighbours;
      begin
         for Info of Info_Set loop
            declare
               G_Ins       : constant Global_Id :=
                 Global_Id'(Kind => Ins_Kind,
                            Name => Info.Name);

               G_Outs      : constant Global_Id :=
                 Global_Id'(Kind => Outs_Kind,
                            Name => Info.Name);

               G_Proof_Ins : constant Global_Id :=
                 Global_Id'(Kind => Proof_Ins_Kind,
                            Name => Info.Name);

               V_Ins       : constant Vertex_Id :=
                 Global_Graph.Get_Vertex (G_Ins);

               V_Outs      : constant Vertex_Id :=
                 Global_Graph.Get_Vertex (G_Outs);

               V_Proof_Ins : constant Vertex_Id :=
                 Global_Graph.Get_Vertex (G_Proof_Ins);

               Inputs      : constant Vertex_Sets.Set :=
                 Get_Variable_Neighbours (V_Ins);

               Outputs     : constant Vertex_Sets.Set :=
                 Get_Variable_Neighbours (V_Outs);

               Proof_Ins   : constant Vertex_Sets.Set :=
                 Get_Variable_Neighbours (V_Proof_Ins);
            begin
               for V of Proof_Ins loop
                  if Inputs.Contains (V)
                    or else Outputs.Contains (V)
                  then
                     if not Global_Graph.Edge_Exists (V_Ins, V) then
                        Global_Graph.Add_Edge (V_Ins, V, EC_Default);
                     end if;

                     Global_Graph.Remove_Edge (V_Proof_Ins, V);
                  end if;
               end loop;
            end;
         end loop;
      end Edit_Proof_Ins;

      ---------------------------
      -- Load_GG_Info_From_ALI --
      ---------------------------

      procedure Load_GG_Info_From_ALI (ALI_File_Name : File_Name_Type) is
         ALI_File_Name_Str   : constant String :=
           Name_String (Name_Id (Full_Lib_File_Name (ALI_File_Name)));

         ALI_File            : Ada.Text_IO.File_Type;
         Line                : Unbounded_String;

         AR_Found            : Boolean := False;
         AW_Found            : Boolean := False;
         EW_Found            : Boolean := False;
         ER_Found            : Boolean := False;

         procedure Parse_Record;
         --  Parses a GG record from the ALI file and if no problems
         --  occurred it adds it to the relevant set.

         ------------------
         -- Parse_Record --
         ------------------

         procedure Parse_Record is
            type Line_Found_T is array (1 .. 9) of Boolean;
            --  This array represents whether we have found a line
            --  of the following format while populating the record.
            --  The order is as follow:
            --
            --  array slot 1 is True if we have found "GG S/T *"
            --  array slot 2 is True if we have found "GG VP *"
            --  array slot 3 is True if we have found "GG VI *"
            --  array slot 4 is True if we have found "GG VO *"
            --  array slot 5 is True if we have found "GG CP *"
            --  array slot 6 is True if we have found "GG CD *"
            --  array slot 7 is True if we have found "GG CC *"
            --  array slot 8 is True if we have found "GG LV *"
            --  array slot 9 is True if we have found "GG LS *"

            Line_Found : Line_Found_T := Line_Found_T'(others => False);
            --  Initially we haven't found anything

            New_Info   : Subprogram_Phase_1_Info;

            procedure Check_GG_Format;
            --  Checks if the line start with "GG "

            function Get_Names_From_Line return Name_Set.Set;
            --  Returns a set of all names appearing in a line

            ---------------------
            -- Check_GG_Format --
            ---------------------

            procedure Check_GG_Format is
            begin
               if Length (Line) <= 3 or else
                 Slice (Line, 1, 3) /= "GG "
               then
                  --  Either the ALI file has been tampered with
                  --  or we are dealing with a new kind of line
                  --  that we are not aware of.
                  raise Program_Error;
               end if;
            end Check_GG_Format;

            -------------------------
            -- Get_Names_From_Line --
            -------------------------

            function Get_Names_From_Line return Name_Set.Set is
               Names_In_Line : Name_Set.Set := Name_Set.Empty_Set;
               Start_Of_Word : Natural      := 7;
               End_Of_Word   : Natural;
            begin
               if Length (Line) = 5 then
                  --  There are no names here. Return the empty set.
                  return Names_In_Line;
               end if;

               while Start_Of_Word < Length (Line) loop
                  End_Of_Word := Start_Of_Word;

                  while End_Of_Word < Length (Line)
                    and then Element (Line, End_Of_Word) > ' '
                  loop
                     End_Of_Word := End_Of_Word + 1;
                  end loop;

                  --  If we have not reached the end of the line then
                  --  we have read one character too many.
                  if End_Of_Word < Length (Line) then
                     End_Of_Word := End_Of_Word - 1;
                  end if;

                  declare
                     EN : constant Entity_Name :=
                       To_Entity_Name (Slice (Line,
                                              Start_Of_Word,
                                              End_Of_Word));
                  begin
                     Names_In_Line.Insert (EN);
                  end;

                  Start_Of_Word := End_Of_Word + 2;
               end loop;

               return Names_In_Line;
            end Get_Names_From_Line;

         --  Start of Parse_Record

         begin
            --  We special case lines that contain info about state
            --  abstractions.
            if Length (Line) > 6
              and then Slice (Line, 1, 6) = "GG AS "
            then
               declare
                  State         : Entity_Name;
                  Constituents  : Name_Set.Set := Get_Names_From_Line;
                  Start_Of_Word : constant Natural := 7;
                  End_Of_Word   : Natural := 7;
               begin
                  while End_Of_Word < Length (Line)
                    and then Element (Line, End_Of_Word) > ' '
                  loop
                     End_Of_Word := End_Of_Word + 1;
                  end loop;

                  --  If we have not reached the end of the line then
                  --  we have read one character too many.
                  if End_Of_Word < Length (Line) then
                     End_Of_Word := End_Of_Word - 1;
                  end if;

                  State := To_Entity_Name (Slice (Line,
                                                  Start_Of_Word,
                                                  End_Of_Word));

                  Constituents.Exclude (State);

                  State_Info_Set.Include
                    (State_Phase_1_Info'(State        => State,
                                         Constituents => Constituents));
               end;

               --  State line parsed. We will now return.
               return;

            --  We special case lines that contain info about volatile
            --  variables and external state abstractions.

            elsif Length (Line) > 6
              and then Slice (Line, 1, 6) in "GG AW " |
                                             "GG AR " |
                                             "GG ER " |
                                             "GG EW "
            then
               if Slice (Line, 1, 6) = "GG AW " then
                  if AW_Found then
                     raise Program_Error;
                  end if;

                  --  Found AW
                  AW_Found := True;
                  --  Read and save AW line
                  Async_Writers_Vars.Union (Get_Names_From_Line);

               elsif Slice (Line, 1, 6) = "GG AR " then
                  if AR_Found then
                     raise Program_Error;
                  end if;

                  --  Found AR
                  AR_Found := True;
                  --  Read and save AR line
                  Async_Readers_Vars.Union (Get_Names_From_Line);

               elsif Slice (Line, 1, 6) = "GG ER " then
                  if ER_Found then
                     raise Program_Error;
                  end if;

                  --  Found ER
                  ER_Found := True;
                  --  Read and save ER line
                  Effective_Reads_Vars.Union (Get_Names_From_Line);

               elsif Slice (Line, 1, 6) = "GG EW " then
                  if EW_Found then
                     raise Program_Error;
                  end if;

                  --  Found EW
                  EW_Found := True;
                  --  Read and save EW line
                  Effective_Writes_Vars.Union (Get_Names_From_Line);

               else
                  --  We should never get here
                  raise Program_Error;
               end if;

               --  Save all names from the line in the All_Volatile_Vars
               --  set and return.
               All_Volatile_Vars.Union (Get_Names_From_Line);
               return;
            end if;

            while (for some I in 1 .. 9 => not Line_Found (I)) loop
               Check_GG_Format;

               if Length (Line) >= 6
                 and then (Slice (Line, 4, 5) in "S " | "T " | "E ")
               then
                  --  Line format: GG S *
                  --      or       GG T *
                  --      or       GG E *
                  if Line_Found (1) then
                     --  We have already processed this line.
                     --  Something is wrong with the ali file.
                     raise Program_Error;
                  end if;

                  if Slice (Line, 4, 5) = "S " then
                     --  Reading back a subprogram
                     New_Info.Kind := S_Kind;
                  elsif Slice (Line, 4, 5) = "T " then
                     --  Reading back a task
                     New_Info.Kind := T_Kind;
                  elsif Slice (Line, 4, 5) = "E " then
                     --  Reading back an entry
                     New_Info.Kind := E_Kind;
                  else
                     raise Program_Error;
                  end if;

                  Line_Found (1) := True;

                  declare
                     GO : constant String := Slice (Line, 6, 7);

                     EN : constant Entity_Name :=
                       To_Entity_Name (Slice (Line, 9, Length (Line)));

                  begin
                     New_Info.Name := EN;
                     New_Info.Globals_Origin :=
                       (if GO = "UG" then UG
                        elsif GO = "FA" then FA
                        elsif GO = "XR" then XR
                        else raise Program_Error);
                     GG_Subprograms.Include (EN);
                     All_Subprograms.Include (EN);
                  end;

               elsif Length (Line) >= 5 then
                  if Slice (Line, 4, 5) = "VP" then
                     if Line_Found (2) then
                        raise Program_Error;
                     end if;

                     Line_Found (2) := True;
                     New_Info.Inputs_Proof := Get_Names_From_Line;
                     All_Globals.Union (Get_Names_From_Line);

                  elsif Slice (Line, 4, 5) = "VI" then
                     if Line_Found (3) then
                        raise Program_Error;
                     end if;

                     Line_Found (3) := True;
                     New_Info.Inputs := Get_Names_From_Line;
                     All_Globals.Union (Get_Names_From_Line);

                  elsif Slice (Line, 4, 5) = "VO" then
                     if Line_Found (4) then
                        raise Program_Error;
                     end if;

                     Line_Found (4) := True;
                     New_Info.Outputs := Get_Names_From_Line;
                     All_Globals.Union (Get_Names_From_Line);

                  elsif Slice (Line, 4, 5) = "CP" then
                     if Line_Found (5) then
                        raise Program_Error;
                     end if;

                     Line_Found (5) := True;
                     New_Info.Proof_Calls := Get_Names_From_Line;
                     All_Subprograms.Union (New_Info.Proof_Calls);

                  elsif Slice (Line, 4, 5) = "CD" then
                     if Line_Found (6) then
                        raise Program_Error;
                     end if;

                     Line_Found (6) := True;
                     New_Info.Definite_Calls := Get_Names_From_Line;
                     All_Subprograms.Union (New_Info.Definite_Calls);

                  elsif Slice (Line, 4, 5) = "CC" then
                     if Line_Found (7) then
                        raise Program_Error;
                     end if;

                     Line_Found (7) := True;
                     New_Info.Conditional_Calls := Get_Names_From_Line;
                     All_Subprograms.Union (New_Info.Conditional_Calls);

                  elsif Slice (Line, 4, 5) = "LV" then
                     if Line_Found (8) then
                        raise Program_Error;
                     end if;

                     Line_Found (8) := True;
                     New_Info.Local_Variables := Get_Names_From_Line;
                     All_Globals.Union (Get_Names_From_Line);

                  elsif Slice (Line, 4, 5) = "LS" then
                     if Line_Found (9) then
                        raise Program_Error;
                     end if;

                     Line_Found (9) := True;
                     New_Info.Local_Subprograms := Get_Names_From_Line;
                     All_Subprograms.Union (New_Info.Local_Subprograms);

                  else
                     --  Unexpected type of line. Something is wrong
                     --  with the ALI file.
                     raise Program_Error;
                  end if;

               else
                  --  Something is wrong with the ALI file
                  raise Program_Error;
               end if;

               if not End_Of_File (ALI_File)
                 and then (for some I in 1 .. 9 => not Line_Found (I))
               then
                  --  Go to the next line
                  Get_Line (ALI_File, Line);
               elsif End_Of_File (ALI_File)
                 and then (for some I in 1 .. 9 => not Line_Found (I))
               then
                  --  We reached the end of the file and our New_Info
                  --  is not yet complete. Something is missing from
                  --  the ALI file.
                  raise Program_Error;
               end if;

               if (for all I in 1 .. 9 => Line_Found (I)) then
                  --  If all lines have been found then we add New_Info to
                  --  Info_Set and return.
                  Info_Set.Include (New_Info);
                  return;
               end if;

            end loop;

            --  We should never reach here
            raise Program_Error;

         end Parse_Record;

      --  Start of Load_GG_Info_From_ALI

      begin
         Open (ALI_File, In_File, ALI_File_Name_Str);

         loop
            if End_Of_File (ALI_File) then
               Close (ALI_File);
               return;
            end if;

            Get_Line (ALI_File, Line);

            --  Check if now reached the "GG" section
            if Length (Line) >= 3 and then Slice (Line, 1, 3) = "GG " then
               exit;
            end if;
         end loop;

         --  We have now reached the "GG" section of the ALI file
         Parse_Record;
         while not End_Of_File (ALI_File) loop
            Get_Line (ALI_File, Line);
            Parse_Record;
         end loop;

         Close (ALI_File);
      end Load_GG_Info_From_ALI;

      -------------------------------------
      -- Remove_Edges_To_Local_Variables --
      -------------------------------------

      procedure Remove_Edges_To_Local_Variables is

         procedure Remove_Local_Variables_From_Set
           (Start : Vertex_Id;
            Info  : Subprogram_Phase_1_Info);
         --  Removes all edges starting from Start and leading to:
         --    * this subprogram's local variables,
         --    * local variables of called subprograms that do not
         --      enclose this subprogram

         -------------------------------------
         -- Remove_Local_Variables_From_Set --
         -------------------------------------

         procedure Remove_Local_Variables_From_Set
           (Start : Vertex_Id;
            Info  : Subprogram_Phase_1_Info)
         is
            G                   : Global_Id;
            VS                  : Vertex_Sets.Set := Vertex_Sets.Empty_Set;
            All_Subs_Called     : Name_Set.Set    := Name_Set.Empty_Set;
            All_Local_Variables : Name_Set.Set    := Info.Local_Variables;
         begin
            for V of Global_Graph.Get_Collection (Start, Out_Neighbours) loop
               if Global_Graph.Get_Key (V).Kind in Proof_Ins_Kind |
                                                   Ins_Kind       |
                                                   Outs_Kind
               then
                  All_Subs_Called.Include (Global_Graph.Get_Key (V).Name);
               end if;
            end loop;

            for Sub_Called of All_Subs_Called loop
               if GG_Subprograms.Contains (Sub_Called) then
                  for I of Info_Set loop
                     if I.Name = Sub_Called then
                        if not I.Local_Subprograms.Contains (Info.Name)
                        then
                           All_Local_Variables.Union (I.Local_Variables);
                        end if;
                        exit;
                     end if;
                  end loop;
               end if;
            end loop;

            for V of Global_Graph.Get_Collection (Start, Out_Neighbours) loop
               G := Global_Graph.Get_Key (V);

               if All_Local_Variables.Contains (G.Name) then
                  VS.Include (V);
               end if;
            end loop;

            for V of VS loop
               Global_Graph.Remove_Edge (Start, V);
            end loop;
         end Remove_Local_Variables_From_Set;

      --  Start of Remove_Edges_From_Local_Variables

      begin
         for Info of Info_Set loop
            declare
               G_Ins       : constant Global_Id :=
                 Global_Id'(Kind => Ins_Kind,
                            Name => Info.Name);

               G_Outs      : constant Global_Id :=
                 Global_Id'(Kind => Outs_Kind,
                            Name => Info.Name);

               G_Proof_Ins : constant Global_Id :=
                 Global_Id'(Kind => Proof_Ins_Kind,
                            Name => Info.Name);

               V_Ins       : constant Vertex_Id :=
                 Global_Graph.Get_Vertex (G_Ins);

               V_Outs      : constant Vertex_Id :=
                 Global_Graph.Get_Vertex (G_Outs);

               V_Proof_Ins : constant Vertex_Id :=
                 Global_Graph.Get_Vertex (G_Proof_Ins);
            begin
               Remove_Local_Variables_From_Set (V_Ins, Info);
               Remove_Local_Variables_From_Set (V_Outs, Info);
               Remove_Local_Variables_From_Set (V_Proof_Ins, Info);
            end;
         end loop;
      end Remove_Edges_To_Local_Variables;

      ---------------------------------------------
      -- Remove_Constants_Without_Variable_Input --
      ---------------------------------------------

      procedure Remove_Constants_Without_Variable_Input is
         All_Constants : Name_Set.Set  := Name_Set.Empty_Set;
      begin
         --  Gather up all constants without variable input
         for Glob of All_Globals loop
            declare
               Const : constant Entity_Id := Find_Entity (Glob);
            begin
               if Const /= Empty
                 and then Ekind (Const) = E_Constant
                 and then not Has_Variable_Input (Direct_Mapping_Id (Const))
               then
                  All_Constants.Include (Glob);
               end if;
            end;
         end loop;

         --  Remove all edges going in and out of a constant without
         --  variable input.
         for Const of All_Constants loop
            declare
               Const_G_Id : constant Global_Id :=
                 Global_Id'(Kind => Variable_Kind,
                            Name => Const);

               Const_V    : constant Vertex_Id :=
                 Global_Graph.Get_Vertex (Const_G_Id);
            begin
               Global_Graph.Clear_Vertex (Const_V);
            end;
         end loop;
      end Remove_Constants_Without_Variable_Input;

   --  Start of GG_Read

   begin
      Current_Mode := GG_Read_Mode;

      --  Initialize volatile info
      All_Volatile_Vars     := Name_Set.Empty_Set;
      Async_Writers_Vars    := Name_Set.Empty_Set;
      Async_Readers_Vars    := Name_Set.Empty_Set;
      Effective_Reads_Vars  := Name_Set.Empty_Set;
      Effective_Writes_Vars := Name_Set.Empty_Set;

      --  Go through all ALI files and populate the Info_Set
      for Index in ALIs.First .. ALIs.Last loop
         Load_GG_Info_From_ALI (ALIs.Table (Index).Afile);
      end loop;

      if Debug_Print_Info_Sets_Read then
         --  Print all GG related info gathered from the ALI files.
         for Info of Info_Set loop
            Write_Eol;
            Print_Subprogram_Phase_1_Info (Info);
         end loop;

         for State_Info of State_Info_Set loop
            Write_Eol;
            Write_Line ("Abstract state " & State_Info.State.S.all);

            Write_Line ("Constituents     :");
            for Name of State_Info.Constituents loop
               Write_Line ("   " & Name.S.all);
            end loop;
         end loop;

         --  Print all volatile info
         Write_Eol;

         Write_Line ("Async_Writers    :");
         for Name of Async_Writers_Vars loop
            Write_Line ("   " & Name.S.all);
         end loop;

         Write_Line ("Async_Readers    :");
         for Name of Async_Readers_Vars loop
            Write_Line ("   " & Name.S.all);
         end loop;

         Write_Line ("Effective_Reads  :");
         for Name of Effective_Reads_Vars loop
            Write_Line ("   " & Name.S.all);
         end loop;

         Write_Line ("Effective_Writes :");
         for Name of Effective_Writes_Vars loop
            Write_Line ("   " & Name.S.all);
         end loop;
      end if;

      --  Populated the All_Other_Subprograms set
      All_Other_Subprograms := All_Subprograms - GG_Subprograms;

      --  Initialize Global_Graph
      Global_Graph := Global_Graphs.Create;

      --  Create all vertices of the Global_Graph
      Create_All_Vertices;

      --  Add all edges in the Global_Graph
      Add_All_Edges;

      --  Remove edges between a subprogram and its local variables
      Remove_Edges_To_Local_Variables;

      --  Edit Proof_Ins
      Edit_Proof_Ins;

      --  Now that the Globals Graph has been generated we set
      --  GG_Generated to True. Notice that we set GG_Generated to
      --  True before we remove edges leading to constants without
      --  variable input. The reasoning behind this is to use the
      --  generated globals instead of the computed globals when we
      --  call Get_Globals from within Has_Variable_Input.
      GG_Generated := True;

      --  Remove edges leading to constants which do not have variable
      --  input.
      Remove_Constants_Without_Variable_Input;

      if Debug_Print_Global_Graph then
         declare
            Filename : constant String :=
              Spec_File_Name_Without_Suffix
                (Enclosing_Comp_Unit_Node (GNAT_Root)) & "_Globals_Graph";
         begin
            Print_Global_Graph (Filename => Filename,
                                G        => Global_Graph);
         end;
      end if;

   end GG_Read;

   --------------
   -- GG_Exist --
   --------------

   function GG_Exist (E : Entity_Id) return Boolean is
      Name : constant Entity_Name := To_Entity_Name (E);
   begin
      return (for some Info of Info_Set => Name.Id = Info.Name.Id);
   end GG_Exist;

   -----------------------
   -- GG_Has_Refinement --
   -----------------------

   function GG_Has_Refinement (EN : Entity_Name) return Boolean is
   begin
      return (for some S of State_Info_Set => S.State.Id = EN.Id);
   end GG_Has_Refinement;

   -----------------------
   -- GG_Is_Constituent --
   -----------------------

   function GG_Is_Constituent (EN : Entity_Name) return Boolean is
   begin
      return (for some S of State_Info_Set =>
                (for some C of S.Constituents => EN.Id = C.Id));
   end GG_Is_Constituent;

   -------------------------
   -- GG_Get_Constituents --
   -------------------------

   function GG_Get_Constituents (EN : Entity_Name) return Name_Set.Set is
   begin
      for S of State_Info_Set loop
         if S.State.Id = EN.Id then
            return S.Constituents;
         end if;
      end loop;

      return Name_Set.Empty_Set;
   end GG_Get_Constituents;

   ------------------------
   -- GG_Enclosing_State --
   ------------------------

   function GG_Enclosing_State (EN : Entity_Name) return Entity_Name is
   begin
      for S of State_Info_Set loop
         for C of S.Constituents loop
            if EN.Id = C.Id then
               return S.State;
            end if;
         end loop;
      end loop;

      return Null_Entity_Name;
   end GG_Enclosing_State;

   ---------------------
   -- GG_Fully_Refine --
   ---------------------

   function GG_Fully_Refine (EN : Entity_Name) return Name_Set.Set is
      NS       : Name_Set.Set;
      Tmp_Name : Entity_Name;
   begin
      NS := GG_Get_Constituents (EN);

      while (for some S of NS => GG_Has_Refinement (S)) loop
         Tmp_Name := Null_Entity_Name;
         for S of NS loop
            if GG_Has_Refinement (S) then
               Tmp_Name := S;
               exit;
            end if;
         end loop;

         if Tmp_Name /= Null_Entity_Name then
            NS.Union (GG_Get_Constituents (Tmp_Name));
            NS.Exclude (Tmp_Name);
         end if;
      end loop;

      return NS;
   end GG_Fully_Refine;

   --------------------
   -- GG_Get_Globals --
   --------------------

   procedure GG_Get_Globals (E           : Entity_Id;
                             S           : Flow_Scope;
                             Proof_Reads : out Flow_Id_Sets.Set;
                             Reads       : out Flow_Id_Sets.Set;
                             Writes      : out Flow_Id_Sets.Set)
   is
      MR_Proof_Reads  : Name_Set.Set := Name_Set.Empty_Set;
      MR_Reads        : Name_Set.Set := Name_Set.Empty_Set;
      MR_Writes       : Name_Set.Set := Name_Set.Empty_Set;
      --  The above 3 sets will contain the most refined views of
      --  their respective globals.

      Subprogram_Name : constant Entity_Name :=
        To_Entity_Name (E);
      --  Holds the Entity_Name of the subprogram

      G_Proof_Ins     : constant Global_Id :=
        Global_Id'(Kind => Proof_Ins_Kind,
                   Name => Subprogram_Name);
      G_Ins           : constant Global_Id :=
        Global_Id'(Kind => Ins_Kind,
                   Name => Subprogram_Name);
      G_Outs          : constant Global_Id :=
        Global_Id'(Kind => Outs_Kind,
                   Name => Subprogram_Name);
      --  The above 3 Global_Ids correspond to the subprogram's Ins,
      --  Outs and Proof_Ins.

      V_Proof_Ins     : constant Vertex_Id :=
        Global_Graph.Get_Vertex (G_Proof_Ins);
      V_Ins           : constant Vertex_Id :=
        Global_Graph.Get_Vertex (G_Ins);
      V_Outs          : constant Vertex_Id :=
        Global_Graph.Get_Vertex (G_Outs);
      --  The above 3 Vertex_Ids correspond to the subprogram's Ins,
      --  Outs and Proof_Ins.

      procedure Up_Project
        (Most_Refined      : Name_Set.Set;
         Final_View        : out Name_Set.Set;
         Processing_Writes : Boolean := False);
      --  Distinguishes between simple vars and constituents. For
      --  constituents, it checks if they are visible and if they are
      --  NOT we check if their enclosing state is. If the enclosing
      --  state is visible then return that (otherwise repeat the
      --  process). When Processing_Writes is set, we also check if
      --  all constituents are used and if they are not we need also
      --  add them on the Reads set.

      ----------------
      -- Up_Project --
      ----------------

      procedure Up_Project
        (Most_Refined      : Name_Set.Set;
         Final_View        : out Name_Set.Set;
         Processing_Writes : Boolean := False)
      is
         Abstract_States : Name_Set.Set := Name_Set.Empty_Set;
      begin
         --  Initializing Final_View to empty
         Final_View := Name_Set.Empty_Set;

         for N of Most_Refined loop
            if GG_Enclosing_State (N) /= Null_Entity_Name and then
              (Find_Entity (N) = Empty or else
                 not Is_Visible (Find_Entity (N), S))
            then
               declare
                  Var               : Entity_Name :=
                    (if Find_Entity (N) /= Empty
                       and then Is_Visible (Find_Entity (N), S)
                     then N
                     else GG_Enclosing_State (N));
                  ES                : Entity_Name := GG_Enclosing_State (N);
                  Is_Abstract_State : Boolean     := False;
               begin
                  while Find_Entity (ES) = Empty or else
                    not Is_Visible (Find_Entity (ES), S)
                  loop
                     Is_Abstract_State := True;
                     Var := ES;

                     if GG_Enclosing_State (ES) /= Null_Entity_Name then
                        ES := GG_Enclosing_State (ES);
                     else
                        --  We cannot go any further up and we still
                        --  do not have visibility of the variable or
                        --  state abstraction that we are making use
                        --  of. This means that the user has neglected
                        --  to provide some state abstraction and the
                        --  refinement thereof. Unfortunately, we
                        --  might now refer to a variable or state
                        --  that the caller should not have vision of.
                        exit;
                     end if;
                  end loop;

                  Final_View.Include (Var);

                  --  We add the enclosing abstract state that we just
                  --  added to the Final_View set to the
                  --  Abstract_States set.
                  if Is_Abstract_State then
                     Abstract_States.Include (Var);
                  end if;
               end;
            else
               --  Add variables that are directly visible or do not
               --  belong to any state abstraction to the Final_View
               --  set.
               Final_View.Include (N);
            end if;
         end loop;

         --  If we Write some but not all constituents of a state
         --  abstraction then this state abstraction is also a Read.
         if Processing_Writes then
            for AS of Abstract_States loop
               declare
                  Constituents : constant Name_Set.Set :=
                    GG_Fully_Refine (AS);
               begin
                  if not (for all C of Constituents =>
                            Most_Refined.Contains (C))
                  then
                     Reads.Include (Get_Flow_Id (AS, In_View, S));
                  end if;
               end;
            end loop;
         end if;
      end Up_Project;

   begin
      --  Initialize the Proof_Reads, Reads and Writes sets
      Proof_Reads := Flow_Id_Sets.Empty_Set;
      Reads       := Flow_Id_Sets.Empty_Set;
      Writes      := Flow_Id_Sets.Empty_Set;

      --  Calculate MR_Proof_Reads, MR_Reads and MR_Writes
      declare
         function Calculate_MR (Start : Vertex_Id) return Name_Set.Set;
         --  Returns a set of all vertices that can be reached from
         --  Start and are of the Variable_Kind.

         ------------------
         -- Calculate_MR --
         ------------------

         function Calculate_MR (Start : Vertex_Id) return Name_Set.Set is
            NS : Name_Set.Set := Name_Set.Empty_Set;
            G  : Global_Id;
         begin
            for V of Global_Graph.Get_Collection (Start, Out_Neighbours) loop
               G := Global_Graph.Get_Key (V);

               if G.Kind = Variable_Kind then
                  NS.Include (G.Name);
               end if;
            end loop;

            return NS;
         end Calculate_MR;

      begin
         MR_Proof_Reads := Calculate_MR (V_Proof_Ins);
         MR_Reads       := Calculate_MR (V_Ins);
         MR_Writes      := Calculate_MR (V_Outs);
      end;

      --  Up project variables based on scope S and give Flow_Ids
      --  their correct views.
      declare
         Temp_NS : Name_Set.Set;

         function To_Flow_Id_Set
           (NS   : Name_Set.Set;
            View : Parameter_Variant)
            return Flow_Id_Sets.Set;
         --  Takes a Name_Set and returns a set of Flow_Id_Set

         --------------------
         -- To_Flow_Id_Set --
         --------------------

         function To_Flow_Id_Set
           (NS   : Name_Set.Set;
            View : Parameter_Variant)
            return Flow_Id_Sets.Set
         is
            FS : Flow_Id_Sets.Set := Flow_Id_Sets.Empty_Set;
         begin
            for N of NS loop
               FS.Include (Get_Flow_Id (N, View, S));
            end loop;

            return FS;
         end To_Flow_Id_Set;

      begin
         Up_Project (Most_Refined => MR_Proof_Reads,
                     Final_View   => Temp_NS);
         Proof_Reads.Union (To_Flow_Id_Set (Temp_NS, In_View));

         Up_Project (Most_Refined => MR_Reads,
                     Final_View   => Temp_NS);
         Reads.Union (To_Flow_Id_Set (Temp_NS, In_View));

         Up_Project (Most_Refined      => MR_Writes,
                     Final_View        => Temp_NS,
                     Processing_Writes => True);
         Writes.Union (To_Flow_Id_Set (Temp_NS, Out_View));
      end;
   end GG_Get_Globals;

   ------------------------
   -- GG_Get_Proof_Reads --
   ------------------------

   function GG_Get_Proof_Reads
     (E : Entity_Id;
      S : Flow_Scope)
      return Flow_Id_Sets.Set
   is
      Proof_Reads, Reads, Writes : Flow_Id_Sets.Set;
   begin
      GG_Get_Globals (E,
                      S,
                      Proof_Reads,
                      Reads,
                      Writes);

      return Proof_Reads;
   end GG_Get_Proof_Reads;

   ------------------
   -- GG_Get_Reads --
   ------------------

   function GG_Get_Reads
     (E : Entity_Id;
      S : Flow_Scope)
      return Flow_Id_Sets.Set
   is
      Proof_Reads, Reads, Writes : Flow_Id_Sets.Set;
   begin
      GG_Get_Globals (E,
                      S,
                      Proof_Reads,
                      Reads,
                      Writes);

      return Reads;
   end GG_Get_Reads;

   ----------------------
   -- GG_Get_All_Reads --
   ----------------------

   function GG_Get_All_Reads
     (E : Entity_Id;
      S : Flow_Scope)
      return Flow_Id_Sets.Set
   is
   begin
      return GG_Get_Proof_Reads (E, S) or GG_Get_Reads (E, S);
   end GG_Get_All_Reads;

   -------------------
   -- GG_Get_Writes --
   -------------------

   function GG_Get_Writes
     (E : Entity_Id;
      S : Flow_Scope)
      return Flow_Id_Sets.Set
   is
      Proof_Reads, Reads, Writes : Flow_Id_Sets.Set;
   begin
      GG_Get_Globals (E,
                      S,
                      Proof_Reads,
                      Reads,
                      Writes);

      return Writes;
   end GG_Get_Writes;

   -----------------------------------
   -- GG_Get_All_State_Abstractions --
   -----------------------------------

   function GG_Get_All_State_Abstractions return Name_Set.Set is
      Tmp : Name_Set.Set := Name_Set.Empty_Set;
   begin
      for S of State_Info_Set loop
         Tmp.Include (S.State);
      end loop;

      return Tmp;
   end GG_Get_All_State_Abstractions;

   --------------------
   -- GG_Is_Volatile --
   --------------------

   function GG_Is_Volatile (EN : Entity_Name) return Boolean is
   begin
      return All_Volatile_Vars.Contains (EN);
   end GG_Is_Volatile;

   --------------------------
   -- GG_Has_Async_Writers --
   --------------------------

   function GG_Has_Async_Writers (EN : Entity_Name) return Boolean is
   begin
      return Async_Writers_Vars.Contains (EN);
   end GG_Has_Async_Writers;

   --------------------------
   -- GG_Has_Async_Readers --
   --------------------------

   function GG_Has_Async_Readers (EN : Entity_Name) return Boolean is
   begin
      return Async_Readers_Vars.Contains (EN);
   end GG_Has_Async_Readers;

   ----------------------------
   -- GG_Has_Effective_Reads --
   ----------------------------

   function GG_Has_Effective_Reads (EN : Entity_Name) return Boolean is
   begin
      return Effective_Reads_Vars.Contains (EN);
   end GG_Has_Effective_Reads;

   -----------------------------
   -- GG_Has_Effective_Writes --
   -----------------------------

   function GG_Has_Effective_Writes (EN : Entity_Name) return Boolean is
   begin
      return Effective_Writes_Vars.Contains (EN);
   end GG_Has_Effective_Writes;

end Flow_Computed_Globals;
