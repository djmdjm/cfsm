{{if source_banner}}{{source_banner}}
{{endif}}/*
 * Automatically generated using the cfsm FSM compiler:
 * http://www.mindrot.org/projects/cfsm/
 */

#include <sys/types.h>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "{{header_name}}"

{{if transition_entry_callbacks}}/* Prototypes for state transition entry callbacks */
{{for cb in transition_entry_callbacks}}void {{cb.key}}({{trans_cb_args_proto}});
{{endfor}}
{{endif}}{{if transition_exit_callbacks}}/* Prototypes for state transition exit callbacks */
{{for cb in transition_exit_callbacks}}void {{cb.key}}({{trans_cb_args_proto}});
{{endfor}}
{{endif}}{{if transition_entry_preconds}}/* Prototypes for state entry precondition checks */
{{for cb in transition_entry_preconds}}int {{cb.key}}({{trans_precond_args_proto}});
{{endfor}}
{{endif}}{{if transition_exit_preconds}}/* Prototypes for state exit precondition checks */
{{for cb in transition_exit_preconds}}int {{cb.key}}({{trans_precond_args_proto}});
{{endfor}}
{{endif}}{{if event_callbacks}}/* Prototypes for event callback functions */
{{for cb in event_callbacks}}void {{cb.key}}({{event_cb_args_proto}});
{{endfor}}
{{endif}}{{if event_preconds}}/* Prototypes for event precondition checks */
{{for cb in event_preconds}}int {{cb.key}}({{event_precond_args_proto}});
{{endfor}}
{{endif}}static int
_is_{{state_enum}}_valid(enum {{state_enum}} n)
{
	if (!(n >= {{min_state_valid}} && n <= {{max_state_valid}}))
		return -1;
	return 0;
}

const char *
{{state_ntop_func}}(enum {{state_enum}} n)
{
	const char *state_names[] = {
{{for state in states}}		"{{state.key}}",
{{endfor}}	};

	if (_is_{{state_enum}}_valid(n) != 0)
		return NULL;
	return state_names[n];
}

const char *
{{state_ntop_func}}_safe(enum {{state_enum}} n)
{
	const char *r = {{state_ntop_func}}(n);

	return r == NULL ? "[INVALID]" : r;
}

static int
_is_{{event_enum}}_valid(enum {{event_enum}} n)
{
	if (!(n >= {{min_event_valid}} && n <= {{max_event_valid}}))
		return -1;
	return 0;
}

const char *
{{event_ntop_func}}(enum {{event_enum}} n)
{
	const char *event_names[] = {
{{for event in events_array}}		"{{event.value}}",
{{endfor}}	};

	if (_is_{{event_enum}}_valid(n) != 0)
		return NULL;
	return event_names[n];
}

const char *
{{event_ntop_func}}_safe(enum {{event_enum}} n)
{
	const char *r = {{event_ntop_func}}(n);

	return r == NULL ? "[INVALID]" : r;
}

{{if multiple_start_states}}int
{{init_func}}(struct {{fsm_struct}} *fsm, enum {{state_enum}} initial_state, char *errbuf, size_t errlen)
{
	switch (initial_state) {
{{for s in initial_states}}	case {{s.value}}:
{{endfor}}		break;
	default:
		if (errlen > 0 && errbuf != NULL) {
			snprintf(errbuf, errlen,
			    "State %s (%d) is not a valid start state",
			    {{state_ntop_func}}_safe(initial_state),
			    initial_state);
		}
		return CFSM_ERR_INVALID_STATE;
	}
	bzero(fsm, sizeof(fsm));
	fsm->current_state = initial_state;
	return CFSM_OK;
}{{else}}int
{{init_func}}(struct {{fsm_struct}} *fsm, char *errbuf, size_t errlen)
{
	bzero(fsm, sizeof(fsm));
	fsm->current_state = {{initial_states[0]}};
	return CFSM_OK;
}{{endif}}

enum {{state_enum}}
{{current_state_func}}(struct {{fsm_struct}} *fsm)
{
	return fsm->current_state;
}

int {{advance_func}}(struct {{fsm_struct}} *fsm, enum {{event_enum}} ev,
    {{if need_ctx}}void *ctx, {{endif}}char *errbuf, size_t errlen)
{
	enum {{state_enum}} old_state = fsm->current_state;
	enum {{state_enum}} new_state;

	/* Sanity check states */
	if (_is_{{state_enum}}_valid(fsm->current_state) != 0) {
		if (errlen > 0 && errbuf != NULL) {
			snprintf(errbuf, errlen, "Invalid current_state (%d)",
			    fsm->current_state);
		}
		return CFSM_ERR_INVALID_STATE;
	}
	if (_is_{{event_enum}}_valid(ev) != 0) {
		if (errlen > 0 && errbuf != NULL)
			snprintf(errbuf, errlen, "Invalid event (%d)", ev);
		return CFSM_ERR_INVALID_EVENT;
	}

	/* Event validity checks */
	switch(old_state) {
{{for state in states}}	case {{state.key}}:
{{if state.value.events}}		switch (ev) {
{{for event in state.value.events}}		case {{event.key}}:
{{if event.value}}			new_state = {{event.value}};
			break;{{else}}			return 0;{{endif}}
{{endfor}}		default:
			goto bad_event;
		}
		break;
{{else}}		goto bad_event;
{{endif}}{{endfor}}	}
{{if event_preconds}}
	/* Event preconditions */
	switch(ev) {
{{for event in events}}{{if event.value.preconds}}	case {{event.key}}:
{{for precond in event.value.preconds}}		if ({{precond.key}}({{event_precond_args}}) != 0)
			goto event_precond_fail;
{{endfor}}		break;
{{endif}}{{endfor}}	default:
		break;
	}
{{endif}}{{if transition_exit_preconds}}
	/* Current state exit preconditions */
	switch(old_state) {
{{for state in states}}{{if state.value.exit_preconds}}	case {{state.key}}:
{{for precond in state.value.exit_preconds}}		if ({{precond.key}}({{trans_precond_args}}) != 0)
			goto exit_precond_fail;
{{endfor}}		break;
{{endif}}{{endfor}}	default:
		break;
	}
{{endif}}{{if transition_entry_preconds}}
	/* Next state entry preconditions */
	switch(new_state) {
{{for state in states}}{{if state.value.entry_preconds}}	case {{state.key}}:
{{for precond in state.value.entry_preconds}}		if ({{precond.key}}({{trans_precond_args}}) != 0)
			goto entry_precond_fail;
{{endfor}}			break;
{{endif}}{{endfor}}	default:
		break;
	}
{{endif}}{{if event_callbacks}}
	/* Event callbacks */
	switch(ev) {
{{for event in events}}{{if event.value.callbacks}}	case {{event.key}}:
{{for cb in event.value.callbacks}}		{{cb.key}}({{event_cb_args}});
{{endfor}}		break;
{{endif}}{{endfor}}	default:
		break;
	}
{{endif}}{{if transition_exit_callbacks}}
	/* Current state exit callbacks */
	switch(old_state) {
{{for state in states}}{{if state.value.exit_callbacks}}	case {{state.key}}:
{{for cb in state.value.exit_callbacks}}		{{cb.key}}({{trans_cb_args}});
{{endfor}}			break;
{{endif}}{{endfor}}	default:
		break;
	}
{{endif}}
	/* Switch state now */
	fsm->current_state = new_state;
{{if transition_entry_callbacks}}
	/* New state entry callbacks */
	switch(new_state) {
{{for state in states}}{{if state.value.entry_callbacks}}	case {{state.key}}:
{{for cb in state.value.entry_callbacks}}		{{cb.key}}({{trans_cb_args}});
{{endfor}}		break;
{{endif}}{{endfor}}	default:
		break;
	}
{{endif}}
	return CFSM_OK;
{{if transition_entry_preconds}}
 entry_precond_fail:
	if (errlen > 0 && errbuf != NULL) {
		snprintf(errbuf, errlen,
		    "State %s entry precondition not satisfied",
		    {{state_ntop_func}}_safe(new_state));
	}
	return CFSM_ERR_PRECONDITION;
{{endif}}{{if transition_exit_preconds}}
 exit_precond_fail:
	if (errlen > 0 && errbuf != NULL) {
		snprintf(errbuf, errlen,
		    "State %s exit precondition not satisfied",
		    {{state_ntop_func}}_safe(fsm->current_state));
	}
	return CFSM_ERR_PRECONDITION;
{{endif}}{{if event_preconds}}
 event_precond_fail:
	if (errlen > 0 && errbuf != NULL) {
		snprintf(errbuf, errlen,
		    "Event %s entry precondition not satisfied",
		    {{event_ntop_func}}_safe(ev));
	}
	return CFSM_ERR_PRECONDITION;
{{endif}}
 bad_event:
	if (errlen > 0 && errbuf != NULL) {
		snprintf(errbuf, errlen,
		    "Invalid event %s in state %s",
		    {{event_ntop_func}}_safe(ev),
		    {{state_ntop_func}}_safe(fsm->current_state));
	}
	return CFSM_ERR_INVALID_TRANSITION;
}
