% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dimensionality_reduction.R
\name{PredictPLS}
\alias{PredictPLS}
\title{Partial Least Squares predictions}
\usage{
PredictPLS(xdata, model)
}
\arguments{
\item{xdata}{matrix of predictors with observations as rows and variables as
columns.}

\item{model}{output of \code{\link{PLS}}.}
}
\value{
An array of predicted values.
}
\description{
Computes predicted values from a Partial Least Squares (PLS) model in
regression mode applied on \code{xdata}. This function is using the algorithm
implemented in \code{\link[mixOmics]{predict.pls}}.
}
\examples{
if (requireNamespace("mixOmics", quietly = TRUE)) {
  # Data simulation
  set.seed(1)
  simul <- SimulateRegression(n = 100, pk = c(5, 5, 5), family = "gaussian")
  x <- simul$xdata
  y <- simul$ydata

  # PLS
  mypls <- PLS(xdata = x, ydata = y, ncomp = 3)

  # Predicted values
  predicted <- PredictPLS(xdata = x, model = mypls)
}
}
\seealso{
\code{\link{PLS}}
}
