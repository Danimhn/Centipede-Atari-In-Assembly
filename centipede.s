##################################################################### 
# Bitmap Display Configuration: 
# - Unit width in pixels: 8 
# - Unit height in pixels: 8 
# - Display width in pixels: 512
# - Display height in pixels: 512
# - Base Address for Display: 0x10008000 ($gp) 
#####################################################################
.data
        debug: .ascii "*"
	displayAddress: .word 0x10008000 #Treated as row/column 0 to 31
	red: .word 0xff0000
	green: .word 0x00ff00
	greenForBlaster: .word 0x3B7A57
	redForBlaster: .word 0xD3212D
	yellow: .word 0xFFEE00
	bulletColor: .word 0xA0E8E0
	wormHead: .word 0x61A301
	blue: .word 0x0000ff
	white: .word 0xffffff
	brown: .word 0xA3520D
	fleaWing: .word 0x6AFF4D
	fleaBody: .word 0x4DE1FF
	wormBody2: .word 0xCCBDAF
	blasterLocation: .word 15 30
	centipedeLocation: .word 31 0 32 0 33 0 34 0 35 0 36 0 37 0 38 0 39 0 40 0
	centipedeInitialLocation: .word 31 0 32 0 33 0 34 0 35 0 36 0 37 0 38 0 39 0 40 0#Used to make new centipedes mid game
	isHead: .word 1 0 0 0 0 0 0 0 0 0
	bulletsLocation: .word -1:60
	bulletCount: .word 0
	mushroomsLocation: .word -1:1000 # x, and y coord of all possible 500 mushrooms, initialized to -1 -> non existant
	mushroomCount: .word 0
	mushroomsBlasted: .word -1:30 #This is the location of all mushrooms blasted during the loop,
	                              # this is used to repaint the screen. (Maxmimum number of mushrooms that
	                              # could be balsteed duringa single loop is 15)
	mushBlastedCount: .word 0 #Number of mushrooms blasted during the loop
	centipedeLives: .word
	blastersLastMove: .word 0 #Used to repaint the the screen
	fleaLocation: .word 0 27
	fleaDirection: .word 1 #Along the x-axis
	fleaMovementFlag: .word 0 # Used for repainting, 0 : no movement, and 1: movement
	fleaAlive: .word 0 #Whether or not there's an alive flea on the screen.
	fleaBeenDeadfor: .word 0
	gameOver: .word 0
.text 

Main:
 
 jal Restart
 jal DrawBlaster
 jal DrawCentipede
 jal InitializeMushrooms
 
 
  #Variable used to lower the speed of flea movements, by updating it's location every 2 iterations
 loop:
 
  #Logic:
  # To avoid a nasty bug with the MIMO simulator, instead of sleeping 40 ms,
  # we will sleep 1 ms 40 times checking the inouts everytime, and then passing
  # in the last input as the parameter to HandleInput
  li $s6, 0
  li $t1, 0
  loop2:
   beq $s6, 40, End9
   
   li $v0, 32# Sleep op code
   li $a0, 1# Sleep 1/1000 second 
   syscall
   
   addi $s6, $s6, 1
   
   lw $t0, 0xffff0000 
   bne $t0, 1, loop2
   lw $t1, 0xffff0004
   j loop2
   
  End9:
  addi $sp, $sp, -4
  sw $t1, 0($sp) #Parameter for HandleInput
  jal HandleInput
  #Check if game is over, awaiting for a restart:
  lw $t0, gameOver
  beq $t0, 1, GOver
  jal CheckBulletColision
  jal Repaint
  jal UpdateCentipedeLocation
  jal UpdateBullets
  
  lw $s0, fleaMovementFlag
  
  beq $s0, 1, FleaMovement
  
  li $s0, 1
  sw $s0, fleaMovementFlag
  j AfterFlea
  FleaMovement:
  jal UpdateFleaLocation
  li $s0, 0
  sw $s0, fleaMovementFlag
  AfterFlea:
  #Check if the blaster has been collided with, if so, leave the loop
  jal CheckBlasterDeath
  #Checks if the centipede is dead, if so, sends in a new centipede:
  jal CheckCentDeath
  
  lw $t0, 0($sp) #Return value of CheckBlasterDeath
  addi $sp, $sp, 4
  bne $t0, 1, MoveOn14
  li $t0, 1
  sw $t0, gameOver
  MoveOn14:
  lw $t0, fleaAlive 
  beq $t0, 0, updateFleaDeath
  j MoveOn13
  #This code is responsible for regenerating fleas after a while:
  updateFleaDeath:
  lw $t0, fleaBeenDeadfor
  addi $t0, $t0, 1
  sw $t0, fleaBeenDeadfor
  bne $t0, 50, MoveOn13
  jal ReFlea #Add a new flea to the screen
  MoveOn13:
  
  
  #Render:
  jal DrawBullets
  jal DrawBlaster
  jal DrawMushrooms
  jal DrawCentipede
  jal DrawFlea
  
  GOver:
  j loop
  

 #End of main:
 jal Exit
 
 
Exit: 
 li $v0, 10 # terminate the program gracefully 
 syscall 

###############################################################
IsEven:
 lw $t5, 0($sp)
 add $t6, $t5, $zero
 srl $t6, $t5, 1
 sll $t6, $t6, 1
 bne $t6, $t5, Odd
 # If even store 1(true) at the top of the stack go back
 addi $t5, $zero, 1
 sw $t5, 0($sp)
 jr $ra
 # Else store 0(false) at the top of the stack go back
 Odd:
  addi $t5, $zero, 0
  sw $t5, 0($sp)
  jr $ra
###############################################################

###############################################################
 DrawCentipede:
  #For loop for drawing each segment:
  li $t7, 0
  For1:
   #Load x coord into t4, and y coord into t5
   mul $t5, $t7, 8
   lw $t4, centipedeLocation($t5)
   addi $t5, $t5, 4
   lw $t5, centipedeLocation($t5)
   #Checking if body part is in screen assuming centipede always enters from the right
   #so we're just checking if x is between 0 and 63, since if y is -1 then so is x.
   li $t0, 31
   slt $t0, $t0, $t4
   beq $t0, $zero, InRange1 # x <= 63
   j Increment1
   InRange1:
    li $t0, 0
    slt $t0, $t4, $t0
    beq $t0, $zero, Draw1 # x >= 0
    j Increment1
   Draw1:
    #Firgure out where to draw: Multiply the y coord by 128, add 2x to it and then multiply everything by 4 and store it in t5:
    addi $t6, $zero, 128
    mul $t5, $t5, $t6
    mul $t4, $t4, 2
    add $t5, $t5, $t4
    addi $t6, $zero, 4
    mul $t5, $t5, $t6
    lw $t0, displayAddress 
    add $t5, $t5, $t0
    #Figuring out whether this is a head:
    mul $t0, $t7, 4
    lw $t4, isHead($t0)
    bne $t4, $zero, Head1
    #Body:
    lw $t2, brown
    lw $t1, wormBody2
    sw $t1, 0($t5)
    sw $t2, 4($t5)
    sw $t1, 256($t5)
    sw $t2, 260($t5)
    j Increment1
    Head1:
     lw $t1, wormHead
     sw $t1, 0($t5)
     sw $t1, 4($t5)
     sw $t1, 256($t5)
     sw $t1, 260($t5)
    Increment1:
     addi $t7, $t7, 1
     beq $t7, 10, End1
     j For1
   End1:
    jr $ra 
###############################################################
  
###############################################################
UpdateCentipedeLocation:
 #Storing s registers:
 addi $sp, $sp, -4
 sw $s0, 0($sp)
 addi $sp, $sp, -4
 sw $s1, 0($sp)
 #For loop for updating each body segment:
 li $t7, 0
 For2:
  #Load x coord into s0, and y coord into s1
  mul $t5, $t7, 8
  lw $s0, centipedeLocation($t5)
  addi $t5, $t5, 4
  lw $s1, centipedeLocation($t5)
  #Check if y is -1, in other words, if that segment has been destroyed:
  beq $s1, -1, SandIncrement1
  #Checking if y coord is even, and storing 1 in t4 if it is and 0 otherwise:
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  addi $sp, $sp, -4
  sw $s1, 0($sp)
  jal IsEven
  lw $t4, 0($sp)
  addi $sp, $sp, 4
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  #If y was even subtract 1 from the x value, else add to it, unless the segment needs
  #to move down:
  addi $t5, $zero, 1
  bne $t4, $t5, Add1
  #Check whether the segment needs to move down:
  beq $s0, 0, Down1 #Because it has reached the end of a row
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  addi $sp, $sp, -4
  sw $t7, 0($sp)
  li $t0, -1
  addi $sp, $sp, -4
  sw $t0, 0($sp)
  jal CheckMushroomAhead
  lw $t0, 0($sp)
  addi $sp, $sp, 4
  lw $t7, 0($sp)
  addi $sp, $sp, 4
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  beq $t0, 1, Down1 #Because of mushroom ahead
  add $s0, $s0, -1
  j SandIncrement1
  Add1:
   #Check whether the segment needs to move down
   beq $s0, 31, Down1 #Because it has reached the end of a row
   addi $sp, $sp, -4
   sw $ra, 0($sp)
   addi $sp, $sp, -4
   sw $t7, 0($sp)
   li $t0, 1
   addi $sp, $sp, -4
   sw $t0, 0($sp)
   jal CheckMushroomAhead
   lw $t0, 0($sp)
   addi $sp, $sp, 4
   lw $t7, 0($sp)
   addi $sp, $sp, 4
   lw $ra, 0($sp)
   addi $sp, $sp, 4
   beq $t0, 1, Down1 #Because of mushroom ahead
   add $s0, $s0, 1
   j SandIncrement1
  Down1:
   add $s1, $s1, 1
  #Save the new coord and increment:
  SandIncrement1:
   mul $t5, $t7, 8
   sw $s0, centipedeLocation($t5)
   addi $t5, $t5, 4
   sw $s1, centipedeLocation($t5)
   addi $t7, $t7, 1
   beq $t7, 10, Return
   j For2
 Return:
  #Restoring s registers:
  lw $s1, 0($sp)
  addi $sp, $sp, 4
  lw $s0, 0($sp)
  addi $sp, $sp, 4
  jr $ra
###############################################################

###############################################################
DrawBlaster:
 lw $t0, displayAddress 
 #Load x coord into t4, and y coord into t5
 addi $t5, $zero, 0
 lw $t4, blasterLocation($t5)
 addi $t5, $t5, 4
 lw $t5, blasterLocation($t5)
 #Firgure out where to draw: Multiply the y coord by 128, add 2x to it and then multiply everything by 4 and store it in t5:
 addi $t6, $zero, 128
 mul $t5, $t5, $t6
 mul $t4, $t4, 2
 add $t5, $t5, $t4
 addi $t6, $zero, 4
 mul $t5, $t5, $t6
 add $t5, $t5, $t0
 #Drawing:
 lw $t2, greenForBlaster
 lw $t3, redForBlaster
 lw $t4, yellow
 #Barrel:
 sw $t4, 8($t5)
 sw $t4, 264($t5)
 #Body middle, including wings:
 sw $t2, 256($t5)
 sw $t2, 272($t5)
 sw $t2, 512($t5)
 sw $t3, 516($t5)
 sw $t3, 520($t5)
 sw $t3, 524($t5)
 sw $t2, 528($t5)
 #Body bottom, including wings:
 sw $t2, 768($t5)
 sw $t3, 772($t5)
 sw $t3, 776($t5)
 sw $t3, 780($t5)
 sw $t2, 784($t5)
 jr $ra
###############################################################
# Repaints the screen, but only repaints the squares that have 
# changed to avoid flickering:
###############################################################
Repaint:
 lw $t0, displayAddress
 #Repaint over bullets:
 #Loop over all bullets
 li $t1, 0
 lw $t7, bulletCount
 beq $t7, 0, MoveOn3
 For8:
  #Loading the x and y values into $t1 and $t2 respectively:
  mul $t3, $t1, 8
  lw $t4, bulletsLocation($t3)
  addi $t3, $t3, 4
  lw $t5, bulletsLocation($t3)
  #Firgure out where to draw: Multiply the y coord by 128, add 2x to it and then multiply everything by 4 and store it in t5:
  addi $t6, $zero, 128
  mul $t5, $t5, $t6
  mul $t4, $t4, 2
  add $t5, $t5, $t4
  addi $t6, $zero, 4
  mul $t5, $t5, $t6
  add $t5, $t5, $t0
  #Repaint:
  sw $zero, 0($t5)
  #Incrementing the counter:
  addi $t1, $t1, 1
  bne $t1, $t7, For8
 #------------------------------------------------
 MoveOn3:
 #Repaint over blaster:
 #------------------------------------------------
 # Store the x and y coord of the blaster in $t4 and $t5:
  addi $t5, $zero, 0
 lw $t4, blasterLocation($t5)
 addi $t5, $t5, 4
 lw $t5, blasterLocation($t5)
 #Check if the blaster has moved, if so which direction. 1 is right, -1 is left,
 # and 0 is no movement:
 lw $t1, blastersLastMove
 beq $t1, 0, MoveOn4 #No movement, so no need to repaint
 #Firgure out where to draw: Multiply the y coord by 128, add 2x to it and then multiply everything by 4 and store it in t5:
 addi $t6, $zero, 128
 mul $t5, $t5, $t6
 mul $t4, $t4, 2
 add $t5, $t5, $t4
 addi $t6, $zero, 4
 mul $t5, $t5, $t6
 add $t5, $t5, $t0
 beq $t1, 1, right2 #Blaster has moved to the right
 #Blaster has moved to the left
 sw $zero, 16($t5)
 sw $zero, 272($t5)
 sw $zero, 264($t5)
 sw $zero, 280($t5)
 sw $zero, 536($t5)
 sw $zero, 532($t5)
 sw $zero, 792($t5)
 sw $zero, 788($t5)
 sw $zero, blastersLastMove
 j MoveOn4
 right2:
 sw $zero, 0($t5)
 sw $zero, 256($t5)
 sw $zero, 248($t5)
 sw $zero, 264($t5)
 sw $zero, 504($t5)
 sw $zero, 508($t5)
 sw $zero, 760($t5)
 sw $zero, 764($t5)
 sw $zero, blastersLastMove
 #------------------------------------------------
 #Repaint a blasted mushroom if needed:
 #Load x coord into t4, and y coord into t5
 MoveOn4:
 #Loop over blasted mushrooms:
 li $t7, 0
 lw $t3, mushBlastedCount
 beq $t3, 0, MoveOn1
 For10:
  mul $t5, $t7, 8
  lw $t4, mushroomsBlasted($t5)
  addi $t5, $t5, 4
  lw $t5, mushroomsBlasted($t5)
  #Reapint over the blasted mushroom:
  lw $t0, displayAddress 
  addi $t6, $zero, 128
  mul $t5, $t5, $t6
  mul $t4, $t4, 2
  add $t5, $t5, $t4
  addi $t6, $zero, 4
  mul $t5, $t5, $t6
  add $t5, $t5, $t0
  sw $zero, 0($t5)
  sw $zero, 260($t5)
  sw $zero, 256($t5)
  sw $zero, 4($t5)
  addi $t7, $t7, 1
  bne $t7, $t3, For10
  sw $zero, mushBlastedCount
 #------------------------------------------------
 #Repaint over the flea:
 MoveOn1:
 lw $t1, fleaMovementFlag
 beq $t1, 0, MoveOn9 #No Movement
 #Load the x y coord into t4 and t5:
 li $t5, 0
 lw $t4, fleaLocation($t5)
 addi $t5, $t5, 4
 lw $t5, fleaLocation($t5)
 #Firgure out where to draw: Multiply the y coord by 128, add 2x to it and then multiply everything by 4 and store it in t5:
 addi $t6, $zero, 128
 mul $t5, $t5, $t6
 mul $t4, $t4, 2
 add $t5, $t5, $t4
 addi $t6, $zero, 4
 mul $t5, $t5, $t6
 add $t5, $t5, $t0
 #Wings:
 sw $zero, 4($t5)
 sw $zero, 256($t5)
 sw $zero, 16($t5)
 sw $zero, 276($t5)
 #Body:
 sw $zero, 264($t5)
 sw $zero, 268($t5)
 sw $zero, 520($t5)
 sw $zero, 524($t5)
 #------------------------------------------------
 #Repaint over centipede:
 MoveOn9:
 li $t7, 0
  For3:
 #Load x coord into t4, and y coord into t5
   mul $t5, $t7, 8
   lw $t4, centipedeLocation($t5)
   addi $t5, $t5, 4
   lw $t5, centipedeLocation($t5)
   #Checking if body part is in screen assuming centipede always enters from the right
   #so we're just checking if x is between 0 and 63, since if y is -1 then so is x.
   li $t0, 31
   slt $t0, $t0, $t4
   beq $t0, $zero, InRange2 # x <= 63
   j Increment2
   InRange2:
    li $t0, 0
    slt $t0, $t4, $t0
    beq $t0, $zero, checkTail # x >= 0
    j Increment2
   #Checking an repainting only if it's a tail segment, since that's the only one that
   # will be painted black.
   checkTail:
    beq $t7, 9, Tail #The last segment is always a tail
    addi $t1, $t7, 1
    mul $t1, $t1, 8
    lw $t1, centipedeLocation($t1)
    beq $t1, -1, Tail #If the next segment has been blasted, then it's a tail
    j Increment2
    Tail:
    #Repainting with balck:
    lw $t0, displayAddress 
    addi $t6, $zero, 128
    mul $t5, $t5, $t6
    mul $t4, $t4, 2
    add $t5, $t5, $t4
    addi $t6, $zero, 4
    mul $t5, $t5, $t6
    add $t5, $t5, $t0
    sw $zero, 0($t5)
    sw $zero, 4($t5)
    sw $zero, 256($t5)
    sw $zero, 260($t5)
    Increment2:
     addi $t7, $t7, 1
     beq $t7, 10, End2
     j For3
  End2:
   jr $ra
###############################################################

###############################################################  
InitializeMushrooms:
 #Pushing ra to the stack:
 addi $sp, $sp, -4
 sw $ra, 0($sp)
 #For loop to add 25 mushrooms in 25 random locations
 li $t0, 0
 For4:
  #Push the counter ($t0) onto the stack:
  addi $sp, $sp, -4
  sw $t0, 0($sp)
  #Initializing a random 1<= x <= 30, and pushing it to the stack
  li $a1, 30
  li $v0, 42
  syscall
  addi $a0, $a0, 1 #Adding one to bring the range from [0,29] to [1,30]
  addi $sp, $sp, -4
  sw $a0, 0($sp)
  #Initializing a random 0<= y <= 29, and pushing it to the stack
  li $a1, 30
  li $v0, 42
  syscall
  addi $sp, $sp, -4
  sw $a0, 0($sp)
  #Calling InsertMushroom:
  jal InsertMushroom
  #Popping the counter($t0) from the stack:
  lw $t0, 0($sp)
  addi $sp, $sp, 4
  #Incrementing the counter:
  addi $t0, $t0, 1
  bne $t0, 25, For4
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra
###############################################################

###############################################################
InsertMushroom:
 #load x and y values into $t1, and $t2 respectively from the stack:
 lw $t2, 0($sp)
 addi $sp, $sp, 4
 lw $t1, 0($sp)
 addi $sp, $sp, 4
 #Checks to see if there aren't already 500(cap) mushroom on the screen:
 lw $t0, mushroomCount
 beq $t0, 500, End3
 #Otherwise find the address to insert by multiplying mushroomcount by 8:
 mul $t3, $t0, 8
 sw $t1, mushroomsLocation($t3)
 addi $t3, $t3, 4
 sw $t2, mushroomsLocation($t3)
 #Increment mushroomCount
 addi $t0, $t0, 1
 sw $t0, mushroomCount
 End3:
  jr $ra
###############################################################

###############################################################  
DrawMushrooms:
 lw $t0, displayAddress 
 #Loop over all mushrooms
 li $t1, 0
 lw $t7, mushroomCount
 beq $t7, 0, End4
 For5:
  #Loading the x and y values into $t4 and $t5 respectively:
  mul $t3, $t1, 8
  lw $t4, mushroomsLocation($t3)
  addi $t3, $t3, 4
  lw $t5, mushroomsLocation($t3)
  #Firgure out where to draw: Multiply the y coord by 128, add 2x to it and then multiply everything by 4 and store it in t5:
  addi $t6, $zero, 128
  mul $t5, $t5, $t6
  mul $t4, $t4, 2
  add $t5, $t5, $t4
  addi $t6, $zero, 4
  mul $t5, $t5, $t6
  add $t5, $t5, $t0
  #Drawing:
  lw $t2, white
  lw $t3, red
  sw $t3, 0($t5)
  sw $t3, 260($t5)
  sw $t2, 256($t5)
  sw $t2, 4($t5)
  #Incrementing the counter:
  addi $t1, $t1, 1
  bne $t1, $t7, For5
  End4:
   jr $ra
###############################################################

###############################################################
InsertBullet:   
 #load x and y values into $t1, and $t2 respectively from the the position of the blaster:
 #Load x coord into t4, and y coord into t5
 addi $t5, $zero, 0
 lw $t4, blasterLocation($t5)
 addi $t5, $t5, 4
 lw $t5, blasterLocation($t5)
 addi $t1, $t4, 1
 addi $t2, $t5, -1
 #Checks to see if there aren't already 30(cap) bullets on the screen:
 lw $t0, bulletCount
 beq $t0, 30, End5
 #Otherwise find the address to insert by multiplying bulletCount by 8:
 mul $t3, $t0, 8
 sw $t1, bulletsLocation($t3)
 addi $t3, $t3, 4
 sw $t2, bulletsLocation($t3)
 #Increment bulletCount
 addi $t0, $t0, 1
 sw $t0, bulletCount
 End5:
  jr $ra
###############################################################

###############################################################
DrawBullets:
 lw $t0, displayAddress 
 #Loop over all bullets
 li $t1, 0
 lw $t7, bulletCount
 beq $t7, 0, End6
 For6:
  #Loading the x and y values into $t1 and $t2 respectively:
  mul $t3, $t1, 8
  lw $t4, bulletsLocation($t3)
  addi $t3, $t3, 4
  lw $t5, bulletsLocation($t3)
  #Firgure out where to draw: Multiply the y coord by 128, add 2x to it and then multiply everything by 4 and store it in t5:
  addi $t6, $zero, 128
  mul $t5, $t5, $t6
  mul $t4, $t4, 2
  add $t5, $t5, $t4
  addi $t6, $zero, 4
  mul $t5, $t5, $t6
  add $t5, $t5, $t0
  #Drawing:
  lw $t2, bulletColor
  sw $t2, 0($t5)
  #Incrementing the counter:
  addi $t1, $t1, 1
  bne $t1, $t7, For6
  End6:
   jr $ra
###############################################################

###############################################################
UpdateBullets:
 #Loop over all bullets
 li $t2, 0 #Boolean to check whether a bullet has gone off screen
 li $t1, 0 #Loop counter
 lw $t7, bulletCount
 beq $t7, 0, End7
 For7:
  #Subtract 1 from the y value:
  mul $t3, $t1, 8
  addi $t3, $t3, 4
  lw $t5, bulletsLocation($t3)
  bne $t5, 0, MoveOn2
  #A bullet has moved off of the screen so delete this bullet by moving the last element in the
  # the bullet location array into its place:
  mul $t3, $t7, 8
  addi $t3, $t3, -4
  lw $t5, bulletsLocation($t3)
  addi $t3, $t3, -4
  lw $t4, bulletsLocation($t3)
  mul $t3, $t1, 8
  sw $t4, bulletsLocation($t3)
  addi $t3, $t3, 4
  sw $t5, bulletsLocation($t3)
  addi $t2, $t2, 1
  MoveOn2:
  addi $t5, $t5, -1
  sw $t5, bulletsLocation($t3)
  #Incrementing the counter:
  addi $t1, $t1, 1
  bne $t1, $t7, For7
  End7:
   sub $t7, $t7, $t2
   sw $t7, bulletCount
   jr $ra
###############################################################

###############################################################
HandleInput:
 lw $t0, 0($sp)
 addi $sp, $sp, 4
 addi $sp, $sp, -4
 sw $ra, 0($sp)
 #Checking if any keys were pressed:
 beq $t0, 0x6A, left # j was pressed
 beq $t0, 0x6B, right # k was pressed
 beq $t0, 0x78, shoot # x was pressed
 beq $t0, 0x73, reset
 j End8
 reset:
 addi $sp, $sp, -4
 sw $ra, 0($sp)
 jal Restart
 lw $ra, 0($sp)
 addi $sp, $sp, 4
 #Move the blaster to the left:
 left:
 lw $t2, blasterLocation($zero)
 beq $t2, 0, End8
 addi $t2, $t2, -1
 sw $t2, blasterLocation($zero)
 li $t2, -1
 sw $t2, blastersLastMove
 j End8
 #Move the blaster to the right:
 right:
 lw $t2, blasterLocation($zero)
 beq $t2, 29, End8
 addi $t2, $t2, 1
 sw $t2, blasterLocation($zero)
 li $t2, 1
 sw $t2, blastersLastMove
 j End8
 #Shoot:
 shoot:
 jal InsertBullet
 End8:
 lw $ra, 0($sp)
 addi $sp, $sp, 4
 jr $ra
###############################################################

###############################################################
CheckMushroomAhead:
 lw $t7, 4($sp) #Index of segment
 #Load x coord into t1, and y coord into t2
 mul $t5, $t7, 8
 lw $t1, centipedeLocation($t5)
 addi $t5, $t5, 4
 lw $t2, centipedeLocation($t5)
 #Figure if the segment is a head or not:
 mul $t0, $t7, 4
 lw $t0, isHead($t0)
 bne $t0, $zero, Head2
 #Body:
 # Checks to see if the segment before it is in the bottom row:
 #The follwoing loop assumes t7 is never 0, since it can never be a body!
  mul $t5, $t7, 8
  addi $t5, $t5, -4
  lw $t4, centipedeLocation($t5)
  addi $t5, $t5, -4
  lw $t3, centipedeLocation($t5)
  beq $t4, $t2, End11
  lw $t0, 0($sp)
  add $t3, $t3, $t0 #Since the segment before had already been updated
  bne $t3, $t1, secondmushroom
  li $t0, 1
  sw $t0, 0($sp)
  jr $ra
  secondmushroom: #If the piece ahead hit another mushroom, then it's 2 rows right below
  addi $t4, $t4, -2
  bne $t4, $t2, End11
  li $t0, 1
  sw $t0, 0($sp)
  jr $ra
 End11:
  sw $zero, 0($sp)
  jr $ra
 #The piece is a head so we must check mushroom to see if there locations match ($t1, $t2):
 Head2:
 lw $t0, 0($sp)
 #Adding t0 to t1 to figure the next location:
 add $t1, $t1, $t0
 li $t0, 0
 lw $t6, mushroomCount
 beq $t6, 0, End10
 For9:
 #Store the mushroom's coord in t3, t4 to compare with ($t1, $t2)::
  mul $t5, $t0, 8
  lw $t3, mushroomsLocation($t5)
  addi $t5, $t5, 4
  lw $t4, mushroomsLocation($t5)
  beq $t1, $t3, XMatch
  addi $t0, $t0, 1
  bne $t0, $t6, For9
  j End10
  XMatch:
  beq $t2, $t4, YMatch
  addi $t0, $t0, 1
  bne $t0, $t6, For9
  j End10
  YMatch:
  li $t0, 1
  sw $t0, 0($sp)
  jr $ra
  End10:
  sw $zero, 0($sp)
  jr $ra
###############################################################

###############################################################
CheckBulletColision:
 addi $sp, $sp, -4
 sw $ra, 0($sp)
 
 jal CheckMushroomCollision
 jal CheckCentCollision
 # Check if the flea was shot:
 lw $t0, fleaAlive
 beq $t0, 0, MoveOn10 #No flea on the screen
 li $t0, 0 # Loop counter
 lw $t2, bulletCount
 beq $t2, 0, MoveOn10 #No bullets on the screen
 For16:
 #Load the bullets x coord into t1, and y coord into t3
  mul $t5, $t0, 8
  lw $t1, bulletsLocation($t5)
  addi $t5, $t5, 4
  lw $t3, bulletsLocation($t5)
  #Load the flea's x coord into t6, and y coord into t5
   mul $t5, $zero, 8
   lw $t6, fleaLocation($t5)
   addi $t5, $t5, 4
   lw $t5, fleaLocation($t5)
   beq $t3, $t5, YLevel1
   addi $t5, $t5, 1
   beq $t3, $t5, YLevel2
   j Increment6
   YLevel1:
   beq $t1, $t6, Shot
   addi $t6, $t6, 1
   beq $t1, $t6, Shot
   addi $t6, $t6, 1
   beq $t1, $t6, Shot
   j Increment6
   YLevel2:
   addi $t6, $t6, 1
   beq $t1, $t6, Shot
   j Increment6
   Shot:
   sw $zero, fleaAlive
   subi $t2, $t2, 1
   sw $t2, bulletCount
   mul $t7, $t2, 8
   lw $t6, bulletsLocation($t7)
   addi $t7, $t7, 4
   lw $t5, bulletsLocation($t7)
   mul $t7, $t0, 8
   sw $t6, bulletsLocation($t7)
   addi $t7, $t7, 4
   sw $t5, bulletsLocation($t7)
   j MoveOn10
   Increment6:
   addi $t0, $t0, 1
   bne $t0, $t2, For16
 MoveOn10:
 lw $ra, 0($sp)
 addi $sp, $sp, 4
 
 jr $ra
###############################################################

###############################################################
CheckMushroomCollision:
 #Storing s registers:
 addi $sp, $sp, -4
 sw $s0, 0($sp)
 addi $sp, $sp, -4
 sw $s1, 0($sp)
 addi $sp, $sp, -4
 sw $s2, 0($sp)
 #Loop over bullets
 li $t0, 0 # Outer loop counter
 li $t1, 0 #Keep track of bullets deleted in the process
 lw $t2, bulletCount
 beq $t2, 0, End13 #No bullets on the screen
 For11:
  #Load x coord into s0, and y coord into s1
  mul $t5, $t0, 8
  lw $s0, bulletsLocation($t5)
  addi $t5, $t5, 4
  lw $s1, bulletsLocation($t5)
  li $t3, 0 #Inner loop counter
  li $s2, 0 #To keep track of mushrooms blasted in the loop 
  lw $t4, mushroomCount
  beq $t4, 0, End13
  For12:
   #Load x coord into t6, and y coord into t5
   mul $t5, $t3, 8
   lw $t6, mushroomsLocation($t5)
   addi $t5, $t5, 4
   lw $t5, mushroomsLocation($t5)
   bne $s0, $t6, Increment3 #X doesn't match
   bne $s1, $t5, Increment3 #X matched but y didn't
   #Insert into blasted:
   lw $t7, mushBlastedCount
   mul $t7, $t7, 8
   sw $t6, mushroomsBlasted($t7)
   addi $t7, $t7, 4
   sw $t5, mushroomsBlasted($t7)
   #Update blasted count
   addi $s2, $s2, 1
   lw $t7, mushBlastedCount
   addi $t7, $t7, 1
   sw $t7, mushBlastedCount
   #Delete from mushroom locations:
   sub $t7, $t4, $t7
   mul $t7, $t7, 8
   lw $t6, mushroomsLocation($t7)
   addi $t7, $t7, 4
   lw $t5, mushroomsLocation($t7)
   mul $t7, $t3, 8
   sw $t6, mushroomsLocation($t7)
   addi $t7, $t7, 4
   sw $t5, mushroomsLocation($t7)
   #Delete from bullet locations:
   addi $t1, $t1, 1
   sub $t7, $t2, $t1
   mul $t7, $t7, 8
   lw $t6, bulletsLocation($t7)
   addi $t7, $t7, 4
   lw $t5, bulletsLocation($t7)
   mul $t7, $t0, 8
   sw $t6, bulletsLocation($t7)
   addi $t7, $t7, 4
   sw $t5, bulletsLocation($t7)
   j MoveOn8
   Increment3:
    addi $t3, $t3, 1
    bne $t3, $t4, For12
    #End of loop
    MoveOn8:
   #Update mushroomCount
   lw $t7, mushroomCount
   sub $t7, $t7, $s2
   sw $t7, mushroomCount
   addi $t0, $t0, 1
   bne $t0, $t2, For11
 End13:
  # Update bullet count
   sub $t7, $t2, $t1
   sw $t7, bulletCount
  #Restoring s registers:
  lw $s2, 0($sp)
  addi $sp, $sp, 4
  lw $s1, 0($sp)
  addi $sp, $sp, 4
  lw $s0, 0($sp)
  addi $sp, $sp, 4
  jr $ra
###############################################################

###############################################################
CheckCentCollision:
 #Storing s registers:
 addi $sp, $sp, -4
 sw $s0, 0($sp)
 addi $sp, $sp, -4
 sw $s1, 0($sp)
 #Loop over bullets
 li $t0, 0 # Outer loop counter
 li $t1, 0 #Keep track of bullets deleted in the process
 lw $t2, bulletCount
 beq $t2, 0, End12 #No bullets on the screen
 For14:
 #Load x coord into s0, and y coord into s1
 mul $t5, $t0, 8
 lw $s0, bulletsLocation($t5)
 addi $t5, $t5, 4
 lw $s1, bulletsLocation($t5)
 li $t3, 0 #Inner loop counter
   For13:
    #Load x coord into t6, and y coord into t5
    mul $t5, $t3, 8
    lw $t6, centipedeLocation($t5)
    addi $t5, $t5, 4
    lw $t5, centipedeLocation($t5)
    bne $s0, $t6, Increment4 #X doesn't match
    bne $s1, $t5, Increment4 #X matched but y didn't
    
    #Pushing important data onto the stack:
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    addi $sp, $sp, -4
    sw $t1, 0($sp)
    addi $sp, $sp, -4
    sw $t2, 0($sp)
    addi $sp, $sp, -4
    sw $t3, 0($sp)
    addi $sp, $sp, -4
    sw $ra, 0($sp)
 
    # Pushing the parameters for InsertMushroom onto the stack:
    addi $sp, $sp, -4
    sw $t6, 0($sp)
    addi $sp, $sp, -4
    sw $t5, 0($sp)
    # There's collision:
    #Delete centipede body segment:
    li $t7, -1
    mul $t5, $t3, 8
    sw $t7, centipedeLocation($t5)
    addi $t5, $t5, 4
    sw $t7, centipedeLocation($t5)
    
    #If not a tail make the next segment a head
    beq $t3, 9, MoveOn7
    addi $t7, $t3, 1
    mul $t7, $t7, 4
    li $t4, 1
    sw $t4 isHead($t7)
    # Add a new mushrrom where the body segment was blasted:
    MoveOn7:
    jal InsertMushroom
    #Popping important data back from the stack:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    lw $t3, 0($sp)
    addi $sp, $sp, 4
    lw $t2, 0($sp)
    addi $sp, $sp, 4
    lw $t1, 0($sp)
    addi $sp, $sp, 4
    lw $t0, 0($sp)
    addi $sp, $sp, 4
    #Delete from bullet locations:
    addi $t1, $t1, 1
    sub $t7, $t2, $t1
    mul $t7, $t7, 8
    lw $t6, bulletsLocation($t7)
    addi $t7, $t7, 4
    lw $t5, bulletsLocation($t7)
    mul $t7, $t0, 8
    sw $t6, bulletsLocation($t7)
    addi $t7, $t7, 4
    sw $t5, bulletsLocation($t7)
    Increment4:
     addi $t3, $t3, 1
     bne $t3, 10, For13
    #End of loop
   addi $t0, $t0, 1
   bne $t0, $t2, For14
 End12:
  # Update bullet count
   sub $t7, $t2, $t1
   sw $t7, bulletCount
  #Restoring s registers:
  lw $s1, 0($sp)
  addi $sp, $sp, 4
  lw $s0, 0($sp)
  addi $sp, $sp, 4
  jr $ra
###############################################################

############################################################### 
CheckBlasterDeath:
 #Load x and y coord of the blaster into t0, and t1:
 li $t5, 0
 lw $t0, blasterLocation($t5)
 addi $t5, $t5, 4
 lw $t1, blasterLocation($t5)
 li $t3, 0 #Loop over centipede segments
   For15:
    #Load x coord of the segment into t4, and y coord into t5
    mul $t5, $t3, 8
    lw $t4, centipedeLocation($t5)
    addi $t5, $t5, 4
    lw $t5, centipedeLocation($t5)
    bne $t0, $t4, Increment5 #X doesn't match
    beq $t1, $t5, Match #Both x and y were a match
    # Since the blaster has height 2(4 squares), the centipede could've been sent
    # To the bottom row of the blaster by a mushroom:
    addi $t5, $t5, -1
    bne $t1, $t5, Increment5
    Match:
    #Then there's been a colision between the centiped and the blaster, so return 1:
    li $t0, 1
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    jr $ra
    Increment5:
     addi $t3, $t3, 1
     bne $t3, 10, For15
  #Check for flea collision:
  #Load the flea's x coord into t5, and y coord into t6
   mul $t7, $zero, 8
   lw $t5, fleaLocation($t7)
   addi $t7, $t7, 4
   lw $t6, fleaLocation($t7)
   beq $t6, 29, YLevel3
   beq $t6, 30, YLevel4
   j End14
   YLevel3:
   beq $t0, $t5, Match
   j End14
   YLevel4:
   addi $t7, $t0, -2
   slt $t7, $t5, $t7
   beq $t7, 1, End14
   addi $t7, $t0, 2
   slt $t7, $t7, $t5
   beq $t7, 1, End14
   j Match
  End14:
  #No collisions detected, so return 0:
  addi $sp, $sp, -4
  sw $zero, 0($sp)
  jr $ra
###############################################################

###############################################################
UpdateFleaLocation:
 lw $t0, fleaAlive
 beq $t0, 0, MoveOn12 #No flea on the screen
 #Load the x y coord into t0 and t1:
 li $t5, 0
 lw $t0, fleaLocation($t5)
 addi $t5, $t5, 4
 lw $t1, fleaLocation($t5)
 #Deciding whether to update the x or y value randomly:
 li $a1, 2
 li $v0, 42
 syscall
 beq $a0, 0, UpdateY
 #Load current direction into t2:
 lw $t2, fleaDirection
 beq $t2, 1, GoingRight
 #Going left then:
 beq $t0, 0, turnRight #Hit the left side of the screen:
 #Else just move to the left:
 addi $t0, $t0, -1
 sw $t0, fleaLocation($zero)
 jr $ra
 turnRight:
 #Update x val and direction both to 1:
 li $t0, 1
 sw $t0, fleaLocation($zero)
 sw $t0, fleaDirection
 jr $ra
 GoingRight:
 beq $t0, 29, turnLeft #Hit the right side of the screen:
 #Else just move to the right:
 addi $t0, $t0, 1
 sw $t0, fleaLocation($zero)
 jr $ra
 turnLeft:
 #Update x val, and set direction to -1:
 li $t0, -1
 sw $t0, fleaDirection
 li $t0, 28
 sw $t0, fleaLocation($zero)
 jr $ra
 UpdateY:
 #Get a random number between 0 or 1, and move up for 1 and down for 0:
 li $a1, 2
 li $v0, 42
 syscall
 beq $a0, 0, MoveDown
 #Move up
 beq $t1, 24, MoveDown #Hit the upper bound:
 #Otherwise just move up:
 MoveUp:
 addi $t1, $t1, -1
 sw $t1, fleaLocation($t5)
 jr $ra
 MoveDown:
 beq $t1, 30, MoveUp #Hit the lower bound:
 addi $t1, $t1, 1
 sw $t1, fleaLocation($t5)
 MoveOn12:
 jr $ra
###############################################################

###############################################################
DrawFlea:
 lw $t0, fleaAlive
 beq $t0, 0, MoveOn11 #No flea on the screen
 lw $t0, displayAddress 
 #Load the x y coord into t4 and t5:
 li $t5, 0
 lw $t4, fleaLocation($t5)
 addi $t5, $t5, 4
 lw $t5, fleaLocation($t5)
 #Firgure out where to draw: Multiply the y coord by 128, add 2x to it and then multiply everything by 4 and store it in t5:
 addi $t6, $zero, 128
 mul $t5, $t5, $t6
 mul $t4, $t4, 2
 add $t5, $t5, $t4
 addi $t6, $zero, 4
 mul $t5, $t5, $t6
 add $t5, $t5, $t0
 lw $t2, fleaWing
 lw $t3, fleaBody

 sw $t2, 4($t5)
 sw $t2, 256($t5)
 sw $t2, 16($t5)
 sw $t2, 276($t5)
 
 sw $t3, 264($t5)
 sw $t3, 268($t5)
 sw $t3, 520($t5)
 sw $t3, 524($t5)
 MoveOn11:
 jr $ra
###############################################################

###############################################################  
ReFlea:
 li $t5, 0
 sw $t5 fleaBeenDeadfor
 mul $t7, $zero, 8
 sw $t5, fleaLocation($t7)
 addi $t7, $t7, 4
 li $t5, 25
 sw $t5, fleaLocation($t7)
 li $t5, 1
 sw $t5 fleaAlive
 jr $ra
###############################################################

###############################################################  
CheckCentDeath:
 li $t0, 0
 For17:
 #Checks if this coord is -1, if not then centipede is alive so return back:
 mul $t7, $t0, 4
 lw $t7, centipedeLocation($t7)
 beq $t7, -1, Increment7
 jr $ra #Not dead
 Increment7:
 addi $t0, $t0, 1
 bne $t0, 20, For17
 #If we reach here then the centipede is dead, so we'll re-initialize it:
 li $t0, 0
 For18:
 mul $t7, $t0, 4
 lw $t5, centipedeInitialLocation($t7)
 sw $t5, centipedeLocation($t7)
 addi $t0, $t0, 1
 bne $t0, 20, For18
 # Load the isHead array:
 li $t0, 1
 sw $t0, isHead($zero)
 For19:
 mul $t7, $t0, 4
 sw $zero, isHead($t7)
 addi $t0, $t0, 1
 bne $t0, 10, For19
 addi $sp, $sp, -4
 sw $ra, 0($sp)
 jal InitializeMushrooms
 lw $ra, 0($sp)
 addi $sp, $sp, 4
 jr $ra
###############################################################

############################################################### 
Restart:
 li $t0, 0
 sw $t0, gameOver
 sw $zero, mushroomCount
 li $t0, 0
 For20:
 mul $t7, $t0, 4
 li $t5, -1
 sw $t5, centipedeLocation($t7)
 addi $t0, $t0, 1
 bne $t0, 20, For20
 
 #Reset mushrooms, centipede, and flea:
 addi $sp, $sp, -4
 sw $ra, 0($sp)

 jal CheckCentDeath
 jal ReFlea
 
 lw $ra, 0($sp)
 addi $sp, $sp, 4
 
 #Clear the screen:
 li $t1, 0
 lw $t0, displayAddress 
 For21:
 mul $t2, $t1, 4
 add $t2, $t2, $t0
 sw $zero, 0($t2)
 addi $t1, $t1, 1
 bne $t1, 4096, For21
 jr $ra
  
 
 
 
 
 
