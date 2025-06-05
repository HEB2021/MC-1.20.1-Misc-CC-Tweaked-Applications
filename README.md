This is a small program designed to control the flow of overflow saplings from a phytogenic insolator from Thermal Expansion, it uses applied energistcs to move items quickly as 1.20.1 has no item ducts at the time of writing this application.

Layout as seen below:
![image](https://github.com/user-attachments/assets/2ab0998f-0106-49ee-a83e-48f7af9038ee)

An infinite water source with an aqueous accumulator pumped into a phytogenic insolator producing spruce sapling or any other tree that only makes logs and sapling in the insolator. The insolator outputs into a chest which must be connected to the computer with a wired modem as well as to an AE2 network with a storage buffer. There is a sawmill to cut the logs into more planks and a multiservo press which extracts the sawdust from the sawmill compressing it into sawdust blocks with a compacting press before outputting the sawdust blocks back into the chest. Finally a stirling generator with 2 ME export nodes attached one set sawdust blocks and the other set to saplings with a redstone card installed set to active high. With the computer placed directly below the export card for saplings ensure the AE2 network has power with an energy acceptor and run the saplingOverflow.lua program on the computer. You may need to kickstart power production. 

This generator doesn't product much RF and is better used with a chunkloader and to slowly charge the contents of a power system that uses large amounts of power infrequently I use it to power stargates from the Just Stargate Mod with a chunkloader to ensure the device is fully powered or close too when I need to use it. Best to place the saplingOverflow.lua file in the startup folder of the computer incase the chunk should become unloaded and then reloaded so the computer continues execution as though it wasn't unloaded.

This has been tested with all dynamos set in config to output 400RF/t but i assume with base config and upgraded integral components the system should work on normal config

Below is screenshots of each machine and its configuration and augments

Phytogenic Insolator:
Configuration:
![image](https://github.com/user-attachments/assets/724e6dd4-bfa6-4124-b2d4-30381dc4b30b)
Augments:
![image](https://github.com/user-attachments/assets/90abcb39-3a95-4d52-b4eb-29dbd836b66d)

Sawmill:
Configuration:
![image](https://github.com/user-attachments/assets/d89c8f7d-0825-4203-a4f0-5865b893ec1d)
No Augments

Multiservo Press:
Configuration:
![image](https://github.com/user-attachments/assets/37f80f68-3009-4f24-b1df-fd9e0544d359)
No Augments

Stirling Dynamo:
Augments:
![image](https://github.com/user-attachments/assets/0a2b771e-0007-4bbf-91d9-0b4e6c037171)

Sapling Export Bus:
![image](https://github.com/user-attachments/assets/f590ae71-af31-42d8-b26f-3068522b08fa)
As can be seen a redstone card is to be installed and set to active high

Wood product Export Bus:
![image](https://github.com/user-attachments/assets/0880163e-1564-4bce-a2b8-7e7d9740945e)



