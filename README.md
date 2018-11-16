# bomberman-de1
A simple game inspired by Bomberman, written in Verilog for an Altera DE1 board

## Compiling and Running
1. Clone the repository using the following command in Terminal or Command Prompt, which will create a folder named 'bomberman-de1'
...
git clone https://github.com/dtcan/bomberman-de1.git
...
2. Open Quartus Prime, and press 'Ctrl+N' to create a new project.
3. Set the 'bomberman-de1' folder as the working directory. The project name and top-level module is 'bomberman'. Click 'Next'.
4. Select 'Empty project' and click 'Next'.
5. Click the 'Add All' button on the right side of the window, which should add all the project files from the repository. Click 'Next'.
6. Select the device that you want to compile for. Click 'Finish'.
7. Go to 'Assignments' > 'Import Assignments..', and choose the .qsf file containing the pin assignments for your device.
8. Press 'Ctrl+L' to start compiling the project.
9. When the compilation is complete, click on the 'Programmer' button in the toolbar to open the 'Programmer' window.
10. Click 'Hardware Setup...'. Select your device from the drop-down menu and close the window. Click 'Auto-Detect' to add your device to the device list.
11. Click on the 'File' column next to your device. Go to 'output_files' and select 'bomberman.sof'.
12. Click the 'Start' button to run the game!

## Compatibility
This project was made for an 5CSEMA5F31C6 (Altera DE1 SOC) device, but it should work with any device that is supported by Quartus Prime. It may also work with any FPGA that can work with Verilog files, although the compilation process may differ.