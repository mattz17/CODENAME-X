# Matthew Zhu, zhumatt2
# Demo for painting
## Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 512
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
.data
displayAddress: .word 0x10008000
blue: 	.word 0x2c85ff 		# stores the blue colour code
red:	.word 0xe81515 		# stores the red colour code
white:	.word 0xffffff 		# stores the white colour code
black:	.word 0x000000 		# stores the black colour code
gray:	.word 0x696969 		# stores the gray colour code
purple: .word 0x9316cd 		# stores the purple colour code
yellow:  .word 0xffbf00  	# stores the yellow colour code
energyBlue: .word 0x009ACD 	# stores special blue color for the energy bar
obstacles:	.word 0:10    	# can have up to 10 obstacles
speeds:		.word 0:10 	# maximum 10 obstacles means 10 speeds
otherAddresses:	.word 0:3	# Stores other addresses, namely the ship's laser, health bar address, and energy bar address in that order
gameCounter: .word 0x000000	# Tells game when to increase difficulty
shipAddress: .word 0x10008000	
xCoordinate: .word 0x00000
yCoordinate: .word 0x0000c
absoluteZeroState:	.word 0x000000	# 1 if special ability Absolute Zero is active, 0 if not
absoluteZeroCounter:	.word 0x000000	# Determines how long to stay in Absolute Zero mode
.text
lw $s0, displayAddress # $s0 stores the base address for display, immutable
#$s0 stores base address
#$s1 stores obstacle array
#$s2 stores speed array for obstacles
#$s3 stores speed of player ship
#$s4 stores current number of enemies
#$s5 stores max number of enemies
#$s6 stores location of laser if one is present
#$s7 stores the ship's form: 0 is ICE, 1 is FIRE, 2 is SHOCK

INITIALIZE:
lw $a0, black
jal ERASE_ALL			# Clear screen
jal DRAW_HUD			# Draw the HUD with full HP Bar and empty energy bar

lw $t0, displayAddress  	# Initialize ship's address at start of game 
addi $t0, $t0, 6144     	# ship starts on 12th row, so 512*12=6144	
sw $t0, shipAddress

addi $t1, $0, 0			# store current x-coordinate of ship
addi $t2, $0, 12		# store current y-coordinate of ship
sw $t1, xCoordinate
sw $t2, yCoordinate
addi $s5, $0, 3			# start game with 3 enemies maximum
lw $t3, gameCounter
addi $t3, $0, 0			# Set game counter to 0.
sw $t3, gameCounter

la $s1, obstacles		# load array of obstacles into $s1
la $s2, speeds			# load array of obstacle speeds into $s2
la $s6, otherAddresses		# load array of other addresses (laser, HP bar, energy bar) into $s6
# Initialize values for $s6
addi $t6, $s6, 4		# Get address of second index of 'otherAddresses'
addi $t7, $s0, 29988 		# This is the address of full HP Bar
sw $t7, ($t6)			# Store address of HP Bar in the second index of 'otherAddresses'
addi $t6, $s6, 8		# This is the address of third index of 'otherAddresses'
addi $t7, $s0, 30060 		# This is address of an empty Energy Bar
sw $t7, ($t6)			# Store address of Energy bar in the third index of 'otherAddresses'

addi $s3, $0, 2 		# Initialize speed of plane to 2
addi $s4, $0, 0			# Start of game has 0 enemies on the screen
addi $s7, $0, 0			# Default ship form is ICE/Blue form
jal resetArray			# Reset our obstacles array in case we have existing values

Start:
lw $a0, black
lw $a1, black
jal drawShip 			# Erase Ship since parameters are both the color of 'black'

# Check for user input
li $t9, 0xffff0000 
lw $t8, 0($t9)
beq $t8, 1, checkWhichInput

keyPressed:			# Come here after doing the respective key action

jal checkShipForm		# Update ship's form/color if needed
add $a0, $v0, $0		# Put the appropriate ship color into $a0
lw $a1, white
jal drawShip			# Redraw the ship with updated position or color

# If current number of enemies equal (or greater which shouldn't be possible, skip spawning a new enemy.
bge $s4, $s5, enemiesCappedOut

# Here we confirmed we're adding an enemy, so let's get its spawn location
jal getNewEnemyLocation
add $a0, $v0, $0
jal addNewEnemy			# Add new enemy to the 'obstacle' array, and add its corresponding speed to the 'speeds' array in parallel

enemiesCappedOut:		# Don't bother spawning anything, max obstacles reached already
lw $a0, black
lw $a1, black
lw $t0, absoluteZeroState
beq $t0, 1, obstaclesFrozen
jal drawObstacles		# Erase obstacles in the current positions
jal moveObstacles		# Move obstacles to new position
lw $a0, gray		
lw $a1, red
jal drawObstacles		# Redraw obstacles our obstacles
obstaclesFrozen:
jal sustainAbsoluteZero		# Check if Absolute Zero should still be active
lw $a0, black		
lw $a1, black
jal despawnObstacles		# Despawn obstacles that reach left of screen, got shot, or collided with ship
lw $a1, black
jal drawLaser			# If a laser is present, erase it from the current position
jal moveLaser			# Move the laser to its new position
lw $a0, red
jal drawLaser			# Redraw the laser in its new position
lw $a0, black
jal despawnLaser		# Despawn laser if it reached the right end of the screen, or collided with an obstacle
jal levelCheck			# Check if player has survived long enough to advance to a harder difficulty

addi $t7, $0, 30			# This is the number of game cycles it will take to charge the energy bar 1 unit
lw $t3, gameCounter
div $t3, $t7
mfhi $t7
bnez $t7, doNotCharge		
bne $s7, $0, singleCharge	# If not equal to 0, then not in blue form and we only do a single energy charge
jal chargeEnergy		# Charge an extra time if in blue form
singleCharge:
jal chargeEnergy		# Charge the energy bar as per usual
doNotCharge:
 

li $v0, 32
li $a0, 40			# SLEEP
syscall
j Start

DONE:
Exit:
li $v0, 10 			# terminate the program gracefully
syscall

checkWhichInput:
lw $t6, 4($t9)
beq $t6, 0x61, boundedLeft
beq $t6, 0x64, boundedRight
beq $t6, 0x77, boundedAbove
beq $t6, 0x73, boundedBelow
beq $t6, 0x20, shoot
beq $t6, 0x70, eraseAndRestart
beq $t6, 0x31, changeToBlue
beq $t6, 0x32, changeToRed
beq $t6, 0x33, changeToYellow
beq $t6, 0x2d, sabotageShip
beq $t6, 0x78, specialAbility
j keyPressed

specialAbility:
addi $t5, $s6, 8	# Get index for Energy Bar element in 'otherAddresses'
lw $t8, ($t5)		# Get address of current Energy bar and store it in $t8
bne $t8, 1, notFullyCharged
beq $s7, 0, absoluteZero
beq $s7, 1, solarFlare
beq $s7, 2, blink
notFullyCharged:
j keyPressed

absoluteZero:		# Freezes all enemies
addi $t9, $0, 1
sw $t9, absoluteZeroState	# Switch Absolute Zero state on
addi $t9, $s0, 30060	# Reset energy bar to 0
jal eraseEnergyBar
sw $t9, ($t5)		# Get address of current Energy bar and store it in $t8
j keyPressed

sustainAbsoluteZero:	# Function that automatically deactivates Absolute Zero after it's reached its time duration
lw $t0, absoluteZeroState
beq $t0, 1, chargeAbsoluteZero	# If 1, charge. If 0, don't need to do anything
jr $ra
chargeAbsoluteZero:
lw $t1, absoluteZeroCounter
addi $t1, $t1, 1
sw $t1, absoluteZeroCounter
beq $t1, 50, turnOffAbsoluteZero
jr $ra
turnOffAbsoluteZero:
addi $t0, $0, 0
sw $t0, absoluteZeroState
sw $t0, absoluteZeroCounter
jr $ra

solarFlare:		# Destroys all enemies
lw $a0, black
lw $a1, black
jal drawObstacles
jal resetArray
addi $t9, $s0, 30060	# Reset energy bar to 0
jal eraseEnergyBar
addi $t5, $s6, 8	# Get index for Energy Bar element in 'otherAddresses'
sw $t9, ($t5)		# Get address of current Energy bar and store it in $t8
j keyPressed

blink:			# Player teleports 1/4 of the screen to the right, or less if there's not enough screen space to the right
lw $t1, xCoordinate
bge $t1, 64, tooFarForward
addi $t1, $t1, 48
sw $t1, xCoordinate
lw $t0, shipAddress
addi $t0, $t0, 192
sw $t0, shipAddress
addi $t9, $s0, 30060	# Reset energy bar to 0
jal eraseEnergyBar
sw $t9, ($t5)		# Get address of current Energy bar and store it in $t8
tooFarForward:
j keyPressed

sabotageShip:
jal damagedShip
j keyPressed

changeToBlue:
add $s7, $0, 0
j keyPressed

changeToRed:
lw $t0, absoluteZeroState  	# $t0 will store the address of the ship
beq $t0, 1, noRedChange
add $s7, $0, 1
noRedChange:
j keyPressed

changeToYellow:
lw $t0, absoluteZeroState  	# $t0 will store the address of the ship
beq $t0, 1, noYellowChange
add $s7, $0, 2
noYellowChange:
j keyPressed

eraseAndRestart:
j INITIALIZE

boundedBelow:
addi $t8, $0, 47
sub $t8, $t8, $s3
lw $t2, yCoordinate
ble $t2, $t8, moveDown
j keyPressed

boundedAbove:
addi $t8, $0, 0
add $t8, $t8, $s3
lw $t2, yCoordinate
bge $t2, $t8, moveUp
j keyPressed

boundedLeft:
addi $t8, $0, 0
add $t8, $t8, $s3
lw $t1, xCoordinate
bge $t1, $t8, moveLeft
j keyPressed

boundedRight:
addi $t8, $0, 113
sub $t8, $t8, $s3
lw $t1, xCoordinate
ble $t1, $t8, moveRight
j keyPressed

moveDown:
addi $t8, $0, 512
mult $s3, $t8
mflo $t7
lw $t0, shipAddress
add $t0, $t0, $t7
sw $t0, shipAddress
lw $t2, yCoordinate
add $t2, $t2, $s3
sw $t2, yCoordinate
j keyPressed

moveUp:
addi $t8, $0, -512
mult $s3, $t8
mflo $t7
lw $t0, shipAddress
add $t0, $t0, $t7
sw $t0, shipAddress
lw $t2, yCoordinate
sub $t2, $t2, $s3
sw $t2, yCoordinate
j keyPressed

moveRight: 
addi $t8, $0, 4
mult $s3, $t8
mflo $t7
lw $t0, shipAddress
add $t0, $t0, $t7
sw $t0, shipAddress
lw $t1, xCoordinate
add $t1, $t1, $s3
sw $t1, xCoordinate
j keyPressed

moveLeft: 
addi $t8, $0, -4
mult $s3, $t8
mflo $t7
lw $t0, shipAddress
add $t0, $t0, $t7
sw $t0, shipAddress
lw $t1, xCoordinate
sub $t1, $t1, $s3
sw $t1, xCoordinate
j keyPressed

shoot:
addi $t5, $s6, 0
lw $t8, ($t5)
bnez $t8, laserCurrentlyActive
lw $t0, shipAddress
add $t8, $t0, 1592
sw $t8, ($t5)
lw $a0, red
jal drawLaser

laserCurrentlyActive:
j keyPressed

drawLaser:
addi $t5, $s6, 0
lw $t8, ($t5)
beqz $t8, noLasers
sw $a0, 0($t8)
sw $a0, 4($t8)
sw $a0, 8($t8)
sw $a0, 12($t8)
sw $a0, 16($t8)
noLasers:
jr $ra

checkShipForm:
beq $s7, 0, ICE
beq $s7, 1, FIRE
beq $s7, 2, SHOCK
ICE:
add $s3, $0, 2		# set to normal ship speed
lw $v0, blue		# color the ship blue
j shipCheckDone

FIRE:
add $s3, $0, 2		# set to normal ship speed
lw $v0, red		# color the ship red
j shipCheckDone

SHOCK:
add $s3, $0, 4		# set to double ship speed
lw $v0, yellow		# color the ship yellow
j shipCheckDone
shipCheckDone:
jr $ra


despawnObstacles:	
addi $t7, $0, 0		# store indices
checkEachAsteroid:
addi $t6, $0, 4
mult $t6, $s5		# Multiply number of max enemies * 4
mflo $t6
beq $t7, $t6, checkedAllAsteroids
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
lw $t9, ($t8) 		# Load in the corresponding element of 'obstacles' into $t9
ble $t9, $0, noAsteroidToDespawn	# If element is less than or equal to 0, this is an empty slot and we don't need to do anything to it
# Despawn obstacle if the obstacle is at a certain x-coordinate (left side of screen)
add $t5, $0, 512
div $t9, $t5
mfhi $t5		# If address is divisible by 512, it's at the edge of the screen on the left, so despawn it
addi $s4, $s4, -1	# Remove 1 from total number of obstacles in game right now
bnez $t5, noAsteroidToDespawn	# Only despawn if address is divisble by 512, as explained above
bge $t7, 32, despawnHunter	# If index is 9 or greater, this is a FILLER
bge $t7, 20, despawnBerserker	# If index is 5 or greater but less than 9, this is a berserker
# Else, this must be an asteroid so just carry on
# Erase the obstacle visually 
despawnAsteroid:
sw $a0, 0($t9)
sw $a0, 16($t9)
sw $a0, 516($t9)
sw $a0, 520($t9)
sw $a0, 524($t9)
sw $a0, 1028($t9)
sw $a0, 1032($t9)
sw $a0, 1036($t9)
sw $a0, 1540($t9)
sw $a0, 1544($t9)
sw $a0, 1548($t9)
sw $a0, 2048($t9)
sw $a0, 2064($t9)

addi $t9, $0, 0		# Reset this obstacle to 0 in the obstacle array (and we don't need to mess with speed array since the arrays are parallel anyway)
sw $t9, ($t8) 		# Store 0 into corresponding array element (i.e. reset the array at this index)
j noAsteroidToDespawn

despawnBerserker:
sw $a0, 0($t9)
sw $a0, 4($t9)
sw $a0, 16($t9)
sw $a0, 516($t9)
sw $a0, 520($t9)
sw $a0, 524($t9)
sw $a0, 1024($t9)
sw $a0, 1028($t9)
sw $a0, 1032($t9)
sw $a0, 1036($t9)
sw $a0, 1040($t9)
sw $a0, 1540($t9)
sw $a0, 1544($t9)
sw $a0, 1548($t9)
sw $a0, 2048($t9)
sw $a0, 2052($t9)
sw $a0, 2064($t9)

addi $t9, $0, 0		# Reset this obstacle to 0 in the obstacle array (and we don't need to mess with speed array since the arrays are parallel anyway)
sw $t9, ($t8) 		# Store 0 into corresponding array element (i.e. reset the array at this index)
j noAsteroidToDespawn

despawnHunter:
sw $a0, 0($t9)
sw $a0, 4($t9)
sw $a0, 8($t9)
sw $a0, 12($t9)
sw $a0, 16($t9)
sw $a0, 512($t9)
sw $a0, 528($t9)
sw $a0, 1032($t9)
sw $a0, 1040($t9)
sw $a0, 1536($t9)
sw $a0, 1552($t9)
sw $a0, 2048($t9)
sw $a0, 2052($t9)
sw $a0, 2056($t9)
sw $a0, 2060($t9)
sw $a0, 2064($t9)

addi $t9, $0, 0		# Reset this obstacle to 0 in the obstacle array (and we don't need to mess with speed array since the arrays are parallel anyway)
sw $t9, ($t8) 		# Store 0 into corresponding array element (i.e. reset the array at this index)
j noAsteroidToDespawn

noAsteroidToDespawn:
addi $t7, $t7, 4	# Go to next element in array
j checkEachAsteroid

checkedAllAsteroids:

jr $ra

drawObstacles:	# set $t to black if erasing, to a color if coloring
addi $t7, $0, 0		# store indices
drawEachAsteroid:
addi $t6, $0, 4
mult $t6, $s5		# Multiply number of max enemies * 4
mflo $t6
beq $t7, $t6, finishedDrawingAsteroids
beq $t7, 20, finishedDrawingAsteroids # A game can have at most 5 asteroids.
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
lw $t9, ($t8) 		# Load in the corresponding element of 'obstacles' into $t9
ble $t9, $0, noAsteroidToDraw	# If element is less than or equal to 0, this is an empty slot and we don't need to do anything to it
# Draw asteroid sprite
sw $a0, 0($t9)
sw $a0, 16($t9)
sw $a0, 516($t9)
sw $a0, 520($t9)
sw $a0, 524($t9)
sw $a0, 1028($t9)
sw $a0, 1032($t9)
sw $a0, 1036($t9)
sw $a0, 1540($t9)
sw $a0, 1544($t9)
sw $a0, 1548($t9)
sw $a0, 2048($t9)
sw $a0, 2064($t9)

noAsteroidToDraw:
addi $t7, $t7, 4	# Go to next element in array
j drawEachAsteroid

finishedDrawingAsteroids:

# start drawing berserkers

drawEachBerserker:
beq $t7, $t6, finishedDrawingBerserkers
beq $t7, 32, finishedDrawingBerserkers # A game can have at most 3 berserkers.
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
lw $t9, ($t8) 		# Load in the corresponding element of 'obstacles' into $t9
ble $t9, $0, noBerserkerToDraw	# If element is less than or equal to 0, this is an empty slot and we don't need to do anything to it
# Draw berserker sprite
sw $a1, 0($t9)
sw $a1, 4($t9)
sw $a1, 16($t9)
sw $a1, 516($t9)
sw $a1, 520($t9)
sw $a1, 524($t9)
sw $a1, 1024($t9)
sw $a1, 1028($t9)
sw $a1, 1032($t9)
sw $a1, 1036($t9)
sw $a1, 1040($t9)
sw $a1, 1540($t9)
sw $a1, 1544($t9)
sw $a1, 1548($t9)
sw $a1, 2048($t9)
sw $a1, 2052($t9)
sw $a1, 2064($t9)

noBerserkerToDraw:
addi $t7, $t7, 4	# Go to next element in array
j drawEachBerserker

finishedDrawingBerserkers:

drawEachHunter:
beq $t7, $t6, finishedDrawingHunters
beq $t7, 40, finishedDrawingHunters # A game can have at most 2 hunters
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
lw $t9, ($t8) 		# Load in the corresponding element of 'obstacles' into $t9
ble $t9, $0, noHunterToDraw	# If element is less than or equal to 0, this is an empty slot and we don't need to do anything to it
# Draw Hunter sprite
sw $a1, 0($t9)
sw $a1, 4($t9)
sw $a1, 8($t9)
sw $a1, 12($t9)
sw $a1, 16($t9)
sw $a1, 512($t9)
sw $a1, 528($t9)
sw $a1, 1032($t9)
sw $a1, 1040($t9)
sw $a1, 1536($t9)
sw $a1, 1552($t9)
sw $a1, 2048($t9)
sw $a1, 2052($t9)
sw $a1, 2056($t9)
sw $a1, 2060($t9)
sw $a1, 2064($t9)

noHunterToDraw:
addi $t7, $t7, 4	# Go to next element in array
j drawEachHunter

finishedDrawingHunters:
jr $ra



moveObstacles:
addi $t7, $0, 0		# store indices
moveEachAsteroid:
addi $t6, $0, 4
mult $t6, $s5		# Multiply number of max enemies * 4
mflo $t6
beq $t7, $t6, movedAllAsteroids
beq $t7, 20, movedAllAsteroids # Can have at most 5 asteroids at a time
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
add $t5, $s2, $t7	# Put address of element of 'speeds' at index $t7 / 4 in here
lw $t9, ($t8) 		# Load in the corresponding element of 'obstacles' into $t9
lw $t6, ($t5)		# Load in the corresponding speed of obstacle into $t6
ble $t9, $0, noAsteroid	# If element is less than or equal to 0, this is an empty slot and we don't need to do anything to it
# Make obstacles move 1 time left
addi $t5, $0, -4
mult $t5, $t6		# This is how many units the obstacle will move based on their speed from speed array
mflo $t5
add $t9, $t9, $t5	# Move address left
sw $t9, ($t8) 		# Store the corresponding new address into $t8
noAsteroid:
addi $t7, $t7, 4	# Go to next element in array
j moveEachAsteroid

movedAllAsteroids:

moveEachBerserker:
beq $t7, $t6, movedAllBerserkers
beq $t7, 32, movedAllBerserkers # Can have at most 3 berserkers in a game
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
add $t5, $s2, $t7	# Put address of element of 'speeds' at index $t7 / 4 in here
lw $t9, ($t8) 		# Load in the corresponding element of 'obstacles' into $t9
lw $t6, ($t5)		# Load in the corresponding speed of obstacle into $t6
ble $t9, $0, noBerserker	# If element is less than or equal to 0, this is an empty slot and we don't need to do anything to it
# Make obstacles randomly move 1 time left, up, or down based on their speed in the speed array
li $v0, 42
li $a0, 0
li $a1, 3
syscall

beq $a0, 0, berserkLeft
beq $a0, 1, berserkUp
beq $a0, 2, berserkDown

berserkLeft:
addi $t5, $0, -4
mult $t5, $t6		# This is how many units the obstacle will move based on their speed from speed array: 4 * speed
mflo $t5
add $t9, $t9, $t5	# Move address left
sw $t9, ($t8) 		# Store the corresponding new address into $t8
j noBerserker

berserkUp:
addi $t5, $0, -512
mult $t5, $t6		# This is how many units the obstacle will move based on their speed from speed array: 4 * speed
mflo $t5
add $t5, $t9, $t5
ble $t5, $s0, berserkLeft # If going up makes the berserker go out of bounds, just go left instead
addi $t5, $0, -512
mult $t5, $t6		# This is how many units the obstacle will move based on their speed from speed array: 4 * speed
mflo $t5
add $t9, $t9, $t5	# Move address up
sw $t9, ($t8) 		# Store the corresponding new address into $t8
j noBerserker

berserkDown:
addi $t5, $0, 512
mult $t5, $t6		# This is how many units the obstacle will move based on their speed from speed array: 4 * speed
mflo $t5
add $t4, $t9, $t5
add $t5, $s0, 25084
bge $t4, $t5, berserkLeft # If going down makes the berserker go out of bounds, just go left instead
addi $t5, $0, 512
mult $t5, $t6		# This is how many units the obstacle will move based on their speed from speed array: 4 * speed
mflo $t5
add $t9, $t9, $t5	# Move address down
sw $t9, ($t8) 		# Store the corresponding new address into $t8
j noBerserker

noBerserker:
addi $t7, $t7, 4	# Go to next element in array
j moveEachBerserker

movedAllBerserkers:


moveEachHunter:
beq $t7, $t6, movedAllHunters
bge $t7, 40, movedAllHunters
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
add $t5, $s2, $t7	# Put address of element of 'speeds' at index $t7 / 4 in here
lw $t9, ($t8) 		# Load in the corresponding element of 'obstacles' into $t9
lw $t6, ($t5)		# Load in the corresponding speed of obstacle into $t6
ble $t9, $0, noHunter	# If element is less than or equal to 0, this is an empty slot and we don't need to do anything to it
# Make obstacles randomly move 1 time left, up, or down based on their speed in the speed array
lw $t0, shipAddress
add $v0, $t0, 1536
sub $v0, $t9, $v0
bgt $v0, 0, huntUp
blt $v0, 0, huntDown

huntUp:
addi $t5, $0, -512
mult $t5, $t6		# This is how many units the obstacle will move based on their speed from speed array: 4 * speed
mflo $t5
#add $t4, $t9, $t5
#ble $t4, $s0, berserkLeft # If going up makes the berserker go out of bounds, just go left instead
add $t9, $t9, $t5	# Move address up
addi $t5, $0, -4
mult $t5, $t6
mflo $t5
add $t9, $t9, $t5 	# Move address left
sw $t9, ($t8) 		# Store the corresponding new address into $t8
j noHunter

huntDown:
addi $t5, $0, 512
mult $t5, $t6		# This is how many units the obstacle will move based on their speed from speed array: 4 * speed
mflo $t5
#add $t4, $t9, $t5
#add $t3, $s0, 25084
#bge $t4, $t3, berserkLeft # If going down makes the berserker go out of bounds, just go left instead
add $t9, $t9, $t5	# Move address down
addi $t5, $0, -4
mult $t5, $t6
mflo $t5
add $t9, $t9, $t5 	# Move address left
sw $t9, ($t8) 		# Store the corresponding new address into $t8
j noHunter

noHunter:
addi $t7, $t7, 4	# Go to next element in array
j moveEachHunter

movedAllHunters:
jr $ra

getNewEnemyLocation: # Returns the address of object in $v0!
# Get random y-coordinate
li $v0, 42 		# Service 42, random int range
li $a0, 0		# Select random generator 0	
li $a1, 48 		# Select upper bound of random number
syscall			# Generate random int (returns in $a0)

# addi $s4, $s4, 1	# Notify game that an obstacle has been added
addi $v0, $0, 512	# Store base address + 512 (512 is the number to add to address to move to next unit in a column)
mult $a0, $v0		# Get y-coordinate offset
mflo $v0
add $v0, $s0, $v0	# Add this y-coordinate to the final offset based on displayAddress
addi $v0, $v0, 496	# Add x-component which makes it appear on very right side of screen (keeping in mind of the enemy's width)
jr $ra

addNewEnemy:	# adds new enemy to obstacle array
addi $t7, $0, 0
loopThroughObstacles:	
addi $t6, $0, 4
mult $t6, $s5		# Multiply number of max enemies * 4
mflo $t6
beq $t7, $t6, finishedLooping
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
add $t5, $s2, $t7	# Put address of element of 'speeds' at index $t7 / 4 in here
lw $t9, ($t8) 		# Load in the corresponding element of 'obstacles' into $t9
ble $t9, $0, loadInAddress	# If $t9 is less than or equal to 0, then this is an empty slot and we can load our address in
add $t7, $t7, 4		# Go to next address in array
j loopThroughObstacles

loadInAddress: 	# we found an empty spot to load in our obstacle
sw $a0, ($t8)		# Store address of object into that empty slot in 'obstacles'
getRandomSpeed:
li $v0, 42 		# Service 42, random int range
li $a0, 0		# Select random generator 0	
li $a1, 4 		# Select upper bound of random number
syscall	
addi $a0, $a0, 1	# Add 1 so we don't generate speeds of 0
beq $a0, 3, getRandomSpeed	# If speed is 3, get another speed since game only allows speeds of 1,2, and 4
sw $a0, ($t5)		# Load speed into speed array
finishedLooping:
jr $ra

moveLaser:
addi $t5, $s6, 0
lw $t8, ($t5)
beq $t8, 0, noLaserActive
beq $s7, 1, fireModeActive
addi $t8, $t8, 8
j storeNewLaserPosition
fireModeActive:
addi $t8, $t8, 16
storeNewLaserPosition:
sw $t8, ($t5)
noLaserActive:
jr $ra

despawnLaser:
addi $t5, $s6, 0	# Get address of array index
lw $t8, ($t5)		# Get laser address
addi $t7, $t8, -496	# Check if laser address is at edge of right side of screen
addi $t6, $0, 512
div $t7, $t6
mfhi $t7
beq $t7, 0, eraseTheLaser
beq $t7, 8, eraseTheLaser
j laserStillActive
eraseTheLaser:
sw $a0, 0($t8)
sw $a0, 4($t8)
sw $a0, 8($t8)
sw $a0, 12($t8)
sw $a0, 16($t8)
sw $0, ($t5)

laserStillActive:
jr $ra

chargeEnergy:
addi $t5, $s6, 8	# Get index for Energy Bar element in 'otherAddresses'
lw $t8, ($t5)		# Get address of current Energy bar and store it in $t8
beq $t8, 1, fullyCharged
addi $t8, $t8, 4
lw $t7, energyBlue
sw $t7, 0($t8)
sw $t7, 512($t8)
sw $t7, 1024($t8)
sw $t8, ($t5)
addi $t9, $s0, 30188
blt $t8, $t9, fullyCharged 
addi $t7, $0, 1
sw $t7, ($t5)
fullyCharged: 	# Energy is fully charged, so don't need to do anything
jr $ra

damagedShip:		# Call every time collision is registered.
addi $t5, $s6, 4	# Get index for HP Bar element in 'otherAddresses'
lw $t8, ($t5)		# Get address of current HP bar and store it in $t8
add $t8, $t8, -40	# Subtract 10 units off the HP bar (total is 60 units, so ship can take 6 hits)
lw $a0, black
# Erase portion of HP Bar
sw $a0, 40($t8)
sw $a0, 552($t8)
sw $a0, 1064($t8)
sw $a0, 36($t8)
sw $a0, 548($t8)
sw $a0, 1060($t8)
sw $a0, 32($t8)
sw $a0, 544($t8)
sw $a0, 1056($t8)
sw $a0, 28($t8)
sw $a0, 540($t8)
sw $a0, 1052($t8)
sw $a0, 24($t8)
sw $a0, 536($t8)
sw $a0, 1048($t8)
sw $a0, 20($t8)
sw $a0, 532($t8)
sw $a0, 1044($t8)
sw $a0, 16($t8)
sw $a0, 528($t8)
sw $a0, 1040($t8)
sw $a0, 12($t8)
sw $a0, 524($t8)
sw $a0, 1036($t8)
sw $a0, 8($t8)
sw $a0, 520($t8)
sw $a0, 1032($t8)
sw $a0, 4($t8)
sw $a0, 516($t8)
sw $a0, 1028($t8)
sw $a0, 0($t8)
sw $a0, 512($t8)
sw $a0, 1024($t8)

sw $t8, ($t5)
addi $t5, $s0, 29748
beq $t5, $t8, GAMEOVER

jr $ra

levelCheck:		# checks if game should increase difficulty
lw $t3, gameCounter
addi $t3, $t3, 1
sw $t3, gameCounter
addi $t7, $s5, 0
addi $t8, $0, 50
mult $t7, $t8
mflo $t7
bgt $t3, $t7, levelUp
jr $ra

levelUp:		# Increases game difficulty
addi $s5, $s5, 1
addi $t3, $0, 0
sw $t3, gameCounter
jr $ra

resetArray:
addi $t7, $0, 0		# store indices
addi $t6, $0, 40	# Max number of elements in array is 10, and each array element is 4 bits large, so 10 * 4 = 40
resetEach:
beq $t7, $t6, finishedClear
add $t8, $s1, $t7	# Put address of element of 'obstacles' at index $t7 / 4 in here
add $t9, $0, -1		# Set $t9 to -1
sw $t9, ($t8) 		# Store -1 into array slot
add $t8, $s2, $t7	# Put address of element of 'speeds' at index $t7 / 4 in here
add $t9, $0, -1		# Set $t9 to -1
sw $t9, ($t8) 		# Store -1 into array slot
addi $t7, $t7, 4	# Go to next element in array
j resetEach
finishedClear:
jr $ra

ERASE_ALL:		# Clear the screen
add $t8, $0, $0
START_ERASING:
add $t9, $s0, $t8
sw $a0, ($t9)
add $t8, $t8, 4
beq $t8, 32768, DONE_ERASING
j START_ERASING

DONE_ERASING:
jr $ra

drawShip:	# Draw the ship shape with the 2 inputted colors. $a0 is the primary color, $a1 is the secondary color
### PAINTING
lw $t0, shipAddress
sw $a0, 0($t0)   # paint back tips of plane
sw $a0, 3072($t0)  
# paint tail of plane
sw $a0, 4($t0)
sw $a0, 516($t0)
sw $a0, 2564($t0)
sw $a0, 3076($t0)
# paint tail of plane
sw $a0, 8($t0)
sw $a0, 520($t0)
sw $a0, 1032($t0)
sw $a0, 1544($t0)
sw $a0, 2056($t0)
sw $a0, 2568($t0)
sw $a0, 3080($t0)
# paint tail of plane
sw $a0, 524($t0)
sw $a0, 1036($t0)
sw $a0, 1548($t0)
sw $a0, 2060($t0)
sw $a0, 2572($t0)
# paint tail body of plane
sw $a0, 1040($t0)
sw $a0, 1552($t0)
sw $a0, 2064($t0)
# paint tail body of plane
sw $a0, 1044($t0)
sw $a1, 1556($t0)
sw $a0, 2068($t0)
# paint body and tips of wings of plane
sw $a0, 1048($t0)
sw $a1, 1560($t0)
sw $a0, 2072($t0)
# paint body and wings of plane
sw $a0, 1052($t0)
sw $a1, 1564($t0)
sw $a0, 2076($t0)
# paint body and wings of plane
sw $a0, 1056($t0)
sw $a1, 1568($t0)
sw $a0, 2080($t0)
# paint head of plane
sw $a0, 36($t0)
sw $a0, 548($t0)
sw $a0, 1060($t0)
sw $a1, 1572($t0)
sw $a0, 2084($t0)
sw $a0, 2596($t0)
sw $a0, 3108($t0)
# paint head of plane
sw $a1, 40($t0)
sw $a0, 552($t0)
sw $a0, 1064($t0)
sw $a1, 1576($t0)
sw $a0, 2088($t0)
sw $a0, 2600($t0)
sw $a1, 3112($t0)
# paint head of plane
sw $a1, 44($t0)
sw $a0, 1068($t0)
sw $a0, 1580($t0)
sw $a0, 2092($t0)
sw $a1, 3116($t0)
# paint head of plane
sw $a1, 48($t0)
sw $a0, 1072($t0)
sw $a0, 1584($t0)
sw $a0, 2096($t0)
sw $a1, 3120($t0)
# paint tip of head of plane
sw $a1, 1588($t0)
jr $ra

GAMEOVER:	# Create gameover screen
# We can use whatever registers since this occurs at the end of the game.
jal ERASE_ALL
lw $t5, red

# PAINT 'G'
sw $t5, 4204($s0)
sw $t5, 4208($s0)
sw $t5, 4212($s0)
sw $t5, 4216($s0)
sw $t5, 4220($s0)

sw $t5, 4712($s0)
sw $t5, 4716($s0)
sw $t5, 4720($s0)
sw $t5, 4724($s0)
sw $t5, 4728($s0)
sw $t5, 4732($s0)
sw $t5, 4736($s0)

sw $t5, 5224($s0)
sw $t5, 5228($s0)
sw $t5, 5232($s0)
sw $t5, 5240($s0)
sw $t5, 5244($s0)
sw $t5, 5248($s0)

sw $t5, 5736($s0)
sw $t5, 5740($s0)
sw $t5, 5756($s0)
sw $t5, 5760($s0)

sw $t5, 6248($s0)
sw $t5, 6252($s0)
sw $t5, 6760($s0)
sw $t5, 6764($s0)

sw $t5, 7272($s0)
sw $t5, 7276($s0)
sw $t5, 7284($s0)
sw $t5, 7288($s0)
sw $t5, 7292($s0)
sw $t5, 7296($s0)

sw $t5, 7784($s0)
sw $t5, 7788($s0)
sw $t5, 7800($s0)
sw $t5, 7804($s0)
sw $t5, 7808($s0)

sw $t5, 8296($s0)
sw $t5, 8300($s0)
sw $t5, 8316($s0)
sw $t5, 8320($s0)

sw $t5, 8808($s0)
sw $t5, 8812($s0)
sw $t5, 8828($s0)
sw $t5, 8832($s0)

sw $t5, 9320($s0)
sw $t5, 9324($s0)
sw $t5, 9328($s0)
sw $t5, 9332($s0)
sw $t5, 9336($s0)
sw $t5, 9340($s0)
sw $t5, 9344($s0)

sw $t5, 9836($s0)
sw $t5, 9840($s0)
sw $t5, 9844($s0)
sw $t5, 9848($s0)
sw $t5, 9852($s0)

# PAINT 'A'
sw $t5, 4240($s0)
sw $t5, 4244($s0)
sw $t5, 4248($s0)
sw $t5, 4252($s0)


sw $t5, 4748($s0)
sw $t5, 4752($s0)
sw $t5, 4756($s0)
sw $t5, 4760($s0)
sw $t5, 4764($s0)
sw $t5, 4768($s0)

sw $t5, 5260($s0)
sw $t5, 5264($s0)
sw $t5, 5276($s0)
sw $t5, 5280($s0)

sw $t5, 5772($s0)
sw $t5, 5776($s0)
sw $t5, 5788($s0)
sw $t5, 5792($s0)

sw $t5, 6284($s0)
sw $t5, 6288($s0)
sw $t5, 6300($s0)
sw $t5, 6304($s0)

sw $t5, 6796($s0)
sw $t5, 6800($s0)
sw $t5, 6812($s0)
sw $t5, 6816($s0)

sw $t5, 7308($s0)
sw $t5, 7312($s0)
sw $t5, 7316($s0)
sw $t5, 7320($s0)
sw $t5, 7324($s0)
sw $t5, 7328($s0)

sw $t5, 7820($s0)
sw $t5, 7824($s0)
sw $t5, 7828($s0)
sw $t5, 7832($s0)
sw $t5, 7836($s0)
sw $t5, 7840($s0)

sw $t5, 8332($s0)
sw $t5, 8336($s0)
sw $t5, 8348($s0)
sw $t5, 8352($s0)

sw $t5, 8844($s0)
sw $t5, 8848($s0)
sw $t5, 8860($s0)
sw $t5, 8864($s0)

sw $t5, 9356($s0)
sw $t5, 9360($s0)
sw $t5, 9372($s0)
sw $t5, 9376($s0)

sw $t5, 9868($s0)
sw $t5, 9872($s0)
sw $t5, 9884($s0)
sw $t5, 9888($s0)

# PAINT 'M'
sw $t5, 4268($s0)
sw $t5, 4272($s0)
sw $t5, 4276($s0)
sw $t5, 4292($s0)
sw $t5, 4296($s0)
sw $t5, 4300($s0)

sw $t5, 4780($s0)
sw $t5, 4784($s0)
sw $t5, 4788($s0)
sw $t5, 4792($s0)
sw $t5, 4800($s0)
sw $t5, 4804($s0)
sw $t5, 4808($s0)
sw $t5, 4812($s0)

sw $t5, 5292($s0)
sw $t5, 5296($s0)
sw $t5, 5300($s0)
sw $t5, 5304($s0)
sw $t5, 5308($s0)
sw $t5, 5312($s0)
sw $t5, 5316($s0)
sw $t5, 5320($s0)
sw $t5, 5324($s0)	

sw $t5, 5804($s0)
sw $t5, 5808($s0)
sw $t5, 5812($s0)
sw $t5, 5816($s0)
sw $t5, 5820($s0)
sw $t5, 5824($s0)
sw $t5, 5828($s0)
sw $t5, 5832($s0)
sw $t5, 5836($s0)

sw $t5, 6316($s0)
sw $t5, 6320($s0)
sw $t5, 6328($s0)
sw $t5, 6332($s0)
sw $t5, 6336($s0)
sw $t5, 6344($s0)
sw $t5, 6348($s0)

sw $t5, 6828($s0)
sw $t5, 6832($s0)
sw $t5, 6844($s0)
sw $t5, 6856($s0)
sw $t5, 6860($s0)

sw $t5, 7340($s0)
sw $t5, 7344($s0)
sw $t5, 7368($s0)
sw $t5, 7372($s0)

sw $t5, 7852($s0)
sw $t5, 7856($s0)
sw $t5, 7880($s0)
sw $t5, 7884($s0)

sw $t5, 8364($s0)
sw $t5, 8368($s0)
sw $t5, 8392($s0)
sw $t5, 8396($s0)

sw $t5, 8876($s0)
sw $t5, 8880($s0)
sw $t5, 8904($s0)
sw $t5, 8908($s0)

sw $t5, 9388($s0)
sw $t5, 9392($s0)
sw $t5, 9416($s0)
sw $t5, 9420($s0)

sw $t5, 9900($s0)
sw $t5, 9904($s0)
sw $t5, 9928($s0)
sw $t5, 9932($s0)

# PAINT 'E'
sw $t5, 4312($s0)
sw $t5, 4316($s0)
sw $t5, 4320($s0)
sw $t5, 4324($s0)
sw $t5, 4328($s0)
sw $t5, 4332($s0)

sw $t5, 4824($s0)
sw $t5, 4828($s0)
sw $t5, 4832($s0)
sw $t5, 4836($s0)
sw $t5, 4840($s0)
sw $t5, 4844($s0)

sw $t5, 5336($s0)
sw $t5, 5340($s0)
	
sw $t5, 5848($s0)
sw $t5, 5852($s0)

sw $t5, 6360($s0)
sw $t5, 6364($s0)

sw $t5, 6872($s0)
sw $t5, 6876($s0)
sw $t5, 6880($s0)
sw $t5, 6884($s0)

sw $t5, 7384($s0)
sw $t5, 7388($s0)
sw $t5, 7392($s0)
sw $t5, 7396($s0)

sw $t5, 7896($s0)
sw $t5, 7900($s0)

sw $t5, 8408($s0)
sw $t5, 8412($s0)

sw $t5, 8920($s0)
sw $t5, 8924($s0)

sw $t5, 9432($s0)
sw $t5, 9436($s0)
sw $t5, 9440($s0)
sw $t5, 9444($s0)
sw $t5, 9448($s0)
sw $t5, 9452($s0)

sw $t5, 9944($s0)
sw $t5, 9948($s0)
sw $t5, 9952($s0)
sw $t5, 9956($s0)
sw $t5, 9960($s0)
sw $t5, 9964($s0)

# PAINT 'O'
sw $t5, 4372($s0)
sw $t5, 4376($s0)
sw $t5, 4380($s0)
sw $t5, 4384($s0)
sw $t5, 4388($s0)
sw $t5, 4392($s0)

sw $t5, 4884($s0)
sw $t5, 4888($s0)
sw $t5, 4892($s0)
sw $t5, 4896($s0)
sw $t5, 4900($s0)
sw $t5, 4904($s0)

sw $t5, 5396($s0)
sw $t5, 5400($s0)
sw $t5, 5412($s0)
sw $t5, 5416($s0)	
	
sw $t5, 5908($s0)
sw $t5, 5912($s0)
sw $t5, 5924($s0)
sw $t5, 5928($s0)

sw $t5, 6420($s0)
sw $t5, 6424($s0)
sw $t5, 6436($s0)
sw $t5, 6440($s0)

sw $t5, 6932($s0)
sw $t5, 6936($s0)
sw $t5, 6948($s0)
sw $t5, 6952($s0)

sw $t5, 7444($s0)
sw $t5, 7448($s0)
sw $t5, 7460($s0)
sw $t5, 7464($s0)

sw $t5, 7956($s0)
sw $t5, 7960($s0)
sw $t5, 7972($s0)
sw $t5, 7976($s0)

sw $t5, 8468($s0)
sw $t5, 8472($s0)
sw $t5, 8484($s0)
sw $t5, 8488($s0)

sw $t5, 8980($s0)
sw $t5, 8984($s0)
sw $t5, 8996($s0)
sw $t5, 9000($s0)


sw $t5, 9492($s0)
sw $t5, 9496($s0)
sw $t5, 9500($s0)
sw $t5, 9504($s0)
sw $t5, 9508($s0)
sw $t5, 9512($s0)

sw $t5, 10004($s0)
sw $t5, 10008($s0)
sw $t5, 10012($s0)
sw $t5, 10016($s0)
sw $t5, 10020($s0)
sw $t5, 10024($s0)

# PAINT 'V'
sw $t5, 4404($s0)
sw $t5, 4408($s0)
sw $t5, 4424($s0)
sw $t5, 4428($s0)

sw $t5, 4916($s0)
sw $t5, 4920($s0)
sw $t5, 4936($s0)
sw $t5, 4940($s0)

sw $t5, 5428($s0)
sw $t5, 5432($s0)
sw $t5, 5448($s0)
sw $t5, 5452($s0)	
	
sw $t5, 5940($s0)
sw $t5, 5944($s0)
sw $t5, 5960($s0)
sw $t5, 5964($s0)

sw $t5, 6452($s0)
sw $t5, 6456($s0)
sw $t5, 6472($s0)
sw $t5, 6476($s0)

sw $t5, 6964($s0)
sw $t5, 6968($s0)
sw $t5, 6984($s0)
sw $t5, 6988($s0)

sw $t5, 7476($s0)
sw $t5, 7480($s0)
sw $t5, 7496($s0)
sw $t5, 7500($s0)

sw $t5, 7988($s0)
sw $t5, 7992($s0)
sw $t5, 7996($s0)
sw $t5, 8004($s0)
sw $t5, 8008($s0)
sw $t5, 8012($s0)

sw $t5, 8504($s0)
sw $t5, 8508($s0)
sw $t5, 8516($s0)
sw $t5, 8520($s0)

sw $t5, 9016($s0)
sw $t5, 9020($s0)
sw $t5, 9028($s0)
sw $t5, 9032($s0)


sw $t5, 9528($s0)
sw $t5, 9532($s0)
sw $t5, 9536($s0)
sw $t5, 9540($s0)
sw $t5, 9544($s0)

sw $t5, 10044($s0)
sw $t5, 10048($s0)
sw $t5, 10052($s0)

# PAINT 'E'
sw $t5, 4440($s0)
sw $t5, 4444($s0)
sw $t5, 4448($s0)
sw $t5, 4452($s0)
sw $t5, 4456($s0)
sw $t5, 4460($s0)

sw $t5, 4952($s0)
sw $t5, 4956($s0)
sw $t5, 4960($s0)
sw $t5, 4964($s0)
sw $t5, 4968($s0)
sw $t5, 4972($s0)

sw $t5, 5464($s0)
sw $t5, 5468($s0)
	
sw $t5, 5976($s0)
sw $t5, 5980($s0)

sw $t5, 6488($s0)
sw $t5, 6492($s0)

sw $t5, 7000($s0)
sw $t5, 7004($s0)
sw $t5, 7008($s0)
sw $t5, 7012($s0)

sw $t5, 7512($s0)
sw $t5, 7516($s0)
sw $t5, 7520($s0)
sw $t5, 7524($s0)

sw $t5, 8024($s0)
sw $t5, 8028($s0)

sw $t5, 8536($s0)
sw $t5, 8540($s0)

sw $t5, 9048($s0)
sw $t5, 9052($s0)

sw $t5, 9560($s0)
sw $t5, 9564($s0)
sw $t5, 9568($s0)
sw $t5, 9572($s0)
sw $t5, 9576($s0)
sw $t5, 9580($s0)

sw $t5, 10072($s0)
sw $t5, 10076($s0)
sw $t5, 10080($s0)
sw $t5, 10084($s0)
sw $t5, 10088($s0)
sw $t5, 10092($s0)

# PAINT 'R'
sw $t5, 4472($s0)
sw $t5, 4476($s0)
sw $t5, 4480($s0)
sw $t5, 4484($s0)
sw $t5, 4488($s0)
sw $t5, 4492($s0)

sw $t5, 4984($s0)
sw $t5, 4988($s0)
sw $t5, 4992($s0)
sw $t5, 4996($s0)
sw $t5, 5000($s0)
sw $t5, 5004($s0)
sw $t5, 5008($s0)

sw $t5, 5496($s0)
sw $t5, 5500($s0)
sw $t5, 5516($s0)
sw $t5, 5520($s0)
	
sw $t5, 6008($s0)
sw $t5, 6012($s0)
sw $t5, 6028($s0)
sw $t5, 6032($s0)

sw $t5, 6520($s0)
sw $t5, 6524($s0)
sw $t5, 6540($s0)
sw $t5, 6544($s0)

sw $t5, 7032($s0)
sw $t5, 7036($s0)
sw $t5, 7052($s0)
sw $t5, 7056($s0)

sw $t5, 7544($s0)
sw $t5, 7548($s0)
sw $t5, 7552($s0)
sw $t5, 7556($s0)
sw $t5, 7560($s0)
sw $t5, 7564($s0)

sw $t5, 8056($s0)
sw $t5, 8060($s0)
sw $t5, 8064($s0)
sw $t5, 8068($s0)
sw $t5, 8072($s0)

sw $t5, 8568($s0)
sw $t5, 8572($s0)
sw $t5, 8580($s0)
sw $t5, 8584($s0)
sw $t5, 8588($s0)

sw $t5, 9080($s0)
sw $t5, 9084($s0)
sw $t5, 9096($s0)
sw $t5, 9100($s0)
sw $t5, 9104($s0)

sw $t5, 9592($s0)
sw $t5, 9596($s0)
sw $t5, 9612($s0)
sw $t5, 9616($s0)

sw $t5, 10104($s0)
sw $t5, 10108($s0)
sw $t5, 10124($s0)
sw $t5, 10128($s0)

j DONE

eraseEnergyBar:
addi $t8, $s0, 30060		# Marks the beginning of energy bar
# Just paint the whole energy bar black


sw $a0, 128($t8)
sw $a0, 124($t8)
sw $a0, 120($t8)
sw $a0, 116($t8)
sw $a0, 112($t8)
sw $a0, 108($t8)
sw $a0, 104($t8)
sw $a0, 100($t8)
sw $a0, 96($t8)
sw $a0, 92($t8)
sw $a0, 88($t8)
sw $a0, 84($t8)
sw $a0, 80($t8)
sw $a0, 76($t8)
sw $a0, 72($t8)
sw $a0, 68($t8)
sw $a0, 64($t8)
sw $a0, 60($t8)
sw $a0, 56($t8)
sw $a0, 52($t8)
sw $a0, 48($t8)
sw $a0, 44($t8)
sw $a0, 40($t8)
sw $a0, 36($t8)
sw $a0, 32($t8)
sw $a0, 28($t8)
sw $a0, 24($t8)
sw $a0, 20($t8)
sw $a0, 16($t8)
sw $a0, 12($t8)
sw $a0, 8($t8)
sw $a0, 4($t8)

sw $a0, 640($t8)
sw $a0, 636($t8)
sw $a0, 632($t8)
sw $a0, 628($t8)
sw $a0, 624($t8)
sw $a0, 620($t8)
sw $a0, 616($t8)
sw $a0, 612($t8)
sw $a0, 608($t8)
sw $a0, 604($t8)
sw $a0, 600($t8)
sw $a0, 596($t8)
sw $a0, 592($t8)
sw $a0, 588($t8)
sw $a0, 584($t8)
sw $a0, 580($t8)
sw $a0, 576($t8)
sw $a0, 572($t8)
sw $a0, 568($t8)
sw $a0, 564($t8)
sw $a0, 560($t8)
sw $a0, 556($t8)
sw $a0, 552($t8)
sw $a0, 548($t8)
sw $a0, 544($t8)
sw $a0, 540($t8)
sw $a0, 536($t8)
sw $a0, 532($t8)
sw $a0, 528($t8)
sw $a0, 524($t8)
sw $a0, 520($t8)
sw $a0, 516($t8)

sw $a0, 1152($t8)
sw $a0, 1148($t8)
sw $a0, 1144($t8)
sw $a0, 1140($t8)
sw $a0, 1136($t8)
sw $a0, 1132($t8)
sw $a0, 1128($t8)
sw $a0, 1124($t8)
sw $a0, 1120($t8)
sw $a0, 1116($t8)
sw $a0, 1112($t8)
sw $a0, 1108($t8)
sw $a0, 1104($t8)
sw $a0, 1100($t8)
sw $a0, 1096($t8)
sw $a0, 1092($t8)
sw $a0, 1088($t8)
sw $a0, 1084($t8)
sw $a0, 1080($t8)
sw $a0, 1076($t8)
sw $a0, 1072($t8)
sw $a0, 1068($t8)
sw $a0, 1064($t8)
sw $a0, 1060($t8)
sw $a0, 1056($t8)
sw $a0, 1052($t8)
sw $a0, 1048($t8)
sw $a0, 1044($t8)
sw $a0, 1040($t8)
sw $a0, 1036($t8)
sw $a0, 1032($t8)
sw $a0, 1028($t8)
jr $ra

DRAW_HUD:
# All of this is just drawing HUD for the first time on game initialization.

# Initialize all the colors - can use any registers since the HUD only needs to be drawn once on game start.
add $t1, $s0, 27648
add $t4, $0, 27648
lw $t2, gray 
lw $t3, red
lw $t5, energyBlue
lw $t6, purple
lw $t7, black
# Draw border between HUD and actual game.
HUD_LOOP:
beq $t4, 28160, HUD_LOOP2	
sw $t6, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP

# Draw second row of HUD (gray spacer)
HUD_LOOP2:
beq $t4, 28672, HUD_LOOP3
lw $t2, gray 	
sw $t2, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP2

# Draw third row of HUD (gray spacer)
HUD_LOOP3:
beq $t4, 29184, DRAW_HUD4	
sw $t2, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP3

# Draw fourth row of HUD, including top of HP and EN Bars
DRAW_HUD4:
sw $t2, ($t1)  
sw $t2, 4($t1)  
sw $t3, 8($t1)
sw $t2, 12($t1) 
sw $t3, 16($t1)
sw $t2, 20($t1) 
sw $t3, 24($t1)
sw $t3, 28($t1)
sw $t3, 32($t1)
sw $t2, 36($t1)
sw $t2, 40($t1)
sw $t2, 44($t1)
addi $t1, $t1, 48
addi $t4, $t4, 48
HUD_LOOP4a:
beq $t4, 29484, DRAW_HUD4b	
sw $t6, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP4a

DRAW_HUD4b:
sw $t2, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
sw $t5, 12($t1)
sw $t5, 16($t1)
sw $t5, 20($t1)
sw $t5, 24($t1)
sw $t2, 28($t1)
sw $t5, 32($t1)
sw $t5, 36($t1)
sw $t2, 40($t1)
sw $t2, 44($t1)
sw $t5, 48($t1)
sw $t2, 52($t1)
sw $t2, 56($t1)
sw $t2, 60($t1)
addi $t1, $t1, 64
addi $t4, $t4, 64
HUD_LOOP4b:
beq $t4, 29684, DRAW_HUD4c	
sw $t6, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP4b

DRAW_HUD4c:
sw $t2, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
addi $t1, $t1, 12
addi $t4, $t4, 12

# Draw fifth row of HUD, including middle of HP and EN Bars
DRAW_HUD5:
sw $t2, ($t1)  
sw $t2, 4($t1)  
sw $t3, 8($t1)
sw $t2, 12($t1) 
sw $t3, 16($t1)
sw $t2, 20($t1) 
sw $t3, 24($t1)
sw $t2, 28($t1)
sw $t3, 32($t1)
sw $t2, 36($t1)
sw $t2, 40($t1)
sw $t2, 44($t1)
sw $t6, 48($t1)
addi $t1, $t1, 52
addi $t4, $t4, 52
HUD_LOOP5a:
beq $t4, 29992, DRAW_HUD5b	
sw $t3, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP5a

DRAW_HUD5b:
sw $t6, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
sw $t2, 12($t1)
sw $t5, 16($t1)
sw $t2, 20($t1)
sw $t2, 24($t1)
sw $t2, 28($t1)
sw $t2, 32($t1)
sw $t5, 36($t1)
sw $t5, 40($t1)
sw $t5, 44($t1)
sw $t2, 48($t1)
sw $t5, 52($t1)
sw $t2, 56($t1)
sw $t2, 60($t1)
sw $t2, 64($t1)
sw $t6, 68($t1)
addi $t1, $t1, 72
addi $t4, $t4, 72
HUD_LOOP5b:
beq $t4, 30192, DRAW_HUD5c	
sw $t7, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP5b

DRAW_HUD5c:
sw $t6, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
sw $t2, 12($t1)
addi $t1, $t1, 16
addi $t4, $t4, 16

# Draw sixth row of HUD, including middle of HP and EN Bars
DRAW_HUD6:
sw $t2, ($t1)  
sw $t2, 4($t1)  
sw $t3, 8($t1)
sw $t3, 12($t1) 
sw $t3, 16($t1)
sw $t2, 20($t1) 
sw $t3, 24($t1)
sw $t3, 28($t1)
sw $t3, 32($t1)
sw $t2, 36($t1)
sw $t2, 40($t1)
sw $t2, 44($t1)
sw $t6, 48($t1)
addi $t1, $t1, 52
addi $t4, $t4, 52
HUD_LOOP6a:
beq $t4, 30504, DRAW_HUD6b	
sw $t3, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP6a

DRAW_HUD6b:
sw $t6, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
sw $t2, 12($t1)
sw $t5, 16($t1)
sw $t5, 20($t1)
sw $t5, 24($t1)
sw $t5, 28($t1)
sw $t2, 32($t1)
sw $t5, 36($t1)
sw $t5, 40($t1)
sw $t5, 44($t1)
sw $t5, 48($t1)
sw $t5, 52($t1)
sw $t2, 56($t1)
sw $t2, 60($t1)
sw $t2, 64($t1)
sw $t6, 68($t1)
addi $t1, $t1, 72
addi $t4, $t4, 72
HUD_LOOP6b:
beq $t4, 30704, DRAW_HUD6c	
sw $t7, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP6b

DRAW_HUD6c:
sw $t6, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
sw $t2, 12($t1)
addi $t1, $t1, 16
addi $t4, $t4, 16

# Draw seventh row of HUD, including middle of HP and EN Bars
DRAW_HUD7:
sw $t2, ($t1)  
sw $t2, 4($t1)  
sw $t3, 8($t1)
sw $t2, 12($t1) 
sw $t3, 16($t1)
sw $t2, 20($t1) 
sw $t3, 24($t1)
sw $t2, 28($t1)
sw $t2, 32($t1)
sw $t2, 36($t1)
sw $t2, 40($t1)
sw $t2, 44($t1)
sw $t6, 48($t1)
addi $t1, $t1, 52
addi $t4, $t4, 52
HUD_LOOP7a:
beq $t4, 31016, DRAW_HUD7b	
sw $t3, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP7a

DRAW_HUD7b:
sw $t6, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
sw $t2, 12($t1)
sw $t5, 16($t1)
sw $t2, 20($t1)
sw $t2, 24($t1)
sw $t2, 28($t1)
sw $t2, 32($t1)
sw $t5, 36($t1)
sw $t2, 40($t1)
sw $t5, 44($t1)
sw $t5, 48($t1)
sw $t5, 52($t1)
sw $t2, 56($t1)
sw $t2, 60($t1)
sw $t2, 64($t1)
sw $t6, 68($t1)
addi $t1, $t1, 72
addi $t4, $t4, 72
HUD_LOOP7b:
beq $t4, 31216, DRAW_HUD7c	
sw $t7, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP7b

DRAW_HUD7c:
sw $t6, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
sw $t2, 12($t1)
addi $t1, $t1, 16
addi $t4, $t4, 16

# Draw eighth row of HUD, including bottom of HP and EN Bars
DRAW_HUD8:
sw $t2, ($t1)  
sw $t2, 4($t1)  
sw $t3, 8($t1)
sw $t2, 12($t1) 
sw $t3, 16($t1)
sw $t2, 20($t1) 
sw $t3, 24($t1)
sw $t2, 28($t1)
sw $t2, 32($t1)
sw $t2, 36($t1)
sw $t2, 40($t1)
sw $t2, 44($t1)
addi $t1, $t1, 48
addi $t4, $t4, 48
HUD_LOOP8a:
beq $t4, 31532, DRAW_HUD8b	
sw $t6, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP8a

DRAW_HUD8b:
sw $t2, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
sw $t5, 12($t1)
sw $t5, 16($t1)
sw $t5, 20($t1)
sw $t5, 24($t1)
sw $t2, 28($t1)
sw $t5, 32($t1)
sw $t2, 36($t1)
sw $t2, 40($t1)
sw $t5, 44($t1)
sw $t5, 48($t1)
sw $t2, 52($t1)
sw $t2, 56($t1)
sw $t2, 60($t1)
addi $t1, $t1, 64
addi $t4, $t4, 64
HUD_LOOP8b:
beq $t4, 31732, DRAW_HUD8c	
sw $t6, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP8b

DRAW_HUD8c:
sw $t2, 0($t1)
sw $t2, 4($t1)
sw $t2, 8($t1)
addi $t1, $t1, 12
addi $t4, $t4, 12

# Draw ninth row of HUD (gray spacer)
HUD_LOOP9:
beq $t4, 32256, HUD_LOOP10
lw $t2, gray 	
sw $t2, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP9

# Draw tenth row of HUD (gray spacer)
HUD_LOOP10:
beq $t4, 32768, HUD_DONE
lw $t2, gray 	
sw $t2, ($t1)  
addi $t1, $t1, 4
addi $t4, $t4, 4
j HUD_LOOP10
HUD_DONE:
jr $ra

ENDGAME:
# cehck for input!

j DONE



