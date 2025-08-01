#' Penalised regression
#'
#' Runs penalised regression using implementation from
#' \code{\link[glmnet]{glmnet}}. This function is not using stability.
#'
#' @inheritParams VariableSelection
#' @param Lambda matrix of parameters controlling the level of sparsity.
#' @param penalisation type of penalisation to use. If
#'   \code{penalisation="classic"} (the default), penalised regression is done
#'   with the same regularisation parameter, or using \code{penalty.factor}, if
#'   specified. If \code{penalisation="randomised"}, the regularisation for each
#'   of the variables is uniformly chosen between \code{lambda} and
#'   \code{lambda/gamma}. If \code{penalisation="adaptive"}, the regularisation
#'   for each of the variables is weighted by \code{1/abs(beta)^gamma} where
#'   \code{beta} is the regression coefficient obtained from unpenalised
#'   regression.
#' @param gamma parameter for randomised or adaptive regularisation. Default is
#'   \code{gamma=0.5} for randomised regularisation and \code{gamma=2} for
#'   adaptive regularisation. The parameter \code{gamma} should be between
#'   \code{0} and \code{1} for randomised regularisation.
#' @param ... additional parameters passed to \code{\link[glmnet]{glmnet}}.
#'
#' @return A list with: \item{selected}{matrix of binary selection status. Rows
#'   correspond to different model parameters. Columns correspond to
#'   predictors.} \item{beta_full}{array of model coefficients. Rows correspond
#'   to different model parameters. Columns correspond to predictors. Indices
#'   along the third dimension correspond to outcome variable(s).}
#'
#' @family underlying algorithm functions
#' @seealso \code{\link{SelectionAlgo}}, \code{\link{VariableSelection}}
#'
#' @references \insertRef{AdaptiveLasso}{sharp}
#'
#'   \insertRef{lasso}{sharp}
#'
#' @examples
#' # Data simulation
#' set.seed(1)
#' simul <- SimulateRegression(pk = 50)
#'
#' # Running the LASSO
#' mylasso <- PenalisedRegression(
#'   xdata = simul$xdata, ydata = simul$ydata,
#'   Lambda = c(0.1, 0.2), family = "gaussian"
#' )
#'
#' # Using glmnet arguments
#' mylasso <- PenalisedRegression(
#'   xdata = simul$xdata, ydata = simul$ydata,
#'   Lambda = c(0.1), family = "gaussian",
#'   penalty.factor = c(rep(0, 10), rep(1, 40))
#' )
#' mylasso$beta_full
#' @export
PenalisedRegression <- function(xdata, ydata, Lambda = NULL, family,
                                penalisation = c("classic", "randomised", "adaptive"),
                                gamma = NULL,
                                ...) {
  # Checking that input data are matrices
  xdata <- as.matrix(xdata)
  ydata <- as.matrix(ydata)

  # Defining the type of penalised regression
  penalisation <- match.arg(penalisation)

  # Setting the default gamma
  if (is.null(gamma)) {
    gamma <- switch(penalisation,
      classic = NULL,
      randomised = 0.5,
      adaptive = 2
    )
  }

  # Storing extra arguments
  extra_args <- list(...)

  # Preparing the data for randomised lasso
  if (penalisation == "randomised") {
    xdata <- t(t(xdata) * stats::runif(ncol(xdata), min = gamma, max = 1))
  }

  # Preparing the data for adaptive lasso
  if (penalisation == "adaptive") {
    # Running unpenalised model to get the weights
    if (family == "multinomial") {
      # Extracting relevant extra arguments (excluding penalty.factor here)
      tmp_extra_args <- MatchingArguments(extra_args = extra_args, FUN = glmnet::glmnet)
      tmp_extra_args <- tmp_extra_args[!names(tmp_extra_args) %in% c("x", "y", "lambda", "standardize", "family", "type.multinomial", "penalty.factor")]

      # Running model
      myweights <- stats::coef(do.call(glmnet::glmnet, args = c(
        list(
          x = xdata,
          y = ydata,
          family = family,
          lambda = 0,
          standardize = FALSE,
          # thresh = 1e-15,
          type.multinomial = "grouped"
        ),
        tmp_extra_args
      )))[-1, 1]
    } else {
      # Extracting relevant extra arguments (excluding penalty.factor here)
      tmp_extra_args <- MatchingArguments(extra_args = extra_args, FUN = glmnet::glmnet)
      tmp_extra_args <- tmp_extra_args[!names(tmp_extra_args) %in% c("x", "y", "lambda", "family", "penalty.factor")]

      # Running model
      myweights <- stats::coef(do.call(glmnet::glmnet, args = c(
        list(
          x = xdata,
          y = ydata,
          lambda = 0,
          standardize = FALSE,
          # thresh = 1e-15, # could cause convergence issues
          family = family
        ),
        tmp_extra_args
      )))[-1, 1]
    }

    # Using the weights as penalty factors
    myweights <- 1 / (abs(myweights)^gamma)
    if ("penalty.factor" %in% names(extra_args)) {
      extra_args$penalty.factor <- extra_args$penalty.factor * myweights
    } else {
      extra_args$penalty.factor <- myweights
    }
  }

  # Running the regression
  if (family == "multinomial") {
    # Extracting relevant extra arguments
    tmp_extra_args <- MatchingArguments(extra_args = extra_args, FUN = glmnet::glmnet)
    tmp_extra_args <- tmp_extra_args[!names(tmp_extra_args) %in% c("x", "y", "lambda", "standardize", "family", "type.multinomial")]

    # Running model
    mymodel <- do.call(glmnet::glmnet, args = c(
      list(
        x = xdata,
        y = ydata,
        family = family,
        lambda = Lambda,
        standardize = FALSE,
        type.multinomial = "grouped"
      ),
      tmp_extra_args
    ))
  } else {
    # Extracting relevant extra arguments
    tmp_extra_args <- MatchingArguments(extra_args = extra_args, FUN = glmnet::glmnet)
    tmp_extra_args <- tmp_extra_args[!names(tmp_extra_args) %in% c("x", "y", "lambda", "standardize", "family")]

    # Running model
    mymodel <- do.call(glmnet::glmnet, args = c(
      list(
        x = xdata,
        y = ydata,
        lambda = Lambda,
        standardize = FALSE,
        family = family
      ),
      tmp_extra_args
    ))
  }

  if (!is.infinite(mymodel$lambda[1])) {
    # Extracting and formatting the beta coefficients
    if (!family %in% c("mgaussian", "multinomial")) {
      if (length(Lambda) > 1) {
        mybeta <- suppressWarnings({
          do.call(stats::coef,
            args = c(list(object = mymodel, s = Lambda, exact = TRUE, x = xdata, y = ydata), tmp_extra_args)
          )
        })
      } else {
        mybeta <- suppressWarnings({
          stats::coef(mymodel, s = Lambda)
        })
      }
      mybeta <- t(as.matrix(mybeta))

      # Preparing the outputs
      beta_full <- mybeta[, colnames(xdata), drop = FALSE] # removing the intercept if included
      if ("penalty.factor" %in% names(extra_args)) {
        selected <- ifelse(mybeta[, colnames(xdata)[which(extra_args$penalty.factor != 0)], drop = FALSE] != 0, yes = 1, no = 0)
      } else {
        selected <- ifelse(mybeta[, colnames(xdata), drop = FALSE] != 0, yes = 1, no = 0)
      }
    } else {
      if (family == "mgaussian") {
        if (is.null(names(Lambda))) {
          names(Lambda) <- paste0("s=", Lambda)
        }
        mybeta <- array(NA,
          dim = c(length(Lambda), ncol(xdata), ncol(ydata)),
          dimnames = list(names(Lambda), colnames(xdata), colnames(ydata))
        )
        if (length(Lambda) > 1) {
          tmpcoefs <- suppressWarnings({
            do.call(stats::coef,
              args = c(list(object = mymodel, s = Lambda, exact = TRUE, x = xdata, y = ydata), tmp_extra_args)
            )
          })
        } else {
          tmpcoefs <- suppressWarnings({
            stats::coef(mymodel, s = Lambda)
          })
        }
        for (y_id in colnames(ydata)) {
          tmpbeta <- tmpcoefs[[y_id]]
          tmpbeta <- t(as.matrix(tmpbeta))
          tmpbeta <- tmpbeta[, colnames(xdata), drop = FALSE] # removing the intercept if included
          mybeta[rownames(tmpbeta), colnames(tmpbeta), y_id] <- tmpbeta
        }
      }
      if (family == "multinomial") {
        y_levels <- as.character(sort(unique(ydata)))
        if (is.null(names(Lambda))) {
          names(Lambda) <- paste0("s=", Lambda)
        }
        mybeta <- array(NA,
          dim = c(length(Lambda), ncol(xdata), length(y_levels)),
          dimnames = list(names(Lambda), colnames(xdata), y_levels)
        )
        if (length(Lambda) > 1) {
          tmpcoefs <- suppressWarnings({
            do.call(stats::coef,
              args = c(list(object = mymodel, s = Lambda, exact = TRUE, x = xdata, y = ydata), tmp_extra_args)
            )
          })
        } else {
          tmpcoefs <- suppressWarnings({
            stats::coef(mymodel, s = Lambda)
          })
        }
        for (y_id in y_levels) {
          tmpbeta <- tmpcoefs[[y_id]]
          tmpbeta <- t(as.matrix(tmpbeta))
          tmpbeta <- tmpbeta[, colnames(xdata), drop = FALSE] # removing the intercept if included
          mybeta[rownames(tmpbeta), colnames(tmpbeta), y_id] <- tmpbeta
        }
      }

      # Preparing the outputs
      if ("penalty.factor" %in% names(extra_args)) {
        selected <- ifelse(abind::adrop(mybeta[, colnames(xdata)[which(extra_args$penalty.factor != 0)], 1, drop = FALSE], drop = 3) != 0, yes = 1, no = 0)
      } else {
        selected <- ifelse(abind::adrop(mybeta[, , 1, drop = FALSE], drop = 3) != 0, yes = 1, no = 0)
      }
      beta_full <- mybeta
    }
  } else {
    # Returning infinite beta is the model failed
    selected <- beta_full <- Inf
  }

  return(list(selected = selected, beta_full = beta_full))
}


#' Graphical LASSO
#'
#' Runs the graphical LASSO algorithm for estimation of a Gaussian Graphical
#' Model (GGM). This function is not using stability.
#'
#' @inheritParams GraphicalModel
#' @param xdata matrix with observations as rows and variables as columns.
#' @param Lambda matrix of parameters controlling the level of sparsity.
#' @param Sequential_template logical matrix encoding the type of procedure to
#'   use for data with multiple blocks in stability selection graphical
#'   modelling. For multi-block estimation, the stability selection model is
#'   constructed as the union of block-specific stable edges estimated while the
#'   others are weakly penalised (\code{TRUE} only for the block currently being
#'   calibrated and \code{FALSE} for other blocks). Other approaches with joint
#'   calibration of the blocks are allowed (all entries are set to \code{TRUE}).
#' @param output_omega logical indicating if the estimated precision matrices
#'   should be stored and returned.
#' @param ... additional parameters passed to the function provided in
#'   \code{implementation}.
#'
#' @return An array with binary and symmetric adjacency matrices along the third
#'   dimension.
#'
#' @family underlying algorithm functions
#' @seealso \code{\link{GraphicalModel}}
#'
#' @references \insertRef{GraphicalLassoTibshirani}{sharp}
#'
#' @details The use of the procedure from Equation (4) or (5) is controlled by
#'   the argument "Sequential_template".
#'
#' @examples
#' # Data simulation
#' set.seed(1)
#' simul <- SimulateGraphical()
#'
#' # Running graphical LASSO
#' myglasso <- PenalisedGraphical(
#'   xdata = simul$data,
#'   Lambda = matrix(c(0.1, 0.2), ncol = 1)
#' )
#'
#' # Returning estimated precision matrix
#' myglasso <- PenalisedGraphical(
#'   xdata = simul$data,
#'   Lambda = matrix(c(0.1, 0.2), ncol = 1),
#'   output_omega = TRUE
#' )
#' @export
PenalisedGraphical <- function(xdata, pk = NULL, Lambda, Sequential_template = NULL,
                               scale = TRUE, start = "cold", output_omega = FALSE, ...) {
  # Checking arguments
  if (!is.matrix(Lambda)) {
    Lambda <- matrix(Lambda, ncol = 1)
  }
  if (is.null(pk)) {
    pk <- ncol(xdata)
  }

  # Storing extra arguments
  extra_args <- list(...)

  # Create matrix with block indices
  bigblocks <- BlockMatrix(pk)
  bigblocks_vect <- bigblocks[upper.tri(bigblocks)]
  N_blocks <- unname(table(bigblocks_vect))
  blocks <- unique(as.vector(bigblocks_vect))
  names(N_blocks) <- blocks
  nblocks <- max(blocks)

  if (is.null(Sequential_template)) {
    Sequential_template <- BlockLambdaGrid(Lambda = Lambda)$Sequential_template
  }

  # Initialisation of array storing adjacency matrices
  adjacency <- array(NA, dim = c(ncol(xdata), ncol(xdata), nrow(Lambda)))
  if (output_omega) {
    omega_full <- adjacency
  }

  for (k in seq_len(nrow(Lambda))) {
    # Creating penalisation matrix
    if (nblocks > 1) {
      lambdamat <- bigblocks
      for (b in seq_len(nblocks)) {
        lambdamat[bigblocks == b] <- Lambda[k, b]
      }
    } else {
      lambdamat <- Lambda[k, 1]
    }

    # Estimation of the covariance
    if (scale) {
      cov_sub <- stats::cor(xdata)
    } else {
      cov_sub <- stats::cov(xdata)
    }

    # Extracting relevant extra arguments
    tmp_extra_args <- MatchingArguments(extra_args = extra_args, FUN = glassoFast::glassoFast)
    tmp_extra_args <- tmp_extra_args[!names(tmp_extra_args) %in% c("S", "rho", "start", "w.init", "wi.init")] # avoid duplicates and args that cannot be manually set (related to warm start)

    # Estimation of the sparse inverse covariance
    if ((start == "warm") & (k != 1)) {
      if (all(which(Sequential_template[k, ]) == which(Sequential_template[k - 1, ]))) {
        # Warm start using
        g_sub <- do.call(glassoFast::glassoFast, args = c(
          list(
            S = cov_sub, rho = lambdamat,
            start = "warm", w.init = sigma, wi.init = omega
          ),
          tmp_extra_args
        ))
      } else {
        # Cold start if first iteration for the block
        g_sub <- do.call(glassoFast::glassoFast, args = c(
          list(S = cov_sub, rho = lambdamat),
          tmp_extra_args
        ))
      }
    } else {
      # Cold start
      g_sub <- do.call(glassoFast::glassoFast, args = c(
        list(S = cov_sub, rho = lambdamat),
        tmp_extra_args
      ))
    }
    omega <- g_sub$wi
    sigma <- g_sub$w

    # Creating adjacency matrix
    A <- ifelse(omega != 0, yes = 1, no = 0)
    A <- A + t(A)
    A <- ifelse(A != 0, yes = 1, no = 0)
    diag(A) <- 0

    adjacency[, , k] <- A

    if (output_omega) {
      omega_full[, , k] <- omega
    }
  }

  if (output_omega) {
    return(list(adjacency = adjacency, omega = omega_full))
  } else {
    return(list(adjacency = adjacency))
  }
}


#' Penalised Structural Equation Model
#'
#' Runs penalised Structural Equation Modelling using implementations from
#' \code{\link[OpenMx]{OpenMx}} functions (for \code{\link{PenalisedOpenMx}}),
#' or using series of penalised regressions with \code{\link[glmnet]{glmnet}}
#' (for \code{\link{PenalisedLinearSystem}}). The function
#' \code{\link{PenalisedLinearSystem}} does not accommodate latent variables.
#' These functions are not using stability.
#'
#' @inheritParams StructuralModel
#' @param Lambda matrix of parameters controlling the level of sparsity. Only
#'   the minimum, maximum and length are used in \code{\link{PenalisedOpenMx}}.
#' @param penalised optional binary matrix indicating which coefficients are
#'   regularised.
#' @param ... additional parameters passed to \code{\link[OpenMx]{OpenMx}} functions (for
#'   \code{\link{PenalisedOpenMx}}), or \code{\link[glmnet]{glmnet}} (for
#'   \code{\link{PenalisedLinearSystem}}).
#'
#' @return A list with: \item{selected}{matrix of binary selection status. Rows
#'   correspond to different regularisation parameters. Columns correspond to
#'   different parameters to estimated.} \item{beta_full}{matrix of model
#'   coefficients. Rows correspond to different regularisation parameters.
#'   Columns correspond to different parameters to estimated.}
#'
#' @family underlying algorithm functions
#' @seealso \code{\link{SelectionAlgo}}, \code{\link{VariableSelection}},
#'   \code{\link{OpenMxMatrix}},
#'   \code{\link{LinearSystemMatrix}}
#'
#' @references \insertRef{RegSEM}{sharp}
#'
#' @examples
#' \donttest{
#' # Data simulation
#' pk <- c(3, 2, 3)
#' dag <- LayeredDAG(layers = pk)
#' theta <- dag
#' theta[2, 4] <- 0
#' set.seed(1)
#' simul <- SimulateStructural(theta = theta, pk = pk, output_matrices = TRUE)
#'
#' # Running regularised SEM (OpenMx)
#' if (requireNamespace("OpenMx", quietly = TRUE)) {
#'   mysem <- PenalisedOpenMx(
#'     xdata = simul$data, adjacency = dag,
#'     Lambda = seq(1, 10, 1)
#'   )
#'   OpenMxMatrix(vect = mysem$selected[3, ], adjacency = dag)
#' }
#'
#' # Running regularised SEM (glmnet)
#' mysem <- PenalisedLinearSystem(
#'   xdata = simul$data, adjacency = dag
#' )
#' LinearSystemMatrix(vect = mysem$selected[20, ], adjacency = dag)
#' }
#' @export
PenalisedOpenMx <- function(xdata,
                            adjacency,
                            penalised = NULL,
                            residual_covariance = NULL,
                            Lambda,
                            ...) {
  # Checking OpenMx package is installed
  CheckPackageInstalled("OpenMx")

  # Storing extra arguments
  extra_args <- list(...)

  # Checking inputs
  if (!is.null(penalised)) {
    if (any(dim(penalised) != dim(adjacency))) {
      stop("Arguments 'adjacency' and 'penalised' are not compatible. They must be of the same dimension.")
    }
  } else {
    penalised <- adjacency
  }
  penalised <- t(penalised)

  # Scaling the data
  xdata <- scale(xdata)

  # Defining RAM matrices in OpenMx format
  ram_matrices <- OpenMxModel(
    adjacency = adjacency,
    residual_covariance = residual_covariance,
    manifest = colnames(adjacency)[colnames(adjacency) %in% colnames(xdata)]
  )

  # Defining expectation
  expectation <- OpenMx::mxExpectationRAM("A", "S", "F", "M",
    dimnames = colnames(adjacency)
  )

  # Defining fit function (maximum likelihood estimation)
  ml_function <- OpenMx::mxFitFunctionML()

  # Running unpenalised model
  model_spec <- OpenMx::mxModel(
    "Model",
    OpenMx::mxData(xdata, type = "raw"),
    ram_matrices$Amat,
    ram_matrices$Smat,
    ram_matrices$Fmat,
    ram_matrices$Mmat,
    expectation,
    ml_function
  )
  unpenalised <- OpenMx::mxRun(model_spec, silent = TRUE, suppressWarnings = TRUE)

  # Running penalised estimations
  coef_to_penalise <- as.character(stats::na.exclude(ram_matrices$Amat$labels[which(penalised == 1)]))
  mymodel <- OpenMx::mxPenaltySearch(OpenMx::mxModel(
    unpenalised,
    OpenMx::mxPenaltyLASSO(
      what = coef_to_penalise,
      name = "lasso",
      lambda = min(Lambda),
      lambda.max = max(Lambda),
      lambda.step = (max(Lambda) - min(Lambda)) / max((length(Lambda) - 1), 1)
    ),
    OpenMx::mxMatrix("Full", 1, 1, free = TRUE, values = 0, labels = "lambda")
  ), silent = TRUE, suppressWarnings = TRUE)$compute$steps$PS$output$detail

  # Extracting estimated coefficients
  beta_full <- as.matrix(mymodel[rev(seq_len(nrow(mymodel))), seq(6, ncol(mymodel) - 1)])

  # Setting as missing if model did not converge
  beta_full[which(as.character(mymodel$statusCode) != "OK"), ] <- NA

  # Defining row and column names
  rownames(beta_full) <- paste0("s", seq(0, nrow(beta_full) - 1))

  # Extracting selection status
  selected <- ifelse(abs(beta_full[, coef_to_penalise, drop = FALSE]) > 1e-5, yes = 1, no = 0)

  return(list(selected = selected, beta_full = beta_full))
}


#' @rdname PenalisedOpenMx
#' @export
PenalisedLinearSystem <- function(xdata,
                                  adjacency,
                                  penalised = NULL,
                                  Lambda = NULL,
                                  ...) {
  # Storing extra arguments
  extra_args <- list(...)

  # Checking inputs
  if (!is.null(penalised)) {
    if (any(dim(penalised) != dim(adjacency))) {
      stop("Arguments 'adjacency' and 'penalised' are not compatible. They must be of the same dimension.")
    }
  } else {
    penalised <- adjacency
  }

  # Standardising xdata
  xdata <- scale(xdata)

  # Defining coefficient labels (A)
  Alabels <- matrix(paste0("a", as.vector(col(adjacency)), "_", as.vector(row(adjacency))),
    nrow = ncol(adjacency), ncol = nrow(adjacency)
  )
  Alabels <- ifelse(adjacency == 1, yes = Alabels, no = NA)

  # Identifying outcomes
  outcome_ids <- which(apply(adjacency, 2, sum) != 0)
  predictor_ids <- which(apply(adjacency, 1, sum) != 0)

  if (is.null(Lambda)) {
    # Computing approximate lambda max
    lambda_max <- max(abs(stats::cov(xdata[, predictor_ids], xdata[, outcome_ids])))

    # Defining lambda grid
    Lambda <- LambdaSequence(lmax = lambda_max, lmin = 1e-4 * lambda_max)
  }

  # Extracting relevant extra arguments
  tmp_extra_args <- MatchingArguments(extra_args = extra_args, FUN = glmnet::glmnet)
  tmp_extra_args <- tmp_extra_args[!names(tmp_extra_args) %in% c("x", "y", "lambda", "family", "penalty.factor", "intercept")]

  # Running series of independent LASSO regressions
  beta_full <- NULL
  for (j in outcome_ids) {
    tmppred_ids <- which(adjacency[, j] != 0)
    tmplasso <- do.call(glmnet::glmnet,
      args = c(list(
        x = xdata[, tmppred_ids],
        y = xdata[, j],
        lambda = Lambda,
        family = "gaussian",
        penalty.factor = penalised[tmppred_ids, j],
        intercept = FALSE
      ), tmp_extra_args)
    )
    tmpbeta <- t(as.matrix(tmplasso$beta))
    colnames(tmpbeta) <- Alabels[tmppred_ids, j]
    beta_full <- cbind(beta_full, tmpbeta)
  }

  # Defining row and column names
  rownames(beta_full) <- paste0("s", seq(0, nrow(beta_full) - 1))

  # Extracting selection status
  selected <- ifelse(beta_full != 0, yes = 1, no = 0)

  return(list(selected = selected, beta_full = beta_full))
}


#' Writing OpenMx model (matrix specification)
#'
#' Returns matrix specification for use in \code{\link[OpenMx]{mxModel}} from
#' (i) the adjacency matrix of a Directed Acyclic Graph (asymmetric matrix A in
#' Reticular Action Model notation), and (ii) a binary matrix encoding nonzero
#' entries in the residual covariance matrix (symmetric matrix S in Reticular
#' Action Model notation).
#'
#' @inheritParams PenalisedOpenMx
#' @param manifest optional vector of manifest variable names.
#'
#' @return A list of RAM matrices that can be used in \code{\link[OpenMx]{mxRun}}.
#'
#' @seealso \code{\link{PenalisedOpenMx}}, \code{\link{OpenMxMatrix}}
#'
#' @examples
#' if (requireNamespace("OpenMx", quietly = TRUE)) {
#'   # Definition of simulated effects
#'   pk <- c(3, 2, 3)
#'   dag <- LayeredDAG(layers = pk)
#'   theta <- dag
#'   theta[2, 4] <- 0
#'   theta[3, 7] <- 0
#'   theta[4, 7] <- 0
#'
#'   # Data simulation
#'   set.seed(1)
#'   simul <- SimulateStructural(n = 500, v_between = 1, theta = theta, pk = pk)
#'
#'   # Writing RAM matrices for mxModel
#'   ram_matrices <- OpenMxModel(adjacency = dag)
#'
#'   # Running unpenalised model
#'   unpenalised <- OpenMx::mxRun(OpenMx::mxModel(
#'     "Model",
#'     OpenMx::mxData(simul$data, type = "raw"),
#'     ram_matrices$Amat,
#'     ram_matrices$Smat,
#'     ram_matrices$Fmat,
#'     ram_matrices$Mmat,
#'     OpenMx::mxExpectationRAM("A", "S", "F", "M", dimnames = colnames(dag)),
#'     OpenMx::mxFitFunctionML()
#'   ), silent = TRUE, suppressWarnings = TRUE)
#'   unpenalised$A$values
#'
#'   # Incorporating latent variables
#'   ram_matrices <- OpenMxModel(
#'     adjacency = dag,
#'     manifest = paste0("x", seq_len(7))
#'   )
#'   ram_matrices$Fmat$values
#'
#'   # Running unpenalised model
#'   unpenalised <- OpenMx::mxRun(OpenMx::mxModel(
#'     "Model",
#'     OpenMx::mxData(simul$data[, seq_len(7)], type = "raw"),
#'     ram_matrices$Amat,
#'     ram_matrices$Smat,
#'     ram_matrices$Fmat,
#'     ram_matrices$Mmat,
#'     OpenMx::mxExpectationRAM("A", "S", "F", "M", dimnames = colnames(dag)),
#'     OpenMx::mxFitFunctionML()
#'   ), silent = TRUE, suppressWarnings = TRUE)
#'   unpenalised$A$values
#' }
#' @export
OpenMxModel <- function(adjacency, residual_covariance = NULL, manifest = NULL) {
  # NB: means and variances are only correct for scaled data

  # Checking OpenMx package is installed
  CheckPackageInstalled("OpenMx")

  # Transposing the adjacency matrix to get support of A matrix in RAM notation
  adjacency <- t(adjacency)

  # Creating residual covariance matrix structure if not provided
  if (is.null(residual_covariance)) {
    residual_covariance <- diag(ncol(adjacency))
  }

  # Creating manifest if not provided (considering all variables as measured)
  if (is.null(manifest)) {
    manifest <- colnames(adjacency)
  }
  latent <- colnames(adjacency)[!colnames(adjacency) %in% manifest]

  # Defining coefficient labels (A)
  Alabels <- matrix(paste0("a", as.vector(row(adjacency)), "_", as.vector(col(adjacency))),
    nrow = nrow(adjacency), ncol = ncol(adjacency)
  )
  Alabels <- ifelse(adjacency == 1, yes = Alabels, no = NA)

  # Defining coefficient labels (S)
  Slabels <- matrix(paste0("s", as.vector(row(residual_covariance)), "_", as.vector(col(residual_covariance))),
    nrow = nrow(residual_covariance), ncol = ncol(residual_covariance)
  )
  Slabels[lower.tri(Slabels)] <- Slabels[upper.tri(Slabels)] # symmetry
  Slabels <- ifelse(residual_covariance != 0, yes = Slabels, no = NA)

  # Creating matrix A
  adjacency_free <- ifelse(adjacency == 1, yes = TRUE, no = FALSE)
  if (length(latent) > 0) {
    for (i in seq_len(length(latent))) {
      id <- which(adjacency_free[, latent[i]])[1]
      adjacency_free[id, latent[i]] <- FALSE
    }
  }
  Amat <- OpenMx::mxMatrix(
    type = "Full",
    nrow = nrow(adjacency),
    ncol = ncol(adjacency),
    name = "A",
    free = as.vector(adjacency_free),
    values = as.vector(adjacency),
    labels = as.vector(Alabels)
  )

  # Creating matrix S
  residual_covariance_free <- ifelse(residual_covariance != 0, yes = TRUE, no = FALSE)
  ids_fixed <- which(apply(adjacency, 1, sum) == 0)
  residual_covariance_free[cbind(ids_fixed, ids_fixed)] <- FALSE # non-residual (co)variances are fixed as data is scaled
  # }
  Smat <- OpenMx::mxMatrix(
    type = "Full",
    nrow = nrow(residual_covariance),
    ncol = ncol(residual_covariance),
    name = "S",
    free = as.vector(residual_covariance_free),
    values = as.vector(residual_covariance),
    labels = as.vector(Slabels)
  )

  # Creating matrix F
  tmpmat <- diag(ncol(adjacency))
  rownames(tmpmat) <- colnames(tmpmat) <- colnames(adjacency)
  tmpmat <- tmpmat[manifest, ]
  Fmat <- OpenMx::mxMatrix(
    type = "Full",
    nrow = nrow(tmpmat),
    ncol = ncol(tmpmat),
    name = "F",
    free = FALSE,
    values = as.vector(tmpmat)
  )

  # Creating matrix M (all zero for scaled data)
  Mmat <- OpenMx::mxMatrix(
    type = "Full",
    nrow = 1,
    ncol = ncol(adjacency),
    name = "M",
    free = FALSE,
    values = rep(0, ncol(adjacency))
  )

  # Preparing output
  out <- list(
    Amat = Amat,
    Smat = Smat,
    Fmat = Fmat,
    Mmat = Mmat
  )

  return(out)
}


#' Matrix from OpenMx outputs
#'
#' Returns a matrix from output of \code{\link[OpenMx]{mxPenaltySearch}}.
#'
#' @inheritParams PenalisedOpenMx
#' @param vect vector of coefficients to assign to entries of the matrix.
#'
#' @return An asymmetric matrix.
#'
#' @seealso \code{\link{PenalisedOpenMx}}, \code{\link{OpenMxModel}}
#'
#' @export
OpenMxMatrix <- function(vect, adjacency, residual_covariance = NULL) {
  # Checking OpenMx package is installed
  CheckPackageInstalled("OpenMx")

  # Re-formatting inputs
  if (is.matrix(vect)) {
    vect <- vect[1, ]
  }

  # Defining RAM matrices in OpenMx format
  ram_matrices <- OpenMxModel(adjacency = adjacency, residual_covariance = residual_covariance)

  # Assigning estimates to corresponding matrix entries
  A <- ram_matrices$Amat$values
  for (k in seq_len(length(vect))) {
    A[which(ram_matrices$Amat$labels == names(vect)[k], arr.ind = TRUE)] <- vect[k]
  }
  A <- t(A)

  # Defining row and column names
  rownames(A) <- rownames(adjacency)
  colnames(A) <- colnames(adjacency)

  # Defining the class of the output
  class(A) <- c("matrix", "adjacency_matrix")

  return(A)
}


#' Matrix from linear system outputs
#'
#' Returns a matrix from output of \code{\link{PenalisedLinearSystem}}.
#'
#' @inheritParams PenalisedOpenMx
#' @param vect vector of coefficients to assign to entries of the matrix.
#'
#' @return An asymmetric matrix.
#'
#' @seealso \code{\link{PenalisedLinearSystem}}
#'
#' @export
LinearSystemMatrix <- function(vect, adjacency) {
  # Defining coefficient labels (A)
  Alabels <- matrix(paste0("a", as.vector(col(adjacency)), "_", as.vector(row(adjacency))),
    nrow = ncol(adjacency), ncol = nrow(adjacency)
  )
  Alabels <- ifelse(adjacency == 1, yes = Alabels, no = NA)

  # Assigning estimates to corresponding matrix entries
  A <- matrix(0, nrow = nrow(adjacency), ncol = ncol(adjacency))
  for (k in seq_len(length(vect))) {
    A[which(Alabels == names(vect)[k], arr.ind = TRUE)] <- vect[k]
  }

  # Defining row and column names
  rownames(A) <- rownames(adjacency)
  colnames(A) <- colnames(adjacency)

  # Defining the class of the output
  class(A) <- c("matrix", "adjacency_matrix")

  return(A)
}
