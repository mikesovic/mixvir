% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/id_mutations.R
\name{id_indels}
\alias{id_indels}
\title{ID Indel-based Amino Acid Changes}
\usage{
id_indels(variant.calls, ref)
}
\arguments{
\item{variant.calls}{Data frame with cols POS, REF, ALT, AF, DP. Additional columns will be ignored.}

\item{ref}{reference genome in "MixVir" format (genomic positions repeated for each associated feature they're associated with, etc.)}
}
\value{
Data frame with cols "genomic_pos", "ref_base", "gene", "ref_codon", "ref_AA", "gene_aa_position", "ref_identity", "REF", "ALT", "ALT_freq", "ALT_COUNT", "samp_codon", "samp_AA", "samp_identity", "DP"
}
\description{
Identify amino acid changes associaged with indel variation. Changes associated with SNVs are identified in separate function. Used by call_mutations function.
}
\examples{
id_indels()
}
\keyword{indel}
