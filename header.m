{{if source_banner}}{{source_banner}}
{{endif}}/*
 * Automatically generated using the cfsm FSM compiler:
 * http://www.mindrot.org/projects/cfsm/
 */

#ifndef {{header_guard}}
#define {{header_guard}}

#include <sys/types.h>

/*
 * The valid states of the FSM
 */
enum {{state_enum}} {
{{for state in states}}	{{state.key}},
{{endfor}}};

/*
 * Events that may cause state transitions in the FSM
 */
enum {{event_enum}} {
{{for event in events}}	{{event.key}},
{{endfor}}};

/*
 * The FSM object itself.
 */
struct {{fsm_struct}}_transtable;
struct {{fsm_struct}} {
	enum {{state_enum}} current_state;
	const struct {{fsm_struct}}_transtable *transition_table;
};

/*
 * Possible error return values
 */
#ifndef CFSM_OK
# define CFSM_OK			0
# define CFSM_ERR_INVALID_STATE		-1
# define CFSM_ERR_INVALID_EVENT		-2
# define CFSM_ERR_INVALID_TRANSITION	-3
# define CFSM_ERR_PRECONDITION		-4
#endif /* CFSM_OK */

{{if multiple_start_states}}/*
 * Initialise a FSM and set its starting state to "initial_state".
 * Will return 0 on success or a CFSM_ERR_* code on failure. 
 * If "errbuf" is not NULL, upto "errlen" bytes of error message
 * will be copied into "errbuf" on failure.
 */
int {{init_func}}(struct {{fsm_struct}} *fsm, enum {{state_enum}} initial_state,
    char *errbuf, size_t errlen);
{{else}}/*
 * Initialise a FSM and set its starting state to {{initial_states[0]}}
 * Will return 0 on success or a CFSM_ERR_* code on failure. 
 * If "errbuf" is not NULL, upto "errlen" bytes of error message
 * will be copied into "errbuf" on failure.
 */
int {{init_func}}(struct {{fsm_struct}} *fsm, char *errbuf, size_t errlen);
{{endif}}

/*
 * Execute a pre-defined event on the FSM that may trigger a transition.
{{if need_ctx}} * The "ctx" argument is a caller-specified context pointer that
 * may be used to pass additional state to precondition, event and transition
 * callback functions.
 *{{endif}}
 * Will return CFSM_OK on success or one of the CFSM_ERR_* codes on failure.
 * If "errbuf" is not NULL, upto "errlen" bytes of error message will be 
 * copied into "errbuf" on failure.
 */
int {{advance_func}}(struct {{fsm_struct}} *fsm, enum {{event_enum}} ev,
    {{if need_ctx}}void *ctx, {{endif}}char *errbuf, size_t errlen);

/*
 * Convert from the %(event_enum)s enumeration to a string. Will return
 * NULL if the event is not known.
 */
const char *{{event_ntop_func}}(enum {{event_enum}});

/*
 * "Safe" version of %(event_enum_to_string_func)s. Will return the string
 * "[INVALID]" if the event is not known, so it can be used directly
 * in printf() statements, etc.
 */
const char *{{event_ntop_func}}_safe(enum {{event_enum}});

/*
 * Convert from the {{state_enum}} enumeration to a string. Will return
 * NULL if the state is not known.
 */
const char *{{state_ntop_func}}(enum {{state_enum}} n);

/*
 * "Safe" version of {{state_ntop_func}}(). Will return the string
 * "[INVALID]" if the state is not known, so it can be used directly
 * in printf() statements or other contexts where a NULL may be harmful.
 */
const char *{{state_ntop_func}}_safe(enum {{state_enum}} n);

/*
 * Returns the current state of the FSM.
 */
enum {{state_enum}} {{current_state_func}}(struct {{fsm_struct}} *fsm);

#endif /* {{header_guard}} */
