/*
 * Copyright (c) Damien Miller <djm@mindrot.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* $Id: cfsm.c,v 1.2 2007/04/15 02:11:17 djm Exp $ */

#include <sys/types.h>
#include <sys/stat.h>

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <err.h>
#include <unistd.h>
#include <fcntl.h>

#include "xtemplate.h"
#include "xobject.h"

#include "cfsm.h"

/*
 * The representation of the FSM that is built during parsing and
 * subsequently used to fill in the template
 */
struct xdict *fsm_namespace;

/* Convencience pointers to commonly-used objects in the namespace */
struct xarray *fsm_initial_states;
struct xarray *fsm_states_array;
struct xarray *fsm_events_array;
struct xdict *fsm_states;
struct xdict *fsm_events;
struct xdict *fsm_event_callbacks;
struct xdict *fsm_event_preconds;
struct xdict *fsm_trans_entry_callbacks;
struct xdict *fsm_trans_entry_preconds;
struct xdict *fsm_trans_exit_callbacks;
struct xdict *fsm_trans_exit_preconds;

u_int lnum = 0;
char *in_path = NULL;

extern int yyparse(void);
extern FILE *yyin;

static char *
read_template(const char *template_path)
{
	char *template;
	size_t tlen;
	ssize_t len;
	char buf[8192];
	int tfd;

	if ((tfd = open(template_path, O_RDONLY)) == -1)
		err(1, "Unable to open template \"%s\" for reading",
		    template_path);

	template = NULL;
	tlen = 0;
	for (;;) {
		if ((len = read(tfd, buf, sizeof(buf))) == -1) {
			if (errno == EINTR || errno == EAGAIN)
				continue;
			err(1, "read");
		}
		if (len == 0)
			break;
		if (tlen + len + 1 < tlen)
			errx(1, "template length exceeds SIZE_T_MAX");
		if ((template = realloc(template, tlen + len + 1)) == NULL)
			errx(1, "realloc(template, %zu) failed",
			    tlen + len + 1);
		memcpy(template + tlen, buf, len);
		*(template + tlen + len) = '\0';
		tlen += len;
	}
	close(tfd);
	return template;
}

static void
usage(void)
{
	fprintf(stderr,
"Usage: cfsm [-h] [-HCD] [-o output-file] fsm-file\n"
"Command line options:\n"
"    -h              Display this help\n"
"    -H              Generate C header file\n"
"    -C              Generate C source file\n"
"    -D              Generate graphviz dot file\n"
"    -o output_file  Specify output file (default: standard output)\n"
"One of -C, -H or -D must be specified\n");
}

int
main(int argc, char **argv)
{
	extern char *optarg;
	extern int optind;
	int ch;
	const char *out_path = NULL, *template_path;
	char *template_text, err_buf[1024];
	FILE *out_file = NULL;
	enum { NOMODE, C_HEADER, C_SOURCE, GRAPHVIZ } out_mode = NOMODE;
	struct xtemplate *compiled_template;
	struct xobject *tmp;
	size_t n;

	while ((ch = getopt(argc, argv, "hCDHo:")) != -1) {
		switch (ch) {
		case 'h':
			usage();
			exit(0);
		case 'C':
			if (out_mode != NOMODE) {
 mode_done:
				warnx("Output mode already specified");
				usage();
				exit(1);
			}
			out_mode = C_SOURCE;
			break;
		case 'H':
			if (out_mode != NOMODE)
				goto mode_done;
			out_mode = C_HEADER;
			break;
		case 'D':
			if (out_mode != NOMODE)
				goto mode_done;
			out_mode = GRAPHVIZ;
			break;
		case 'o':
			out_path = optarg;
			break;
		default:
			warnx("Unrecognised command line option");
			usage();
			exit(1);
		}
	}

	argc -= optind;
	argv += optind;

	if (argc != 1) {
		warnx("No FSM file specified");
		usage();
		exit(1);
	}

	if (out_mode == NOMODE) {
		warnx("No output mode specified");
		usage();
		exit(1);
	}

	if ((fsm_namespace = xdict_new()) == NULL)
		errx(1, "xdict_new failed");

#define DEF_STRING(k, v) do { \
		if (xdict_insert_ss(fsm_namespace, k, v) != 0) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_DICT(k) do { \
		if (xdict_insert_sd(fsm_namespace, k) != 0) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_ARRAY(k) do { \
		if (xdict_insert_sa(fsm_namespace, k) != 0) \
			errx(1, "Default set for \"%s\" failed", k); \
	} while (0)
#define DEF_GET(o, k, c) do { \
		if ((o = (struct c *)xdict_item_s(fsm_namespace, k)) == NULL) \
			errx(1, "Lookup for default \"%s\" failed", k); \
	} while (0)

	/* Set our defaults */
	DEF_STRING("source_banner", "");
	DEF_STRING("header_guard", "XXX");
	DEF_STRING("header_name", "XXX");
	DEF_STRING("event_enum", DEFAULT_EVENT_ENUM);
	DEF_STRING("state_enum", DEFAULT_STATE_ENUM);
	DEF_STRING("fsm_struct", DEFAULT_FSM_STRUCT);
	DEF_STRING("init_func", DEFAULT_INIT_FUNC);
	DEF_STRING("free_func", DEFAULT_FREE_FUNC);
	DEF_STRING("advance_func", DEFAULT_FREE_FUNC);
	DEF_STRING("state_ntop_func", DEFAULT_STATE_NTOP_FUNC);
	DEF_STRING("event_ntop_func", DEFAULT_EVENT_NTOP_FUNC);

	DEF_STRING("event_precond_args", "");
	DEF_STRING("event_precond_args_proto", "void");
	DEF_STRING("trans_precond_args", "");
	DEF_STRING("trans_precond_args_proto", "void");
	DEF_STRING("event_cb_args", "");
	DEF_STRING("event_cb_args_proto", "void");
	DEF_STRING("trans_cb_args", "");
	DEF_STRING("trans_cb_args_proto", "void");

	DEF_ARRAY("events_array");
	DEF_ARRAY("states_array");
	DEF_ARRAY("initial_states");
	DEF_DICT("states");
	DEF_DICT("events");
	DEF_DICT("event_callbacks");
	DEF_DICT("event_preconds");
	DEF_DICT("transition_entry_callbacks");
	DEF_DICT("transition_exit_callbacks");
	DEF_DICT("transition_entry_preconds");
	DEF_DICT("transition_exit_preconds");

	DEF_GET(fsm_states_array, "states_array", xarray);
	DEF_GET(fsm_events_array, "events_array", xarray);
	DEF_GET(fsm_initial_states, "initial_states", xarray);
	DEF_GET(fsm_states, "states", xdict);
	DEF_GET(fsm_events, "events", xdict);
	DEF_GET(fsm_event_callbacks, "event_callbacks", xdict);
	DEF_GET(fsm_event_preconds, "event_preconds", xdict);
	DEF_GET(fsm_trans_entry_callbacks, "transition_entry_callbacks",xdict);
	DEF_GET(fsm_trans_entry_preconds, "transition_entry_preconds", xdict);
	DEF_GET(fsm_trans_exit_callbacks, "transition_exit_callbacks", xdict);
	DEF_GET(fsm_trans_exit_preconds, "transition_exit_preconds", xdict);

	in_path = argv[0];
	if (strcmp(in_path, "-") == 0) {
		yyin = stdin;
		in_path = "(stdin)";
	} else if ((yyin = fopen(in_path, "r")) == NULL)
		err(1, "Could not open \"%s\" for reading)", in_path);

	if (yyparse() != 0)
		errx(1, "Input file \"%s\" had errors", in_path);

	if (yyin != stdin)
		fclose(yyin);

	if ((n = xarray_len(fsm_initial_states)) == 0)
		errx(1, "No initial state defined");
	if (xdict_insert_si(fsm_namespace, "multiple_start_states",
	    n > 1 ? 1 : 0) == -1)
		errx(1, "xdict_insert_s failed");

	if ((n = xarray_len(fsm_states_array)) == 0)
		errx(1, "No states defined");
	if (n == 1)
		errx(1, "Only one state defined");

	if ((tmp = xarray_item(fsm_states_array, 0)) == NULL)
		errx(1, "xarray_item failed");
	if ((tmp = xobject_deepcopy(tmp)) == NULL)
		errx(1, "xobject_deepcopy failed");
	if (xdict_insert_s(fsm_namespace, "min_state_valid", tmp) == -1)
		errx(1, "xdict_insert_s failed");
	if ((tmp = xarray_item(fsm_states_array, n - 1)) == NULL)
		errx(1, "xarray_item failed");
	if ((tmp = xobject_deepcopy(tmp)) == NULL)
		errx(1, "xobject_deepcopy failed");
	if (xdict_insert_s(fsm_namespace, "max_state_valid", tmp) == -1)
		errx(1, "xdict_insert_s failed");

	n = xarray_len(fsm_events_array);
	if (n > 0) {
		if ((tmp = xarray_item(fsm_events_array, 0)) == NULL)
			errx(1, "xarray_item failed");
		if ((tmp = xobject_deepcopy(tmp)) == NULL)
			errx(1, "xobject_deepcopy failed");
		if (xdict_insert_s(fsm_namespace, "min_event_valid", tmp) == -1)
			errx(1, "xdict_insert_s failed");
		if ((tmp = xarray_item(fsm_events_array, n - 1)) == NULL)
			errx(1, "xarray_item failed");
		if ((tmp = xobject_deepcopy(tmp)) == NULL)
			errx(1, "xobject_deepcopy failed");
		if (xdict_insert_s(fsm_namespace, "max_event_valid", tmp) == -1)
			errx(1, "xdict_insert_s failed");
	}

	switch (out_mode) {
	case C_SOURCE:
		template_path = TEMPLATE_C_SOURCE;
		break;
	case C_HEADER:
		template_path = TEMPLATE_C_HEADER;
		break;
	case GRAPHVIZ:
		template_path = TEMPLATE_GRAPHVIZ;
		break;
	default:
		errx(1, "Unknown output mode %d", out_mode);
	}

	if ((template_text = read_template(template_path)) == NULL)
		errx(1, "read_template failed");

	if ((compiled_template = xtemplate_parse(template_text,
	    err_buf, sizeof(err_buf))) == NULL)
		errx(1, "xtemplate_parse: %s", err_buf);

	if (out_path == NULL || strcmp(out_path, "-") == 0) {
		out_file = stdout;
		out_path = "(stdout)";
	} else if ((out_file = fopen(out_path, "w")) == NULL)
		err(1, "fopen(\"%s\")", out_path);

	if (xtemplate_run(compiled_template, fsm_namespace, out_file,
	    err_buf, sizeof(err_buf)) == -1)
		errx(1, "xtemplate_run: %s", err_buf);

	if (out_file != stdout)
		fclose(out_file);

	return 0;
}
