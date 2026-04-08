

class PatrolReportTableViewState {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String searchQuery;
  final String filterSearch;
  final int rowsPerPage;
  final int page;
  final int? selectedReportId;
  final bool showSummary;
  final bool downloading;
  final String? activeFilterColumn;
  final Map<String, Set<String>> filterValues;

  const PatrolReportTableViewState({
    this.fromDate,
    this.toDate,
    this.searchQuery = '',
    this.filterSearch = '',
    this.rowsPerPage = 30,
    this.page = 0,
    this.selectedReportId,
    this.showSummary = true,
    this.downloading = false,
    this.activeFilterColumn,
    this.filterValues = const {},
  });

  PatrolReportTableViewState copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? searchQuery,
    String? filterSearch,
    int? rowsPerPage,
    int? page,
    int? selectedReportId,
    bool? showSummary,
    bool? downloading,
    String? activeFilterColumn,
    Map<String, Set<String>>? filterValues,
    bool clearSelectedReportId = false,
    bool clearActiveFilterColumn = false,
  }) {
    return PatrolReportTableViewState(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      searchQuery: searchQuery ?? this.searchQuery,
      filterSearch: filterSearch ?? this.filterSearch,
      rowsPerPage: rowsPerPage ?? this.rowsPerPage,
      page: page ?? this.page,
      selectedReportId: clearSelectedReportId
          ? null
          : (selectedReportId ?? this.selectedReportId),
      showSummary: showSummary ?? this.showSummary,
      downloading: downloading ?? this.downloading,
      activeFilterColumn: clearActiveFilterColumn
          ? null
          : (activeFilterColumn ?? this.activeFilterColumn),
      filterValues: filterValues ?? this.filterValues,
    );
  }
}
