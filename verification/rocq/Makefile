COQMAKEFILE := Makefile.rocq

all: $(COQMAKEFILE)
	$(MAKE) -f $(COQMAKEFILE)

real:
	rocq compile -R theory Diana theory/Real/Bisect.v

$(COQMAKEFILE): _CoqProject
	rocq makefile -f _CoqProject -o $(COQMAKEFILE)

clean:
	-$(MAKE) -f $(COQMAKEFILE) cleanall
	rm -f $(COQMAKEFILE) $(COQMAKEFILE).conf

.PHONY: all real clean
