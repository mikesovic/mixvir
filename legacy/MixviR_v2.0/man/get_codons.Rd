% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_codons.R
\name{get_codons}
\alias{get_codons}
\title{Get Codons From Gene Sequence}
\usage{
get_codons(gene.seq)
}
\arguments{
\item{gene.seq}{Character vector containing gene sequence, with length of vector equal to length of sequence.}
}
\description{
Group a gene sequence into codons (triplets) that can be used for subsequent translation. If any elements of the character vector have length >1 (insertions in ALT column of VCF), they are trimmed to the first base. Used by id.snps, id.indels, and create_ref functions.
}
\examples{
get_codons()
}
\keyword{codons}
