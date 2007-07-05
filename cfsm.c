/*
 * Copyright (c) 2007 Damien Miller <djm@mindrot.org>
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

/* $Id: cfsm.c,v 1.11 2007/07/05 02:00:55 djm Exp $ */

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

#include "mtemplate.h"
#include "mobject.h"
#include "strlcpy.h"
#include "strlcat.h"

#include "cfsm.h"

/* From cfsm_parse.y */
extern FILE *yyin;
extern int yyparse(void);
extern void finalise_namespace(void);
extern void setup_initial_namespace(void);
extern struct mobject *fsm_namespace;

/* Exported for use in cfsm_parse.y */
const char *in_path = NULL;		/* Input pathname */
char *header_name = NULL;		/* Header file name */

static struct mtemplate *
read_template(const char *template_dir, const char *template_name)
{
	char *template;
	size_t tlen;
	ssize_t len;
	char buf[8192];
	int tfd;
	struct mtemplate *ret;

	if ((tlen = strlcpy(buf, template_dir, sizeof(buf))) >= sizeof(buf))
		errx(1, "Template path too long");
	if (tlen > 0 && buf[tlen - 1] != '/') {
		if (tlen + 2 >= sizeof(buf))
			errx(1, "Template path too long");
		buf[tlen++] = '/';
		buf[tlen++] = '\0';
	}
	if ((tlen = strlcat(buf, template_name, sizeof(buf))) >= sizeof(buf))
		errx(1, "Template path too long");

	if ((tfd = open(buf, O_RDONLY)) == -1)
		err(1, "Unable to open template \"%s\" for reading", buf);

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

	if ((ret = mtemplate_parse(template, buf, sizeof(buf))) == NULL)
		errx(1, "mtemplate_parse: %s", buf);

	return ret;
}

static void
render_template(const char *template_dir, const char *template_path,
    const char *out_arg)
{
	char err_buf[1024];
	FILE *out_file = NULL;
	struct mtemplate *tmpl;

	tmpl = read_template(template_dir, template_path);
	if (strcmp(out_arg, "-") == 0) {
		out_file = stdout;
		out_arg = "(stdout)";
	} else if ((out_file = fopen(out_arg, "w")) == NULL)
		err(1, "fopen(\"%s\", \"w\")", out_arg);
	if (mtemplate_run_stdio(tmpl, fsm_namespace, out_file,
		err_buf, sizeof(err_buf)) == -1)
		errx(1, "mtemplate_run_stdio: %s", err_buf);
	if (out_file != stdout)
		fclose(out_file);
}

static void
usage(void)
{
	fprintf(stderr,
"Usage: cfsm [-h] [-HCD] [-o output-file] fsm-file\n"
"Command line options:\n"
"    -h               Display this help\n"
"    -d               Generate C header file in addition to source file\n"
"    -D               Only generate C header file (and not a source file)\n"
"    -g               Generate Graphviz dot file instead of C source/header\n"
"    -m template_file \"Manual\" output mode using user-supplied template\n"
"    -o output_file   Specify output file (default: fsm.[c|h|dot])\n"
"    -t template_dir  Specify path to C and Graphviz templates\n");
}

int
main(int argc, char **argv)
{
	extern char *optarg;
	extern int optind;
	int ch;
	const char *manual_arg = NULL, *out_arg = NULL, *out;
	const char *template_dir = TEMPLATE_DIR;
	int output_dot = 0, output_header = 0, output_src = 1;
	size_t len;

	while ((ch = getopt(argc, argv, "Dhdgm:o:t:")) != -1) {
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
		case 'm':
			output_src = 0;
			manual_arg = optarg;
			break;
		case 'o':
			out_arg = optarg;
			break;
		case 't':
			template_dir = optarg;
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

	if (output_dot + output_header + (manual_arg != NULL ? 1 : 0) > 1) {
		warnx("Please select only one of -D, -g and -m");
		usage();
		exit(1);
	}

	if (manual_arg != NULL && out_arg == NULL) {
		warnx("An output path (-o) must be specified in manual mode");
		usage();
		exit(1);
	}

	if (output_src && output_header && out_arg != NULL &&
	    strcmp(out_arg, "-") == 0) {
		warnx("Cannot specify stdout output when generating both C "
		    "source and header");
		usage();
		exit(1);
	}

	/* Synthesise a header path from the source path */
	if (output_src && out_arg != NULL && (len = strlen(out_arg)) >= 2) {
		if (strcmp(out_arg + len - 2, ".c") == 0) {
			if ((header_name = strdup(out_arg)) == NULL)
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
		out = out_arg == NULL ? DEFAULT_OUT_DOT : out_arg;
		warnx("Writing Graphviz dot to \"%s\"", out);
		render_template(template_dir, TEMPLATE_GRAPHVIZ, out);
	}

	if (output_src) {
		out = out_arg == NULL ? DEFAULT_OUT_C_SRC : out_arg;
		warnx("Writing C source to \"%s\"", out);
		render_template(template_dir, TEMPLATE_C_SOURCE, out);
	}

	if (output_header) {
		if (header_name != NULL)
			out = header_name;
		else
			out = out_arg == NULL ? DEFAULT_OUT_C_HDR : out_arg;
		warnx("Writing C header to \"%s\"", out);
		render_template(template_dir, TEMPLATE_C_HEADER, out);
	}

	if (manual_arg != NULL) {
		warnx("Rendering template \"%s\" to \"%s\"",
		    manual_arg, out_arg);
		render_template("", manual_arg, out_arg);
	}

	if (header_name != NULL)
		free(header_name);

	return 0;
}
