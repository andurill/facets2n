% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/facets-cncf.R
\name{fitcncf}
\alias{fitcncf}
\title{Copy number and cellular fraction of segment clusters}
\usage{
fitcncf(out, dipLogR = 0, nX = 23)
}
\arguments{
\item{out}{the out element from procSample fit}

\item{dipLogR}{log-ratio level corresponding to diploid copy number}

\item{nX}{integer value of ChrX; humans 23 (default); mouse 20.}
}
\value{
A data frame with the same columns as out and three additional columns which give the cellular fraction (cf), total copy number (tcn) and lower copy number (lcn) for each segment. If a cluster does not have sufficient heterozygotes the lcn value will be NA.
}
\description{
Copy number and cellular fraction of segment clusters
}
\details{
This function is called internally by procSample. It can be used to refit the model at a different dipLogR value.
}
