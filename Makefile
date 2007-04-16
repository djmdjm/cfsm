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
#CFLAGS+=    -Wno-pointer-sign
#CFLAGS+=    -Wno-attributes

BINDIR=/usr/local/bin
TEMPLATEDIR=/usr/local/share/cfsm

CFLAGS+=    -g -std=gnu99 -D_GNU_SOURCE
CFLAGS+=    -I.
CFLAGS+=    -DTEMPLATE_DIR=\"$(TEMPLATEDIR)\"

LDFLAGS+= -L../xobject -L../xtemplate
CFLAGS+= -I../xobject -I../xtemplate -DYYDEBUG=1
LIBS+= -lxtemplate -lxobject -ly -ll

RANLIB=ranlib
LEX=lex
YACC=yacc

all: cfsm

cfsm: cfsm.o cfsm_parse.o cfsm_lex.o strlcat.o
	$(CC) -o $@ cfsm.o cfsm_parse.o cfsm_lex.o strlcat.o $(LDFLAGS) $(LIBS)

cfsm_lex.o: cfsm_parse.h

cfsm_lex.c: cfsm_lex.l
	$(LEX) -o$@ cfsm_lex.l

cfsm_parse.c: cfsm_parse.y
	$(YACC) -d -o$@ cfsm_parse.y

clean:
	rm -f *.o cfsm_xxx cfsm_lex.[ch] cfsm_parse.[ch]
	rm -f lex.yy.[ch] y.tab.[ch] core *.core
	cd regress && make clean

test: all
	cd regress && make
