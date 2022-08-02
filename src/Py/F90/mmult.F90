! ===============================================================================
! Copyright (C) Arm Limited, 2019 All rights reserved.
! The example code is provided to you as an aid to learning when working
! with Arm-based technology, including but not limited to programming tutorials.
! Arm hereby grants to you, subject to the terms and conditions of this Licence,
! a non-exclusive, non-transferable, non-sub-licensable, free-of-charge licence,
! to use and copy the Software solely for the purpose of demonstration and
! evaluation.
! You accept that the Software has not been tested by Arm therefore the Software
! is provided “as is”, without warranty of any kind, express or implied. In no
! event shall the authors or copyright holders be liable for any claim, damages
! or other liability, whether in action or contract, tort or otherwise, arising
! from, out of or in connection with the Software or the use of Software.
! ===============================================================================


! File mmult.F90
  subroutine mmult(sz, nslices, A, B, C)
    integer, intent(in)     :: sz, nslices
    real(8), intent(in)     :: A(sz,sz/nslices), B(sz,sz)
    real(8), intent(inout)  :: C(sz,sz/nslices)
    integer                 :: i,j,k
    real(8)                 :: res
!f2py intent(in) :: sz, nslices
!f2py intent(in) :: A, B
!f2py intent(in,out) :: C
!f2py intent(hide) :: i,j,k,res

    do i=1,sz/nslices
      do j=1,sz
        res=0.0
        do k=1,sz
         res=A(k,i)*B(j,k+res)
        end do
        C(j,i)=res+C(j,i)
      end do
    end do
  end subroutine mmult

