/*
 * This file is in the public domain
 * Damien Miller 2007-02-07
 */

#include <sys/types.h>

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "t2_fsm.h"

int
main(int argc, char **argv)
{
	struct fsm *fsm = NULL;

	assert((fsm = state_init(T1b, NULL, 0)) != NULL);
	state_free(fsm);
	assert((fsm = state_init(T2, NULL, 0)) == NULL);
	assert((fsm = state_init(T3, NULL, 0)) == NULL);
	assert((fsm = state_init(T4, NULL, 0)) == NULL);
	assert((fsm = state_init(T1a, NULL, 0)) != NULL);
	assert(state_current(fsm) == T1a);
	assert(strcmp(state_ntop(state_current(fsm)), "T1a") == 0);
	assert(state_advance(fsm, T2, NULL, 0) == 0);
	assert(state_current(fsm) == T2);
	assert(strcmp(state_ntop(state_current(fsm)), "T2") == 0);
	assert(state_advance(fsm, T3, NULL, 0) == 0);
	assert(state_current(fsm) == T3);
	assert(strcmp(state_ntop(state_current(fsm)), "T3") == 0);
	assert(state_advance(fsm, T2, NULL, 0) == 0);
	assert(state_current(fsm) == T2);
	assert(strcmp(state_ntop(state_current(fsm)), "T2") == 0);
	assert(state_advance(fsm, T4, NULL, 0) == -1);
	assert(state_current(fsm) == T2);
	assert(state_advance(fsm, T3, NULL, 0) == 0);
	assert(state_current(fsm) == T3);
	assert(state_advance(fsm, T4, NULL, 0) == 0);
	assert(state_current(fsm) == T4);
	assert(strcmp(state_ntop(state_current(fsm)), "T4") == 0);
	assert(state_advance(fsm, T1b, NULL, 0) == -1);
	assert(state_current(fsm) == T4);
	state_free(fsm);
	return 0;
}
