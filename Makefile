BAMTOOLS_ROOT=/scratch/ngsvin2/RNA-seq/ruping/Tools/bamtools/
CXX=g++
BAMFLAGS=-lbamtools
CXXFLAGS=-lz -static -Wall -O3
PREFIX=./
SRC=./src
TOOLSB=./tools_binaries_linux_x86_64/
BIN=/bin/
SOURCE_STA=Rseq_bam_stats.cpp
SOURCE_EXP=Rseq_bam_reads2expr.cpp
STA=Rseq_bam_stats
EXP=Rseq_bam_reads2expr

all: Rseq_bam_stats Rseq_bam_reads2expr perl_scripts R_scripts other_tools

.PHONY: all

Rseq_bam_stats:
	@mkdir -p $(PREFIX)/$(BIN)
	@echo "* compiling" $(SOURCE_STA)
	@$(CXX) $(SRC)/$(SOURCE_STA) -o $(PREFIX)/$(BIN)/$(STA) $(BAMFLAGS) $(CXXFLAGS) -I $(BAMTOOLS_ROOT)/include/ -L $(BAMTOOLS_ROOT)/lib/ 

Rseq_bam_reads2expr:
	@echo "* compiling" $(SOURCE_EXP)
	@$(CXX) $(SRC)/$(SOURCE_EXP) -o $(PREFIX)/$(BIN)/$(EXP) $(BAMFLAGS) $(CXXFLAGS) -I $(BAMTOOLS_ROOT)/include/ -L $(BAMTOOLS_ROOT)/lib/

perl_scripts:
	@echo "* copying perl scripts"
	@cp $(SRC)/*.pl $(PREFIX)/$(BIN)/
	@echo "* done."

R_scripts:
	@echo "* copying R scripts"
	@cp $(SRC)/*.R $(PREFIX)/$(BIN)/
	@echo "* done."

other_tools:
	@echo "* copying x86_64 linux binaries of other tools"
	@cp $(TOOLSB)/* $(PREFIX)/$(BIN)/
	@echo "* done."

RTrace:
	@echo "* copying RTrace.pl"
	@cp $(SRC)/RTrace.pl $(PREFIX)/$(BIN)/
	@echo "* done."

html:
	@echo "* copying html report script"
	@cp $(SRC)/html_report.R $(PREFIX)/$(BIN)/
	@echo "* done."

clean:
	@echo "Cleaning up everthing."
	@rm -rf $(PREFIX)/$(BIN)/


.PHONY: clean