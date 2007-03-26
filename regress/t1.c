/*
 * This file is in the public domain
 * Damien Miller 2007-02-07
 */

#include <sys/types.h>

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "t1_fsm.h"

int
main(int argc, char **argv)
{
	struct fsm *fsm = NULL;

	assert((fsm = state_init(NULL, 0)) != NULL);
	assert(state_current(fsm) == T1);
	assert(strcmp(state_ntop(state_current(fsm)), "T1") == 0);
	assert(state_advance(fsm, T2, NULL, 0) == CFSM_OK);
	assert(state_current(fsm) == T2);
	assert(strcmp(state_ntop(state_current(fsm)), "T2") == 0);
	assert(state_advance(fsm, T3, NULL, 0) == CFSM_OK);
	assert(state_current(fsm) == T3);
	assert(strcmp(state_ntop(state_current(fsm)), "T3") == 0);
	assert(state_advance(fsm, T2, NULL, 0) == CFSM_OK);
	assert(state_current(fsm) == T2);
	assert(strcmp(state_ntop(state_current(fsm)), "T2") == 0);
	assert(state_advance(fsm, T4, NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(state_current(fsm) == T2);
	assert(state_advance(fsm, T3, NULL, 0) == CFSM_OK);
	assert(state_current(fsm) == T3);
	assert(state_advance(fsm, T4, NULL, 0) == CFSM_OK);
	assert(state_current(fsm) == T4);
	assert(strcmp(state_ntop(state_current(fsm)), "T4") == 0);
	assert(state_advance(fsm, T1, NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(state_current(fsm) == T4);
	state_free(fsm);
	return 0;
}
