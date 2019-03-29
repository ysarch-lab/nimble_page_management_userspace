CC=gcc
launcher: launcher.c
	$(CC) -o $@ $^ -lnuma
	sudo setcap "all=ep" $@