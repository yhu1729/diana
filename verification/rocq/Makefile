COQMAKEFILE := Makefile.rocq

all: $(COQMAKEFILE)
	$(MAKE) -f $(COQMAKEFILE)

real:
	rocq compile -R theory Diana theory/Real/Bisection.v
	rocq compile -R theory Diana theory/Real/Cholesky.v
	rocq compile -R theory Diana theory/Real/Quadrature.v
	rocq compile -R theory Diana theory/Real/Vector.v
	rocq compile -R theory Diana theory/Real/OneStep.v
	rocq compile -R theory Diana theory/Real/Euler.v
	rocq compile -R theory Diana theory/Real/Newton.v
	rocq compile -R theory Diana theory/Real/Taylor.v
	rocq compile -R theory Diana theory/Real/RK4.v
	rocq compile -R theory Diana theory/Real/Simpson.v
	rocq compile -R theory Diana theory/Real/Substitution.v
	rocq compile -R theory Diana theory/Real/LU.v
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
