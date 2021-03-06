% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/explanatory_performance.R
\name{Recalibrate}
\alias{Recalibrate}
\title{Regression model recalibration}
\usage{
Recalibrate(
  xdata,
  ydata,
  stability = NULL,
  family = NULL,
  implementation = NULL,
  ...
)
}
\arguments{
\item{xdata}{matrix of predictors with observations as rows and variables as
columns.}

\item{ydata}{optional vector or matrix of outcome(s). If \code{family} is set
to \code{"binomial"} or \code{"multinomial"}, \code{ydata} can be a vector
with character/numeric values or a factor.}

\item{stability}{output of \code{\link{VariableSelection}} or
\code{\link{BiSelection}}. If \code{stability=NULL} (the default), a model
including all variables in \code{xdata} as predictors is fitted. Argument
\code{family} must be provided in this case.}

\item{family}{type of regression model. Possible values include
\code{"gaussian"} (linear regression), \code{"binomial"} (logistic
regression), \code{"multinomial"} (multinomial regression), and
\code{"cox"} (survival analysis). If provided, this argument must be
consistent with input \code{stability}.}

\item{implementation}{optional function to recalibrate the model. If
\code{implementation=NULL} and \code{stability} is the output of
\code{\link{VariableSelection}}, \code{\link[stats]{lm}} (linear
regression), \code{\link[survival]{coxph}} (Cox regression),
\code{\link[stats]{glm}} (logistic regression), or
\code{\link[nnet]{multinom}} (multinomial regression) is used. The function
\code{\link{PLS}} is used for the output of \code{\link{BiSelection}}.}

\item{...}{additional arguments to be passed to the recalibration function
(see \code{implementation}).}
}
\value{
The output as obtained from: \item{\code{\link[stats]{lm}}}{for
  linear regression (\code{"gaussian"} family).}
  \item{\code{\link[survival]{coxph}}}{for Cox regression (\code{"cox"}
  family).} \item{\code{\link[stats]{glm}}}{for logistic regression
  (\code{"binomial"} family).} \item{\code{\link[nnet]{multinom}}}{for
  multinomial regression (\code{"multinomial"} family).}
}
\description{
Recalibrates the regression model with stably selected variables as
predictors (without penalisation). Variables in \code{xdata} not evaluated in
the stability selection model will automatically be included as predictors.
}
\examples{
\donttest{
## Linear regression

# Data simulation
set.seed(1)
simul <- SimulateRegression(n = 100, pk = 50, family = "gaussian")

# Data split
ids_train <- Resample(
  data = simul$ydata,
  tau = 0.5, family = "gaussian"
)
xtrain <- simul$xdata[ids_train, , drop = FALSE]
ytrain <- simul$ydata[ids_train, , drop = FALSE]
xrecalib <- simul$xdata[-ids_train, , drop = FALSE]
yrecalib <- simul$ydata[-ids_train, , drop = FALSE]

# Stability selection
stab <- VariableSelection(xdata = xtrain, ydata = ytrain, family = "gaussian")
print(SelectedVariables(stab))

# Recalibrating the model
recalibrated <- Recalibrate(
  xdata = xrecalib, ydata = yrecalib,
  stability = stab
)
recalibrated$coefficients # recalibrated coefficients
head(recalibrated$fitted.values) # recalibrated predicted values

# Fitting the full model (including all possible predictors)
recalibrated <- Recalibrate(
  xdata = simul$xdata, ydata = simul$ydata,
  family = "gaussian"
)
recalibrated$coefficients # recalibrated coefficients


## Cox regression

# Data simulation
set.seed(1)
simul <- SimulateRegression(n = 100, pk = 50, family = "binomial")
ydata <- cbind(
  time = runif(nrow(simul$ydata), min = 100, max = 2000),
  case = simul$ydata[, 1]
) # including dummy time to event

# Data split
ids_train <- Resample(
  data = ydata,
  tau = 0.5, family = "cox"
)
xtrain <- simul$xdata[ids_train, , drop = FALSE]
ytrain <- ydata[ids_train, , drop = FALSE]
xrecalib <- simul$xdata[-ids_train, , drop = FALSE]
yrecalib <- ydata[-ids_train, , drop = FALSE]

# Stability selection
stab <- VariableSelection(xdata = xtrain, ydata = ytrain, family = "cox")
print(SelectedVariables(stab))

# Recalibrating the model
recalibrated <- Recalibrate(
  xdata = xrecalib, ydata = yrecalib,
  stability = stab
)
recalibrated$coefficients # recalibrated coefficients
head(recalibrated$linear.predictors) # recalibrated scores


## Logistic regression

# Data simulation
set.seed(1)
simul <- SimulateRegression(n = 200, pk = 20, family = "binomial")

# Data split
ids_train <- Resample(
  data = simul$ydata,
  tau = 0.5, family = "binomial"
)
xtrain <- simul$xdata[ids_train, , drop = FALSE]
ytrain <- simul$ydata[ids_train, , drop = FALSE]
xrecalib <- simul$xdata[-ids_train, , drop = FALSE]
yrecalib <- simul$ydata[-ids_train, , drop = FALSE]

# Stability selection
stab <- VariableSelection(xdata = xtrain, ydata = ytrain, family = "binomial")

# Recalibrating the model
recalibrated <- Recalibrate(
  xdata = xrecalib, ydata = yrecalib,
  stability = stab
)
recalibrated$coefficients # recalibrated coefficients
head(recalibrated$fitted.values) # recalibrated predicted probabilities


## Multinomial regression

# Data simulation
set.seed(1)
simul <- SimulateRegression(n = 200, pk = 15, family = "multinomial")

# Data split
ids_train <- Resample(
  data = simul$ydata,
  tau = 0.5, family = "multinomial"
)
xtrain <- simul$xdata[ids_train, , drop = FALSE]
ytrain <- simul$ydata[ids_train, , drop = FALSE]
xrecalib <- simul$xdata[-ids_train, , drop = FALSE]
yrecalib <- simul$ydata[-ids_train, , drop = FALSE]

# Stability selection
stab <- VariableSelection(
  xdata = xtrain, ydata = ytrain,
  family = "multinomial"
)

# Recalibrating the model
recalibrated <- Recalibrate(
  xdata = xrecalib, ydata = yrecalib,
  stability = stab
)
summary(recalibrated) # recalibrated coefficients
head(recalibrated$fitted.values) # recalibrated predicted probabilities


## Partial Least Squares (single component)

# Data simulation
set.seed(1)
simul <- SimulateRegression(n = 100, pk = 50, family = "gaussian")

# Data split
ids_train <- Resample(
  data = simul$ydata,
  tau = 0.5, family = "gaussian"
)
xtrain <- simul$xdata[ids_train, , drop = FALSE]
ytrain <- simul$ydata[ids_train, , drop = FALSE]
xrecalib <- simul$xdata[-ids_train, , drop = FALSE]
yrecalib <- simul$ydata[-ids_train, , drop = FALSE]

# Stability selection
stab <- VariableSelection(
  xdata = xtrain, ydata = ytrain,
  implementation = SparsePLS,
  family = "gaussian"
)
print(SelectedVariables(stab))

# Recalibrating the model
recalibrated <- Recalibrate(
  xdata = xrecalib, ydata = yrecalib,
  implementation = PLS,
  stability = stab
)
recalibrated$Wmat # recalibrated X-weights
head(recalibrated$Tmat) # recalibrated X-scores


## Partial Least Squares (multiple components)

# Data simulation
set.seed(1)
simul <- SimulateRegression(n = 200, pk = c(5, 5, 5), family = "gaussian")

# Data split
ids_train <- Resample(
  data = simul$ydata,
  tau = 0.5, family = "gaussian"
)
xtrain <- simul$xdata[ids_train, , drop = FALSE]
ytrain <- simul$ydata[ids_train, , drop = FALSE]
xrecalib <- simul$xdata[-ids_train, , drop = FALSE]
yrecalib <- simul$ydata[-ids_train, , drop = FALSE]

# Stability selection
stab <- BiSelection(
  xdata = xtrain, ydata = ytrain,
  family = "gaussian", ncomp = 3,
  LambdaX = 1:(ncol(xtrain) - 1),
  LambdaY = 1:(ncol(ytrain) - 1),
  implementation = SparsePLS
)
plot(stab)

# Recalibrating the model
recalibrated <- Recalibrate(
  xdata = xrecalib, ydata = yrecalib,
  stability = stab
)
recalibrated$Wmat # recalibrated X-weights
recalibrated$Cmat # recalibrated Y-weights
}

}
\seealso{
\code{\link{VariableSelection}}
}
