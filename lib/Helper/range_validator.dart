/// Validates and adjusts the range values to be within the valid range of the document.
/// @param start - The start value of the range.
/// @param end - The end value of the range.
/// @param documentLength - The length of the document.
/// @returns - A tuple containing the adjusted start and end values.
List<int> validateRange(int start, int end, int documentLength) {
  if (start < 0) start = 0;
  if (end > documentLength) end = documentLength;
  if (start > end) start = end;
  return [start, end];
}
