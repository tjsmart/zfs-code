!
!  Original Version Created Wed. June 19th 2019 by Tyler J. Smart
!  This code calculates the ZFS parameter as in the PRB:
!    ”First principles method for the calculation of zero-field splitting tensors in periodic systems”,
!    M. J. Rayson and P. R. Briddon, Physical Review B 77, 035119 (2008)
!


program main

!< modules and subroutines >!
    use params,            only : dp
    use mpi_var,           only : mpi_get_var
    use intro_outro,       only : intro, outro
    use input,             only : command_input, parse_input, print_input
    use loop_var,          only : init_loop_array
    use readmod,           only : read_length, read_grid, read_wfc
    use printmod,          only : printIntegerArray, printComplexArray
    use main_inner,        only : inner_routine
    use main_mpi,          only : mpi_routine
    use zfs_calc,          only : calc_ZFS
    use mpi

    implicit none

    
!< user input variables >!
    character(len=256)          :: file_in, export_dir
    real(dp)                    :: alat
    integer                     :: band_min, band_max, occ_up, occ_dn
    logical                     :: direct_flag
    character(len=16)           :: verbosity

!< internal variables >!
    ! mpi variables
    integer                     :: nproc, ierr, myrank, root_rank
    logical                     :: is_root
    ! loop array containing ispin, iband , and jband
    integer, allocatable        :: loop_array(:,:)
    integer                     :: loop_size
    ! dimensions and file names
    integer                     :: npw, dim_G = 3
    character(len=256)          :: file_G, file_w1, file_w2
    ! main functions
    integer, allocatable        :: grid(:,:)                                            ! dim (npw,3)
    complex(dp), allocatable    :: wfc1(:), wfc2(:)                                     ! dim (npw) defined over grid
    complex(dp), allocatable    :: f1_G(:), f2_G(:), f2_minusG (:), f3_G(:), rho_G(:)   ! dim (npw) defined over grid
    ! I_zz parameter
    complex(dp)                 :: I_zz
    ! other
    character(len=4)            :: indent="    "
    character(len=64)           :: prog="ZFS"

!< output variables >!
    ! ZFS parameters in eV, GHz, and cm-1
    real(dp)                    :: D_en, D_fr1, D_fr2


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!                            Beginning program                              !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!< initialize mpi and get nproc, myrank, and is_root >!
    call MPI_INIT (ierr) 
    call mpi_get_var(nproc, myrank, is_root)

!< print introduction >!
    if ( is_root ) then
        call intro(prog)
    end if

!< Read input file (file_G,file_w1,file_w2,alat)>!
    call command_input(file_in)
    call parse_input(file_in, export_dir, band_min, band_max, occ_up, occ_dn, alat, direct_flag, verbosity)
    if ( is_root ) then
        call print_input( file_in, export_dir, band_min, band_max, occ_up, occ_dn, alat, direct_flag, verbosity)
    end if

!< Read in number of plane waves (npw) >!
    file_G  = trim(export_dir) // "/" // "grid.txt"
    call read_length(file_G,npw)

!< Read in grid of G vectors (grid) >!
    allocate (grid(npw,dim_G))
    call read_grid(file_G,npw,dim_G,grid)


!< Begin Calculation >!
    if ( is_root ) then
        print *
        print *, "Beginning Calculation of ZFS"
        print *
    end if

!< Below begins structure of do loop over bands specified by input file !

    ! create loop_array = ((ispin, i, j) ... )
    call init_loop_array(band_min, band_max, occ_up, occ_dn, loop_size, loop_array)

    if ( is_root ) then
        print "(a5,a29,i9)", indent, "number of steps to compute = ", loop_size
        if ( loop_size .le. 20 ) then
            call printIntegerArray(loop_array,loop_size,3,loop_size)
        end if
        print *

        print *, indent, "computing I_zz"
    end if

    call mpi_routine(verbosity, direct_flag, npw, dim_G, grid, export_dir, loop_size, loop_array, I_zz)
    


!< End of loop section print final I_zz >!
    if ( is_root ) then
        print *, "================================"
        print "(a14,e13.6e2)", "Final I_zz = ", real(I_zz)
    end if


!< Calculate ZFS >!
    if ( is_root ) then
        call calc_ZFS(alat,I_zz,D_en,D_fr1,D_fr2)
        print *
        print *, "================================"
        print "(a9,f10.6,a7,f10.6,a5)", "! ZFS = ", D_fr1, " GHz = ", D_fr2, " cm-1"
    end if


!< print outro >!
    if ( is_root ) then
        call outro()
    end if

    call MPI_FINALIZE (ierr)


end program main