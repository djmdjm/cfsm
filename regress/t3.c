/*
 * This file is in the public domain
 * Damien Miller 2007-02-07
 */

/* $Id: t3.c,v 1.6 2007/11/18 09:51:19 djm Exp $ */

#include <sys/types.h>

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "t3_fsm.h"

#define state_funcs(st, en, ex) \
	int st##_entry_pre_visited = 0; \
	int st##_exit_pre_visited = 0; \
	int st##_exit_visited = 0; \
	int st##_enter_visited = 0; \
	int st##_entry_pre(enum fsm_state c, enum fsm_state n) \
		{ st##_entry_pre_visited++; return en; } \
	int st##_exit_pre(enum fsm_state c, enum fsm_state n)  \
		{ st##_exit_pre_visited++; return ex; } \
	void st##_exit(enum fsm_state c, enum fsm_state n) \
		{ st##_exit_visited++; } \
	void st##_enter(enum fsm_state c, enum fsm_state n) \
		{ st##_enter_visited++; }

state_funcs(t1a, -1, 0)
state_funcs(t1b, -1, -1)
state_funcs(t2, 0, 0)
state_funcs(t3, 0, 0)
state_funcs(t4, -1, -1)

int
main(int argc, char **argv)
{
	struct fsm fsm;

	/* T1b -> T2 - expect fail */
	assert(fsm_init(&fsm, T1b, NULL, 0) == CFSM_OK);
	assert(t1b_exit_pre_visited == 0);
	assert(fsm_advance(&fsm, T1_DONE, NULL,
	    NULL, 0) == CFSM_ERR_PRECONDITION);
	assert(fsm_current_state(&fsm) == T1b);
	assert(t1b_exit_pre_visited == 1);
	assert(t2_enter_visited == 0);
	assert(t2_entry_pre_visited == 0);

	assert(fsm_init(&fsm, T2, NULL, 0) == CFSM_ERR_INVALID_STATE);
	assert(fsm_init(&fsm, T3, NULL, 0) == CFSM_ERR_INVALID_STATE);
	assert(fsm_init(&fsm, T4, NULL, 0) == CFSM_ERR_INVALID_STATE);

	assert(fsm_init(&fsm, T1a, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T1a);
	assert(t1a_exit_visited == 0);
	assert(t1a_enter_visited == 0);
	assert(t1a_exit_pre_visited == 0);
	assert(t1a_entry_pre_visited == 0);

	/* T1b -> T2 - expect success */
	assert(fsm_advance(&fsm, T1_DONE, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T2);
	assert(t1a_exit_visited == 1);
	assert(t1a_enter_visited == 0);
	assert(t1a_exit_pre_visited == 1);
	assert(t1a_entry_pre_visited == 0);
	assert(t2_exit_visited == 0);
	assert(t2_enter_visited == 1);
	assert(t2_exit_pre_visited == 0);
	assert(t2_entry_pre_visited == 1);

	/* T2 -> T3 - expect success */
	assert(fsm_advance(&fsm, T2_DONE, NULL, NULL, 0) == CFSM_OK);
	assert(t2_exit_visited == 1);
	assert(t2_enter_visited == 1);
	assert(t2_exit_pre_visited == 1);
	assert(t2_entry_pre_visited == 1);
	assert(t3_exit_visited == 0);
	assert(t3_enter_visited == 1);
	assert(t3_exit_pre_visited == 0);
	assert(t3_entry_pre_visited == 1);
	assert(fsm_current_state(&fsm) == T3);

	/* T3 -> T2 - expect success */
	assert(fsm_advance(&fsm, T3_DONE1, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T2);
	assert(t2_exit_visited == 1);
	assert(t2_enter_visited == 2);
	assert(t2_exit_pre_visited == 1);
	assert(t2_entry_pre_visited == 2);
	assert(t3_exit_visited == 1);
	assert(t3_enter_visited == 1);
	assert(t3_exit_pre_visited == 1);
	assert(t3_entry_pre_visited == 1);

	/* T2 -> T4 - expect failure */
	assert(fsm_advance(&fsm, T3_DONE3, NULL,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(t2_exit_visited == 1);
	assert(t2_enter_visited == 2);
	assert(t2_exit_pre_visited == 1);
	assert(t2_entry_pre_visited == 2);
	assert(fsm_current_state(&fsm) == T2);

	/* T2 -> T3 - expect success */
	assert(fsm_advance(&fsm, T2_DONE, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T3);
	assert(t2_exit_visited == 2);
	assert(t2_enter_visited == 2);
	assert(t2_exit_pre_visited == 2);
	assert(t2_entry_pre_visited == 2);
	assert(t3_exit_visited == 1);
	assert(t3_enter_visited == 2);
	assert(t3_exit_pre_visited == 1);
	assert(t3_entry_pre_visited == 2);

	/* T3 -> T4 - expect failure */
	assert(fsm_advance(&fsm, T3_DONE3, NULL,
	    NULL, 0) == CFSM_ERR_PRECONDITION);
	assert(fsm_current_state(&fsm) == T3);
	assert(t3_exit_visited == 1);
	assert(t3_enter_visited == 2);
	assert(t3_exit_pre_visited == 2);
	assert(t3_entry_pre_visited == 2);
	assert(t4_exit_visited == 0);
	assert(t4_enter_visited == 0);
	assert(t4_exit_pre_visited == 0);
	assert(t4_entry_pre_visited == 1);

	/* T3 -> T3 - expect success */
	assert(fsm_advance(&fsm, T3_DONE2, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T3);
	assert(t3_exit_visited == 2);
	assert(t3_enter_visited == 3);
	assert(t3_exit_pre_visited == 3);
	assert(t3_entry_pre_visited == 3);

	return 0;
}
