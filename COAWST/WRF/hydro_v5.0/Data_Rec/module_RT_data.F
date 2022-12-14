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

Module module_RT_data
   IMPLICIT NONE
   INTEGER, PARAMETER :: max_domain=5

! define Routing data
#include "rt_include.inc"
   TYPE ( RT_FIELD ), DIMENSION (max_domain) :: RT_DOMAIN
   save RT_DOMAIN
   integer :: cur_did

  !!!!!!!!!!!!!!!!!!!!!!!!bdy
  integer hdbdy_n
  integer hdbdy_num
  integer,allocatable :: hdbdy_idx(:)
  integer,allocatable :: hdbdy_jdx(:)
  real,allocatable :: hdbdy_head(:,:)
  integer hdbdy_t
  integer hdbdy_time
  integer hdbdy_glonum
  real,allocatable :: hdbdy_ot(:)
  !!!!!!!!!!!!!!!!!!!!!!!!!!!

end module module_RT_data
