.data
filename:  .string "input.txt"    # The file I need to read
yes_msg:   .string "Yes\n"        # print this if it's a palindrome
no_msg:    .string "No\n"         # print this if it's not a palindrome

buffer:    .space 1024            

.text
.globl main
main:
    addi sp, sp, -32         # make room on the stack
    sw   ra, 28(sp)          # save return address
    sw   s0, 24(sp)          # s0 = file descriptor (temporarily)
    sw   s1, 20(sp)          # s1 = left index
    sw   s2, 16(sp)          # s2 = right index
    sw   s3, 12(sp)          # s3 = file size

    # Open the file
    # I use openat (56). AT_FDCWD (-100) just tells it to look in the current folder.
    li   a7, 56              # syscall number for openat
    li   a0, -100            # AT_FDCWD = -100
    la   a1, filename        # a1 = pointer to input.txt
    li   a2, 0               # O_RDONLY = 0 read only
    li   a3, 0               # mode = 0
    ecall                    # make the system call
    mv   s0, a0              # save the file descriptor in s0

    # Read the entire file into my buffer in memory at once
    li   a7, 63              # syscall number for read
    mv   a0, s0              # a0 = my file descriptor
    la   a1, buffer          # a1 = pointer to my big buffer
    li   a2, 1024            # a2 = maximum bytes to read
    ecall                    # make the system call
    
    # read syscall automatically returns the numberof bytes read in a0.
    mv   s3, a0              # s3 = the actual file size

    # closing, the file since I don't need it open anymore because everything is safely in my array
    li   a7, 57              # syscall close
    mv   a0, s0
    ecall

    # Set up my two pointers for the palindrome check
    li   s1, 0               # s1 = Left index starts at 0
    addi s2, s3, -1          # s2 = Right index starts at the end (size - 1)
    la   t4, buffer          # t4 = base address of my buffer

check_loop:
    bge  s1, s2, is_palindrome  # If left index >= right index, they met, meaning it's a palindrome.

    # load the character at the left index
    add  t0, t4, s1          # memory address = buffer + left_index
    lbu  t5, 0(t0)           # t5 = left character

    # load the character at the right index
    add  t1, t4, s2          # memory address = buffer + right_index
    lbu  t6, 0(t1)           # t6 = right character

    # compare the two characters
    bne  t5, t6, not_palindrome # If they don't match, it's NOT a palindrome

    # if they match move both pointers inward
    addi s1, s1, 1           # move left index 1 step to the right
    addi s2, s2, -1          # move right index 1 step to the left
    j    check_loop          # check the next pair

is_palindrome:
    # I print "Yes"
    li   a7, 64              # syscall write
    li   a0, 1               # fd = 1 (stdout)
    la   a1, yes_msg
    li   a2, 4               # "Yes\n" is 4 bytes
    ecall
    j    done

not_palindrome:
    # I print "No"
    li   a7, 64              # syscall write
    li   a0, 1               # fd = 1 (stdout)
    la   a1, no_msg
    li   a2, 3               # "No\n" is 3 bytes
    ecall

done:
    # I return 0 from main
    li   a0, 0
    lw   ra, 28(sp)
    lw   s0, 24(sp)
    lw   s1, 20(sp)
    lw   s2, 16(sp)
    lw   s3, 12(sp)
    addi sp, sp, 32
    ret