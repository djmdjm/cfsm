/*
 * This file is in the public domain
 * Damien Miller 2007-02-07
 */

/* $Id: t2.c,v 1.5 2007/04/15 13:54:58 djm Exp $ */

#include <sys/types.h>

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "t2_fsm.h"

int
main(int argc, char **argv)
{
	struct fsm *fsm = NULL;

	assert((fsm = fsm_init(T1b, NULL, 0)) != NULL);
	fsm_free(fsm);
	assert((fsm = fsm_init(T2, NULL, 0)) == NULL);
	assert((fsm = fsm_init(T3, NULL, 0)) == NULL);
	assert((fsm = fsm_init(T4, NULL, 0)) == NULL);
	assert((fsm = fsm_init(T1a, NULL, 0)) != NULL);
	assert(fsm_current_state(fsm) == T1a);
	assert(strcmp(fsm_state_ntop(fsm_current_state(fsm)), "T1a") == 0);
	assert(fsm_advance(fsm, T2, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(fsm) == T2);
	assert(strcmp(fsm_state_ntop(fsm_current_state(fsm)), "T2") == 0);
	assert(fsm_advance(fsm, T3, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(fsm) == T3);
	assert(strcmp(fsm_state_ntop(fsm_current_state(fsm)), "T3") == 0);
	assert(fsm_advance(fsm, T2, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(fsm) == T2);
	assert(strcmp(fsm_state_ntop(fsm_current_state(fsm)), "T2") == 0);
	assert(fsm_advance(fsm, T4, NULL,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(fsm_current_state(fsm) == T2);
	assert(fsm_advance(fsm, T3, NULL, NULL, 0) == CFSM_OK);
	assert(fsm_current_state(fsm) == T3);
	assert(fsm_advance(fsm, T4, NULL, NULL, 0) == 0);
	assert(fsm_current_state(fsm) == T4);
	assert(strcmp(fsm_state_ntop(fsm_current_state(fsm)), "T4") == 0);
	assert(fsm_advance(fsm, T1b, NULL,
	    NULL, 0) == CFSM_ERR_INVALID_TRANSITION);
	assert(fsm_current_state(fsm) == T4);
	fsm_free(fsm);
	return 0;
}
