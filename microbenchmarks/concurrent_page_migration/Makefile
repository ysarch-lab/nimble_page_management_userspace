
CC=gcc

thp_move_pages: move_page_breakdown.c 
	$(CC) -o $@ $^ -lnuma
	sudo setcap "all=ep" $@

non_thp_move_pages: non_thp_move_page_breakdown.c 
	$(CC) -o $@ $^ -lnuma
	sudo setcap "all=ep" $@