# This Makefile is used to build gnat2why and gnatprove, and to install these
# tools.
#
# To build gnat2why, you need a working GNAT compiler and a symbolic link in
# gnat_backends/gnat_src that points to the GNAT sources.
#
# To build gnatprove, you additionnally need an installation of the gnatcoll
# library.
#
# For gnatprove to work, you also need working installations of Why and
# Alt-Ergo. The directory why-patches contains a README file with information
# on how to install those.
#
# The necessary steps to correctly install gnat2why/gnatprove are
#
# 1) make
#
#    This will build gnatprove and gnat2why
#
# 2) make stdlib
#
#    This will apply gnat2why to the standard library of GNAT to obtain
#    precompiled Why files
#
# 3) make install-stdlib WHYLIB=$WHYLIB
#
#    This will copy the files generated in the previous step to the directory
#    of the Why library.
#
# 4) Put the directory install/bin in your path:
#	export PATH=<path_to_hilite_repo>/install/bin:$PATH

.PHONY: clean doc gnat1why gnat2why gnatprove stdlib install-stdlib

# default for WHYLIB, should not be used
WHYLIB=/usr/local/lib/why

ADAINCLUDE=$(shell gnatls -v | grep adainclude)
GNAT_ROOT=$(shell echo $(ADAINCLUDE) | sed -e 's!\(.*\)/lib/gcc/\(.*\)!\1!')
DOC=install/share/doc/gnatprove
LIB=install/lib/gnatprove
EXAMPLES=install/share/examples/gnatprove
STDLIB_TMP=stdlib_tmp

all: gnat2why gnatprove

all-nightly: gnat1why gnatprove local-stdlib install-stdlib install-examples

doc:
	$(MAKE) -C docs/ug latexpdf
	$(MAKE) -C docs/ug html
	mkdir -p $(DOC)/pdf
	cp -p docs/ug/_build/latex/gnatprove_ug.pdf $(DOC)/pdf
	cp -pr docs/ug/_build/html $(DOC)
	$(MAKE) -C docs/ug clean

gnat1why:
	$(MAKE) -C gnat_backends/why/xgen
	$(MAKE) -C gnat_backends/why gnat1 gnat2why

gnat2why:
	$(MAKE) -C gnat_backends/why/xgen
	$(MAKE) -C gnat_backends/why

gnatprove:
	$(MAKE) -C gnatprove

local-stdlib:
	rm -rf $(STDLIB_TMP)
	mkdir -p $(STDLIB_TMP)
	cp Makefile.libprove $(STDLIB_TMP)
	$(MAKE) -C $(STDLIB_TMP) -f Makefile.libprove ROOT=$(GNAT_ROOT) \
	GNAT2WHY="../install/bin/gnat2why -B ../install/bin -I $(ADAINCLUDE)"

stdlib:
	rm -rf $(STDLIB_TMP)
	mkdir -p $(STDLIB_TMP)
	cp Makefile.libprove $(STDLIB_TMP)
	$(MAKE) -C $(STDLIB_TMP) -f Makefile.libprove ROOT=$(GNAT_ROOT)

stdlib-check:
	$(MAKE) -C $(STDLIB_TMP) -f Makefile.libprove ROOT=$(GNAT_ROOT) check -k

install-stdlib:
	mkdir -p $(LIB)
	cp $(STDLIB_TMP)/*.ali $(LIB)
	cp $(STDLIB_TMP)/*__types_vars_spec.mlw \
           $(STDLIB_TMP)/*__types_vars_body.mlw \
	   $(STDLIB_TMP)/*__subp_spec.mlw \
	   $(STDLIB_TMP)/_standard.mlw \
	   $(WHYLIB)/why
	cp why/lib/_gnatprove_standard.why $(WHYLIB)/why

install-examples:
	mkdir -p $(EXAMPLES)
	cp -r dist-examples/* $(EXAMPLES)

clean:
	$(MAKE) -C gnat_backends/why/xgen clean
	$(MAKE) -C gnat_backends/why clean
	$(MAKE) -C gnatprove clean
	$(MAKE) -C docs/ug clean
