/*
 * This file is in the public domain
 * Damien Miller 2007-02-07
 */

#include <sys/types.h>

#include <stdio.h>
#include <assert.h>

#include "t1_fsm.h"

int
main(int argc, char **argv)
{
	assert(state_current() == T1);
	assert(strcmp(state_ntop(state_current()), "T1") == 0);
	assert(state_advance(T2, NULL, 0) == 0);
	assert(state_current() == T2);
	assert(strcmp(state_ntop(state_current()), "T2") == 0);
	assert(state_advance(T3, NULL, 0) == 0);
	assert(state_current() == T3);
	assert(strcmp(state_ntop(state_current()), "T3") == 0);
	assert(state_advance(T2, NULL, 0) == 0);
	assert(state_current() == T2);
	assert(strcmp(state_ntop(state_current()), "T2") == 0);
	assert(state_advance(T4, NULL, 0) == -1);
	assert(state_current() == T2);
	assert(state_advance(T3, NULL, 0) == 0);
	assert(state_current() == T3);
	assert(state_advance(T4, NULL, 0) == 0);
	assert(state_current() == T4);
	assert(strcmp(state_ntop(state_current()), "T4") == 0);
	assert(state_advance(T1, NULL, 0) == -1);
	assert(state_current() == T4);
	return 0;
}
