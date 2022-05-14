# mc-nuclear-reactor-network
3 scripts to be ran on opencomputers computers in minecraft 1.12.2 to manage nuclearcraft fisson reactors

The controller is the less powerful computer that connects to the reactor. Is the child of the hub.

The hub is the main computer that controls all the controllers that are connected to each reactor.

The server is the information storer. Just keeps data from reactor controllers on memory until called for.

Keep in mind when copying over the hub code, it the ingame computers can only paste up to 257 lines of code, so you will have to copy and paste twice.

# From quest

To run the code on the floppy disk you have to navigate onto the disk. All storage devices are listed in /mnt. So to access a disk with the address starting with 5b8, you will do:

cd /mnt/5b8

Next typing ls will list whats in the directory.
Then typing in the file name to run it.

If there is a problem with any of the programs not starting right it will be that you haven't connected the fission reactor to the computer (cable attached to the computer must be attached to the fission controller or fission reactor port) or you don't have a wireless network card. Anything else is probally something to do your ingame computer.

### Hub
The hub controls all the reactors (that have a controller on then) in the range of the modem. Theres singular-reactor commands and also all-reactor commands. singular-reactor commands only control the reactor that has been specifically chosen by the user. All-reactor commands have simple commands that affects all reactors connected to/in range of the hub.

### Controller
The controller simply controls the reactor that it is connected to. It is only ment to be connected to one reactor only. You have to enter a reactor ID which be the fuel type or whatever. This ID will show up on the hub. To connect the computer to the reactor you simply have a cable attached to the computer connect to the fission controller or the fission reactor port.

### Server
The most expensive part of this, but is key. The server just has to be in range of both the controllers and the hub. Just run the script to start.

If you lose the floppy disks or want more copys, you can use the copy command or you can go to the github:
