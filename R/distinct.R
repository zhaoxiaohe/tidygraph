#' @importFrom dplyr distinct
#' @importFrom rlang quos quo sym eval_tidy UQS
#' @importFrom utils head
#' @export
distinct.tbl_graph <- function(.data, ..., .keep_all = FALSE) {
  .graph_context$set(.data)
  on.exit(.graph_context$clear())
  d_tmp <- as_tibble(.data)
  if ('.tbl_graph_index' %in% names(d_tmp)) {
    stop('The attribute name ".tbl_graph_index" is reserved', call. = FALSE)
  }
  orig_ind <- seq_len(nrow(d_tmp))
  dot_list <- quos(..., .named = TRUE)
  if (length(dot_list) == 0) {
    dot_list <- lapply(names(d_tmp), function(n) quo(!! sym(n)))
    names(dot_list) <- names(d_tmp)
  }
  d_tmp$.tbl_graph_index <- orig_ind

  d_tmp <- eval_tidy(
    quo(
      distinct(d_tmp, UQS(dot_list), .keep_all = TRUE)
    )
  )

  remove_ind <- orig_ind[-d_tmp$.tbl_graph_index]
  graph <- switch(
    active(.data),
    nodes = delete_vertices(.data, remove_ind),
    edges = delete_edges(.data, remove_ind)
  ) %gr_attr% .data
  if (!.keep_all) {
    d_tmp <- d_tmp[, names(d_tmp) %in% names(dot_list), drop = FALSE]
  } else {
    d_tmp <- d_tmp[, names(d_tmp) != '.tbl_graph_index', drop = FALSE]
  }
  set_graph_data(graph, d_tmp)
}
#' @export
dplyr::distinct
