analyze <- function(query.gene.sig,
                    analysis.set='Drug_Name',
                    num.rand.sigs=2000,
                    endpoint=getOption('quadratic.endpoint', default = 'http://127.0.0.1:8090'))
{
  probes <- data.frame.to.qgs(query.gene.sig)
  sig.id <- paste0('sig', abs(ceiling(rnorm(1) * 100)))

  # submit query gene sig
  r <- httr::POST(paste0(endpoint, '/api/sigs'), body=list(id=sig.id, probes=as.list(probes)), encode='json')

  # submit job
  job.id <- paste0(sig.id, format(Sys.time(), "%Y-%m-%d-%H-%M-%S"))
  job.body <- list(id=job.id, sigId=sig.id,
                   datasetId=analysis.set,
                   nRands=num.rand.sigs,
                   notes=' == QUADrATiC run by QUADrATiC API for Rlang == ')

  job.response <- httr::POST(paste0(endpoint, '/api/jobs'), body=job.body, encode='json')
  job.id.timestamped <- httr::content(job.response)$id

  # poll server to wait for job to finish
  while (TRUE) {
    # poll each second
    Sys.sleep(1)
    current.jobs <- httr::GET(paste0(endpoint, '/api/jobs/current'))
    current.jobs.content <- httr::content(current.jobs)

    is.job.still.going <-
      Reduce(`||`, sapply(current.jobs.content,
                          function(job) job$sigId == sig.id && job$state == 'IN_PROGRESS'))

    if (!is.job.still.going) break;
  }

  # unmarshal result and convert to data.frame
  result.endpoint <- paste0('/api/results/', job.id.timestamped)
  result <- httr::content(httr::GET(paste0(endpoint, result.endpoint)))

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

data.frame.to.qgs <- function(qgs.df) {
  stopifnot(is.data.frame(qgs.df))
  stopifnot(ncol(qgs.df) == 2)
  stopifnot(is.character(qgs.df[[1]]))
  stopifnot(is.integer(qgs.df[[2]]))

  qgs <- qgs.df[[2]]
  names(qgs) <- qgs.df[[1]]

  return(qgs)
}
