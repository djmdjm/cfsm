/*
 * This file is in the public domain
 * Damien Miller 2007-02-07
 */

/* $Id: t2.c,v 1.6 2007/11/18 09:51:19 djm Exp $ */

#include <sys/types.h>

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "t2_fsm.h"

int
main(int argc, char **argv)
{
	struct fsm fsm;

	assert(fsm_init(&fsm, T1b, NULL, 0) == CFSM_OK);
	assert(fsm_init(&fsm, T2, NULL, 0) == CFSM_ERR_INVALID_STATE);
	assert(fsm_init(&fsm, T3, NULL, 0) == CFSM_ERR_INVALID_STATE);
	assert(fsm_init(&fsm, T4, NULL, 0) == CFSM_ERR_INVALID_STATE);
	assert(fsm_init(&fsm, T1a, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T1a);
	assert(strcmp(fsm_state_ntop(fsm_current_state(&fsm)), "T1a") == 0);
	assert(fsm_advance(&fsm, T1_DONE, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T2);
	assert(strcmp(fsm_state_ntop(fsm_current_state(&fsm)), "T2") == 0);
	assert(fsm_advance(&fsm, T2_DONE, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T3);
	assert(strcmp(fsm_state_ntop(fsm_current_state(&fsm)), "T3") == 0);
	assert(fsm_advance(&fsm, T3_DONE1, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T2);
	assert(strcmp(fsm_state_ntop(fsm_current_state(&fsm)), "T2") == 0);
	assert(fsm_advance(&fsm, T3_DONE2, NULL,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(fsm_current_state(&fsm) == T2);
	assert(fsm_advance(&fsm, T2_DONE, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(&fsm) == T3);
	assert(fsm_advance(&fsm, T3_DONE2, NULL, NULL, 0) == 0);
	assert(fsm_current_state(&fsm) == T4);
	assert(strcmp(fsm_state_ntop(fsm_current_state(&fsm)), "T4") == 0);
	assert(fsm_advance(&fsm, T3_DONE2, NULL,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(fsm_current_state(&fsm) == T4);
	return 0;
}
