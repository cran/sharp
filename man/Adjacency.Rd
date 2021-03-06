% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calibration.R
\name{Adjacency}
\alias{Adjacency}
\title{Calibrated adjacency matrix}
\usage{
Adjacency(stability, argmax_id = NULL)
}
\arguments{
\item{stability}{output of \code{\link{GraphicalModel}}.}

\item{argmax_id}{optional matrix of parameter IDs. If \code{argmax_id=NULL},
the calibrated model is used.}
}
\value{
A binary and symmetric adjacency matrix encoding an undirected graph
  with no self-loops.
}
\description{
Extracts the adjacency matrix of the (calibrated) stability selection
graphical model.
}
\examples{
# Data simulation
set.seed(1)
simul <- SimulateGraphical(pk = 20)

# Stability selection
stab <- GraphicalModel(xdata = simul$data)

# Calibrated adjacency matrix
A <- Adjacency(stab)

# User-defined parameters
myids <- matrix(c(20, 10), nrow = 1)
stab$Lambda[myids[1], 1] # corresponding penalty
stab$params$pi_list[myids[2]] # corresponding threshold
A <- Adjacency(stab, argmax_id = myids)
}
\seealso{
\code{\link{GraphicalModel}}

Other calibration functions: 
\code{\link{ArgmaxId}()},
\code{\link{Argmax}()},
\code{\link{CalibrationPlot}()},
\code{\link{SelectedVariables}()},
\code{\link{SelectionProportions}()}
}
\concept{calibration functions}
