#' A data structure for tidy graph manipulation
#'
#' The `tbl_graph` class is a thin wrapper around an `igraph` object that
#' provides methods for manipulating the graph using the tidy API. As it is just
#' a subclass of `igraph` every igraph method will work as expected. A
#' `grouped_tbl_graph` is the equivalent of a `grouped_df` where either the
#' nodes or the edges has been grouped. The `grouped_tbl_graph` is not
#' constructed directly but by using the [group_by()] verb. After creation of a
#' `tble_graph` the nodes are activated by default. The context can be changed
#' using the [activate()] verb and affects all subsequent operations. Changing
#' context automatically drops any grouping. The current active context can
#' always be extracted with [as_tibble()], which drops the graph structure and
#' just returns a `tbl_df` or a `grouped_df` depending on the state of the
#' `tbl_graph`. The returned context can be overriden by using the `active`
#' argument in [as_tibble()].
#'
#' @details
#' Constructors are provided for most data structures that resembles networks.
#' If a class provides an [igraph::as.igraph()] method it is automatically
#' supported.
#'
#' @param x An object convertible to a `tbl_graph`
#'
#' @param directed Should the constructed graph be directed (defaults to `TRUE`)
#'
#' @param mode In case `directed = TRUE` should the edge direction be away from
#' node or towards. Possible values are `"out"` (default) or `"in"`.
#'
#' @param ... Arguments passed on to the conversion function
#'
#' @return A `tbl_graph` object
#'
#' @aliases tbl_graph
#' @export
#'
as_tbl_graph <- function(x, ...) {
  UseMethod('as_tbl_graph')
}
#' @describeIn as_tbl_graph Default method. tries to call [igraph::as.igraph()] on the input.
#' @export
#' @importFrom igraph as.igraph
as_tbl_graph.default <- function(x, ...) {
  tryCatch({
    as_tbl_graph(as.igraph(x))
  }, error = function(e) stop('No support for ', class(x)[1], ' objects', call. = FALSE))
}
#' @rdname as_tbl_graph
#' @export
is.tbl_graph <- function(x) {
  inherits(x, 'tbl_graph')
}
#' @importFrom tibble trunc_mat
#' @importFrom tools toTitleCase
#' @export
print.tbl_graph <- function(x, ...) {
  arg_list <- list(...)
  graph_desc <- describe_graph(x)
  not_active <- if (active(x) == 'nodes') 'edges' else 'nodes'
  top <- do.call(trunc_mat, modifyList(arg_list, list(x = as_tibble(x), n = 6)))
  top$summary <- sub('A tibble', toTitleCase(paste0(substr(active(x), 1, 4), ' data')), top$summary)
  top$summary <- paste0(top$summary, ' (active)')
  bottom <- do.call(trunc_mat, modifyList(arg_list, list(x = as_tibble(x, active = not_active), n = 3)))
  bottom$summary <- sub('A tibble', toTitleCase(paste0(substr(not_active, 1, 4), ' data')), bottom$summary)
  cat('# A tbl_graph: ', gorder(x), ' nodes and ', gsize(x), ' edges\n', sep = '')
  cat('#\n')
  cat('# ', graph_desc, '\n', sep = '')
  cat('#\n')
  print(top)
  cat('#\n')
  print(bottom)
  invisible(x)
}
#' @importFrom igraph is_simple is_directed is_bipartite is_connected is_dag
describe_graph <- function(x) {
  prop <- list(simple = is_simple(x), directed = is_directed(x),
                  bipartite = is_bipartite(x), connected = is_connected(x),
                  tree = is_tree(x), forest = is_forest(x), DAG = is_dag(x))
  desc <- c()
  if (prop$tree || prop$forest) {
    desc[1] <- if (prop$directed) 'A rooted' else 'An unrooted'
    desc[2] <- if (prop$tree) 'tree' else paste0('forest with ', count_components(x), ' trees')
  } else {
    desc[1] <- if (prop$DAG) 'A directed acyclic' else if (prop$bipartite) 'A bipartite' else if (prop$directed) 'A directed' else 'An undirected'
    desc[2] <- if (prop$simple) 'simple graph' else 'multigraph'
    n_comp <- count_components(x)
    desc[3] <- paste0('with ' , n_comp, ' component', if (n_comp > 1) 's' else '')
  }
  paste(desc, collapse = ' ')
}
#' @importFrom igraph is_connected is_simple gorder gsize
is_tree <- function(x) {
  is_connected(x) && is_simple(x) && (gorder(x) - gsize(x) == 1)
}
#' @importFrom igraph is_connected is_simple gorder gsize count_components
is_forest <- function(x) {
  !is_connected(x) && is_simple(x) && (gorder(x) - gsize(x) - count_components(x) == 1)
}
#' @importFrom igraph is_bipartite
#' @export
igraph::is_bipartite
#' @importFrom igraph is_chordal
#' @export
igraph::is_chordal
#' @importFrom igraph is_connected
#' @export
igraph::is_connected
#' @importFrom igraph is_dag
#' @export
igraph::is_dag
#' @importFrom igraph is_directed
#' @export
igraph::is_directed
#' @importFrom igraph is_simple
#' @export
igraph::is_simple
#' @export
as_tbl_graph.tbl_graph <- function(x, ...) {
  x
}
set_graph_data <- function(x, value, active) {
  UseMethod('set_graph_data')
}
set_graph_data.tbl_graph <- function(x, value, active = NULL) {
  if (is.null(active)) active <- active(x)
  switch(
    active,
    nodes = set_node_attributes(x, value),
    edges = set_edge_attributes(x, value),
    stop('Unknown active element: ', active(x), '. Only nodes and edges supported', call. = FALSE)
  )
}
set_graph_data.grouped_tbl_graph <- function(x, value, active = NULL) {
  x <- NextMethod()
  apply_groups(x, attributes(value))
}
#' @importFrom igraph vertex_attr<-
set_node_attributes <- function(x, value) {
  vertex_attr(x) <- as.list(value)
  x
}
#' @importFrom igraph edge_attr<-
set_edge_attributes <- function(x, value) {
  value <- value[, !names(value) %in% c('from', 'to')]
  edge_attr(x) <- as.list(value)
  x
}
#' @importFrom igraph as.igraph
#' @export
as.igraph.tbl_graph <- function(x, ...) {
  class(x) <- 'igraph'
  attr(x, 'active') <- NULL
  x
}
#' @importFrom dplyr tbl_vars
#' @export
tbl_vars.tbl_graph <- function(x) {
  names(as_tibble(x))
}
#' @importFrom dplyr groups
#' @export
groups.tbl_graph <- function(x) {
  NULL
}
