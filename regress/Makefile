
TARGETS=t1

all: $(TARGETS)
	@echo -n "Running tests: "
	@(set -e ; for x in $(TARGETS) ; do \
		test "x$(VERBOSE)" = "x" || echo -n $${x} ; \
		./$$x && echo -n . || echo -n '!' ; \
		test "x$(VERBOSE)" = "x" || echo -n ' ' ; \
	done)
	@echo ""

t1_fsm.c: t1_fsm.fsm
	../cfsm -C t1_fsm.c -H t1_fsm.h t1_fsm.fsm

t1: t1_fsm.c t1_fsm.o t1.o
	$(CC) -o $@ t1.o t1_fsm.o

clean:
	rm -f *.o *_fsm.[ch] $(TARGETS)

