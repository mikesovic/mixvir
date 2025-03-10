## Summary

*MixviR* is an R package designed to help analyze, explore, and visualize high-throughput genomic data from samples that may contain mixed lineages of a given microbial taxon. It 
was originally developed to analyze SARS-CoV-2 environmental (wastewater) samples, but can be applied to samples from any microbial taxon. It uses vcf-formatted input files along with reference genomic information to identify genetic variants (both at the DNA and amino acid level), and if provided optional input information about lineage-characteristic mutations, can estimate frequencies of target lineages within samples. 

## Installation

### CRAN

*MixviR* is available from CRAN and can be installed from within R with...
install.packages("MixviR")

### GitHub
devtools::install_github("mikesovic/MixviR/MixviR_X.Y.Z")


## Usage

Most *MixviR* analyses will start by running the *call_mutations()* function, which requires a directory storing one or more vcf files, a 
fasta-formatted reference genome file, and an annotation file associated with the reference genome that defines genes/open reading 
frames. 
If analyzing SARS-CoV-2, a pre-consructed reference object is available (based on the Wuhan reference) and can be specified with 
*reference = "Wuhan"*, meaning the sample vcf(s) are the only required input.

The *call_mutations()* function produces a data frame that can be saved as an object and/or written to a file, and that is used as input 
for the *explore_mutations()* and *estimate_lineages()* functions.

## Getting Help

Aside from the vignette associated with the program, we encourage you to use the [MixviR Google Group](https://groups.google.com/g/mixvir) to get help with 
the program. 
