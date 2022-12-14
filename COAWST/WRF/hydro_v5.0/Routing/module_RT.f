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

MODULE module_Routing

   use module_gw_baseflow, only: pix_ct_1
   use module_HYDRO_io, only: mpp_read_routedim, read_routing_seq, mpp_read_chrouting_new, &
                              mpp_read_simp_gw, read_routelink, get_nlinksl
   use MODULE_mpp_ReachLS, only: ReachLS_ini, getlocalindx,  getToInd
   USE module_mpp_land, only : left_id, up_id, right_id, down_id, mpp_land_com_integer, & 
                               mpp_land_bcast_int, mpp_land_bcast_int1, &
                               updateLake_seq
   use module_mpp_GWBUCKET, only : collectSizeInd




   use module_HYDRO_io, only: readgw2d, simp_gw_ind,read_GWBUCKPARM, get_gw_strm_msk_lind, readBucket_nhd, read_NSIMLAKES
   use module_HYDRO_utils 

   use module_UDMAP, only: LNUMRSL, LUDRSL, UDMP_ini
   IMPLICIT NONE







   integer, parameter :: r8 = selected_real_kind(8)
   real*8,  parameter :: zeroDbl=0.0000000000000000000_r8   
   integer, parameter :: r4 = selected_real_kind(4)
   real  ,  parameter :: zeroFlt=0.0000000000000000000_r4

CONTAINS

   subroutine rt_allocate(did,ix,jx,ixrt,jxrt,nsoil,CHANRTSWCRT)   
      use module_RT_data, only: rt_domain
      implicit none
      integer ixrt,jxrt, ix,jx,nsoil,NLINKS, CHANRTSWCRT, NLAKES, NLINKSL
      integer istatus, did, nsizes
      if(rt_domain(did)%allo_status .eq. 1) return
      rt_domain(did)%allo_status = 1

      rt_domain(did)%ix = ix
      rt_domain(did)%jx = jx
      rt_domain(did)%ixrt = ixrt
      rt_domain(did)%jxrt = jxrt
!     ixrt = rt_domain(did)%ixrt
!     jxrt = rt_domain(did)%jxrt
      
!     if( nlst_rt(did)%channel_option .eq. 1  .or. nlst_rt(did)%channel_option .eq. 2 ) then
!         rt_domain(did)%NLINKS = rt_domain(did)%NLINKSL
!     endif
  if(nlst_rt(did)%UDMP_OPT .eq. 1) then
      if(rt_domain(did)%NLINKS .lt. rt_domain(did)%NLINKSL) then
          rt_domain(did)%NLINKS = rt_domain(did)%NLINKSL
      endif
  endif

      NLINKS = rt_domain(did)%NLINKS
      NLAKES = rt_domain(did)%NLAKES
      NLINKSL = rt_domain(did)%NLINKSL
     
      if(NLINKSL .gt. NLINKS) then
         nsizes = nlinksl
      else
         nsizes = nlinks
!           write(6,*) "Fatal Error: NLINKSL .gt. NLINKS .. "
!           call hydro_stop("not solved, contact WRF-Hydro group. ")
      endif
      rt_domain(did)%nlinksize = nsizes


      if(rt_domain(did)%NLINKS .eq. 0) NLINKS = 1
      if(rt_domain(did)%NLAKES .eq. 0) NLAKES = 1
      if(rt_domain(did)%NLINKSL .eq. 0) NLINKSL = 1

      rt_domain(did)%iswater = 0
      rt_domain(did)%isurban = 0
      rt_domain(did)%isoilwater = 0

!DJG Allocate routing and disaggregation arrays





  if(nlst_rt(did)%channel_only       .eq. 0 .and. & 
     nlst_rt(did)%channelBucket_only .eq. 0        ) then

     allocate( rt_domain(did)%DSMC   	(NSOIL) )
     rt_domain(did)%dsmc = 0 
     allocate( rt_domain(did)%SMCRTCHK    	(NSOIL) )
     rt_domain(did)%SMCRTCHK = 0
     allocate( rt_domain(did)%SH2OAGGRT   	(NSOIL) )
     rt_domain(did)%SH2OAGGRT = 0
     allocate( rt_domain(did)%STCAGGRT   	(NSOIL) )
     rt_domain(did)%STCAGGRT = 0
     allocate( rt_domain(did)%SMCAGGRT   	(NSOIL) )
     rt_domain(did)%SMCAGGRT = 0
     
     if(nlst_rt(did)%UDMP_OPT .eq. 1) then
        allocate ( RT_DOMAIN(did)%landRunOff (ixrt,jxrt) )
     endif
     
     allocate( rt_domain(did)%SMCRT   	(IXRT,JXRT,NSOIL) )
     rt_domain(did)%SMCRT   	= 0.0                
     allocate( rt_domain(did)%soiltypRT   	(IXRT,JXRT) )
     !!

     allocate( rt_domain(did)%SOXRT  	(IXRT,JXRT) )
     rt_domain(did)%SOXRT  	= 0.0                
     allocate( rt_domain(did)%SOYRT   	(IXRT,JXRT) )
     rt_domain(did)%SOYRT   	= 0.0                
     allocate( rt_domain(did)%SO8RT   	(IXRT,JXRT,8) )
     rt_domain(did)%SO8RT   	= -999               
     allocate( rt_domain(did)%SO8RT_D   	(IXRT,JXRT,3) )
     rt_domain(did)%SO8RT_D   	= 0.0                
     allocate( rt_domain(did)%OVROUGHRT   (IXRT,JXRT) )
     !

     !allocate( rt_domain(did)%QSUBBDRYTRT   (IXRT,JXRT) )
     !rt_domain(did)%QSUBBDRYTRT = 0.0
     allocate( rt_domain(did)%OVROUGHRTFAC   (IXRT,JXRT) )
     rt_domain(did)%OVROUGHRT   = 0.0                
     allocate( rt_domain(did)%RETDEPRT    (IXRT,JXRT) )
     !

     allocate( rt_domain(did)%RETDEPRTFAC    (IXRT,JXRT) )
     !

     allocate( rt_domain(did)%SFCHEADSUBRT(IXRT,JXRT) )
     rt_domain(did)%SFCHEADSUBRT= 0.0                
     allocate( rt_domain(did)%INFXSUBRT   (IXRT,JXRT) )
     rt_domain(did)%INFXSUBRT   = 0.0                
     allocate( rt_domain(did)%INFXSWGT    (IXRT,JXRT) )
     rt_domain(did)%INFXSWGT    = 0.0                
     allocate( rt_domain(did)%LKSATRT     (IXRT,JXRT) )
     rt_domain(did)%LKSATRT     = 0.0                
     allocate( rt_domain(did)%LKSATFAC    (IXRT,JXRT) )
     rt_domain(did)%LKSATFAC    = 0.0                
     allocate( rt_domain(did)%QSUBRT      (IXRT,JXRT) )
     rt_domain(did)%QSUBRT      = 0.0                
     allocate( rt_domain(did)%ZWATTABLRT  (IXRT,JXRT) )
     rt_domain(did)%ZWATTABLRT  = 0.0                
     allocate( rt_domain(did)%QSUBBDRYRT  (IXRT,JXRT) )
     rt_domain(did)%QSUBBDRYRT  = 0.0                
     allocate( rt_domain(did)%SOLDEPRT    (IXRT,JXRT) )
     rt_domain(did)%SOLDEPRT    = 0.0                
     allocate( rt_domain(did)%q_sfcflx_x  (IXRT,JXRT) )
     rt_domain(did)%q_sfcflx_x  = 0.0                
     allocate( rt_domain(did)%q_sfcflx_y  (IXRT,JXRT) )
     rt_domain(did)%q_sfcflx_y  = 0.0                
     allocate( rt_domain(did)%SMCMAXRT   	(IXRT,JXRT,NSOIL) )
     rt_domain(did)%SMCMAXRT   	= 0.0                
     allocate( rt_domain(did)%SMCWLTRT   	(IXRT,JXRT,NSOIL) )
     rt_domain(did)%SMCWLTRT   	= 0.0                
     allocate( rt_domain(did)%SH2OWGT   	(IXRT,JXRT,NSOIL) )
     rt_domain(did)%SH2OWGT     = 0.0
     allocate( rt_domain(did)%INFXSAGGRT 	(IXRT,JXRT) )
     rt_domain(did)%INFXSAGGRT 	= 0.0                
     allocate( rt_domain(did)%DHRT   	(IXRT,JXRT) )
     rt_domain(did)%DHRT   	= 0.0                
     allocate( rt_domain(did)%QSTRMVOLRT  (IXRT,JXRT) )
     rt_domain(did)%QSTRMVOLRT  = 0.0
     allocate( rt_domain(did)%QSTRMVOLRT_TS  (IXRT,JXRT) )
     rt_domain(did)%QSTRMVOLRT_TS  = 0.0                
     allocate( rt_domain(did)%QSTRMVOLRT_ACC  (IXRT,JXRT) )
     rt_domain(did)%QSTRMVOLRT_ACC  = 0.0                
     allocate( rt_domain(did)%QBDRYRT   	(IXRT,JXRT) )
     rt_domain(did)%QBDRYRT   	= 0.0     
     allocate( rt_domain(did)%SUB_RESID (ixrt,jxrt) )
     rt_domain(did)%SUB_RESID = 0.0                

     allocate( rt_domain(did)%sea_id(IXRT,JXRT) )  !bdy for seamask
     rt_domain(did)%sea_id= 0.0    
     
     ! tmp array 
     allocate( rt_domain(did)%SMCREFRT    	(IXRT,JXRT,NSOIL) )
     ! tmp
     
     !! Variables (formerly?) needed for channel_only
     allocate( rt_domain(did)%ELRT   	(IXRT,JXRT) )
     rt_domain(did)%ELRT   	= 0.0                
     allocate( rt_domain(did)%LAKE_MSKRT 	(IXRT,JXRT) )
     rt_domain(did)%LAKE_MSKRT 	= -9999              
     allocate( rt_domain(did)%LAKE_INFLORT(IXRT,JXRT) )
     rt_domain(did)%LAKE_INFLORT= 0.0                
     allocate( rt_domain(did)%LAKE_INFLORT_TS(IXRT,JXRT) )
     allocate( rt_domain(did)%LAKE_INFLORT_DUM(IXRT,JXRT) )
     rt_domain(did)%LAKE_INFLORT_DUM= 0.0                
     allocate( rt_domain(did)%LATVAL (ixrt,jxrt) )
     allocate( rt_domain(did)%LONVAL (ixrt,jxrt) )
     rt_domain(did)%LONVAL = 0.0
     rt_domain(did)%LATVAL = 0.0                


  !DJG Allocate routing and disaggregation arrays
  allocate(rt_domain(did)%qinflowbase  (IXRT,JXRT) )
  rt_domain(did)%qinflowbase = 0.0           
  
  allocate(rt_domain(did)%gw_strm_msk  (IXRT,JXRT) )
           rt_domain(did)%gw_strm_msk   = 0         
  allocate(rt_domain(did)%gw_strm_msk_lind  (IXRT,JXRT) )

  ! allocate land surface grid variables
  allocate( rt_domain(did)%SMC  (IX,JX,NSOIL) )
            rt_domain(did)%SMC   = 0.25           
  allocate( rt_domain(did)%SICE (IX,JX,NSOIL) )
            rt_domain(did)%SICE  = 0.
  ! allocate( rt_domain(did)%dist_lsm (ixrt,jxrt,9) )
  ! allocate( rt_domain(did)%lat_lsm (ixrt,jxrt) )
  ! allocate( rt_domain(did)%lon_lsm (ixrt,jxrt) )

  ! allocate( rt_domain(did)%SICE  (IX,JX,NSOIL) )
  allocate( rt_domain(did)%SMCMAX1  (IX,JX) )
            rt_domain(did)%SMCMAX1   = 0.0
           !rt_domain(did)%SMCMAX1   = 0.434          
  allocate( rt_domain(did)%STC  (IX,JX,NSOIL) )
            rt_domain(did)%STC   = 282.0          
  allocate( rt_domain(did)%SH2OX(IX,JX,NSOIL) )
            rt_domain(did)%SH2OX = rt_domain(did)%SMC   
  allocate( rt_domain(did)%SMCWLT1  (IX,JX) )
            rt_domain(did)%SMCWLT1   = 0.0            
  allocate( rt_domain(did)%SMCREF1  (IX,JX) )
            rt_domain(did)%SMCREF1   = 0.0            
  allocate( rt_domain(did)%VEGTYP   (IX,JX) )
            rt_domain(did)%VEGTYP    = 0            

  allocate( rt_domain(did)%OV_ROUGH2d   (IX,JX) )
            
  allocate( rt_domain(did)%SOILTYP   (IX,JX) )

  allocate( rt_domain(did)%GWSUBBASMSK   (IX,JX) )
            rt_domain(did)%GWSUBBASMSK    = 0              
  allocate( rt_domain(did)%SLDPTH(NSOIL) )
            rt_domain(did)%SLDPTH = 0.0           
  allocate( rt_domain(did)%SO8LD_D   (IX,JX,3) )
            rt_domain(did)%SO8LD_D    = 0.0           
  allocate( rt_domain(did)%SO8LD_Vmax   (IX,JX) )
            rt_domain(did)%SO8LD_Vmax    = 0.0            
  allocate( rt_domain(did)%SFCHEADRT   (IX,JX) )
            rt_domain(did)%SFCHEADRT    = 0.0
  allocate( rt_domain(did)%INFXSRT   (IX,JX) )
            rt_domain(did)%INFXSRT    = 0.0            
  allocate( rt_domain(did)%TERRAIN   (IX,JX) )
            rt_domain(did)%TERRAIN    = 0.0            
  allocate( rt_domain(did)%LKSAT   (IX,JX) )
            rt_domain(did)%LKSAT    = 0.0            
  allocate( rt_domain(did)%SOLDRAIN   (IX,JX) )
            rt_domain(did)%SOLDRAIN    = 0.0            

  end if ! neither channel_only nor channelBucket_only


  !! needed regardless
  allocate( rt_domain(did)%dist_lsm (ix,jx,9) )
            rt_domain(did)%dist_lsm = 0.0 
  allocate( rt_domain(did)%lat_lsm (ix,jx) )
  allocate( rt_domain(did)%lon_lsm (ix,jx) )
  rt_domain(did)%timestep_flag = 1    ! default is cold start
  allocate( rt_domain(did)%dist (ixrt,jxrt,9) )
  rt_domain(did)%dist = -999  

  !! This is needed for channelBucket_only 
  !! because the bucket area (basns_area) depends on the initialization of the
  !! UDMP code, this is a required variable.
  !! JLM: could these be deallocated under channel_only
  if(nlst_rt(did)%channel_only       .eq. 0) then
     allocate( rt_domain(did)%CH_NETRT   	(IXRT,JXRT) )
     rt_domain(did)%CH_NETRT   	= 0.0                
     allocate( rt_domain(did)%CH_LNKRT (IXRT,JXRT) )
     rt_domain(did)%CH_LNKRT = 0.0
  endif


  if (CHANRTSWCRT.eq.1 .or. CHANRTSWCRT .eq. 2) then  !IF/then for channel routing

     !! JLM TODO: clean up this section for routing options, group 2D variables.

     allocate( rt_domain(did)%CH_NETLNK (IXRT,JXRT) )
     rt_domain(did)%CH_NETLNK = 0.0               
     allocate( rt_domain(did)%GCH_NETLNK (IXRT,JXRT) )
     rt_domain(did)%GCH_NETLNK = 0.0           


     allocate( rt_domain(did)%LAKE_INDEX(NLAKES) )
     rt_domain(did)%lake_index = -99
     allocate( rt_domain(did)%nlinks_INDEX(nsizes) )
     allocate( rt_domain(did)%Link_location(ixrt,jxrt) )


     allocate( rt_domain(did)%CH_LNKRT_SL (IXRT,JXRT) )
     rt_domain(did)%CH_LNKRT_SL = -99         
     rt_domain(did)%MAXORDER = -9999

!tmp  if( nlst_rt(did)%channel_option .eq. 1  .or. nlst_rt(did)%channel_option .eq. 3 ) then
!tmp       NLINKS = rt_domain(did)%NLINKSL
!tmp       NLAKES = rt_domain(did)%NLINKSL
!tmp  endif

     allocate( rt_domain(did)%LINKID(nsizes) )
     allocate( rt_domain(did)%gages(nsizes) )
     allocate( rt_domain(did)%TO_NODE(nsizes) )
     allocate( rt_domain(did)%FROM_NODE(nsizes) )
     allocate( rt_domain(did)%CHLAT(nsizes) )   !-latitutde of channel grid point
     allocate( rt_domain(did)%CHLON(nsizes) )   !-longitude of channel grid point
     allocate( rt_domain(did)%ZELEV(nsizes) )
     allocate( rt_domain(did)%TYPEL(nsizes) )
     allocate( rt_domain(did)%ORDER(nsizes) )
     allocate( rt_domain(did)%QLINK(nsizes,2) )




     allocate( rt_domain(did)%MUSK(nsizes) )
     allocate( rt_domain(did)%MUSX(nsizes) )
     allocate( rt_domain(did)%CHANLEN(nsizes) )
     allocate( rt_domain(did)%MannN(nsizes))
     allocate( rt_domain(did)%So(nsizes) )
     allocate( rt_domain(did)%ChSSlp(nsizes) )
     allocate( rt_domain(did)%Bw(nsizes) )
     allocate( rt_domain(did)%LAKEIDA(nsizes) )
     allocate( rt_domain(did)%LAKEIDX(nsizes) )

     if(NLAKES .gt. 0) then
        allocate( rt_domain(did)%LAKEIDM(NLAKES) )
        allocate( rt_domain(did)%HRZAREA(NLAKES) )
        allocate( rt_domain(did)%LAKEMAXH(NLAKES) )
        allocate( rt_domain(did)%ELEVLAKE(NLAKES) )
        allocate( rt_domain(did)%WEIRH(NLAKES) )
        allocate( rt_domain(did)%WEIRC(NLAKES) )
        allocate( rt_domain(did)%WEIRL(NLAKES) )
        allocate( rt_domain(did)%ORIFICEC(NLAKES) )
        allocate( rt_domain(did)%ORIFICEA(NLAKES) )
        allocate( rt_domain(did)%ORIFICEE(NLAKES) )

         rt_domain(did)%HRZAREA = 0.0        
         rt_domain(did)%WEIRH = 0.0        
         rt_domain(did)%WEIRC = 0.0        
         rt_domain(did)%WEIRL = 0.0        
         rt_domain(did)%LAKEMAXH = 0.0        
         rt_domain(did)%ELEVLAKE= 0.0        
         rt_domain(did)%ORIFICEC = 0.0        
         rt_domain(did)%ORIFICEA = 0.0        
         rt_domain(did)%ORIFICEE = 0.0        

     endif


!    allocate( rt_domain(did)%LAKEMAXH(nsizes) )
!    allocate( rt_domain(did)%WEIRC(nsizes) )
!    allocate( rt_domain(did)%WEIRL(nsizes) )
!    allocate( rt_domain(did)%ORIFICEC(nsizes) )
!    allocate( rt_domain(did)%ORIFICEA(nsizes) )
!    allocate( rt_domain(did)%ORIFICEE(nsizes) )

     if(nsizes .gt. 0) then
        if(nlst_rt(did)%output_channelBucket_influx .eq. 1 .or. &
           nlst_rt(did)%output_channelBucket_influx .eq. 2      ) then        
           allocate( rt_domain(did)%accSfcLatRunoff(1) )
           allocate( rt_domain(did)%accBucket(      1) )
           allocate( rt_domain(did)%qSfcLatRunoff(  nsizes) )
           allocate( rt_domain(did)%qBucket(        nsizes) )
        endif

        if(nlst_rt(did)%output_channelBucket_influx .eq. 1 .or. &
           nlst_rt(did)%output_channelBucket_influx .eq. 3      ) &
           allocate( rt_domain(did)%qBtmVertRunoff(     1) )
        if(nlst_rt(did)%output_channelBucket_influx .eq. 2) then
             allocate( rt_domain(did)%qBtmVertRunoff(nsizes) )
             rt_domain(did)%qBtmVertRunoff  = zeroFlt
        endif

        if(nlst_rt(did)%output_channelBucket_influx .eq. 3) then        
           allocate( rt_domain(did)%accSfcLatRunoff(nsizes) )
           allocate( rt_domain(did)%accBucket(      nsizes) )
           allocate( rt_domain(did)%qSfcLatRunoff(       1) )
           allocate( rt_domain(did)%qBucket(             1) )
           rt_domain(did)%accSfcLatRunoff = zeroDbl
           rt_domain(did)%accBucket       = zeroDbl
           rt_domain(did)%qSfcLatRunoff   = zeroFlt
           rt_domain(did)%qBucket         = zeroFlt
        endif

	allocate( rt_domain(did)%QLateral(nsizes) )
	allocate( rt_domain(did)%velocity(nsizes) )
	rt_domain(did)%QLateral  = zeroFlt
	rt_domain(did)%velocity  = zeroFlt
     endif

  if( nlst_rt(did)%channel_option .eq. 1  .or. nlst_rt(did)%channel_option .eq. 2 ) then
       NLINKS = rt_domain(did)%NLINKS
       NLAKES = rt_domain(did)%NLAKES 
  endif

     allocate( rt_domain(did)%LINK(nsizes) )
     allocate( rt_domain(did)%STRMFRXSTPTS(nsizes) )
     allocate( rt_domain(did)%CHANXI(nsizes) )
     allocate( rt_domain(did)%CHANYJ(nsizes) )
     allocate( rt_domain(did)%CVOL(nsizes) )
     allocate( rt_domain(did)%LATLAKE(NLAKES) )
     allocate( rt_domain(did)%LONLAKE(NLAKES) )
!    allocate( rt_domain(did)%ELEVLAKE(NLAKES) )
     allocate( rt_domain(did)%LAKENODE(nsizes) )
     allocate( rt_domain(did)%RESHT(NLAKES),STAT=istatus )
     allocate( rt_domain(did)%QLAKEI(NLAKES),STAT=istatus )
     allocate( rt_domain(did)%QLAKEO(NLAKES),STAT=istatus )

     allocate( rt_domain(did)%HLINK(nsizes) )  !--used for diffusion only

     allocate( rt_domain(did)%node_area(nsizes) )

!!!! tmp
      if(nsizes .gt. 0) then
      rt_domain(did)%LINK = 0.0        
      rt_domain(did)%gages = rt_domain(did)%gageMiss
      rt_domain(did)%TO_NODE = 0.0        
      rt_domain(did)%FROM_NODE = 0        
      rt_domain(did)%TYPEL = -999       
      rt_domain(did)%ORDER = 0.0        
      rt_domain(did)%STRMFRXSTPTS = 0.0        
      rt_domain(did)%MUSK = 0.0        
      rt_domain(did)%MUSX = 0.0        
      rt_domain(did)%CHANXI = 0.0        
      rt_domain(did)%CHANYJ = 0.0        
      rt_domain(did)%CHLAT = 0.0         !-latitutde of channel grid point
      rt_domain(did)%CHLON = 0.0         !-longitude of channel grid point
      rt_domain(did)%CHANLEN = 0.0        
      rt_domain(did)%ChSSlp = 0.0        
      rt_domain(did)%Bw = 0.0        
      rt_domain(did)%ZELEV = 0.0        
      rt_domain(did)%CVOL = 0.0        
      rt_domain(did)%LAKEIDA = 0
      rt_domain(did)%LAKEIDX = 0

      rt_domain(did)%LATLAKE = 0.0        
      rt_domain(did)%LONLAKE = 0.0        
!     rt_domain(did)%ELEVLAKE = 0.0        
      rt_domain(did)%LAKENODE = 0.0        
      rt_domain(did)%RESHT = 0.0                    
      rt_domain(did)%QLAKEI = 0.0                     
      rt_domain(did)%QLAKEO = 0.0                     
      rt_domain(did)%QLINK = 0        



      rt_domain(did)%HLINK = 0.0        !--used for diffusion only
      rt_domain(did)%MannN = 0.0        
      rt_domain(did)%LINKID = 0.0        

      rt_domain(did)%So = 0.01
     endif
   
     rt_domain(did)%restQSTRM = .true.

  END IF   !IF/then for channel routing

  rt_domain(did)%out_counts = 0
  rt_domain(did)%his_out_counts = 0
  rt_domain(did)%rst_counts = 1





end subroutine rt_allocate


subroutine getChanDim(did)
use module_namelist, only:  nlst_rt 
use module_RT_data, only: rt_domain
implicit none
      
integer ixrt,jxrt, ix,jx, did, i,j
integer, allocatable,dimension(:,:) :: CH_NETLNK, GCH_NETLNK
!INTEGER, dimension( rt_domain(did)%ixrt,GCH_NETLNK(ixrt,jxrt)) :: GCH_NETLNK, CH_NETLNK

real :: Vmax

ix = rt_domain(did)%ix 
jx = rt_domain(did)%jx 
ixrt = rt_domain(did)%ixrt 
jxrt = rt_domain(did)%jxrt 

if(nlst_rt(did)%rtFlag .eq. 0) return

if(nlst_rt(did)%channel_only       .eq. 1 .or. & 
   nlst_rt(did)%channelBucket_only .eq. 1        ) then

   !! Try to avoid some of the 2-d initialization. 
   !! if this is successful, it most likely will not work for gridded channel (opt 3)

   if(my_id .eq. io_id) then
      call get_NLINKSL(rt_domain(did)%NLINKSL, nlst_rt(did)%channel_option, nlst_rt(did)%route_link_f)
   end if
   call mpp_land_bcast_int1(rt_domain(did)%NLINKSL)

   
   if(nlst_rt(did)%channel_option .eq. 1 .or. nlst_rt(did)%channel_option .eq. 2) then
      rt_domain(did)%GNLINKSL = rt_domain(did)%NLINKSL

      call ReachLS_ini(rt_domain(did)%GNLINKSL,rt_domain(did)%nlinksl,   & 
           rt_domain(did)%linklsS, rt_domain(did)%linklsE )
   else
      rt_domain(did)%GNLINKSL = 1
      rt_domain(did)%NLINKSL = 1
   endif
   if(nlst_rt(did)%UDMP_OPT .eq. 1) &
        call read_NSIMLAKES(rt_domain(did)%NLAKES,nlst_rt(did)%route_lake_f)

   call rt_allocate(did,rt_domain(did)%ix,rt_domain(did)%jx,&
        rt_domain(did)%ixrt,rt_domain(did)%jxrt, nlst_rt(did)%nsoil,nlst_rt(did)%CHANRTSWCRT)

   return
   
endif 


allocate(CH_NETLNK(ixrt,jxrt)) 
allocate(GCH_NETLNK(ixrt,jxrt)) 

if (nlst_rt(did)%CHANRTSWCRT.eq.1 .or. nlst_rt(did)%CHANRTSWCRT .eq. 2) then  !IF/then for channel routing

   call MPP_READ_ROUTEDIM(did, rt_domain(did)%g_IXRT,rt_domain(did)%g_JXRT, &
                          GCH_NETLNK, rt_domain(did)%GNLINKS, &



              IXRT, JXRT, nlst_rt(did)%route_chan_f, nlst_rt(did)%route_link_f, &
              nlst_rt(did)%route_direction_f, &
              rt_domain(did)%NLINKS, &
              CH_NETLNK, nlst_rt(did)%channel_option, nlst_rt(did)%geo_finegrid_flnm, &
              rt_domain(did)%NLINKSL, nlst_rt(did)%udmp_opt , rt_domain(did)%nlakes)








   if(nlst_rt(did)%channel_option .eq. 1 .or. nlst_rt(did)%channel_option .eq. 2) then

      rt_domain(did)%GNLINKSL = rt_domain(did)%NLINKSL


      call ReachLS_ini(rt_domain(did)%GNLINKSL,rt_domain(did)%nlinksl,   & 
           rt_domain(did)%linklsS, rt_domain(did)%linklsE )




   else
      rt_domain(did)%GNLINKSL = 1
      rt_domain(did)%NLINKSL = 1
   endif





endif

if(nlst_rt(did)%UDMP_OPT .eq. 1) then
   call read_NSIMLAKES(rt_domain(did)%NLAKES,nlst_rt(did)%route_lake_f)
endif

call rt_allocate(did,rt_domain(did)%ix,rt_domain(did)%jx,&
     rt_domain(did)%ixrt,rt_domain(did)%jxrt, nlst_rt(did)%nsoil,nlst_rt(did)%CHANRTSWCRT)


if (nlst_rt(did)%CHANRTSWCRT.eq.1 .or. nlst_rt(did)%CHANRTSWCRT .eq. 2) then  !IF/then for channel routing
   rt_domain(did)%CH_NETLNK = CH_NETLNK
   rt_domain(did)%GCH_NETLNK = GCH_NETLNK
endif

if(allocated(CH_NETLNK)) deallocate(CH_NETLNK)
if(allocated(GCH_NETLNK)) deallocate(GCH_NETLNK)

end subroutine getChanDim

!===================================================================================================   
subroutine LandRT_ini(did)

use module_noah_chan_param_init_rt
use module_namelist, only:  nlst_rt
use module_rt_data, only: rt_domain
use module_gw_gw2d_data, only: gw2d








implicit none 

integer :: did
real    :: Vmax

integer :: bas 
character(len=19)                      :: header
character(len=1)                       :: jnk

real,  dimension(50)     :: BOTWID,HLINK_INIT,CHAN_SS,CHMann !Channel parms from table
integer :: i,j,k, ll, count
 
     integer, allocatable, dimension(:) :: tmp_int
     real, allocatable, dimension(:) :: tmp_real
     integer, allocatable, dimension(:) :: buf
     real, allocatable, dimension(:) :: tmpRESHT




!------------------------------------------------------------------------
!DJG Routing Processing
!------------------------------------------------------------------------
!DJG IF/then to get routing terrain fields if either routing module is 
!DJG   activated

if(nlst_rt(did)%rtFlag .eq. 0) return
     
if (nlst_rt(did)%SUBRTSWCRT  .eq.1 .or. &
    nlst_rt(did)%OVRTSWCRT   .eq.1 .or. &
    nlst_rt(did)%GWBASESWCRT .ne. 0) then

   if(nlst_rt(did)%channel_only       .eq. 0 .and. & 
      nlst_rt(did)%channelBucket_only .eq. 0        ) then





      call READ_ROUTING_seq  (  &
           rt_domain(did)%IXRT,rt_domain(did)%JXRT,rt_domain(did)%ELRT,rt_domain(did)%CH_NETRT, &
           rt_domain(did)%CH_LNKRT, &
           rt_domain(did)%LKSATFAC,trim(nlst_rt(did)%route_topo_f),&
           nlst_rt(did)%route_chan_f,nlst_rt(did)%geo_finegrid_flnm  ,  &
           rt_domain(did)%OVROUGHRTFAC,rt_domain(did)%RETDEPRTFAC, &
           nlst_rt(did)%channel_option, nlst_rt(did)%udmp_opt, rt_domain(did)%sea_id) !bdy for seamask

      
   !yw CALL READ_ROUTING_old(rt_domain(did)%IXRT,rt_domain(did)%JXRT,rt_domain(did)%ELRT,rt_domain(did)%CH_NETRT, &

      if (nlst_rt(did)%CHANRTSWCRT.eq.1 .or. nlst_rt(did)%CHANRTSWCRT .eq. 2) then  !IF/then for channel routing


         call MPP_READ_CHROUTING_new(    &



             rt_domain(did)%IXRT,         rt_domain(did)%JXRT,       &
             rt_domain(did)%ELRT,         rt_domain(did)%CH_NETRT,        &
             rt_domain(did)%CH_LNKRT,     rt_domain(did)%LAKE_MSKRT, & 
             rt_domain(did)%FROM_NODE,    rt_domain(did)%TO_NODE, &
             rt_domain(did)%TYPEL,        rt_domain(did)%ORDER, &
             rt_domain(did)%MAXORDER,     rt_domain(did)%NLINKS, &
             rt_domain(did)%NLAKES,       rt_domain(did)%CHANLEN, &
             rt_domain(did)%MannN,        rt_domain(did)%So, &
             rt_domain(did)%ChSSlp,       rt_domain(did)%Bw, &
             rt_domain(did)%HRZAREA,      rt_domain(did)%LAKEMAXH, &
             rt_domain(did)%WEIRH,        rt_domain(did)%WEIRC, &
             rt_domain(did)%WEIRL,        rt_domain(did)%ORIFICEC, &
             rt_domain(did)%ORIFICEA,     rt_domain(did)%ORIFICEE, &
             rt_domain(did)%LATLAKE,      rt_domain(did)%LONLAKE, &
             rt_domain(did)%ELEVLAKE,     rt_domain(did)%dist, &
             rt_domain(did)%ZELEV,        rt_domain(did)%LAKENODE,        &
             rt_domain(did)%CH_NETLNK,    rt_domain(did)%CHANXI,          &
             rt_domain(did)%CHANYJ,       rt_domain(did)%CHLAT,           &
             rt_domain(did)%CHLON,        nlst_rt(did)%channel_option,    &
             rt_domain(did)%latval,       rt_domain(did)%lonval,          &
             rt_domain(did)%STRMFRXSTPTS, nlst_rt(did)%geo_finegrid_flnm, &
             nlst_rt(did)%route_lake_f, rt_domain(did)%LAKEIDM,nlst_rt(did)%UDMP_OPT   & !! no comma

             ,rt_domain(did)%g_IXRT,      rt_domain(did)%g_JXRT      &
             ,rt_domain(did)%gnlinks,     rt_domain(did)%GCH_NETLNK  &
             ,rt_domain(did)%map_l2g,     rt_domain(did)%link_location, &
             rt_domain(did)%yw_mpp_nlinks,rt_domain(did)%lake_index, &
             rt_domain(did)%nlinks_index &

             )
         
      end if  !! CHANRTSWCRT 1 or 2

   end if  !! neither channel_only nor channelBucket_only
   
   
   if((nlst_rt(did)%CHANRTSWCRT    .eq. 1 .or. nlst_rt(did)%CHANRTSWCRT    .eq. 2) .and. &
      (nlst_rt(did)%channel_option .eq. 1 .or. nlst_rt(did)%channel_option .eq. 2)        ) then
      call read_routelink( &
           rt_domain(did)%TO_NODE,       rt_domain(did)%TYPEL,      &
           rt_domain(did)%ORDER,         rt_domain(did)%MAXORDER,   &
           rt_domain(did)%NLAKES,        rt_domain(did)%MUSK,       &
           rt_domain(did)%MUSX,                                     &
           rt_domain(did)%QLINK,         rt_domain(did)%CHANLEN,    &
           rt_domain(did)%MannN,         rt_domain(did)%So,         &
           rt_domain(did)%ChSSlp,        rt_domain(did)%Bw,         &
           rt_domain(did)%LAKEIDA,       rt_domain(did)%HRZAREA,    &
           rt_domain(did)%LAKEMAXH,      rt_domain(did)%WEIRH,      &
           rt_domain(did)%WEIRC,         rt_domain(did)%WEIRL,      &
           rt_domain(did)%ORIFICEC,      rt_domain(did)%ORIFICEA,   &
           rt_domain(did)%ORIFICEE,      rt_domain(did)%LATLAKE,    &
           rt_domain(did)%LONLAKE,       rt_domain(did)%ELEVLAKE,   &
           rt_domain(did)%LAKEIDM,       rt_domain(did)%LAKEIDX,    &
           nlst_rt(did)%route_link_f,    nlst_rt(did)%route_lake_f, &
           rt_domain(did)%ZELEV,         rt_domain(did)%CHLAT,      &
           rt_domain(did)%CHLON,         rt_domain(did)%NLINKSL,    &
           rt_domain(did)%LINKID,        rt_domain(did)%GNLINKSL,   &
           rt_domain(did)%NLINKS,        rt_domain(did)%gages,      &
           rt_domain(did)%gageMiss                                   )
   end if

   !ADCHANGE: Add lake reach output






! end OUTPUT_CHAN_CONN


   ! The UDMP_ini effectively sets the nhd gw bucket area (that field is not used from the file)
   !   this may be the only dependence of the nhd_routing on the UDMAPING in channelBucket_only
   if(nlst_rt(did)%channel_only .eq. 0) then

      if(nlst_rt(did)%UDMP_OPT .eq. 1) then   
         ! get NHDPLUS mapping function. 
         !          call UDMP_ini(rt_domain(did)%GNLINKSL,rt_domain(did)%ixrt,rt_domain(did)%jxrt,rt_domain(did)%CH_LNKRT , &
         call UDMP_ini( rt_domain(did)%GNLINKSL, rt_domain(did)%ixrt,      &
              rt_domain(did)%jxrt,     rt_domain(did)%CH_NETRT , &
              nlst_rt(did)%OVRTSWCRT,  nlst_rt(did)%SUBRTSWCRT,  &
              rt_domain(did)%dist(:,:,9)                         )
      endif

   end if ! end not channel_only


    if ( (nlst_rt(did)%CHANRTSWCRT .eq. 1) .and. &
         (nlst_rt(did)%channel_option .eq. 1 .or. nlst_rt(did)%channel_option .eq. 2) ) then

      if(nlst_rt(did)%UDMP_OPT .eq. 1) then
           ! NHDPLUS
           rt_domain(did)%LNLINKSL = LNUMRSL
           allocate(rt_domain(did)%LLINKID(rt_domain(did)%LNLINKSL))
           do k = 1,LNUMRSL
               rt_domain(did)%LLINKID(k) = LUDRSL(k)%myid
           end do

      else

           allocate (buf(rt_domain(did)%GNLINKS) )
           buf = -99
           do j = 1, rt_domain(did)%jxrt
              do i = 1, rt_domain(did)%ixrt
                 if( .not. ( (i .eq. 1 .and. left_id .ge. 0) .or. (i .eq. rt_domain(did)%ixrt .and. right_id .ge. 0) .or.  &
                        (j .eq. 1 .and. down_id .ge. 0) .or. (j .eq. rt_domain(did)%jxrt .and. up_id .ge. 0)    )   ) then 
                    if(rt_domain(did)%CH_LNKRT(i,j) .gt. 0) then
                       k = rt_domain(did)%CH_LNKRT(i,j)
                       buf(k) = k
                    endif
                 endif
              end do 
           end do

           rt_domain(did)%LNLINKSL = 0
           do k = 1, rt_domain(did)%GNLINKS
                if(buf(k) .gt. 0) then
                    rt_domain(did)%LNLINKSL = rt_domain(did)%LNLINKSL + 1
                endif
           end do
   

           allocate(rt_domain(did)%LLINKID(rt_domain(did)%LNLINKSL))
   
           k = 0
           do i = 1, rt_domain(did)%GNLINKS
                if(buf(i) .gt. 0) then
                   k = k + 1
                   rt_domain(did)%LLINKID(k) = buf(i)
                endif
           end do

         if(allocated(buf)) deallocate(buf)

      endif  ! end if block for UDMP_OPT
      
           do k = 1, rt_domain(did)%LNLINKSL
               do j = 1, rt_domain(did)%jxrt
                  do i = 1, rt_domain(did)%ixrt
                     if( .not. ( (i .eq. 1 .and. left_id .ge. 0) .or. (i .eq. rt_domain(did)%ixrt .and. right_id .ge. 0) .or.  &
                            (j .eq. 1 .and. down_id .ge. 0) .or. (j .eq. rt_domain(did)%jxrt .and. up_id .ge. 0)    )   ) then
                            if(rt_domain(did)%CH_LNKRT(i,j) .eq. rt_domain(did)%LLINKID(k) ) then
                               rt_domain(did)%CH_LNKRT_SL(i,j) = k   !! mapping
                            endif
                     endif
                  end do 
               end do
           end do

            call getLocalIndx(rt_domain(did)%gnlinksl,rt_domain(did)%LINKID, rt_domain(did)%LLINKID)

           call getToInd(rt_domain(did)%LINKID,rt_domain(did)%to_node,rt_domain(did)%toNodeInd,rt_domain(did)%nToInd,rt_domain(did)%gtoNode)

!!$        ! use gage information in RouteLink like strmfrxstpts
!!$        rt_domain(did)%STRMFRXSTPTS = -9999  !! existing info useless for link-based routing
!!$        count = 1
!!$        do ll=1,rt_domain(did)%NLINKSL
!!$           if(trim(rt_domain(did)%gages(ll)) .ne. trim(rt_domain(did)%gageMiss)) then
!!$              rt_domain(did)%STRMFRXSTPTS(count) = ll
!!$              count = count + 1 
!!$           end if
!!$        end do

   endif ! end of if (nlst_rt(did)%channel_option .eq. 1 .or. nlst_rt(did)%channel_option .eq. 2) 
   
end if ! end of if (nlst_rt(did)%SUBRTSWCRT  .eq.1 .or. &    nlst_rt(did)%OVRTSWCRT   .eq.1 .or. &
!            nlst_rt(did)%GWBASESWCRT .ne. 0) then


   
!yw       allocate(tmp_int(rt_domain(did)%GNLINKS))
!yw       allocate(tmp_real(rt_domain(did)%GNLINKS))


if(nlst_rt(did)%channel_only       .eq. 0 .and. & 
   nlst_rt(did)%channelBucket_only .eq. 0        ) then

   !DJG Temporary hardwire of RETDEPRT,RETDEP_CHAN
   !DJG    will later make this a function of SOLTYP and VEGTYP
   !            OVROUGHRT(i,j) = 0.01
   
   rt_domain(did)%RETDEPRT = 0.001   ! units (mm)
   rt_domain(did)%RETDEP_CHAN = 0.001


   !DJG Need to insert call for acquiring routing fields here...
   !DJG     include as a subroutine in module module_Noahlsm_wrfcode_input.F
   !DJG  Calculate terrain slopes 'SOXRT,SOYRT' from subgrid elevation 'ELRT'

   rt_domain(did)%so8rt = -999
   Vmax = 0.0
   do j=2,rt_domain(did)%JXRT-1
      do i=2,rt_domain(did)%IXRT-1
         rt_domain(did)%SOXRT(i,j)=(rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i+1,j))/rt_domain(did)%dist(i,j,3)
         rt_domain(did)%SOYRT(i,j)=(rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i,j+1))/rt_domain(did)%dist(i,j,1)
         !DJG Introduce reduction in retention depth as a linear function of terrain slope
         if (nlst_rt(did)%RT_OPTION.eq.2) then
            if (rt_domain(did)%SOXRT(i,j).gt.rt_domain(did)%SOYRT(i,j)) then
               Vmax=rt_domain(did)%SOXRT(i,j)
            else
               Vmax=rt_domain(did)%SOYRT(i,j)
            end if
            
            if (Vmax.gt.0.1) then
               rt_domain(did)%RETDEPRT(i,j)=0.
            else
               rt_domain(did)%RETDEPFRAC=Vmax/0.1
               rt_domain(did)%RETDEPRT(i,j)=rt_domain(did)%RETDEPRT(i,j)*(1.-rt_domain(did)%RETDEPFRAC)
               if (rt_domain(did)%RETDEPRT(i,j).lt.0.) rt_domain(did)%RETDEPRT(i,j)=0.
            end if
         end if

!!!!!!!!!!!!!!!!!!!!!!!!!!bdy         
         Vmax=-99999

 
                rt_domain(did)%SO8RT(i,j,1) = &
                     (rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i,j+1))/rt_domain(did)%dist(i,j,1)
                rt_domain(did)%SO8RT_D(i,j,1) = i
                rt_domain(did)%SO8RT_D(i,j,2) = j + 1 
                rt_domain(did)%SO8RT_D(i,j,3) = 1 
                Vmax = rt_domain(did)%SO8RT(i,j,1)
                
                rt_domain(did)%SO8RT(i,j,2) = &
                     (rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i+1,j+1))/rt_domain(did)%dist(i,j,2)  
                if(rt_domain(did)%SO8RT(i,j,2) .gt. Vmax ) then
                   rt_domain(did)%SO8RT_D(i,j,1) = i + 1
                   rt_domain(did)%SO8RT_D(i,j,2) = j + 1 
                   rt_domain(did)%SO8RT_D(i,j,3) = 2
                   Vmax = rt_domain(did)%SO8RT(i,j,2)
                end if
                
                rt_domain(did)%SO8RT(i,j,3) = &
                     (rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i+1,j))/rt_domain(did)%dist(i,j,3)
                if(rt_domain(did)%SO8RT(i,j,3) .gt. Vmax ) then
                   rt_domain(did)%SO8RT_D(i,j,1) = i + 1
                   rt_domain(did)%SO8RT_D(i,j,2) = j  
                   rt_domain(did)%SO8RT_D(i,j,3) = 3
                   Vmax = rt_domain(did)%SO8RT(i,j,3)
                end if
                
                rt_domain(did)%SO8RT(i,j,4) = &
                     (rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i+1,j-1))/rt_domain(did)%dist(i,j,4)  
                if(rt_domain(did)%SO8RT(i,j,4) .gt. Vmax ) then
                   rt_domain(did)%SO8RT_D(i,j,1) = i + 1
                   rt_domain(did)%SO8RT_D(i,j,2) = j - 1 
                   rt_domain(did)%SO8RT_D(i,j,3) = 4
                   Vmax = rt_domain(did)%SO8RT(i,j,4)
                end if
                
                rt_domain(did)%SO8RT(i,j,5) = &
                     (rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i,j-1))/rt_domain(did)%dist(i,j,5)
                if(rt_domain(did)%SO8RT(i,j,5) .gt. Vmax ) then
                   rt_domain(did)%SO8RT_D(i,j,1) = i 
                   rt_domain(did)%SO8RT_D(i,j,2) = j - 1 
                   rt_domain(did)%SO8RT_D(i,j,3) = 5
                   Vmax = rt_domain(did)%SO8RT(i,j,5)
                end if
                
                rt_domain(did)%SO8RT(i,j,6) = & 
                     (rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i-1,j-1))/rt_domain(did)%dist(i,j,6)  
                if(rt_domain(did)%SO8RT(i,j,6) .gt. Vmax ) then
                   rt_domain(did)%SO8RT_D(i,j,1) = i - 1 
                   rt_domain(did)%SO8RT_D(i,j,2) = j - 1 
                   rt_domain(did)%SO8RT_D(i,j,3) = 6
                   Vmax = rt_domain(did)%SO8RT(i,j,6)
                end if
                
                rt_domain(did)%SO8RT(i,j,7) = &
                     (rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i-1,j))/rt_domain(did)%dist(i,j,7)
                if(rt_domain(did)%SO8RT(i,j,7) .gt. Vmax ) then
                   rt_domain(did)%SO8RT_D(i,j,1) = i - 1 
                   rt_domain(did)%SO8RT_D(i,j,2) = j  
                   rt_domain(did)%SO8RT_D(i,j,3) = 7
                   Vmax = rt_domain(did)%SO8RT(i,j,7)
                end if
                
                rt_domain(did)%SO8RT(i,j,8) = &
                     (rt_domain(did)%ELRT(i,j)-rt_domain(did)%ELRT(i-1,j+1))/rt_domain(did)%dist(i,j,8)  
                if(rt_domain(did)%SO8RT(i,j,8) .gt. Vmax ) then
                   rt_domain(did)%SO8RT_D(i,j,1) = i - 1 
                   rt_domain(did)%SO8RT_D(i,j,2) = j + 1 
                   rt_domain(did)%SO8RT_D(i,j,3) = 8
                   Vmax = rt_domain(did)%SO8RT(i,j,8)
                end if             
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         
         !DJG Introduce reduction in retention depth as a linear function of terrain slope
         if (nlst_rt(did)%RT_OPTION.eq.1) then
            if (Vmax.gt.0.75) then
               rt_domain(did)%RETDEPRT(i,j)=0.
            else
               rt_domain(did)%RETDEPFRAC=Vmax/0.75
               rt_domain(did)%RETDEPRT(i,j)=rt_domain(did)%RETDEPRT(i,j)*(1.-rt_domain(did)%RETDEPFRAC)
               if (rt_domain(did)%RETDEPRT(i,j).lt.0.) rt_domain(did)%RETDEPRT(i,j)=0.
            end if
         end if
         
         
      end do
   end do
   !Apply calibration scaling factors to sfc roughness and retention depth here...
   rt_domain(did)%RETDEPRT = rt_domain(did)%RETDEPRT * rt_domain(did)%RETDEPRTFAC
   rt_domain(did)%OVROUGHRT = rt_domain(did)%OVROUGHRT * rt_domain(did)%OVROUGHRTFAC
   
   ! AD new limit for RETDEPRT at 1mm, assuming larger values of RETDEPRTFAC possible
   rt_domain(did)%RETDEPRT = min(rt_domain(did)%RETDEPRT, 1.0)  
 
   ! calculate the slope for boundary        
   if(right_id .lt. 0) rt_domain(did)%SOXRT(rt_domain(did)%IXRT,:)= &
        rt_domain(did)%SOXRT(rt_domain(did)%IXRT-1,:)
   if(left_id  .lt. 0) rt_domain(did)%SOXRT(1,:)=rt_domain(did)%SOXRT(2,:)
   if(up_id    .lt. 0) rt_domain(did)%SOYRT(:,rt_domain(did)%JXRT)= &
        rt_domain(did)%SOYRT(:,rt_domain(did)%JXRT-1)
   if(down_id  .lt. 0) rt_domain(did)%SOYRT(:,1)=rt_domain(did)%SOYRT(:,2)
   
   ! communicate the value to 
   call MPP_LAND_COM_REAL(rt_domain(did)%RETDEPRT,rt_domain(did)%IXRT,rt_domain(did)%JXRT,99)
   call MPP_LAND_COM_REAL(rt_domain(did)%SOXRT,rt_domain(did)%IXRT,rt_domain(did)%JXRT,99)
   call MPP_LAND_COM_REAL(rt_domain(did)%SOYRT,rt_domain(did)%IXRT,rt_domain(did)%JXRT,99)
   do i = 1, 8
      call MPP_LAND_COM_REAL(rt_domain(did)%SO8RT(:,:,i),rt_domain(did)%IXRT,rt_domain(did)%JXRT,99)
   end do
   do i = 1, 3
      call MPP_LAND_COM_INTEGER(rt_domain(did)%SO8RT_D(:,:,i),rt_domain(did)%IXRT,rt_domain(did)%JXRT,99)
   end do
   
end if ! end of neither channel_only nor channelBucket_only
   
if(nlst_rt(did)%UDMP_OPT .eq. 1) then

   allocate (rt_domain(did)%qout_gwsubbas (rt_domain(did)%nlinksL))
   rt_domain(did)%qout_gwsubbas = 0
   ! use different baseflow for NHDPlus
   if (nlst_rt(did)%GWBASESWCRT.ge.1) then
      rt_domain(did)%numbasns = rt_domain(did)%NLINKSL
      RT_DOMAIN(did)%gnumbasns = rt_domain(did)%gNLINKSL
      
      allocate (rt_domain(did)%z_gwsubbas (rt_domain(did)%numbasns  ))
      allocate (rt_domain(did)%nhdBuckMask(rt_domain(did)%numbasns  ))  ! default is -999
      
      allocate (rt_domain(did)%qin_gwsubbas (rt_domain(did)%numbasns))
      allocate (rt_domain(did)%gwbas_pix_ct (rt_domain(did)%numbasns))
      allocate (rt_domain(did)%ct2_bas (rt_domain(did)%numbasns))
      allocate (rt_domain(did)%bas_pcp (rt_domain(did)%numbasns))
      allocate (rt_domain(did)%gw_buck_coeff (rt_domain(did)%numbasns))
      allocate (rt_domain(did)%bas_id (rt_domain(did)%numbasns))
      allocate (rt_domain(did)%gw_buck_exp(rt_domain(did)%numbasns))
      allocate (rt_domain(did)%z_max (rt_domain(did)%numbasns))
      allocate (rt_domain(did)%basns_area (rt_domain(did)%numbasns))
      
      rt_domain(did)%qin_gwsubbas = 0
      rt_domain(did)%z_gwsubbas = 0
      rt_domain(did)%gwbas_pix_ct = 0
      rt_domain(did)%bas_pcp = 0
      
      rt_domain(did)%gw_buck_coeff = 0.04
      rt_domain(did)%gw_buck_exp  = 0.2
      rt_domain(did)%z_max = 0.1
      
      !Temporary hardwire...
      rt_domain(did)%z_gwsubbas = 0.05   ! This gets updated with spun-up GW level in GWBUCKPARM.TBL
      
      call readBucket_nhd(trim(nlst_rt(did)%GWBUCKPARM_file), rt_domain(did)%numbasns, &
           rt_domain(did)%gw_buck_coeff, rt_domain(did)%gw_buck_exp, &
           rt_domain(did)%z_max, rt_domain(did)%z_gwsubbas, rt_domain(did)%LINKID(1:rt_domain(did)%numbasns),  &
           rt_domain(did)%nhdBuckMask )
      !ADCHANGE: Added in read for z_init from GWBUCKPARM. Units coming in are mm but z_gwsubbas is in m
      !for UDMP=1 so we convert units.
      rt_domain(did)%z_gwsubbas = rt_domain(did)%z_gwsubbas/1000.     

   endif

else

   !---------------------------------------------------------------------
   !DJG  If GW/Baseflow activated...Read in req'd fields...
   !----------------------------------------------------------------------
   if (nlst_rt(did)%GWBASESWCRT.ge.1) then
      if (nlst_rt(did)%GWBASESWCRT.eq.1.or.nlst_rt(did)%GWBASESWCRT.eq.2) then
         call MPP_READ_SIMP_GW(              &
         rt_domain(did)%IX,rt_domain(did)%JX,rt_domain(did)%IXRT,&
         rt_domain(did)%JXRT,rt_domain(did)%GWSUBBASMSK,nlst_rt(did)%gwbasmskfil,&
         rt_domain(did)%gw_strm_msk,rt_domain(did)%numbasns,rt_domain(did)%ch_netrt,nlst_rt(did)%AGGFACTRT)
         
         
         call SIMP_GW_IND(rt_domain(did)%ix,rt_domain(did)%jx,rt_domain(did)%GWSUBBASMSK,  &
              rt_domain(did)%numbasns,rt_domain(did)%gnumbasns,rt_domain(did)%basnsInd)
         
         call collectSizeInd(rt_domain(did)%numbasns)

         call get_gw_strm_msk_lind (rt_domain(did)%IXRT, rt_domain(did)%JXRT, rt_domain(did)%gw_strm_msk,&
              rt_domain(did)%numbasns,rt_domain(did)%basnsInd,rt_domain(did)%gw_strm_msk_lind)

         allocate (rt_domain(did)%qout_gwsubbas (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%qin_gwsubbas (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%z_gwsubbas (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%gwbas_pix_ct (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%ct2_bas (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%bas_pcp (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%gw_buck_coeff (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%bas_id (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%gw_buck_exp(rt_domain(did)%numbasns))
         allocate (rt_domain(did)%z_max (rt_domain(did)%numbasns))
         allocate (rt_domain(did)%basns_area (rt_domain(did)%numbasns))

     
!Temporary hardwire...
         rt_domain(did)%z_gwsubbas = 1.     ! This gets updated with spun-up GW level in GWBUCKPARM.TBL

         call read_GWBUCKPARM(trim(nlst_rt(did)%GWBUCKPARM_file),rt_domain(did)%numbasns,   &
              rt_domain(did)%gnumbasns, rt_domain(did)%basnsInd, &
              rt_domain(did)%gw_buck_coeff, rt_domain(did)%gw_buck_exp, rt_domain(did)%z_max, &
              rt_domain(did)%z_gwsubbas, rt_domain(did)%bas_id,rt_domain(did)%basns_area)


!!! Determine number of stream pixels per GW basin for distribution...
         call pix_ct_1(rt_domain(did)%gw_strm_msk,rt_domain(did)%ixrt,rt_domain(did)%jxrt,rt_domain(did)%gwbas_pix_ct,rt_domain(did)%numbasns, &
              rt_domain(did)%gnumbasns,rt_domain(did)%basnsInd)

      
         ! BF gw2d model
      elseif (nlst_rt(did)%GWBASESWCRT.ge.3) then
      
         call readGW2d(gw2d(did)%ix, gw2d(did)%jx,     &
              gw2d(did)%hycond, gw2d(did)%ho, &
              gw2d(did)%bot, gw2d(did)%poros, &
              gw2d(did)%ltype, nlst_rt(did)%gwIhShift)
         
         gw2d(did)%elev = rt_domain(did)%elrt
      
      end if ! end if (nlst_rt(did)%GWBASESWCRT.eq.1.or.nlst_rt(did)%GWBASESWCRT.eq.2) 

   end if ! end if (nlst_rt(did)%GWBASESWCRT.ge.1)

!---------------------------------------------------------------------
!DJG  End if GW/Baseflow activated...
!----------------------------------------------------------------------
endif   !!! end if block for UDMP_OPT .eq. 1 



!---------------------------------------------------------------------
!DJG,DNY  If channel routing activated...
!----------------------------------------------------------------------

if (nlst_rt(did)%CHANRTSWCRT.eq.1 .or. nlst_rt(did)%CHANRTSWCRT .eq. 2) then
   
   !---------------------------------------------------------------------
   !DJG,DNY  Initalize lake and channel heights, this may be overwritten by RESTART
   !--------------------------------------------------------------------
   
   if (nlst_rt(did)%channel_option .eq. 3) then
      call mpp_CHAN_PARM_INIT (BOTWID,HLINK_INIT,CHAN_SS,CHMann)  !Read chan parms from table...
   end if

   if (nlst_rt(did)%channel_option .ne. 3) then

        if(my_id .eq. io_id) then
           allocate(tmpRESHT(rt_domain(did)%nlakes))
           tmpRESHT = rt_domain(did)%RESHT
        endif

        call updateLake_seq(rt_domain(did)%RESHT, rt_domain(did)%NLAKES,tmpRESHT)
        if(my_id .eq. io_id) then 
            if(allocated(tmpRESHT)) deallocate(tmpRESHT)
        endif

   else       !-- parameterize according to order of diffusion scheme, or if read from hi res file, use its value
                !--  put condition within the if/then structure, which will assign a value if something is missing in hi res

        do j=1,rt_domain(did)%NLINKS

             if (rt_domain(did)%ORDER(j) .eq. 1) then    !-- smallest stream reach
               if(rt_domain(did)%Bw(j) .eq. 0.0) then 
                rt_domain(did)%Bw(j) = BOTWID(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%ChSSlp(j) .eq. 0.0) then  !if id didn't get set from the hi res file, use the  CHANPARAM
                rt_domain(did)%ChSSlp(j) = CHAN_SS(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%MannN(j) .eq. 0.0) then 
                rt_domain(did)%MannN(j) = CHMann(rt_domain(did)%ORDER(j))
               endif
               rt_domain(did)%HLINK(j) = HLINK_INIT(rt_domain(did)%ORDER(j))
             elseif (rt_domain(did)%ORDER(j) .eq. 2) then
               if(rt_domain(did)%Bw(j) .eq. 0.0) then 
                rt_domain(did)%Bw(j) = BOTWID(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%ChSSlp(j) .eq. 0.0) then  !if id didn't get set from the hi res file, use the  CHANPARAM
                rt_domain(did)%ChSSlp(j) = CHAN_SS(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%MannN(j) .eq. 0.0) then 
                rt_domain(did)%MannN(j) = CHMann(rt_domain(did)%ORDER(j))
               endif
               rt_domain(did)%HLINK(j) = HLINK_INIT(rt_domain(did)%ORDER(j))
             elseif (rt_domain(did)%ORDER(j) .eq. 3) then
               if(rt_domain(did)%Bw(j) .eq. 0.0) then 
                rt_domain(did)%Bw(j) = BOTWID(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%ChSSlp(j) .eq. 0.0) then  !if id didn't get set from the hi res file, use the  CHANPARAM
                rt_domain(did)%ChSSlp(j) = CHAN_SS(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%MannN(j) .eq. 0.0) then 
                rt_domain(did)%MannN(j) = CHMann(rt_domain(did)%ORDER(j))
               endif
               rt_domain(did)%HLINK(j) = HLINK_INIT(rt_domain(did)%ORDER(j))
             elseif (rt_domain(did)%ORDER(j) .eq. 4) then
               if(rt_domain(did)%Bw(j) .eq. 0.0) then 
                rt_domain(did)%Bw(j) = BOTWID(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%ChSSlp(j) .eq. 0.0) then  !if id didn't get set from the hi res file, use the  CHANPARAM
                rt_domain(did)%ChSSlp(j) = CHAN_SS(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%MannN(j) .eq. 0.0) then 
                rt_domain(did)%MannN(j) = CHMann(rt_domain(did)%ORDER(j))
               endif
               rt_domain(did)%HLINK(j) = HLINK_INIT(rt_domain(did)%ORDER(j))
             elseif (rt_domain(did)%ORDER(j) .eq. 5) then
               if(rt_domain(did)%Bw(j) .eq. 0.0) then 
                rt_domain(did)%Bw(j) = BOTWID(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%ChSSlp(j) .eq. 0.0) then  !if id didn't get set from the hi res file, use the  CHANPARAM
                rt_domain(did)%ChSSlp(j) = CHAN_SS(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%MannN(j) .eq. 0.0) then 
                rt_domain(did)%MannN(j) = CHMann(rt_domain(did)%ORDER(j))
               endif
               rt_domain(did)%HLINK(j) = HLINK_INIT(rt_domain(did)%ORDER(j))
             elseif (rt_domain(did)%ORDER(j) .eq. 6) then
               if(rt_domain(did)%Bw(j) .eq. 0.0) then 
                rt_domain(did)%Bw(j) = BOTWID(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%ChSSlp(j) .eq. 0.0) then  !if id didn't get set from the hi res file, use the  CHANPARAM
                rt_domain(did)%ChSSlp(j) = CHAN_SS(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%MannN(j) .eq. 0.0) then 
                rt_domain(did)%MannN(j) = CHMann(rt_domain(did)%ORDER(j))
               endif
               rt_domain(did)%HLINK(j) = HLINK_INIT(rt_domain(did)%ORDER(j))
             elseif (rt_domain(did)%ORDER(j) .ge. 7) then
               if(rt_domain(did)%Bw(j) .eq. 0.0) then 
                rt_domain(did)%Bw(j) = BOTWID(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%ChSSlp(j) .eq. 0.0) then  !if id didn't get set from the hi res file, use the  CHANPARAM
                rt_domain(did)%ChSSlp(j) = CHAN_SS(rt_domain(did)%ORDER(j))
               endif
               if(rt_domain(did)%MannN(j) .eq. 0.0) then 
                rt_domain(did)%MannN(j) = CHMann(rt_domain(did)%ORDER(j))
               endif
               rt_domain(did)%HLINK(j) = HLINK_INIT(rt_domain(did)%ORDER(j))
             else   !-- the outlets won't have orders since there's no nodes, so
                    !-- assign the order 5 values

               if(rt_domain(did)%Bw(j) .eq. 0.0) then 
                rt_domain(did)%Bw(j) = BOTWID(5)
               endif
               if(rt_domain(did)%ChSSlp(j) .eq. 0.0) then  !if id didn't get set from the hi res file, use the  CHANPARAM
                rt_domain(did)%ChSSlp(j) = CHAN_SS(5)
               endif
              if(rt_domain(did)%MannN(j) .eq. 0.0) then 
               rt_domain(did)%MannN(j) = CHMann(5)
               endif
               rt_domain(did)%HLINK(j) = HLINK_INIT(5)
             endif
                
            rt_domain(did)%CVOL(j) = (rt_domain(did)%Bw(j)+ 1/rt_domain(did)%ChSSLP(j)*rt_domain(did)%HLINK(j))*rt_domain(did)%HLINK(j)*rt_domain(did)%CHANLEN(j) !-- initalize channel volume
        end do

   endif  !End if channel option eq 3; else;


! Initialize Lake Elevations for Gridded and NWM routing.  
          do j=1,rt_domain(did)%NLAKES
                rt_domain(did)%RESHT(j) = rt_domain(did)%ORIFICEE(j) + &
                  ((rt_domain(did)%LAKEMAXH(j) - rt_domain(did)%ORIFICEE(j) )* rt_domain(did)%ELEVLAKE(j)) 
          end do 

 end if     ! Endif for channel routing setup
!-----------------------------------------------------------------------

if(nlst_rt(did)%channel_only       .eq. 0 .and. & 
   nlst_rt(did)%channelBucket_only .eq. 0        ) then

   rt_domain(did)%INFXSWGT = 1./(nlst_rt(did)%AGGFACTRT*nlst_rt(did)%AGGFACTRT)
   rt_domain(did)%SH2OWGT = 1.
   rt_domain(did)%SOLDEPRT = -1.0 * nlst_rt(did)%ZSOIL8(nlst_rt(did)%NSOIL)
   rt_domain(did)%QSUBRT = 0.0
   rt_domain(did)%ZWATTABLRT = 0.0
   rt_domain(did)%QSUBBDRYRT = 0.0
   rt_domain(did)%QSTRMVOLRT = 0.0
   rt_domain(did)%QBDRYRT = 0.0
   rt_domain(did)%SFCHEADSUBRT = 0.0
   rt_domain(did)%INFXSUBRT = 0.0
   rt_domain(did)%DHRT = 0.0
   rt_domain(did)%LAKE_INFLORT = 0.0
   rt_domain(did)%LAKE_CT = 0
   rt_domain(did)%STRM_CT = 0
   rt_domain(did)%SOLDRAIN = 0.0
   rt_domain(did)%qinflowbase = 0.0
   
   !  rt_domain(did)%BASIN_MSK = 1
   ! !DJG Initialize mass balance check variables...
   rt_domain(did)%SMC_INIT=0.
   rt_domain(did)%DSMC=0.
   rt_domain(did)%DACRAIN=0.
   rt_domain(did)%DSFCEVP=0.
   rt_domain(did)%DCANEVP=0.
   rt_domain(did)%DEDIR=0.
   rt_domain(did)%DETT=0.
   rt_domain(did)%DEPND=0.
   rt_domain(did)%DESNO=0.
   rt_domain(did)%DSFCRNFF=0.
   rt_domain(did)%DQBDRY=0.
   rt_domain(did)%SUMINFXS1=0.
   
end if ! end of neither channel_only nor channelBucket_only

end subroutine LandRT_ini


       subroutine deriveFromNode(did)
            implicit none
            integer :: did
            integer :: i,j, kk, maxv
            integer :: tmp(rt_domain(did)%nlinks)
            tmp = 0
            maxv = 1
            do i = 1, rt_domain(did)%nlinks
                if(rt_domain(did)%to_node(i) .gt. 0) then
                    kk = rt_domain(did)%to_node(i)
                    tmp(kk) = tmp(kk) + 1
                    if(maxv .lt. tmp(kk)) maxv = tmp(kk)
                end if
            end do
            allocate(rt_domain(did)%pnode(rt_domain(did)%nlinks,maxv+1) )
            rt_domain(did)%maxv_p = maxv+1
            rt_domain(did)%pnode = -99
            rt_domain(did)%pnode(:,1) = 1
            do i = 1, rt_domain(did)%nlinks
                if(rt_domain(did)%to_node(i) .gt. 0) then
                    j = rt_domain(did)%to_node(i)
                    rt_domain(did)%pnode(j,1) = rt_domain(did)%pnode(j,1) + 1
                    kk = rt_domain(did)%pnode(j,1)
                    rt_domain(did)%pnode(j,kk) = i
                end if
            end do

       end subroutine deriveFromNode



END MODULE module_Routing
