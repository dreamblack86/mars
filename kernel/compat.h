/*
 * MARS Long Distance Replication Software
 *
 * This file is part of MARS project: http://schoebel.github.io/mars/
 *
 * Copyright (C) 2010-2014 Thomas Schoebel-Theuer
 * Copyright (C) 2011-2014 1&1 Internet AG
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef _MARS_COMPAT
#define _MARS_COMPAT

#include <linux/major.h>

/* TRANSITIONAL compatibility to BOTH the old prepatch
 * and the new wrappers around vfs_*().
 */
#ifdef MARS_MAJOR
#define MARS_HAS_PREPATCH
#else
#define MARS_MAJOR (DRBD_MAJOR + 1)
#endif

#ifdef MARS_HAS_PREPATCH

#include <linux/syscalls.h>

#else /* MARS_HAS_PREPATCH */

#include <linux/compiler.h>
#include <linux/time.h>
#include "lamport.h"

extern int _compat_symlink(
	const char __user *oldname,
	const char __user *newname,
	struct lamport_time *mtime);

extern int _compat_mkdir(
	const char __user *pathname,
	int mode);

extern int _compat_rename(
	const char __user *oldname,
	const char __user *newname);

extern int _compat_unlink(
	const char __user *pathname);

#endif /* MARS_HAS_PREPATCH */

/* Various compatibility checks for upstream kernels.
 * This is a hell.
 */

/* For bio block layer compatibility */
#include <linux/blk_types.h>
#include <linux/bio.h>

#ifdef __bvec_iter_bvec
#define MARS_HAS_BVEC_ITER
#endif

/* Detect upstream commits
 * dc3b17cc8bf21307c7e076e7c778d5db756f7871
 * d03f6cdc1fc422accb734c7c07a661a0018d8631
 * b1d2dc5659b41741f5a29b2ade76ffb4e5bb13d8
 * via 57292b58ddb58689e8c3b4c6eadbef10d9ca44dd (removal of
 * very old macro blk_account_rq())
 */
#include <linux/blkdev.h>
#ifndef blk_account_rq
#define MARS_HAS_BDI_GET
#endif
#ifdef MARS_HAS_BDI_GET
#include <linux/backing-dev.h>
#endif

/* Detect upstream commits
 * 2a842acab109f40f0d7d10b38e9ca88390628996
 * 4e4cbee93d56137ebff722be022cae5f70ef84fb
 * & neighbour commits.
 */
#ifdef BLK_STS_OK
#define MARS_HAS_BI_STATUS
#else
/* adaptation to 4246a0b63bd8f56a1469b12eafeb875b1041a451 and 8ae126660fddbeebb9251a174e6fa45b6ad8f932 */
#ifndef bio_io_error
#define MARS_HAS_BI_ERROR
#else
#define MARS_HAS_MERGE_BVEC
#endif
#endif

/* adapt to 4e1b2d52a80d79296a5d899d73249748dea71a53 and many others */
#ifdef bio_op
#define MARS_HAS_NEW_BIO_OP
#endif

#ifdef bio_end_sector
#define MARS_HAS_VOID_RELEASE
#endif

#ifdef __bvec_iter_bvec
#define MARS_HAS_BVEC_ITER
#endif

/* 54efd50bfd873e2dbf784e0b21a8027ba4299a3e and 8ae126660fddbeebb9251a174e6fa45b6ad8f932,
 * detected via 4246a0b63bd8f56a1469b12eafeb875b1041a451
 */
#ifndef BIO_UPTODATE
#define NEED_BIO_SPLIT
#endif

/* adapt to 4e1b2d52a80d79296a5d899d73249748dea71a53 and many others */
#ifdef bio_op
#define MARS_HAS_NEW_BIO_OP
#endif

/* for networking */
#include <net/sock.h>

#ifndef TCP_MAX_REORDERING
#define __HAS_IOV_ITER
#endif

/* see eeb1bd5c40edb0e2fd925c8535e2fdebdbc5cef2 */
#ifdef sk_net_refcnt
#define __HAS_STRUCT_NET
#endif

/* for crypto stuff */
#include <linux/crypto.h>

/*
 * Forced by 896545098777564212b9e91af4c973f094649aa7
 * Detected by 7b5a080b3c46f0cac71c0d0262634c6517d4ee4f
 */
#ifdef CRYPTO_ALG_TYPE_SHASH
#define MARS_HAS_NEW_CRYPTO
#endif

#endif /* _MARS_COMPAT */
