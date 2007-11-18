/*
 * This file is in the public domain
 * Damien Miller 2007-02-09
 */

/* $Id: t_ex0.c,v 1.5 2007/11/18 09:51:19 djm Exp $ */

#include <sys/types.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "t_ex0_fsm.h"

int a_enter_called = 0;
int b_enter_called = 0;
int a_leave_called = 0;
int b_leave_called = 0;
int a_done_precondition_called = 0;
int f_done1_precondition_called = 0;
int g_done1_called = 0;
int f_done1_called = 0;
int b_ready_called = 0;
int a_finished_called = 0;
int b_finished_called = 0;
int a_ready_called = 0;


void a_enter(enum myevent ev, enum mystate old)
{
	assert(ev == G_DONE1);
	assert(old == STATE_G);
	a_enter_called++;
}

void b_enter(enum myevent ev, enum mystate old)
{
	assert((ev == A_DONE && old == STATE_A) ||
	    (ev == F_DONE2 && old == STATE_F));
	b_enter_called++;
}

void a_leave(enum myevent ev, enum mystate old)
{
	assert(old == STATE_A);
	assert(ev == A_DONE);
	a_leave_called++;
}

void b_leave(enum myevent ev, enum mystate old)
{
	assert(old == STATE_B);
	assert(ev == B_DONE1 || ev == B_DONE2);
	b_leave_called++;
}

int b_ready(enum myevent ev, enum mystate new, void *ctx)
{
	assert(ev == A_DONE || ev == F_DONE2);
	assert(new == STATE_B);
	assert(ctx == &a_finished_called);
	return (b_ready_called++ > 0) ? 0 : -1;
}

int a_finished(enum myevent ev, enum mystate new, void *ctx)
{
	assert(ev == A_DONE);
	assert(new == STATE_B);
	assert(ctx == &a_finished_called);
	return (a_finished_called++ > 0) ? 0 : -1;
}

int b_finished(enum myevent ev, enum mystate new, void *ctx)
{
	assert(ev == B_DONE1 || ev == B_DONE2);
	assert(new == STATE_C1 || new == STATE_C2);
	assert(ctx == &a_finished_called);
	return (b_finished_called++ > 0) ? 0 : -1;
}

int a_ready(enum myevent ev, enum mystate new, void *ctx)
{
	assert(ev == G_DONE1);
	assert(new == STATE_A);
	assert(ctx == &a_finished_called);
	return (a_ready_called++ > 0) ? 0 : -1;
}

void g_done1_callback(enum myevent ev, void *ctx)
{
	assert(ev == G_DONE1);
	assert(ctx == &a_finished_called);
	g_done1_called++;
}

void f_done1_callback(enum myevent ev, void *ctx)
{
	assert(ev == F_DONE1);
	assert(ctx == &a_finished_called);
	f_done1_called++;
}

int a_done_precondition(enum myevent ev, enum mystate old,
    enum mystate new, void *ctx)
{
	assert(ev == A_DONE);
	assert(old == STATE_A);
	assert(new == STATE_B);
	assert(ctx == &a_finished_called);
	return (a_done_precondition_called++ > 0) ? 0 : -1;
}

int f_done1_precondition(enum myevent ev, enum mystate old,
    enum mystate new, void *ctx)
{
	assert(ev == F_DONE1);
	assert(old == STATE_F);
	assert(new == STATE_G);
	assert(ctx == &a_finished_called);
	return (f_done1_precondition_called++ > 0) ? 0 : -1;
}

int
main(int argc, char **argv)
{
	struct myfsm fsm;

	assert(strcmp(myfsm_event_ntop_safe(A_DONE), "A_DONE") == 0);
	assert(myfsm_event_ntop(0xffffffff) == NULL);
	assert(strcmp(myfsm_event_ntop_safe(0xffffffff), "[INVALID]") == 0);

	assert(myfsm_init(&fsm, NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_A);
	assert(strcmp(myfsm_state_ntop(myfsm_current(&fsm)), "STATE_A") == 0);
	assert(strcmp(myfsm_state_ntop_safe(myfsm_current(&fsm)),
	    "STATE_A") == 0);

	assert(myfsm_init(&fsm, NULL, 0) == CFSM_OK);
	assert(myfsm_advance(&fsm, G_DONE1, NULL,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(myfsm_current(&fsm) == STATE_A);
	assert(myfsm_advance(&fsm, B_DONE1, NULL,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(myfsm_advance(&fsm, B_DONE2, NULL,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(myfsm_current(&fsm) == STATE_A);

	assert(a_enter_called == 0);
	assert(b_enter_called == 0);
	assert(a_leave_called == 0);
	assert(b_leave_called == 0);
	assert(a_done_precondition_called == 0);
	assert(f_done1_precondition_called == 0);
	assert(g_done1_called == 0);
	assert(f_done1_called == 0);
	assert(b_ready_called == 0);
	assert(a_finished_called == 0);
	assert(b_finished_called == 0);
	assert(a_ready_called == 0);

	assert(myfsm_advance(&fsm, A_DONE, &a_finished_called,
	    NULL, 0) == CFSM_ERR_PRECONDITION);
	assert(a_done_precondition_called == 1);
	assert(b_enter_called == 0);
	assert(a_leave_called == 0);
	assert(b_ready_called == 0);
	assert(a_finished_called == 0);

	assert(myfsm_advance(&fsm, A_DONE, &a_finished_called,
	    NULL, 0) == CFSM_ERR_PRECONDITION);
	assert(a_done_precondition_called == 2);
	assert(b_enter_called == 0);
	assert(a_leave_called == 0);
	assert(b_ready_called == 0);
	assert(a_finished_called == 1);

	assert(myfsm_advance(&fsm, A_DONE, &a_finished_called,
	    NULL, 0) == CFSM_ERR_PRECONDITION);
	assert(a_done_precondition_called == 3);
	assert(b_enter_called == 0);
	assert(a_leave_called == 0);
	assert(b_ready_called == 1);
	assert(a_finished_called == 2);

	assert(myfsm_advance(&fsm, A_DONE, &a_finished_called,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_B);
	assert(a_done_precondition_called == 4);
	assert(b_enter_called == 1);
	assert(a_leave_called == 1);
	assert(b_ready_called == 2);
	assert(a_finished_called == 3);
	assert(b_finished_called == 0);

	assert(myfsm_advance(&fsm, B_DONE2, &a_finished_called,
	    NULL, 0) == CFSM_ERR_PRECONDITION);
	assert(myfsm_current(&fsm) == STATE_B);
	assert(b_finished_called == 1);
	assert(b_leave_called == 0);

	assert(myfsm_advance(&fsm, B_DONE2, &a_finished_called,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_C2);
	assert(b_finished_called == 2);
	assert(b_leave_called == 1);

	assert(myfsm_advance(&fsm, B_DONE1, &a_finished_called,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(myfsm_current(&fsm) == STATE_C2);

	assert(myfsm_advance(&fsm, C_DONE2, NULL,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_D4);

	assert(myfsm_advance(&fsm, D_DONE2, NULL,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_E2);

	assert(myfsm_advance(&fsm, E_DONE, NULL,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_F);

	assert(f_done1_called == 0);
	assert(f_done1_precondition_called == 0);
	assert(myfsm_advance(&fsm, F_DONE1, &a_finished_called,
	    NULL, 0) == CFSM_ERR_PRECONDITION);
	assert(myfsm_current(&fsm) == STATE_F);
	assert(f_done1_called == 0);
	assert(f_done1_precondition_called == 1);

	assert(myfsm_advance(&fsm, F_DONE1, &a_finished_called,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_G);
	assert(f_done1_called == 1);
	assert(f_done1_precondition_called == 2);

	assert(myfsm_advance(&fsm, G_DONE2, &a_finished_called,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_F);

	assert(myfsm_advance(&fsm, F_DONE2, &a_finished_called,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_B);

	assert(myfsm_advance(&fsm, B_DONE1, &a_finished_called,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_C1);
	assert(myfsm_advance(&fsm, C_DONE1, NULL,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_D1);
	assert(myfsm_advance(&fsm, D_DONE2, NULL, NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_E2);
	assert(myfsm_advance(&fsm, E_DONE, NULL, NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_F);
	assert(myfsm_advance(&fsm, F_DONE1, &a_finished_called,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_G);

	assert(g_done1_called == 0);
	assert(myfsm_advance(&fsm, G_DONE1, &a_finished_called,
	    NULL, 0) == CFSM_ERR_PRECONDITION);
	assert(myfsm_current(&fsm) == STATE_G);
	assert(a_enter_called == 0);
	assert(a_ready_called == 1);

	assert(myfsm_advance(&fsm, G_DONE1, &a_finished_called,
	    NULL, 0) == CFSM_OK);
	assert(myfsm_current(&fsm) == STATE_A);
	assert(g_done1_called == 1);
	assert(a_enter_called == 1);
	assert(a_ready_called == 2);

	return 0;
}

