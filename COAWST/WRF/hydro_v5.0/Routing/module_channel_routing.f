!  Program Name:
!  Author(s)/Contact(s):
!  Abstract:
!  History Log:
! 
!  Usage:
!  Parameters: <Specify typical arguments passed>
!  Input Files:
!        <list file names and briefly describe the data they include>
!  Output Files:
!        <list file names and briefly describe the information they include>
! 
!  Condition codes:
!        <list exit condition or error codes returned >
!        If appropriate, descriptive troubleshooting instructions or
!        likely causes for failures could be mentioned here with the
!        appropriate error code
! 
!  User controllable options: <if applicable>

MODULE module_channel_routing

use module_mpp_land
use MODULE_mpp_ReachLS, only : updatelinkv,                   & 
                               ReachLS_write_io, gbcastvalue, &
                               gbcastreal2,      linkls_s

implicit none

contains

! ------------------------------------------------
!   FUNCTION MUSKING
! ------------------------------------------------
real function MUSKING(idx,qup,quc,qdp,dt,Km,X)

implicit none

!--local variables
real    :: C1, C2, C3
real    :: Km         !K travel time in hrs in reach
real    :: X          !weighting factors 0<=X<=0.5 
real    :: dt         !routing period in hrs
real    :: avgbf      !average base flow for initial condition
real    :: qup        !inflow from previous timestep
real    :: quc        !inflow  of current timestep
real    :: qdp        !outflow of previous timestep
real    :: dth        !timestep in hours
integer :: idx       ! index

dth = dt/3600    !hours in timestep
C1 = (dth - 2*Km*X)/(2*Km*(1-X)+dth)
C2 = (dth+2*Km*X)/(2*Km*(1-X)+dth)
C3 = (2*Km*(1-X)-dth)/(2*Km*(1-X)+dth)
MUSKING = (C1*quc)+(C2*qup)+(C3*qdp)

! ----------------------------------------------------------------
end function MUSKING
! ----------------------------------------------------------------

! ------------------------------------------------
!   SUBROUTINE LEVELPOOL
! ------------------------------------------------

subroutine LEVELPOOL(ln,qi0,qi1,qo1,ql,dt,H,ar,we,maxh,wc,wl,oe,oc,oa)

!! ----------------------------  argument variables
!! All elevations should be relative to a common base (often belev(k))

real, intent(INOUT) :: H       ! water elevation height (m)
real, intent(IN)    :: dt      ! routing period [s]
real, intent(IN)    :: qi0     ! inflow at previous timestep (cms)
real, intent(IN)    :: qi1     ! inflow at current timestep (cms)
real, intent(OUT)   :: qo1     ! outflow at current timestep
real, intent(IN)    :: ql      ! lateral inflow
real, intent(IN)    :: ar      ! area of reservoir (km^2)
real, intent(IN)    :: we      ! bottom of weir elevation
real, intent(IN)    :: wc      ! weir coeff.
real, intent(IN)    :: wl      ! weir length (m)
real, intent(IN)    :: oe      ! orifice elevation
real, intent(IN)    :: oc      ! orifice coeff.
real, intent(IN)    :: oa      ! orifice area (m^2)
real, intent(IN)    :: maxh    ! max depth of reservoir before overtop (m)                     
integer, intent(IN) :: ln      ! lake number

!!DJG Add lake option switch here...move up to namelist in future versions...
integer :: LAKE_OPT            ! Lake model option (move to namelist later)
real    :: Htmp                ! Temporary assign of incoming lake el. (m)

!! ----------------------------  local variables
real :: sap                    ! local surface area values
real :: discharge              ! storage discharge m^3/s
real :: tmp1, tmp2
real :: dh, dh1, dh2, dh3      ! height function and 3 order RK
real :: It, Itdt_3, Itdt_2_3
real :: maxWeirDepth           !maximum capacity of weir
!! ----------------------------  subroutine body: from chow, mad mays. pg. 252
!! -- determine from inflow hydrograph


!!DJG Set hardwire for LAKE_OPT...move specification of this to namelist in
!future versions...
LAKE_OPT = 2
Htmp = H   !temporary set of incoming lake water elevation...


!!DJG IF-block for lake model option  1 - outflow=inflow, 2 - Chow et al level
!pool, .....
if (LAKE_OPT.eq.1) then     ! If-block for simple pass through scheme....
   
   qo1 = qi1                 ! Set outflow equal to inflow at current time      
   H = Htmp                  ! Set new lake water elevation to incoming lake el.
   
else if (LAKE_OPT.eq.2) then   ! If-block for Chow et al level pool scheme
   
   It = qi0
   Itdt_3   = (qi0 + (qi1 + ql))/3
   Itdt_2_3 = (qi0 + (qi1 + ql))/3 + Itdt_3
   maxWeirDepth =  maxh - we   
   
   !-- determine Q(dh) from elevation-discharge relationship
   !-- and dh1
   dh = H - we
   if (dh .gt. maxWeirDepth) then 
      dh = maxWeirDepth 
   endif
   
   if (dh .gt. 0.0 ) then              !! orifice and overtop discharge
      tmp1 = oc * oa * sqrt(2 * 9.81 * ( H - oe ) )
      tmp2 = wc * wl * (dh ** 2./3.)
      discharge = tmp1 + tmp2
      
      if (H .gt. 0.0) then
         sap = (ar * 1.0E6 ) * (1 + (H - we) / H)
      else
         sap  = 0.0
      endif
      
   else if ( H .gt. oe ) then     !! only orifice flow,not full
      discharge = oc * oa * sqrt(2 * 9.81 * ( H - oe ) )
      sap = ar * 1.0E6
   else
      discharge = 0.0
      sap = ar * 1.0E6
   endif
   
   if (sap .gt. 0) then 
      dh1 = ((It - discharge)/sap)*dt
   else
      dh1 = 0.0
   endif
   
   !-- determine Q(H + dh1/3) from elevation-discharge relationship
   !-- dh2
   dh = (H+dh1/3) - we
   if (dh .gt. maxWeirDepth) then 
      dh = maxWeirDepth 
   endif
   
   if (dh .gt. 0.0 ) then              !! orifice and overtop discharge
      tmp1 = oc * oa * sqrt(2 * 9.81 * ( H - oe ) )
      tmp2 = wc * wl * (dh ** 2./3.) 
      discharge = tmp1 + tmp2
      
      if (H .gt. 0.0) then 
         sap = (ar * 1.0E6 ) * (1 + (H - we) / H)
      else
         sap  = 0.0
      endif
      
   else if ( H .gt. oe ) then     !! only orifice flow,not full
      discharge = oc * oa * sqrt(2 * 9.81 * ( H - oe ) )
      sap = ar * 1.0E6
   else
      discharge = 0.0
      sap = ar * 1.0E6
   endif
   
   if (sap .gt. 0.0) then 
      dh2 = ((Itdt_3 - discharge)/sap)*dt
   else
      dh2 = 0.0
   endif
   
   !-- determine Q(H + 2/3 dh2) from elevation-discharge relationship
   !-- dh3
   dh = (H + (0.667*dh2)) - we
   if (dh .gt. maxWeirDepth) then 
      dh = maxWeirDepth 
   endif
   
   if (dh .gt. 0.0 ) then              !! orifice and overtop discharge
      tmp1 = oc * oa * sqrt(2 * 9.81 * ( H - oe ) )
      tmp2 = wc * wl * (dh ** 2./3.) 
      discharge = tmp1 + tmp2
      
      if (H .gt. 0.0) then
         sap = (ar * 1.0E6 ) * (1 + (H - we) / H)
      else
         sap = 0.0
      endif
      
   else if ( H .gt. oe ) then     !! only orifice flow,not full
      discharge = oc * oa * sqrt(2 * 9.81 * ( H - oe ) )
      sap = ar * 1.0E6
   else
      discharge = 0.0
      sap = ar * 1.0E6
   endif
   
   if (sap .gt. 0.0) then 
      dh3 = ((Itdt_2_3 - discharge)/sap)*dt
   else
      dh3 = 0.0
   endif
    
   !-- determine dh and H
   dh = (dh1/4.) + (0.75*dh3)
   H = H + dh
   
   !-- compute final discharge
   dh = H - we
   if (dh .gt. maxWeirDepth) then 
      dh = maxWeirDepth 
   endif
   if (dh .gt. 0.0 ) then              !! orifice and overtop discharge
      tmp1 = oc * oa * sqrt(2 * 9.81 * ( H - oe ) )
      tmp2 = wc * wl * (dh ** 2./3.)
      discharge = tmp1 + tmp2
      
      if (H .gt. 0.0) then 
         sap = (ar * 1.0E6 ) * (1 + (H - we) / H)
      else
         sap = 0.0
      endif
      
   else if ( H .gt. oe ) then     !! only orifice flow,not full
      discharge = oc * oa * sqrt(2 * 9.81 * ( H - oe ) )
      sap = ar * 1.0E6
   else
      discharge = 0.0
      sap = ar * 1.0E6
   endif
   
   if(H .ge. maxh) then  ! overtop condition
      discharge = qi1
      H = maxh
   endif
   
   qo1  = discharge  ! return the flow rate from reservoir
   
23 format('botof H dh orf wr Q',f8.4,2x,f8.4,2x,f8.3,2x,f8.3,2x,f8.2)
24 format('ofonl H dh sap Q ',f8.4,2x,f8.4,2x,f8.0,2x,f8.2)
   
   
else   ! ELSE for LAKE_OPT....
endif  ! ENDIF for LAKE_OPT....

return
 
! ----------------------------------------------------------------
end subroutine LEVELPOOL
! ----------------------------------------------------------------

 
! ------------------------------------------------
!   FUNCTION Diffusive wave
! ------------------------------------------------
real function DIFFUSION(nod,z1,z20,h1,h2,dx,n, &
     Bw, Cs)
implicit none
!-- channel geometry and characteristics
real    :: Bw         !-bottom width (meters)
real    :: Cs         !-Channel side slope slope
real    :: dx         !-channel lngth (m)
real,intent(in)    :: n          !-mannings coefficient
real    :: R          !-Hydraulic radius
real    :: AREA       !- wetted area
real    :: h1,h2      !-tmp height variables
real    :: z1,z2      !-z1 is 'from', z2 is 'to' elevations
real    :: z          !-channel side distance
real    :: w          !-upstream weight
real    :: Ku,Kd      !-upstream and downstream conveyance
real    :: Kf         !-final face conveyance
real    :: Sf         !-friction slope
real    :: sgn        !-0 or 1 
integer :: nod         !- node
real ::  z20, dzx

! added by Wei Yu for bad data.

dzx = (z1 - z20)/dx
if(dzx .lt. 0.002) then
   z2 = z1 - dx*0.002  
else
   z2 = z20
endif
!end 

if (n.le.0.0.or.Cs.le.0.or.Bw.le.0) then
   print *, "Error in Diffusion function ->channel coefficients"
   print *, "nod, n, Cs, Bw", nod, n, Cs, Bw 
   call hydro_stop("In DIFFUSION() - Error channel coefficients.")
endif

!        Sf = ((z1+h1)-(z2+h2))/dx  !-- compute the friction slope
!if(z1 .eq. z2) then
! Sf = ((z1-(z2-0.01))+(h1-h2))/dx  !-- compute the friction slope
!else
!         Sf = ((z1-z2)+(h1-h2))/dx  !-- compute the friction slope
!endif

!modifieed by Wei Yu for false geography data
if(abs(z1-z2) .gt. 1.0E5) then



   Sf = ((h1-h2))/dx  !-- compute the friction slope
else
   Sf = ((z1-z2)+(h1-h2))/dx  !-- compute the friction slope
endif
!end  modfication

sgn = SGNf(Sf)             !-- establish sign

w = 0.5*(sgn + 1.)         !-- compute upstream or downstream weighting

z = 1/Cs                   !--channel side distance (m)
R = ((Bw+z*h1)*h1)/(Bw+2*h1*sqrt(1+z*z)) !-- Hyd Radius
AREA = (Bw+z*h1)*h1        !-- Flow area
Ku = (1/n)*(R**(2./3.))*AREA     !-- convenyance

R = ((Bw+z*h2)*h2)/(Bw+2*h2*sqrt(1+z*z)) !-- Hyd Radius
AREA = (Bw+z*h2)*h2        !-- Flow area
Kd = (1/n)*(R**(2./3.))*AREA     !-- convenyance

Kf =  (1-w)*Kd + w*Ku      !-- conveyance 
DIFFUSION = Kf * sqrt(abs(Sf))*sgn


100 format('z1,z2,h1,h2,kf,Dif, Sf, sgn  ',f8.3,2x,f8.3,2x,f8.4,2x,f8.4,2x,f8.3,2x,f8.3,2x,f8.3,2x,f8.0)

end function DIFFUSION
! ----------------------------------------------------------------

subroutine SUBMUSKINGCUNGE(qdc,vel,idx,qup,quc,qdp,ql,dt,So,dx,n,Cs,Bw)





        IMPLICIT NONE

        REAL, intent(IN)       :: dt         !routing period in  seconds
        REAL, intent(IN)       :: qup        !flow upstream previous timestep
        REAL, intent(IN)       :: quc        !flow upstream current timestep
        REAL, intent(IN)       :: qdp        !flow downstream previous timestep
        REAL, intent(INOUT)    :: qdc        !flow downstream current timestep
        REAL, intent(IN)       :: ql         !lateral inflow through reach (m^3/sec)
        REAL, intent(IN)       :: Bw         ! bottom width (meters)
        REAL, intent(IN)       :: Cs         ! Channel side slope slope
        REAL, intent(IN)       :: So         ! Channel bottom slope %
        REAL, intent(IN)       :: dx         ! channel lngth (m)
        REAL, intent(IN)       :: n          ! mannings coefficient
        REAL, intent(INOUT)    :: vel        ! mannings coefficient
        INTEGER, intent(IN)    :: idx        ! channel id

!--local variables
        REAL    :: C1, C2, C3, C4
        REAL    :: Km          !K travel time in hrs in reach
        REAL    :: X           !weighting factors 0<=X<=0.5
        REAL    :: Ck          ! wave celerity (m/s)

!-- channel geometry and characteristics
        REAL    :: Tw         ! top width at peak flow
        REAL    :: AREA       ! Cross sectional area m^2
        REAL    :: Z          ! trapezoid distance (m)
        REAL    :: R          ! Hydraulic radius
        REAL    :: WP         ! wetted perimmeter
        REAL    :: h          ! depth of flow
        REAL    :: h_0,h_1    ! secant method estimates
        REAL    :: Qj_0       ! secant method estimates
        REAL    :: Qj         ! intermediate flow estimate
        REAL    :: D,D1       ! diffusion coeff
        REAL    :: dtr        ! required timestep, minutes
        REAL    :: error
        REAL    :: hp         !courant, previous height
        INTEGER :: maxiter    !maximum number of iterations

!-- local variables.. needed if channel is sub-divded
        REAL    :: a,b,c
        INTEGER :: i          !-- channel segment counter

        c = 0.52           !-- coefficnets for finding dx/Ckdt
        b = 1.15
        
        if(Cs .eq.0) then 
         z = 1.0 
        else 
         z = 1/Cs              !channel side distance (m)
        endif

        !qC = quc + ql !current upstream in reach

        if (n .le.0 .or. So .le. 0 .or. z .le. 0 .or. Bw .le. 0) then
          print*, "Error in channel coefficients -> Muskingum cunge",n,So,z,Bw
          call hydro_stop("In MUSKINGCUNGE() - Error in channel coefficients")
        end if

        error   = 1.0
        maxiter = 0
        a = 0.0

        if ((quc+ql) .lt. 100) then 
          b=5 
        else 
         b= 20
        endif

!-------------  Secant Method
        h    =  (a+b)/2  !- upper interval
        h_0  = 0.0       !- lower interval
        Qj_0 = 0.0       !- initial flow of lower interval

        do while ((error .gt. 0.05 .and. maxiter .le. 100 .and. h .gt. 0.01))  

          !----- lower interval  --------------------
          Tw = Bw + 2*z*h_0                    !--top width of the channel inflow
          if(h_0 .le. 0.0) then
             AREA= 0.0
             R = 0.0
             WP = 0.0
           else
            AREA = (Bw * h_0 + z * (h_0*h_0) )
            WP = (Bw + 2 * h_0 * sqrt(1+z*z))
            R   = AREA/ WP
           endif

           ! Ck = (sqrt(So)/n)*(5./3.)*(h_0**0.667)   !-- pg 287 Chow, Mdt, Mays
           ! This is for wide rectangle and not trapezoid so it was replaced
           ! with the following 

           if (h_0 .le. 0.0) then 
                Ck = 0.0
           else 
                Ck = (sqrt(So)/n)*((5./3.)*R**(2./3.) - &
                ((2./3.)*R**(5./3.)*(2*sqrt(1+z*z)/(Bw+2*h_0*z))))
           endif

           if(Ck .gt. 0.0) then
             Km = dx/Ck                       !-- seconds Muskingum Param
             if(Km .lt. dt) then           
               Km = dt
             endif
           else 
             Km = dt
           endif
 
           if(Tw*So*Ck*dx .eq. 0.0) then 
             X = 0.25
           else
             X = 0.5-(Qj_0/(2*Tw*So*Ck*dx))
           endif
  
           if(X .le. 0.0) then 
             X = 0.25
           elseif(X .gt. 0.5) then
             X = 0.5
           endif
  
           D = (Km*(1 - X) + dt/2)              !--seconds
            if(D .eq. 0.0) then 
              print *, "FATAL ERROR: D is 0 in MUSKINGCUNGE", Km, X, dt,D
              call hydro_stop("In MUSKINGCUNGE() - D is 0.")
           endif 
  
           C1 =  (Km*X + dt/2)/D
           C2 =  (dt/2 - Km*X)/D
           C3 =  (Km*(1-X)-dt/2)/D
           C4 =  (ql*dt)/D                       !-- ql already multipled by the dx length

           
           if(R .le. 0.0) then 
              Qj_0 =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4)
           else 
              Qj_0 =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4) - ((1/n) * AREA * (R**(2./3.)) * sqrt(So)) !f(x)
           endif

           !--upper interval -----------
           Tw = Bw + 2*z*h                    !--top width of the channel inflow

           if(h .le. 0) then
            AREA = 0.0
            WP = 0.0
            R   = 0.0
           else
            AREA = (Bw * h + z * (h*h) )
            WP =  (Bw + 2 * h * sqrt(1+z*z))
            R   = AREA / WP
           endif

!           Ck = (sqrt(So)/n)*(5./3.)*(h**0.667)   !-- pg 287 Chow, Mdt, Mays
           ! This is for wide rectangle and not trapezoid so it was replaced
           ! with the following

           if (h .le. 0.0) then
                Ck = 0.0
           else
                Ck = (sqrt(So)/n)*((5./3.)*R**(2./3.) - &
                ((2./3.)*R**(5./3.)*(2*sqrt(1+z*z)/(Bw+2*h*z))))
           endif

           if(Ck .gt. 0.0) then
             Km = dx/Ck                       !-- seconds Muskingum Param
             if(Km .lt. dt) then           
               Km = dt
             endif
           else 
             Km = dt
           endif
 
           if(Tw*So*Ck*dx .eq. 0.0) then 
             X = 0.25
           else
             X = 0.5-(((C1*qup)+(C2*quc)+(C3*qdp) + C4)/(2*Tw*So*Ck*dx))
           endif
  
           if(X .le. 0.0) then 
             X = 0.25
           elseif(X .gt. 0.5) then
             X = 0.5
           endif
  
           D = (Km*(1 - X) + dt/2)              !--seconds
            if(D .eq. 0.0) then 
              print *, "FATAL ERROR: D is 0 in MUSKINGCUNGE", Km, X, dt,D
              call hydro_stop("In MUSKINGCUNGE() - D is 0.")
           endif 
  
           C1 =  (Km*X + dt/2)/D
           C2 =  (dt/2 - Km*X)/D
           C3 =  (Km*(1-X)-dt/2)/D
           C4 =  (ql*dt)/D                       !-- ql already multipled by the dx length

           if(R .le. 0.0) then 
             Qj =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4)
           else
             Qj =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4) -((1/n) * AREA * (R**(2./3.)) * sqrt(So))
           endif

           if(Qj_0-Qj .ne. 0.0) then
             h_1 = h - ((Qj * (h_0 - h))/(Qj_0 - Qj)) !update h, 3rd estimate
              if(h_1 .lt. 0.0) then
                h_1 = h
              endif
           else
             h_1 = h
           endif

           error = abs((h_1 - h)/h) !error is new estatimate and 2nd estimate

!           if(idx .eq. 626) then 
!             write(6,*) h_0,h,h_1,error
!           endif

           h_0  = h 
           h    = h_1
           maxiter = maxiter + 1

      end do

      if((maxiter .ge. 100 .and. error .gt. 0.05) .or. h .gt. 100) then 

         print*, "WARNING:"
         print*,'RouteLink index:', idx + linkls_s(my_id+1) - 1
         print*, "id,err,iters,h", idx, error, maxiter, h
         print*, "n,z,B,So,dx,X,dt,Km",n,z,Bw,So,dx,X,dt,Km
         print*, "qup,quc,qdp,ql", qup,quc,qdp,ql
         if(h.gt.100) then
              print*, "FATAL ERROR: Water Elevation Calculation is Diverging"
              call hydro_stop("In SUBMUSKINGCUNGE() - Water Elevation Calculation is Diverging")
         endif
      endif

      
!yw added for test
      if(((C1*qup)+(C2*quc)+(C3*qdp) + C4) .lt. 0.0) then
!       MUSKINGCUNGE =  MAX( ( (C1*qup)+(C2*quc) + C4),((C1*qup)+(C3*qdp) + C4) )
        qdc = MAX( ( (C1*qup)+(C2*quc) + C4),((C1*qup)+(C3*qdp) + C4) )

      else
!       MUSKINGCUNGE =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4) !-- pg 295 Bedient huber
        qdc =  ((C1*qup)+(C2*quc)+(C3*qdp) + C4) !-- pg 295 Bedient huber

      endif

      Tw = Bw + (2*z*h)
      R = (h*(Bw + Tw) / 2) / (Bw + 2*(((Tw - Bw) / 2)**2 + h**2)**0.5)    
      vel =  (1./n) * (R **(2./3.)) * sqrt(So)  ! average velocity in m/s

! ----------------------------------------------------------------
END SUBROUTINE SUBMUSKINGCUNGE
! ----------------------------------------------------------------

! ------------------------------------------------
!   FUNCTION KINEMATIC
! ------------------------------------------------
	REAL FUNCTION KINEMATIC()

	IMPLICIT NONE

! -------- DECLARATIONS -----------------------
 
!	REAL, INTENT(OUT), DIMENSION(IXRT,JXRT)	:: OVRGH

        KINEMATIC = 1       
!----------------------------------------------------------------
  END FUNCTION KINEMATIC
!----------------------------------------------------------------


! ------------------------------------------------
!   SUBROUTINE drive_CHANNEL
! ------------------------------------------------
! ------------------------------------------------
     Subroutine drive_CHANNEL(latval,lonval,KT, IXRT,JXRT, SUBRTSWCRT, &
       QSUBRT, LAKEINFLORT, QSTRMVOLRT, TO_NODE, FROM_NODE, &
       TYPEL, ORDER, MAXORDER, NLINKS, CH_NETLNK, CH_NETRT, CH_LNKRT, &
       LAKE_MSKRT, DT, DTCT, DTRT_CH,MUSK, MUSX, QLINK, &
       QLateral, &
       HLINK, ELRT, CHANLEN, MannN, So, ChSSlp, Bw, &
       RESHT, HRZAREA, LAKEMAXH, WEIRH, WEIRC, WEIRL, ORIFICEC, ORIFICEA, &
       ORIFICEE, ZELEV, CVOL, NLAKES, QLAKEI, QLAKEO, LAKENODE, &
       dist, QINFLOWBASE, CHANXI, CHANYJ, channel_option, RETDEP_CHAN, &
       NLINKSL, LINKID, node_area  &
       , lake_index,link_location,mpp_nlinks,nlinks_index,yw_mpp_nlinks  &
       , LNLINKSL, LLINKID  &
       , gtoNode,toNodeInd,nToNodeInd &
       , CH_LNKRT_SL &
       ,gwBaseSwCRT, gwHead, qgw_chanrt, gwChanCondSw, gwChanCondConstIn, &
       gwChanCondConstOut,velocity)


       IMPLICIT NONE

! -------- DECLARATIONS ------------------------

        INTEGER, INTENT(IN) :: IXRT,JXRT,channel_option
        INTEGER, INTENT(IN) :: NLINKS,NLAKES, NLINKSL
        integer, INTENT(INOUT) :: KT   ! flag of cold start (1) or continue run.
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: QSUBRT
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: QSTRMVOLRT
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: LAKEINFLORT
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: ELRT
        REAL, INTENT(IN), DIMENSION(IXRT,JXRT)    :: QINFLOWBASE
        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: CH_NETLNK

        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: CH_NETRT
        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: CH_LNKRT
        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: CH_LNKRT_SL

       real , dimension(ixrt,jxrt):: latval,lonval

        INTEGER, INTENT(IN), DIMENSION(IXRT,JXRT) :: LAKE_MSKRT
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: ORDER, TYPEL !--link
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: TO_NODE, FROM_NODE
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: CHANXI, CHANYJ
        REAL,    INTENT(IN), DIMENSION(NLINKS)    :: ZELEV  !--elevation of nodes
        REAL, INTENT(INOUT), DIMENSION(NLINKS)    :: CVOL
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: MUSK, MUSX
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: CHANLEN
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: So, MannN
        REAL, INTENT(IN), DIMENSION(NLINKS)       :: ChSSlp,Bw  !--properties of nodes or links
        REAL                                      :: Km, X
        REAL , INTENT(INOUT), DIMENSION(:,:) :: QLINK
        REAL ,  DIMENSION(NLINKS,2) :: tmpQLINK
        REAL , INTENT(INOUT), DIMENSION(NLINKS)   :: HLINK
        REAL, dimension(NLINKS), intent(inout)    :: QLateral !--lateral flow
        REAL, INTENT(IN)                          :: DT    !-- model timestep
        REAL, INTENT(IN)                          :: DTRT_CH  !-- routing timestep
        REAL, INTENT(INOUT)                       :: DTCT
        real                                      :: minDTCT !BF minimum routing timestep
        REAL                                      :: dist(ixrt,jxrt,9)
        REAL                                      :: RETDEP_CHAN
        INTEGER, INTENT(IN)                       :: MAXORDER, SUBRTSWCRT, &
                                                     gwBaseSwCRT, gwChanCondSw
        real, intent(in)                          :: gwChanCondConstIn, gwChanCondConstOut ! aquifer-channel conductivity constant from namelist                                             
        REAL , INTENT(IN), DIMENSION(NLINKS)      :: node_area
        REAL, DIMENSION(:), INTENT(inout)           :: velocity


!DJG GW-chan coupling variables...
        REAL, DIMENSION(NLINKS)                   :: dzGwChanHead
        REAL, DIMENSION(NLINKS)                   :: Q_GW_CHAN_FLUX     !DJG !!! Change 'INTENT' to 'OUT' when ready to update groundwater state...
        REAL, DIMENSION(IXRT,JXRT)                :: ZWATTBLRT          !DJG !!! Match with subsfce/gw routing & Change 'INTENT' to 'INOUT' when ready to update groundwater state...
        REAL, INTENT(INOUT), DIMENSION(IXRT,JXRT) :: gwHead            !DJG !!! groundwater head from Fersch-2d gw implementation...units (m ASL)
        REAL, INTENT(INOUT), DIMENSION(IXRT,JXRT) :: qgw_chanrt         !DJG !!! Channel-gw flux as used in Fersch 2d gw implementation...units (m^3/s)...Change 'INTENT' to 'OUT' when ready to update groundwater state...
         


        !-- lake params
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: HRZAREA  !-- horizontal area (km^2)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: LAKEMAXH !-- maximum lake depth  (m^2)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: WEIRH    !-- lake depth  (m^2)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: WEIRC    !-- weir coefficient
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: WEIRL    !-- weir length (m)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: ORIFICEC !-- orrifice coefficient
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: ORIFICEA !-- orrifice area (m^2)
        REAL, INTENT(IN), DIMENSION(NLAKES)       :: ORIFICEE !-- orrifce elevation (m)

        REAL, INTENT(INOUT), DIMENSION(NLAKES)    :: RESHT    !-- reservoir height (m)
        REAL*8,  DIMENSION(NLAKES)    :: QLAKEI8   !-- lake inflow (cms)
        REAL, INTENT(INOUT), DIMENSION(NLAKES)    :: QLAKEI   !-- lake inflow (cms)
        REAL,                DIMENSION(NLAKES)    :: QLAKEIP  !-- lake inflow previous timestep (cms)
        REAL, INTENT(INOUT), DIMENSION(NLAKES)    :: QLAKEO   !-- outflow from lake used in diffusion scheme
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: LAKENODE !-- outflow from lake used in diffusion scheme
        INTEGER, INTENT(IN), DIMENSION(NLINKS)    :: LINKID   !--  id of channel elements for linked scheme
        !REAL, DIMENSION(NLINKS)                   :: QLateral !--lateral flow
        REAL, DIMENSION(NLINKS)                   :: QSUM     !--mass bal of node
        REAL*8, DIMENSION(NLINKS)                   :: QSUM8     !--mass bal of node
        REAL, DIMENSION(NLAKES)                   :: QLLAKE   !-- lateral inflow to lake in diffusion scheme
        REAL*8, DIMENSION(NLAKES)                   :: QLLAKE8   !-- lateral inflow to lake in diffusion scheme

!-- Local Variables
        INTEGER                     :: i,j,k,t,m,jj,kk,KRT,node
        INTEGER                     :: DT_STEPS               !-- number of timestep in routing
        REAL                        :: Qup,Quc                !--Q upstream Previous, Q Upstream Current, downstream Previous
        REAL                        :: bo                     !--critical depth, bnd outflow just for testing
        REAL                        :: AREA,WP                !--wetted area and perimiter for MuskingC. routing

        REAL ,DIMENSION(NLINKS)     :: HLINKTMP,CVOLTMP       !-- temporarily store head values and volume values
        REAL ,DIMENSION(NLINKS)     :: CD                     !-- critical depth
        real, DIMENSION(IXRT,JXRT)  :: tmp
        real, dimension(nlinks)     :: tmp2

        integer lake_index(nlakes)
        integer nlinks_index(nlinks)
        integer mpp_nlinks, iyw, yw_mpp_nlinks
        integer link_location(ixrt,jxrt)
        real     ywtmp(ixrt,jxrt)
        integer LNLINKSL
        integer, dimension(LNLINKSL) :: LLINKID
        real*8,  dimension(LNLINKSL) :: LQLateral
!        real*4,  dimension(LNLINKSL) :: LQLateral
        integer, dimension(:) ::  toNodeInd
        integer, dimension(:,:) ::  gtoNode
        integer  :: nToNodeInd
        real, dimension(nToNodeInd,2) :: gQLINK
        integer flag

        integer :: n, kk2, nt, nsteps  ! tmp 

        QLAKEIP = 0
        QLAKEI8 = 0
        HLINKTMP = 0
        CVOLTMP = 0
        CD = 0  
        node = 1
        QLateral = 0
        QSUM     = 0
        QLLAKE   = 0


!yw      print *, "DRIVE_channel,option,nlinkl,nlinks!!", channel_option,NLINKSL,NLINKS
!      print *, "DRIVE_channel, RESHT", RESHT

         
      dzGwChanHead = 0.

   IF(channel_option .ne. 3) then   !--muskingum methods ROUTE ON DT timestep, not DTRT!!

         nsteps = (DT+0.5)/DTRT_CH

         LQLateral = 0          !-- initial lateral flow to 0 for this reach
         DO iyw = 1,yw_MPP_NLINKS
         jj = nlinks_index(iyw)
          !--------river grid points, convert depth in mm to rate across reach in m^3/sec
              if( .not. (  (CHANXI(jj) .eq. 1 .and. left_id .ge. 0) .or. &
                           (CHANXI(jj) .eq. ixrt .and. right_id .ge. 0) .or. &
                           (CHANYJ(jj) .eq. 1 .and. down_id .ge. 0) .or. &
                           (CHANYJ(jj) .eq. jxrt .and. up_id .ge. 0)      &
                   ) ) then
                  if (CH_LNKRT_SL(CHANXI(jj),CHANYJ(jj)) .gt. 0) then
                     k = CH_LNKRT_SL(CHANXI(jj),CHANYJ(jj))
                     LQLateral(k) = LQLateral(k)+((QSTRMVOLRT(CHANXI(jj),CHANYJ(jj))+QINFLOWBASE(CHANXI(jj),CHANYJ(jj)))/1000 & 
                            *node_area(jj)/DT)
                  elseif ( (LAKE_MSKRT(CHANXI(jj),CHANYJ(jj)) .gt. 0)) then !-lake grid
                      k = LAKE_MSKRT(CHANXI(jj),CHANYJ(jj))
                      LQLateral(k) = LQLateral(k) +((LAKEINFLORT(CHANXI(jj),CHANYJ(jj))+QINFLOWBASE(CHANXI(jj),CHANYJ(jj)))/1000 &
                               *node_area(jj)/DT)
                  endif
              endif
         end do  ! jj


!   assign LQLATERAL to QLATERAL
       call updateLinkV(LQLateral, QLateral(1:NLINKSL))


!       QLateral = QLateral / nsteps

   do nt = 1, nsteps

 
!----------  route order 1 reaches which have no upstream inflow
!       do k=1, NLINKSL
!          if (ORDER(k) .eq. 1) then  !-- first order stream has no headflow


!             if(TYPEL(k) .eq. 1) then    !-- level pool route of reservoir
!                 !CALL LEVELPOOL(1,0.0, 0.0, qd, QLINK(k,2), QLateral(k), &
!                 ! DT, RESHT(k), HRZAREA(k), LAKEMAXH(k), &
!                 ! WEIRC(k), WEIRL(k), ORIFICEE(i), ORIFICEC(k), ORIFICEA(k) )
!             elseif (channel_option .eq. 1) then
!                  Km  = MUSK(k)
!                  X   = MUSX(k)
!                  QLINK(k,2) = MUSKING(k,0.0, QLateral(k), QLINK(k,1), DTRT_CH, Km, X) !--current outflow
!             elseif (channel_option .eq. 2) then !-- upstream is assumed constant initial condition

!                  call SUBMUSKINGCUNGE(QLINK(k,2), velocity(k), k,  &
!                   0.0,0.0, QLINK(k,1), QLateral(k),   DTRT_CH, So(k), &
!                   CHANLEN(k), MannN(k), ChSSlp(k), Bw(k) )

!             else
!                 print *, "FATAL ERROR: No channel option selected"
!                 call hydro_stop("In drive_CHANNEL() -No channel option selected ") 
!             endif
!          endif
!       end do

       gQLINK = 0
       call gbcastReal2(toNodeInd,nToNodeInd,QLINK(1:NLINKSL,2), NLINKSL, gQLINK(:,2))
       call gbcastReal2(toNodeInd,nToNodeInd,QLINK(1:NLINKSL,1), NLINKSL, gQLINK(:,1))

      !---------- route other reaches, with upstream inflow
       tmpQlink = 0
       do k = 1,NLINKSL
!         if (ORDER(k) .gt. 1 ) then  !-- exclude first order stream 
             Quc  = 0
             Qup  = 0

!using mapping index
               do n = 1, gtoNODE(k,1)
                  m = gtoNODE(k,n+1)
!yw                  if (LINKID(k) .eq. m) then
                    Quc = Quc + gQLINK(m,2)  !--accum of upstream inflow of current timestep (2)
                    Qup = Qup + gQLINK(m,1)  !--accum of upstream inflow of previous timestep (1)

                      !     if(LINKID(k) .eq. 3259 .or. LINKID(k) .eq. 3316 .or. LINKID(k) .eq. 3219) then
                      !       write(6,*) "id,Uc,Up",LINKID(k),Quc,Qup
                      !       call flush(6)
                      !     endif

!yw                  endif
                end do ! do i

                   
                if(TYPEL(k) .eq. 1) then   !--link is a reservoir

                   ! CALL LEVELPOOL(1,QLINK(k,1), Qup, QLINK(k,1), QLINK(k,2), &
                   !  QLateral(k), DT, RESHT(k), HRZAREA(k), LAKEMAXH(k), &
                   !  WEIRC(k), WEIRL(k),ORIFICEE(k),  ORIFICEC(k), ORIFICEA(k))

                elseif (channel_option .eq. 1) then  !muskingum routing
                       Km = MUSK(k)
                       X = MUSX(k)
                       tmpQLINK(k,2) = MUSKING(k,Qup,(Quc+QLateral(k)),QLINK(k,1),DTRT_CH,Km,X) !upstream plust lateral inflow 
                elseif (channel_option .eq. 2) then ! muskingum cunge

                   call SUBMUSKINGCUNGE(tmpQLINK(k,2), velocity(k), LINKID(k),  &
                    Qup,Quc, QLINK(k,1), QLateral(k),   DTRT_CH, So(k), &
                    CHANLEN(k), MannN(k), ChSSlp(k), Bw(k))
 
!                    if(LINKID(k) .eq. 24800) then 
!                      print *, "ZZ", ORDER(k),QLateral(k),QLINK(k,1), tmpQLINK(k,2)
!                     endif

                   else
                    print *, "FATAL ERROR: no channel option selected"
                    call hydro_stop("In drive_CHANNEL() - no channel option selected") 
                   endif
!           endif !!! order(1) .ne. 1
         end do       !--k links

          do k = 1, NLINKSL
            if(TYPEL(k) .ne. 1) then
               QLINK(k,2) = tmpQLINK(k,2)
            endif
            QLINK(k,1) = QLINK(k,2)    !assing link flow of current to be previous for next time step
         end do

   end do  ! nsteps


!    END DO !-- krt timestep for muksingumcunge routing

   elseif(channel_option .eq. 3) then   !--- route using the diffusion scheme on nodes not links

         call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,HLINK,NLINKS,99)
         call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,CVOL,NLINKS,99)

         KRT = 0                  !-- initialize the time counter
         minDTCT = 0.01           ! define minimum routing sub-timestep (s), simulation will end with smaller timestep
         DTCT = min(max(DTCT*2.0, minDTCT),DTRT_CH)
       
         HLINKTMP = HLINK         !-- temporary storage of the water elevations (m)
         CVOLTMP = CVOL           !-- temporary storage of the volume of water in channel (m^3)
         QLAKEIP = QLAKEI         !-- temporary lake inflow from previous timestep  (cms)

!        call check_channel(77,HLINKTMP,1,nlinks)
!        call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,ZELEV,NLINKS,99)
 crnt:   DO                      !-- loop on the courant condition
          QSUM     = 0.              !-- initialize the total flow out of each cell to zero
          QSUM8     = 0.              !-- initialize the total flow out of each cell to zero
          QLAKEI8  = 0.              !-- set the lake inflow as zero
          QLAKEI   = 0.              !-- set the lake inflow as zero
          QLLAKE   = 0.              !-- initialize each lake's lateral inflow to zero  
          QLLAKE8   = 0.              !-- initialize each lake's lateral inflow to zero  
          DT_STEPS = INT(DT/DTCT)   !-- fix the timestep
          QLateral = 0. 
!DJG GW-chan coupling variables...
          if(gwBaseSwCRT == 3) then
	  Q_GW_CHAN_FLUX = 0.
	  qgw_chanrt     = 0.
          end if
         
!         ZWATTBLRT=1.0   !--HARDWIRE, remove this and pass in from subsfc/gw routing routines...


!-- vectorize
!--------------------- 
         DO iyw = 1,yw_MPP_NLINKS
         i = nlinks_index(iyw)
          
           if(node_area(i) .eq. 0) then
               write(6,*) "FATAL ERROR: node_area(i) is zero. i=", i
               call hydro_stop("In drive_CHANNEL() - Error node_area") 
           endif

           

nodeType:if((CH_NETRT(CHANXI(i), CHANYJ(i) ) .eq. 0) .and. &
              (LAKE_MSKRT(CHANXI(i),CHANYJ(i)) .lt.0) ) then !--a reg. node
              
gwOption:   if(gwBaseSwCRT == 3) then

             ! determine potential gradient between groundwater head and channel stage
             ! units in (m)
             dzGwChanHead(i) = gwHead(CHANXI(i),CHANYJ(i)) - (HLINK(i)+ZELEV(i)) 

             if(gwChanCondSw .eq. 0) then
	       
                qgw_chanrt(CHANXI(i),CHANYJ(i)) = 0.
	        
             else if(gwChanCondSw .eq. 1 .and. dzGwChanHead(i) > 0) then
	       
	       ! channel bed interface, units in (m^3/s), flux into channel...
	       ! BF todo: consider channel width
                qgw_chanrt(CHANXI(i),CHANYJ(i)) = gwChanCondConstIn * dzGwChanHead(i) &
                                                * CHANLEN(i) * 2. 

             else if(gwChanCondSw .eq. 1 .and. dzGwChanHead(i) < 0) then
	       
	       ! channel bed interface, units in (m^3/s), flux out of channel...
	       ! BF todo: consider channel width
                qgw_chanrt(CHANXI(i),CHANYJ(i)) = max(-0.005, gwChanCondConstOut * dzGwChanHead(i) &
                                                * CHANLEN(i) * 2.)
!              else if(gwChanCondSw .eq. 2 .and. dzGwChanHead(i) > 0) then  TBD: exponential dependency
!              else if(gwChanCondSw .eq. 2 .and. dzGwChanHead(i) > 0) then
	       
             else
	       
	        qgw_chanrt(CHANXI(i),CHANYJ(i)) = 0.
	        
             end if
             
             Q_GW_CHAN_FLUX(i) = qgw_chanrt(CHANXI(i),CHANYJ(i))
!             if ( i .eq. 1001 ) then
!                print *, Q_GW_CHAN_FLUX(i), dzGwChanHead(i), ELRT(CHANXI(i),CHANYJ(i)), HLINK(i), ZELEV(i)
!             end if
!              if ( Q_GW_CHAN_FLUX(i) .lt. 0. ) then   !-- temporary hardwire for only allowing flux into channel...REMOVE later...
!                 Q_GW_CHAN_FLUX(i) = 0.
! 	        qgw_chanrt(CHANXI(i),CHANYJ(i)) = 0.
!              end if
            
            else
	      Q_GW_CHAN_FLUX(i) = 0.
	    end if gwOption


              QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))) =  &
!DJG  awaiting gw-channel exchg...  Q_GW_CHAN_FLUX(i)+& ...obsolete-> ((QSUBRT(CHANXI(i),CHANYJ(i))+&
                Q_GW_CHAN_FLUX(i)+&
                ((QSTRMVOLRT(CHANXI(i),CHANYJ(i))+&
                 QINFLOWBASE(CHANXI(i),CHANYJ(i))) &
                   /DT_STEPS*node_area(i)/1000/DTCT)
	       if((QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))).lt.0.) .and. (gwChanCondSw == 0)) then
               elseif (QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))) .gt. 1.0) then
!#ifdef HYDRO_D
!               print *, "LatIn(Ql,Qsub,Qstrmvol)..",i,QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))), &
!                          QSUBRT(CHANXI(i),CHANYJ(i)),QSTRMVOLRT(CHANXI(i),CHANYJ(i))
!#endif
               end if

         elseif(LAKE_MSKRT(CHANXI(i),CHANYJ(i)) .gt. 0 .and. &
!               (LAKE_MSKRT(CHANXI(i),CHANYJ(i)) .ne. -9999)) then !--a lake node
                (CH_NETRT(CHANXI(i),CHANYJ(i)) .le. 0)) then !--a lake node
              QLLAKE8(LAKE_MSKRT(CHANXI(i),CHANYJ(i))) = &
                 QLLAKE8(LAKE_MSKRT(CHANXI(i),CHANYJ(i))) + &
                 (LAKEINFLORT(CHANXI(i),CHANYJ(i))+ &
                 QINFLOWBASE(CHANXI(i),CHANYJ(i))) &
                 /DT_STEPS*node_area(i)/1000/DTCT
         elseif(CH_NETRT(CHANXI(i),CHANYJ(i)) .gt. 0) then  !pour out of lake
                 QLateral(CH_NETLNK(CHANXI(i),CHANYJ(i))) =  &
                   QLAKEO(CH_NETRT(CHANXI(i),CHANYJ(i)))  !-- previous timestep
         endif nodeType

        ENDDO


    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,QLateral,NLINKS,99)
    if(NLAKES .gt. 0) then
       !yw call MPP_CHANNEL_COM_REAL(LAKE_MSKRT   ,ixrt,jxrt,QLLAKE,NLAKES,99)
       call sum_real8(QLLAKE8,NLAKES)
       QLLAKE = QLLAKE8
    endif

          !-- compute conveyances, with known depths (just assign to QLINK(,1)
          !--QLINK(,2) will not be used), QLINK is the flow across the node face
          !-- units should be m3/second.. consistent with QL (lateral flow)

         DO iyw = 1,yw_MPP_NLINKS
         i = nlinks_index(iyw)
           if (TYPEL(i) .eq. 0 .AND. HLINKTMP(FROM_NODE(i)) .gt. RETDEP_CHAN) then 
               if(from_node(i) .ne. to_node(i) .and. (to_node(i) .gt. 0) .and.(from_node(i) .gt. 0) ) &  ! added by Wei Yu
                   QLINK(i,1)=DIFFUSION(i,ZELEV(FROM_NODE(i)),ZELEV(TO_NODE(i)), &
                     HLINKTMP(FROM_NODE(i)),HLINKTMP(TO_NODE(i)), &
                     CHANLEN(i), MannN(i), Bw(i), ChSSlp(i))
            else !--  we are just computing critical depth for outflow points
               QLINK(i,1) =0.
            endif
          ENDDO

    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,QLINK(:,1),NLINKS,99)
 

          !-- compute total flow across face, into node
         DO iyw = 1,yw_mpp_nlinks
         i = nlinks_index(iyw)
           if(TYPEL(i) .eq. 0) then                                       !-- only regular nodes have to attribute
              QSUM8(TO_NODE(i)) = QSUM8(TO_NODE(i)) + QLINK(i,1)
           endif
          END DO

    call MPP_CHANNEL_COM_REAL8(Link_location,ixrt,jxrt,qsum8,NLINKS,0)
    qsum = qsum8



         do iyw = 1,yw_mpp_nlinks
         i = nlinks_index(iyw)
            QSUM(FROM_NODE(i)) = QSUM(FROM_NODE(i)) - QLINK(i,1)
         end do
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,qsum,NLINKS,99)


         flag = 99


         do iyw = 1,yw_MPP_NLINKS
             i = nlinks_index(iyw)
 
           if( TYPEL(i).eq.0 .and. CVOLTMP(i) .ge. 0.001 .and.(CVOLTMP(i)-QSUM(i)*DTCT)/CVOLTMP(i) .le. -0.01 ) then  
            flag = -99
            
            goto 999  
            endif 
          enddo 

999 continue
        call mpp_same_int1(flag)


        if(flag < 0  .and. DTCT >0.1)   then   
             
             ! call smoth121(HLINK,nlinks,maxv_p,pnode,to_node)

             if(DTCT .gt. minDTCT) then                !-- timestep in seconds
              DTCT = max(DTCT/2 , minDTCT)             !-- 1/2 timestep
              KRT = 0                                  !-- restart counter
              HLINKTMP = HLINK                         !-- set head and vol to start value of timestep
              CVOLTMP = CVOL
              CYCLE crnt                               !-- start cycle over with smaller timestep
             else
              write(6,*) "Courant error with smallest routing timestep DTCT: ",DTCT
!              call hydro_stop("drive_CHANNEL")
              DTCT = 0.1
              HLINKTMP = HLINK                          !-- set head and volume to start values of timestep
              CVOLTMP  = CVOL
              goto 998  
             end if
        endif 

998 continue


        do iyw = 1,yw_MPP_NLINKS
            i = nlinks_index(iyw)
 
           if(TYPEL(i) .eq. 0) then                   !--  regular channel grid point, compute volume
              CVOLTMP(i) = CVOLTMP(i) + (QSUM(i) + QLateral(i) )* DTCT
              if((CVOLTMP(i) .lt. 0) .and. (gwChanCondSw == 0)) then 
                CVOLTMP(i) =0 
              endif

           elseif(TYPEL(i) .eq. 1) then               !-- pour point, critical depth downstream 

              if (QSUM(i)+QLateral(i) .lt. 0) then
              else

!DJG remove to have const. flux b.c....   CD(i) =CRITICALDEPTH(i,abs(QSUM(i)+QLateral(i)), Bw(i), 1./ChSSlp(i))
                  CD(i) = HLINKTMP(i)  !This is a temp hardwire for flow depth for the pour point...
              endif

               ! change in volume is inflow, lateral flow, and outflow 
               !yw DIFFUSION(i,ZELEV(i),ZELEV(i)-(So(i)*DXRT),HLINKTMP(i), &
                   CVOLTMP(i) = CVOLTMP(i) + (QSUM(i) + QLateral(i) - &
                       DIFFUSION(i,ZELEV(i),ZELEV(i)-(So(i)*CHANLEN(i)),HLINKTMP(i), &
                       CD(i),CHANLEN(i), MannN(i), Bw(i), ChSSlp(i)) ) * DTCT
          elseif (TYPEL(i) .eq. 2) then              !--- into a reservoir, assume critical depth
              if ((QSUM(i)+QLateral(i) .lt. 0) .and. (gwChanCondSw == 0)) then
             else
!DJG remove to have const. flux b.c....    CD(i) =CRITICALDEPTH(i,abs(QSUM(i)+QLateral(i)), Bw(i), 1./ChSSlp(i))
               CD(i) = HLINKTMP(i)  !This is a temp hardwire for flow depth for the pour point...
             endif
 
              !-- compute volume in reach (m^3)
                   CVOLTMP(i) = CVOLTMP(i) + (QSUM(i) + QLateral(i) - &
                          DIFFUSION(i,ZELEV(i),ZELEV(i)-(So(i)*CHANLEN(i)),HLINKTMP(i), &
                             CD(i) ,CHANLEN(i), MannN(i), Bw(i), ChSSlp(i)) ) * DTCT
          else
              print *, "FATAL ERROR: This node does not have a type.. error TYPEL =", TYPEL(i)
              call hydro_stop("In drive_CHANNEL() - error TYPEL") 
          endif
           
          if(TYPEL(i) == 0) then !-- regular channel node, finalize head and flow
              HLINKTMP(i) = HEAD(i, CVOLTMP(i)/CHANLEN(i),Bw(i),1/ChSSlp(i))  !--updated depth 
          else
              HLINKTMP(i) = CD(i)  !!!   CRITICALDEPTH(i,QSUM(i)+QLateral(i), Bw(i), 1./ChSSlp(i)) !--critical depth is head
          endif 

          if(TO_NODE(i) .gt. 0) then
             if(LAKENODE(TO_NODE(i)) .gt. 0) then
                  QLAKEI8(LAKENODE(TO_NODE(i))) = QLAKEI8(LAKENODE(TO_NODE(i))) + QLINK(i,1)
             endif
          endif

        END DO  !--- done processing all the links

    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,CVOLTMP,NLINKS,99)
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,CD,NLINKS,99)
    if(NLAKES .gt. 0) then
!       call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLAKEI,NLAKES,99)
        call sum_real8(QLAKEI8,NLAKES)
        QLAKEI = QLAKEI8
    endif
    call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,HLINKTMP,NLINKS,99)
!   call check_channel(83,CVOLTMP,1,nlinks)
!   call check_channel(84,CD,1,nlinks)
!   call check_channel(85,HLINKTMP,1,nlinks)
!   call check_lake(86,QLAKEI,lake_index,nlakes)

           do i = 1, NLAKES !-- mass balances of lakes
            if(lake_index(i) .gt. 0)  then
              CALL LEVELPOOL(i,QLAKEIP(i), QLAKEI(i), QLAKEO(i), QLLAKE(i), &
                DTCT, RESHT(i), HRZAREA(i), WEIRH(i), LAKEMAXH(i), WEIRC(i), &
                WEIRL(i), ORIFICEE(i), ORIFICEC(i), ORIFICEA(i))
                QLAKEIP(i) = QLAKEI(i)  !-- store total lake inflow for this timestep

            endif
           enddo
    if(NLAKES .gt. 0) then
!yw       call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLLAKE,NLAKES,99)
!yw       call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,RESHT,NLAKES,99)
!yw      call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLAKEO,NLAKES,99)
!yw      call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLAKEI,NLAKES,99)
!yw      call MPP_CHANNEL_COM_REAL(LAKE_MSKRT,ixrt,jxrt,QLAKEIP,NLAKES,99)
         call updateLake_grid(QLLAKE, nlakes,lake_index)
         call updateLake_grid(RESHT,  nlakes,lake_index)
         call updateLake_grid(QLAKEO, nlakes,lake_index)
         call updateLake_grid(QLLAKE, nlakes,lake_index)
         call updateLake_grid(QLAKEIP,nlakes,lake_index)
    endif


         do iyw = 1,yw_MPP_NLINKS
            i = nlinks_index(iyw)
            if(TYPEL(i) == 0) then !-- regular channel node, finalize head and flow
                   QLINK(i,1)=DIFFUSION(i,ZELEV(FROM_NODE(i)),ZELEV(TO_NODE(i)), &
                      HLINKTMP(FROM_NODE(i)),HLINKTMP(TO_NODE(i)), &
                      CHANLEN(i), MannN(i), Bw(i), ChSSlp(i))
            endif
         enddo

          call MPP_CHANNEL_COM_REAL(Link_location,ixrt,jxrt,QLINK(:,1),NLINKS,99)

           KRT = KRT + 1                     !-- iterate on the timestep
           if(KRT .eq. DT_STEPS) exit crnt   !-- up to the maximum time in interval

          end do crnt   !--- DTCT timestep of DT_STEPS
 
           HLINK = HLINKTMP                 !-- update head based on final solution in timestep
           CVOL  = CVOLTMP                  !-- update volume
        else                                !-- no channel option apparently selected
         print *, "FATAL ERROR: no channel option selected"
         call hydro_stop("In drive_CHANNEL() - no channel option selected") 
        endif


        if (KT .eq. 1) KT = KT + 1
         

end subroutine drive_CHANNEL
! ----------------------------------------------------------------

!-=======================================
     REAL FUNCTION AREAf(AREA,Bw,h,z)
     REAL :: AREA, Bw, z, h
       AREAf = (Bw+z*h)*h-AREA       !-- Flow area
     END FUNCTION AREAf

!-====critical depth function  ==========
     REAL FUNCTION CDf(Q,Bw,h,z)
     REAL :: Q, Bw, z, h
       if(h .le. 0) then
         print *, "FATAL ERROR: head is zero, will get division by zero error"
         call hydro_stop("In CDf() - head is zero") 
       else
       CDf = (Q/((Bw+z*h)*h))/(sqrt(9.81*(((Bw+z*h)*h)/(Bw+2*z*h))))-1  !--critical depth function
       endif
     END FUNCTION CDf

!=======find flow depth in channel with bisection Chapra pg. 131
    REAL FUNCTION HEAD(idx,AREA,Bw,z)  !-- find the water elevation given wetted area, 
                                         !--bottom widith and side channel.. index was for debuggin
     REAL :: Bw,z,AREA,test           
     REAL :: hl, hu, hr, hrold
     REAL :: fl, fr,error                !-- function evaluation
     INTEGER :: maxiter, idx

     error = 1.0
     maxiter = 0
     hl = 0.00001   !-- minimum depth is small
     hu = 30.  !-- assume maximum depth is 30 meters

    if (AREA .lt. 0.00001) then 
     hr = 0.
    else
      do while ((AREAf(AREA,BW,hl,z)*AREAf(AREA,BW,hu,z)).gt.0 .and. maxiter .lt. 100) 
       !-- allows for larger , smaller heads 
       if(AREA .lt. 1.) then
        hl=hl/2
       else
        hu = hu * 2
       endif
       maxiter = maxiter + 1
        
      end do

      maxiter =0
      hr = 0
      fl = AREAf(AREA,Bw,hl,z)
      do while (error .gt. 0.0001 .and. maxiter < 1000)
        hrold = hr
        hr = (hl+hu)/2
        fr =  AREAf(AREA,Bw,hr,z)
        maxiter = maxiter + 1
         if (hr .ne. 0) then
          error = abs((hr - hrold)/hr)
         endif
        test = fl * fr
         if (test.lt.0) then
           hu = hr
         elseif (test.gt.0) then
           hl=hr
           fl = fr
         else
           error = 0.0
         endif
      end do
     endif
     HEAD = hr

22   format("i,hl,hu,Area",i5,2x,f12.8,2x,f6.3,2x,f6.3,2x,f6.3,2x,f9.1,2x,i5)

    END FUNCTION HEAD
!=================================
     REAL FUNCTION MANNING(h1,n,Bw,Cs)

     REAL :: Bw,h1,Cs,n
     REAL :: z, AREA,R,Kd

     z=1/Cs
     R = ((Bw+z*h1)*h1)/(Bw+2*h1*sqrt(1+z*z)) !-- Hyd Radius
     AREA = (Bw+z*h1)*h1        !-- Flow area
     Kd = (1/n)*(R**(2./3.))*AREA     !-- convenyance
     MANNING = Kd
     
     END FUNCTION MANNING

!=======find flow depth in channel with bisection Chapra pg. 131
     REAL FUNCTION CRITICALDEPTH(lnk,Q,Bw,z)  !-- find the critical depth
     REAL :: Bw,z,Q,test
     REAL :: hl, hu, hr, hrold
     REAL :: fl, fr,error   !-- function evaluation
     INTEGER :: maxiter
     INTEGER :: lnk

     error = 1.0
     maxiter = 0
     hl = 1e-5   !-- minimum depth is 0.00001 meters
!    hu = 35.       !-- assume maximum  critical depth 25 m
     hu = 100.       !-- assume maximum  critical depth 25 m

     if(CDf(Q,BW,hl,z)*CDf(Q,BW,hu,z) .gt. 0) then
      if(Q .gt. 0.001) then
      else
        Q = 0.0
      endif
     endif

     hr = 0.
     fl = CDf(Q,Bw,hl,z)

     if (Q .eq. 0.) then
       hr = 0.
     else
      do while (error .gt. 0.0001 .and. maxiter < 1000)
        hrold = hr
        hr = (hl+hu)/2
        fr =  CDf(Q,Bw,hr,z)
        maxiter = maxiter + 1
         if (hr .ne. 0) then
          error = abs((hr - hrold)/hr)
         endif
        test = fl * fr
         if (test.lt.0) then
           hu = hr
         elseif (test.gt.0) then
           hl=hr
           fl = fr
         else
           error = 0.0
         endif

       end do
      endif

     CRITICALDEPTH = hr

     END FUNCTION CRITICALDEPTH
!================================================
     REAL FUNCTION SGNf(val)  !-- function to return the sign of a number
     REAL:: val

     if (val .lt. 0) then
       SGNf= -1.
     elseif (val.gt.0) then
       SGNf= 1.
     else
       SGNf= 0.
     endif

     END FUNCTION SGNf
!================================================

     REAL FUNCTION fnDX(qp,Tw,So,Ck,dx,dt) !-- find channel sub-length for MK method
     REAL    :: qp,Tw,So,Ck,dx, dt,test
     REAL    :: dxl, dxu, dxr, dxrold
     REAL    :: fl, fr, error
     REAL    :: X
     INTEGER :: maxiter

     error = 1.0
     maxiter =0
     dxl = dx*0.9  !-- how to choose dxl???
     dxu = dx
     dxr=0

     do while (fnDXCDT(qp,Tw,So,Ck,dxl,dt)*fnDXCDT(qp,Tw,So,Ck,dxu,dt) .gt. 0 &
               .and. dxl .gt. 10)  !-- don't let dxl get too small
      dxl = dxl/1.1
     end do
     
      
     fl = fnDXCDT(qp,Tw,So,Ck,dxl,dt)
     do while (error .gt. 0.0001 .and. maxiter < 1000)
        dxrold = dxr
        dxr = (dxl+dxu)/2
        fr =  fnDXCDT(qp,Tw,So,Ck,dxr,dt)
        maxiter = maxiter + 1
         if (dxr .ne. 0) then
          error = abs((dxr - dxrold)/dxr)
         endif
        test = fl * fr
         if (test.lt.0) then
           dxu = dxr
         elseif (test.gt.0) then
           dxl=dxr
           fl = fr
         else
           error = 0.0
         endif
      end do
     FnDX = dxr

    END FUNCTION fnDX
!================================================
     REAL FUNCTION fnDXCDT(qp,Tw,So,Ck,dx,dt) !-- function to help find sub-length for MK method
     REAL    :: qp,Tw,So,Ck,dx,dt,X
     REAL    :: c,b  !-- coefficients on dx/cdt log approximation function
     
     c = 0.2407
     b = 1.16065
     X = 0.5-(qp/(2*Tw*So*Ck*dx))
     if (X .le.0) then 
      fnDXCDT = -1 !0.115
     else
      fnDXCDT = (dx/(Ck*dt)) - (c*LOG(X)+b)  !-- this function needs to converge to 0
     endif
     END FUNCTION fnDXCDT
! ----------------------------------------------------------------------

    subroutine check_lake(unit,cd,lake_index,nlakes)
         use module_RT_data, only: rt_domain
         implicit none 
         integer :: unit,nlakes,i,lake_index(nlakes)
         real cd(nlakes)
         call write_lake_real(cd,lake_index,nlakes)
         write(unit,*) cd
          call flush(unit)
         return
    end subroutine check_lake

    subroutine check_channel(unit,cd,did,nlinks)
         use module_RT_data, only: rt_domain
  USE module_mpp_land
         implicit none 
         integer :: unit,nlinks,i, did
         real cd(nlinks)
         real g_cd(rt_domain(did)%gnlinks)
         call write_chanel_real(cd,rt_domain(did)%map_l2g,rt_domain(did)%gnlinks,nlinks,g_cd)
         if(my_id .eq. IO_id) then
            write(unit,*) "rt_domain(did)%gnlinks = ",rt_domain(did)%gnlinks
           write(unit,*) g_cd
         endif
          call flush(unit)
          close(unit)
         return
    end subroutine check_channel
    subroutine smoth121(var,nlinks,maxv_p,from_node,to_node)
        implicit none
        integer,intent(in) ::  nlinks, maxv_p
        integer, intent(in), dimension(nlinks):: to_node
        integer, intent(in), dimension(nlinks):: from_node(nlinks,maxv_p)
        real, intent(inout), dimension(nlinks) :: var
        real, dimension(nlinks) :: vartmp
        integer :: i,j  , k, from,to
        integer :: plen
              vartmp = 0
              do i = 1, nlinks
                 to = to_node(i)
                 plen = from_node(i,1)
                 if(plen .gt. 1) then 
                     do k = 1, plen-1 
                         from = from_node(i,k+1)
                         if(to .gt. 0) then
                            vartmp(i) = vartmp(i)+0.25*(var(from)+2.*var(i)+var(to))
                         else
                            vartmp(i) = vartmp(i)+(2.*var(i)+var(from))/3.0
                         endif
                     end do
                     vartmp(i) = vartmp(i) /(plen-1)
                 else
                         if(to .gt. 0) then
                            vartmp(i) = vartmp(i)+(2.*var(i)+var(to)/3.0)
                         else
                            vartmp(i) = var(i)
                         endif
                 endif
              end do
              var = vartmp 
        return
    end subroutine smoth121

!   SUBROUTINE drive_CHANNEL for NHDPLUS
! ------------------------------------------------

     subroutine drive_CHANNEL_RSL(UDMP_OPT,KT, IXRT,JXRT,  &
        LAKEINFLORT, QSTRMVOLRT, TO_NODE, FROM_NODE, &
        TYPEL, ORDER, MAXORDER,   CH_LNKRT, &
        LAKE_MSKRT, DT, DTCT, DTRT_CH,MUSK, MUSX, QLINK, &
        CHANLEN, MannN, So, ChSSlp, Bw, &
        RESHT, HRZAREA, LAKEMAXH, WEIRH, WEIRC, WEIRL, ORIFICEC, ORIFICEA, &
        ORIFICEE,  CVOL, QLAKEI, QLAKEO, LAKENODE, &
        QINFLOWBASE, CHANXI, CHANYJ, channel_option,  &
        nlinks,NLINKSL, LINKID, node_area, qout_gwsubbas, &
        LAKEIDA, LAKEIDM, NLAKES, LAKEIDX, &
        nlinks_index,mpp_nlinks,yw_mpp_nlinks, &
        LNLINKSL, &
        gtoNode,toNodeInd,nToNodeInd,   &
         CH_LNKRT_SL, landRunOff  & 
       , accSfcLatRunoff, accBucket                  &
       , qSfcLatRunoff,     qBucket                  &
       , QLateral, velocity &
       , nsize , OVRTSWCRT, SUBRTSWCRT, channel_only, channelBucket_only)

       use module_UDMAP, only: LNUMRSL, LUDRSL
       use module_namelist, only:  nlst_rt 



       implicit none

! -------- DECLARATIONS ------------------------

       integer, intent(IN) :: IXRT,JXRT,channel_option, OVRTSWCRT, SUBRTSWCRT
       integer, intent(IN) :: NLAKES, NLINKSL, nlinks
       integer, intent(INOUT) :: KT   ! flag of cold start (1) or continue run.
       real, intent(IN), dimension(IXRT,JXRT)    :: QSTRMVOLRT
       real, intent(IN), dimension(IXRT,JXRT)    :: LAKEINFLORT
       real, intent(IN), dimension(IXRT,JXRT)    :: QINFLOWBASE
       real, dimension(ixrt,jxrt) :: landRunOff
       
       integer, intent(IN), dimension(IXRT,JXRT) :: CH_LNKRT
       integer, intent(IN), dimension(IXRT,JXRT) :: CH_LNKRT_SL
       
       integer, intent(IN), dimension(IXRT,JXRT) :: LAKE_MSKRT
       integer, intent(IN), dimension(:)         :: ORDER, TYPEL !--link
       integer, intent(IN), dimension(:)     :: TO_NODE, FROM_NODE
       integer, intent(IN), dimension(:)     :: CHANXI, CHANYJ
       real, intent(IN), dimension(:)        :: MUSK, MUSX
       real, intent(IN), dimension(:)        :: CHANLEN
       real, intent(IN), dimension(:)        :: So, MannN
       real, intent(IN), dimension(:)        :: ChSSlp,Bw  !--properties of nodes or links
       real                                      :: Km, X
       real , intent(INOUT), dimension(:,:)  :: QLINK

       real, dimension(:), intent(inout)     :: QLateral !--lateral flow
       real, dimension(:), intent(out)       :: velocity
       real*8, dimension(:), intent(inout)     :: accSfcLatRunoff, accBucket 
       real  , dimension(:), intent(out)     :: qSfcLatRunoff  ,   qBucket
              
       real ,  dimension(NLINKSL,2) :: tmpQLINK
       real, intent(IN)                          :: DT    !-- model timestep
       real, intent(IN)                          :: DTRT_CH  !-- routing timestep
       real, intent(INOUT)                       :: DTCT
       real                                      :: minDTCT !BF minimum routing timestep
       integer, intent(IN)                       :: MAXORDER
       real , intent(IN), dimension(:)   :: node_area
       
       !DJG GW-chan coupling variables...
       real, dimension(NLINKS)                   :: dzGwChanHead
       real, dimension(NLINKS)                   :: Q_GW_CHAN_FLUX     !DJG !!! Change 'INTENT' to 'OUT' when ready to update groundwater state...
       real, dimension(IXRT,JXRT)                :: ZWATTBLRT          !DJG !!! Match with subsfce/gw routing & Change 'INTENT' to 'INOUT' when ready to update groundwater state...
       
       !-- lake params
       
       real, intent(IN), dimension(:)       :: HRZAREA  !-- horizontal area (km^2)
       real, intent(IN), dimension(:)       :: LAKEMAXH !-- maximum lake depth  (m^2)
       real, intent(IN), dimension(:)       :: WEIRH    !--  lake depth  (m^2)
       real, intent(IN), dimension(:)       :: WEIRC    !-- weir coefficient
       real, intent(IN), dimension(:)       :: WEIRL    !-- weir length (m)
       real, intent(IN), dimension(:)       :: ORIFICEC !-- orrifice coefficient
       real, intent(IN), dimension(:)       :: ORIFICEA !-- orrifice area (m^2)
       real, intent(IN), dimension(:)       :: ORIFICEE !-- orrifce elevation (m)
       integer, intent(IN), dimension(:)    :: LAKEIDM  !-- NHDPLUS lakeid for lakes to be modeled
       
       real, intent(INOUT), dimension(:)    :: RESHT    !-- reservoir height (m)
       real, intent(INOUT), dimension(:)    :: QLAKEI   !-- lake inflow (cms)
       real,                dimension(NLAKES)    :: QLAKEIP  !-- lake inflow previous timestep (cms)
       real, intent(INOUT), dimension(NLAKES)    :: QLAKEO   !-- outflow from lake used in diffusion scheme
       
       integer, intent(IN), dimension(:)    :: LAKENODE !-- outflow from lake used in diffusion scheme
       integer, intent(IN), dimension(:)   :: LINKID   !--  id of channel elements for linked scheme
       integer, intent(IN), dimension(:)   :: LAKEIDA  !--  (don't need) NHDPLUS lakeid for all lakes in domain
       integer, intent(IN), dimension(:)   :: LAKEIDX  !--  the sequential index of the lakes id by com id
       
       real, dimension(NLINKS)                   :: QSUM     !--mass bal of node
       real, dimension(NLAKES)                   :: QLLAKE   !-- lateral inflow to lake in diffusion scheme
       integer :: nsize
       
       !-- Local Variables
       integer                      :: i,j,k,t,m,jj,ii,lakeid, kk,KRT,node, UDMP_OPT
       integer                      :: DT_STEPS               !-- number of timestep in routing
       real                         :: Qup,Quc                !--Q upstream Previous, Q Upstream Current, downstream Previous
       real                         :: bo                     !--critical depth, bnd outflow just for testing
       
       real ,dimension(NLINKS)                          :: CD    !-- critical depth
       real, dimension(IXRT,JXRT)                       :: tmp
       real, dimension(nlinks)                          :: tmp2
       real, intent(INOUT), dimension(:)           :: CVOL
       
       real*8,  dimension(LNLINKSL) :: LQLateral
       real*8,  dimension(LNLINKSL) :: tmpLQLateral
       real,  dimension(NLINKSL)    :: tmpQLateral

       integer nlinks_index(:)
       integer  iyw, yw_mpp_nlinks, mpp_nlinks
       real     ywtmp(ixrt,jxrt)
       integer LNLINKSL
       integer, dimension(:)         ::  toNodeInd
       integer, dimension(:,:)       ::  gtoNode
       integer  :: nToNodeInd
       real, dimension(nToNodeInd,2) :: gQLINK
       integer flag
       integer, intent(in) :: channel_only, channelBucket_only
       
       integer :: n, kk2, nt, nsteps  ! tmp 
       real, intent(in), dimension(:) :: qout_gwsubbas
       real, allocatable,dimension(:) :: tmpQLAKEO, tmpQLAKEI, tmpRESHT
       
       if(my_id .eq. io_id) then
            allocate(tmpQLAKEO(NLAKES))
            allocate(tmpQLAKEI(NLAKES))
            allocate(tmpRESHT(NLAKES))
        endif

        QLAKEIP = 0
        CD = 0  
        node = 1
        QSUM     = 0
        QLLAKE   = 0
        dzGwChanHead = 0.
        nsteps = (DT+0.5)/DTRT_CH



!---------------------------------------------
if(channel_only .eq. 1 .or. channelBucket_only .eq. 1) then
   
!   if(nlst_rt(1)%output_channelBucket_influx .eq. 1 .or. &
!        nlst_rt(1)%output_channelBucket_influx .eq. 2       ) &
!        !! qScfLatRunoff = qLateral - qBucket
!        qSfcLatRunoff(1:NLINKSL) = qLateral(1:NLINKSL) - qout_gwsubbas(1:NLINKSL)

   if(nlst_rt(1)%output_channelBucket_influx .eq. 1 .or. &
      nlst_rt(1)%output_channelBucket_influx .eq. 2       ) then

      if(channel_only .eq. 1) &
        !! qScfLatRunoff = qLateral - qBucket
        qSfcLatRunoff(1:NLINKSL) = qLateral(1:NLINKSL) - qout_gwsubbas(1:NLINKSL)

      if(channelBucket_only .eq. 1) &
        !! qScfLatRunoff = qLateral - qBucket
        qSfcLatRunoff(1:NLINKSL) = qLateral(1:NLINKSL)

   end if
   
   if(nlst_rt(1)%output_channelBucket_influx .eq. 3) &
        accSfcLatRunoff(1:NLINKSL) = qSfcLatRunoff * DT

else

   QLateral = 0 !! the variable solved in this section. Channel only knows this already.
   LQLateral = 0          !-- initial lateral flow to 0 for this reach

   tmpQLateral = 0  !! WHY DOES THIS tmp variable EXIST?? Only for accumulations??
   tmpLQLateral = 0

   ! NHDPLUS maping
   if(OVRTSWCRT .eq. 0)      then
      do k = 1, LNUMRSL
         ! get from land grid runoff
         do m = 1, LUDRSL(k)%ncell  
            ii =  LUDRSL(k)%cell_i(m)
            jj =  LUDRSL(k)%cell_j(m)
            LQLateral(k) = LQLateral(k)+landRunOff(ii,jj)*LUDRSL(k)%cellweight(m)/1000 & 
                 *LUDRSL(k)%cellArea(m)/DT
            tmpLQLateral(k) = tmpLQLateral(k)+landRunOff(ii,jj)*LUDRSL(k)%cellweight(m)/1000 & 
                 *LUDRSL(k)%cellArea(m)/DT
         end do
      end do

      call updateLinkV(tmpLQLateral, tmpQLateral)
      if(NLINKSL .gt. 0) then
         if (nlst_rt(1)%output_channelBucket_influx .eq. 1 .or. &
             nlst_rt(1)%output_channelBucket_influx .eq. 2      ) &
               qSfcLatRunoff(1:NLINKSL) = tmpQLateral(1:NLINKSL)
         if (nlst_rt(1)%output_channelBucket_influx .eq. 3) &
              accSfcLatRunoff(1:NLINKSL) = accSfcLatRunoff(1:NLINKSL) + tmpQLateral(1:NLINKSL) * DT
      endif
      tmpLQLateral = 0  !! JLM:: These lines imply that squeege runoff does not count towards 
      tmpQLateral = 0   !! JLM:: accumulated runoff to be output but it does for internal QLateral?
      !! JLM: But then the next accumulation is added to the amt before zeroing? result
      !! JLM: should be identical to LQLateral.... I'm totally mystified.
   endif

   !! JLM:: if ovrtswcrt=0 and subrtswcrt=1, then this accumulation is calculated twice for LQLateral???
   !! This impiles that if overland routing is off and subsurface routing is on, that
   !! qstrmvolrt represents only the subsurface contribution to the channel.
   if(OVRTSWCRT .ne. 0 .or. SUBRTSWCRT .ne. 0 ) then
      do k = 1, LNUMRSL
         ! get from channel grid
         do m = 1, LUDRSL(k)%ngrids
            ii =  LUDRSL(k)%grid_i(m)
            jj =  LUDRSL(k)%grid_j(m)
            LQLateral(k) = LQLateral(k) + QSTRMVOLRT(ii,jj)*LUDRSL(k)%weight(m)/1000 & 
                 *LUDRSL(k)%nodeArea(m)/DT
            tmpLQLateral(k) = tmpLQLateral(k) + QSTRMVOLRT(ii,jj)*LUDRSL(k)%weight(m)/1000 & 
                 *LUDRSL(k)%nodeArea(m)/DT
         end do
      end do

      call updateLinkV(tmpLQLateral, tmpQLateral)

      !! JLM:: again why output in this conditional ?? why not just output QLateral
      !! after this section ????
      if(NLINKSL .gt. 0) then 
         if(nlst_rt(1)%output_channelBucket_influx .eq. 1 .OR. &
            nlst_rt(1)%output_channelBucket_influx .eq. 2       ) &
              qSfcLatRunoff(1:NLINKSL) = tmpQLateral(1:NLINKSL)
         if(nlst_rt(1)%output_channelBucket_influx .eq. 3) &
              accSfcLatRunoff(1:NLINKSL) = accSfcLatRunoff(1:NLINKSL) + tmpQLateral(1:NLINKSL) * DT
      end if

   endif

   call updateLinkV(LQLateral, QLateral(1:NLINKSL))
endif !! (channel_only .eq. 1 .or. channelBucket_only .eq. 1) then; else; endif


!---------------------------------------------
!! If not running channelOnly, here is where the bucket model is picked up
if(channel_only .eq. 1) then
else
   !! REQUIRE BUCKET MODEL ON HERE?
   if(NLINKSL .gt. 0) QLateral(1:NLINKSL) = QLateral(1:NLINKSL) + qout_gwsubbas(1:NLINKSL)
endif  !! if(channel_only .eq. 1) then; else; endif

if(nlst_rt(1)%output_channelBucket_influx .eq. 1 .or. &
   nlst_rt(1)%output_channelBucket_influx .eq. 2       ) &
      qBucket(1:NLINKSL) = qout_gwsubbas(1:NLINKSL)
   
if(nlst_rt(1)%output_channelBucket_influx .eq. 3) &
     accBucket(1:NLINKSL) = accBucket(1:NLINKSL) + qout_gwsubbas(1:NLINKSL) * DT


!---------------------------------------------
!       QLateral = QLateral / nsteps
do nt = 1, nsteps
   
   gQLINK = 0
   call gbcastReal2(toNodeInd,nToNodeInd,QLINK(1:NLINKSL,2), NLINKSL, gQLINK(:,2))
   call gbcastReal2(toNodeInd,nToNodeInd,QLINK(1:NLINKSL,1), NLINKSL, gQLINK(:,1)) 
   !---------- route other reaches, with upstream inflow
   
   tmpQlink = 0
   if(my_id .eq. io_id) then
      tmpQLAKEO = QLAKEO
      tmpQLAKEI = QLAKEI
      tmpRESHT = RESHT
   endif
   
   
   do k = 1,NLINKSL
      
      Quc  = 0
      Qup  = 0
      
      !process as standard link or a lake inflow link, or lake outflow link
      ! link flowing out of lake, accumulate all the inflows with the revised TO_NODEs
      ! TYPEL = -999 stnd; TYPEL=1 outflow from lake; TYPEL = 3 inflow to a lake
      
      if(TYPEL(k) .ne. 2) then ! don't process internal lake links only
         
         !using mapping index
         do n = 1, gtoNODE(k,1)
            m = gtoNODE(k,n+1)
            !! JLM - I think gQLINK(,2) is actually previous. Global array never sees current. Seeing
            !! current would require global communication at the end of each loop through k
            !! (=kth reach). Additionally, how do you synchronize to make sure the upstream are all
            !! done before doing the downstream?
            if(gQLINK(m,2) .gt. 0)   Quc = Quc + gQLINK(m,2)  !--accum of upstream inflow of current timestep (2)  
            if(gQLINK(m,1) .gt. 0)   Qup = Qup + gQLINK(m,1)  !--accum of upstream inflow of previous timestep (1)
         end do ! do i
      endif !note that we won't process type 2 links, since they are internal to a lake
      
      
      !yw ### process each link k,
      !       There is a situation that different k point to the same LAKEIDX
      !        if(TYPEL(k) .eq. 1 .and. LAKEIDX(k) .gt. 0) then   !--link is a reservoir
      if(TYPEL(k) .eq. 1 ) then   !--link is a reservoir
         
         lakeid = LAKEIDX(k)
         if(lakeid .ge. 0) then
            call LEVELPOOL(lakeid,Qup, Quc, tmpQLINK(k,2), &
                 QLateral(k), DTRT_CH, RESHT(lakeid), HRZAREA(lakeid), WEIRH(lakeid), LAKEMAXH(lakeid), &
                 WEIRC(lakeid), WEIRL(lakeid),ORIFICEE(lakeid), ORIFICEC(lakeid), ORIFICEA(lakeid))
            
            QLAKEO(lakeid)  = tmpQLINK(k,2) !save outflow to lake
            QLAKEI(lakeid)  = Quc           !save inflow to lake
         endif
105      continue
         
         
      elseif (channel_option .eq. 1) then  !muskingum routing
         Km = MUSK(k)
         X = MUSX(k)
         tmpQLINK(k,2) = MUSKING(k,Qup,(Quc+QLateral(k)),QLINK(k,1),DTRT_CH,Km,X) !upstream plust lateral inflow 
         
      elseif (channel_option .eq. 2) then ! muskingum cunge, don't process internal lake nodes TYP=2
         !              tmpQLINK(k,2) = MUSKINGCUNGE(k,Qup, Quc, QLINK(k,1), &
         !                  QLateral(k), DTRT_CH, So(k),  CHANLEN(k), &
         !                  MannN(k), ChSSlp(k), Bw(k) )
         
         
         call SUBMUSKINGCUNGE(&
              tmpQLINK(k,2), velocity(k), LINKID(k),     Qup,        Quc, QLINK(k,1), &
              QLateral(k),   DTRT_CH,     So(k), CHANLEN(k),                  &
              MannN(k),      ChSSlp(k),   Bw(k)                                )
         
      else
         call hydro_stop("drive_CHANNEL") 
      endif
      
   end do  !--k links
   
   
   call updateLake_seq(QLAKEO,nlakes,tmpQLAKEO)
   call updateLake_seq(QLAKEI,nlakes,tmpQLAKEI)
   call updateLake_seq(RESHT,nlakes,tmpRESHT)
   
   do k = 1, NLINKSL !tmpQLINK?
      if(TYPEL(k) .ne. 2) then   !only the internal lake nodes don't have info.. but need to save QLINK of lake out too
         QLINK(k,2) = tmpQLINK(k,2)
      endif
      QLINK(k,1) = QLINK(k,2)    !assigng link flow of current to be previous for next time step
   end do
   
   
  
   
!#ifdef HYDRO_D
!   print *, "END OF ALL REACHES...",KRT,DT_STEPS
!#endif
   
end do  ! nsteps

if (KT .eq. 1) KT = KT + 1

if(my_id .eq. io_id)      then 
   if(allocated(tmpQLAKEO))  deallocate(tmpQLAKEO)
   if(allocated(tmpQLAKEI))  deallocate(tmpQLAKEI)
   if(allocated(tmpRESHT))  deallocate(tmpRESHT)
endif

if (KT .eq. 1) KT = KT + 1  ! redundant?

end subroutine drive_CHANNEL_RSL

! ----------------------------------------------------------------

end module module_channel_routing

!! Is this outside the module scope on purpose?
 subroutine checkReach(ii,  inVar)
   use module_mpp_land
   use module_RT_data, only: rt_domain
   use MODULE_mpp_ReachLS, only : updatelinkv,                   &
                                 ReachLS_write_io, gbcastvalue, &
                                 gbcastreal2
   implicit none
   integer :: ii
   real,dimension(rt_domain(1)%nlinksl) :: inVar
   real:: g_var(rt_domain(1)%gnlinksl)
   call ReachLS_write_io(inVar, g_var)
   if(my_id .eq. io_id) then
      write(ii,*) g_var
      call flush(ii)
   endif
 end subroutine checkReach
