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

/* $Id: cfsm_lex.l,v 1.5 2007/07/07 00:28:01 djm Exp $ */

%{
#include <sys/types.h>
#include <string.h>

#include "cfsm_parse.h"

extern u_int lnum;
%}

whitespace	[ \t]+
comment		#.*
id		[a-zA-Z_][a-zA-Z0-9_]*
number		([0-9]+)|(0x[0-9a-fA-F]+)
nl		\n
comma		,
fullline	^.*

moveto		->

%x BANNER

%%

{whitespace}	;
{comment}	;

{comma}					{ return COMMA; }
{moveto}				{ return MOVETO; }

advance-function			{ return ADVANCE_FUNC; }
ctx					{ return CTX; }
current-state-function			{ return CURRENT_STATE_FUNC; }
entry-precondition			{ return TRANSITION_ENTRY_PRECOND; }
event-callback-args			{ return EVENT_CALLBACK_ARGS; }
event-callback				{ return EVENT_CALLBACK; }
event-enum-to-string-function		{ return EVENT_NTOP_FUNC; }
event-enum-type				{ return EVENT_ENUM; }
event-precondition-args			{ return EVENT_PRECOND_ARGS; }
event-precondition			{ return EVENT_PRECOND; }
event					{ return EVENT; }
exit-precondition			{ return TRANSITION_EXIT_PRECOND; }
free-function				{ return FREE_FUNC; }
fsm-struct-type				{ return FSM_STRUCT; }
ignore-event				{ return IGNORE_EVENT; }
initialise-function			{ return INIT_FUNC; }
initialize-function			{ return INIT_FUNC; }
initial-state				{ return INITIAL_STATE; }
new-state				{ return NEW_STATE; }
next-state				{ return NEXT_STATE; }
none					{ return NONE; }
old-state				{ return OLD_STATE; }
onentry-func				{ return TRANSITION_ENTRY_CALLBACK; }
on-event				{ return EVENT_ADVANCE; }
onexit-func				{ return TRANSITION_EXIT_CALLBACK; }
precondition-function-args		{ return TRANSITION_PRECOND_ARGS; }
state-enum-to-string-function		{ return STATE_NTOP_FUNC; }
state-enum-type				{ return STATE_ENUM; }
state					{ return STATE; }
transition-function-args		{ return TRANSITION_CALLBACK_ARGS; }

{id}					{ yylval.string = strdup(yytext);
					  return ID;
					}
{number}				{ yylval.string = strdup(yytext);
					  return NUMBER;
					}
{nl}					{ lnum++; }
.					{ return yytext[0]; }

source-banner{nl}			{ BEGIN(BANNER);
					  return BANNER_START;
					}
<BANNER>end-source-banner{nl}		{ BEGIN(INITIAL);
					  lnum++;
					  return BANNER_END;
					}
<BANNER>{fullline}{nl}			{ lnum++;
					  yylval.string = strdup(yytext);
					  return BANNER_LINE;
					}
