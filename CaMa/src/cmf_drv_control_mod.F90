MODULE CMF_DRV_CONTROL_MOD
!==========================================================
!* PURPOSE: Initialize/Finalize CaMa-Flood Model 
!
!* CONTAINS:
! -- CMF_DRV_INPUT    : Set namelist & logfile
! -- CMF_DRV_INIT     : Initialize        CaMa-Flood
! -- CMF_DRV_END      : Finalize          CaMa-Flood
!
! (C) D.Yamazaki & E. Dutra  (U-Tokyo/FCUL)  Aug 2019
!
! Modifications: I. Ayan-Miguez (BSC) Apr 2023: Added LECMF2LAKEC switch
!
! Licensed under the Apache License, Version 2.0 (the "License");
!   You may not use this file except in compliance with the License.
!   You may obtain a copy of the License at: http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software distributed under the License is 
!  distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
! See the License for the specific language governing permissions and limitations under the License.
!==========================================================
   !** shared variables in module
   USE PARKIND1,                only: JPIM, JPRB, JPRM
   USE YOS_CMF_INPUT,           only: LOGNAM
   USE YOS_CMF_MAP,             only: REGIONALL, REGIONTHIS
   IMPLICIT NONE
   !** local variables
   SAVE
   real(KIND=JPRB)                 :: ZTT0, ZTT1, ZTT2   ! Time elapsed related 
!==========================================================
CONTAINS
   !####################################################################
   ! -- CMF_DRV_INPUT    : Set namelist & logfile
   ! -- CMF_DRV_INIT     : Initialize        CaMa-Flood
   ! -- CMF_DRV_END      : Finalize          CaMa-Flood
   !
   !####################################################################
   SUBROUTINE CMF_DRV_INPUT
   ! Read setting from namelist ("input_flood.nam" as default)
   ! -- Called from CMF_DRV_INIT
   USE YOS_CMF_INPUT,           only: LLOGOUT, LOGNAM, CLOGOUT, CSETFILE, LSEALEV, LDAMOUT, LLEVEE, LOUTPUT
   USE CMF_CTRL_NMLIST_MOD,     only: CMF_CONFIG_NMLIST, CMF_CONFIG_CHECK
   USE CMF_CTRL_TIME_MOD,       only: CMF_TIME_NMLIST
   USE CMF_CTRL_FORCING_MOD,    only: CMF_FORCING_NMLIST
   USE CMF_CTRL_BOUNDARY_MOD,   only: CMF_BOUNDARY_NMLIST
   USE CMF_CTRL_RESTART_MOD,    only: CMF_RESTART_NMLIST
   USE CMF_CTRL_DAMOUT_MOD,     only: CMF_DAMOUT_NMLIST
   USE CMF_CTRL_LEVEE_MOD,      only: CMF_LEVEE_NMLIST
   USE CMF_CTRL_OUTPUT_MOD,     only: CMF_OUTPUT_NMLIST
   USE CMF_CTRL_MAPS_MOD,       only: CMF_MAPS_NMLIST
   USE CMF_UTILS_MOD,           only: INQUIRE_FID
#ifdef sediment
   USE YOS_CMF_INPUT,           only: LSEDOUT
   USE cmf_ctrl_sed_mod,        only: cmf_sed_nmlist
#endif
   IMPLICIT NONE
   !* local
   character(LEN=8)              :: CREG                 !! 
   !================================================

   !*** 0a. Set log file & namelist
   ! Preset in YOS_INPUT:  LLOGOUT=.TRUE.   CLOGOUT='./log_CaMa.txt'
   ! It can be modified in MAIN program before DRV_INPUT

      IF (REGIONALL>=2 )THEN 
         write(CREG,'(I0)') REGIONTHIS                                    !! Distributed Log Output for MPI run
         CLOGOUT=TRIM(CLOGOUT)//'-'//TRIM(CREG)                           !! Change suffix of output file for each calculation node
      ENDIF

      IF( LLOGOUT )THEN
         LOGNAM=INQUIRE_FID()
         open(LOGNAM,FILE=CLOGOUT,FORM='FORMATTED')  
      ELSE
         LOGNAM=6  !! use standard output
         CLOGOUT="NONE"
      ENDIF

      write(LOGNAM,*) ""
      write(LOGNAM,*) "!******************************"
      write(LOGNAM,*) "CMF::DRV_INPUT: log file:            ", TRIM(CLOGOUT), LOGNAM

      !*** 0b. Input namelist filename
      ! Preset in YOS_INPUT:  CSETFILE="input_cmf.nam"
      ! It can be modified in MAIN program before DRV_INPUT
      write(LOGNAM,*) "CMF::DRV_INPUT: input namelist:      ", TRIM(CSETFILE)

      !*** 1. CaMa-Flood configulation namelist
      CALL CMF_CONFIG_NMLIST

      CALL CMF_TIME_NMLIST

      CALL CMF_MAPS_NMLIST

      !*** 2. read namelist for each module
      CALL CMF_FORCING_NMLIST

      IF( LSEALEV )THEN
         CALL CMF_BOUNDARY_NMLIST
      ENDIF

      CALL CMF_RESTART_NMLIST

      IF( LDAMOUT )THEN
         CALL CMF_DAMOUT_NMLIST
      ENDIF

      IF( LLEVEE )THEN
         CALL CMF_LEVEE_NMLIST
      ENDIF

      IF( LOUTPUT )THEN
         CALL CMF_OUTPUT_NMLIST
      ENDIF

#ifdef sediment
      IF( LSEDOUT )THEN
         CALL cmf_sed_nmlist
      ENDIF
#endif

      write(LOGNAM,*) "CMF::DRV_INPUT: end reading namelist"

      !*** 3. check configulation conflicts
      CALL CMF_CONFIG_CHECK

      write(LOGNAM,*) "CMF::DRV_INPUT: finished"
      write(LOGNAM,*) "******************************!"
      write(LOGNAM,*) ""

   END SUBROUTINE CMF_DRV_INPUT
   !####################################################################





   !####################################################################
SUBROUTINE CMF_DRV_INIT(LECMF2LAKEC)
   ! Initialize CaMa-Flood
   ! -- Called from CMF_DRV_INIT
   USE YOS_CMF_INPUT,           only: LRESTART, LSTOONLY, LOUTPUT, LSEALEV, LDAMOUT, LLEVEE, LOUTINI
   ! init routines
   USE CMF_CTRL_TIME_MOD,       only: CMF_TIME_INIT
   USE CMF_CTRL_MAPS_MOD,       only: CMF_RIVMAP_INIT,  CMF_TOPO_INIT
   USE CMF_CTRL_VARS_MOD,       only: CMF_PROG_INIT,    CMF_DIAG_INIT
   USE CMF_CTRL_FORCING_MOD,    only: CMF_FORCING_INIT
   USE CMF_CTRL_BOUNDARY_MOD,   only: CMF_BOUNDARY_INIT
   USE CMF_CTRL_OUTPUT_MOD,     only: CMF_OUTPUT_INIT,  CMF_OUTPUT_WRITE
   USE CMF_CTRL_RESTART_MOD,    only: CMF_RESTART_INIT
   USE CMF_CTRL_DAMOUT_MOD,     only: CMF_DAMOUT_INIT
   USE CMF_CTRL_LEVEE_MOD,      only: CMF_LEVEE_INIT
#ifdef sediment
   USE YOS_CMF_INPUT,           only: LSEDOUT
   USE cmf_ctrl_sed_mod,        only: cmf_sed_init
#endif
   ! import
   USE CMF_CTRL_PHYSICS_MOD,    only: CMF_PHYSICS_FLDSTG
   USE CMF_OPT_OUTFLW_MOD,      only: CMF_CALC_OUTPRE
   USE CMF_UTILS_MOD,           only: INQUIRE_FID
   !$ USE OMP_LIB    
   IMPLICIT NONE
      integer(KIND=JPIM),OPTIONAL,INTENT(IN)  :: LECMF2LAKEC !! for lake coupling, currently only used in ECMWF
      !================================================
      write(LOGNAM,*) ""
      write(LOGNAM,*) "!******************************!"
      write(LOGNAM,*) "CMF::DRV_INIT: initialization start"

      !*** 0b. get start time
      CALL CPU_TIME(ZTT0)
      !$ ZTT0=OMP_GET_WTIME()

      !================================================
      write(LOGNAM,*) "CMF::DRV_INIT: (1) Set Time"

      !*** 1a. Set time related 
      CALL CMF_TIME_INIT

      !================================================
      write(LOGNAM,*) "CMF::DRV_INIT: (2) Set River Map & Topography"

      !*** 2a. Read input river map 
      CALL CMF_RIVMAP_INIT

      !*** 2b. Set topography 
      CALL CMF_TOPO_INIT

      !*** 2c. Optional levee scheme initialization
      IF( LLEVEE )THEN
         CALL CMF_LEVEE_INIT
      ENDIF

      !================================================
      write(LOGNAM,*) "CMF::DRV_INIT: (3) Set output & forcing modules"

      !*** 3a. Create Output files 
      !IF( LOUTPUT )THEN
      CALL CMF_OUTPUT_INIT
      !ENDIF

!*** 3b. Initialize forcing data
IF(PRESENT(LECMF2LAKEC)) THEN
  CALL CMF_FORCING_INIT(LECMF2LAKEC)
ELSE
  CALL CMF_FORCING_INIT()
ENDIF

      !*** 3b. Initialize dynamic sea level boundary data
      IF( LSEALEV )THEN
         CALL CMF_BOUNDARY_INIT
      ENDIF
      !================================================
      write(LOGNAM,*) "CMF::DRV_INIT: (4) allocate prog&diag vars & initialize"

      !*** 4a. Set initial prognostic variables 
      CALL CMF_PROG_INIT

      !*** 4b. Initialize (allocate) diagnostic arrays
      CALL CMF_DIAG_INIT

      !v4.03 CALC_FLDSTG for zero storage restart
      CALL CMF_PHYSICS_FLDSTG

      !*** 4c. Restart file
      IF( LRESTART )THEN
         CALL CMF_RESTART_INIT
      ENDIF

      !*** 4d. Optional reservoir initialization
      IF( LDAMOUT )THEN
         CALL CMF_DAMOUT_INIT
      ENDIF

#ifdef sediment
      !*** 4e. Optional sediment initialization
      IF( LSEDOUT )THEN
         CALL cmf_sed_init
      ENDIF
#endif

      !================================================
      !** v4.03 CALC_FLDSTG moved to the top of CTRL_PHYSICS for strict restart configulation (Hatono & Yamazaki)

      !*** 5 reconstruct previous t-step flow (if needed)
      IF( LRESTART .and. LSTOONLY )THEN
         write(LOGNAM,*) "CMF::DRV_INIT: (5a) set flood stage at initial condition"
         !** v4.03 CALC_FLDSTG for storagy only restart (v4.03)
         CALL CMF_PHYSICS_FLDSTG
         CALL CMF_CALC_OUTPRE  !! bugfix in v4.12
      ENDIF

      !*** 5b save initial storage if LOUTINI specified
      IF ( LOUTINI .and. LOUTPUT ) THEN
         write(LOGNAM,*) "CMF::DRV_INIT: (5b) write initial condition"
         CALL CMF_OUTPUT_WRITE
      ENDIF

      !================================================

      !*** get initialization end time time
      CALL CPU_TIME(ZTT1)
      !$ ZTT1=OMP_GET_WTIME()

      write(LOGNAM,*) "CMF::DRV_INIT: initialization finished:"
      write(LOGNAM,*) "Elapsed cpu time (Init)", ZTT1-ZTT0,"Seconds"
      write(LOGNAM,*) "CMF::DRV_INIT: end"
      write(LOGNAM,*) "***********************************"


   END SUBROUTINE CMF_DRV_INIT
   !####################################################################




   !####################################################################
   SUBROUTINE CMF_DRV_END
   ! Finalize CaMa-Flood
   USE YOS_CMF_INPUT,           only: LOUTPUT, LSEALEV
   USE CMF_CTRL_OUTPUT_MOD,     only: CMF_OUTPUT_END
   USE CMF_CTRL_FORCING_MOD,    only: CMF_FORCING_END
   USE CMF_CTRL_BOUNDARY_MOD,   only: CMF_BOUNDARY_END
#ifdef sediment
   USE YOS_CMF_INPUT,           only: LSEDOUT
   USE cmf_ctrl_sedout_mod,     only: sediment_output_end
#endif
   !$ USE OMP_LIB    
   IMPLICIT NONE 
      !==========================================================
      write(LOGNAM,*) ""
      write(LOGNAM,*) "!******************************!"
      write(LOGNAM,*) "CMF::DRV_END: finalize forcing & output modules"
      CALL CMF_FORCING_END
      IF( LOUTPUT )THEN
         CALL CMF_OUTPUT_END
#ifdef sediment
         IF( LSEDOUT ) CALL sediment_output_end
#endif
      ENDIF
      IF( LSEALEV ) THEN
         CALL CMF_BOUNDARY_END
      ENDIF

      !*** get simulation end time
      CALL CPU_TIME(ZTT2)
      !$ ZTT2=OMP_GET_WTIME()
      write(LOGNAM,*) "CMF::DRV_END: simulation finished in:",ZTT2-ZTT0,' Seconds'

      write(LOGNAM,*) "CMF::DRV_END: close logfile"
      write(LOGNAM,*) "CMF::===== CALCULATION END ====="
      close(LOGNAM)

   END SUBROUTINE CMF_DRV_END
      !####################################################################


END MODULE CMF_DRV_CONTROL_MOD
