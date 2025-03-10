% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_codons.R
\name{get_codons}
\alias{get_codons}
\title{Get Codons From Gene Sequence}
\usage{
get_codons(gene.seq)
}
\arguments{
\item{gene.seq}{Character vector containing gene sequence}
}
\description{
Group a gene sequence into codons (triplets) that can be used for subsequent translation. If any elements of the character vector have length >1, they are trimmed to the first base. Primarily used by id.snps and id.indels functions.
}
\examples{
get_codons()
}
\keyword{codons}
