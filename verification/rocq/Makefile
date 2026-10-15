COQMAKEFILE := Makefile.rocq

all: $(COQMAKEFILE)
	$(MAKE) -f $(COQMAKEFILE)

real:
	rocq compile -R theory Diana theory/Real/Bisection.v
	rocq compile -R theory Diana theory/Real/Quadrature.v
	rocq compile -R theory Diana theory/Real/Trapezoidal.v

check: all
	rocq compile -R theory Diana -Q ../clight Diana.Clight \
	    -w -deprecated-syntactic-definition CheckSpec.v

$(COQMAKEFILE): _CoqProject
	rocq makefile -f _CoqProject -o $(COQMAKEFILE)

clean:
	-$(MAKE) -f $(COQMAKEFILE) cleanall
	rm -f $(COQMAKEFILE) $(COQMAKEFILE).conf
	rm -f CheckSpec.vo CheckSpec.vok CheckSpec.vos CheckSpec.glob .CheckSpec.aux

.PHONY: all real check clean
