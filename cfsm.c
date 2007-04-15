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

/* $Id: cfsm.c,v 1.4 2007/04/15 12:24:42 djm Exp $ */

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
char *header_name = NULL;		/* Header file name */

static struct xtemplate *
read_template(const char *template_path)
{
	char *template;
	size_t tlen;
	ssize_t len;
	char buf[8192];
	int tfd;
	struct xtemplate *ret;

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

	if ((ret = xtemplate_parse(template, buf, sizeof(buf))) == NULL)
		errx(1, "xtemplate_parse: %s", buf);

	return ret;
}

static void
render_template(const char *template_path, const char *out_path)
{
	char err_buf[1024];
	FILE *out_file = NULL;
	struct xtemplate *tmpl;

	tmpl = read_template(template_path);
	if (strcmp(out_path, "-") == 0) {
		out_file = stdout;
		out_path = "(stdout)";
	} else if ((out_file = fopen(out_path, "w")) == NULL)
		err(1, "fopen(\"%s\", \"w\")", out_path);
	if (xtemplate_run(tmpl, fsm_namespace, out_file,
		err_buf, sizeof(err_buf)) == -1)
		errx(1, "xtemplate_run: %s", err_buf);
	if (out_file != stdout)
		fclose(out_file);
}

static void
usage(void)
{
	fprintf(stderr,
"Usage: cfsm [-h] [-HCD] [-o output-file] fsm-file\n"
"Command line options:\n"
"    -h              Display this help\n"
"    -d              Generate C header file in addition to source file\n"
"    -D              Only generate C header file (and not a source file)\n"
"    -g              Generate graphviz dot file instead of C source/header\n"
"    -o output_file  Specify output file (default: fsm.[c|h|dot])\n");
}

int
main(int argc, char **argv)
{
	extern char *optarg;
	extern int optind;
	int ch;
	const char *out_path = NULL;
	int output_dot = 0, output_header = 0, output_src = 1;
	size_t len;

	while ((ch = getopt(argc, argv, "Dhdgo:")) != -1) {
		switch (ch) {
		case 'h':
			usage();
			exit(0);
		case 'D':
			output_src = 0;
			output_header = 1;
			break;
		case 'd':
			output_header = 1;
			break;
		case 'g':
			output_src = 0;
			output_dot = 1;
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

	if (output_dot && output_header) {
		warnx("Cannot output Graphviz dot and header simultaneously");
		usage();
		exit(1);
	}

	if (output_src && output_header && out_path != NULL &&
	    strcmp(out_path, "-") == 0) {
		warnx("Cannot specify stdout output when generating both C "
		    "source and header");
		usage();
		exit(1);
	}

	/* Synthesise a header path from the source path */
	if (output_src && (len = strlen(out_path)) >= 2) {
		if (strcmp(out_path + len - 2, ".c") == 0) {
			if ((header_name = strdup(out_path)) == NULL)
				errx(1, "strdup");
			header_name[len - 1] = 'h';
		}
	}

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

	if (output_dot) {
		if (out_path == NULL)
			out_path = DEFAULT_OUT_DOT;
		render_template(TEMPLATE_GRAPHVIZ, out_path);
	}

	if (output_src) {
		if (out_path == NULL)
			out_path = DEFAULT_OUT_C_SRC;
		render_template(TEMPLATE_C_SOURCE, out_path);
	}

	if (output_header) {
		if (out_path == NULL)
			out_path = header_name == NULL ?
			    DEFAULT_OUT_C_HDR : header_name;
		render_template(TEMPLATE_C_HEADER, out_path);
	}

	if (header_name != NULL)
		free(header_name);

	return 0;
}
