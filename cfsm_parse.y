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

/* $Id: cfsm_parse.y,v 1.1 2007/04/08 03:32:54 djm Exp $ */

%{
#include <sys/types.h>
#include <sys/param.h>

#include <stdio.h>
#include <string.h>
#include <stdarg.h>

int yyparse(void);
void yyerror(const char *, ...);

extern int yylex(void);

extern char *path;
extern u_int lnum;
extern char *yytext;
%}

%token COMMA MOVETO BANNER_START BANNER_END
%token ADVANCE_FUNC CTX CURRENT_STATE_FUNC TRANSITION_ENTRY_PRECOND
%token EVENT_CALLBACK_ARGS EVENT_CALLBACK EVENT_NTOP_FUNC EVENT_ENUM
%token EVENT_PRECOND_ARGS EVENT_PRECOND EVENT TRANSITION_EXIT_PRECOND
%token FREE_FUNC FSM_STRUCT IGNORE_EVENT INIT_FUNC INITIAL_STATE
%token NEW_STATE NEXT_STATE NONE OLD_STATE TRANSITION_ENTRY_CALLBACK
%token EVENT_ADVANCE TRANSITION_EXIT_CALLBACK TRANSITION_PRECOND_ARGS
%token SOURCE_BANNER_START SOURCE_BANNER_END STATE_NTOP_FUNC STATE_ENUM STATE 
%token TRANSITION_CALLBACK_ARGS
%token <string> ID BANNER_LINE

%union {
	char *string;
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

banner:			banner_start | banner_lines | banner_end
	;

state_enum_def:		STATE_ENUM ID
	;

event_enum_def:		EVENT_ENUM ID
	;

fsm_struct_def:		FSM_STRUCT ID
	;

current_state_func_def:	CURRENT_STATE_FUNC ID
	;

init_func_def:		INIT_FUNC ID
	;

free_func_def:		FREE_FUNC ID
	;

advance_func_def:	ADVANCE_FUNC ID
	;

state_ntop_func_def:	STATE_NTOP_FUNC ID
	;

event_ntop_func_def:	EVENT_NTOP_FUNC ID
	;

callback_arg:		CTX | EVENT | NEW_STATE | OLD_STATE
	;

callback_arglist:	callback_arg |
			callback_arglist COMMA callback_arg
	;

callback_args:		NONE |
			callback_arglist
	;

event_precond_arg_def:	EVENT_PRECOND_ARGS callback_args
	;

trans_precond_arg_def:	TRANSITION_PRECOND_ARGS callback_args
	;

event_callback_arg_def:	EVENT_CALLBACK_ARGS callback_args
	;

trans_callback_arg_def:	TRANSITION_CALLBACK_ARGS callback_args
	;

state_decl:		STATE ID
	;

initial_state_def:	INITIAL_STATE
	;

next_state_def:		NEXT_STATE ID
	;

on_event_def:		EVENT_ADVANCE ID MOVETO ID
	;

ignore_event_def:	IGNORE_EVENT ID
	;

entry_callback_def:	TRANSITION_ENTRY_CALLBACK ID
	;

exit_callback_def:	TRANSITION_EXIT_CALLBACK ID
	;

entry_precond_def:	TRANSITION_ENTRY_PRECOND ID
	;

exit_precond_def:	TRANSITION_EXIT_PRECOND ID
	;

event_decl:		EVENT ID
	;

event_callback_def:	EVENT_CALLBACK ID
	;

event_precond_def:	EVENT_PRECOND ID
	;

banner_start:		BANNER_START
	;

banner_lines:		| banner_lines banner_line
	;

banner_line:		BANNER_LINE
	;

banner_start:		BANNER_END
	;

%%

void
yyerror(const char *fmt, ...)
{
	char fmtbuf[255];
	va_list args;

	snprintf(fmtbuf, sizeof(fmtbuf), "%s:%u %s near \"%s\"\n",
	    path, lnum, fmt, yytext);
	va_start(args, fmt);
	vfprintf(stderr, fmtbuf, args);
	va_end(args);
}
