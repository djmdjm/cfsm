/*
 * Copyright (c) 2007 Damien Miller <djm@mindrot.org>
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

/* $Id: cfsm_parse.y,v 1.14 2007/11/18 09:51:19 djm Exp $ */

%{
#include <sys/types.h>
#include <sys/param.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>
#include <err.h>

#include "mobject.h"
#include "strlcat.h"

#include "cfsm.h"

extern char *yytext;

/* Local prototypes */
int yyparse(void);
void yyerror(const char *, ...);
static const char *gen_cb_args(u_int);
static const char *gen_cb_args_proto(u_int);
static struct mobject *get_or_create_event(char *);
static int create_action(char *, const char *, const char *, struct mobject *,
    const char *, struct mobject *);
void finalise_namespace(void);
void setup_initial_namespace(void);

/* From cfsm_lex.l */
extern int yylex(void);

/* From cfsm.c */
extern const char *in_path;
extern char *header_name;

/* Local variables */

/* Line number in input file */
u_int lnum = 0;

/*
 * The representation of the FSM that is built during parsing and
 * subsequently used to fill in the template
 */
struct mobject *fsm_namespace = NULL;

/* Convenience pointers to commonly-used objects in the namespace */
static struct mobject *fsm_initial_states = NULL;
static struct mobject *fsm_states_array = NULL;
static struct mobject *fsm_events_array = NULL;
static struct mobject *fsm_states = NULL;
static struct mobject *fsm_events = NULL;
static struct mobject *fsm_event_callbacks = NULL;
static struct mobject *fsm_event_preconds = NULL;
static struct mobject *fsm_trans_entry_callbacks = NULL;
static struct mobject *fsm_trans_entry_preconds = NULL;
static struct mobject *fsm_trans_exit_callbacks = NULL;
static struct mobject *fsm_trans_exit_preconds = NULL;

/* Pointers to active event or state */
static struct mobject *current_state;
static struct mobject *current_event;

/* Temporary buffer to accumulate source-banner */
static size_t banner_len = 0;
static char *banner = NULL;

/* Bitfields for arguments to provide to callback functions */
u_int trans_callback_args = 0;
u_int event_callback_args = 0;
u_int trans_precond_args = 0;
u_int event_precond_args = 0;

u_int event_specified = 0;

#define CB_ARG_CTX		(1)
#define CB_ARG_EVENT		(1<<1)
#define CB_ARG_NEW_STATE	(1<<2)
#define CB_ARG_OLD_STATE	(1<<3)

%}

%token CTX EVENT NEW_STATE OLD_STATE NONE
%token COMMA MOVETO BANNER_START BANNER_END
%token ADVANCE_FUNC CURRENT_STATE_FUNC TRANSITION_ENTRY_PRECOND
%token EVENT_CALLBACK_ARGS EVENT_CALLBACK EVENT_NTOP_FUNC EVENT_ENUM
%token EVENT_PRECOND_ARGS EVENT_PRECOND TRANSITION_EXIT_PRECOND
%token FREE_FUNC FSM_STRUCT IGNORE_EVENT INIT_FUNC INITIAL_STATE
%token NEXT_STATE TRANSITION_ENTRY_CALLBACK
%token EVENT_ADVANCE TRANSITION_EXIT_CALLBACK TRANSITION_PRECOND_ARGS
%token SOURCE_BANNER_START SOURCE_BANNER_END STATE_NTOP_FUNC STATE_ENUM STATE 
%token TRANSITION_CALLBACK_ARGS
%token <string> ID BANNER_LINE NUMBER

%type <n> callback_arg callback_arglist callback_args number

%union {
	char *string;
	u_int n;
};

%%

directives:		| directives directive
	;

directive:		type_def | func_def | func_arg_def | 
			state_def | event_def | banner
	;

type_def:		state_enum_def | event_enum_def | fsm_struct_def
	;

func_def:		current_state_func_def | init_func_def |
			free_func_def | advance_func_def |
			state_ntop_func_def | event_ntop_func_def
	;

func_arg_def:		event_precond_arg_def | trans_precond_arg_def |
			event_callback_arg_def | trans_callback_arg_def
	;

state_def:		state_decl | initial_state_def | on_event_def |
			ignore_event_def  |
			entry_callback_def | exit_callback_def |
			entry_precond_def | exit_precond_def
	;

event_def:		event_decl | event_callback_def | event_precond_def
	;

banner:			banner_start banner_lines banner_end
	;

state_enum_def:		STATE_ENUM ID {
		if (mdict_replace_ss(fsm_namespace, "state_enum", $2) == NULL)
			errx(1, "state_enum_def: mdict_replace_ss");
		free($2);
	}
	;

event_enum_def:		EVENT_ENUM ID {
		if (mdict_replace_ss(fsm_namespace, "event_enum", $2) == NULL)
			errx(1, "event_enum_def: mdict_replace_ss");
		free($2);
	}
	;

fsm_struct_def:		FSM_STRUCT ID {
		if (mdict_replace_ss(fsm_namespace, "fsm_struct", $2) == NULL)
			errx(1, "fsm_struct_def: mdict_replace_ss");
	}
	;

current_state_func_def:	CURRENT_STATE_FUNC ID {
		if (mdict_replace_ss(fsm_namespace, "current_state_func",
		    $2) == NULL)
			errx(1, "current_state_func_def: mdict_replace_ss");
		free($2);
	}
	;

init_func_def:		INIT_FUNC ID {
		if (mdict_replace_ss(fsm_namespace, "init_func", $2) == NULL)
			errx(1, "init_func_def: mdict_replace_ss");
		free($2);
	}
	;

free_func_def:		FREE_FUNC ID {
		if (mdict_replace_ss(fsm_namespace, "free_func", $2) == NULL)
			errx(1, "free_func_def: mdict_replace_ss");
		free($2);
	}
	;

advance_func_def:	ADVANCE_FUNC ID {
		if (mdict_replace_ss(fsm_namespace, "advance_func", $2) == NULL)
			errx(1, "advance_func_def: mdict_replace_ss");
		free($2);
	}
	;

state_ntop_func_def:	STATE_NTOP_FUNC ID {
		if (mdict_replace_ss(fsm_namespace, "state_ntop_func",
		    $2) == NULL)
			errx(1, "state_ntop_func_def: mdict_replace_ss");
		free($2);
	}
	;

event_ntop_func_def:	EVENT_NTOP_FUNC ID {
		if (mdict_replace_ss(fsm_namespace, "event_ntop_func",
		    $2) == NULL)
			errx(1, "event_ntop_func_def: mdict_replace_ss");
		free($2);
	}
	;

callback_arg:		EVENT		{ $$ = CB_ARG_EVENT; }
			| NEW_STATE	{ $$ = CB_ARG_NEW_STATE; }
			| OLD_STATE	{ $$ = CB_ARG_OLD_STATE; }
			| CTX {
		$$ = CB_ARG_CTX;
		if (mdict_replace_si(fsm_namespace, "need_ctx", 1) == NULL)
			errx(1, "ctx: mdict_replace_si failed");
	}
	;

callback_arglist:	callback_arg |
			callback_arglist COMMA callback_arg { $$ = $1 | $3; }
	;

callback_args:		NONE 		{ $$ = 0; }
			| callback_arglist
	;

event_precond_arg_def:	EVENT_PRECOND_ARGS callback_args {
		event_precond_args = $2;
	}
	;

trans_precond_arg_def:	TRANSITION_PRECOND_ARGS callback_args {
		trans_precond_args = $2;
	}
	;

event_callback_arg_def:	EVENT_CALLBACK_ARGS callback_args {
		event_callback_args = $2;
	}
	;

trans_callback_arg_def:	TRANSITION_CALLBACK_ARGS callback_args {
		trans_callback_args = $2;
	}
	;

state_decl:		STATE ID {
		current_event = NULL;
		current_state = mdict_insert_sd(fsm_states, $2);
		if (current_state == NULL) {
			yyerror("state \"%s\" already defined", $2);
			free($2);
			YYERROR;
		}
		if (mdict_insert_ss(current_state, "name", $2) == NULL ||
		    mdict_insert_sd(current_state, "events") == NULL ||
		    mdict_insert_sd(current_state, "next_states") == NULL ||
		    mdict_insert_sd(current_state, "exit_preconds") == NULL ||
		    mdict_insert_sd(current_state, "entry_preconds") == NULL ||
		    mdict_insert_sd(current_state, "exit_callbacks") == NULL ||
		    mdict_insert_sd(current_state, "entry_callbacks") == NULL ||
		    mdict_insert_si(current_state, "is_initial", 0) == NULL ||
		    mdict_insert_si(current_state, "indegree", 0) == NULL ||
		    marray_append_s(fsm_states_array, $2) == NULL)
			errx(1, "state_decl: set up state failed");
		free($2);
	}
	;

initial_state_def:	INITIAL_STATE {
		struct mobject *i;

		if (current_state == NULL) {
			yyerror("\"initial-state\" outside state block");
			YYERROR;
		}
		if ((i = mdict_item_s(current_state, "is_initial")) == NULL)
			errx(1, "initial_state_def: state lacks is_initial");
		if (mint_value(i) != 0) {
			yyerror("\"initial-state\" already set for this state");
			YYERROR;
		}
		if (mdict_replace_si(current_state, "is_initial", 1) == NULL)
			errx(1, "initial_state_def: mdict_replace_si failed");
		if ((i = mdict_item_s(current_state, "name")) == NULL)
			errx(1, "initial_state_def: state lacks name");
		if ((i = mobject_deepcopy(i)) == NULL)
			errx(1, "initial_state_def: mobject_deepcopy");
		if (marray_append(fsm_initial_states, i) == -1)
			errx(1, "initial_state_def: marray_append");
	}
	;

on_event_def:		EVENT_ADVANCE ID MOVETO ID {
		struct mobject *events, *next_states;

		if (current_state == NULL) {
			yyerror("\"on-event\" outside state block");
			free($2);
			free($4);
			YYERROR;
		}
		if (get_or_create_event($2) == NULL) {
			free($2);
			free($4);
			YYERROR;
		}
		if ((events = mdict_item_s(current_state, "events")) == NULL)
			errx(1, "on_event_def: state lacks events");
		if (mdict_replace_ss(events, $2, $4) == NULL)
			errx(1, "on_event_def: mdict_replace_ss failed");

		if ((next_states = mdict_item_s(current_state,
		    "next_states")) == NULL)
			errx(1, "on_event_def: state lacks next_states");
		if (mdict_replace_si(next_states, $4, 1) == NULL)
			errx(1, "on_event_def: mdict_replace_si failed");

		free($2);
		free($4);
	}
	;

ignore_event_def:	IGNORE_EVENT ID {
		struct mobject *events;

		if (current_state == NULL) {
			yyerror("\"ignore-event\" outside state block");
			free($2);
			YYERROR;
		}
		if (get_or_create_event($2) == NULL) {
			free($2);
			YYERROR;
		}
		if ((events = mdict_item_s(current_state, "events")) == NULL)
			errx(1, "on_event_def: state lacks events");
		if (mdict_replace_sn(events, $2) == NULL)
			errx(1, "on_event_def: mdict_replace_sn failed");
		free($2);
	}
	;

entry_callback_def:	TRANSITION_ENTRY_CALLBACK ID {
		if (create_action($2, "onentry-func", "state", current_state,
		    "entry_callbacks", fsm_trans_entry_callbacks) == -1) {
			free($2);
			YYERROR;
		}
		free($2);
	}
	;

exit_callback_def:	TRANSITION_EXIT_CALLBACK ID {
		if (create_action($2, "onexit-func", "state", current_state,
		    "exit_callbacks", fsm_trans_exit_callbacks) == -1) {
			free($2);
			YYERROR;
		}
		free($2);
	}
	;

entry_precond_def:	TRANSITION_ENTRY_PRECOND ID {
		if (create_action($2, "entry-precondition", "state",
		    current_state, "entry_preconds", 
		    fsm_trans_entry_preconds) == -1) {
			free($2);
			YYERROR;
		}
		free($2);
	}
	;

exit_precond_def:	TRANSITION_EXIT_PRECOND ID {
		if (create_action($2, "exit-precondition", "state",
		    current_state, "exit_preconds", 
		    fsm_trans_exit_preconds) == -1) {
			free($2);
			YYERROR;
		}
		free($2);
	}
	;

event_decl:		EVENT ID {
		current_state = NULL;
		if ((current_event = get_or_create_event($2)) == NULL) {
			free($2);
			YYERROR;
		}
		free($2);
	}
	;

event_callback_def:	EVENT_CALLBACK ID {
		if (create_action($2, "event-callback", "event", current_event,
		    "callbacks", fsm_event_callbacks) == -1) {
			free($2);
			YYERROR;
		}
		free($2);
	}
	;

event_precond_def:	EVENT_PRECOND ID {
		if (create_action($2, "event-precondition", "event",
		    current_event, "preconds", fsm_event_preconds) == -1) {
			free($2);
			YYERROR;
		}
		free($2);
	}
	;

banner_start:		BANNER_START
	;

banner_lines:		| banner_lines banner_line
	;

banner_line:		BANNER_LINE {
		size_t llen = strlen($1);

		if ((banner = realloc(banner, banner_len + llen + 1)) == NULL)
			errx(1, "realloc(banner, %zu) failed",
			    banner_len + llen + 1);
		memcpy(banner + banner_len, $1, llen + 1);
		banner_len += llen;
		free($1);
	}
	;

banner_end:		BANNER_END {
		if (mdict_replace_ss(fsm_namespace, "source_banner",
		    banner) == NULL)
			errx(1, "mdict_replace_ss failed");
		free(banner);
		banner = NULL;
		banner_len = 0;
	}
	;
number:			NUMBER {
		u_long n;
		char *ep;

		errno = 0;
		n = strtoul($1, &ep, 0);
		if (*$1 == '\0' || *ep != '\0') {
			yyerror("argument \"%s\" is not a valid number", $1);
			free($1);
			YYERROR;
		}
		if ((errno == ERANGE && n == ULONG_MAX) || n > 0xffffffff) {
			yyerror("numeric argument out of range", $1);
			free($1);
			YYERROR;
		}
		$$ = n;
		free($1);
	}
	;
%%

void
yyerror(const char *fmt, ...)
{
	char fmtbuf[255];
	va_list args;

	snprintf(fmtbuf, sizeof(fmtbuf), "%s:%u %s near \"%s\"\n",
	    in_path, lnum, fmt, yytext);
	va_start(args, fmt);
	vfprintf(stderr, fmtbuf, args);
	va_end(args);
}

static void
commacat(char *dst, const char *src, size_t len)
{
	if (*dst != '\0')
		strlcat(dst, ", ", len);
	strlcat(dst, src, len);
}

static const char *
gen_cb_args(u_int argdef)
{
	static char buf[256];

	if (argdef == 0)
		return "";
	*buf = '\0';
	if ((argdef & CB_ARG_EVENT) != 0)
		commacat(buf, "ev", sizeof(buf));
	if ((argdef & CB_ARG_OLD_STATE) != 0)
		commacat(buf, "old_state", sizeof(buf));
	if ((argdef & CB_ARG_NEW_STATE) != 0)
		commacat(buf, "new_state", sizeof(buf));
	if ((argdef & CB_ARG_CTX) != 0)
		commacat(buf, "ctx", sizeof(buf));

	return buf;
}

static const char *
gen_cb_args_proto(u_int argdef)
{
	static char buf[512];
	const char *state_enum, *event_enum;
	struct mobject *tmp;

	if ((tmp = mdict_item_s(fsm_namespace, "state_enum")) == NULL ||
	    (state_enum = mstring_ptr(tmp)) == NULL ||
	    (tmp = mdict_item_s(fsm_namespace, "event_enum")) == NULL ||
	    (event_enum = mstring_ptr(tmp)) == NULL)
		errx(1, "Unable to retrieve event/state enum def");

	if (argdef == 0)
		return "";
	*buf = '\0';
	if ((argdef & CB_ARG_EVENT) != 0) {
		commacat(buf, "enum ", sizeof(buf));
		strlcat(buf, event_enum, sizeof(buf));
		strlcat(buf, " ev", sizeof(buf));
	}
	if ((argdef & CB_ARG_OLD_STATE) != 0) {
		commacat(buf, "enum ", sizeof(buf));
		strlcat(buf, state_enum, sizeof(buf));
		strlcat(buf, " old_state", sizeof(buf));
	}
	if ((argdef & CB_ARG_NEW_STATE) != 0) {
		commacat(buf, "enum ", sizeof(buf));
		strlcat(buf, state_enum, sizeof(buf));
		strlcat(buf, " new_state", sizeof(buf));
	}
	if ((argdef & CB_ARG_CTX) != 0)
		commacat(buf, "void *ctx", sizeof(buf));
	return buf;
}

static struct mobject *
get_or_create_event(char *name)
{
	struct mobject *ret;

	event_specified = 1;

	ret = mdict_item_s(fsm_events, name);
	if (ret == NULL) {
		if (mdict_insert_sd(fsm_events, name) == NULL)
			errx(1, "%s: mdict_item_s failed", __func__);
		if ((ret = mdict_item_s(fsm_events, name)) == NULL)
			errx(1, "%s: mdict_item_s failed", __func__);
		if (mdict_insert_sd(ret, "preconds") == NULL ||
		    mdict_insert_sd(ret, "callbacks") == NULL)
			errx(1, "%s: set up event failed", __func__);
		if (marray_append_s(fsm_events_array, name) == NULL)
			errx(1, "%s: marray_append_s failed", __func__);
	}
	return ret;
}

static int
create_action(char *name, const char *context, const char *block,
    struct mobject *parent, const char *member, struct mobject *main_list)
{
	struct mobject *l;

	if (parent == NULL) {
		yyerror("\"%s\" outside %s block", context, block);
		return -1;
	}
	if ((l = mdict_item_s(parent, member)) == NULL)
		errx(1, "%s(%s): %s lacks %s", __func__, context,
		    block, member);
	if (mdict_replace_si(l, name, 1) == NULL)
		errx(1, "%s(%s): mdict_replace_si(%p, %s, 1) failed",
		    __func__, context, l, name);
	if (mdict_replace_si(main_list, name, 1) == NULL)
		errx(1, "%s(%s): mdict_replace_si(%p, %s, 1) failed",
		    __func__, context, main_list, name);
	return 0;
}

void
setup_initial_namespace(void)
{
	u_int i;
	char *guard;

#define DEF_STRING(k, v) do { \
		if (mdict_insert_ss(fsm_namespace, k, v) == NULL) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_DICT(k) do { \
		if (mdict_insert_sd(fsm_namespace, k) == NULL) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_ARRAY(k) do { \
		if (mdict_insert_sa(fsm_namespace, k) == NULL) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_GET(o, k) do { \
		if ((o = mdict_item_s(fsm_namespace, k)) == NULL) \
			errx(1, "Lookup for default \"%s\" failed", k); \
	} while (0)

	if ((fsm_namespace = mdict_new()) == NULL)
		errx(1, "%s(%d): mdict_new failed", __func__, __LINE__);

	/* Set our defaults */
	DEF_STRING("source_banner", "");
	DEF_STRING("event_enum", DEFAULT_EVENT_ENUM);
	DEF_STRING("state_enum", DEFAULT_STATE_ENUM);
	DEF_STRING("fsm_struct", DEFAULT_FSM_STRUCT);
	DEF_STRING("init_func", DEFAULT_INIT_FUNC);
	DEF_STRING("free_func", DEFAULT_FREE_FUNC);
	DEF_STRING("advance_func", DEFAULT_ADVANCE_FUNC);
	DEF_STRING("state_ntop_func", DEFAULT_STATE_NTOP_FUNC);
	DEF_STRING("event_ntop_func", DEFAULT_EVENT_NTOP_FUNC);
	DEF_STRING("current_state_func", DEFAULT_CURRENT_STATE_FUNC);

	DEF_STRING("event_precond_args", "");
	DEF_STRING("event_precond_args_proto", "void");
	DEF_STRING("trans_precond_args", "");
	DEF_STRING("trans_precond_args_proto", "void");
	DEF_STRING("event_cb_args", "");
	DEF_STRING("event_cb_args_proto", "void");
	DEF_STRING("trans_cb_args", "");
	DEF_STRING("trans_cb_args_proto", "void");

	DEF_ARRAY("events_array");
	DEF_ARRAY("states_array");
	DEF_ARRAY("initial_states");
	DEF_DICT("states");
	DEF_DICT("events");
	DEF_DICT("event_callbacks");
	DEF_DICT("event_preconds");
	DEF_DICT("transition_entry_callbacks");
	DEF_DICT("transition_exit_callbacks");
	DEF_DICT("transition_entry_preconds");
	DEF_DICT("transition_exit_preconds");

	DEF_GET(fsm_states_array, "states_array");
	DEF_GET(fsm_events_array, "events_array");
	DEF_GET(fsm_initial_states, "initial_states");
	DEF_GET(fsm_states, "states");
	DEF_GET(fsm_events, "events");
	DEF_GET(fsm_event_callbacks, "event_callbacks");
	DEF_GET(fsm_event_preconds, "event_preconds");
	DEF_GET(fsm_trans_entry_callbacks, "transition_entry_callbacks");
	DEF_GET(fsm_trans_entry_preconds, "transition_entry_preconds");
	DEF_GET(fsm_trans_exit_callbacks, "transition_exit_callbacks");
	DEF_GET(fsm_trans_exit_preconds, "transition_exit_preconds");

	if (mdict_insert_si(fsm_namespace, "need_ctx", 0) == NULL)
		errx(1, "Default set for \"need_ctx\" failed");

	if (header_name == NULL) {
		DEF_STRING("header_guard", DEFAULT_HEADER_GUARD);
		DEF_STRING("header_name", DEFAULT_HEADER);
	} else {
		if ((guard = malloc(strlen(header_name) + 2)) == NULL)
			errx(1, "malloc failed");
		guard[0] = '_';
		for (i = 0; header_name[i] != '\0'; i++) {
			if (isalnum(header_name[i]))
				guard[i + 1] = toupper(header_name[i]);
			else
				guard[i + 1] = '_';
		}
		guard[i + 1] = '\0';
		DEF_STRING("header_name", header_name);
		DEF_STRING("header_guard", guard);
		free(guard);
	}
}

void
finalise_namespace(void)
{
	size_t n;
	struct mobject *tmp;
	struct miterator *siter, *niter;
	struct miteritem *sitem, *nitem;
	const char *state, *next_state;
	int64_t indegree;

	/* Make sure we have at least two states */
	if ((n = marray_len(fsm_states_array)) == 0)
		errx(1, "No states defined");
	if (n == 1)
		errx(1, "Only one state defined");

	if (!event_specified)
		errx(1, "No events specified");

	/* Set min and max valid states */
	if ((tmp = marray_item(fsm_states_array, 0)) == NULL)
		errx(1, "%s(%d): marray_item", __func__, __LINE__);
	if ((tmp = mobject_deepcopy(tmp)) == NULL)
		errx(1, "%s(%d): mobject_deepcopy", __func__, __LINE__);
	if (mdict_insert_s(fsm_namespace, "min_state_valid", tmp) == NULL)
		errx(1, "%s(%d): mdict_insert_s", __func__, __LINE__);
	if ((tmp = marray_item(fsm_states_array, n - 1)) == NULL)
		errx(1, "%s(%d): marray_item", __func__, __LINE__);
	if ((tmp = mobject_deepcopy(tmp)) == NULL)
		errx(1, "%s(%d): mobject_deepcopy", __func__, __LINE__);
	if (mdict_insert_s(fsm_namespace, "max_state_valid", tmp) == NULL)
		errx(1, "%s(%d): mdict_insert_s", __func__, __LINE__);

	/* Set flag for multiple initial states */
	if ((n = marray_len(fsm_initial_states)) == 0)
		errx(1, "No initial state defined");
	if (mdict_insert_si(fsm_namespace, "multiple_start_states",
	    n > 1 ? 1 : 0) == NULL)
		errx(1, "%s(%d): mdict_insert_s", __func__, __LINE__);

	/* If FSM is event-driven, set min and max valid events */
	n = marray_len(fsm_events_array);
	if (n > 0) {
		if ((tmp = marray_item(fsm_events_array, 0)) == NULL)
			errx(1, "%s(%d): marray_item", __func__, __LINE__);
		if ((tmp = mobject_deepcopy(tmp)) == NULL)
			errx(1, "%s(%d): mobject_deepcopy", __func__, __LINE__);
		if (mdict_insert_s(fsm_namespace, "min_event_valid",
		    tmp) == NULL)
			errx(1, "%s(%d): mdict_insert_s", __func__, __LINE__);
		if ((tmp = marray_item(fsm_events_array, n - 1)) == NULL)
			errx(1, "%s(%d): marray_item", __func__, __LINE__);
		if ((tmp = mobject_deepcopy(tmp)) == NULL)
			errx(1, "%s(%d): mobject_deepcopy", __func__, __LINE__);
		if (mdict_insert_s(fsm_namespace, "max_event_valid",
		    tmp) == NULL)
			errx(1, "%s(%d): mdict_insert_s", __func__, __LINE__);
	}

	/* Set callback and precondition arguments and prototype signatures */
	if (mdict_replace_ss(fsm_namespace, "event_precond_args",
	    gen_cb_args(event_precond_args)) == NULL)
		errx(1, "%s(%d): mdict_replace_ss", __func__, __LINE__);
	if (mdict_replace_ss(fsm_namespace, "event_precond_args_proto",
	    gen_cb_args_proto(event_precond_args)) == NULL)
		errx(1, "%s(%d): mdict_replace_ss", __func__, __LINE__);

	if (mdict_replace_ss(fsm_namespace, "trans_precond_args",
	    gen_cb_args(trans_precond_args)) == NULL)
		errx(1, "%s(%d): mdict_replace_ss", __func__, __LINE__);
	if (mdict_replace_ss(fsm_namespace, "trans_precond_args_proto",
	    gen_cb_args_proto(trans_precond_args)) == NULL)
		errx(1, "%s(%d): mdict_replace_ss", __func__, __LINE__);

	if (mdict_replace_ss(fsm_namespace, "event_cb_args",
	    gen_cb_args(event_callback_args)) == NULL)
		errx(1, "%s(%d): mdict_replace_ss", __func__, __LINE__);
	if (mdict_replace_ss(fsm_namespace, "event_cb_args_proto",
	    gen_cb_args_proto(event_callback_args)) == NULL)
		errx(1, "%s(%d): mdict_replace_ss", __func__, __LINE__);

	if (mdict_replace_ss(fsm_namespace, "trans_cb_args",
	    gen_cb_args(trans_callback_args)) == NULL)
		errx(1, "%s(%d): mdict_replace_ss", __func__, __LINE__);
	if (mdict_replace_ss(fsm_namespace, "trans_cb_args_proto",
	    gen_cb_args_proto(trans_callback_args)) == NULL)
		errx(1, "%s(%d): mdict_replace_ss", __func__, __LINE__);

	/*
	 * Walk next_states and update each state's indegree, checking
	 * for nonexistent next-states.
	 */
	if ((siter = mobject_getiter(fsm_states)) == NULL)
		errx(1, "%s(%d): mobject_getiter", __func__, __LINE__);
	while ((sitem = miterator_next(siter)) != NULL) {
		if ((state = mstring_ptr(sitem->key)) == NULL)
			errx(1, "%s(%d): fsm_states returned NULL key",
			    __func__, __LINE__);
		if ((tmp = mdict_item_s(sitem->value, "next_states")) == NULL)
			errx(1, "%s(%d): mdict_item_s", __func__, __LINE__);
		if ((niter = mobject_getiter(tmp)) == NULL)
			errx(1, "%s(%d): mobject_getiter", __func__, __LINE__);
		while ((nitem = miterator_next(niter)) != NULL) {
			if ((next_state = mstring_ptr(nitem->key)) == NULL)
				errx(1, "%s(%d): %s.next_states returned "
				    "NULL key", __func__, __LINE__, state);
			if ((tmp = mdict_item(fsm_states, nitem->key)) == NULL)
				errx(1, "State \"%s\" references non-existent "
				    "next state \"%s\"", state, next_state);
			if ((tmp = mdict_item_s(tmp, "indegree")) == NULL)
				errx(1, "State \"%s\" lacks indegree",
				    next_state);
			if (mint_add(tmp, 1) != 0)
				errx(1, "%s(%d): %s mint_add", __func__,
				    __LINE__, next_state);
		}
		miterator_free(niter);
	}
	miterator_free(siter);

	/* Now look for unreachable (indegree == 0) states */
	if ((siter = mobject_getiter(fsm_states)) == NULL)
		errx(1, "%s(%d): mobject_getiter", __func__, __LINE__);
	while ((sitem = miterator_next(siter)) != NULL) {
		if ((state = mstring_ptr(sitem->key)) == NULL)
			errx(1, "%s(%d): fsm_states returned NULL key",
			    __func__, __LINE__);
		if ((tmp = mdict_item_s(sitem->value, "indegree")) == NULL)
			errx(1, "State \"%s\" lacks indegree", state);
		if ((indegree = mint_value(tmp)) > 0)
			continue;
		if ((tmp = mdict_item_s(sitem->value, "is_initial")) == NULL)
			errx(1, "State \"%s\" lacks is_initial", state);
		if (mint_value(tmp) != 1)
			errx(1, "State \"%s\" is unreachable", state);
	}
	miterator_free(siter);

}
