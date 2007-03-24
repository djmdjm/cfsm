/*
 * This file is in the public domain
 * Damien Miller 2007-02-09
 */

#include <sys/types.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "t_ex0_fsm.h"

enum mystate ie_expected_cb_state = INITIAL_1;
enum mystate rtep_expected_cb_state = GROUND_STATE;
int ie_called = 0;
int rtep_called = 0;
int ne_called = 0;
int rtep_fail = 1;

int
is_excited(enum mystate s, void *ctx)
{
	assert(s == ie_expected_cb_state);
	assert(ctx == NULL);
	ie_called++;
	return ie_called < 3 ? -1 : 0;
}

int
ready_to_emit_photon(enum mystate s, void *ctx)
{
	assert(s == rtep_expected_cb_state);
	assert(ctx == (void *)atoi);
	rtep_called++;
	return rtep_fail ? -1 : 0;
}

void
now_excited(void)
{
	ne_called++;
}

void
absorb_a_photon()
{
}

int
main(int argc, char **argv)
{
	struct myfsm *fsm = NULL;

	assert((fsm = myfsm_init(EXCITED_STATE, NULL, 0)) == NULL);
	assert((fsm = myfsm_init(GROUND_STATE, NULL, 0)) == NULL);
	assert((fsm = myfsm_init(INITIAL_1, NULL, 0)) != NULL);
	assert(myfsm_current(fsm) == INITIAL_1);
	assert(strcmp(myfsm_tostring(myfsm_current(fsm)), "INITIAL_1") == 0);
	assert(strcmp(myfsm_tostring_safe(myfsm_current(fsm)),
	    "INITIAL_1") == 0);
	myfsm_free(fsm);

	assert((fsm = myfsm_init(INITIAL_2, NULL, 0)) != NULL);
	assert(myfsm_current(fsm) == INITIAL_2);
	assert(strcmp(myfsm_tostring(myfsm_current(fsm)), "INITIAL_2") == 0);
	ie_expected_cb_state = INITIAL_2;
	assert(myfsm_advance(fsm, EXCITED_STATE, NULL, NULL, 0) == -1);
	assert(ie_called == 1);
	assert(myfsm_advance(fsm, EXCITED_STATE, NULL, NULL, 0) == -1);
	assert(ie_called == 2);
	assert(myfsm_advance(fsm, EXCITED_STATE, NULL, NULL, 0) == 0);
	assert(myfsm_current(fsm) == EXCITED_STATE);
	assert(ie_called == 3);
	assert(ne_called == 1);
	assert(rtep_called == 0);
	rtep_expected_cb_state = EXCITED_STATE;
	assert(myfsm_advance(fsm, GROUND_STATE, (void *)atoi, NULL, 0) == -1);
	assert(myfsm_current(fsm) == EXCITED_STATE);
	assert(rtep_called == 1);
	rtep_fail = 0;
	assert(myfsm_advance(fsm, GROUND_STATE, (void *)atoi, NULL, 0) == 0);
	assert(myfsm_current(fsm) == GROUND_STATE);
	assert(rtep_called == 2);
	myfsm_free(fsm);

	return 0;
}

