/*
 * Copyright (c) Damien Miller <djm@mindrot.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* $Id: cfsm.h,v 1.3 2007/04/15 12:24:42 djm Exp $ */

#ifndef _CFSM_H
#define _CFSM_H

/* XXX */
#define TEMPLATE_C_SOURCE	"source.x"
#define TEMPLATE_C_HEADER	"header.x"
#define TEMPLATE_GRAPHVIZ	"graphviz.x"

/* Default output file names */
#define DEFAULT_OUT_DOT		"fsm.dot"
#define DEFAULT_OUT_C_SRC	"fsm.c"
#define DEFAULT_OUT_C_HDR	"fsm.h"

/* Default variable and function names, etc. */
#define DEFAULT_HEADER		"fsm.h"
#define DEFAULT_HEADER_GUARD	"_FSM_H"
#define DEFAULT_EVENT_ENUM	"fsm_event"
#define DEFAULT_STATE_ENUM	"fsm_state"
#define DEFAULT_FSM_STRUCT	"fsm"
#define DEFAULT_INIT_FUNC	"fsm_init"
#define DEFAULT_FREE_FUNC	"fsm_free"
#define DEFAULT_ADVANCE_FUNC	"fsm_advance"
#define DEFAULT_STATE_NTOP_FUNC	"fsm_state_ntop"
#define DEFAULT_EVENT_NTOP_FUNC	"fsm_event_ntop"

#endif /* _CFSM_H */
