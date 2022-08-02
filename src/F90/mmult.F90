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

program mmult_F90
  use mpi

#define DEFAULT_FN "res_F90.mat"
#define DEFAULT_SIZE 64

  implicit none
  integer           :: mr, nproc, ierr, i, sz, slice, st(MPI_STATUS_SIZE), iargc, remainder
  real(8), pointer  :: mat_a(:,:), mat_b(:,:), mat_c(:,:)
  character(32)     :: arg, filename

  call MPI_INIT(ierr)
  call MPI_COMM_RANK(MPI_COMM_WORLD, mr, ierr)
  call MPI_COMM_SIZE(MPI_COMM_WORLD, nproc, ierr)
  
  if(mr==0) then

    if(iargc() > 0) then
      call getarg(1, arg)
      if(iargc()>2 .or. arg=='-h') then
        print *,"Usage: ./mmult SIZE FILENAME"
        print *,"    -h: display this help message"
        print *,"    SIZE: size of the matrix to compute (default is ", DEFAULT_SIZE, ")"
        print *,"    FILENAME: output matrix file name (default is ", DEFAULT_FN, ")"

        call exit(1)
      end if
    end if

    if(iargc()>0) then
      call getarg(1, arg)
      read(arg, '(i10)') sz ! set sz for master
    else
      sz=DEFAULT_SIZE
    end if

    if(iargc()==2) then
      call getarg(2, filename) ! set filename
    else
      filename=DEFAULT_FN
    end if

    remainder = mod(sz,nproc)
    if(remainder/=0) then
      print *, mr, ": Info: reducing SIZE (", sz, ") to", sz-remainder

      sz = sz-remainder
    end if

    print *, mr, ": Size of the matrices: ", sz, "x", sz
    
    do i=1,nproc-1
      call MPI_Send(sz, 1, MPI_INT, i, i, MPI_COMM_WORLD, ierr)
    end do
  else
    call MPI_Recv(sz, 1, MPI_INT, 0, mr, MPI_COMM_WORLD, st, ierr) ! set sz for slaves
  end if

  slice=sz/nproc ! set slice size in number of elements

  if(mr==0) then
    allocate(mat_a(sz,sz))
    allocate(mat_b(sz,sz))
    allocate(mat_c(sz,sz))

    print *,mr,": Initializing matrices..."

    call minit(sz, mat_a)
    call minit(sz, mat_b)
    call minit(sz, mat_c)
    
    print *,mr,": Sending matrices..."

    do i=1,nproc-1
      call MPI_Send(mat_a(:,i*slice+1:(i+1)*slice), slice*sz, MPI_DOUBLE, i, 100+i, MPI_COMM_WORLD, ierr)
      call MPI_Send(mat_b, sz*sz, MPI_DOUBLE, i, 200+i, MPI_COMM_WORLD, ierr)
      call MPI_Send(mat_c(:,i*slice+1:(i+1)*slice), slice*sz, MPI_DOUBLE, i, 300+i, MPI_COMM_WORLD, ierr)
    end do
  else
    allocate(mat_a(sz,slice))
    allocate(mat_b(sz,sz))
    allocate(mat_c(sz,slice))

    print *,mr,": Receiving matrices..."
    
    call MPI_Recv(mat_a, slice*sz, MPI_DOUBLE, 0, 100+mr, MPI_COMM_WORLD, st, ierr)
    call MPI_Recv(mat_b, sz*sz, MPI_DOUBLE, 0, 200+mr, MPI_COMM_WORLD, st, ierr)
    call MPI_Recv(mat_c, slice*sz, MPI_DOUBLE, 0, 300+mr, MPI_COMM_WORLD, st, ierr)
  end if
  
  print *,mr,": Processing..."

  call mmult(sz, nproc, mat_a, mat_b, mat_c)

  if(mr==0) then
    print *,mr,": Receiving result matrix..."

    do i=1,nproc-1
      call MPI_Recv(mat_c(:,i*slice+1:(i+1)*slice), slice*sz, MPI_DOUBLE, i, 500+i, MPI_COMM_WORLD, st, ierr)
    end do
  else
    print *,mr,": Sending result matrix..."
    
    call MPI_Send(mat_c, slice*sz, MPI_DOUBLE, 0, 500+mr, MPI_COMM_WORLD, ierr)
  end if

  if(mr==0) then
    print *,mr,": Writing results..."
    call mwrite(sz, mat_c, filename)
    print *,mr,": Done."
  endif

  deallocate(mat_a)
  deallocate(mat_b)
  deallocate(mat_c)

  call MPI_Finalize(ierr)

contains

  subroutine minit(sz, A)
    integer, intent(in)   :: sz
    real(8), intent(out)  :: A(sz,sz)
    real(8)               :: num
    integer               :: i,j

    do i=1,sz
      do j=1,sz
        A(j,i)=(i-1)*j
      end do
    enddo
  end subroutine minit

  subroutine mwrite(sz, A, fn)
    integer, intent(in)       :: sz
    real(8), intent(in)       :: A(sz,sz)
    character(32), intent(in) :: fn
    integer                   :: i,j

    open(unit=12, file=fn, status="replace")

    do i=1,sz
      do j=1,sz
        write(12, "(E10.3)", advance="no") A(j,i)
      end do
      write(12, "(A)", advance="yes") " "
    end do
    close(12)
  end subroutine mwrite

  subroutine mmult(sz, nslices, A, B, C)
    integer, intent(in)     :: sz, nslices
    real(8), intent(in)     :: A(sz,sz), B(sz,sz)
    real(8), intent(inout)  :: C(sz,sz)
    integer                 :: i,j,k
    real(8)                 :: res

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

end program mmult_F90

