/// Sorting options for ride discovery.
enum SearchSort {
  recommended,
  priceLowToHigh,
  priceHighToLow,
  nearest,
  highestRated,
  newestVehicle;

  String get displayLabel => switch (this) {
    SearchSort.recommended => 'Recommended',
    SearchSort.priceLowToHigh => 'Price: Low to High',
    SearchSort.priceHighToLow => 'Price: High to Low',
    SearchSort.nearest => 'Nearest',
    SearchSort.highestRated => 'Highest Rated',
    SearchSort.newestVehicle => 'Newest Vehicle',
  };
}
