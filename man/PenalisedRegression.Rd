% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/penalised_models.R
\name{PenalisedRegression}
\alias{PenalisedRegression}
\title{Penalised regression}
\usage{
PenalisedRegression(xdata, ydata, Lambda = NULL, family, ...)
}
\arguments{
\item{xdata}{matrix of predictors with observations as rows and variables as
columns.}

\item{ydata}{optional vector or matrix of outcome(s). If \code{family} is set
to \code{"binomial"} or \code{"multinomial"}, \code{ydata} can be a vector
with character/numeric values or a factor.}

\item{Lambda}{matrix of parameters controlling the level of sparsity.}

\item{family}{type of regression model. This argument is defined as in
\code{\link[glmnet]{glmnet}}. Possible values include \code{"gaussian"}
(linear regression), \code{"binomial"} (logistic regression),
\code{"multinomial"} (multinomial regression), and \code{"cox"} (survival
analysis).}

\item{...}{additional parameters passed to \code{\link[glmnet]{glmnet}}.}
}
\value{
A list with: \item{selected}{matrix of binary selection status. Rows
  correspond to different model parameters. Columns correspond to
  predictors.} \item{beta_full}{array of model coefficients. Rows correspond
  to different model parameters. Columns correspond to predictors. Indices
  along the third dimension correspond to outcome variable(s).}
}
\description{
Runs penalised regression using implementation from
\code{\link[glmnet]{glmnet}}. This function is not using stability.
}
\examples{
# Data simulation
set.seed(1)
simul <- SimulateRegression(pk = 50)

# Running the LASSO
mylasso <- PenalisedRegression(
  xdata = simul$xdata, ydata = simul$ydata,
  Lambda = c(0.1, 0.2), family = "gaussian"
)

# Using glmnet arguments
mylasso <- PenalisedRegression(
  xdata = simul$xdata, ydata = simul$ydata,
  Lambda = c(0.1), family = "gaussian",
  penalty.factor = c(rep(0, 10), rep(1, 40))
)
mylasso$beta_full
}
\seealso{
\code{\link{SelectionAlgo}}, \code{\link{VariableSelection}}

Other underlying algorithm functions: 
\code{\link{PenalisedGraphical}()}
}
\concept{underlying algorithm functions}
