CFLAGS=     -Wall
#CFLAGS+=    -Werror
CFLAGS+=    -Wpointer-arith
CFLAGS+=    -Wno-uninitialized
CFLAGS+=    -Wstrict-prototypes
CFLAGS+=    -Wmissing-prototypes
CFLAGS+=    -Wunused
CFLAGS+=    -Wsign-compare
#CFLAGS+=    -Wbounded
CFLAGS+=    -Wshadow
CFLAGS+=    -Wno-pointer-sign
CFLAGS+=    -Wno-attributes

BINDIR=/usr/local/bin
TEMPLATEDIR=/usr/local/share/cfsm

CFLAGS+=    -g -std=gnu99 -D_GNU_SOURCE
CFLAGS+=    -I.
CFLAGS+=    -DTEMPLATE_DIR=\"$(TEMPLATEDIR)\"

LDFLAGS+= -Lmtemplate
CFLAGS+= -Imtemplate -DYYDEBUG=1
LIBS+= -lmtemplate -ly -ll

RANLIB=ranlib
LEX=lex
YACC=yacc

CFSM_OBJS=cfsm.o cfsm_parse.o cfsm_lex.o
COMPAT_OBJS=strlcat.o strlcpy.o

all: cfsm

cfsm: mtemplate/libmtemplate.a $(CFSM_OBJS) $(COMPAT_OBJS)
	$(CC) -o $@ $(CFSM_OBJS) $(COMPAT_OBJS) $(LDFLAGS) $(LIBS)

cfsm_lex.o: cfsm_parse.h

cfsm_lex.c: cfsm_lex.l
	$(LEX) -o$@ cfsm_lex.l

cfsm_parse.c: cfsm_parse.y
	$(YACC) -d -o$@ cfsm_parse.y

mtemplate/libmtemplate.a:
	@if ! test -f mtemplate/Makefile ; then \
		echo "mtemplate/Makefile missing. Did you forget to run " \
		    "'git submodule init'?"; \
		exit 1; \
	fi
	${MAKE} -C mtemplate

clean:
	rm -f *.o cfsm cfsm_lex.[ch] cfsm_parse.[ch]
	rm -f lex.yy.[ch] y.tab.[ch] core *.core fsm.c fsm.h fsm.dot
	${MAKE} -C regress clean
	${MAKE} -C mtemplate clean

test: all
	${MAKE} -C mtemplate test
	${MAKE} -C regress
