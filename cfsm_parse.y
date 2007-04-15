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

/* $Id: cfsm_parse.y,v 1.4 2007/04/15 08:45:58 djm Exp $ */

%{
#include <sys/types.h>
#include <sys/param.h>

#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>
#include <err.h>

#include "xobject.h"
#include "strlcat.h"

#include "cfsm.h"

extern char *yytext;

/* Local prototypes */
int yyparse(void);
void yyerror(const char *, ...);
static const char *gen_cb_args(u_int);
static const char *gen_cb_args_proto(u_int);
static struct xdict *get_or_create_event(char *);
static int create_action(char *, const char *, const char *, struct xdict *,
    const char *, struct xdict *);
void finalise_namespace(void);
void setup_initial_namespace(void);

/* From cfsm_lex.l */
extern int yylex(void);

/* From cfsm.c */
extern const char *in_path;
extern const char *header_name;

/* Local variables */

/* Line number in input file */
u_int lnum = 0;

/*
 * The representation of the FSM that is built during parsing and
 * subsequently used to fill in the template
 */
struct xdict *fsm_namespace = NULL;

/* Convenience pointers to commonly-used objects in the namespace */
static struct xarray *fsm_initial_states = NULL;
static struct xarray *fsm_states_array = NULL;
static struct xarray *fsm_events_array = NULL;
static struct xdict *fsm_states = NULL;
static struct xdict *fsm_events = NULL;
static struct xdict *fsm_event_callbacks = NULL;
static struct xdict *fsm_event_preconds = NULL;
static struct xdict *fsm_trans_entry_callbacks = NULL;
static struct xdict *fsm_trans_entry_preconds = NULL;
static struct xdict *fsm_trans_exit_callbacks = NULL;
static struct xdict *fsm_trans_exit_preconds = NULL;

/* Pointers to active event or state */
static struct xdict *current_state;
static struct xdict *current_event;

static size_t banner_len = 0;
static char *banner = NULL;

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
%token <string> ID BANNER_LINE

%type <n> callback_arg callback_arglist callback_args

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
			ignore_event_def | next_state_def |
			entry_callback_def | exit_callback_def |
			entry_precond_def | exit_precond_def
	;

event_def:		event_decl | event_callback_def | event_precond_def
	;

banner:			banner_start banner_lines banner_end
	;

state_enum_def:		STATE_ENUM ID {
		if (xdict_replace_ss(fsm_namespace, "state_enum", $2) == -1)
			errx(1, "state_enum_def: xdict_replace_ss");
		free($2);
	}
	;

event_enum_def:		EVENT_ENUM ID {
		if (xdict_replace_ss(fsm_namespace, "event_enum", $2) == -1)
			errx(1, "event_enum_def: xdict_replace_ss");
		free($2);
	}
	;

fsm_struct_def:		FSM_STRUCT ID {
		if (xdict_replace_ss(fsm_namespace, "fsm_struct", $2) == -1)
			errx(1, "fsm_struct_def: xdict_replace_ss");
	}
	;

current_state_func_def:	CURRENT_STATE_FUNC ID {
		if (xdict_replace_ss(fsm_namespace, "current_state_func",
		    $2) == -1)
			errx(1, "current_state_func_def: xdict_replace_ss");
		free($2);
	}
	;

init_func_def:		INIT_FUNC ID {
		if (xdict_replace_ss(fsm_namespace, "init_func", $2) == -1)
			errx(1, "init_func_def: xdict_replace_ss");
		free($2);
	}
	;

free_func_def:		FREE_FUNC ID {
		if (xdict_replace_ss(fsm_namespace, "free_func", $2) == -1)
			errx(1, "free_func_def: xdict_replace_ss");
		free($2);
	}
	;

advance_func_def:	ADVANCE_FUNC ID {
		if (xdict_replace_ss(fsm_namespace, "advance_func", $2) == -1)
			errx(1, "advance_func_def: xdict_replace_ss");
		free($2);
	}
	;

state_ntop_func_def:	STATE_NTOP_FUNC ID {
		if (xdict_replace_ss(fsm_namespace, "state_ntop_func",
		    $2) == -1)
			errx(1, "state_ntop_func_def: xdict_replace_ss");
		free($2);
	}
	;

event_ntop_func_def:	EVENT_NTOP_FUNC ID {
		if (xdict_replace_ss(fsm_namespace, "event_ntop_func",
		    $2) == -1)
			errx(1, "event_ntop_func_def: xdict_replace_ss");
		free($2);
	}
	;

callback_arg:		EVENT		{ $$ = CB_ARG_EVENT; }
			| NEW_STATE	{ $$ = CB_ARG_NEW_STATE; }
			| OLD_STATE	{ $$ = CB_ARG_OLD_STATE; }
			| CTX {
		$$ = CB_ARG_CTX;
		if (xdict_replace_si(fsm_namespace, "need_ctx", 1) == -1)
			errx(1, "ctx: xdict_replace_si failed");
	}
	;

callback_arglist:	callback_arg |
			callback_arglist COMMA callback_arg { $$ = $1 | $3; }
	;

callback_args:		NONE 		{ $$ = 0; }
			| callback_arglist
	;

event_precond_arg_def:	EVENT_PRECOND_ARGS callback_args {
		if (xdict_replace_ss(fsm_namespace, "event_precond_args",
		    gen_cb_args($2)) == -1)
			errx(1, "event_precond_arg_def: xdict_replace_ss");
		if (xdict_replace_ss(fsm_namespace, "event_precond_args_proto",
		    gen_cb_args_proto($2)) == -1)
			errx(1, "event_precond_arg_def: xdict_replace_ss");
	}
	;

trans_precond_arg_def:	TRANSITION_PRECOND_ARGS callback_args {
		if (xdict_replace_ss(fsm_namespace, "trans_precond_args",
		    gen_cb_args($2)) == -1)
			errx(1, "trans_precond_arg_def: xdict_replace_ss");
		if (xdict_replace_ss(fsm_namespace, "trans_precond_args_proto",
		    gen_cb_args_proto($2)) == -1)
			errx(1, "trans_precond_arg_def: xdict_replace_ss");
	}
	;

event_callback_arg_def:	EVENT_CALLBACK_ARGS callback_args {
		if (xdict_replace_ss(fsm_namespace, "event_cb_args",
		    gen_cb_args($2)) == -1)
			errx(1, "event_callback_arg_def: xdict_replace_ss");
		if (xdict_replace_ss(fsm_namespace, "event_cb_args_proto",
		    gen_cb_args_proto($2)) == -1)
			errx(1, "event_callback_arg_def: xdict_replace_ss");
	}
	;

trans_callback_arg_def:	TRANSITION_CALLBACK_ARGS callback_args {
		if (xdict_replace_ss(fsm_namespace, "trans_cb_args",
		    gen_cb_args($2)) == -1)
			errx(1, "trans_callback_arg_def: xdict_replace_ss");
		if (xdict_replace_ss(fsm_namespace, "trans_cb_args_proto",
		    gen_cb_args_proto($2)) == -1)
			errx(1, "trans_callback_arg_def: xdict_replace_ss");
	}
	;

state_decl:		STATE ID {
		current_event = NULL;
		if (xdict_insert_sd(fsm_states, $2) == -1) {
			yyerror("state \"%s\" already defined", $2);
			free($2);
			YYERROR;
		} else {
			if ((current_state = (struct xdict *)xdict_item_s(
			    fsm_states, $2)) == NULL)
				errx(1, "state_decl: xdict_item_s failed");
		}
		if (xdict_insert_ss(current_state, "name", $2) == -1 ||
		    xdict_insert_sd(current_state, "events") == -1 ||
		    xdict_insert_sd(current_state, "next_states") == -1 ||
		    xdict_insert_sd(current_state, "exit_preconds") == -1 ||
		    xdict_insert_sd(current_state, "entry_preconds") == -1 ||
		    xdict_insert_sd(current_state, "exit_callbacks") == -1 ||
		    xdict_insert_sd(current_state, "entry_callbacks") == -1 ||
		    xdict_insert_si(current_state, "is_initial", 0) == -1 ||
		    xarray_append_s(fsm_states_array, $2) == -1)
			errx(1, "state_decl: set up state failed");
		free($2);
	}
	;

initial_state_def:	INITIAL_STATE {
		struct xobject *i;

		if (current_state == NULL) {
			yyerror("\"initial-state\" outside state block");
			YYERROR;
		}
		if ((i = xdict_item_s(current_state, "is_initial")) == NULL)
			errx(1, "initial_state_def: state lacks is_initial");
		if (xint_value((struct xint *)i) != 0) {
			yyerror("\"initial-state\" already set for this state");
			YYERROR;
		}
		if (xdict_replace_si(current_state, "is_initial", 1) == -1)
			errx(1, "initial_state_def: xdict_replace_si failed");
		if ((i = xdict_item_s(current_state, "name")) == NULL)
			errx(1, "initial_state_def: state lacks name");
		if ((i = xobject_deepcopy(i)) == NULL)
			errx(1, "initial_state_def: xobject_deepcopy");
		if (xarray_append(fsm_initial_states, i) == -1)
			errx(1, "initial_state_def: xarray_append");
	}
	;

next_state_def:		NEXT_STATE ID {
		struct xdict *next_states;

		if (current_state == NULL) {
			yyerror("\"next-state\" outside state block");
			free($2);
			YYERROR;
		}
		if ((next_states = (struct xdict *)xdict_item_s(current_state,
		    "next_states")) == NULL)
			errx(1, "next_state_def: state lacks next_states");
		if (xdict_replace_si(next_states, $2, 1) == -1)
			errx(1, "next_state_def: xdict_replace_si failed");
		free($2);
	}
	;

on_event_def:		EVENT_ADVANCE ID MOVETO ID {
		struct xdict *events;

		if (current_state == NULL) {
			yyerror("\"on-event\" outside state block");
			free($2);
			free($4);
			YYERROR;
		}
		get_or_create_event($2);
		if ((events = (struct xdict *)xdict_item_s(current_state,
		    "events")) == NULL)
			errx(1, "on_event_def: state lacks events");
		if (xdict_replace_ss(events, $4, $2) == -1)
			errx(1, "on_event_def: xdict_replace_ss failed");
		free($2);
		free($4);
	}
	;

ignore_event_def:	IGNORE_EVENT ID {
		struct xdict *events;

		if (current_state == NULL) {
			yyerror("\"ignore-event\" outside state block");
			free($2);
			YYERROR;
		}
		get_or_create_event($2);
		if ((events = (struct xdict *)xdict_item_s(current_state,
		    "events")) == NULL)
			errx(1, "on_event_def: state lacks events");
		if (xdict_replace_sn(events, $2) == -1)
			errx(1, "on_event_def: xdict_replace_sn failed");
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
		current_event = get_or_create_event($2);
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
		if (xdict_replace_ss(fsm_namespace, "source_banner",
		    banner) == -1)
			errx(1, "xdict_replace_ss failed");
		free(banner);
		banner = NULL;
		banner_len = 0;
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
		commacat(buf, "fsm->current_state", sizeof(buf));
	if ((argdef & CB_ARG_NEW_STATE) != 0)
		commacat(buf, "new_state", sizeof(buf));
	if ((argdef & CB_ARG_CTX) != 0)
		commacat(buf, "ctx", sizeof(buf));

	return buf;
}

static const char *
gen_cb_args_proto(u_int argdef)
{
	static char buf[256];

	/* XXX: shit. need state_enum and event_enum expansion here! */
	if (argdef == 0)
		return "";
	*buf = '\0';
	if ((argdef & CB_ARG_EVENT) != 0)
		commacat(buf, "XXX1", sizeof(buf));
	if ((argdef & CB_ARG_OLD_STATE) != 0)
		commacat(buf, "XXX2", sizeof(buf));
	if ((argdef & CB_ARG_NEW_STATE) != 0)
		commacat(buf, "XXX3", sizeof(buf));
	if ((argdef & CB_ARG_CTX) != 0)
		commacat(buf, "void *ctx", sizeof(buf));
	return buf;
}

static struct xdict *
get_or_create_event(char *name)
{
	struct xdict *ret;

	ret = (struct xdict *)xdict_item_s(fsm_events, name);
	if (ret == NULL) {
		if (xdict_insert_sd(fsm_events, name) == -1)
			errx(1, "%s: xdict_item_s failed", __func__);
		if ((ret = (struct xdict *)xdict_item_s(
			fsm_events, name)) == NULL)
			errx(1, "%s: xdict_item_s failed", __func__);
		if (xdict_insert_sd(ret, "preconds") == -1 ||
		    xdict_insert_sd(ret, "callbacks") == -1)
			errx(1, "%s: set up event failed", __func__);
		if (xarray_append_s(fsm_events_array, name) == -1)
			errx(1, "%s: xarray_append_s failed", __func__);
	}
	return ret;
}

static int
create_action(char *name, const char *context, const char *block,
    struct xdict *parent, const char *member, struct xdict *main_list)
{
	struct xdict *l;

	if (parent == NULL) {
		yyerror("\"%s\" outside %s block", context, block);
		return -1;
	}
	if ((l = (struct xdict *)xdict_item_s(parent, member)) == NULL)
		errx(1, "%s(%s): %s lacks %s", __func__, context,
		    block, member);
	if (xdict_replace_si(l, name, 1) != 0)
		errx(1, "%s(%s): xdict_replace_si(%p, %s, 1) failed",
		    __func__, context, l, name);
	if (xdict_replace_si(main_list, name, 1) != 0)
		errx(1, "%s(%s): xdict_replace_si(%p, %s, 1) failed",
		    __func__, context, main_list, name);
	return 0;
}

void
setup_initial_namespace(void)
{
	u_int i;
	char *guard;

#define DEF_STRING(k, v) do { \
		if (xdict_insert_ss(fsm_namespace, k, v) != 0) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_DICT(k) do { \
		if (xdict_insert_sd(fsm_namespace, k) != 0) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_ARRAY(k) do { \
		if (xdict_insert_sa(fsm_namespace, k) != 0) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_GET(o, k, c) do { \
		if ((o = (struct c *)xdict_item_s(fsm_namespace, k)) == NULL) \
			errx(1, "Lookup for default \"%s\" failed", k); \
	} while (0)

	/* Set our defaults */
	DEF_STRING("source_banner", "");
	DEF_STRING("event_enum", DEFAULT_EVENT_ENUM);
	DEF_STRING("state_enum", DEFAULT_STATE_ENUM);
	DEF_STRING("fsm_struct", DEFAULT_FSM_STRUCT);
	DEF_STRING("init_func", DEFAULT_INIT_FUNC);
	DEF_STRING("free_func", DEFAULT_FREE_FUNC);
	DEF_STRING("advance_func", DEFAULT_FREE_FUNC);
	DEF_STRING("state_ntop_func", DEFAULT_STATE_NTOP_FUNC);
	DEF_STRING("event_ntop_func", DEFAULT_EVENT_NTOP_FUNC);

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

	DEF_GET(fsm_states_array, "states_array", xarray);
	DEF_GET(fsm_events_array, "events_array", xarray);
	DEF_GET(fsm_initial_states, "initial_states", xarray);
	DEF_GET(fsm_states, "states", xdict);
	DEF_GET(fsm_events, "events", xdict);
	DEF_GET(fsm_event_callbacks, "event_callbacks", xdict);
	DEF_GET(fsm_event_preconds, "event_preconds", xdict);
	DEF_GET(fsm_trans_entry_callbacks, "transition_entry_callbacks",xdict);
	DEF_GET(fsm_trans_entry_preconds, "transition_entry_preconds", xdict);
	DEF_GET(fsm_trans_exit_callbacks, "transition_exit_callbacks", xdict);
	DEF_GET(fsm_trans_exit_preconds, "transition_exit_preconds", xdict);

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
	struct xobject *tmp;

	if ((n = xarray_len(fsm_initial_states)) == 0)
		errx(1, "No initial state defined");
	if (xdict_insert_si(fsm_namespace, "multiple_start_states",
	    n > 1 ? 1 : 0) == -1)
		errx(1, "xdict_insert_s failed");

	if ((n = xarray_len(fsm_states_array)) == 0)
		errx(1, "No states defined");
	if (n == 1)
		errx(1, "Only one state defined");

	if ((tmp = xarray_item(fsm_states_array, 0)) == NULL)
		errx(1, "xarray_item failed");
	if ((tmp = xobject_deepcopy(tmp)) == NULL)
		errx(1, "xobject_deepcopy failed");
	if (xdict_insert_s(fsm_namespace, "min_state_valid", tmp) == -1)
		errx(1, "xdict_insert_s failed");
	if ((tmp = xarray_item(fsm_states_array, n - 1)) == NULL)
		errx(1, "xarray_item failed");
	if ((tmp = xobject_deepcopy(tmp)) == NULL)
		errx(1, "xobject_deepcopy failed");
	if (xdict_insert_s(fsm_namespace, "max_state_valid", tmp) == -1)
		errx(1, "xdict_insert_s failed");

	n = xarray_len(fsm_events_array);
	if (n > 0) {
		if ((tmp = xarray_item(fsm_events_array, 0)) == NULL)
			errx(1, "xarray_item failed");
		if ((tmp = xobject_deepcopy(tmp)) == NULL)
			errx(1, "xobject_deepcopy failed");
		if (xdict_insert_s(fsm_namespace, "min_event_valid", tmp) == -1)
			errx(1, "xdict_insert_s failed");
		if ((tmp = xarray_item(fsm_events_array, n - 1)) == NULL)
			errx(1, "xarray_item failed");
		if ((tmp = xobject_deepcopy(tmp)) == NULL)
			errx(1, "xobject_deepcopy failed");
		if (xdict_insert_s(fsm_namespace, "max_event_valid", tmp) == -1)
			errx(1, "xdict_insert_s failed");
	}
}
