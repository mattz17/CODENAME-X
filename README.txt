CODENAME:X is a horizontal scrolling shoot-em-up game implemented in MIPS assembly language.

Game Rules:
Survive as long as possible while avoiding all obstacles. Hitting an obstacle will lower the ship's HP. 
When HP reaches 0, then the game ends. There is also an Energy Bar that will increase over time. 
A full energy bar allows the ship to use a very powerful, special ability. Upon usage, the Energy Bar 
is reset to 0 and will begin building up again.

The Ship Basics:
The ship can move in 4 directions: Up, Down, Left, and Right
To move up, press the 'W' key.
To move left, press the 'A' key.
To move down, press the 'S' key.
To move right, press the 'D' key.
The ship is also capable of firing a laser to destroy obstacles/enemies in one hit. 
Laser cooldown refreshes if an enemy is hit, or if the laser travels to the right end of the screen.
To fire a laser, press the spacebar.

Ship Forms and Associated Abilities:
The player ship is also capable of switching to different forms to fit different player play-styles or situations.
For each Active Ability, the player can activate it by pressing 'X' when the Energy Bar is full.
The three forms are as follows:

CODENAME:ICE - Colour: Blue - A strategic based form - Press '1' to activate
Passive Ability: The ship feeds off the cold frigidness of space, thus granting 2x energy gain.
Active Ability: Absolute Zero - Freeze all enemy ships for a short amount of time.
Note: While the player ship is free to fire lasers and destroy foes when Absolute Zero is active,
the player ship can still take damage if they collide with an obstacle/enemy

CODENAME:FIRE - Colour: Red - An offensive based form - Press '2' to activate
Passive Ability: The ship emits an energetic pulse that allows its lasers to travel at 2x speed
Active Ability: Solar Flare - destroy all active obstacles/enemies

CODENAME:SHOCK - Colour: Yellow - A mobility based form - Press '3' to activate
Passive Ability: The ship makes clever use of electric fields to propel itself and travel at 2x speed
Active Ability: Blink! - Teleport a short distance forward (to the right)
Note: In the best interest of its pilot, the ship will refuse to teleport into uncharted, unknown territory
(the ship will only teleportif on the left half of the screen).

Obstacles and Enemies:
Obstacles/Enemies will spawn exclusively on the right end of the screen. The Y-coordinate in which the
foe spawns is random, and it can have a speed of either 1 or 2 (where 2 travels 2x as fast as 1).
The Obstacles/Enemies are as follows:

Asteroid: the gray foe
Asteroid Movement: Will always travel to the left in a linear fashion

Berserker: a red foe resembling an insect
Berserker Movement: Will randomly travel either up, down, or left (and will never go out of bounds on up or down)

Hunter: a red foe resembling an eye
Hunter Movement: Will track the player ship, either moving up and left or down and left to move closer to the player.

Other Commands:
P - Restart the game

On the GAME OVER screen:
P - Play Again
X - Quit