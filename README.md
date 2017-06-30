# QuadraticAPI

_Please note, this package is under development and the format of functions used here is not set in stone. Consequently, the way functions are called may break in future builds. For any queries, please email me at [meicaljohnjones@gmail.com](mailto:meicaljohnjones@gmail.com). Pull requests are welcome!_

The aim of QuadraticAPI is to provide an R wrapper for Paul O'Reilly's [QUADrATiC: scalable gene expression connectivity mapping for repurposing FDA-approved therapeutics](http://pure.qub.ac.uk/portal/en/publications/quadratic-scalable-gene-expression-connectivity-mapping-for-repurposing-fdaapproved-therapeutics(d536c74c-8eee-480e-a23e-656e1570416c).html). QUADrATiC exposes a web service interface which this package interacts with, making it easier to run batches of jobs against the server.

## Getting Started

* Ensure you have Java installed on your machine
* Download QUADrATiC from http://go.qub.ac.uk/QUADrATiC and follow instructions to install and run the software 
provided in `Manual.pdf`
* Ensure you have the `xml2` package installed by running
```R
install.packages('xml2')
```

* Download Hadley Wickham's `devtools` package and use it to install QuadraticAPI:
```R
install.packages('devtools')
devtools::install_github('hiraethus/QuadraticAPI')
```
* Run an example Connectivity Map. Up regulated and down regulated probe IDs are provided in a data.frame 
comprised of two columns: the first column being the probe IDs and the second column being the signed rank of the 
probe IDs. For an example `tsv`, see the data folder in the R package archive.

```R
library('QuadraticAPI')

estrogen.sig <- read.table('data/Estrogen.tsv', stringsAsFactors=F)
result <- analyze(estrogen.sig)
```
* *Note:* Probe IDs must be for the Affymetrix GeneChip U133A platform in order to be successful
* `result` will contain a data.frame and it should look something like this:
![Rable of Results](./results-table.PNG "Table of Results")

## Batch Processing Example

To perform a batch of connections using QuadraticAPI, you can do this quite easily using the lapply command:

```R
files <- list.files(path='data/', pattern='*.tsv', full.names = T)
perform.quadratic <- function(file.name) {
  sig.df <- read.table(file.name, stringsAsFactors = F)
  connections <- analyze(sig.df)
  
  result <- list(
    file.name=file.name,
    connections=connections
  )
}

all.connections <- lapply(files, perform.quadratic)
```

which will return a list containing lists that have both the filename and connections in them. e.g. to access
the first result, use the following notation:

```R
all.connections[[1]]$file.name
all.connections[[1]]$connections
```

_Note:_ If you have memory constraints, you may want to save results to separate files rather than collecting them all in memory:

```R
files <- list.files(path='data/', pattern='*.tsv', full.names = T)
perform.quadratic <- function(file.name) {
  sig.df <- read.table(file.name, stringsAsFactors = F)
  connections <- analyze(sig.df)
  
  write.table(connections, file=paste0(file.name, '.connections'))
}

lapply(files, perform.quadratic)
```

### References
O’Reilly, Paul G., Qing Wen, Peter Bankhead, Philip D. Dunne, Darragh G. McArt, Suzanne McPherson, Peter W. Hamilton, Ken I. Mills, and Shu-Dong Zhang. "QUADrATiC: scalable gene expression connectivity mapping for repurposing FDA-approved therapeutics." BMC bioinformatics 17, no. 1 (2016): 198.
