.text

# make_node(int val)
# I receive the value in a0, and I need to return a pointer to a new Node
# On RV64, struct Node { int val; Node* left; Node* right; } is 24 bytes:
#   offset 0:  val   (4 bytes, int)
#   offset 8:  left  (8 bytes, pointer, aligned to 8)
#   offset 16: right (8 bytes, pointer)
.globl make_node
make_node:
    # I need to save my return address and the value, because malloc will rewrite them
    addi sp, sp, -16         # making room on the stack (16-byte aligned)
    sd   ra, 8(sp)           # save return address (8 bytes on RV64)
    sw   a0, 0(sp)           # save the value (a0) - only need 4 bytes for an int

    # I need 24 bytes for my Node struct on RV64
    li   a0, 24              # asking malloc for 24 bytes
    call malloc              # malloc gives me a pointer in a0

    # Now a0 has the pointer to my new node
    lw   t0, 0(sp)           # get back the value saved earlier
    sw   t0, 0(a0)           # store the value into node->val (int, 4 bytes)
    sd   zero, 8(a0)         # set node->left = NULL (pointer, 8 bytes)
    sd   zero, 16(a0)        # set node->right = NULL (pointer, 8 bytes)

    # restore ra and clean up the stack before returning
    ld   ra, 8(sp)           # get back my return address (malloc overwrote it)
    addi sp, sp, 16          # free the stack space I allocated
    # a0 already holds the pointer to my new node, so just return
    ret

# insert(Node* root, int val)
# I receive root in a0 and the value to insert in a1 and need to return the root of the tree
.globl insert
insert:
    addi sp, sp, -32         # make room on the stack (4 regs * 8 bytes = 32, already 16-byte aligned)
    sd   ra, 24(sp)          # save return address
    sd   s0, 16(sp)          # save s0 for root
    sd   s1, 8(sp)           # save s1 for the value
    sd   s2, 0(sp)           # save s2 for the parent
    mv   s1, a1              # copying of the value I want to insert in s1
    # If root is NULL, I just need to make a new node and return it
    bne  a0, zero, insert_not_null  # If root isn't NULL, I skip ahead
    mv   a0, s1              # put the value in a0 as argument for make_node
    call make_node           # create a brand new node
    j    insert_done         # jump to cleanup, a0 has my new root

insert_not_null:
    mv   s0, a0              # save the root in s0 so I can return it at the end
    mv   s2, a0              # s2 is my "current" pointer as I walk down the tree

insert_walk:
    lw   t0, 0(s2)           # load the current node's value (int, 4 bytes)
    blt  s1, t0, insert_go_left   # If my value < current value, go left
    # Otherwise, my value >= current value, go right

insert_go_right:
    ld   t1, 16(s2)          # load the right child pointer (offset 16, 8 bytes on RV64)
    beq  t1, zero, insert_attach_right  # If right child is NULL, attach here
    mv   s2, t1              # Otherwise, move down to the right child
    j    insert_walk         # keep moving down the tree

insert_attach_right:
    mv   a0, s1              # put the value in a0 for make_node
    call make_node           # create the new node
    sd   a0, 16(s2)          # attach it as the right child of the current node (pointer, 8 bytes)
    mv   a0, s0              # put the original root back in a0 as my return value
    j    insert_done

insert_go_left:
    ld   t1, 8(s2)           # load the left child pointer (offset 8, 8 bytes on RV64)
    beq  t1, zero, insert_attach_left   # If left child is NULL, attach here
    mv   s2, t1              # Otherwise, move down to the left child
    j    insert_walk         # keep moving down the tree

insert_attach_left:
    mv   a0, s1              # put the value in a0 for make_node
    call make_node           # create the new node
    sd   a0, 8(s2)           # attach it as the left child of the current node (pointer, 8 bytes)
    mv   a0, s0              # put the original root back in a0 as my return value

insert_done:
    ld   ra, 24(sp)          # restore return address
    ld   s0, 16(sp)          # restore s0
    ld   s1, 8(sp)           # restore s1
    ld   s2, 0(sp)           # restore s2
    addi sp, sp, 32          # clean up stack space
    ret                      # return the root


# get(Node* root, int val)
# receive root in a0 and the value I'm looking for in a1
# return a pointer to the node with that value, or NULL if not found
.globl get
get:
    # don't need to save anything because I'm not calling other functions
    # just walk through the tree iteratively

get_loop:
    beq  a0, zero, get_not_found  # If current node is NULL, the value isn't in the tree
    lw   t0, 0(a0)           # load the current node's value (int, 4 bytes)
    beq  a1, t0, get_found   # If it matches what I'm looking for, done
    blt  a1, t0, get_left    # If my value < node's value, go left

    # My value > node's value, so go right
    ld   a0, 16(a0)          # move to the right child (pointer at offset 16)
    j    get_loop            # keep searching

get_left:
    ld   a0, 8(a0)           # move to the left child (pointer at offset 8)
    j    get_loop            # keep searching

get_found:
    ret                      # a0 already points to the node I found, so I just return

get_not_found:
    li   a0, 0               # return NULL (0) because the value wasn't found
    ret


# getAtMost(int val, Node* root)
# receive the target value in a0 and the root in a1
# need to find the greatest value in the tree that is <= val
# return -1 if no such value exists
.globl getAtMost
getAtMost:
    # don't call other functions so don't need to save ra
    mv   t2, a0              # save the target value in t2
    mv   a0, a1              # move root to a0 so I can use it as my pointer
    li   t3, -1              # t3 is my "best answer so far", starting at -1 (meaning nothing found)

getAtMost_loop:
    beq  a0, zero, getAtMost_done  # If I've hit NULL, I'm done searching
    lw   t0, 0(a0)           # load the current node's value (int, 4 bytes)

    bgt  t0, t2, getAtMost_go_left  # If node's value > target, it's too big, go left

    # The node's value <= target, so it's a candidate for my answer
    # check if this is better than my current best
    bge  t0, t3, getAtMost_update  # If this value >= my current best, update
    j    getAtMost_go_right   # Otherwise keep going right for bigger values

getAtMost_update:
    mv   t3, t0              # found a better answer, update my best

getAtMost_go_right:
    ld   a0, 16(a0)          # go right (pointer at offset 16) for bigger values still <= target
    j    getAtMost_loop

getAtMost_go_left:
    ld   a0, 8(a0)           # go left (pointer at offset 8) for smaller values
    j    getAtMost_loop

getAtMost_done:
    mv   a0, t3              # put my best answer in a0 to return it
    ret                      # return the greatest value <= target