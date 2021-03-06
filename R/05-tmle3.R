## ----cv_fig4, echo = FALSE----------------------------------------------------
knitr::include_graphics("img/misc/TMLEimage.pdf")


## ----tmle3-load-data----------------------------------------------------------
library(data.table)
library(tmle3)
library(sl3)
washb_data <- fread("https://raw.githubusercontent.com/tlverse/tlverse-data/master/wash-benefits/washb_data.csv", stringsAsFactors = TRUE)


## ----tmle3-node-list----------------------------------------------------------
node_list <- list(
  W = c(
    "month", "aged", "sex", "momage", "momedu",
    "momheight", "hfiacat", "Nlt18", "Ncomp", "watmin",
    "elec", "floor", "walls", "roof", "asset_wardrobe",
    "asset_table", "asset_chair", "asset_khat",
    "asset_chouki", "asset_tv", "asset_refrig",
    "asset_bike", "asset_moto", "asset_sewmach",
    "asset_mobile"
  ),
  A = "tr",
  Y = "whz"
)


## ----tmle3-process_missing----------------------------------------------------
processed <- process_missing(washb_data, node_list)
washb_data <- processed$data
node_list <- processed$node_list


## ----tmle3-ate-spec-----------------------------------------------------------
ate_spec <- tmle_ATE(
  treatment_level = "Nutrition + WSH",
  control_level = "Control"
)


## ----tmle3-learner-list-------------------------------------------------------
# choose base learners
lrnr_mean <- make_learner(Lrnr_mean)
lrnr_xgboost <- make_learner(Lrnr_xgboost)

# define metalearners appropriate to data types
ls_metalearner <- make_learner(Lrnr_nnls)
mn_metalearner <- make_learner(
  Lrnr_solnp, metalearner_linear_multinomial,
  loss_loglik_multinomial
)
sl_Y <- Lrnr_sl$new(
  learners = list(lrnr_mean, lrnr_xgboost),
  metalearner = ls_metalearner
)
sl_A <- Lrnr_sl$new(
  learners = list(lrnr_mean, lrnr_xgboost),
  metalearner = mn_metalearner
)

learner_list <- list(A = sl_A, Y = sl_Y)


## ----tmle3-spec-fit-----------------------------------------------------------
tmle_fit <- tmle3(ate_spec, washb_data, node_list, learner_list)


## ----tmle3-spec-summary-------------------------------------------------------
print(tmle_fit)

estimates <- tmle_fit$summary$psi_transformed
print(estimates)


## ----tmle3-spec-task----------------------------------------------------------
tmle_task <- ate_spec$make_tmle_task(washb_data, node_list)


## ----tmle3-spec-task-npsem----------------------------------------------------
tmle_task$npsem


## ----tmle3-spec-initial-likelihood--------------------------------------------
initial_likelihood <- ate_spec$make_initial_likelihood(
  tmle_task,
  learner_list
)
print(initial_likelihood)


## ----tmle3-spec-initial-likelihood-estimates----------------------------------
initial_likelihood$get_likelihoods(tmle_task)


## ----tmle3-spec-targeted-likelihood-------------------------------------------
targeted_likelihood <- Targeted_Likelihood$new(initial_likelihood)


## ----tmle3-spec-targeted-likelihood-no-cv-------------------------------------
targeted_likelihood_no_cv <-
  Targeted_Likelihood$new(initial_likelihood,
    updater = list(cvtmle = FALSE)
  )


## ----tmle3-spec-params--------------------------------------------------------
tmle_params <- ate_spec$make_params(tmle_task, targeted_likelihood)
print(tmle_params)


## ----tmle3-manual-fit---------------------------------------------------------
tmle_fit_manual <- fit_tmle3(
  tmle_task, targeted_likelihood, tmle_params,
  targeted_likelihood$updater
)
print(tmle_fit_manual)


## ----tmle3-tsm-all------------------------------------------------------------
tsm_spec <- tmle_TSM_all()
targeted_likelihood <- Targeted_Likelihood$new(initial_likelihood)
all_tsm_params <- tsm_spec$make_params(tmle_task, targeted_likelihood)
print(all_tsm_params)


## ----tmle3-delta-method-param-------------------------------------------------
ate_param <- define_param(
  Param_delta, targeted_likelihood,
  delta_param_ATE,
  list(all_tsm_params[[1]], all_tsm_params[[4]])
)
print(ate_param)


## ----tmle3-tsm-plus-delta-----------------------------------------------------
all_params <- c(all_tsm_params, ate_param)

tmle_fit_multiparam <- fit_tmle3(
  tmle_task, targeted_likelihood, all_params,
  targeted_likelihood$updater
)

print(tmle_fit_multiparam)


## ----stratified_ate-----------------------------------------------------------
stratified_ate_spec <- tmle_stratified(ate_spec, "sex")
stratified_fit <- tmle3(stratified_ate_spec, washb_data, node_list, learner_list)
print(stratified_fit)


## ----tmle-exercise-data, message=FALSE, warning=FALSE-------------------------
# load the data set
data(cpp)
cpp <- cpp[!is.na(cpp[, "haz"]), ]
cpp$parity01 <- as.numeric(cpp$parity > 0)
cpp[is.na(cpp)] <- 0
cpp$haz01 <- as.numeric(cpp$haz > 0)


## ---- metalrnr-exercise-------------------------------------------------------
metalearner <- make_learner(Lrnr_solnp,
  loss_function = loss_loglik_binomial,
  learner_function = metalearner_logistic_binomial
)


## ----tmle3-ex2----------------------------------------------------------------
ist_data <- data.table(read.csv("https://raw.githubusercontent.com/tlverse/deming2019-workshop/master/data/ist_sample.csv"))

