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

/* $Id: cfsm.c,v 1.3 2007/04/15 08:45:58 djm Exp $ */

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

/* From cfsm_parse.y */
extern FILE *yyin;
extern int yyparse(void);
extern void finalise_namespace(void);
extern void setup_initial_namespace(void);
extern struct xdict *fsm_namespace;

/* Exported for use in cfsm_parse.y */
const char *in_path = NULL;		/* Input pathname */
const char *header_name = NULL;		/* Header file name */

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
"    -n header_name  Specify header file name (default: fsm.h)\n"
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

	while ((ch = getopt(argc, argv, "hCDHo:n:")) != -1) {
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
		case 'n':
			header_name = optarg;
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

	setup_initial_namespace();

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

	finalise_namespace();

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
