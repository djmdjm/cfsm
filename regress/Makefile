CFSM=../cfsm
TARGETS=t0 t1 t2 t3

all: $(TARGETS)
	@echo -n "Running tests: "
	@set -e ; for x in $(TARGETS) ; do \
		test "x$(VERBOSE)" = "x" || echo -n $${x} ; \
		./$$x && echo -n . || echo -n '!' ; \
		test "x$(VERBOSE)" = "x" || echo -n ' ' ; \
	done
	@echo ""

# Make sure the example works!
t0_fsm.c: ../example.fsm
	$(CFSM) -C t0_fsm.c -H t0_fsm.h ../example.fsm

t0: t0_fsm.c t0_fsm.o t0.o
	$(CC) -o $@ t0.o t0_fsm.o

t1_fsm.c: t1_fsm.fsm
	$(CFSM) -C t1_fsm.c -H t1_fsm.h t1_fsm.fsm

t1: t1_fsm.c t1_fsm.o t1.o
	$(CC) -o $@ t1.o t1_fsm.o

t2_fsm.c: t2_fsm.fsm
	$(CFSM) -C t2_fsm.c -H t2_fsm.h t2_fsm.fsm

t2: t2_fsm.c t2_fsm.o t2.o
	$(CC) -o $@ t2.o t2_fsm.o

t3_fsm.c: t3_fsm.fsm
	$(CFSM) -C t3_fsm.c -H t3_fsm.h t3_fsm.fsm

t3: t3_fsm.c t3_fsm.o t3.o
	$(CC) -o $@ t3.o t3_fsm.o

clean:
	rm -f *.o *_fsm.[ch] $(TARGETS) *.core core

