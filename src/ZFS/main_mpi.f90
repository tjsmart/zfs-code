module main_mpi

    use params,            only : dp
    use main_inner,        only : inner_routine
    use printmod,          only : printIntegerArray
    use mpi_var,           only : mpi_get_var
    use mpi

    implicit none

contains

    subroutine mpi_routine(verbosity, direct_flag, npw, dim_G, grid, nbnd, wfc_all, b, export_dir, loop_size, loop_array, I_ab)
    ! evaluates inner routine looping over loop_array values
    ! returns I_zz_out -- a portion of the I_zz value
    
        ! input variables -- fed to inner loop
        integer, intent(in)                             :: npw, dim_G, loop_size
        integer, dimension(npw, dim_G), intent(in)      :: grid
        character(len=256), intent(in)                  :: export_dir
        integer, dimension(loop_size,3), intent(in)     :: loop_array
        logical                                         :: direct_flag
        character(len=16), intent(in)                   :: verbosity
        
        ! mpi variables
        integer                                         :: nproc, myrank, root_rank
        logical                                         :: is_root
        integer                                         :: ierr, status(MPI_STATUS_SIZE)

        ! internal variables -- dummy variables
        integer                                         :: arank, i, remainder
        ! internal variables -- interfaced with inner_routine
        integer                                         :: myloop_size, mystart
        integer, allocatable                            :: myloop_array(:,:)
        complex(dp)                                     :: myI_zz, yourI_zz

        ! return variables
        ! complex(dp), intent(out)                        :: I_zz
!!!!!!!!!! new
        real(dp), dimension(3,3)                        :: myI_ab
        real(dp), dimension(3,3), intent(out)           :: I_ab
        real(dp), dimension(9)           :: test
        real(dp), dimension(3,3)                        :: b
        integer, intent(in)                             :: nbnd
        complex(dp), dimension(2,nbnd,npw), intent(in)  :: wfc_all
!!!!!!!!!! endnew

        call mpi_get_var(nproc, myrank, is_root)
        root_rank = 0

        ! calculate lowest loop size (integer division) and remainder
        myloop_size = loop_size / nproc
        remainder = mod(loop_size, nproc)

        ! increase loop size in case of a remainder
        if ( myrank .lt. remainder ) then
            myloop_size = myloop_size + 1
        end if

        ! calculate starting position
        if (myrank .lt. remainder ) then
            mystart = myloop_size * myrank + 1
        else
            mystart = myloop_size * myrank + remainder + 1
        end if

        ! allocate loop_array and form from subsection of loop_array defined by start and loop size
        allocate( myloop_array( myloop_size, 3 ) )
        ! print *, myrank, "'s start is: ", mystart, "  and end is", mystart + myloop_size -1
        do i = 1, myloop_size
            myloop_array( i, : ) = loop_array( (mystart + i - 1), : )
        end do

        ! ! compare with full loop array
        ! print *, myrank, "'s loop array is: "
        ! call printIntegerArray( myloop_array, myloop_size, 3, myloop_size )

        ! compute inner routine
        ! call inner_routine(verbosity, direct_flag, npw, dim_G, grid, export_dir, myloop_size, myloop_array, myI_zz)
!!!!!!!!!! new
        call inner_routine(verbosity, direct_flag, npw, dim_G, grid, nbnd, wfc_all, b, export_dir, myloop_size, myloop_array, myI_ab)
!!!!!!!!!! new

!!!!!!!!!! new
        ! report myI_ab
        ! print *, "My rank is ", myrank, " myI_ab is ", myI_ab
!!!!!!!!!! endnew


        ! collect and sum myI_ab into final I_ab
!!!!!!!!!! new
        call MPI_REDUCE(myI_ab, I_ab, 9, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
!!!!!!!!!! endnew

        
    
    end subroutine mpi_routine


end module main_mpi