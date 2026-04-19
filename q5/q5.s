.data
filename:   .asciz "input.txt"    # The file I need to read
yes_msg:    .asciz "Yes\n"        # print this if it's a palindrome
no_msg:     .asciz "No\n"         # print this if it's not a palindrome
buf_left:   .byte 0               # use this tiny 1-byte buffer for the left character
buf_right:  .byte 0               # use this tiny 1-byte buffer for the right character

.text
.globl main
main:
    addi sp, sp, -48         # make room on the stack (16-byte aligned for RV64)
    sd   ra, 40(sp)          # save return address (8 bytes on RV64)
    sd   s0, 32(sp)          # s0 = file descriptor
    sd   s1, 24(sp)          # s1 = left pointer (starts at 0)
    sd   s2, 16(sp)          # s2 = right pointer (starts at end - 1)
    sd   s3, 8(sp)           # s3 = file size

    # open the file
    # use the openat syscall (56) with AT_FDCWD (-100) to open relative to cwd
    li   a7, 56              # syscall number for openat
    li   a0, -100            # AT_FDCWD = -100 (means "current directory")
    la   a1, filename        # a1 = pointer to "input.txt"
    li   a2, 0               # O_RDONLY = 0 (only need to read)
    li   a3, 0               # mode = 0 (not creating a file)
    ecall                    # make the system call
    mv   s0, a0              # save the file descriptor in s0

    # find out how long the file is using lseek
    # lseek(fd, 0, SEEK_END) tells me the file size
    li   a7, 62              # syscall number for lseek
    mv   a0, s0              # a0 = my file descriptor
    li   a1, 0               # offset = 0
    li   a2, 2               # SEEK_END = 2 (go to the end of the file)
    ecall                    # Now a0 has the file size!
    mv   s3, a0              # save the file size

    # check if the file might have a trailing newline
    # If the last character is '\n', subtract 1 from the size
    # (because newlines aren't part of the palindrome check)
    addi t0, s3, -1          # t0 = position of last byte
    blt  t0, zero, is_palindrome  # If file is empty, it's a palindrome (edge case)

    # seek to the last byte to check if it's a newline
    li   a7, 62              # lseek again
    mv   a0, s0
    mv   a1, t0              # offset = file_size - 1
    li   a2, 0               # SEEK_SET = 0
    ecall

    # read 1 byte from the end
    li   a7, 63              # syscall read
    mv   a0, s0              # fd
    la   a1, buf_left        # reuse this buffer temporarily
    li   a2, 1               # read 1 byte
    ecall

    la   t0, buf_left
    lbu  t1, 0(t0)           # load the byte I just read
    li   t2, 10              # 10 is the ASCII code for newline '\n'
    bne  t1, t2, no_newline  # If it's not a newline, I keep the full size
    addi s3, s3, -1          # subtract 1 because the last char is just a newline

no_newline:
    # set up my two pointers
    li   s1, 0               # Left pointer starts at the beginning (position 0)
    addi s2, s3, -1          # Right pointer starts at the end (position size - 1)

check_loop:
    bge  s1, s2, is_palindrome  # If left >= right, they've met in the middle - it's a palindrome!

    # read the character at position s1 (left pointer)
    li   a7, 62              # lseek to position s1
    mv   a0, s0
    mv   a1, s1              # offset = left
    li   a2, 0               # SEEK_SET
    ecall

    li   a7, 63              # read 1 byte
    mv   a0, s0
    la   a1, buf_left        # read into my left buffer
    li   a2, 1
    ecall

    # read the character at position s2 (right pointer)
    li   a7, 62              # lseek to position s2
    mv   a0, s0
    mv   a1, s2              # offset = right
    li   a2, 0               # SEEK_SET
    ecall

    li   a7, 63              # read 1 byte
    mv   a0, s0
    la   a1, buf_right       # read into my right buffer
    li   a2, 1
    ecall

    # compare the two characters
    la   t0, buf_left
    lbu  t0, 0(t0)           # t0 = left character
    la   t1, buf_right
    lbu  t1, 0(t1)           # t1 = right character

    bne  t0, t1, not_palindrome  # If they don't match, it's NOT a palindrome

    # They match! move both pointers inward
    addi s1, s1, 1           # move left pointer one step to the right
    addi s2, s2, -1          # move right pointer one step to the left
    j    check_loop           # check the next pair

is_palindrome:
    # close the file first
    li   a7, 57              # syscall close
    mv   a0, s0
    ecall

    # print "Yes"
    li   a7, 64              # syscall write
    li   a0, 1               # fd = 1 (stdout)
    la   a1, yes_msg
    li   a2, 4               # "Yes\n" is 4 bytes
    ecall

    j    done

not_palindrome:
    # close the file first
    li   a7, 57              # syscall close
    mv   a0, s0
    ecall

    # print "No"
    li   a7, 64              # syscall write
    li   a0, 1               # fd = 1 (stdout)
    la   a1, no_msg
    li   a2, 3               # "No\n" is 3 bytes
    ecall

done:
    # return 0 from main
    li   a0, 0
    ld   ra, 40(sp)
    ld   s0, 32(sp)
    ld   s1, 24(sp)
    ld   s2, 16(sp)
    ld   s3, 8(sp)
    addi sp, sp, 48
    ret