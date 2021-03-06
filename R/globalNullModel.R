#' @title Generate global null model p-value
#'
#' @description
#' Randomly select the same number of nodes in the largest component of netbox
#' result as a new gene candidate list and repeat multiple times to produce a
#' distribution of node size and edge numbers. This distribution will be used
#' to produce global p-value of netbox result based on the node size or edge
#' numbers of largest component in the final network result.
#'
#' @param netboxGraph A vector containing candidate gene list
#' @param networkGraph An igraph graph object
#' @param directed TRUE or FALSE
#' @param iterations TRUE of FALSE
#' @param numOfGenes A numeric value
#' @param pValueAdj A string for p-value correction method c('BH, 'Bonferroni')
#' @param pValueCutoff A numeric value c(0,1)
#'
#' @return a list with four lists (i.e. netboxOutput, nodeType, moduleMembership, neighborData)
#'
#' @author Eric Minwei Liu, \email{emliu.research@gmail.com}
#'
#' @examples
#' data(netbox2010)
#'
#' sifNetwork<-netbox2010$network
#' graphReduced <- networkSimplify(sifNetwork,directed = FALSE) 
#' 
#' geneList<-as.character(netbox2010$geneList)
#' 
#' results<-geneConnector(geneList=geneList,networkGraph=graphReduced,
#'                       pValueAdj='BH',pValueCutoff=0.05,
#'                       communityMethod='lec',keepIsolatedNodes=FALSE)
#'
#' names(results)
#' 
#' # Suggested 100 iterations. 
#' # Use 5 interations in the exampel to save running time.
#' # globalTest <- globalNullModel(netboxGraph=results$netboxGraph, 
#' #                              networkGraph=graphReduced, 
#' #                              iterations=5, numOfGenes = 274)
#' @concept netboxr
#' @export
#' @import igraph
globalNullModel <- function(netboxGraph, networkGraph, directed, 
                            iterations = 30,
                            numOfGenes = NULL, pValueAdj = "BH", 
                            pValueCutoff = 0.05) {

  # calculate component size in the final network result
  cl <- clusters(netboxGraph)

  if (is.null(numOfGenes)) {
    numOfGenes <- length(V(netboxGraph))
  }

  graphGiantComponent <- induced.subgraph(netboxGraph, which(cl$membership == which.max(cl$csize)))

  numOfNodesGiantComponent <- length(V(graphGiantComponent))
  numOfEdgesGiantComponent <- length(E(graphGiantComponent))
  message(sprintf(
    "Largest component in the network contains %s nodes and %s interactions\n", numOfNodesGiantComponent,
    numOfEdgesGiantComponent
  ))

  numOfNodes <- NULL
  numOfEdges <- NULL
  selectedGenes <- NULL
  for (iter in seq_len(iterations)) {
    message(sprintf("Global null model iteration: %s / %s\n", iter, iterations))

    selectedGenes <- sample(V(networkGraph)$name, numOfGenes, replace = FALSE)

    resultTmp <- geneConnector(
      geneList = selectedGenes, networkGraph = networkGraph, directed = FALSE,
      pValueAdj = "BH", pValueCutoff = 0.05, communityMethod = "ebc", keepIsolatedNodes = FALSE
    )

    cl <- clusters(resultTmp$netboxGraph)
    graphGiantComponentTmp <- induced.subgraph(resultTmp$netboxGraph, which(cl$membership == which.max(cl$csize)))

    numOfNodes[iter] <- length(V(graphGiantComponentTmp))
    numOfEdges[iter] <- length(E(graphGiantComponentTmp))
    message(sprintf(
      "Largest component in the network contains %s nodes and %s interactions\n\n", numOfNodes[iter],
      numOfEdges[iter]
    ))
  }

  pValueNodes <- (sum(numOfNodes >= numOfNodesGiantComponent) + 1) / (length(numOfNodes) + 1)
  pValueEdges <- (sum(numOfEdges >= numOfEdgesGiantComponent) + 1) / (length(numOfEdges) + 1)

  giantComponentRandom <- data.frame(rep(numOfGenes, length(numOfGenes)), numOfNodes, numOfEdges)
  colnames(giantComponentRandom) <- c("numOfGenesInput", "numOfNodes", "numOfEdges")

  globalNodesResult <- data.frame(
    numOfNodesGiantComponent, sum(numOfNodes >= numOfNodesGiantComponent),
    iterations, pValueNodes
  )
  colnames(globalNodesResult) <- c("numOfNodes", "numOfNodesAbove", "iterations", "pValueNodes")
  globalEdgesResult <- data.frame(
    numOfEdgesGiantComponent, sum(numOfEdges >= numOfEdgesGiantComponent),
    iterations, pValueEdges
  )
  colnames(globalEdgesResult) <- c("numOfEdges", "numOfEdgesAbove", "iterations", "pValueEdges")

  result <- list(
    globalNull = giantComponentRandom,
    globalNodesResult = globalNodesResult,
    globalEdgesResult = globalEdgesResult
  )

  return(result)
}
