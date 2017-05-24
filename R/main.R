
analyze <- function(up.regulated, down.regulated,
                    analysis.set='Drug_Name',
                    num.rand.sigs=2000,
                    endpoint=getOption('quadratic.endpoint', default = 'http://127.0.0.1:8090'))
{
  # check up.regulated and down.regulated are char vecs
  stopifnot(is.character(up.regulated))
  stopifnot(is.character(down.regulated))

  up.regulated.vals <- rep(1, length(up.regulated))
  names(up.regulated.vals) <- up.regulated

  down.regulated.vals <- rep(-1, length(down.regulated))
  names(down.regulated.vals) <- down.regulated

  probes <- c(up.regulated.vals, down.regulated.vals)
  sig.id <- paste0('sig', abs(ceiling(rnorm(1) * 100)))
  cat(sig.id, '\n')

  # submit query gene sig
  r <- POST(paste0(endpoint, '/api/sigs'), body=list(id=sig.id, probes=as.list(probes)), encode='json')

  # submit job
  job.id <- paste(sig.id, Sys.time())
  job.body <- list(id=job.id, sigId=sig.id,
                   datasetId=analysis.set,
                   nRands=num.rand.sigs,
                   notes=' == QUADrATiC run by QUADrATiC SDK for Rlang == ')

  job.response <- POST(paste0(endpoint, '/api/jobs'), body=job.body, encode='json')
}
