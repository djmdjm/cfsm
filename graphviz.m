digraph {{fsm_struct}} {
	rankdir = LR;
	node [shape = doublecircle];
	{{for state in initial_states}}{{state.value}} {{endfor}};
	node [shape = circle];
	{{for state in states}}{{if state.value.is_initial}}{{else}}{{state.value.name}} {{endif}}{{endfor}};
{{if events}}
{{for state in states}}{{for event in state.value.events}}{{if event.value}}	{{state.key}} -> {{event.value}} [ label = "{{event.key}}"];
{{endif}}{{endfor}}{{endfor}}{{else}}
{{for state in states}}{{for next in state.value.next_states}}	{{state.key}} -> {{next.key}};
{{endfor}}{{endfor}}{{endif}}
}
