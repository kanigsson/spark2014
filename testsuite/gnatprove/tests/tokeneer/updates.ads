------------------------------------------------------------------
-- Tokeneer ID Station Core Software
--
-- Copyright (2003) United States Government, as represented
-- by the Director, National Security Agency. All rights reserved.
--
-- This material was originally developed by Praxis High Integrity
-- Systems Ltd. under contract to the National Security Agency.
------------------------------------------------------------------

------------------------------------------------------------------
-- Updates
--
-- Description:
--    Utility package responsible for performing updates of the
--    environment.
--
------------------------------------------------------------------
with Admin;
with Stats;
with Door; use Door;
with AlarmTypes; use AlarmTypes;
with Alarm; use Alarm;
with Latch; use Latch;
--# inherit
--#    Admin,
--#    Alarm,
--#    AlarmTypes,
--#    AuditLog,
--#    Clock,
--#    ConfigData,
--#    Display,
--#    Door,
--#    Latch,
--#    Screen,
--#    Stats;
package Updates
is pragma SPARK_Mode (On);


   ------------------------------------------------------------------
   -- EarlyActivity
   --
   -- Description:
   --    Performs the critical updates of the latch and the alarm.
   --
   -- Traceunit: C.Updates.EarlyActivity
   -- Traceto: FD.Interfac.TISEarlyUpdates
   ------------------------------------------------------------------
   procedure EarlyActivity (SystemFault :    out Boolean);
   --# global in     Latch.State;
   --#        in     Clock.Now;
   --#        in     ConfigData.State;
   --#        in     Door.State;
   --#        in out AuditLog.State;
   --#        in out AuditLog.FileState;
   --#           out Latch.Output;
   --#           out Alarm.Output;
   --# derives Latch.Output,
   --#         SystemFault        from Latch.State &
   --#         AuditLog.State     from *,
   --#                                 Latch.State,
   --#                                 AuditLog.FileState,
   --#                                 Clock.Now,
   --#                                 ConfigData.State &
   --#         AuditLog.FileState from *,
   --#                                 Latch.State,
   --#                                 AuditLog.State,
   --#                                 Clock.Now,
   --#                                 ConfigData.State &
   --#         Alarm.Output       from Latch.State,
   --#                                 AuditLog.State,
   --#                                 AuditLog.FileState,
   --#                                 Clock.Now,
   --#                                 ConfigData.State,
   --#                                 Door.State;
   --# post
   --#      --------------------------------------------------------
   --#      -- PROOF ANNOTATIONS FOR SECURITY PROPERTY 3          --
   --#      --====================================================--
   --#      -- After each call to EarlyActivity, the Alarm is     --
   --#      -- alarming if the conditions of the security         --
   --#      -- property hold.                                     --
   --#      -- Note that from the Door package annotation,        --
   --#      -- Door.TheDoorAlarm = Alarming is equivalent to the  --
   --#      -- security property conditions                       --
   --#      --------------------------------------------------------
   --#      ( Door.TheDoorAlarm(Door.State) = AlarmTypes.Alarming ->
   --#        Alarm.prf_isAlarming(Alarm.Output) ) and
   --#
   --#
   --#      ( ( Latch.IsLocked(Latch.State) <-> Latch.prf_isLocked(Latch.Output) )
   --#        or SystemFault );

    pragma Postcondition
         ( ((Door.TheDoorAlarm = AlarmTypes.Alarming) <=
           Alarm.isAlarming ) and then

         ( ( Latch.IsLocked = Latch.LatchIsLocked )
           or else SystemFault ));

   ------------------------------------------------------------------
   -- Activity
   --
   -- Description:
   --    Performs the updates performed at the end of a processing cycle.
   --
   -- Traceunit: C.Updates.Activity
   -- Traceto: FD.Interfac.TISUpdates
   ------------------------------------------------------------------
   procedure Activity (TheStats    : in     Stats.T;
                       TheAdmin    : in     Admin.T;
                       SystemFault :    out Boolean);
   --# global in     Latch.State;
   --#        in     Clock.Now;
   --#        in     ConfigData.State;
   --#        in     Door.State;
   --#        in out Display.State;
   --#        in out AuditLog.State;
   --#        in out AuditLog.FileState;
   --#        in out Screen.State;
   --#           out Screen.Output;
   --#           out Latch.Output;
   --#           out Alarm.Output;
   --#           out Display.Output;
   --# derives Latch.Output,
   --#         SystemFault        from Latch.State &
   --#         AuditLog.State,
   --#         AuditLog.FileState from Latch.State,
   --#                                 AuditLog.State,
   --#                                 AuditLog.FileState,
   --#                                 Screen.State,
   --#                                 Door.State,
   --#                                 TheAdmin,
   --#                                 TheStats,
   --#                                 Clock.Now,
   --#                                 ConfigData.State,
   --#                                 Display.State &
   --#         Alarm.Output       from Latch.State,
   --#                                 AuditLog.State,
   --#                                 AuditLog.FileState,
   --#                                 Screen.State,
   --#                                 TheAdmin,
   --#                                 TheStats,
   --#                                 Clock.Now,
   --#                                 ConfigData.State,
   --#                                 Door.State,
   --#                                 Display.State &
   --#         Display.State,
   --#         Display.Output     from Display.State &
   --#         Screen.State       from *,
   --#                                 TheStats,
   --#                                 Display.State,
   --#                                 Door.State,
   --#                                 ConfigData.State,
   --#                                 AuditLog.FileState,
   --#                                 AuditLog.State,
   --#                                 Clock.Now,
   --#                                 TheAdmin &
   --#         Screen.Output      from TheStats,
   --#                                 Screen.State,
   --#                                 Door.State,
   --#                                 Display.State,
   --#                                 ConfigData.State,
   --#                                 AuditLog.FileState,
   --#                                 AuditLog.State,
   --#                                 Clock.Now,
   --#                                 TheAdmin;
   --# post
   --#      --------------------------------------------------------
   --#      -- PROOF ANNOTATIONS FOR SECURITY PROPERTY 3          --
   --#      --====================================================--
   --#      -- After each call to Activity, the Alarm is alarming --
   --#      -- if the conditions of the security property hold.   --
   --#      -- Note that from the Door package annotation,        --
   --#      -- Door.TheDoorAlarm = Alarming is equivalent to the  --
   --#      -- security property conditions                       --
   --#      --------------------------------------------------------
   --#      ( Door.TheDoorAlarm(Door.State) = AlarmTypes.Alarming  ->
   --#        Alarm.prf_isAlarming(Alarm.Output) ) and
   --#
   --#
   --#      ( ( Latch.IsLocked(Latch.State) <-> Latch.prf_isLocked(Latch.Output) )
   --#        or SystemFault );

    pragma Postcondition

         (( (Door.TheDoorAlarm = AlarmTypes.Alarming)  <=
           Alarm.isAlarming ) and then


         ( ( Latch.IsLocked = Latch.LatchisLocked )
           or else SystemFault ));

end Updates;
