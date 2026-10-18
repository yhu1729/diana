COQMAKEFILE := Makefile.rocq
SOURCE := $(filter %.v,$(shell cat _CoqProject))
REAL := $(patsubst %.v,%.vo,$(filter theory/Real/%.v,$(SOURCE)))
FLOAT := $(patsubst %.v,%.vo,$(filter theory/Float/%.v,$(SOURCE)))
CHECK_SPEC := rocq compile -R theory Diana -Q ../clight Diana.Clight \
    -w -deprecated-syntactic-definition CheckSpec.v

all: $(COQMAKEFILE)
	$(MAKE) -f $(COQMAKEFILE)

real: $(COQMAKEFILE)
	$(MAKE) -f $(COQMAKEFILE) $(REAL)

float: $(COQMAKEFILE)
	$(MAKE) -f $(COQMAKEFILE) $(REAL) $(FLOAT)

check: all
	$(CHECK_SPEC)

check_real: real
	$(CHECK_SPEC)

check_float: float
	$(CHECK_SPEC)

$(COQMAKEFILE): _CoqProject
	rocq makefile -f _CoqProject -o $(COQMAKEFILE)

clean:
	-$(MAKE) -f $(COQMAKEFILE) cleanall
	rm -f $(COQMAKEFILE) $(COQMAKEFILE).conf
	rm -f CheckSpec.vo CheckSpec.vok CheckSpec.vos CheckSpec.glob .CheckSpec.aux

.PHONY: all real float check check_real check_float clean
