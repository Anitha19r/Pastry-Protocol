DISTRIBUTED OPERATING SYSTEM- PASTRY PROTOCOL IMPLEMENTATION
Authors:
1)    Anitha Ranganathan - anitha19r - 76783421
2)    Sweta Thapliyal – Sthapliyal - 35436779

Requirements:
The following needs to be installed in the system:
1)    Elixir

Installation and Configuration:
1.    The mix.exs configuration.
2.    To install the project, just download the project folder ‘project3’ and then do build it using the commands:
a.    cd project3
b.    mix escript.build

Guide:
The following code takes the number of nodes and establish the a pastry network between these nodes. The network receives the message at one
client and route it to another random client.
The average hops which ideally should be made are in logarithmic values of number of nodes as per pastry.

Working: pastry protocol implementation
1. spawning nodes
2. pastry network creation
3. routing table creation
4. creation of leaf set and neighbourhood
5. message passing between the nodes
6. prints the average number of hops for request


Usage:
       ./project3 <number of nodes> <number of requests>
	Example: ./project3 1000 line 10


	   
What is the largest network we managed to deal with for each type of topology and algorithm ?:
   The largest network we were able to handle is nearly 3000 for larger network than this it will take time.
   


NUMBER OF NODES	NUMBER OF REQUESTS	AVERAGE NUMBER OF HOPS
10      	           10	                 2.5
100	                   10	                 3.32
1000	               10	                 4.98



	   