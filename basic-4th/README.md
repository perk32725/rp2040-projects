**Really basic TTY**

This project strips down the basic-tty project to it's absolute basics

**Missing:**

The dump routines, the show routines, and the input routines are all in archives

**What can be done here**

Copy this directory to a project of your choice.

In main.s, you will find a call to 'productive_stuff'. When the 'something' flag is non-zero, there is a string of data from the TTY residing in inpbuffer; the current input ptr is in inpptr.

The 'something' flag, inpbuffer, and inpptr are all defined in uart0-io.s

**EOF:**
