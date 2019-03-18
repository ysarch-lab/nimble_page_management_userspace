/*
 * Test program to test the moving of a processes pages.
 *
 * From:
 * http://numactl.sourcearchive.com/documentation/2.0.2/migrate__pages_8c-source.html
 *
 * (C) 2006 Silicon Graphics, Inc.
 *          Christoph Lameter <clameter@sgi.com>
 */
#include <stdio.h>
#include <stdlib.h>
#include "numa.h"
#include <unistd.h>
#include <errno.h>
#include <inttypes.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <numaif.h>


unsigned int pagesize;
unsigned int page_count = 32;

char *from_page_base;
char *to_page_base;
char *from_pages;
char *to_pages;

void **from_addr;
void **to_addr;
int *status;
int *nodes;
int errors;
int nr_nodes;

struct bitmask *old_nodes;
struct bitmask *new_nodes;

#define PAGE_4K (4UL*1024)
#define PAGE_2M (PAGE_4K*512)
/*#define PAGE_1G (PAGE_2M*512)*/
#define PAGE_1G (128*1024*1024)

#define PRESENT_MASK (1UL<<63)
#define SWAPPED_MASK (1UL<<62)
#define PAGE_TYPE_MASK (1UL<<61)
#define PFN_MASK     ((1UL<<55)-1)

#define KPF_THP      (1UL<<22)

void print_paddr_and_flags(char *bigmem, int pagemap_file, int kpageflags_file)
{
	uint64_t paddr;
	uint64_t page_flags;

	if (pagemap_file) {
		pread(pagemap_file, &paddr, sizeof(paddr), ((long)bigmem>>12)*sizeof(paddr));


		if (kpageflags_file) {
			pread(kpageflags_file, &page_flags, sizeof(page_flags), 
				  (paddr & PFN_MASK)*sizeof(page_flags));

			fprintf(stderr, "vpn: 0x%lx, pfn: 0x%lx is %s %s, %s, %s\n",
					   ((long)bigmem)>>12,
					   (paddr & PFN_MASK),
					   paddr & PAGE_TYPE_MASK ? "file-page" : "anon",
					   paddr & PRESENT_MASK ? "there": "not there",
					   paddr & SWAPPED_MASK ? "swapped": "not swapped",
					   page_flags & KPF_THP ? "thp" : "not thp"
					   /*page_flags*/
					   );

		}
	}



}


int main(int argc, char **argv)
{
      int i, rc;
	unsigned long begin = 0, end = 0;
	unsigned cycles_high, cycles_low;
	unsigned cycles_high1, cycles_low1;
	const char *move_pages_stats = "/proc/%d/move_pages_breakdown";
	const char *pagemap_template = "/proc/%d/pagemap";
	const char *kpageflags_proc = "/proc/kpageflags";
	char move_pages_stats_proc[255];
	char pagemap_proc[255];
	char stats_buffer[1024] = {0};
	char transfer_method[255] = {0};
	char batch_mode[255] = {0};
	int stats_fd;
	int pagemap_fd;
	int kpageflags_fd;
	int move_page_flag = 0;
	unsigned long node0 = 1<<0;
	unsigned long node1 = 1<<1;

      /*pagesize = getpagesize();*/
	  pagesize = PAGE_4K;

      nr_nodes = numa_max_node()+1;

      old_nodes = numa_bitmask_alloc(nr_nodes);
        new_nodes = numa_bitmask_alloc(nr_nodes);
        numa_bitmask_setbit(old_nodes, 1);
        numa_bitmask_setbit(new_nodes, 0);

      if (nr_nodes < 2) {
            printf("A minimum of 2 nodes is required for this test.\n");
            exit(1);
      }

      setbuf(stdout, NULL);
      printf("migrate_pages() test ......\n");
      if (argc > 1)
            sscanf(argv[1], "%d", &page_count);
	  if (argc > 2)
			sscanf(argv[2], "%s", transfer_method);
	  if (argc > 3)
			sscanf(argv[3], "%s", batch_mode);

	if (strncmp(transfer_method, "dma", 3) == 0) {
		printf("-----Using DMA-----\n");
	}
	if (strncmp(transfer_method, "mt", 2) == 0) {
		printf("-----Using Multi Threads-----\n");
	}
	if (strncmp(batch_mode, "batch", 5) == 0) {
		printf("-----Using Batch Mode-----\n");
	}

	/* from pages  */
	  from_page_base = aligned_alloc(pagesize, pagesize*page_count);
      from_addr = malloc(sizeof(char *) * page_count);
      status = malloc(sizeof(int *) * page_count);
      if (!from_page_base || !from_addr || !status) {
            printf("Unable to allocate memory\n");
            exit(1);
      }

	  madvise(from_page_base, pagesize*page_count, MADV_NOHUGEPAGE);
	  mbind(from_page_base, pagesize*page_count, MPOL_BIND, &node0, sizeof(node0)*8, 0);

	  from_pages = from_page_base;

      for (i = 0; i < page_count; i++) {
            from_pages[ i * pagesize] = (char) i;
            from_addr[i] = from_pages + i * pagesize;
            status[i] = -123;
      }

	  /* to pages  */
	  to_page_base = aligned_alloc(pagesize, pagesize*page_count);
      to_addr = malloc(sizeof(char *) * page_count);
      if (!to_page_base || !to_addr) {
            printf("Unable to allocate memory\n");
            exit(1);
      }

	  madvise(to_page_base, pagesize*page_count, MADV_NOHUGEPAGE);
	  mbind(to_page_base, pagesize*page_count, MPOL_BIND, &node1, sizeof(node1)*8, 0);
      /*pages = (void *) ((((long)page_base) & ~((long)(pagesize - 1))) + pagesize);*/

	  to_pages = to_page_base;

      for (i = 0; i < page_count; i++) {
            to_pages[ i * pagesize] = (char) (i+1);
            to_addr[i] = to_pages + i * pagesize;
      }

	sprintf(pagemap_proc, pagemap_template, getpid());
	pagemap_fd = open(pagemap_proc, O_RDONLY);

	if (pagemap_fd == -1)
	{
		perror("read pagemap:");
		exit(-1);
	}

	kpageflags_fd = open(kpageflags_proc, O_RDONLY);

	if (kpageflags_fd == -1)
	{
		perror("read kpageflags:");
		exit(-1);
	}

	printf("----------From Pages------------\n");
	for (i = 0; i < page_count; ++i) {
		print_paddr_and_flags(from_pages+pagesize*i, pagemap_fd, kpageflags_fd);
	}
	printf("----------To Pages------------\n");
	for (i = 0; i < page_count; ++i) {
		print_paddr_and_flags(to_pages+pagesize*i, pagemap_fd, kpageflags_fd);
	}

	sprintf(move_pages_stats_proc, move_pages_stats, getpid());
	stats_fd = open(move_pages_stats_proc, O_RDONLY);

	if (stats_fd == -1)
	{
		perror("read stats:");
		exit(-1);
	}

	asm volatile
	( "CPUID\n\t"
	  "RDTSC\n\t"
	  "mov %%edx, %0\n\t"
	  "mov %%eax, %1\n\t"
	  :
	  "=r" (cycles_high), "=r" (cycles_low)
	  ::
	  "rax", "rbx", "rcx", "rdx"
	);
	begin = ((uint64_t)cycles_high <<32 | cycles_low);

      /* Move to starting node */
	if (strncmp(transfer_method, "mt", 2) == 0)
		move_page_flag |= (1<<6);

	if (strncmp(batch_mode, "batch", 5) == 0)
		move_page_flag |= (1<<7);

	  /*rc = numa_move_pages(0, page_count, addr, nodes, status, move_page_flag);*/
	rc = syscall(333,0, page_count, from_addr, to_addr, status, move_page_flag);

      if (rc < 0 && errno != ENOENT) {
		  printf("errno: %d\n", rc);
            perror("move_pages");
            exit(1);
      }
	asm volatile
	( "RDTSCP\n\t"
	  "mov %%edx, %0\n\t"
	  "mov %%eax, %1\n\t"
	  "CPUID\n\t"
	  :
	  "=r" (cycles_high1), "=r" (cycles_low1)
	  ::
	  "rax", "rbx", "rcx", "rdx"
	);

	end = ((uint64_t)cycles_high1 <<32 | cycles_low1);

	printf("+++++After Exchange+++++\n");

	pread(stats_fd, stats_buffer, sizeof(stats_buffer), 0);


	printf("Total_cycles\tBegin_timestamp\tEnd_timestamp\n"
		   "%llu\t%llu\t%llu\n",
		   (end-begin), begin, end);
	printf("%s", stats_buffer);


      /* Verify correct startup locations */
	printf("----------From Pages2------------\n");
	for (i = 0; i < page_count; ++i) {
		print_paddr_and_flags(from_pages+pagesize*i, pagemap_fd, kpageflags_fd);
	}
	printf("----------To Pages2------------\n");
	for (i = 0; i < page_count; ++i) {
		print_paddr_and_flags(to_pages+pagesize*i, pagemap_fd, kpageflags_fd);
	}

      for (i = 0; i < page_count; i++) {
			  if (from_pages[ i* pagesize ] != (char) i) {
					fprintf(stderr, "*** From Page contents corrupted. expected: %d, got: %d\n", (char)i,from_pages[i*pagesize]);
					errors++;
			  } 
	  }
      for (i = 0; i < page_count; i++) {
			  if (to_pages[ i* pagesize ] != (char) (i+1)) {
					fprintf(stderr, "*** To Page contents corrupted. expected: %d, got: %d\n", (char)(i+1), to_pages[i*pagesize]);
					errors++;
			  } 
	  }

      if (!errors)
            printf("Test successful.\n");
      else
            fprintf(stderr, "%d errors.\n", errors);

	close(stats_fd);

	return errors > 0 ? 1 : 0;
}
