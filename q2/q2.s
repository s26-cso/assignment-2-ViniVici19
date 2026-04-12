.data
space:    .asciz " "         # need this to print spaces between numbers
newline:  .asciz "\n"        # need this for the newline at the end

.text
.globl main
main:
    # save all the callee-saved registers I'll need
    addi sp, sp, -36         # make room for saving registers
    sw   ra, 32(sp)          # save return address
    sw   s0, 28(sp)          # s0 = argc (number of args including program name)
    sw   s1, 24(sp)          # s1 = pointer to argv
    sw   s2, 20(sp)          # s2 = n (number of actual elements = argc - 1)
    sw   s3, 16(sp)          # s3 = pointer to my array of parsed integers
    sw   s4, 12(sp)          # s4 = pointer to my result array
    sw   s5, 8(sp)           # s5 = pointer to my stack array
    sw   s6, 4(sp)           # s6 = stack top index (how many things on my stack)
    sw   s7, 0(sp)           # s7 = loop counter

    mv   s0, a0              # save argc
    mv   s1, a1              # save argv
    addi s2, a0, -1          # n = argc - 1 (skip the program name)

    # need to allocate memory for 3 arrays, each of size n*4 bytes:
    #   1. arr[] - to hold the parsed integers
    #   2. result[] - to hold the answers
    #   3. stack[] - to use as my stack

    slli a0, s2, 2           # calculate n * 4 bytes for my integer array
    call malloc              # ask for memory
    mv   s3, a0              # save the pointer to my array

    slli a0, s2, 2           # calculate n * 4 bytes for my result array
    call malloc
    mv   s4, a0              # save the pointer to my result array

    slli a0, s2, 2           # calculate n * 4 bytes for my stack
    call malloc
    mv   s5, a0              # save the pointer to my stack
    li   s7, 0               # start my loop counter at 0

parse_loop:
    bge  s7, s2, parse_done  # If all n elements have been parsed, then done
    addi t0, s7, 1           # t0 = i + 1 (to skip argv[0] which is program name)
    slli t0, t0, 2           # t0 = (i+1) * 4 (byte offset into argv)
    add  t0, s1, t0          # t0 = &argv[i+1]
    lw   a0, 0(t0)           # a0 = argv[i+1] (the string pointer)
    call atoi                # convert the string to an integer, result in a0

    slli t1, s7, 2           # t1 = i * 4 (byte offset into my array)
    add  t1, s3, t1          # t1 = &arr[i]
    sw   a0, 0(t1)           # store the parsed integer into arr[i]

    addi s7, s7, 1           # move to the next element
    j    parse_loop

parse_done:
    # initialize the result array to all -1s
    li   s7, 0               # reset my counter

init_result:
    bge  s7, s2, init_done   # If all elements have been initialized, then done
    slli t0, s7, 2           # t0 = i * 4
    add  t0, s4, t0          # t0 = &result[i]
    li   t1, -1              # store -1 as the default
    sw   t1, 0(t0)           # result[i] = -1
    addi s7, s7, 1           # Next element
    j    init_result

init_done:
    # run the next greater element algo
    # iterate from the last element backwards to the first
    li   s6, 0               # stack starts empty (stack top index = 0)
    addi s7, s2, -1          # start from i = n - 1 (the last element)

nge_loop:
    blt  s7, zero, nge_done  # If i < 0, then done

    # I load arr[i] into t0
    slli t2, s7, 2           # t2 = i * 4
    add  t2, s3, t2          # t2 = &arr[i]
    lw   t0, 0(t2)           # t0 = arr[i], the current element

    # While stack is not empty and arr[stack.top()] <= arr[i], I pop
pop_loop:
    beq  s6, zero, pop_done  # If stack is empty, stop popping

    # peek at the top of my stack to get the index stored there
    addi t3, s6, -1          # t3 = stack_top_index - 1
    slli t3, t3, 2           # t3 *= 4
    add  t3, s5, t3          # t3 = &stack[top-1]
    lw   t4, 0(t3)           # t4 = stack.top() (this is an index into arr)

    # I load arr[stack.top()] to compare with arr[i]
    slli t5, t4, 2           # t5 = stack.top() * 4
    add  t5, s3, t5          # t5 = &arr[stack.top()]
    lw   t5, 0(t5)           # t5 = arr[stack.top()]

    bgt  t5, t0, pop_done    # If arr[stack.top()] > arr[i], stop (found something greater)

    # arr[stack.top()] <= arr[i], so I pop it off
    addi s6, s6, -1          # pop by decrementing the stack top index
    j    pop_loop             # check again

pop_done:
    # If the stack isn't empty, the top has the index of the next greater element
    beq  s6, zero, skip_update  # If stack is empty, no next greater element exists

    # result[i] = stack.top()
    addi t3, s6, -1          # peek at the top of the stack again
    slli t3, t3, 2
    add  t3, s5, t3
    lw   t4, 0(t3)           # t4 = stack.top() (the position of next greater)

    slli t3, s7, 2           # t3 = i * 4
    add  t3, s4, t3          # t3 = &result[i]
    sw   t4, 0(t3)           # result[i] = stack.top()

skip_update:
    # push the current index i onto the stack
    slli t3, s6, 2           # t3 = stack_top * 4
    add  t3, s5, t3          # t3 = &stack[stack_top]
    sw   s7, 0(t3)           # stack[stack_top] = i
    addi s6, s6, 1           # increment stack top

    addi s7, s7, -1          # move to the previous element (i--)
    j    nge_loop

nge_done:
    # print the result array
    li   s7, 0               # reset counter

print_loop:
    bge  s7, s2, print_done  # If all elements have been printed, then done

    slli t0, s7, 2           # t0 = i * 4
    add  t0, s4, t0          # t0 = &result[i]
    lw   a0, 0(t0)           # a0 = result[i]
    call print_int           # print the integer

    # print a space after each number except the last
    addi t0, s7, 1           # t0 = i + 1
    bge  t0, s2, no_space    # If this is the last element, skip the space
    la   a0, space           # load the address of my space string
    call print_string        # print a space
no_space:

    addi s7, s7, 1           # Next element
    j    print_loop

print_done:
    # print a newline at the end
    la   a0, newline
    call print_string

    # free allocated memory (being a good citizen)
    mv   a0, s3
    call free
    mv   a0, s4
    call free
    mv   a0, s5
    call free

    # return 0 from main
    li   a0, 0

    # restore saved registers
    lw   ra, 32(sp)
    lw   s0, 28(sp)
    lw   s1, 24(sp)
    lw   s2, 20(sp)
    lw   s3, 16(sp)
    lw   s4, 12(sp)
    lw   s5, 8(sp)
    lw   s6, 4(sp)
    lw   s7, 0(sp)
    addi sp, sp, 36          # clean up the stack
    ret


# print_int(int value in a0)
# print an integer using printf with "%d" format
print_int:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   a0, 0(sp)           # save the value

    mv   a1, a0              # a1 = the integer to print (second arg for printf)
    la   a0, fmt_int         # a0 = format string "%d"
    call printf

    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# print_string(char* str in a0)
# print a string using printf
print_string:
    addi sp, sp, -4
    sw   ra, 0(sp)

    call printf              # printf(a0) - a0 already has the string

    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

.data
fmt_int:  .asciz "%d"        # use this format string to print integers
