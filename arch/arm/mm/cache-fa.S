/* SPDX-License-Identifier: GPL-2.0-only */
/*
 *  linux/arch/arm/mm/cache-fa.S
 *
 *  Copyright (C) 2005 Faraday Corp.
 *  Copyright (C) 2008-2009 Paulius Zaleckas <paulius.zaleckas@teltonika.lt>
 *
 * Based on cache-v4wb.S:
 *  Copyright (C) 1997-2002 Russell king
 *
 *  Processors: FA520 FA526 FA626	
 */
#include <linux/linkage.h>
#include <linux/init.h>
#include <linux/cfi_types.h>
#include <asm/assembler.h>
#include <asm/page.h>

#include "proc-macros.S"

/*
 * The size of one data cache line.
 */
#define CACHE_DLINESIZE	16

/*
 * The total size of the data cache.
 */
#ifdef CONFIG_ARCH_GEMINI
#define CACHE_DSIZE	8192
#else
#define CACHE_DSIZE	16384 
#endif 

/* FIXME: put optimal value here. Current one is just estimation */
#define CACHE_DLIMIT	(CACHE_DSIZE * 2)

/*
 *	flush_icache_all()
 *
 *	Unconditionally clean and invalidate the entire icache.
 */
SYM_TYPED_FUNC_START(fa_flush_icache_all)
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0		@ invalidate I cache
	ret	lr
SYM_FUNC_END(fa_flush_icache_all)

/*
 *	flush_user_cache_all()
 *
 *	Clean and invalidate all cache entries in a particular address
 *	space.
 */
SYM_FUNC_ALIAS(fa_flush_user_cache_all, fa_flush_kern_cache_all)

/*
 *	flush_kern_cache_all()
 *
 *	Clean and invalidate the entire cache.
 */
SYM_TYPED_FUNC_START(fa_flush_kern_cache_all)
	mov	ip, #0
	mov	r2, #VM_EXEC
__flush_whole_cache:
	mcr	p15, 0, ip, c7, c14, 0		@ clean/invalidate D cache
	tst	r2, #VM_EXEC
	mcrne	p15, 0, ip, c7, c5, 0		@ invalidate I cache
	mcrne	p15, 0, ip, c7, c5, 6		@ invalidate BTB
	mcrne	p15, 0, ip, c7, c10, 4		@ drain write buffer
	mcrne	p15, 0, ip, c7, c5, 4		@ prefetch flush
	ret	lr
SYM_FUNC_END(fa_flush_kern_cache_all)

/*
 *	flush_user_cache_range(start, end, flags)
 *
 *	Invalidate a range of cache entries in the specified
 *	address space.
 *
 *	- start - start address (inclusive, page aligned)
 *	- end	- end address (exclusive, page aligned)
 *	- flags	- vma_area_struct flags describing address space
 */
SYM_TYPED_FUNC_START(fa_flush_user_cache_range)
	mov	ip, #0
	sub	r3, r1, r0			@ calculate total size
	cmp	r3, #CACHE_DLIMIT		@ total size >= limit?
	bhs	__flush_whole_cache		@ flush whole D cache

1:	tst	r2, #VM_EXEC
	mcrne	p15, 0, r0, c7, c5, 1		@ invalidate I line
	mcr	p15, 0, r0, c7, c14, 1		@ clean and invalidate D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
	tst	r2, #VM_EXEC
	mcrne	p15, 0, ip, c7, c5, 6		@ invalidate BTB
	mcrne	p15, 0, ip, c7, c10, 4		@ data write barrier
	mcrne	p15, 0, ip, c7, c5, 4		@ prefetch flush
	ret	lr
SYM_FUNC_END(fa_flush_user_cache_range)

/*
 *	coherent_kern_range(start, end)
 *
 *	Ensure coherency between the Icache and the Dcache in the
 *	region described by start.  If you have non-snooping
 *	Harvard caches, you need to implement this function.
 *
 *	- start  - virtual start address
 *	- end	 - virtual end address
 */
SYM_TYPED_FUNC_START(fa_coherent_kern_range)
#ifdef CONFIG_CFI_CLANG /* Fallthrough if !CFI */
	b	fa_coherent_user_range
#endif
SYM_FUNC_END(fa_coherent_kern_range)

/*
 *	coherent_user_range(start, end)
 *
 *	Ensure coherency between the Icache and the Dcache in the
 *	region described by start.  If you have non-snooping
 *	Harvard caches, you need to implement this function.
 *
 *	- start  - virtual start address
 *	- end	 - virtual end address
 */
SYM_TYPED_FUNC_START(fa_coherent_user_range)
	bic	r0, r0, #CACHE_DLINESIZE - 1
1:	mcr	p15, 0, r0, c7, c14, 1		@ clean and invalidate D entry
	mcr	p15, 0, r0, c7, c5, 1		@ invalidate I entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 6		@ invalidate BTB
	mcr	p15, 0, r0, c7, c10, 4		@ drain write buffer
	mcr	p15, 0, r0, c7, c5, 4		@ prefetch flush
	ret	lr
SYM_FUNC_END(fa_coherent_user_range)

/*
 *	flush_kern_dcache_area(void *addr, size_t size)
 *
 *	Ensure that the data held in the page kaddr is written back
 *	to the page in question.
 *
 *	- addr	- kernel address
 *	- size	- size of region
 */
SYM_TYPED_FUNC_START(fa_flush_kern_dcache_area)
	add	r1, r0, r1
1:	mcr	p15, 0, r0, c7, c14, 1		@ clean & invalidate D line
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0		@ invalidate I cache
	mcr	p15, 0, r0, c7, c10, 4		@ drain write buffer
	ret	lr
SYM_FUNC_END(fa_flush_kern_dcache_area)

/*
 *	dma_inv_range(start, end)
 *
 *	Invalidate (discard) the specified virtual address range.
 *	May not write back any entries.  If 'start' or 'end'
 *	are not cache line aligned, those lines must be written
 *	back.
 *
 *	- start  - virtual start address
 *	- end	 - virtual end address
 */
fa_dma_inv_range:
	tst	r0, #CACHE_DLINESIZE - 1
	bic	r0, r0, #CACHE_DLINESIZE - 1
	mcrne	p15, 0, r0, c7, c14, 1		@ clean & invalidate D entry
	tst	r1, #CACHE_DLINESIZE - 1
	bic	r1, r1, #CACHE_DLINESIZE - 1
	mcrne	p15, 0, r1, c7, c14, 1		@ clean & invalidate D entry
1:	mcr	p15, 0, r0, c7, c6, 1		@ invalidate D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
	mov	r0, #0
	mcr	p15, 0, r0, c7, c10, 4		@ drain write buffer
	ret	lr

/*
 *	dma_clean_range(start, end)
 *
 *	Clean (write back) the specified virtual address range.
 *
 *	- start  - virtual start address
 *	- end	 - virtual end address
 */
fa_dma_clean_range:
	bic	r0, r0, #CACHE_DLINESIZE - 1
1:	mcr	p15, 0, r0, c7, c10, 1		@ clean D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
	mov	r0, #0	
	mcr	p15, 0, r0, c7, c10, 4		@ drain write buffer
	ret	lr

/*
 *	dma_flush_range(start,end)
 *	- start   - virtual start address of region
 *	- end     - virtual end address of region
 */
SYM_TYPED_FUNC_START(fa_dma_flush_range)
	bic	r0, r0, #CACHE_DLINESIZE - 1
1:	mcr	p15, 0, r0, c7, c14, 1		@ clean & invalidate D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
	mov	r0, #0	
	mcr	p15, 0, r0, c7, c10, 4		@ drain write buffer
	ret	lr
SYM_FUNC_END(fa_dma_flush_range)

/*
 *	dma_map_area(start, size, dir)
 *	- start	- kernel virtual start address
 *	- size	- size of region
 *	- dir	- DMA direction
 */
SYM_TYPED_FUNC_START(fa_dma_map_area)
	add	r1, r1, r0
	cmp	r2, #DMA_TO_DEVICE
	beq	fa_dma_clean_range
	bcs	fa_dma_inv_range
	b	fa_dma_flush_range
SYM_FUNC_END(fa_dma_map_area)

/*
 *	dma_unmap_area(start, size, dir)
 *	- start	- kernel virtual start address
 *	- size	- size of region
 *	- dir	- DMA direction
 */
SYM_TYPED_FUNC_START(fa_dma_unmap_area)
	ret	lr
SYM_FUNC_END(fa_dma_unmap_area)
