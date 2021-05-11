# Centipede-Atari-In-Assembly
A recreation of the Centipede Atari game form the 80s written entirely in MIPS assembly for authenticity.
Here are the steps to run the game:
1. Download the Mars simulator jar file and run it.  
   
2. Open centipede.s in the simulator.  
   
3. In the top bar menu click on Tools and select "Bitmap Display", and configure it 
   as specified at the top of the centipede.s file. Then click "Connect to MIPS" (make sure you don't connect midrun, 
   as this causes the simulator to freeze indefinitely until you restart your computer)

4. In the top bar menu click on Tools and select "Keyboard and Display MMIO Simulator". Again click on "Connect to 
   MIPS".
   
5. Compile the program and run it. You can move the blaster left and right using j and k, shoot using x and restart using s.
Simply type them in the bottom box of the keyboard simulator.