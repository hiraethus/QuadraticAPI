#' Call QUADrATiC with a query gene signature
#'
#' @param query.gene.sig A data frame containing one column of probe IDs and a second with values of 1 where up-regulated and -1 where down-regulated.
#' @param analysis.set Define how reference profiles are grouped into reference sets in QUADrATiC. Valid values are Drug_Name, Drug_Name+Cell_Line, Drug_Name+Cell_Line+Time, Drug_Name+Conc+Cell_Line and Drug_Name+Conc+Cell_Line+Time. Default is Drug_Name.
#' @param num.rand.sigs The number of random signatures generated to estimate p-value. Default is 2000.
#' @param endpoint The URL for QUADrATiC. Default is http://localhost:8090. This can also be set globally by setting the option 'quadratic.endpoint'.
#'
#' @export
#'
#' @examples
#' estrogen.signature <- read.table('data/Estrogen.tsv', stringsAsFactors = F)
#' analyze(estrogen.signature)
#'
analyze <- function(query.gene.sig,
                    analysis.set='Drug_Name',
                    num.rand.sigs=2000,
                    endpoint=getOption('quadratic.endpoint', default = 'http://127.0.0.1:8090')) {

  StopIfQuadraticEndpointDown(endpoint)

  sig.id <- GenerateRandomSigID()
  probes <- DataFrameToQGS(query.gene.sig)
  SubmitQueryGeneSignature(sig.id, probes, endpoint)
  job.id.timestamped <- SubmitJob(sig.id, analysis.set, num.rand.sigs, endpoint)

  WaitForJobToFinish(job.id.timestamped, endpoint)
  DeleteQueryGeneSignature(sig.id, endpoint)

  result <- RetrieveResult(job.id.timestamped, endpoint)
  ResultToDataFrame(result)
}

DataFrameToQGS <- function(qgs.df) {
  stopifnot(is.data.frame(qgs.df))
  stopifnot(ncol(qgs.df) == 2)
  stopifnot(is.character(qgs.df[[1]]))
  stopifnot(is.integer(qgs.df[[2]]))

  qgs <- qgs.df[[2]]
  names(qgs) <- qgs.df[[1]]

  return(qgs)
}

GenerateRandomSigID <- function() {
  paste0('sig', abs(ceiling(rnorm(1) * 100)))
}

SubmitQueryGeneSignature <- function(sig.id, probes, endpoint) {
  httr::POST(paste0(endpoint, '/api/sigs'), body=list(id=sig.id, probes=as.list(probes)), encode='json')
}

DeleteQueryGeneSignature <- function(sig.id, endpoint) {
  sig.id.endpoint <- paste0('/api/sigs/', sig.id)
  httr::DELETE(paste0(endpoint, sig.id.endpoint))
}

SubmitJob <- function(sig.id, analysis.set, num.rand.sigs, endpoint) {
  job.id <- paste0(sig.id, format(Sys.time(), "%Y-%m-%d-%H-%M-%S"))
  job.body <- list(id=job.id, sigId=sig.id,
                   datasetId=analysis.set,
                   nRands=num.rand.sigs,
                   notes=' == QUADrATiC run by QUADrATiC API for Rlang == ')

  job.response <- httr::POST(paste0(endpoint, '/api/jobs'), body=job.body, encode='json')
  httr::content(job.response)$id
}

WaitForJobToFinish <- function(job.id.timestamped, endpoint) {
  progress.bar <- txtProgressBar(1, 100, style=3)

  # poll server to wait for job to finish
  while (TRUE) {
    # poll each second
    Sys.sleep(1)
    current.jobs <- httr::GET(paste0(endpoint, '/api/jobs/current'))
    current.jobs.content <- httr::content(current.jobs)

    this.job <- Filter(function(job) job$id == job.id.timestamped, current.jobs.content)[[1]]
    if (is.finite(this.job$percentDone) && this.job$percentDone >= 1 && this.job$percentDone <= 100) {
      setTxtProgressBar(progress.bar, this.job$percentDone)
    }

    if (this.job$state != 'IN_PROGRESS') break;
  }
}

RetrieveResult <- function(job.id.timestamped, endpoint) {
  result.endpoint <- paste0('/api/results/', job.id.timestamped)
  result.response <- httr::GET(paste0(endpoint, result.endpoint))

  while (result.response$status_code == 500) {
    # result isn't quite ready yet, let's back off and try again
    cat('Waiting for result...\n')
    Sys.sleep(1)
    result.response <- httr::GET(paste0(endpoint, result.endpoint))
  }

  httr::content(result.response)
}

ResultToDataFrame <- function(result) {
  num.results <- length(result$resultList)
  results.df <- data.frame(id=character(num.results),
                           z.score=numeric(num.results),
                           connection.score=numeric(num.results),
                           p.val=numeric(num.results),
                           num.profiles=numeric(num.results),
                           stringsAsFactors = FALSE)

  for (i in seq(num.results)) {
    results.df[i, 'id']                   <-  as.character(result$resultList[[i]][['id']])
    results.df[i, 'z.score']     <-  result$resultList[[i]][['cs']]
    results.df[i, 'connection.score'] <-  result$resultList[[i]][['rawCs']]
    results.df[i, 'p.val']                <-  result$resultList[[i]][['pVal']]
    results.df[i, 'num.profiles']         <-  result$resultList[[i]][['n']]
  }

  results.df
}

StopIfQuadraticEndpointDown <- function(endpoint) {
  tryCatch({
    httr::GET(endpoint)
  }, error = function(e) {
    cat('Could not contact QUADrATiC Server')
    stop(e)
  })
}
